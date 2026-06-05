import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/yard.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../models/row_model.dart';
import '../services/api_service.dart';
import '../widgets/nav_profile_btn.dart';
import 'customer_yard_view_screen.dart';
import 'landing_screen.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
class _C {
  static const navBg = Color(0xFF0B3D0F);
  static const green = Color(0xFF0B560D);
  static const red = Color(0xFFFF2800);
  static const blue = Color(0xFF1565C0);
  static const orange = Color(0xFFE65100);
  static const purple = Color(0xFF6A1B9A);
  static const bg = Color(0xFFF0F2EE);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8EAE4);
  static const textD = Color(0xFF1A1A0A);
  static const textM = Color(0xFF4A4A4A);
  static const textL = Color(0xFF757575);
  static const laden = Color(0xFF1565C0);
  static const empty = Color(0xFFFF2800);
}

// ── CustomerDashboardScreen ───────────────────────────────────────────────────
class CustomerDashboardScreen extends StatefulWidget {
  final Session session;
  const CustomerDashboardScreen({super.key, required this.session});

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  bool _loading = true;
  bool _refreshing = false;

  List<ContainerModel> _myContainers = [];
  Map<int, ({Yard yard, String portName, int portId})> _myYards = {};
  int? _resolvedCustomerId;

  Map<int, String> _portNames = {};
  Map<int, Block> _blocksById = {};
  Map<int, Bay> _baysById = {};
  Map<int, RowModel> _rowsById = {};

