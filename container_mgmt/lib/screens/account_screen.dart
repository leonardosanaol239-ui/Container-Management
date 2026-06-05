import 'package:flutter/material.dart';
import '../models/session.dart';
import 'user_management_screen.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
const _navBg = Color(0xFF0B3D0F);
const _green = Color(0xFF0B560D);
const _bg = Color(0xFFF0F2EE);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE8EAE4);
const _textD = Color(0xFF1A1A0A);
const _textM = Color(0xFF4A4A4A);
const _textL = Color(0xFF757575);

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
      backgroundColor: const Color(0xFFF0F2EE),
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
      height: 60,
      color: _navBg,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Back button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.manage_accounts_rounded,
              color: Colors.white,
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
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Manage your profile and system users',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
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
      width: 220,
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
      decoration: const BoxDecoration(
        color: _green,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(2, 0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Avatar card ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
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
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  session.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    session.role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Nav label ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
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
            indent: 16,
            endIndent: 16,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Container Management System',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
                ? Colors.white.withValues(alpha: 0.15)
                : _hovered
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
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
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                widget.icon,
                size: 18,
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: active
                        ? Colors.white
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
                    color: Colors.white,
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
                  color: _green,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'MY PROFILE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _textD,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Hero banner card ──────────────────────────────────
          _ProfileHeroCard(initials: _initials, session: session),

          const SizedBox(height: 20),

          // ── Info grid ─────────────────────────────────────────
          _ProfileInfoGrid(session: session),
        ],
      ),
    );
  }
}

// ── Hero banner ───────────────────────────────────────────────────────────────

class _ProfileHeroCard extends StatelessWidget {
  final String initials;
  final Session session;

  const _ProfileHeroCard({required this.initials, required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Left accent stripe — dark green
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 5, color: _navBg),
            ),

            // Decorative circles on the right
            Positioned(
              top: -30,
              right: -30,
              child: _DecorativeCircle(size: 160, opacity: 0.06),
            ),
            Positioned(
              bottom: -10,
              right: 80,
              child: _DecorativeCircle(size: 100, opacity: 0.05),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 28, 32, 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  _AvatarRing(initials: initials),
                  const SizedBox(width: 24),

                  // Name + role + code
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          session.fullName,
                          style: const TextStyle(
                            color: _textD,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _RoleBadge(role: session.role),
                            const SizedBox(width: 10),
                            _CodeChip(code: session.userCode),
                          ],
                        ),
                        if (session.portDesc != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 13,
                                color: _textL,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                session.portDesc!,
                                style: const TextStyle(
                                  color: _textL,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: Color(0xFF2E7D32)),
                        SizedBox(width: 6),
                        Text(
                          'Active',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

// ── Avatar with animated gold ring ───────────────────────────────────────────

class _AvatarRing extends StatelessWidget {
  final String initials;
  const _AvatarRing({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer border ring
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _border, width: 3),
          ),
        ),
        // Inner avatar — dark nav green bg, white initials
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: _navBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Role badge ────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _navBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── User code chip ────────────────────────────────────────────────────────────

class _CodeChip extends StatelessWidget {
  final String code;
  const _CodeChip({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tag_rounded, size: 11, color: _textL),
          const SizedBox(width: 4),
          Text(
            code,
            style: const TextStyle(
              color: _textM,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Decorative circle ─────────────────────────────────────────────────────────

class _DecorativeCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _DecorativeCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _border.withValues(alpha: opacity * 3),
          width: 1.5,
        ),
      ),
    );
  }
}

// ── Info grid ─────────────────────────────────────────────────────────────────

class _ProfileInfoGrid extends StatelessWidget {
  final Session session;
  const _ProfileInfoGrid({required this.session});

  @override
  Widget build(BuildContext context) {
    final items = [
      _InfoItem(
        icon: Icons.badge_outlined,
        label: 'User Code',
        value: session.userCode,
        accent: _green,
      ),
      _InfoItem(
        icon: Icons.person_outline_rounded,
        label: 'Full Name',
        value: session.fullName,
        accent: const Color(0xFF1565C0),
      ),
      _InfoItem(
        icon: Icons.work_outline_rounded,
        label: 'Role',
        value: session.role,
        accent: const Color(0xFF6A1B9A),
      ),
      if (session.portDesc != null)
        _InfoItem(
          icon: Icons.location_on_outlined,
          label: 'Assigned Port',
          value: session.portDesc!,
          accent: const Color(0xFFE65100),
        ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items
          .map(
            (item) => SizedBox(
              width: _cardWidth(context, items.length),
              child: _InfoCard(item: item),
            ),
          )
          .toList(),
    );
  }

  double _cardWidth(BuildContext context, int count) {
    final available =
        MediaQuery.of(context).size.width - 220 - 64 - 16; // sidebar + padding
    if (available > 700) return (available - 16) / 2;
    return available;
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
}

class _InfoCard extends StatefulWidget {
  final _InfoItem item;
  const _InfoCard({required this.item});

  @override
  State<_InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<_InfoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered
                ? item.accent.withValues(alpha: 0.3)
                : Colors.grey.shade100,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? item.accent.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: _hovered ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon container
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: _hovered ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(item.icon, size: 22, color: item.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade400,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textD,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            // Accent dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: _hovered ? 1.0 : 0.3),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
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
