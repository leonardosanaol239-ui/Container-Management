import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/container_model.dart';
import '../models/port.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../models/row_model.dart';

// ── Notification model ────────────────────────────────────────────────────────

enum NotifType { movement, moveOut }

class AppNotification {
  final String id;
  final NotifType type;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;
  // Extra structured data for the detail dialog
  final Map<String, String> metadata;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'title': title,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'metadata': metadata,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'],
    type: NotifType.values[j['type'] as int],
    title: j['title'],
    body: j['body'],
    timestamp: DateTime.parse(j['timestamp']),
    isRead: j['isRead'] ?? false,
    metadata: (j['metadata'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, v.toString()),
    ),
  );
}

// ── Notification Service ──────────────────────────────────────────────────────

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  static const _kStorageKey = 'app_notifications_v1';
  static const _kSeenMovementsKey = 'seen_movement_ids_v1';
  static const _kSeenMoveOutsKey = 'seen_moveout_ids_v1';
  static const int _maxNotifications = 50;

  final _api = ApiService();
  Timer? _pollTimer;

  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  final Set<String> _seenMovementIds = {};
  final Set<String> _seenMoveOutIds = {};

  // The currently logged-in user — set via setSession()
  String? _currentUserName;

  bool _initialized = false;

  // ── Session ─────────────────────────────────────────────────────────────────

  /// Call this after login so notifications can record who approved movements.
  void setSession(String fullName) {
    _currentUserName = fullName;
  }

  // ── Init / dispose ──────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFromPrefs();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Polling ─────────────────────────────────────────────────────────────────

  void _startPolling() {
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final ports = await _api.getPorts();
      final prefs = await SharedPreferences.getInstance();

      for (final port in ports) {
        final containers = await _api.getContainersByPort(port.portId);
        await _checkMovements(containers, port, prefs);
        _checkMoveOuts(containers, port, prefs);
      }
    } catch (_) {
      // Silently ignore network errors during polling
    }
  }

  // ── Movement detection ───────────────────────────────────────────────────────

  Future<void> _checkMovements(
    List<ContainerModel> containers,
    Port port,
    SharedPreferences prefs,
  ) async {
    final confirmed = containers
        .where(
          (c) =>
              c.locationStatusId == 1 &&
              c.moveConfirmedDate != null &&
              c.rowId != null,
        )
        .toList();

    if (confirmed.isEmpty) return;

    // Fetch layout data once per port poll so we can resolve IDs → names
    // Cache: blockId → Block, bayId → Bay, rowId → RowModel
    final Map<int, Block> blocksById = {};
    final Map<int, Bay> baysById = {};
    final Map<int, RowModel> rowsById = {};

    try {
      // We need yards → blocks → bays → rows
      final yards = await _api.getYards(port.portId);
      for (final yard in yards) {
        final blocks = await _api.getBlocks(yard.yardId);
        for (final block in blocks) {
          blocksById[block.blockId] = block;
          final bays = await _api.getBays(block.blockId);
          for (final bay in bays) {
            baysById[bay.bayId] = bay;
            final rows = await _api.getRows(bay.bayId);
            for (final row in rows) {
              rowsById[row.rowId] = row;
            }
          }
        }
      }
    } catch (_) {
      // If layout fetch fails, fall back to IDs
    }

    for (final c in confirmed) {
      final key = '${c.containerId}_${c.moveConfirmedDate}';
      if (_seenMovementIds.contains(key)) continue;

      _seenMovementIds.add(key);
      _persistSeenMovements(prefs);

      // Resolve exact names
      final block = c.blockId != null ? blocksById[c.blockId] : null;
      final bay = c.bayId != null ? baysById[c.bayId] : null;
      final row = c.rowId != null ? rowsById[c.rowId] : null;

      final blockLabel = block != null
          ? (block.blockName ?? 'Block ${block.blockNumber}')
          : (c.blockId != null ? 'Block ${c.blockId}' : null);
      final bayLabel =
          bay?.bayNumber ?? (c.bayId != null ? '${c.bayId}' : null);
      final rowLabel = row != null
          ? '${row.rowNumber}'
          : (c.rowId != null ? '${c.rowId}' : null);
      final tierLabel = c.tier != null ? '${c.tier}' : null;

      // (locationParts available if a combined string is ever needed)

      final confirmedDt = _parseDate(c.moveConfirmedDate);
      final requestedDt = _parseDate(c.moveRequestDate);

      final notif = AppNotification(
        id: key,
        type: NotifType.movement,
        title: 'Movement Approved',
        body:
            '${c.containerNumber} has been approved and placed at ${port.portDesc}.',
        timestamp: confirmedDt ?? DateTime.now(),
        metadata: {
          'Container': c.containerNumber,
          'Port': port.portDesc,
          'Block': ?blockLabel,
          'Bay': ?bayLabel,
          'Row': ?rowLabel,
          'Tier': ?tierLabel,
          if (c.type != null) 'Type': c.type!,
          'Confirmed': confirmedDt != null ? _formatDateTime(confirmedDt) : '—',
          if (requestedDt != null) 'Requested': _formatDateTime(requestedDt),
          if (c.yardEntryDate != null)
            'Yard Entry': _formatDateTime(
              _parseDate(c.yardEntryDate) ?? DateTime.now(),
            ),
          'Approved By': ?_currentUserName,
        },
      );
      _addNotification(notif);
    }
  }

  // ── Move-out detection ────────────────────────────────────────────────────────

  void _checkMoveOuts(
    List<ContainerModel> containers,
    Port port,
    SharedPreferences prefs,
  ) {
    final movedOut = containers.where((c) => c.isMovedOut && c.boundTo != null);

    for (final c in movedOut) {
      final key = 'out_${c.containerId}_${c.boundTo}';
      if (_seenMoveOutIds.contains(key)) continue;

      _seenMoveOutIds.add(key);
      _persistSeenMoveOuts(prefs);

      final now = DateTime.now();

      final notif = AppNotification(
        id: key,
        type: NotifType.moveOut,
        title: 'Container Moved Out',
        body:
            '${c.containerNumber} has been moved out from ${port.portDesc}'
            '${c.boundTo != null && c.boundTo!.isNotEmpty ? ' → ${c.boundTo}' : ''}.',
        timestamp: now,
        metadata: {
          'Container': c.containerNumber,
          'From Port': port.portDesc,
          if (c.boundTo != null && c.boundTo!.isNotEmpty)
            'Bound To': c.boundTo!,
          if (c.type != null) 'Type': c.type!,
          'Moved Out': _formatDateTime(now),
          if (c.yardEntryDate != null)
            'Yard Entry': _formatDateTime(_parseDate(c.yardEntryDate) ?? now),
          'Processed By': ?_currentUserName,
        },
      );
      _addNotification(notif);
    }
  }

  // ── Notification management ──────────────────────────────────────────────────

  void _addNotification(AppNotification notif) {
    _notifications.insert(0, notif);
    if (_notifications.length > _maxNotifications) {
      _notifications.removeRange(_maxNotifications, _notifications.length);
    }
    _saveToPrefs();
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    _saveToPrefs();
    notifyListeners();
  }

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].isRead = true;
      _saveToPrefs();
      notifyListeners();
    }
  }

  void clearAll() {
    _notifications.clear();
    _saveToPrefs();
    notifyListeners();
  }

  // ── Persistence ──────────────────────────────────────────────────────────────

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_kStorageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _notifications.addAll(
          list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)),
        );
      } catch (_) {}
    }

    final seenRaw = prefs.getStringList(_kSeenMovementsKey) ?? [];
    _seenMovementIds.addAll(seenRaw);

    final seenOutRaw = prefs.getStringList(_kSeenMoveOutsKey) ?? [];
    _seenMoveOutIds.addAll(seenOutRaw);
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_notifications.map((n) => n.toJson()).toList());
    await prefs.setString(_kStorageKey, encoded);
  }

  Future<void> _persistSeenMovements(SharedPreferences prefs) async {
    final list = _seenMovementIds.toList();
    final trimmed = list.length > 500 ? list.sublist(list.length - 500) : list;
    await prefs.setStringList(_kSeenMovementsKey, trimmed);
  }

  Future<void> _persistSeenMoveOuts(SharedPreferences prefs) async {
    final list = _seenMoveOutIds.toList();
    final trimmed = list.length > 500 ? list.sublist(list.length - 500) : list;
    await prefs.setStringList(_kSeenMoveOutsKey, trimmed);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  DateTime? _parseDate(String? iso) {
    if (iso == null) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${months[d.month - 1]} ${d.day}, ${d.year}  $h:$m $ampm';
  }
}