  Yard? _selectedYard;

  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);
    try {
      int? customerId = widget.session.customerId;
      if (customerId == null) {
        final customers = await _api.getCustomers();
        customerId = customers
            .where((c) => c.userId == widget.session.userId)
            .firstOrNull
            ?.customerId;
      }
      if (customerId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final ports = await _api.getPorts();
      final Map<int, String> portNames = {
        for (final p in ports) p.portId: p.portDesc,
      };
      final portContainerLists = await Future.wait(
        ports.map((p) => _api.getContainersByPort(p.portId)),
      );
      final allContainers = portContainerLists
          .expand((l) => l)
          .where((c) => c.customerId == customerId)
          .toList();

      final uniqueYardIds = allContainers
          .where((c) => c.yardId != null)
          .map((c) => c.yardId!)
          .toSet();
      final yardResults = await Future.wait(
        uniqueYardIds.map((id) => _api.getYardById(id)),
      );

      final Map<int, ({Yard yard, String portName, int portId})> yards = {};
      for (final yard in yardResults) {
        if (yard != null) {
          yards[yard.yardId] = (
            yard: yard,
            portName: portNames[yard.portId] ?? 'Port ${yard.portId}',
            portId: yard.portId,
          );
        }
      }

      final validYards = yardResults.whereType<Yard>().toList();
      final blockLists = await Future.wait(
        validYards.map((y) => _api.getBlocks(y.yardId)),
      );
      final allBlocks = blockLists.expand((l) => l).toList();
      final blocksById = {for (final b in allBlocks) b.blockId: b};
      final bayLists = await Future.wait(
        allBlocks.map((b) => _api.getBays(b.blockId)),
      );
      final allBays = bayLists.expand((l) => l).toList();
      final baysById = {for (final b in allBays) b.bayId: b};
      final rowLists = await Future.wait(
        allBays.map((b) => _api.getRows(b.bayId)),
      );
      final allRows = rowLists.expand((l) => l).toList();
      final rowsById = {for (final r in allRows) r.rowId: r};

      if (mounted) {
        setState(() {
          _myContainers = allContainers;
          _myYards = yards;
          _resolvedCustomerId = customerId;
          _portNames = portNames;
          _blocksById = blocksById;
          _baysById = baysById;
          _rowsById = rowsById;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _manualRefresh() async {
    if (_refreshing) return;
    if (mounted) setState(() => _refreshing = true);
    await _loadData();
    if (mounted) {
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Refreshed', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: _C.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  List<ContainerModel> get _filteredContainers {
    if (_searchQuery.isEmpty) return _myContainers;
    final q = _searchQuery.toLowerCase();
    return _myContainers
        .where((c) => c.containerNumber.toLowerCase().contains(q))
        .toList();
  }

  int get _laden => _myContainers.where((c) => c.statusId == 1).length;
  int get _empty => _myContainers.where((c) => c.statusId == 2).length;
  int get _inYard => _myContainers.where((c) => c.yardId != null).length;

  void _openYard(Yard yard, int portId, String portName) {
    if (_resolvedCustomerId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerYardViewScreen(
          yard: yard,
          portId: portId,
          portName: portName,
          customerId: _resolvedCustomerId!,
        ),
      ),
    );
  }

  void _logout() => Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LandingScreen()),
    (_) => false,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            color: _C.green,
                            strokeWidth: 4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Loading your containers...',
                          style: TextStyle(color: _C.textL, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _C.navBg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
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
          const SizedBox(width: 12),
          const Text(
            'Gothong Southern',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline, color: Colors.white, size: 13),
                SizedBox(width: 6),
                Text(
                  'Customer Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Refresh
          _navBtn(
            icon: _refreshing ? null : Icons.refresh_rounded,
            label: _refreshing ? 'Refreshing...' : 'Refresh',
            onTap: _refreshing ? null : _manualRefresh,
            loading: _refreshing,
          ),
          const SizedBox(width: 16),
          // Profile avatar dropdown
          NavProfileBtn(session: widget.session, onLogout: _logout),
        ],
      ),
    );
  }

  Widget _navBtn({
    IconData? icon,
    required String label,
    VoidCallback? onTap,
    bool outlined = false,
    bool loading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: outlined
                ? Border.all(color: Colors.white.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_C.green),
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 15, color: outlined ? Colors.white : _C.green),
              if (icon != null || loading) const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: outlined ? Colors.white : _C.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _C.green,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.business_center_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Welcome, ',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            widget.session.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('👋', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 7),
                            SizedBox(width: 5),
                            Text(
                              'Active Account',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // KPI row
          _sectionLabel('OVERVIEW'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  icon: Icons.inventory_2_outlined,
                  value: '${_myContainers.length}',
                  label: 'My Containers',
                  iconBg: _C.green,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiCard(
                  icon: Icons.warehouse_outlined,
                  value: '$_inYard',
                  label: 'In Yard',
                  iconBg: _C.orange,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiCard(
                  icon: Icons.check_circle_outline,
                  value: '$_laden',
                  label: 'Laden',
                  iconBg: _C.blue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiCard(
                  icon: Icons.radio_button_unchecked,
                  value: '$_empty',
                  label: 'Empty',
                  iconBg: _C.textL,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Two-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: yards
              SizedBox(width: 300, child: _buildYardsPanel()),
              const SizedBox(width: 20),
              // Right: container list
              Expanded(child: _buildContainerPanel()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYardsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('MY YARDS'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _myYards.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Icon(Icons.warehouse_outlined, size: 40, color: _C.textL),
                      const SizedBox(height: 8),
                      const Text(
                        'No containers in any yard',
                        style: TextStyle(color: _C.textL, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _myYards.values.map((entry) {
                    final isSelected =
                        _selectedYard?.yardId == entry.yard.yardId;
                    final count = _myContainers
                        .where((c) => c.yardId == entry.yard.yardId)
                        .length;
                    return GestureDetector(
                      onTap: () => setState(
                        () => _selectedYard = isSelected ? null : entry.yard,
                      ),
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _C.green.withValues(alpha: 0.08)
                              : _C.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? _C.green : _C.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _C.green.withValues(alpha: 0.12)
                                    : _C.bg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.warehouse,
                                size: 22,
                                color: isSelected ? _C.green : _C.textL,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.portName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _C.textL,
                              ),
                            ),
                            Text(
                              'Yard ${entry.yard.yardNumber}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? _C.green : _C.textD,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$count containers',
                              style: const TextStyle(
                                fontSize: 10,
                                color: _C.textL,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _openYard(
                                    entry.yard,
                                    entry.portId,
                                    entry.portName,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _C.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    elevation: 0,
                                    textStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Text('View Map'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildContainerPanel() {
    final containers = _filteredContainers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('MY CONTAINERS'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panel header + search
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                child: Row(
                  children: [
                    const Text(
                      'List of my containers',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _C.textD,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 220,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _C.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _C.border),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(fontSize: 13, color: _C.textD),
                        decoration: InputDecoration(
                          hintText: 'Search container...',
                          hintStyle: const TextStyle(
                            color: _C.textL,
                            fontSize: 12,
                          ),
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 16,
                            color: _C.textL,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    size: 14,
                                    color: _C.textL,
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tab bar
              TabBar(
                controller: _tabController,
                labelColor: _C.green,
                unselectedLabelColor: _C.textL,
                indicatorColor: _C.green,
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Undertime'),
                  Tab(text: 'Due'),
                  Tab(text: 'Overdue'),
                ],
              ),
              const Divider(height: 1, color: _C.border),
              // Tab views
              SizedBox(
                height: 460,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    containers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 48,
                                  color: _C.textL,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No containers found',
                                  style: TextStyle(
                                    color: _C.textL,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: containers.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, color: _C.border),
                            itemBuilder: (ctx, i) => _ContainerTile(
                              c: containers[i],
                              myYards: _myYards,
                              portNames: _portNames,
                              blocksById: _blocksById,
                              baysById: _baysById,
                              rowsById: _rowsById,
                            ),
                          ),
                    const Center(
                      child: Text(
                        'No undertime containers',
                        style: TextStyle(color: _C.textL, fontSize: 13),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'No due containers',
                        style: TextStyle(color: _C.textL, fontSize: 13),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'No overdue containers',
                        style: TextStyle(color: _C.textL, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String title) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: _C.green,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: _C.textM,
          letterSpacing: 1.2,
        ),
      ),
    ],
  );
}

// ── KPI Card ──────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconBg;
  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
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
    );
  }
}

// ── Container Tile ────────────────────────────────────────────────────────────
class _ContainerTile extends StatelessWidget {
  final ContainerModel c;
  final Map<int, ({Yard yard, String portName, int portId})> myYards;
  final Map<int, String> portNames;
  final Map<int, Block> blocksById;
  final Map<int, Bay> baysById;
  final Map<int, RowModel> rowsById;

  const _ContainerTile({
    required this.c,
    required this.myYards,
    required this.portNames,
    required this.blocksById,
    required this.baysById,
    required this.rowsById,
  });

  void _showDetails(BuildContext context) {
    final yardEntry = c.yardId != null ? myYards[c.yardId] : null;
    final portName =
        yardEntry?.portName ??
        (c.currentPortId != 0 ? portNames[c.currentPortId] ?? '-' : '-');
    final yardLabel = yardEntry != null
        ? 'Yard ${yardEntry.yard.yardNumber}'
        : '-';
    final block = c.blockId != null ? blocksById[c.blockId] : null;
    final blockLabel =
        block?.blockName ??
        (block != null ? 'Block ${block.blockNumber}' : '-');
    final bay = c.bayId != null ? baysById[c.bayId] : null;
    final bayLabel = bay?.bayNumber ?? '-';
    final row = c.rowId != null ? rowsById[c.rowId] : null;
    final rowLabel = row != null ? '${row.rowNumber}' : '-';
    final tierLabel = c.tier != null ? '${c.tier}' : '-';
    final typeLabel = c.containerSizeId == 1
        ? '20ft'
        : c.containerSizeId == 2
        ? '40ft'
        : (c.type ?? '-');
    final isLaden = c.statusId == 1;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                decoration: const BoxDecoration(
                  color: _C.navBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'CONTAINER DETAILS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _C.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        c.containerNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: (isLaden ? _C.laden : _C.empty).withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (isLaden ? _C.laden : _C.empty).withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            isLaden ? 'Laden' : 'Empty',
                            style: TextStyle(
                              color: isLaden ? _C.laden : _C.empty,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _C.bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            typeLabel,
                            style: const TextStyle(
                              color: _C.textM,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: _C.border),
                    const SizedBox(height: 10),
                    _dlSection('GENERAL INFO'),
                    _dlRow('Date Added:', _fmtDate(c.createdDate)),
                    _dlRow(
                      'Date Moved:',
                      _fmtDate(c.moveConfirmedDate ?? c.createdDate),
                    ),
                    _dlRow(
                      'Days in Slot:',
                      _daysSince(c.moveConfirmedDate ?? c.createdDate),
                    ),
                    _dlRow(
                      'Date in Yard:',
                      _fmtDate(c.yardEntryDate ?? c.createdDate),
                    ),
                    _dlRow(
                      'Days in Yard:',
                      _daysSince(c.yardEntryDate ?? c.createdDate),
                    ),
                    if (c.containerDesc != null && c.containerDesc!.isNotEmpty)
                      _dlRow('Description:', c.containerDesc!),
                    const SizedBox(height: 12),
                    _dlSection('LOCATION'),
                    _dlRow('Port:', portName),
                    _dlRow('Yard:', yardLabel),
                    _dlRow('Block:', blockLabel),
                    _dlRow('Bay:', bayLabel),
                    _dlRow('Row:', rowLabel),
                    _dlRow('Tier:', tierLabel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(String? d) {
    if (d == null) return '-';
    try {
      final dt = DateTime.parse(d);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  String _daysSince(String? d) {
    if (d == null) return '-';
    try {
      final days = DateTime.now().difference(DateTime.parse(d)).inDays;
      return '$days day${days != 1 ? "s" : ""}';
    } catch (_) {
      return '-';
    }
  }

  Widget _dlSection(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: _C.textL,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _dlRow(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _C.textM,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: valueColor ?? _C.textD,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isLaden = c.statusId == 1;
    final statusColor = isLaden ? _C.laden : _C.empty;
    final statusLabel = isLaden ? 'Laden' : 'Empty';
    final location = c.isMovedOut
        ? 'Moved out${c.boundTo != null ? " → ${c.boundTo}" : ""}'
        : c.yardId != null
        ? 'In yard'
        : 'Not in yard';

    return InkWell(
      onTap: () => _showDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _C.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: _C.green,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.containerNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _C.textD,
                    ),
                  ),
                  if (c.containerDesc != null && c.containerDesc!.isNotEmpty)
                    Text(
                      c.containerDesc!,
                      style: const TextStyle(fontSize: 11, color: _C.textL),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  location,
                  style: const TextStyle(fontSize: 10, color: _C.textL),
                ),
              ],
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 16, color: _C.textL),
          ],
        ),
      ),
    );
  }
}
