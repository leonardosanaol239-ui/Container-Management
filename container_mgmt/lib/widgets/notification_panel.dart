import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

// ── Bell button with badge ────────────────────────────────────────────────────

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  int _prevUnread = 0;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.06), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: -0.04), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
    NotificationService().addListener(_onNotifChanged);
    _prevUnread = NotificationService().unreadCount;
  }

  void _onNotifChanged() {
    final current = NotificationService().unreadCount;
    if (current > _prevUnread) {
      _shakeCtrl.forward(from: 0);
    }
    _prevUnread = current;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    NotificationService().removeListener(_onNotifChanged);
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _openPanel(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (_) => const _NotificationPanelDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = NotificationService().unreadCount;

    return GestureDetector(
      onTap: () => _openPanel(context),
      child: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) =>
            Transform.rotate(angle: _shakeAnim.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_rounded,
                color: AppColors.yellow,
                size: 18,
              ),
              if (unread > 0)
                Positioned(
                  top: -7,
                  right: -7,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    constraints: const BoxConstraints(
                      minWidth: 17,
                      minHeight: 17,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.yellow, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Panel dialog ──────────────────────────────────────────────────────────────

class _NotificationPanelDialog extends StatefulWidget {
  const _NotificationPanelDialog();

  @override
  State<_NotificationPanelDialog> createState() =>
      _NotificationPanelDialogState();
}

class _NotificationPanelDialogState extends State<_NotificationPanelDialog> {
  NotifType? _filter; // null = show all

  @override
  void initState() {
    super.initState();
    NotificationService().addListener(_rebuild);
  }

  @override
  void dispose() {
    NotificationService().removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  List<AppNotification> _filtered(List<AppNotification> all) {
    if (_filter == null) return all;
    return all.where((n) => n.type == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final svc = NotificationService();
    final all = svc.notifications;
    final shown = _filtered(all);
    final unread = svc.unreadCount;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.only(
        top: 70,
        right: 16,
        bottom: 16,
        left: 16,
      ),
      alignment: Alignment.topRight,
      child: Container(
        width: 400,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────
            _PanelHeader(
              unread: unread,
              hasNotifs: all.isNotEmpty,
              onMarkAllRead: () => svc.markAllRead(),
              onClearAll: () => svc.clearAll(),
              onClose: () => Navigator.pop(context),
            ),

            // ── Filter tabs ──────────────────────────────────────────
            if (all.isNotEmpty)
              _FilterBar(
                selected: _filter,
                notifications: all,
                onSelect: (t) => setState(() => _filter = t),
              ),

            // ── List ────────────────────────────────────────────────
            Flexible(
              child: shown.isEmpty
                  ? _EmptyState(isFiltered: _filter != null)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final n = shown[i];
                        return _NotifTile(
                          notif: n,
                          onTap: () {
                            svc.markRead(n.id);
                            showDialog(
                              context: context,
                              builder: (_) => _NotifDetailDialog(notif: n),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Panel header ──────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  final int unread;
  final bool hasNotifs;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClearAll;
  final VoidCallback onClose;

  const _PanelHeader({
    required this.unread,
    required this.hasNotifs,
    required this.onMarkAllRead,
    required this.onClearAll,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        children: [
          // Bell icon with pulse ring when unread
          Stack(
            alignment: Alignment.center,
            children: [
              if (unread > 0)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: AppColors.yellow,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (unread > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unread new',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ] else
                      Text(
                        'All caught up',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          if (unread > 0)
            _HeaderAction(
              label: 'Mark read',
              icon: Icons.done_all_rounded,
              onTap: onMarkAllRead,
            ),
          if (hasNotifs) ...[
            const SizedBox(width: 6),
            _HeaderAction(
              label: 'Clear',
              icon: Icons.delete_sweep_rounded,
              color: AppColors.red.withValues(alpha: 0.8),
              onTap: onClearAll,
            ),
          ],
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (color ?? Colors.white).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final NotifType? selected;
  final List<AppNotification> notifications;
  final ValueChanged<NotifType?> onSelect;

  const _FilterBar({
    required this.selected,
    required this.notifications,
    required this.onSelect,
  });

  int _count(NotifType? type) {
    if (type == null) return notifications.length;
    return notifications.where((n) => n.type == type).length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.green,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            count: _count(null),
            selected: selected == null,
            color: AppColors.yellow,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Movements',
            count: _count(NotifType.movement),
            selected: selected == NotifType.movement,
            color: AppColors.green,
            onTap: () => onSelect(
              selected == NotifType.movement ? null : NotifType.movement,
            ),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: 'Move Out',
            count: _count(NotifType.moveOut),
            selected: selected == NotifType.moveOut,
            color: const Color(0xFF1565C0),
            onTap: () => onSelect(
              selected == NotifType.moveOut ? null : NotifType.moveOut,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.green : Colors.white,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: selected ? color : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotifTile extends StatefulWidget {
  final AppNotification notif;
  final VoidCallback onTap;

  const _NotifTile({required this.notif, required this.onTap});

  @override
  State<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends State<_NotifTile> {
  bool _hovered = false;

  Color get _accentColor {
    switch (widget.notif.type) {
      case NotifType.movement:
        return AppColors.green;
      case NotifType.moveOut:
        return const Color(0xFF1565C0);
    }
  }

  IconData get _icon {
    switch (widget.notif.type) {
      case NotifType.movement:
        return Icons.check_circle_rounded;
      case NotifType.moveOut:
        return Icons.local_shipping_rounded;
    }
  }

  String get _typeLabel {
    switch (widget.notif.type) {
      case NotifType.movement:
        return 'Movement';
      case NotifType.moveOut:
        return 'Move Out';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;
    final isRead = widget.notif.isRead;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? color.withValues(alpha: 0.06)
                : isRead
                ? Colors.white
                : color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead
                  ? Colors.grey.shade200
                  : color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left accent bar
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: isRead ? Colors.transparent : color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, color: color, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Type label chip
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _typeLabel.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: color,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.notif.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isRead
                                        ? FontWeight.w600
                                        : FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _timeAgo(widget.notif.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (!isRead) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.notif.body,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Notification detail dialog ────────────────────────────────────────────────

class _NotifDetailDialog extends StatelessWidget {
  final AppNotification notif;
  const _NotifDetailDialog({required this.notif});

  Color get _color {
    switch (notif.type) {
      case NotifType.movement:
        return AppColors.green;
      case NotifType.moveOut:
        return const Color(0xFF1565C0);
    }
  }

  IconData get _icon {
    switch (notif.type) {
      case NotifType.movement:
        return Icons.check_circle_rounded;
      case NotifType.moveOut:
        return Icons.local_shipping_rounded;
    }
  }

  String get _typeLabel {
    switch (notif.type) {
      case NotifType.movement:
        return 'Movement Approved';
      case NotifType.moveOut:
        return 'Container Moved Out';
    }
  }

  String _formatFull(DateTime dt) {
    final d = dt.toLocal();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}  ·  $h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Colored header ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _typeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatFull(notif.timestamp),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable body ────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Summary body ───────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            notif.body,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),

                      // ── Metadata rows ──────────────────────────────
                      if (notif.metadata.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DETAILS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.grey.shade400,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...notif.metadata.entries.map(
                                (e) => _DetailRow(
                                  label: e.key,
                                  value: e.value,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Close button (always visible at bottom) ────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: color.withValues(alpha: 0.4)),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.color,
  });

  IconData get _labelIcon {
    switch (label.toLowerCase()) {
      case 'container':
        return Icons.inventory_2_rounded;
      case 'port':
      case 'from port':
        return Icons.location_on_rounded;
      case 'block':
        return Icons.grid_view_rounded;
      case 'bay':
        return Icons.view_column_rounded;
      case 'row':
        return Icons.table_rows_rounded;
      case 'tier':
        return Icons.layers_rounded;
      case 'type':
        return Icons.category_rounded;
      case 'confirmed':
      case 'moved out':
        return Icons.check_circle_rounded;
      case 'requested':
        return Icons.schedule_rounded;
      case 'yard entry':
        return Icons.login_rounded;
      case 'bound to':
        return Icons.flag_rounded;
      case 'approved by':
      case 'processed by':
        return Icons.verified_user_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(_labelIcon, size: 14, color: color),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isFiltered;
  const _EmptyState({this.isFiltered = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFiltered
                  ? Icons.filter_list_off_rounded
                  : Icons.notifications_none_rounded,
              size: 40,
              color: AppColors.green.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No matching notifications' : 'All caught up',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Try selecting a different filter.'
                : 'Approved movements and move-outs\nwill appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade400,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
