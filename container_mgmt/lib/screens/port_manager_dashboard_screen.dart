import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/yard.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/port_selection_dialog.dart';
import 'login_screen.dart';
import 'port_management_screen.dart';

class PortManagerDashboardScreen extends StatefulWidget {
  final Session session;
  const PortManagerDashboardScreen({super.key, required this.session});
  @override
  State<PortManagerDashboardScreen> createState() => _PMDashState();
}

class _PMDashState extends State<PortManagerDashboardScreen> {
  final _api = ApiService();
  List<ContainerModel> _containers = [];
  List<Yard> _yards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.session.portId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        _api.getContainersByPort(widget.session.portId!),
        _api.getYards(widget.session.portId!),
      ]);
      setState(() {
        _containers = r[0] as List<ContainerModel>;
        _yards = r[1] as List<Yard>;
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
    final portId = widget.session.portId;
    final portName = widget.session.portDesc ?? 'Unassigned Port';
    final active = _containers.where((c) => !c.isMovedOut).toList();
    final laden = active.where((c) => c.statusId == 1).length;
    final empty = active.where((c) => c.statusId == 2).length;
    final inYard = active.where((c) => c.isInYard).length;
    final movedOut = _containers.where((c) => c.isMovedOut).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(),
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.green.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.yellow,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.anchor_rounded,
                                    color: AppColors.green,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'MANAGING PORT',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      portName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _sec(
                            Icons.bar_chart_rounded,
                            'OVERVIEW',
                            AppColors.green,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _SC(
                                label: 'Total',
                                value: '${active.length}',
                                icon: Icons.inventory_2_rounded,
                                color: AppColors.green,
                              ),
                              const SizedBox(width: 10),
                              _SC(
                                label: 'Laden',
                                value: '$laden',
                                icon: Icons.check_circle_rounded,
                                color: AppColors.yellow,
                                tc: AppColors.textDark,
                              ),
                              const SizedBox(width: 10),
                              _SC(
                                label: 'Empty',
                                value: '$empty',
                                icon: Icons.radio_button_unchecked_rounded,
                                color: AppColors.red,
                              ),
                              const SizedBox(width: 10),
                              _SC(
                                label: 'In Yard',
                                value: '$inYard',
                                icon: Icons.warehouse_rounded,
                                color: const Color(0xFF1565C0),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _SC(
                                label: 'Yards',
                                value: '${_yards.length}',
                                icon: Icons.grid_view_rounded,
                                color: AppColors.green,
                              ),
                              const SizedBox(width: 10),
                              _SC(
                                label: 'Moved Out',
                                value: '$movedOut',
                                icon: Icons.local_shipping_rounded,
                                color: AppColors.textGrey,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(child: SizedBox()),
                              const SizedBox(width: 10),
                              const Expanded(child: SizedBox()),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _sec(
                            Icons.flash_on_rounded,
                            'QUICK ACTIONS',
                            AppColors.red,
                          ),
                          const SizedBox(height: 10),
                          if (portId != null) ...[
                            _AB(
                              icon: Icons.warehouse_rounded,
                              label: 'MANAGE CONTAINER LOCATION',
                              sub: 'Move containers between yards and blocks',
                              color: AppColors.green,
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => const PortSelectionDialog(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _AB(
                              icon: Icons.grid_view_rounded,
                              label: 'VIEW YARDS',
                              sub: 'See all yards at $portName',
                              color: const Color(0xFF1565C0),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PortManagementScreen(
                                    portId: portId,
                                    portName: portName,
                                  ),
                                ),
                              ).then((_) => _load()),
                            ),
                          ],
                          if (_yards.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sec(
                              Icons.warehouse_rounded,
                              'YARDS AT THIS PORT',
                              AppColors.green,
                            ),
                            const SizedBox(height: 10),
                            ..._yards.map(
                              (y) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.yellow.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.yellow.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.warehouse_rounded,
                                        color: AppColors.green,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Yard ${y.yardNumber}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (y.hasLayout)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.green.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          'Has Layout',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.green,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: const BoxDecoration(color: AppColors.yellow),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_rounded, color: AppColors.green, size: 16),
                SizedBox(width: 6),
                Text(
                  'Gothong Southern  ·  Container Management System',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Container(
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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(
          children: [
            Image.asset(
              'assets/gothong_logo.png',
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'PORT MANAGER',
                style: TextStyle(
                  color: AppColors.yellow,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.session.fullName,
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  widget.session.userCode,
                  style: TextStyle(
                    color: AppColors.green.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: AppColors.yellow,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: AppColors.yellow,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
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

  Widget _sec(IconData icon, String title, Color color) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 8),
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: AppColors.textDark,
          letterSpacing: 0.8,
        ),
      ),
    ],
  );
}

class _SC extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final Color tc;
  const _SC({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.tc = Colors.white,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: tc, size: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AB extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _AB({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white60,
            size: 14,
          ),
        ],
      ),
    ),
  );
}
