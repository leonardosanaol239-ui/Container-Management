import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/container_model.dart';
import '../models/port.dart';
import '../models/yard.dart';

// ── Notification model ────────────────────────────────────────────────────────

enum NotifType { movement, capacityWarning, capacityFull, moveOut }

class AppNotification {
  final String id;
  final NotifType type;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'title': title,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'],
    type: NotifType.values[j['type'] as int],
    title: j['title'],
    body: j['body'],
    timestamp: DateTime.parse(j['timestamp']),
    isRead: j['isRead'] ?? false,
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
  static const _kCapacityPrefix = 'yard_capacity_';
  static const int _maxNotifications = 50;
  static const double _capacityWarnThreshold = 0.90;

  final _api = ApiService();
  Timer? _pollTimer;

  final List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Track which container IDs we've already notified about
  final Set<String> _seenMovementIds = {};
  final Set<String> _seenMoveOutIds = {};
  // Track which yards we've already sent a capacity warning for (reset when drops below threshold)
  final Set<int> _warnedYardIds = {};

  bool _initialized = false;

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
    // Poll immediately, then every 10 seconds
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final ports = await _api.getPorts();
      final prefs = await SharedPreferences.getInstance();

      for (final port in ports) {
        final containers = await _api.getContainersByPort(port.portId);
        _checkMovements(containers, port, prefs);
        _checkMoveOuts(containers, port, prefs);
        await _checkCapacity(port, containers, prefs);
      }
    } catch (_) {
      // Silently ignore network errors during polling
    }
  }

  // ── Movement detection ───────────────────────────────────────────────────────
  // A "confirmed movement" = locationStatusId == 1 AND moveConfirmedDate is set

  void _checkMovements(
    List<ContainerModel> containers,
    Port port,
    SharedPreferences prefs,
  ) {
    final confirmed = containers.where(
      (c) =>
          c.locationStatusId == 1 &&
          c.moveConfirmedDate != null &&
          c.rowId != null,
    );

    for (final c in confirmed) {
      // Unique key: containerId + moveConfirmedDate
      final key = '${c.containerId}_${c.moveConfirmedDate}';
      if (_seenMovementIds.contains(key)) continue;

      _seenMovementIds.add(key);
      _persistSeenMovements(prefs);

      final notif = AppNotification(
        id: key,
        type: NotifType.movement,
        title: 'Movement Approved',
        body:
            '${c.containerNumber} has been approved and placed at ${port.portDesc}.',
        timestamp: _parseDate(c.moveConfirmedDate) ?? DateTime.now(),
      );
      _addNotification(notif);
    }
  }

  // ── Move-out detection ────────────────────────────────────────────────────────
  // A "move-out" = locationStatusId == 2 (isMovedOut) AND boundTo or truckId set

  void _checkMoveOuts(
    List<ContainerModel> containers,
    Port port,
    SharedPreferences prefs,
  ) {
    final movedOut = containers.where((c) => c.isMovedOut && c.boundTo != null);

    for (final c in movedOut) {
      // Unique key: containerId + boundTo (stable once moved out)
      final key = 'out_${c.containerId}_${c.boundTo}';
      if (_seenMoveOutIds.contains(key)) continue;

      _seenMoveOutIds.add(key);
      _persistSeenMoveOuts(prefs);

      final notif = AppNotification(
        id: key,
        type: NotifType.moveOut,
        title: 'Container Moved Out',
        body:
            '${c.containerNumber} has been moved out from ${port.portDesc}'
            '${c.boundTo != null && c.boundTo!.isNotEmpty ? ' → ${c.boundTo}' : ''}.',
        timestamp: DateTime.now(),
      );
      _addNotification(notif);
    }
  }

  // ── Capacity check ───────────────────────────────────────────────────────────

  Future<void> _checkCapacity(
    Port port,
    List<ContainerModel> containers,
    SharedPreferences prefs,
  ) async {
    List<Yard> yards;
    try {
      yards = await _api.getYards(port.portId);
    } catch (_) {
      return;
    }

    for (final yard in yards) {
      final capacity = prefs.getInt('$_kCapacityPrefix${yard.yardId}');
      if (capacity == null || capacity <= 0) {
        // No limit set — clear any existing warning state
        _warnedYardIds.remove(yard.yardId);
        continue;
      }

      final inYard = containers
          .where(
            (c) => c.yardId == yard.yardId && c.rowId != null && !c.isMovedOut,
          )
          .length;

      final fill = inYard / capacity;

      if (fill < _capacityWarnThreshold) {
        // Dropped below threshold — allow re-warning next time
        _warnedYardIds.remove(yard.yardId);
        continue;
      }

      if (_warnedYardIds.contains(yard.yardId)) continue;
      _warnedYardIds.add(yard.yardId);

      final isFull = fill >= 1.0;
      final pct = (fill * 100).toStringAsFixed(0);

      final notif = AppNotification(
        id: 'cap_${yard.yardId}_${DateTime.now().millisecondsSinceEpoch}',
        type: isFull ? NotifType.capacityFull : NotifType.capacityWarning,
        title: isFull
            ? '⚠️ Yard Full — ${port.portDesc}'
            : '⚠️ Yard Near Capacity — ${port.portDesc}',
        body: isFull
            ? 'Yard ${yard.yardNumber} at ${port.portDesc} is FULL ($inYard/$capacity containers).'
            : 'Yard ${yard.yardNumber} at ${port.portDesc} is at $pct% capacity ($inYard/$capacity containers).',
        timestamp: DateTime.now(),
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

    // Load notifications
    final raw = prefs.getString(_kStorageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _notifications.addAll(
          list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)),
        );
      } catch (_) {}
    }

    // Load seen movement IDs
    final seenRaw = prefs.getStringList(_kSeenMovementsKey) ?? [];
    _seenMovementIds.addAll(seenRaw);

    // Load seen move-out IDs
    final seenOutRaw = prefs.getStringList(_kSeenMoveOutsKey) ?? [];
    _seenMoveOutIds.addAll(seenOutRaw);
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_notifications.map((n) => n.toJson()).toList());
    await prefs.setString(_kStorageKey, encoded);
  }

  Future<void> _persistSeenMovements(SharedPreferences prefs) async {
    // Keep only the last 500 to avoid unbounded growth
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
}
