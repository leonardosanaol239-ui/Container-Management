import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/container_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  final Session session;
  const DriverDashboardScreen({super.key, required this.session});
  @override
  State<DriverDashboardScreen> createState() => _DriverDashState();
}

class _DriverDashState extends State<DriverDashboardScreen> {
  final _api = ApiService();
  List<ContainerModel> _active = [];
  List<ContainerModel> _movedOut = [];
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
        final all = await _api.getContainersByPort(widget.session.portId!);
        final moved = await _api.getMovedOutContainers(widget.session.portId!);
        setState(() {
          _active = all
              .where((c) => c.truckId != null && !c.isMovedOut)
              .toList();
          _movedOut = moved;
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroSection(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatsRow(),
                                const SizedBox(height: 28),
                                _buildSection(
                                  title: 'ACTIVE LOADS',
                                  icon: Icons.local_shipping_rounded,
                                  color: AppColors.green,
                                  count: _active.length,
                                  child: _active.isEmpty
                                      ? _buildEmpty(
                                          'No active containers assigned to your truck',
                                        )
                                      : Column(
                                          children: _active
                                              .map(
                                                (c) => _ContainerCard(
                                                  c: c,
                                                  showLocation: true,
                                                ),
                                              )
                                              .toList(),
                                        ),
                                ),
                                const SizedBox(height: 24),
                                _buildSection(
                                  title: 'RECENTLY DELIVERED',
                                  icon: Icons.check_circle_rounded,
                                  color: AppColors.textGrey,
                                  count: _movedOut.length,
                                  child: _movedOut.isEmpty
                                      ? _buildEmpty('No delivery history yet')
                                      : Column(
                                          children: _movedOut
                                              .take(5)
                                              .map(
                                                (c) => _ContainerCard(
                                                  c: c,
                                                  showLocation: false,
                                                ),
                                              )
                                              .toList(),
                                        ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'DRIVER PORTAL',
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
                      size: 14,
                    ),
                    SizedBox(width: 5),
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

  // ── Hero Section (port banner + greeting) ────────────────────────────────

  Widget _buildHeroSection() => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: AppColors.green,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      boxShadow: [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: AppColors.green,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${widget.session.fullName.split(' ').first}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Here\'s your delivery overview for today.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AppColors.yellow,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'ASSIGNED PORT',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.session.portDesc ?? 'No port assigned',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Stats Row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow() => Row(
    children: [
      _StatCard(
        label: 'Active Loads',
        value: '${_active.length}',
        icon: Icons.inventory_2_rounded,
        color: AppColors.green,
      ),
      const SizedBox(width: 12),
      _StatCard(
        label: 'Delivered',
        value: '${_movedOut.length}',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF1565C0),
      ),
      const SizedBox(width: 12),
      _StatCard(
        label: 'Laden',
        value: '${_active.where((c) => c.statusId == 1).length}',
        icon: Icons.circle_rounded,
        color: AppColors.yellow,
        textColor: AppColors.textDark,
      ),
      const SizedBox(width: 12),
      _StatCard(
        label: 'Empty',
        value: '${_active.where((c) => c.statusId == 2).length}',
        icon: Icons.radio_button_unchecked_rounded,
        color: AppColors.red,
      ),
    ],
  );

  // ── Section ───────────────────────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required int count,
    required Widget child,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 5,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color == AppColors.textGrey ? AppColors.textGrey : color,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      child,
    ],
  );

  // ── Empty State ───────────────────────────────────────────────────────────

  Widget _buildEmpty(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.yellow.withValues(alpha: 0.25)),
    ),
    child: Column(
      children: [
        Icon(
          Icons.inbox_rounded,
          size: 40,
          color: AppColors.yellow.withValues(alpha: 0.45),
        ),
        const SizedBox(height: 10),
        Text(
          msg,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
    decoration: const BoxDecoration(color: AppColors.yellow),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_rounded, color: AppColors.green, size: 16),
        SizedBox(width: 8),
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
  );
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final Color textColor;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: textColor, size: 15),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
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

// ── Container Card ────────────────────────────────────────────────────────────

class _ContainerCard extends StatelessWidget {
  final ContainerModel c;
  final bool showLocation;
  const _ContainerCard({required this.c, required this.showLocation});

  @override
  Widget build(BuildContext context) {
    final isLaden = c.statusId == 1;
    final statusColor = isLaden ? AppColors.green : AppColors.red;
    final statusLabel = isLaden ? 'Laden' : 'Empty';

    final locationParts = <String>[
      if (c.yardId != null) 'Yard ${c.yardId}',
      if (c.blockId != null) 'Block ${c.blockId}',
      if (c.bayId != null) 'Bay ${c.bayId}',
      if (c.rowId != null) 'Row ${c.rowId}',
      if (c.tier != null) 'Tier ${c.tier}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.yellow.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top accent
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: statusColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.containerNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppColors.textDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (c.type != null)
                            Text(
                              c.type!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textGrey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                // Location row
                if (showLocation && locationParts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.yellow.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warehouse_rounded,
                          size: 13,
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            locationParts.join(' · '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Bound to
                if (c.boundTo != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        size: 13,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Bound to: ${c.boundTo}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
