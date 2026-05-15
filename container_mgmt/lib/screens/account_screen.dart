import 'package:flutter/material.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';
import 'user_management_screen.dart';

// ── Account Screen ────────────────────────────────────────────────────────────
// Full-page screen with a permanent left sidebar.
// Sidebar items: My Profile | User Management (admin only)

enum _AccountTab { profile, users }

class AccountScreen extends StatefulWidget {
  final Session session;
  final bool isAdmin;

  const AccountScreen({
    super.key,
    required this.session,
    required this.isAdmin,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  _AccountTab _tab = _AccountTab.profile;

  String get _initials {
    final parts = widget.session.fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────────
          _TopBar(onBack: () => Navigator.pop(context)),

          // ── Main content: sidebar + body ─────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Permanent sidebar ─────────────────────────────
                _Sidebar(
                  initials: _initials,
                  session: widget.session,
                  isAdmin: widget.isAdmin,
                  selected: _tab,
                  onSelect: (t) => setState(() => _tab = t),
                ),

                // ── Content area ──────────────────────────────────
                Expanded(
                  child: _tab == _AccountTab.profile
                      ? _ProfilePanel(session: widget.session)
                      : const _UserManagementPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.yellow,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.yellow,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.manage_accounts_rounded,
              color: AppColors.yellow,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Account Settings',
                style: TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Manage your profile and system users',
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Permanent sidebar ─────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final String initials;
  final Session session;
  final bool isAdmin;
  final _AccountTab selected;
  final ValueChanged<_AccountTab> onSelect;

  const _Sidebar({
    required this.initials,
    required this.session,
    required this.isAdmin,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.green,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(2, 0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Avatar card ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  session.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.yellow.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    session.role,
                    style: const TextStyle(
                      color: AppColors.yellow,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Nav label ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: Text(
              'NAVIGATION',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // ── Nav items ─────────────────────────────────────────
          _SidebarItem(
            icon: Icons.person_rounded,
            label: 'My Profile',
            selected: selected == _AccountTab.profile,
            onTap: () => onSelect(_AccountTab.profile),
          ),

          if (isAdmin)
            _SidebarItem(
              icon: Icons.people_rounded,
              label: 'User Management',
              selected: selected == _AccountTab.users,
              onTap: () => onSelect(_AccountTab.users),
            ),

          const Spacer(),

          // ── Bottom divider ────────────────────────────────────
          Divider(
            color: Colors.white.withValues(alpha: 0.12),
            height: 1,
            indent: 20,
            endIndent: 20,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              'Container Management System',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar nav item ──────────────────────────────────────────────────────────

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? AppColors.yellow.withValues(alpha: 0.18)
                : _hovered
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(
                    color: AppColors.yellow.withValues(alpha: 0.4),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              // Active indicator bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: active ? AppColors.yellow : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                widget.icon,
                size: 18,
                color: active
                    ? AppColors.yellow
                    : Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: active
                        ? AppColors.yellow
                        : Colors.white.withValues(alpha: 0.85),
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              if (active)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.yellow,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── My Profile panel ──────────────────────────────────────────────────────────

class _ProfilePanel extends StatelessWidget {
  final Session session;
  const _ProfilePanel({required this.session});

  String get _initials {
    final parts = session.fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  Widget _infoRow(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppColors.green),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ────────────────────────────────────
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'MY PROFILE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Profile card ──────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Green header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 3,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials,
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.yellow.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.yellow.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                session.role,
                                style: const TextStyle(
                                  color: AppColors.yellow,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Info rows
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
                  child: Column(
                    children: [
                      _infoRow(
                        'User Code',
                        session.userCode,
                        Icons.badge_rounded,
                      ),
                      Divider(height: 1, color: Colors.grey.shade100),
                      _infoRow(
                        'Full Name',
                        session.fullName,
                        Icons.person_rounded,
                      ),
                      Divider(height: 1, color: Colors.grey.shade100),
                      _infoRow('Role', session.role, Icons.work_rounded),
                      if (session.portDesc != null) ...[
                        Divider(height: 1, color: Colors.grey.shade100),
                        _infoRow(
                          'Assigned Port',
                          session.portDesc!,
                          Icons.location_on_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── User Management panel ─────────────────────────────────────────────────────
// Embeds UserManagementScreen in embedded mode (no Scaffold/AppBar).

class _UserManagementPanel extends StatelessWidget {
  const _UserManagementPanel();

  @override
  Widget build(BuildContext context) {
    return const UserManagementScreen(embedded: true);
  }
}
