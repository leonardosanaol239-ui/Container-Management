import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/port.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/port_selection_dialog.dart';
import '../widgets/notification_panel.dart';
import 'landing_screen.dart';
import 'account_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
// Gothong Southern Brand Colors
// PRIMARY:  Lincoln Green #0B560D | Scarlet Red #FF2800 | Canary Yellow #FFF200
// SECONDARY: Live Green #98F29B   | Smiley Red #E0474C  | Cyber Yellow #FFD300
class _C {
  // Backgrounds & surfaces
  static const bg = Color(0xFFF0F2EE);
  static const surface = Color(0xFFFFFFFF);

  // Navigation (dark green tones derived from Lincoln Green)
  static const navBg = Color(0xFF0B3D0F);
  static const navBg2 = Color(0xFF0D4A12);

  // PRIMARY palette
  static const lincolnGreen = Color(0xFF0B560D); // Pantone Lincoln Green
  static const scarletRed = Color(0xFFFF2800); // Pantone Scarlet Red
  static const canaryYellow = Color(0xFFFFF200); // Pantone Canary Yellow

  // SECONDARY palette
  static const liveGreen = Color(0xFF98F29B); // Pantone Live Green
  static const smileRed = Color(0xFFE0474C); // Pantone Smiley Red
  static const cyberYellow = Color(0xFFFFD300); // Pantone Cyber Yellow

  // Aliases kept for backward compatibility
  static const emerald = lincolnGreen;
  static const emeraldL = liveGreen;
  static const gold = cyberYellow;
  static const goldD = Color(0xFFCCA900);
  static const red = scarletRed;

  // Accent / semantic
  static const blue = Color(0xFF1565C0);
  static const orange = Color(0xFFE65100);
  static const purple = Color(0xFF6A1B9A);
  static const teal = Color(0xFF00695C);

  // Text
  static const textD = Color(0xFF1A1A0A);
  static const textM = Color(0xFF4A4A4A);
  static const textL = Color(0xFF757575);

  // Utility
  static const border = Color(0xFFE8EAE4);
  static const shadow = Color(0x0A000000);
}

