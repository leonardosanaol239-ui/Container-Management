import 'package:flutter/material.dart';
import 'dart:async';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/yard.dart';
import '../services/api_service.dart';
import '../widgets/nav_profile_btn.dart';
import 'driver_yard_screen.dart';
import 'landing_screen.dart';
import 'account_screen.dart';

/// Modern Driver Dashboard - Enhanced UI for logistics operations
/// Redesigned with Material 3 principles and professional shipping aesthetics
class DriverDashboardScreen extends StatefulWidget {
  final Session session;
  const DriverDashboardScreen({super.key, required this.session});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  bool _loading = true; // true only on first load â€” shows full-screen spinner
  bool _refreshing =
      false; // true during manual refresh â€” spins the button icon
  List<ContainerModel> _moveRequests = [];
  Map<int, Yard> _yardsById = {};
  Map<int, String> _portNames = {};
  Map<int, int> _requestCountByYard = {};
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _pollTimer;
  late AnimationController _fadeController;
  late AnimationController _slideController;

  // â”€â”€ Gothong Southern Brand Colors â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // PRIMARY:   Lincoln Green #0B560D | Scarlet Red #FF2800 | Canary Yellow #FFF200
  // SECONDARY: Live Green #98F29B    | Smiley Red #E0474C  | Cyber Yellow #FFD300

  // Primary palette
  static const _primaryGreen = Color(0xFF0B560D); // Pantone Lincoln Green
  static const _scarletRed = Color(0xFFFF2800); // Pantone Scarlet Red
  static const _canaryYellow = Color(0xFFFFF200); // Pantone Canary Yellow

  // Secondary palette
  static const _liveGreen = Color(0xFF98F29B); // Pantone Live Green
  static const _smileRed = Color(0xFFE0474C); // Pantone Smiley Red
  static const _cyberYellow = Color(0xFFFFD300); // Pantone Cyber Yellow

  // Aliases used throughout the UI
  static const _secondaryGold = _cyberYellow;
  static const _accent = Color(0xFFE65100);
  static const _background = Color(0xFFF0F2EE);
  static const _cardWhite = Color(0xFFFFFFFF);
  static const _textDark = Color(0xFF1A1A0A);
  static const _textLight = Color(0xFF757575);
  static const _successGreen = _liveGreen;
  static const _warningRed = _scarletRed;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
    // No auto-poll â€” driver refreshes manually via the Refresh button
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _pollTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final driverPortId = widget.session.portId;

