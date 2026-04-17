import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/yard.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'landing_screen.dart';
import 'driver_yard_screen.dart';

class CheckerDashboardScreen extends StatefulWidget {
  final Session session;
  const CheckerDashboardScreen({super.key, required this.session});

  @override
  State<CheckerDashboardScreen> createState() => _CheckerDashboardScreenState();
}

class _CheckerDashboardScreenState extends State<CheckerDashboardScreen> {
  final _api = ApiService();
  bool _loading = true;

  List<ContainerModel> _allContainers = [];
  List<ContainerModel> _moveRequests = [];
  List<Yard> _yards = [];
  Map<int, int> _requestsByYard = {};

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

      final allContainers = results[0] as List<ContainerModel>;
      final yards = results[1] as List<Yard>;

      final moveRequests =
          allContainers.where((c) => c.locationStatusId == 3).toList()
            ..sort((a, b) => a.containerId.compareTo(b.containerId));

      final Map<int, int> byYard = {};
      for (final c in moveRequests) {
        if (c.yardId != null) {
          byYard[c.yardId!] = (byYard[c.yardId!] ?? 0) + 1;
        }
      }

      setState(() {
        _allContainers = allContainers;
        _moveRequests = moveRequests;
        _yards = yards;
        _requestsByYard = byYard;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<ContainerModel> get _filtered {
    if (_searchQuery.isEmpty) return _moveRequests;
    final q = _searchQuery.toLowerCase();
    return _moveRequests
        .where((c) => c.containerNumber.toLowerCase().contains(q))
        .toList();
  }

  int get _totalContainers => _allContainers.where((c) => !c.isMovedOut).length;
  int get _yardsWithRequests =>
      _requestsByYard.values.where((v) => v > 0).length;

  Future<void> _confirmRequest(ContainerModel c) async {
    try {
      await _api.confirmMoveRequest(c.containerId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${c.containerNumber} confirmed — now In Yard'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.red),
        );
      }
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
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  )
                : _buildBody(),
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
              GestureDetector(
                onTap: _loadData,
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

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 16,
                color: AppColors.green,
              ),
              const SizedBox(width: 6),
              Text(
                widget.session.portDesc ??
                    'Port ${widget.session.portId ?? "-"}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Overview stat cards
          _sectionLabel('OVERVIEW'),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatCard(
                label: 'Total\nContainers',
                value: '$_totalContainers',
                icon: Icons.inventory_2_rounded,
                accent: AppColors.green,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Pending Move\nRequests',
                value: '${_moveRequests.length}',
                icon: Icons.pending_actions_rounded,
                accent: Colors.blue.shade700,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Yards with\nRequests',
                value: '$_yardsWithRequests',
                icon: Icons.warehouse_rounded,
                accent: AppColors.yellow,
                accentText: AppColors.textDark,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Total\nYards',
                value: '${_yards.length}',
                icon: Icons.grid_view_rounded,
                accent: AppColors.green,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Two-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('YARDS WITH PENDING REQUESTS'),
                    const SizedBox(height: 14),
                    _buildYardsPanel(),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('MOVE REQUESTS'),
                    const SizedBox(height: 14),
                    _buildRequestList(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.red,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  // ── Yards Panel ───────────────────────────────────────────────────────────

  Widget _buildYardsPanel() {
    final yardsWithRequests = _yards
        .where((y) => (_requestsByYard[y.yardId] ?? 0) > 0)
        .toList();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: yardsWithRequests.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 40,
                      color: AppColors.green,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'All clear — no pending requests',
                      style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: yardsWithRequests.map((yard) {
                final count = _requestsByYard[yard.yardId] ?? 0;
                return _YardCard(
                  yard: yard,
                  requestCount: count,
                  portName: widget.session.portDesc ?? '',
                  portId: widget.session.portId ?? yard.portId,
                  session: widget.session,
                  onReturn: _loadData,
                );
              }).toList(),
            ),
    );
  }

  // ── Request List ──────────────────────────────────────────────────────────

  Widget _buildRequestList() {
    final containers = _filtered;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade400, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.pending_actions_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pending Move Requests',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search container...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      isDense: true,
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 16,
                        color: Colors.white70,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: 14,
                                color: Colors.white70,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (containers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 44,
                      color: Colors.grey.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No move requests',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: containers.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (ctx, i) => _RequestTile(
                container: containers[i],
                onConfirm: () => _confirmRequest(containers[i]),
              ),
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 3),
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
      ),
    );
  }
}

// ── Yard Card ─────────────────────────────────────────────────────────────────

class _YardCard extends StatelessWidget {
  final Yard yard;
  final int requestCount;
  final String portName;
  final int portId;
  final Session session;
  final VoidCallback onReturn;

  const _YardCard({
    required this.yard,
    required this.requestCount,
    required this.portName,
    required this.portId,
    required this.session,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.warehouse_rounded, size: 30, color: Colors.blue.shade600),
          const SizedBox(height: 6),
          Text(
            'Yard ${yard.yardNumber}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$requestCount request${requestCount != 1 ? "s" : ""}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverYardScreen(
                    yard: yard,
                    portId: portId,
                    portName: portName,
                    session: session,
                  ),
                ),
              );
              onReturn();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'View Map',
                style: TextStyle(
                  color: AppColors.yellow,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Request Tile ──────────────────────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final ContainerModel container;
  final VoidCallback onConfirm;

  const _RequestTile({required this.container, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final c = container;
    final typeLabel = c.containerSizeId == 1
        ? '20ft'
        : c.containerSizeId == 2
        ? '40ft'
        : (c.type ?? '-');
    final isLaden = c.statusId == 1;
    final statusColor = isLaden ? Colors.amber.shade700 : Colors.red.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
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
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
                if (c.containerDesc != null && c.containerDesc!.isNotEmpty)
                  Text(
                    c.containerDesc!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            typeLabel,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isLaden ? 'Laden' : 'Empty',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: AppColors.yellow,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
