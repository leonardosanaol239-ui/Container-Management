import 'package:flutter/material.dart';
import 'dart:async';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/yard.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'landing_screen.dart';
import 'port_management_screen.dart';

class CheckerDashboardScreen extends StatefulWidget {
  final Session session;
  const CheckerDashboardScreen({super.key, required this.session});

  @override
  State<CheckerDashboardScreen> createState() => _CheckerDashboardScreenState();
}

class _CheckerDashboardScreenState extends State<CheckerDashboardScreen> {
  final _api = ApiService();
  bool _loading = true;

  List<ContainerModel> _containers = [];
  List<Yard> _yards = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _silentRefresh(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
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
      setState(() {
        _containers = results[0] as List<ContainerModel>;
        _yards = results[1] as List<Yard>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _silentRefresh() async {
    if (!mounted) return;
    final portId = widget.session.portId;
    if (portId == null) return;
    try {
      final results = await Future.wait([
        _api.getContainersByPort(portId),
        _api.getYards(portId),
      ]);
      if (!mounted) return;
      setState(() {
        _containers = results[0] as List<ContainerModel>;
        _yards = results[1] as List<Yard>;
      });
    } catch (_) {}
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

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (_) => false,
    );
  }

  int get _inYard => _containers.where((c) => c.locationStatusId == 1).length;
  int get _pending => _containers.where((c) => c.locationStatusId == 3).length;

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
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.yellow,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Row(
        children: [
          Image.asset(
            'assets/gothong_logo.png',
            height: 36,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'CONTAINER MANAGEMENT SYSTEM',
              style: TextStyle(
                color: AppColors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Welcome, ${widget.session.fullName}',
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                'Checker',
                style: TextStyle(
                  color: AppColors.green.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 16, color: AppColors.green),
            label: const Text(
              'Refresh',
              style: TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 16, color: AppColors.green),
            label: const Text(
              'Logout',
              style: TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Port name
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: AppColors.green),
              const SizedBox(width: 4),
              Text(
                widget.session.portDesc ??
                    'Port ${widget.session.portId ?? "-"}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Section header
          _sectionHeader('OVERVIEW'),
          const SizedBox(height: 12),
          // Stat cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.green,
                  value: '${_containers.length}',
                  label: 'Total\nContainers',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.pending_actions,
                  iconColor: Colors.blue,
                  value: '$_pending',
                  label: 'Pending Move\nRequests',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.warehouse_outlined,
                  iconColor: Colors.amber.shade700,
                  value: '$_inYard',
                  label: 'Containers\nin Yard',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.grid_view,
                  iconColor: AppColors.green,
                  value: '${_yards.length}',
                  label: 'Total\nYards',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Manage Containers button
          _sectionHeader('CONTAINER MANAGEMENT'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openPortManagement,
              icon: const Icon(Icons.warehouse, size: 22),
              label: const Text(
                'MANAGE CONTAINERS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.yellow,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Opens the yard map and container holding area for ${widget.session.portDesc ?? "your port"}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 28),
          // Yards overview
          if (_yards.isNotEmpty) ...[
            _sectionHeader('YARDS'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _yards.map((y) {
                final inYard = _containers
                    .where(
                      (c) => c.yardId == y.yardId && c.locationStatusId == 1,
                    )
                    .length;
                final pending = _containers
                    .where(
                      (c) => c.yardId == y.yardId && c.locationStatusId == 3,
                    )
                    .length;
                return Container(
                  width: 160,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warehouse,
                            size: 18,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Yard ${y.yardNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$inYard in yard',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (pending > 0)
                        Text(
                          '$pending pending',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: AppColors.textDark,
          letterSpacing: 1,
        ),
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
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
    );
  }
}
