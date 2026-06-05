import 'package:flutter/material.dart';
import '../models/session.dart';
import '../screens/account_screen.dart';

// ── Shared Nav Profile Button ─────────────────────────────────────────────────
// Avatar circle + full name + role + chevron dropdown for non-admin dashboards.
// Used by Driver, Checker, and Customer dashboards.

class NavProfileBtn extends StatefulWidget {
  final Session session;
  final VoidCallback onLogout;
  const NavProfileBtn({
    super.key,
    required this.session,
    required this.onLogout,
  });

  @override
  State<NavProfileBtn> createState() => _NavProfileBtnState();
}

class _NavProfileBtnState extends State<NavProfileBtn> {
  bool _h = false;
  final _link = LayerLink();
  OverlayEntry? _ov;
  final _inMenu = ValueNotifier<bool>(false);

  String get _ini {
    final p = widget.session.fullName.trim().split(' ');
    return p.length >= 2
        ? '${p.first[0]}${p.last[0]}'.toUpperCase()
        : p.first.isNotEmpty
        ? p.first[0].toUpperCase()
        : '?';
  }

  void _show() {
    _inMenu.value = true;
    if (_ov != null) return;
    _ov = OverlayEntry(
      builder: (_) => _NavDropdown(
        link: _link,
        initials: _ini,
        session: widget.session,
        inMenu: _inMenu,
        onHide: _hide,
        onScheduleHide: _sched,
        onProfile: () {
          _hide();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AccountScreen(session: widget.session, isAdmin: false),
            ),
          );
        },
        onLogout: widget.onLogout,
      ),
    );
    Overlay.of(context).insert(_ov!);
    if (mounted) setState(() => _h = true);
  }

  void _sched() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_inMenu.value && mounted) _hide();
    });
  }

  void _hide() {
    _ov?.remove();
    _ov = null;
    if (mounted) setState(() => _h = false);
  }

  @override
  void dispose() {
    _hide();
    _inMenu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _show(),
        onExit: (_) {
          _inMenu.value = false;
          _sched();
        },
        child: GestureDetector(
          onTap: () => _ov != null ? _hide() : _show(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _h
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _h
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar circle — dark green
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0B560D),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _ini,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Name + role
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.session.fullName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.session.role,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                // Chevron
                AnimatedRotation(
                  turns: _h ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dropdown ──────────────────────────────────────────────────────────────────
class _NavDropdown extends StatefulWidget {
  final LayerLink link;
  final String initials;
  final Session session;
  final ValueNotifier<bool> inMenu;
  final VoidCallback onHide, onScheduleHide, onProfile, onLogout;

  const _NavDropdown({
    required this.link,
    required this.initials,
    required this.session,
    required this.inMenu,
    required this.onHide,
    required this.onScheduleHide,
    required this.onProfile,
    required this.onLogout,
  });

  @override
  State<_NavDropdown> createState() => _NavDropdownState();
}

class _NavDropdownState extends State<_NavDropdown> {
  void _sched() {
    widget.inMenu.value = false;
    widget.onScheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: widget.link,
      showWhenUnlinked: false,
      offset: const Offset(0, 50),
      targetAnchor: Alignment.topRight,
      followerAnchor: Alignment.topRight,
      child: Align(
        alignment: Alignment.topRight,
        child: MouseRegion(
          onEnter: (_) => widget.inMenu.value = true,
          onExit: (_) => _sched(),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 210,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.13),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0B560D),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0B3D0F),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.session.fullName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.session.role,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  _DDItem(
                    icon: Icons.manage_accounts_rounded,
                    label: 'Manage Profile',
                    onTap: widget.onProfile,
                  ),
                  Divider(
                    height: 1,
                    color: Colors.grey.shade100,
                    indent: 14,
                    endIndent: 14,
                  ),
                  const SizedBox(height: 3),
                  _DDItem(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    color: const Color(0xFFFF2800),
                    onTap: widget.onLogout,
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DDItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _DDItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF1A1A0A),
  });

  @override
  State<_DDItem> createState() => _DDItemState();
}

class _DDItemState extends State<_DDItem> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: _h
                ? widget.color.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 15, color: widget.color),
              const SizedBox(width: 9),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
