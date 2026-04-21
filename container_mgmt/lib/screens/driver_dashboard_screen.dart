import 'package:flutter/material.dart';
import 'dart:async';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/yard.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'landing_screen.dart';
import 'driver_yard_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  final Session session;
  const DriverDashboardScreen({super.key, required this.session});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final _api = ApiService();
  bool _loading = true;

  List<ContainerModel> _moveRequests = [];
  List<Yard> _yards = [];
  // yardId -> count of move requests
  Map<int, int> _requestsByYard = {};

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
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

      // Only containers with locationStatusId == 3 (Move Request) — oldest first
      final moveRequests =
          allContainers.where((c) => c.locationStatusId == 3).toList()
            ..sort((a, b) {
              final da = a.moveRequestDate;
              final db = b.moveRequestDate;
              if (da == null && db == null)
                return a.containerId.compareTo(b.containerId);
              if (da == null) return 1;
              if (db == null) return -1;
              return da.compareTo(db);
            });

      // Count move requests per yard
      final Map<int, int> byYard = {};
      for (final c in moveRequests) {
        if (c.yardId != null) {
          byYard[c.yardId!] = (byYard[c.yardId!] ?? 0) + 1;
        }
      }

      setState(() {
        _moveRequests = moveRequests;
        _yards = yards;
        _requestsByYard = byYard;
        _loading = false;
      });
    } catch (e) {
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
      final allContainers = results[0] as List<ContainerModel>;
      final yards = results[1] as List<Yard>;
      final moveRequests =
          allContainers.where((c) => c.locationStatusId == 3).toList()
            ..sort((a, b) {
              final da = a.moveRequestDate;
              final db = b.moveRequestDate;
              if (da == null && db == null)
                return a.containerId.compareTo(b.containerId);
              if (da == null) return 1;
              if (db == null) return -1;
              return da.compareTo(db);
            });
      final Map<int, int> byYard = {};
      for (final c in moveRequests) {
        if (c.yardId != null) byYard[c.yardId!] = (byYard[c.yardId!] ?? 0) + 1;
      }
      if (!mounted) return;
      setState(() {
        _moveRequests = moveRequests;
        _yards = yards;
        _requestsByYard = byYard;
      });
    } catch (_) {}
  }

  List<ContainerModel> get _filtered {
    if (_searchQuery.isEmpty) return _moveRequests;
    final q = _searchQuery.toLowerCase();
    return _moveRequests
        .where((c) => c.containerNumber.toLowerCase().contains(q))
        .toList();
  }

  int get _yardsWithRequests =>
      _requestsByYard.values.where((v) => v > 0).length;

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingScreen()),
      (_) => false,
    );
  }

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
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
              'Logged in as Driver',
              style: TextStyle(
                color: AppColors.yellow,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const Spacer(),
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
          Text(
            'Welcome: ${widget.session.fullName}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.session.portDesc ?? 'Port ${widget.session.portId ?? "-"}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatCards(),
                    const SizedBox(height: 24),
                    _buildYardsSection(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right column — move request list
              Expanded(flex: 5, child: _buildRequestList()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Move\nRequests',
            value: '${_moveRequests.length}',
            icon: Icons.pending_actions,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Yards with\nMove Requests',
            value: '$_yardsWithRequests',
            icon: Icons.warehouse_outlined,
            color: AppColors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildYardsSection() {
    final yardsWithRequests = _yards
        .where((y) => (_requestsByYard[y.yardId] ?? 0) > 0)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shows Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: yardsWithRequests.isEmpty
              ? const Center(
                  child: Text(
                    'No move requests in any yard',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: yardsWithRequests.map((yard) {
                    final count = _requestsByYard[yard.yardId] ?? 0;
                    return _YardRequestCard(
                      yard: yard,
                      requestCount: count,
                      portName: widget.session.portDesc ?? '',
                      portId: widget.session.portId ?? yard.portId,
                      session: widget.session,
                      onReturn: _loadData,
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildRequestList() {
    final containers = _filtered;
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Text(
                  'List of Move Requests',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search container...',
                      hintStyle: const TextStyle(fontSize: 12),
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
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
          const Divider(height: 1),
          if (containers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No move requests',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: containers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) => _MoveRequestTile(
                c: containers[i],
                onConfirm: () => _confirmRequest(containers[i]),
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
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Row(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Yard Request Card ─────────────────────────────────────────────────────────

class _YardRequestCard extends StatelessWidget {
  final Yard yard;
  final int requestCount;
  final String portName;
  final int portId;
  final Session session;
  final VoidCallback onReturn;

  const _YardRequestCard({
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
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade300, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(Icons.warehouse, size: 28, color: Colors.blue.shade600),
          const SizedBox(height: 6),
          Text(
            '$portName\nYard ${yard.yardNumber}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          const SizedBox(height: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(4),
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

// ── Move Request Tile ─────────────────────────────────────────────────────────

class _MoveRequestTile extends StatelessWidget {
  final ContainerModel c;
  final VoidCallback onConfirm;

  const _MoveRequestTile({required this.c, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final typeLabel = c.containerSizeId == 1
        ? '20ft'
        : c.containerSizeId == 2
        ? '40ft'
        : (c.type ?? '-');
    final statusLabel = c.statusId == 1 ? 'Laden' : 'Empty';
    final statusColor = c.statusId == 1
        ? Colors.amber.shade700
        : Colors.red.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.blue,
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
              statusLabel,
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