// ── DashboardScreen ───────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  final Session session;
  const DashboardScreen({super.key, required this.session});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  int _total = 0, _laden = 0, _empty = 0, _ports = 0;
  int _mtFood = 0, _fsl = 0, _stripping = 0, _mtNonFood = 0;
  int _inTransit = 0, _movedOut = 0;
  bool _loading = true;
  List<ContainerModel> _inYard = [];
  List<Port> _portList = [];
  int _navIndex = 0;
  bool _collapsed = false;
  late AnimationController _statsAnim;
  late AnimationController _pulseAnim;
  Timer? _clock;
  Timer? _pollTimer;
  DateTime _now = DateTime.now();

  static const _nav = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
    {'icon': Icons.anchor_rounded, 'label': 'Ports'},
    {'icon': Icons.bar_chart_rounded, 'label': 'Analytics'},
    {'icon': Icons.summarize_rounded, 'label': 'Reports'},
    {'icon': Icons.notifications_rounded, 'label': 'Notifications'},
    {'icon': Icons.settings_rounded, 'label': 'Settings'},
  ];

  @override
  void initState() {
    super.initState();
    NotificationService().init();
    NotificationService().setSession(widget.session.fullName);
    _statsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadStats();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Auto-refresh every 5 s — keeps dashboard in sync with movements
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _silentRefresh();
    });
  }

  @override
  void dispose() {
    _statsAnim.dispose();
    _pulseAnim.dispose();
    _clock?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final portList = await _api.getPorts();
      List<ContainerModel> all = [];
      for (final p in portList) {
        all.addAll(await _api.getContainersByPort(p.portId));
      }
      final inYard = all.where((c) => !c.isMovedOut).toList();
      setState(() {
        _total = inYard.length;
        _laden = inYard.where((c) => c.statusId == 1).length;
        _empty = inYard.where((c) => c.statusId == 2).length;
        _ports = portList.length;
        _mtFood = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'food' ||
              d.startsWith('food —') ||
              d.startsWith('food -');
        }).length;
        _fsl = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'fsl' || d.startsWith('fsl —') || d.startsWith('fsl -');
        }).length;
        _stripping = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'stripping' || d.startsWith('stripping —');
        }).length;
        _mtNonFood = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'non-food' ||
              d.startsWith('non-food —') ||
              d.contains('non food');
        }).length;
        _inTransit = inYard.where((c) => c.locationStatusId == 3).length;
        _movedOut = all.where((c) => c.isMovedOut).length;
        _inYard = inYard;
        _portList = portList;
        _loading = false;
      });
      _statsAnim.forward(from: 0);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // Silent refresh — updates data without showing the loading spinner.
  // Called every 5 s by the poll timer so movements reflect in real-time.
  Future<void> _silentRefresh() async {
    try {
      final portList = await _api.getPorts();
      List<ContainerModel> all = [];
      for (final p in portList) {
        all.addAll(await _api.getContainersByPort(p.portId));
      }
      final inYard = all.where((c) => !c.isMovedOut).toList();
      if (!mounted) return;
      setState(() {
        _total = inYard.length;
        _laden = inYard.where((c) => c.statusId == 1).length;
        _empty = inYard.where((c) => c.statusId == 2).length;
        _ports = portList.length;
        _mtFood = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'food' ||
              d.startsWith('food —') ||
              d.startsWith('food -');
        }).length;
        _fsl = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'fsl' || d.startsWith('fsl —') || d.startsWith('fsl -');
        }).length;
        _stripping = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'stripping' || d.startsWith('stripping —');
        }).length;
        _mtNonFood = inYard.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'non-food' ||
              d.startsWith('non-food —') ||
              d.contains('non food');
        }).length;
        _inTransit = inYard.where((c) => c.locationStatusId == 3).length;
        _movedOut = all.where((c) => c.isMovedOut).length;
        _inYard = inYard;
        _portList = portList;
      });
    } catch (_) {
      // Silently ignore network errors during background refresh
    }
  }

  String get _timeStr {
    final h = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return '$h:$m:$s ${_now.hour < 12 ? "AM" : "PM"}';
  }

  String get _dateStr {
    const mo = [
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
    const dy = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${dy[_now.weekday - 1]}, ${mo[_now.month - 1]} ${_now.day}, ${_now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Row(
        children: [
          _Sidebar(
            items: _nav,
            activeIndex: _navIndex,
            collapsed: _collapsed,
            onSelect: (i) {
              setState(() => _navIndex = i);
            },
            onToggle: () => setState(() => _collapsed = !_collapsed),
            onLogout: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LandingScreen()),
              (_) => false,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _TopNav(
                  session: widget.session,
                  timeStr: _timeStr,
                  dateStr: _dateStr,
                  pulseAnim: _pulseAnim,
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Switch between different pages based on nav index
    switch (_navIndex) {
      case 0: // Dashboard
        return _buildDashboardPage();
      case 1: // Ports
        return _buildPortsPage();
      case 2: // Analytics
        return _buildAnalyticsPage();
      case 3: // Reports
        return _buildReportsPage();
      case 4: // Notifications
        return _buildNotificationsPage();
      case 5: // Settings
        return _buildSettingsPage();
      default:
        return _buildDashboardPage();
    }
  }

  Widget _buildDashboardPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WelcomeBanner(
            session: widget.session,
            onRefresh: _loadStats,
            loading: _loading,
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'OVERVIEW',
            icon: Icons.analytics_rounded,
            color: _C.emerald,
          ),
          const SizedBox(height: 14),
          _loading ? _SkeletonRow(6) : _buildStatCards(),
          const SizedBox(height: 20),
          _loading ? _SkeletonRow(4) : _buildTypeCards(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _DonutCard(laden: _laden, empty: _empty, total: _total),
                    const SizedBox(height: 20),
                    _OccupancyCard(
                      laden: _laden,
                      empty: _empty,
                      mtFood: _mtFood,
                      fsl: _fsl,
                      stripping: _stripping,
                      mtNonFood: _mtNonFood,
                      total: _total,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Column(children: [_ActivityCard(containers: _inYard)]),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'PORT ACTIVITY',
            icon: Icons.anchor_rounded,
            color: _C.blue,
          ),
          const SizedBox(height: 14),
          _PortLeaderboard(portList: _portList, containers: _inYard),
          const SizedBox(height: 16),
          _Footer(year: _now.year),
        ],
      ),
    );
  }

  Widget _buildPortsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'PORT MANAGEMENT',
            icon: Icons.anchor_rounded,
            color: _C.blue,
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => PortSelectionDialog(session: widget.session),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Manage Ports'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.emerald,
                foregroundColor: _C.gold,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'ANALYTICS',
            icon: Icons.bar_chart_rounded,
            color: _C.purple,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Analytics page coming soon',
              style: TextStyle(color: _C.textL, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'REPORTS',
            icon: Icons.summarize_rounded,
            color: _C.orange,
          ),
          const SizedBox(height: 24),
          _ReportsPageContent(containers: _inYard, portList: _portList),
        ],
      ),
    );
  }

  Widget _buildNotificationsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'NOTIFICATIONS',
            icon: Icons.notifications_rounded,
            color: _C.emerald,
          ),
          const SizedBox(height: 24),
          const _NotificationsPageContent(),
        ],
      ),
    );
  }

  Widget _buildSettingsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'SETTINGS',
            icon: Icons.settings_rounded,
            color: _C.textM,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Settings page coming soon',
              style: TextStyle(color: _C.textL, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final cards = [
      (
        label: 'Total Containers',
        value: '$_total',
        icon: Icons.inventory_2_rounded,
        color: _C.emerald,
        sub: 'In yard',
        trend: '+2.4%',
        up: true,
        dark: false,
        filter: 'all',
      ),
      (
        label: 'Laden',
        value: '$_laden',
        icon: Icons.check_circle_rounded,
        color: _C.gold,
        sub: 'Loaded',
        trend: '+1.1%',
        up: true,
        dark: true,
        filter: 'laden',
      ),
      (
        label: 'Empty',
        value: '$_empty',
        icon: Icons.radio_button_unchecked_rounded,
        color: _C.red,
        sub: 'Available',
        trend: '-0.8%',
        up: false,
        dark: false,
        filter: 'empty',
      ),
      (
        label: 'Active Ports',
        value: '$_ports',
        icon: Icons.anchor_rounded,
        color: _C.blue,
        sub: 'Operational',
        trend: 'Stable',
        up: true,
        dark: false,
        filter: '',
      ),
      (
        label: 'In Transit',
        value: '$_inTransit',
        icon: Icons.local_shipping_rounded,
        color: _C.orange,
        sub: 'Move requests',
        trend: '+3.2%',
        up: true,
        dark: false,
        filter: '',
      ),
      (
        label: 'Moved Out',
        value: '$_movedOut',
        icon: Icons.exit_to_app_rounded,
        color: _C.teal,
        sub: 'Dispatched',
        trend: '+5.0%',
        up: true,
        dark: false,
        filter: '',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: cards.asMap().entries.map((e) {
            final c = e.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: e.key < cards.length - 1 ? 14 : 0,
                ),
                child: _StatCard(
                  label: c.label,
                  value: c.value,
                  icon: c.icon,
                  color: c.color,
                  subtitle: c.sub,
                  trend: c.trend,
                  trendUp: c.up,
                  textDark: c.dark,
                  anim: _statsAnim,
                  delay: e.key * 0.1,
                  onTap: c.filter.isNotEmpty ? () => _showList(c.filter) : null,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTypeCards() {
    final types = [
      (
        label: 'MT Food',
        value: '$_mtFood',
        color: _C.emeraldL,
        icon: Icons.restaurant_rounded,
      ),
      (
        label: 'FSL',
        value: '$_fsl',
        color: _C.blue,
        icon: Icons.inventory_2_rounded,
      ),
      (
        label: 'Stripping',
        value: '$_stripping',
        color: _C.orange,
        icon: Icons.content_cut_rounded,
      ),
      (
        label: 'MT Non-Food',
        value: '$_mtNonFood',
        color: _C.purple,
        icon: Icons.no_food_rounded,
      ),
    ];
    return Row(
      children: types.asMap().entries.map((e) {
        final t = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: e.key < types.length - 1 ? 14 : 0),
            child: _TypeCard(
              label: t.label,
              value: t.value,
              color: t.color,
              icon: t.icon,
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showList(String filter) {
    final filtered = filter == 'laden'
        ? _inYard.where((c) => c.statusId == 1).toList()
        : filter == 'empty'
        ? _inYard.where((c) => c.statusId == 2).toList()
        : _inYard;
    final title = filter == 'laden'
        ? 'Laden Containers'
        : filter == 'empty'
        ? 'Empty Containers'
        : 'All Containers';
    final accent = filter == 'laden'
        ? _C.gold
        : filter == 'empty'
        ? _C.red
        : _C.emerald;
    showDialog(
      context: context,
      builder: (_) =>
          _ListDialog(title: title, containers: filtered, accent: accent),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int activeIndex;
  final bool collapsed;
  final void Function(int) onSelect;
  final VoidCallback onToggle, onLogout;
  const _Sidebar({
    required this.items,
    required this.activeIndex,
    required this.collapsed,
    required this.onSelect,
    required this.onToggle,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      width: collapsed ? 68 : 236,
      decoration: const BoxDecoration(
        color: _C.navBg,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo
          Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Image.asset(
                        'assets/gothong_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'GOTHONG',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'SOUTHERN',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 8,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: List.generate(
                items.length,
                (i) => _NavItem(
                  icon: items[i]['icon'] as IconData,
                  label: items[i]['label'] as String,
                  active: activeIndex == i,
                  collapsed: collapsed,
                  showBadge: i == 4, // Show badge for Notifications (index 4)
                  onTap: () => onSelect(i),
                ),
              ),
            ),
          ),
          // Bottom
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Column(
              children: [
                _NavItem(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  active: false,
                  collapsed: collapsed,
                  color: _C.red,
                  showBadge: false,
                  onTap: onLogout,
                ),
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    child: AnimatedRotation(
                      turns: collapsed ? 0 : 0.5,
                      duration: const Duration(milliseconds: 260),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white.withOpacity(0.35),
                        size: 18,
                      ),
                    ),
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

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active, collapsed;
  final bool showBadge;
  final Color? color;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.collapsed,
    required this.onTap,
    this.color,
    this.showBadge = false,
  });
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _h = false;

  @override
  void initState() {
    super.initState();
    if (widget.showBadge) {
      NotificationService().addListener(_onNotifChanged);
    }
  }

  @override
  void dispose() {
    if (widget.showBadge) {
      NotificationService().removeListener(_onNotifChanged);
    }
    super.dispose();
  }

  void _onNotifChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? (widget.active ? Colors.white : Colors.white);
    final unreadCount = widget.showBadge
        ? NotificationService().unreadCount
        : 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: widget.collapsed ? 0 : 12,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: widget.active
                ? Colors.white.withValues(alpha: 0.13)
                : _h
                ? Colors.white.withOpacity(0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: widget.active
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  )
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: widget.collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (widget.active && !widget.collapsed)
                    Container(
                      width: 3,
                      height: 16,
                      margin: const EdgeInsets.only(right: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Icon(widget.icon, color: c, size: 17),
                  if (!widget.collapsed) ...[
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: c,
                          fontSize: 12.5,
                          fontWeight: widget.active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Badge indicator
              if (widget.showBadge && unreadCount > 0)
                Positioned(
                  top: widget.collapsed ? -4 : 0,
                  right: widget.collapsed ? -4 : 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    decoration: BoxDecoration(
                      color: _C.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.navBg, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _C.red.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
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

// ── Top Nav ───────────────────────────────────────────────────────────────────
class _TopNav extends StatelessWidget {
  final Session session;
  final String timeStr, dateStr;
  final AnimationController pulseAnim;
  const _TopNav({
    required this.session,
    required this.timeStr,
    required this.dateStr,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _C.textD,
                ),
              ),
              Text(
                'Container Management System',
                style: TextStyle(fontSize: 10, color: _C.textL),
              ),
            ],
          ),
          const Spacer(),
          // Clock
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _C.textD,
                  ),
                ),
                Text(dateStr, style: TextStyle(fontSize: 8.5, color: _C.textL)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ProfileBtn(session: session),
        ],
      ),
    );
  }
}

// ── Profile Button ────────────────────────────────────────────────────────────
class _ProfileBtn extends StatefulWidget {
  final Session session;
  const _ProfileBtn({required this.session});
  @override
  State<_ProfileBtn> createState() => _ProfileBtnState();
}

class _ProfileBtnState extends State<_ProfileBtn> {
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
      builder: (_) => _ProfileDropdown(
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
              builder: (_) => AccountScreen(
                session: widget.session,
                isAdmin: widget.session.isAdmin,
              ),
            ),
          );
        },
        onLogout: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LandingScreen()),
          (_) => false,
        ),
      ),
    );
    Overlay.of(context).insert(_ov!);
    setState(() => _h = true);
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
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _h ? _C.bg : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _h ? _C.border : Colors.transparent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: _C.lincolnGreen,
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
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.session.fullName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _C.textD,
                      ),
                    ),
                    Text(
                      widget.session.role,
                      style: const TextStyle(fontSize: 9.5, color: _C.textL),
                    ),
                  ],
                ),
                const SizedBox(width: 3),
                AnimatedRotation(
                  turns: _h ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: _C.textL,
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

// ── Profile Dropdown ──────────────────────────────────────────────────────────
class _ProfileDropdown extends StatefulWidget {
  final LayerLink link;
  final String initials;
  final Session session;
  final ValueNotifier<bool> inMenu;
  final VoidCallback onHide, onScheduleHide, onLogout;
  final VoidCallback onProfile;
  const _ProfileDropdown({
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
  State<_ProfileDropdown> createState() => _ProfileDropdownState();
}

class _ProfileDropdownState extends State<_ProfileDropdown> {
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
                    color: Colors.black.withOpacity(0.13),
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
                      color: _C.emerald,
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
                            color: _C.lincolnGreen,
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
                    color: _C.red,
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
    this.color = _C.textD,
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
            color: _h ? widget.color.withOpacity(0.07) : Colors.transparent,
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

// ── Welcome Banner ────────────────────────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  final Session session;
  final VoidCallback onRefresh;
  final bool loading;
  const _WelcomeBanner({
    required this.session,
    required this.onRefresh,
    required this.loading,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.navBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/gothong_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${session.fullName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Gothong Southern Container Management',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Refresh button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                    const SizedBox(width: 7),
                    const Text(
                      'Refresh',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _C.textD,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: _C.border)),
      ],
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────
class _SkeletonRow extends StatelessWidget {
  final int count;
  const _SkeletonRow(this.count);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        count,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < count - 1 ? 14 : 0),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade200,
                    Colors.grey.shade100,
                    Colors.grey.shade200,
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatefulWidget {
  final String label, value, subtitle, trend;
  final IconData icon;
  final Color color;
  final bool trendUp, textDark;
  final AnimationController anim;
  final double delay;
  final VoidCallback? onTap;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.trend,
    required this.trendUp,
    required this.textDark,
    required this.anim,
    required this.delay,
    this.onTap,
  });
  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final tc = widget.textDark ? _C.textD : Colors.white;
    return AnimatedBuilder(
      animation: widget.anim,
      builder: (_, child) {
        final t = ((widget.anim.value - widget.delay) / (1 - widget.delay))
            .clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(18),
            transform: Matrix4.translationValues(0, _h ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 4,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: _h ? 0.25 : 0.10),
                  blurRadius: _h ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, color: tc, size: 20),
                    ),
                    if (widget.trend.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.trendUp
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: tc,
                              size: 11,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.trend,
                              style: TextStyle(
                                color: tc,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.value,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: tc,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tc.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: TextStyle(fontSize: 10, color: tc.withOpacity(0.65)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Type Card ─────────────────────────────────────────────────────────────────
class _TypeCard extends StatefulWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _TypeCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  @override
  State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        transform: Matrix4.translationValues(0, _h ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _h ? widget.color.withOpacity(0.4) : _C.border,
          ),
          boxShadow: [
            BoxShadow(
              color: _h ? widget.color.withOpacity(0.12) : _C.shadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: widget.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: widget.color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _C.textM,
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

// ── Donut Chart Card ──────────────────────────────────────────────────────────
class _DonutCard extends StatelessWidget {
  final int laden, empty, total;
  const _DonutCard({
    required this.laden,
    required this.empty,
    required this.total,
  });
  @override
  Widget build(BuildContext context) {
    final ladenPct = total > 0 ? laden / total : 0.0;
    final emptyPct = total > 0 ? empty / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.donut_large_rounded,
                color: _C.emerald,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Container Distribution',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.textD,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Total: $total',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _C.textM,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _DonutPainter(
                    ladenPct: ladenPct,
                    emptyPct: emptyPct,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _C.textD,
                          ),
                        ),
                        const Text(
                          'Total',
                          style: TextStyle(fontSize: 10, color: _C.textL),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _DonutLegend(
                      color: _C.gold,
                      label: 'Laden',
                      value: laden,
                      pct: (ladenPct * 100).round(),
                    ),
                    const SizedBox(height: 10),
                    _DonutLegend(
                      color: _C.red,
                      label: 'Empty',
                      value: empty,
                      pct: (emptyPct * 100).round(),
                    ),
                    const SizedBox(height: 10),
                    _DonutLegend(
                      color: _C.border,
                      label: 'Other',
                      value: total - laden - empty,
                      pct: total > 0
                          ? (((total - laden - empty) / total) * 100).round()
                          : 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int value, pct;
  const _DonutLegend({
    required this.color,
    required this.label,
    required this.value,
    required this.pct,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _C.textM,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _C.textD,
          ),
        ),
        const SizedBox(width: 6),
        Text('$pct%', style: TextStyle(fontSize: 10, color: _C.textL)),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double ladenPct, emptyPct;
  const _DonutPainter({required this.ladenPct, required this.emptyPct});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = size.width / 2 - 10;
    final stroke = 18.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    // Background
    paint.color = _C.border;
    canvas.drawCircle(Offset(cx, cy), r, paint);
    // Laden arc
    paint.color = _C.gold;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * ladenPct,
      false,
      paint,
    );
    // Empty arc
    paint.color = _C.red;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2 + 2 * math.pi * ladenPct,
      2 * math.pi * emptyPct,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter o) =>
      o.ladenPct != ladenPct || o.emptyPct != emptyPct;
}

// ── Occupancy Card ────────────────────────────────────────────────────────────
class _OccupancyCard extends StatelessWidget {
  final int laden, empty, mtFood, fsl, stripping, mtNonFood, total;
  const _OccupancyCard({
    required this.laden,
    required this.empty,
    required this.mtFood,
    required this.fsl,
    required this.stripping,
    required this.mtNonFood,
    required this.total,
  });
  @override
  Widget build(BuildContext context) {
    final bars = [
      (
        label: 'Laden',
        value: laden,
        color: _C.gold,
        icon: Icons.check_circle_rounded,
      ),
      (
        label: 'Empty',
        value: empty,
        color: _C.red,
        icon: Icons.radio_button_unchecked_rounded,
      ),
      (
        label: 'MT Food',
        value: mtFood,
        color: _C.emeraldL,
        icon: Icons.restaurant_rounded,
      ),
      (
        label: 'FSL',
        value: fsl,
        color: _C.blue,
        icon: Icons.inventory_2_rounded,
      ),
      (
        label: 'Stripping',
        value: stripping,
        color: _C.orange,
        icon: Icons.content_cut_rounded,
      ),
      (
        label: 'MT Non-Food',
        value: mtNonFood,
        color: _C.purple,
        icon: Icons.no_food_rounded,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: _C.blue, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Yard Occupancy by Type',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.textD,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...bars.map((b) {
            final pct = total > 0 ? b.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(b.icon, color: b.color, size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          b.label,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _C.textM,
                          ),
                        ),
                      ),
                      Text(
                        '${b.value}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: b.color,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${(pct * 100).round()}%',
                        style: const TextStyle(fontSize: 10, color: _C.textL),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: b.color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(b.color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Recent Activity Card ──────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final List<ContainerModel> containers;
  const _ActivityCard({required this.containers});
  @override
  Widget build(BuildContext context) {
    // Show last 6 containers sorted by createdDate desc
    final recent = [...containers]
      ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
    final shown = recent.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: _C.orange, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Recent Containers',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _C.textD,
                ),
              ),
              const Spacer(),
              Text(
                '${containers.length} total',
                style: const TextStyle(fontSize: 10.5, color: _C.textL),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No containers',
                  style: TextStyle(color: _C.textL, fontSize: 12),
                ),
              ),
            )
          else
            ...shown.map((c) {
              final isLaden = c.statusId == 1;
              final color = isLaden ? _C.gold : _C.red;
              final desc = c.containerDesc ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.containerNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _C.textD,
                            ),
                          ),
                          if (desc.isNotEmpty)
                            Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _C.textL,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isLaden ? 'Laden' : 'Empty',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── Port Leaderboard ──────────────────────────────────────────────────────────
class _PortLeaderboard extends StatelessWidget {
  final List<Port> portList;
  final List<ContainerModel> containers;
  const _PortLeaderboard({required this.portList, required this.containers});
  @override
  Widget build(BuildContext context) {
    if (portList.isEmpty) return const SizedBox.shrink();
    final data = portList.map((p) {
      final pc = containers.where((c) => c.currentPortId == p.portId).toList();
      return (
        port: p,
        total: pc.length,
        laden: pc.where((c) => c.statusId == 1).length,
        empty: pc.where((c) => c.statusId == 2).length,
      );
    }).toList()..sort((a, b) => b.total.compareTo(a.total));
    final maxTotal = data.isEmpty ? 1 : data.first.total.clamp(1, 999999);
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _C.navBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 28),
                const Expanded(
                  flex: 3,
                  child: Text(
                    'PORT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'LADEN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'EMPTY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'OCCUPANCY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...data.asMap().entries.map((e) {
            final i = e.key;
            final d = e.value;
            final pct = d.total / maxTotal;
            final rankColor = i == 0
                ? _C.gold
                : i == 1
                ? Colors.grey.shade400
                : i == 2
                ? const Color(0xFFCD7F32)
                : _C.textL;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: i.isEven ? _C.surface : _C.bg,
                borderRadius: i == data.length - 1
                    ? const BorderRadius.vertical(bottom: Radius.circular(18))
                    : null,
                border: Border(
                  bottom: BorderSide(
                    color: _C.border,
                    width: i < data.length - 1 ? 1 : 0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: rankColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _C.emerald.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.anchor_rounded,
                            color: _C.emerald,
                            size: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.port.portDesc,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _C.textD,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${d.total}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _C.textD,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${d.laden}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _C.gold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${d.empty}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _C.red,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 7,
                              backgroundColor: _C.emerald.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation(
                                _C.emerald,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '${(pct * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: _C.textL,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Container Table ───────────────────────────────────────────────────────────
class _ContainerTable extends StatefulWidget {
  final List<ContainerModel> containers;
  final List<Port> portList;
  const _ContainerTable({required this.containers, required this.portList});
  @override
  State<_ContainerTable> createState() => _ContainerTableState();
}

class _ContainerTableState extends State<_ContainerTable> {
  String _search = '';
  String _statusFilter = 'all';
  int _page = 0;
  static const _perPage = 10;

  List<ContainerModel> get _filtered {
    var list = widget.containers;
    if (_statusFilter == 'laden') {
      list = list.where((c) => c.statusId == 1).toList();
    }
    if (_statusFilter == 'empty') {
      list = list.where((c) => c.statusId == 2).toList();
    }
    if (_search.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.containerNumber.toLowerCase().contains(_search.toLowerCase()),
          )
          .toList();
    }
    return list;
  }

  String _portName(int portId) {
    try {
      return widget.portList.firstWhere((p) => p.portId == portId).portDesc;
    } catch (_) {
      return 'Port $portId';
    }
  }

  String _fmt(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pages = (filtered.length / _perPage).ceil().clamp(1, 9999);
    final start = _page * _perPage;
    final pageItems = filtered.skip(start).take(_perPage).toList();

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: _C.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border(bottom: BorderSide(color: _C.border)),
            ),
            child: Row(
              children: [
                // Search
                Container(
                  width: 220,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _C.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _C.border),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.search_rounded,
                        size: 14,
                        color: _C.textL,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() {
                            _search = v;
                            _page = 0;
                          }),
                          style: const TextStyle(fontSize: 12, color: _C.textD),
                          decoration: InputDecoration(
                            hintText: 'Search by container no…',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              color: _C.textL,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Filter chips
                ...[('all', 'All'), ('laden', 'Laden'), ('empty', 'Empty')].map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _statusFilter = f.$1;
                        _page = 0;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusFilter == f.$1
                              ? _C.emerald
                              : _C.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _statusFilter == f.$1
                                ? _C.emerald
                                : _C.border,
                          ),
                        ),
                        child: Text(
                          f.$2,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _statusFilter == f.$1
                                ? Colors.white
                                : _C.textM,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} records',
                  style: const TextStyle(fontSize: 11, color: _C.textL),
                ),
              ],
            ),
          ),
          // Header
          Container(
            color: _C.navBg,
            child: _TableRow(
              cells: const [
                '#',
                'CONTAINER NO.',
                'STATUS',
                'SIZE',
                'TYPE',
                'PORT',
                'DATE IN YARD',
                'DAYS IN YARD',
              ],
              isHeader: true,
            ),
          ),
          // Rows
          if (pageItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No containers found',
                  style: TextStyle(color: _C.textL, fontSize: 13),
                ),
              ),
            )
          else
            ...pageItems.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              final isLaden = c.statusId == 1;
              final days = c.yardEntryDate != null
                  ? DateTime.now()
                        .difference(
                          DateTime.tryParse(c.yardEntryDate!) ?? DateTime.now(),
                        )
                        .inDays
                  : 0;
              return _TableRow(
                bg: i.isEven ? _C.surface : _C.bg,
                isLast: i == pageItems.length - 1,
                cells: [
                  '${start + i + 1}',
                  c.containerNumber,
                  isLaden ? 'Laden' : 'Empty',
                  c.containerSizeId == 1
                      ? '20ft'
                      : c.containerSizeId == 2
                      ? '40ft'
                      : '—',
                  c.containerDesc ?? '—',
                  _portName(c.currentPortId),
                  _fmt(c.yardEntryDate),
                  '$days days',
                ],
                statusIndex: 2,
                isLaden: isLaden,
              );
            }),
          // Pagination
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
              border: Border(top: BorderSide(color: _C.border)),
            ),
            child: Row(
              children: [
                Text(
                  'Page ${_page + 1} of $pages',
                  style: const TextStyle(fontSize: 11, color: _C.textL),
                ),
                const Spacer(),
                ...[
                  Icons.first_page_rounded,
                  Icons.chevron_left_rounded,
                  Icons.chevron_right_rounded,
                  Icons.last_page_rounded,
                ].asMap().entries.map((e) {
                  final enabled = e.key < 2 ? _page > 0 : _page < pages - 1;
                  return GestureDetector(
                    onTap: enabled
                        ? () => setState(() {
                            if (e.key == 0) {
                              _page = 0;
                            } else if (e.key == 1)
                              _page--;
                            else if (e.key == 2)
                              _page++;
                            else
                              _page = pages - 1;
                          })
                        : null,
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: enabled ? _C.surface : _C.bg,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _C.border),
                      ),
                      child: Icon(
                        e.value,
                        size: 14,
                        color: enabled ? _C.textD : _C.textL,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  final List<String> cells;
  final bool isHeader;
  final Color? bg;
  final bool isLast;
  final int statusIndex;
  final bool? isLaden;
  const _TableRow({
    required this.cells,
    this.isHeader = false,
    this.bg,
    this.isLast = false,
    this.statusIndex = -1,
    this.isLaden,
  });
  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (!widget.isHeader) setState(() => _h = true);
      },
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: widget.isHeader
            ? Colors.transparent
            : _h
            ? _C.emerald.withOpacity(0.04)
            : (widget.bg ?? _C.surface),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: widget.cells.asMap().entries.map((e) {
              final isStatus = e.key == widget.statusIndex;
              final flex = e.key == 1
                  ? 2
                  : e.key == 4
                  ? 2
                  : e.key == 5
                  ? 2
                  : 1;
              Widget cell;
              if (widget.isHeader) {
                cell = Text(
                  e.value,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                );
              } else if (isStatus) {
                final isLaden = widget.isLaden ?? false;
                cell = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (isLaden ? _C.gold : _C.red).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isLaden ? _C.goldD : _C.red,
                    ),
                  ),
                );
              } else {
                cell = Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: e.key == 0 ? _C.textL : _C.textD,
                    fontWeight: e.key == 1 ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              }
              return Expanded(flex: flex, child: cell);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  final int year;
  const _Footer({required this.year});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: _C.navBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _C.gold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/gothong_logo.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Gothong Southern  ·  Container Management System  ·  v1.0.0',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '© $year All rights reserved',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Container List Dialog ─────────────────────────────────────────────────────
class _ListDialog extends StatelessWidget {
  final String title;
  final List<ContainerModel> containers;
  final Color accent;
  const _ListDialog({
    required this.title,
    required this.containers,
    required this.accent,
  });
  @override
  Widget build(BuildContext context) {
    final laden = containers.where((c) => c.statusId == 1).length;
    final empty = containers.where((c) => c.statusId == 2).length;
    final ft20 = containers.where((c) => c.containerSizeId == 1).length;
    final ft40 = containers.where((c) => c.containerSizeId == 2).length;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: accent == _C.gold ? _C.textD : Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: accent == _C.gold ? _C.textD : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${containers.length} containers',
                          style: TextStyle(
                            color: (accent == _C.gold ? _C.textD : Colors.white)
                                .withOpacity(0.65),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      color: accent == _C.gold ? _C.textD : Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            // Stats
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _MiniStat('Laden', '$laden', _C.gold),
                  const SizedBox(width: 10),
                  _MiniStat('Empty', '$empty', _C.red),
                  const SizedBox(width: 10),
                  _MiniStat('20ft', '$ft20', _C.emerald),
                  const SizedBox(width: 10),
                  _MiniStat('40ft', '$ft40', _C.blue),
                ],
              ),
            ),
            // List
            Flexible(
              child: containers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'No containers found',
                        style: TextStyle(color: _C.textL, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: containers.length,
                      itemBuilder: (_, i) {
                        final c = containers[i];
                        final isLaden = c.statusId == 1;
                        final sc = isLaden ? _C.gold : _C.red;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: sc.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: sc.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: sc,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  c.containerNumber,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _C.textD,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: sc.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isLaden ? 'Laden' : 'Empty',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: sc,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _C.emerald.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c.containerSizeId == 1
                                      ? '20ft'
                                      : c.containerSizeId == 2
                                      ? '40ft'
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: _C.emerald,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: _C.textL,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Report Dialog ─────────────────────────────────────────────────────────────
class _ReportDialog extends StatefulWidget {
  final List<ContainerModel> containers;
  final List<Port> portList;
  const _ReportDialog({required this.containers, required this.portList});
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _fmt(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  String _days(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.now().difference(DateTime.parse(iso)).inDays;
      return '$d day${d != 1 ? "s" : ""}';
    } catch (_) {
      return '—';
    }
  }

  List<ContainerModel> _filter(String type) {
    final all = widget.containers;
    switch (type) {
      case 'laden':
        return all.where((c) => c.statusId == 1).toList();
      case 'empty':
        return all.where((c) => c.statusId == 2).toList();
      case 'mtfood':
        return all.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'food' ||
              d.startsWith('food —') ||
              d.startsWith('food -');
        }).toList();
      case 'fsl':
        return all.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'fsl' || d.startsWith('fsl —');
        }).toList();
      case 'strip':
        return all.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'stripping' || d.startsWith('stripping —');
        }).toList();
      case 'nonfood':
        return all.where((c) {
          final d = c.containerDesc?.toLowerCase() ?? '';
          return d == 'non-food' ||
              d.startsWith('non-food —') ||
              d.contains('non food');
        }).toList();
      default:
        return all;
    }
  }

  Future<void> _print(BuildContext ctx) async {
    final all = widget.containers;
    final laden = _filter('laden');
    final empty = _filter('empty');
    final mtFood = _filter('mtfood');
    final fsl = _filter('fsl');
    final strip = _filter('strip');
    final nonFood = _filter('nonfood');
    final dateStr = _fmt(DateTime.now().toIso8601String());
    final pdf = pw.Document();

    pw.Widget hdr() => pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(color: PdfColors.grey900),
      child: pw.Column(
        children: [
          pw.Text(
            'GOTHONG SOUTHERN — CONTAINER REPORT',
            style: pw.TextStyle(
              color: PdfColors.yellow,
              fontWeight: pw.FontWeight.bold,
              fontSize: 13,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Date: $dateStr',
            style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 9),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              for (final s in [
                ('Total', '${all.length}', PdfColors.green800),
                ('Laden', '${laden.length}', PdfColors.yellow800),
                ('MT Food', '${mtFood.length}', PdfColors.green700),
                ('FSL', '${fsl.length}', PdfColors.blue800),
                ('Stripping', '${strip.length}', PdfColors.orange800),
                ('MT Non-Food', '${nonFood.length}', PdfColors.purple800),
                ('Empty', '${empty.length}', PdfColors.red700),
                ('Ports', '${widget.portList.length}', PdfColors.blueGrey700),
              ]) ...[
                pw.Expanded(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.only(right: 4),
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: s.$3,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Text(
                          s.$2,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.Text(
                          s.$1,
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    pw.Widget tblHdr(List<String> cols) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 7),
      color: PdfColors.grey800,
      child: pw.Row(
        children: cols
            .map(
              (c) => pw.Expanded(
                child: pw.Text(
                  c,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );

    pw.Widget tblRow(int i, ContainerModel c) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 7),
      color: i.isEven ? PdfColors.grey100 : PdfColors.white,
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              c.containerNumber,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              c.statusId == 1 ? 'Laden' : 'Empty',
              style: pw.TextStyle(
                fontSize: 8,
                color: c.statusId == 1 ? PdfColors.yellow800 : PdfColors.red700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              c.containerSizeId == 1
                  ? '20ft'
                  : c.containerSizeId == 2
                  ? '40ft'
                  : '—',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _fmt(c.yardEntryDate),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _days(c.yardEntryDate),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _fmt(c.moveConfirmedDate ?? c.createdDate),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _days(c.moveConfirmedDate ?? c.createdDate),
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ],
      ),
    );

    final cols = [
      'CONTAINER NO.',
      'STATUS',
      'SIZE',
      'DATE IN YARD',
      'DAYS IN YARD',
      'DATE MOVED',
      'DAYS IN SLOT',
    ];
    for (final s in [
      ('ALL CONTAINERS', all),
      ('LADEN', laden),
      ('MT FOOD', mtFood),
      ('FSL', fsl),
      ('STRIPPING', strip),
      ('MT NON-FOOD', nonFood),
      ('EMPTY', empty),
    ]) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(22),
          header: (_) => hdr(),
          build: (_) => [
            pw.SizedBox(height: 10),
            pw.Text(
              '${s.$1} (${s.$2.length})',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.SizedBox(height: 5),
            tblHdr(cols),
            ...s.$2.asMap().entries.map((e) => tblRow(e.key, e.value)),
          ],
        ),
      );
    }
    // Ports page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        header: (_) => hdr(),
        build: (_) => [
          pw.SizedBox(height: 10),
          pw.Text(
            'PORTS SUMMARY (${widget.portList.length})',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 5),
          tblHdr(['PORT NAME', 'TOTAL', 'LADEN', 'EMPTY', '20FT', '40FT']),
          ...widget.portList.asMap().entries.map((e) {
            final pc = all
                .where((c) => c.currentPortId == e.value.portId)
                .toList();
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 7,
              ),
              color: e.key.isEven ? PdfColors.grey100 : PdfColors.white,
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      e.value.portDesc,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.length}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.where((c) => c.statusId == 1).length}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.yellow800,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.where((c) => c.statusId == 2).length}',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.red700),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.where((c) => c.containerSizeId == 1).length}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '${pc.where((c) => c.containerSizeId == 2).length}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Container_Report_$dateStr.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.containers;
    final laden = _filter('laden');
    final empty = _filter('empty');
    final mtFood = _filter('mtfood');
    final fsl = _filter('fsl');
    final strip = _filter('strip');
    final nonFood = _filter('nonfood');
    final date = _fmt(DateTime.now().toIso8601String());

    final tiles = [
      ('Total', '${all.length}', _C.emerald),
      ('Laden', '${laden.length}', _C.gold),
      ('MT Food', '${mtFood.length}', _C.emeraldL),
      ('FSL', '${fsl.length}', _C.blue),
      ('Stripping', '${strip.length}', _C.orange),
      ('MT Non-Food', '${nonFood.length}', _C.purple),
      ('Empty', '${empty.length}', _C.red),
      ('Ports', '${widget.portList.length}', Colors.blueGrey),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 0),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.summarize_rounded,
                        color: _C.gold,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GOTHONG SOUTHERN — CONTAINER REPORT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Generated: $date',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _print(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _C.gold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.print_rounded,
                                color: _C.textD,
                                size: 14,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Print',
                                style: TextStyle(
                                  color: _C.textD,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: tiles
                          .map(
                            (t) => Container(
                              width: 78,
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                vertical: 7,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: t.$3,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    t.$2,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    t.$1,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TabBar(
                    controller: _tab,
                    indicatorColor: _C.gold,
                    labelColor: _C.gold,
                    unselectedLabelColor: Colors.white38,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                    tabs: const [
                      Tab(text: 'ALL'),
                      Tab(text: 'LADEN'),
                      Tab(text: 'MT FOOD'),
                      Tab(text: 'FSL'),
                      Tab(text: 'STRIPPING'),
                      Tab(text: 'MT NON-FOOD'),
                      Tab(text: 'EMPTY'),
                      Tab(text: 'PORTS'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _ReportTable(containers: all, fmt: _fmt, days: _days),
                  _ReportTable(containers: laden, fmt: _fmt, days: _days),
                  _ReportTable(containers: mtFood, fmt: _fmt, days: _days),
                  _ReportTable(containers: fsl, fmt: _fmt, days: _days),
                  _ReportTable(containers: strip, fmt: _fmt, days: _days),
                  _ReportTable(containers: nonFood, fmt: _fmt, days: _days),
                  _ReportTable(containers: empty, fmt: _fmt, days: _days),
                  _ReportPortsTable(portList: widget.portList, containers: all),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Report Table ──────────────────────────────────────────────────────────────
class _ReportTable extends StatelessWidget {
  final List<ContainerModel> containers;
  final String Function(String?) fmt, days;
  const _ReportTable({
    required this.containers,
    required this.fmt,
    required this.days,
  });

  static Widget _th(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 9),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 9.5,
        letterSpacing: 0.3,
      ),
    ),
  );

  static Widget _td(String t, {bool center = false, TextStyle? style}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 9),
        child: Text(
          t,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: style ?? const TextStyle(fontSize: 11.5, color: _C.textD),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (containers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: Text(
            'No data available.',
            style: TextStyle(color: _C.textL, fontSize: 13),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              '${containers.length} record${containers.length != 1 ? "s" : ""} found',
              style: const TextStyle(
                fontSize: 10.5,
                color: _C.textL,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Table(
            border: TableBorder.all(
              color: Colors.grey.shade200,
              width: 1,
              borderRadius: BorderRadius.circular(8),
            ),
            columnWidths: const {
              0: FixedColumnWidth(32),
              1: FlexColumnWidth(2.5),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(0.8),
              4: FlexColumnWidth(1.8),
              5: FlexColumnWidth(1.4),
              6: FlexColumnWidth(1.8),
              7: FlexColumnWidth(1.4),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
                children: [
                  _th('#'),
                  _th('CONTAINER NO.'),
                  _th('STATUS'),
                  _th('SIZE'),
                  _th('DATE IN YARD'),
                  _th('DAYS IN YARD'),
                  _th('DATE MOVED'),
                  _th('DAYS IN SLOT'),
                ],
              ),
              ...containers.asMap().entries.map((e) {
                final i = e.key;
                final c = e.value;
                final isLaden = c.statusId == 1;
                return TableRow(
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : const Color(0xFFF8F9FA),
                  ),
                  children: [
                    _td(
                      '${i + 1}',
                      center: true,
                      style: const TextStyle(fontSize: 10.5, color: _C.textL),
                    ),
                    _td(
                      c.containerNumber,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 9,
                      ),
                      child: Text(
                        isLaden ? 'Laden' : 'Empty',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isLaden
                              ? Colors.amber.shade800
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                    _td(
                      c.containerSizeId == 1
                          ? '20ft'
                          : c.containerSizeId == 2
                          ? '40ft'
                          : '—',
                      center: true,
                    ),
                    _td(fmt(c.yardEntryDate ?? c.createdDate)),
                    _td(days(c.yardEntryDate ?? c.createdDate), center: true),
                    _td(fmt(c.moveConfirmedDate ?? c.createdDate)),
                    _td(
                      days(c.moveConfirmedDate ?? c.createdDate),
                      center: true,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Report Ports Table ────────────────────────────────────────────────────────
class _ReportPortsTable extends StatelessWidget {
  final List<Port> portList;
  final List<ContainerModel> containers;
  const _ReportPortsTable({required this.portList, required this.containers});

  static Widget _th(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 9),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 9.5,
        letterSpacing: 0.3,
      ),
    ),
  );
  static Widget _td(String t, {bool center = false, TextStyle? style}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 9),
        child: Text(
          t,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: style ?? const TextStyle(fontSize: 11.5, color: _C.textD),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (portList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(36),
          child: Text(
            'No data available.',
            style: TextStyle(color: _C.textL, fontSize: 13),
          ),
        ),
      );
    }
    int gTotal = 0, gLaden = 0, gEmpty = 0, g20 = 0, g40 = 0;
    final data = portList.map((p) {
      final pc = containers.where((c) => c.currentPortId == p.portId).toList();
      final l = pc.where((c) => c.statusId == 1).length;
      final e = pc.where((c) => c.statusId == 2).length;
      final f20 = pc.where((c) => c.containerSizeId == 1).length;
      final f40 = pc.where((c) => c.containerSizeId == 2).length;
      gTotal += pc.length;
      gLaden += l;
      gEmpty += e;
      g20 += f20;
      g40 += f40;
      return (
        port: p,
        total: pc.length,
        laden: l,
        empty: e,
        ft20: f20,
        ft40: f40,
      );
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              '${portList.length} port${portList.length != 1 ? "s" : ""} active',
              style: const TextStyle(
                fontSize: 10.5,
                color: _C.textL,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Table(
            border: TableBorder.all(
              color: Colors.grey.shade200,
              width: 1,
              borderRadius: BorderRadius.circular(8),
            ),
            columnWidths: const {
              0: FixedColumnWidth(32),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
              5: FlexColumnWidth(1.2),
              6: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
                children: [
                  _th('#'),
                  _th('PORT NAME'),
                  _th('TOTAL'),
                  _th('LADEN'),
                  _th('EMPTY'),
                  _th('20FT'),
                  _th('40FT'),
                ],
              ),
              ...data.asMap().entries.map((e) {
                final i = e.key;
                final d = e.value;
                return TableRow(
                  decoration: BoxDecoration(
                    color: i.isEven ? Colors.white : const Color(0xFFF8F9FA),
                  ),
                  children: [
                    _td(
                      '${i + 1}',
                      center: true,
                      style: const TextStyle(fontSize: 10.5, color: _C.textL),
                    ),
                    _td(
                      d.port.portDesc,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _td(
                      '${d.total}',
                      center: true,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _td(
                      '${d.laden}',
                      center: true,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    _td(
                      '${d.empty}',
                      center: true,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                    _td('${d.ft20}', center: true),
                    _td('${d.ft40}', center: true),
                  ],
                );
              }),
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF0F4F8)),
                children: [
                  _td('', center: true),
                  _td(
                    'TOTAL',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: _C.textD,
                    ),
                  ),
                  _td(
                    '$gTotal',
                    center: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _td(
                    '$gLaden',
                    center: true,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.amber.shade800,
                    ),
                  ),
                  _td(
                    '$gEmpty',
                    center: true,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.red.shade700,
                    ),
                  ),
                  _td(
                    '$g20',
                    center: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _td(
                    '$g40',
                    center: true,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Reports Page Content ──────────────────────────────────────────────────────
class _ReportsPageContent extends StatelessWidget {
  final List<ContainerModel> containers;
  final List<Port> portList;
  const _ReportsPageContent({required this.containers, required this.portList});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(color: _C.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: _C.orange,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generate Container Report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _C.textD,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Export all container data to PDF format',
                      style: TextStyle(fontSize: 13, color: _C.textL),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => _ReportDialog(
                      containers: containers,
                      portList: portList,
                    ),
                  );
                },
                icon: const Icon(Icons.print_rounded),
                label: const Text('Generate PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: _C.border),
          const SizedBox(height: 24),
          Text(
            'Report Summary',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _C.textD,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ReportStat(
                label: 'Total Containers',
                value: '${containers.length}',
                icon: Icons.inventory_2_rounded,
                color: _C.emerald,
              ),
              _ReportStat(
                label: 'Laden',
                value: '${containers.where((c) => c.statusId == 1).length}',
                icon: Icons.check_circle_rounded,
                color: _C.gold,
              ),
              _ReportStat(
                label: 'Empty',
                value: '${containers.where((c) => c.statusId == 2).length}',
                icon: Icons.radio_button_unchecked_rounded,
                color: _C.red,
              ),
              _ReportStat(
                label: 'Active Ports',
                value: '${portList.length}',
                icon: Icons.anchor_rounded,
                color: _C.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ReportStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(label, style: TextStyle(fontSize: 11, color: _C.textM)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notifications Page Content ────────────────────────────────────────────────
class _NotificationsPageContent extends StatefulWidget {
  const _NotificationsPageContent();

  @override
  State<_NotificationsPageContent> createState() =>
      _NotificationsPageContentState();
}

class _NotificationsPageContentState extends State<_NotificationsPageContent> {
  NotifType? _filter;

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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(color: _C.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.emerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: _C.emerald,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _C.textD,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unread > 0
                          ? '$unread unread notification${unread != 1 ? "s" : ""}'
                          : 'All caught up!',
                      style: TextStyle(
                        fontSize: 13,
                        color: unread > 0 ? _C.red : _C.textL,
                        fontWeight: unread > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread > 0)
                TextButton.icon(
                  onPressed: () => svc.markAllRead(),
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Mark all read'),
                  style: TextButton.styleFrom(foregroundColor: _C.emerald),
                ),
              if (all.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => svc.clearAll(),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: const Text('Clear all'),
                  style: TextButton.styleFrom(foregroundColor: _C.red),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          // Filter tabs
          if (all.isNotEmpty)
            Row(
              children: [
                _FilterChipPage(
                  label: 'All',
                  count: all.length,
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                _FilterChipPage(
                  label: 'Movements',
                  count: all.where((n) => n.type == NotifType.movement).length,
                  selected: _filter == NotifType.movement,
                  onTap: () => setState(
                    () => _filter = _filter == NotifType.movement
                        ? null
                        : NotifType.movement,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterChipPage(
                  label: 'Move Out',
                  count: all.where((n) => n.type == NotifType.moveOut).length,
                  selected: _filter == NotifType.moveOut,
                  onTap: () => setState(
                    () => _filter = _filter == NotifType.moveOut
                        ? null
                        : NotifType.moveOut,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(color: _C.border),
          const SizedBox(height: 16),
          // Notifications list
          if (shown.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_off_rounded,
                      size: 64,
                      color: _C.textL.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _filter != null
                          ? 'No notifications in this category'
                          : 'No notifications yet',
                      style: TextStyle(fontSize: 16, color: _C.textL),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: List.generate(shown.length, (i) {
                final n = shown[i];
                return _NotifTilePage(
                  notif: n,
                  onTap: () {
                    svc.markRead(n.id);
                    showDialog(
                      context: context,
                      builder: (_) => NotifDetailDialog(notif: n),
                    );
                  },
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _FilterChipPage extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChipPage({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _C.emerald : _C.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _C.emerald : _C.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _C.textD,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.2)
                      : _C.emerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : _C.emerald,
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

class _NotifTilePage extends StatefulWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  const _NotifTilePage({required this.notif, required this.onTap});

  @override
  State<_NotifTilePage> createState() => _NotifTilePageState();
}

class _NotifTilePageState extends State<_NotifTilePage> {
  bool _hovered = false;

  Color get _accentColor {
    switch (widget.notif.type) {
      case NotifType.movement:
        return _C.emerald;
      case NotifType.moveOut:
        return _C.blue;
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
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered
                ? color.withOpacity(0.05)
                : isRead
                ? Colors.white
                : color.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead ? _C.border : color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _typeLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: color,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _timeAgo(widget.notif.timestamp),
                          style: TextStyle(fontSize: 11, color: _C.textL),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 8),
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
                    const SizedBox(height: 8),
                    Text(
                      widget.notif.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                        color: _C.textD,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.notif.body,
                      style: TextStyle(
                        fontSize: 12,
                        color: _C.textM,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
