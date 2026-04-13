import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/port.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/port_selection_dialog.dart';
import 'user_management_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Session session;
  const DashboardScreen({super.key, required this.session});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  List<ContainerModel> _containers = [];
  List<Port> _ports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getPorts(),
        // fetch containers from first port as a sample; admin sees all ports
      ]);
      final ports = results[0];
      // Load containers from all ports
      List<ContainerModel> allContainers = [];
      for (final port in ports) {
        try {
          final c = await _api.getContainersByPort(port.portId);
          allContainers.addAll(c);
        } catch (_) {}
      }
      setState(() {
        _ports = ports;
        _containers = allContainers;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _logout() => Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );

  @override
  Widget build(BuildContext context) {
    final total = _containers.length;
    final laden = _containers.where((c) => c.statusId == 1).length;
    final empty = _containers.where((c) => c.statusId == 2).length;
    final inYard = _containers.where((c) => c.isInYard).length;
    final movedOut = _containers.where((c) => c.isMovedOut).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _AdminHeader(session: widget.session, onLogout: _logout),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  )
                : RefreshIndicator(
                    color: AppColors.yellow,
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatsSection(
                            total: total,
                            laden: laden,
                            empty: empty,
                            ports: _ports.length,
                            inYard: inYard,
                            movedOut: movedOut,
                          ),
                          _QuickActionsSection(
                            context: context,
                            session: widget.session,
                          ),
                          _PortsSection(ports: _ports, containers: _containers),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
          ),
          _FooterStrip(),
        ],
      ),
    );
  }
}

// ── Admin Header ─────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  final Session session;
  final VoidCallback onLogout;
  const _AdminHeader({required this.session, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.yellow,
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/gothong_logo.png',
                height: 38,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'ADMIN DASHBOARD',
                  style: TextStyle(
                    color: AppColors.yellow,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    session.fullName,
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    session.role,
                    style: TextStyle(
                      color: AppColors.green.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Users button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserManagementScreen(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.manage_accounts,
                        color: AppColors.yellow,
                        size: 15,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Users',
                        style: TextStyle(
                          color: AppColors.yellow,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Logout button
              GestureDetector(
                onTap: onLogout,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: AppColors.yellow,
                        size: 15,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: AppColors.yellow,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
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

// ── Stats Section ─────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final int total, laden, empty, ports, inYard, movedOut;
  const _StatsSection({
    required this.total,
    required this.laden,
    required this.empty,
    required this.ports,
    required this.inYard,
    required this.movedOut,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('OVERVIEW', AppColors.red),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatCard(
                label: 'Total\nContainers',
                value: '$total',
                icon: Icons.inventory_2_rounded,
                accent: AppColors.green,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Laden',
                value: '$laden',
                icon: Icons.check_circle_rounded,
                accent: AppColors.yellow,
                accentText: AppColors.textDark,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Empty',
                value: '$empty',
                icon: Icons.radio_button_unchecked_rounded,
                accent: AppColors.red,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Active\nPorts',
                value: '$ports',
                icon: Icons.location_on_rounded,
                accent: AppColors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(
                label: 'In Yard',
                value: '$inYard',
                icon: Icons.warehouse_rounded,
                accent: AppColors.green,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Moved Out',
                value: '$movedOut',
                icon: Icons.local_shipping_rounded,
                accent: AppColors.yellow,
                accentText: AppColors.textDark,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Unassigned',
                value: '${total - inYard - movedOut}',
                icon: Icons.help_outline_rounded,
                accent: AppColors.textGrey,
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color accent;
  final Color accentText;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.accentText = AppColors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentText, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QuickActionsSection extends StatelessWidget {
  final BuildContext context;
  final Session session;
  const _QuickActionsSection({required this.context, required this.session});

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('QUICK ACTIONS', AppColors.red),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const PortSelectionDialog(),
              ),
              icon: const Icon(Icons.location_city_rounded, size: 22),
              label: const Text(
                'MANAGE CONTAINER LOCATION',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: AppColors.green.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ports Overview ────────────────────────────────────────────────────────────

class _PortsSection extends StatelessWidget {
  final List<Port> ports;
  final List<ContainerModel> containers;
  const _PortsSection({required this.ports, required this.containers});

  @override
  Widget build(BuildContext context) {
    if (ports.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('PORTS OVERVIEW', AppColors.red),
          const SizedBox(height: 16),
          ...ports.map((port) {
            final portContainers = containers
                .where((c) => c.currentPortId == port.portId)
                .toList();
            final laden = portContainers.where((c) => c.statusId == 1).length;
            final empty = portContainers.where((c) => c.statusId == 2).length;
            return _PortRow(
              port: port,
              total: portContainers.length,
              laden: laden,
              empty: empty,
            );
          }),
        ],
      ),
    );
  }
}

class _PortRow extends StatelessWidget {
  final Port port;
  final int total, laden, empty;
  const _PortRow({
    required this.port,
    required this.total,
    required this.laden,
    required this.empty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.yellow.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.yellow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.yellow,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              port.portDesc,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.textDark,
              ),
            ),
          ),
          _pill('$total total', AppColors.green, AppColors.white),
          const SizedBox(width: 6),
          _pill('$laden laden', AppColors.yellow, AppColors.textDark),
          const SizedBox(width: 6),
          _pill('$empty empty', AppColors.red, AppColors.white),
        ],
      ),
    );
  }

  Widget _pill(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _FooterStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: const BoxDecoration(color: AppColors.yellow),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_rounded, color: AppColors.green, size: 18),
          SizedBox(width: 8),
          Text(
            'Gothong Southern  ·  Container Management System',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _sectionTitle(String text, Color accentColor) => Row(
  children: [
    Container(
      width: 5,
      height: 22,
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    const SizedBox(width: 10),
    Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: AppColors.textDark,
        letterSpacing: 1.2,
      ),
    ),
  ],
);
