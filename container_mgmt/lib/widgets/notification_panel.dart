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
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    NotificationService().addListener(_onNotifChanged);
    _prevUnread = NotificationService().unreadCount;
  }

  void _onNotifChanged() {
    final current = NotificationService().unreadCount;
    if (current > _prevUnread) {
      _shakeCtrl.forward(from: 0).then((_) => _shakeCtrl.reverse());
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
      barrierColor: Colors.black38,
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
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
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

  @override
  Widget build(BuildContext context) {
    final svc = NotificationService();
    final notifs = svc.notifications;
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
        width: 380,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: AppColors.yellow,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NOTIFICATIONS',
                          style: TextStyle(
                            color: AppColors.yellow,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          unread > 0 ? '$unread unread' : 'All caught up',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Mark all read
                  if (unread > 0)
                    GestureDetector(
                      onTap: () => svc.markAllRead(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  // Clear all
                  if (notifs.isNotEmpty)
                    GestureDetector(
                      onTap: () => svc.clearAll(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),

            // ── List ────────────────────────────────────────────────
            Flexible(
              child: notifs.isEmpty
                  ? _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: notifs.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.grey.shade100,
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (_, i) {
                        final n = notifs[i];
                        return _NotifTile(
                          notif: n,
                          onTap: () => svc.markRead(n.id),
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

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;

  const _NotifTile({required this.notif, required this.onTap});

  Color get _accentColor {
    switch (notif.type) {
      case NotifType.movement:
        return AppColors.green;
      case NotifType.capacityWarning:
        return const Color(0xFFFF6F00);
      case NotifType.capacityFull:
        return AppColors.red;
    }
  }

  IconData get _icon {
    switch (notif.type) {
      case NotifType.movement:
        return Icons.check_circle_rounded;
      case NotifType.capacityWarning:
        return Icons.warning_amber_rounded;
      case NotifType.capacityFull:
        return Icons.error_rounded;
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: notif.isRead
            ? Colors.transparent
            : color.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notif.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 52,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Approved movements and yard capacity\nalerts will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