      if (driverPortId == null) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No port assigned to your account'),
              backgroundColor: _warningRed,
            ),
          );
        }
        return;
      }

      final ports = await _api.getPorts();
      final assignedPort = ports.firstWhere(
        (p) => p.portId == driverPortId,
        orElse: () => throw Exception('Assigned port not found'),
      );

      final Map<int, String> portNames = {
        assignedPort.portId: assignedPort.portDesc,
      };

      final containers = await _api.getContainersByPort(driverPortId);
      final yards = await _api.getYards(driverPortId);
      final yardsById = <int, Yard>{
        for (final yard in yards) yard.yardId: yard,
      };

      final moveRequests =
          containers.where((c) => c.locationStatusId == 3).toList()..sort(
            (a, b) =>
                (a.moveRequestDate ?? '').compareTo(b.moveRequestDate ?? ''),
          );

      final requestCountByYard = <int, int>{};
      for (final req in moveRequests) {
        if (req.yardId != null) {
          requestCountByYard[req.yardId!] =
              (requestCountByYard[req.yardId!] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _moveRequests = moveRequests;
          _yardsById = yardsById;
          _portNames = portNames;
          _requestCountByYard = requestCountByYard;
          _loading = false;
        });
        // Only animate on first load
        _fadeController.forward(from: 0);
        _slideController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: ${e.toString()}'),
            backgroundColor: _warningRed,
          ),
        );
      }
    }
  }

  /// Manual refresh â€” updates data silently, spins the refresh button icon,
  /// and shows a brief confirmation snackbar when done.
  Future<void> _silentRefresh() async {
    if (_refreshing) return;
    if (mounted) setState(() => _refreshing = true);
    try {
      final driverPortId = widget.session.portId;
      if (driverPortId == null) return;

      final containers = await _api.getContainersByPort(driverPortId);
      final yards = await _api.getYards(driverPortId);
      final yardsById = <int, Yard>{
        for (final yard in yards) yard.yardId: yard,
      };

      final moveRequests =
          containers.where((c) => c.locationStatusId == 3).toList()..sort(
            (a, b) =>
                (a.moveRequestDate ?? '').compareTo(b.moveRequestDate ?? ''),
          );

      final requestCountByYard = <int, int>{};
      for (final req in moveRequests) {
        if (req.yardId != null) {
          requestCountByYard[req.yardId!] =
              (requestCountByYard[req.yardId!] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _moveRequests = moveRequests;
          _yardsById = yardsById;
          _requestCountByYard = requestCountByYard;
          _refreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text(
                  'Dashboard refreshed',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            backgroundColor: _primaryGreen,
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

  List<ContainerModel> get _filteredRequests {
    if (_searchQuery.isEmpty) return _moveRequests;
    final query = _searchQuery.toLowerCase();
    return _moveRequests.where((c) {
      return c.containerNumber.toLowerCase().contains(query) ||
          (c.containerDesc?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _confirmMoveRequest(ContainerModel container) async {
    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: _primaryGreen),
        ),
      );

      // Call API to confirm move request (sets locationStatusId to 1)
      await _api.confirmMoveRequest(container.containerId);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Reload data to refresh the list
      await _loadData();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Operation confirmed for ${container.containerNumber}',
            ),
            backgroundColor: _successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming request: ${e.toString()}'),
            backgroundColor: _warningRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  String get _currentDate {
    final now = DateTime.now();
    final months = [
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
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Column(
        children: [
          _buildModernHeader(),
          Expanded(
            child: _loading
                ? _buildLoadingState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeCard(),
                        const SizedBox(height: 24),
                        _buildStatisticsCards(),
                        const SizedBox(height: 24),
                        _buildAssignedYardsSection(),
                        const SizedBox(height: 24),
                        _buildDriverTipsCard(),
                        const SizedBox(height: 24),
                        _buildMoveRequestsPanel(),
                        const SizedBox(height: 32),
                        _buildFooter(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // MODERN HEADER
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(color: Color(0xFF0B3D0F)),
      child: Row(
        children: [
          // Company Logo
          Container(
            width: 46,
            height: 46,
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
          const SizedBox(width: 14),

          // Company name
          const Text(
            'Gothong Southern',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 16),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'Driver Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Refresh Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _refreshing ? null : _silentRefresh,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _refreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _primaryGreen,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.refresh,
                            color: _primaryGreen,
                            size: 16,
                          ),
                    const SizedBox(width: 7),
                    Text(
                      _refreshing ? 'Refreshing...' : 'Refresh',
                      style: const TextStyle(
                        color: _primaryGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Profile avatar dropdown
          NavProfileBtn(
            session: widget.session,
            onLogout: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LandingScreen()),
              (_) => false,
            ),
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // WELCOME CARD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildWelcomeCard() {
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _primaryGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.person, size: 34, color: Colors.white),
            ),
            const SizedBox(width: 20),

            // Welcome Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Welcome Back, ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        widget.session.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('ðŸ‘‹', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.session.portDesc ?? 'Cebu Port',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 7),
                            SizedBox(width: 5),
                            Text(
                              'Active Driver',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _currentDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Shipping icon accent â€” removed per design update
          ],
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // STATISTICS CARDS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.assignment_outlined,
            label: 'Total Move Requests',
            value: '${_moveRequests.length}',
            trend: 'Pending',
            iconBg: _primaryGreen,
            iconColor: Colors.white,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildStatCard(
            icon: Icons.warehouse_outlined,
            label: 'Yards With Move Requests',
            value: '${_requestCountByYard.length}',
            trend: 'Active',
            iconBg: _primaryGreen,
            iconColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String trend,
    required Color iconBg,
    required Color iconColor,
  }) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
          .animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
          ),
      child: Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trend,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
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
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // ASSIGNED YARDS SECTION
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildAssignedYardsSection() {
    final yardsWithRequests = _requestCountByYard.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shows Number',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 16),
        if (yardsWithRequests.isEmpty)
          _buildEmptyYardsCard()
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: yardsWithRequests.map((entry) {
              final yard = _yardsById[entry.key];
              if (yard == null) return const SizedBox.shrink();
              return _buildYardCard(yard, entry.value);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildEmptyYardsCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _textLight.withOpacity(0.2)),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.warehouse_outlined, size: 48, color: _textLight),
            SizedBox(height: 12),
            Text(
              'No yards with move requests',
              style: TextStyle(color: _textLight, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYardCard(Yard yard, int requestCount) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverYardScreen(
                  yard: yard,
                  portId: yard.portId,
                  portName: _portNames[yard.portId] ?? '',
                  session: widget.session,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _primaryGreen.withOpacity(0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
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
                        color: _primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warehouse,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, color: _primaryGreen, size: 8),
                          SizedBox(width: 6),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: _primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _portNames[yard.portId] ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Yard ${yard.yardNumber}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.assignment, color: _accent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '$requestCount requests',
                        style: const TextStyle(
                          color: _accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DriverYardScreen(
                            yard: yard,
                            portId: yard.portId,
                            portName: _portNames[yard.portId] ?? '',
                            session: widget.session,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'View Map',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // DRIVER TIPS CARD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildDriverTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: _primaryGreen, width: 5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lightbulb, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver Tip',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _primaryGreen,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Always verify container condition before confirming movement.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // MOVE REQUESTS PANEL
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildMoveRequestsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Search
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'List of Move Requests',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                ),
                // Modern Search Bar
                Container(
                  width: 280,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _textLight.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search container...',
                      hintStyle: TextStyle(
                        color: _textLight.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: _textLight,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.filter_list,
                          color: _textLight,
                          size: 20,
                        ),
                        onPressed: () {},
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Request List
          if (_filteredRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(60),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: _textLight.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No move requests found',
                      style: TextStyle(
                        color: _textLight.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredRequests.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, index) {
                final container = _filteredRequests[index];
                return _buildRequestCard(container);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(ContainerModel container) {
    final isLaden = container.statusId == 1;
    final isEmpty = container.statusId == 2;

    final statusColor = isLaden
        ? const Color(0xFF1565C0)
        : isEmpty
        ? _warningRed
        : _textLight;
    final statusBgColor = isLaden
        ? const Color(0xFF1565C0).withValues(alpha: 0.1)
        : isEmpty
        ? _warningRed.withOpacity(0.1)
        : _textLight.withOpacity(0.1);
    final statusText = isLaden
        ? 'Laden'
        : isEmpty
        ? 'Empty'
        : 'Unknown';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              // Container Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primaryGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Container Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          container.containerNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _textLight.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            container.type ?? '20ft',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _textLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: _textLight,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Requested ${_getTimeAgo(container.moveRequestDate)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _textLight,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          container.containerDesc ?? 'Food',
                          style: const TextStyle(
                            fontSize: 13,
                            color: _textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Confirm Button
              ElevatedButton(
                onPressed: () => _confirmMoveRequest(container),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Operation Confirm',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(String? dateStr) {
    if (dateStr == null) return 'recently';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      return '${diff.inDays} days ago';
    } catch (_) {
      return 'recently';
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // FOOTER
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _textLight.withOpacity(0.2))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/gothong_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Gothong Southern Container Management System',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Driver Portal',
            style: TextStyle(fontSize: 12, color: _textLight.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // LOADING STATE
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              valueColor: const AlwaysStoppedAnimation<Color>(_primaryGreen),
              backgroundColor: _primaryGreen.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading dashboard...',
            style: TextStyle(
              fontSize: 16,
              color: _textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Nav Profile Button (avatar + name + role + dropdown) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Shared by Driver, Checker, and Customer dashboards.
// On dark nav bar â€” avatar is green circle, text is white, dropdown is white card.

class _NavProfileBtn extends StatefulWidget {
  final Session session;
  final VoidCallback onLogout;
  const _NavProfileBtn({required this.session, required this.onLogout});

  @override
  State<_NavProfileBtn> createState() => _NavProfileBtnState();
}

class _NavProfileBtnState extends State<_NavProfileBtn> {
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
      builder: (_) => _NavProfileDropdown(
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
              builder: (_) =>
                  AccountScreen(session: widget.session, isAdmin: false),
            ),
          );
        },
        onLogout: widget.onLogout,
      ),
    );
    Overlay.of(context).insert(_ov!);
    if (mounted) setState(() => _h = true);
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _h
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _h
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar circle
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0B560D),
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
                const SizedBox(width: 8),
                // Name + role
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.session.fullName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.session.role,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                // Chevron
                AnimatedRotation(
                  turns: _h ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.7),
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

class _NavProfileDropdown extends StatefulWidget {
  final LayerLink link;
  final String initials;
  final Session session;
  final ValueNotifier<bool> inMenu;
  final VoidCallback onHide, onScheduleHide, onProfile, onLogout;

  const _NavProfileDropdown({
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
  State<_NavProfileDropdown> createState() => _NavProfileDropdownState();
}

class _NavProfileDropdownState extends State<_NavProfileDropdown> {
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
                    color: Colors.black.withValues(alpha: 0.13),
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
                      color: Color(0xFF0B560D),
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
                            color: Color(0xFF0B3D0F),
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
                  _NavDDItem(
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
                  _NavDDItem(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    color: const Color(0xFFFF2800),
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

class _NavDDItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _NavDDItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF1A1A0A),
  });

  @override
  State<_NavDDItem> createState() => _NavDDItemState();
}

class _NavDDItemState extends State<_NavDDItem> {
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
            color: _h
                ? widget.color.withValues(alpha: 0.07)
                : Colors.transparent,
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
