import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/yard.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/port_selection_dialog.dart';
import 'login_screen.dart';

class PortManagerDashboardScreen extends StatefulWidget {
  final Session session;
  const PortManagerDashboardScreen({super.key, required this.session});

  @override
  State<PortManagerDashboardScreen> createState() =>
      _PortManagerDashboardState();
}

class _PortManagerDashboardState extends State<PortManagerDashboardScreen> {
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
    setState(() => _loading = true);
    try {
      if (widget.session.portId != null) {
        final results = await Future.wait([
          _api.getContainersByPort(widget.session.portId!),
          _api.getYards(widget.session.portId!),
        ]);
        setState(() {
          _containers = results[0] as List<ContainerModel>;
          _yards = results[1] as List<Yard>;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
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
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPortBanner(),
                          const SizedBox(height: 24),
                          _buildStats(total, laden, empty, inYard, movedOut),
                          const SizedBox(height: 28),
                          _buildQuickActions(context),
                          const SizedBox(height: 28),
                          _buildYardsSection(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
          ),
          Container(
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
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        child: Row(
          children: [
            Image.asset(
              'assets/gothong_logo.png',
              height: 38,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'PORT MANAGER',
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
                  widget.session.fullName,
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  widget.session.role,
                  style: TextStyle(
                    color: AppColors.green.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: _logout,
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

  Widget _buildPortBanner() => Container(
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
            Icons.location_on_rounded,
            color: AppColors.green,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ASSIGNED PORT',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.session.portDesc ?? 'No port assigned',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildStats(
    int total,
    int laden,
    int empty,
    int inYard,
    int movedOut,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('OVERVIEW', AppColors.red),
        const SizedBox(height: 16),
        Row(
          children: [
            _Chip(label: 'Total', value: '$total', color: AppColors.green),
            const SizedBox(width: 10),
            _Chip(
              label: 'Laden',
              value: '$laden',
              color: AppColors.yellow,
              tc: AppColors.textDark,
            ),
            const SizedBox(width: 10),
            _Chip(label: 'Empty', value: '$empty', color: AppColors.red),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Chip(label: 'In Yard', value: '$inYard', color: AppColors.green),
            const SizedBox(width: 10),
            _Chip(
              label: 'Moved Out',
              value: '$movedOut',
              color: AppColors.yellow,
              tc: AppColors.textDark,
            ),
            const SizedBox(width: 10),
            _Chip(
              label: 'Yards',
              value: '${_yards.length}',
              color: const Color(0xFF1565C0),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) => Column(
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
  );

  Widget _buildYardsSection() {
    if (_yards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('YARDS', AppColors.red),
        const SizedBox(height: 16),
        ..._yards.map((yard) {
          final yardContainers = _containers
              .where((c) => c.yardId == yard.yardId)
              .toList();
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
                    Icons.warehouse_rounded,
                    color: AppColors.yellow,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Yard ${yard.yardNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                _pill(
                  '${yardContainers.length} containers',
                  AppColors.green,
                  AppColors.white,
                ),
              ],
            ),
          );
        }),
      ],
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

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  final Color tc;
  const _Chip({
    required this.label,
    required this.value,
    required this.color,
    this.tc = Colors.white,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: tc,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: tc.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

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
