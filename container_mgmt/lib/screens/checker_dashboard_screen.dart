import 'package:flutter/material.dart';
import 'dart:async';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/yard.dart';
import '../services/api_service.dart';
import '../widgets/nav_profile_btn.dart';
import 'landing_screen.dart';
import 'port_management_screen.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
class _C {
  static const navBg = Color(0xFF0B3D0F);
  static const green = Color(0xFF0B560D);
  static const greenL = Color(0xFF98F29B);
  static const red = Color(0xFFFF2800);
  static const blue = Color(0xFF1565C0);
  static const orange = Color(0xFFE65100);
  static const bg = Color(0xFFF0F2EE);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8EAE4);
  static const textD = Color(0xFF1A1A0A);
  static const textM = Color(0xFF4A4A4A);
  static const textL = Color(0xFF757575);
}

class CheckerDashboardScreen extends StatefulWidget {
  final Session session;
  const CheckerDashboardScreen({super.key, required this.session});

  @override
  State<CheckerDashboardScreen> createState() => _CheckerDashboardScreenState();
}

class _CheckerDashboardScreenState extends State<CheckerDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  bool _loading = true;
  bool _refreshing = false;
  List<ContainerModel> _containers = [];
  List<Yard> _yards = [];
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);
    try {
      final portId = widget.session.portId;
      if (portId == null) {
        setState(() => _loading = false);
        return;
      }
      final results = await Future.wait([
        _api.getContainersByPort(portId),
        _api.getYards(portId),
      ]);
      if (mounted) {
        setState(() {
          _containers = results[0] as List<ContainerModel>;
          _yards = results[1] as List<Yard>;
          _loading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _manualRefresh() async {
    if (_refreshing) return;
    if (mounted) setState(() => _refreshing = true);
    try {
      final portId = widget.session.portId;
      if (portId == null) return;
      final results = await Future.wait([
        _api.getContainersByPort(portId),
        _api.getYards(portId),
      ]);
      if (mounted) {
        setState(() {
          _containers = results[0] as List<ContainerModel>;
          _yards = results[1] as List<Yard>;
          _refreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Dashboard refreshed',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: _C.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _openPortManagement() {
    final portId = widget.session.portId;
    if (portId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PortManagementScreen(
          portId: portId,
          portName: widget.session.portDesc ?? 'Port $portId',
          session: widget.session,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _logout() => Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LandingScreen()),
    (_) => false,
  );

  int get _inYard => _containers.where((c) => c.locationStatusId == 1).length;
  int get _pending => _containers.where((c) => c.locationStatusId == 3).length;
  int get _laden => _containers.where((c) => c.statusId == 1).length;
  int get _empty => _containers.where((c) => c.statusId == 2).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            color: _C.green,
                            strokeWidth: 4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading ${widget.session.portDesc ?? "dashboard"}...',
                          style: const TextStyle(color: _C.textL, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : FadeTransition(opacity: _fadeCtrl, child: _buildBody()),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _C.navBg,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          // Logo box
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  'assets/gothong_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Gothong Southern',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: Colors.white,
                  size: 13,
                ),
                SizedBox(width: 6),
                Text(
                  'Checker Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Refresh button
          _headerBtn(
            icon: _refreshing ? null : Icons.refresh_rounded,
            label: _refreshing ? 'Refreshing...' : 'Refresh',
            onTap: _refreshing ? null : _manualRefresh,
            loading: _refreshing,
          ),
          const SizedBox(width: 16),
          // Profile avatar dropdown
          NavProfileBtn(session: widget.session, onLogout: _logout),
        ],
      ),
    );
  }

  Widget _headerBtn({
    IconData? icon,
    required String label,
    VoidCallback? onTap,
    bool outlined = false,
    bool loading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: outlined
                ? Border.all(color: Colors.white.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_C.green),
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 15, color: outlined ? Colors.white : _C.green),
              if (icon != null || loading) const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: outlined ? Colors.white : _C.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome strip
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _C.green,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Welcome, ',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            widget.session.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('👋', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.session.portDesc ?? 'Assigned Port',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Colors.white,
                                  size: 7,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Active Checker',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // KPI cards
          _sectionLabel('OVERVIEW'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  icon: Icons.inventory_2_outlined,
                  value: '${_containers.length}',
                  label: 'Total Containers',
                  iconBg: _C.green,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiCard(
                  icon: Icons.pending_actions_outlined,
                  value: '$_pending',
                  label: 'Pending Move\nRequests',
                  iconBg: _C.blue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiCard(
                  icon: Icons.warehouse_outlined,
                  value: '$_inYard',
                  label: 'Containers\nin Yard',
                  iconBg: _C.orange,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiCard(
                  icon: Icons.grid_view_rounded,
                  value: '${_yards.length}',
                  label: 'Total Yards',
                  iconBg: _C.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  icon: Icons.check_circle_outline,
                  value: '$_laden',
                  label: 'Laden',
                  iconBg: _C.blue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiCard(
                  icon: Icons.radio_button_unchecked,
                  value: '$_empty',
                  label: 'Empty',
                  iconBg: _C.textL,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(child: SizedBox()),
              const SizedBox(width: 14),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 28),
          _buildManageSection(),
          const SizedBox(height: 28),
          _buildYardsSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildManageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('CONTAINER MANAGEMENT'),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openPortManagement,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _C.green,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warehouse_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Containers',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Open yard map, container holding area and move requests',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYardsSection() {
    if (_yards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('YARDS'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: _yards.map((y) {
            final inYard = _containers
                .where((c) => c.yardId == y.yardId && c.locationStatusId == 1)
                .length;
            final pending = _containers
                .where((c) => c.yardId == y.yardId && c.locationStatusId == 3)
                .length;
            return Container(
              width: 170,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _C.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warehouse,
                          size: 16,
                          color: _C.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Yard ${y.yardNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _C.textD,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: _C.border, height: 1),
                  const SizedBox(height: 10),
                  _yardStat(
                    Icons.inventory_2_outlined,
                    '$inYard in yard',
                    _C.textM,
                  ),
                  if (pending > 0) ...[
                    const SizedBox(height: 4),
                    _yardStat(
                      Icons.pending_actions,
                      '$pending pending',
                      _C.blue,
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _yardStat(IconData icon, String text, Color color) => Row(
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 6),
      Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _sectionLabel(String title) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: _C.green,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: _C.textM,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}

// ── KPI Card ──────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconBg;

  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: Colors.white.withValues(alpha: 0.35),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: iconBg.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
