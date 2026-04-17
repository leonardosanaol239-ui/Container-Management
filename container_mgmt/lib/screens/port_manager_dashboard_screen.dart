import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/port.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/port_selection_dialog.dart';
import 'landing_screen.dart';
import 'port_management_screen.dart';

class PortManagerDashboardScreen extends StatefulWidget {
  final Session session;
  const PortManagerDashboardScreen({super.key, required this.session});

  @override
  State<PortManagerDashboardScreen> createState() =>
      _PortManagerDashboardScreenState();
}

class _PortManagerDashboardScreenState
    extends State<PortManagerDashboardScreen> {
  final _api = ApiService();

  int _totalContainers = 0;
  int _laden = 0;
  int _empty = 0;
  int _activePorts = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        // Containers for this manager's port
        if (widget.session.portId != null)
          _api.getContainersByPort(widget.session.portId!)
        else
          Future.value(<ContainerModel>[]),
        // All ports for active count
        _api.getPorts(),
      ]);

      final containers = results[0] as List<ContainerModel>;
      final ports = results[1] as List<Port>;

      final inYard = containers.where((c) => !c.isMovedOut).toList();

      setState(() {
        _totalContainers = inYard.length;
        _laden = inYard.where((c) => c.statusId == 1).length;
        _empty = inYard.where((c) => c.statusId == 2).length;
        _activePorts = ports.length;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _goToManageContainerLocation() {
    if (widget.session.portId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PortManagementScreen(
            portId: widget.session.portId!,
            portName: widget.session.portDesc ?? 'My Port',
          ),
        ),
      ).then((_) => _loadStats());
    } else {
      // Fallback: show port selection dialog
      showDialog(
        context: context,
        builder: (_) => const PortSelectionDialog(),
      ).then((_) => _loadStats());
    }
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewSection(),
                    _buildQuickActionsSection(),
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

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/gothong_logo.png',
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.directions_boat_filled,
                  size: 36,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 12),
              // System badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'CONTAINER MANAGEMENT SYSTEM',
                  style: TextStyle(
                    color: AppColors.yellow,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              // Welcome text
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
                    widget.session.role,
                    style: TextStyle(
                      color: AppColors.green.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Refresh button
              GestureDetector(
                onTap: _loadStats,
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
                        Icons.refresh_rounded,
                        color: AppColors.yellow,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Refresh',
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
              const SizedBox(width: 10),
              // Logout button
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
                      Icon(Icons.logout, color: AppColors.yellow, size: 16),
                      SizedBox(width: 6),
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

  // ── Overview Section ──────────────────────────────────────────────────────

  Widget _buildOverviewSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Row(
            children: [
              Container(
                width: 5,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'OVERVIEW',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(
                      color: AppColors.yellow,
                      strokeWidth: 3,
                    ),
                  ),
                )
              : Row(
                  children: [
                    _StatCard(
                      label: 'Total\nContainers',
                      value: '$_totalContainers',
                      icon: Icons.inventory_2_rounded,
                      accent: AppColors.green,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Laden',
                      value: '$_laden',
                      icon: Icons.check_circle_rounded,
                      accent: AppColors.yellow,
                      accentText: AppColors.textDark,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Empty',
                      value: '$_empty',
                      icon: Icons.radio_button_unchecked_rounded,
                      accent: AppColors.red,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Active\nPorts',
                      value: '$_activePorts',
                      icon: Icons.location_on_rounded,
                      accent: AppColors.green,
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // ── Quick Actions Section ─────────────────────────────────────────────────

  Widget _buildQuickActionsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Primary CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _goToManageContainerLocation,
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
          const SizedBox(height: 12),
          // Info tiles row
          Row(
            children: [
              _InfoTile(
                icon: Icons.sailing_rounded,
                label: 'Transport',
                color: AppColors.yellow,
                textColor: AppColors.textDark,
              ),
              const SizedBox(width: 12),
              _InfoTile(
                icon: Icons.sync_alt_rounded,
                label: 'E2E Supply Chain',
                color: AppColors.red,
              ),
              const SizedBox(width: 12),
              _InfoTile(
                icon: Icons.business_center_rounded,
                label: 'Business Solutions',
                color: AppColors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
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

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
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

// ── Info Tile ─────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.color,
    this.textColor = AppColors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
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
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
