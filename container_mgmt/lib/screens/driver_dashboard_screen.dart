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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPortBanner(),
                          const SizedBox(height: 20),
                          _buildStats(),
                          const SizedBox(height: 24),
                          _sec(
                            'ACTIVE LOADS',
                            Icons.local_shipping_rounded,
                            AppColors.green,
                            _active.isEmpty
                                ? _empty('No active containers on your truck')
                                : Column(
                                    children: _active
                                        .map((c) => _CRow(c: c))
                                        .toList(),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          _sec(
                            'RECENTLY MOVED OUT',
                            Icons.check_circle_rounded,
                            AppColors.textGrey,
                            _movedOut.isEmpty
                                ? _empty('No move-out history')
                                : Column(
                                    children: _movedOut
                                        .take(5)
                                        .map((c) => _CRow(c: c))
                                        .toList(),
                                  ),
                          ),
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
                  'Gothong Southern  Â·  Container Management System',
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
                'DRIVER PORTAL',
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
            Icons.local_shipping_rounded,
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

  Widget _buildStats() => Row(
    children: [
      _Chip(
        label: 'Active\nLoads',
        value: '${_active.length}',
        color: AppColors.green,
      ),
      const SizedBox(width: 10),
      _Chip(
        label: 'Delivered',
        value: '${_movedOut.length}',
        color: const Color(0xFF1565C0),
      ),
      const SizedBox(width: 10),
      _Chip(
        label: 'Laden',
        value: '${_active.where((c) => c.statusId == 1).length}',
        color: AppColors.yellow,
        tc: AppColors.textDark,
      ),
      const SizedBox(width: 10),
      _Chip(
        label: 'Empty',
        value: '${_active.where((c) => c.statusId == 2).length}',
        color: AppColors.red,
      ),
    ],
  );

  Widget _sec(String title, IconData icon, Color color, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
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
      ),
      const SizedBox(height: 10),
      child,
    ],
  );

  Widget _empty(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3)),
    ),
    child: Column(
      children: [
        Icon(
          Icons.inbox_rounded,
          size: 36,
          color: AppColors.yellow.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 8),
        Text(
          msg,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
        ),
      ],
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
              height: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CRow extends StatelessWidget {
  final ContainerModel c;
  const _CRow({required this.c});
  @override
  Widget build(BuildContext context) {
    final isLaden = c.statusId == 1;
    final color = isLaden ? AppColors.yellow : AppColors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory_2_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.containerNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
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
                if (c.boundTo != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.near_me_rounded,
                        size: 11,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Bound to: ${c.boundTo}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isLaden ? color : color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isLaden ? 'Laden' : 'Empty',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isLaden ? AppColors.textDark : AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

