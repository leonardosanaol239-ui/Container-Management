import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/container_model.dart';
import '../models/yard.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../models/row_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'customer_yard_view_screen.dart';
import 'landing_screen.dart';

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

  List<ContainerModel> _myContainers = [];
  Map<int, ({Yard yard, String portName, int portId})> _myYards = {};
  int? _resolvedCustomerId;

  // Location lookup maps
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
    setState(() => _loading = true);
    try {
      // Resolve customerId — the login session may not include it,
      // so we look up the customer record by userId as a fallback.
      int? customerId = widget.session.customerId;
      if (customerId == null) {
        final customers = await _api.getCustomers();
        final match = customers
            .where((c) => c.userId == widget.session.userId)
            .firstOrNull;
        customerId = match?.customerId;
      }

      if (customerId == null) {
        setState(() => _loading = false);
        return;
      }

      // Load all ports, then all containers across all ports
      final ports = await _api.getPorts();
      final Map<int, String> portNames = {
        for (final p in ports) p.portId: p.portDesc,
      };

      // Fetch containers from all ports in parallel
      final portContainerLists = await Future.wait(
        ports.map((p) => _api.getContainersByPort(p.portId)),
      );
      final allContainers = portContainerLists
          .expand((list) => list)
          .where((c) => c.customerId == customerId)
          .toList();

      // Find unique yards where customer has containers
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
          final portName = portNames[yard.portId] ?? 'Port ${yard.portId}';
          yards[yard.yardId] = (
            yard: yard,
            portName: portName,
            portId: yard.portId,
          );
        }
      }

      // Load blocks/bays/rows for all relevant yards so we can resolve location labels
      final validYards = yardResults.whereType<Yard>().toList();
      final blockLists = await Future.wait(
        validYards.map((y) => _api.getBlocks(y.yardId)),
      );
      final allBlocks = blockLists.expand((l) => l).toList();
      final Map<int, Block> blocksById = {
        for (final b in allBlocks) b.blockId: b,
      };

      final bayLists = await Future.wait(
        allBlocks.map((b) => _api.getBays(b.blockId)),
      );
      final allBays = bayLists.expand((l) => l).toList();
      final Map<int, Bay> baysById = {for (final b in allBays) b.bayId: b};

      final rowLists = await Future.wait(
        allBays.map((b) => _api.getRows(b.bayId)),
      );
      final allRows = rowLists.expand((l) => l).toList();
      final Map<int, RowModel> rowsById = {for (final r in allRows) r.rowId: r};

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
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<ContainerModel> get _filteredContainers {
    if (_searchQuery.isEmpty) return _myContainers;
    final q = _searchQuery.toLowerCase();
    return _myContainers
        .where((c) => c.containerNumber.toLowerCase().contains(q))
        .toList();
  }

  List<ContainerModel> get _containersInSelectedYard {
    if (_selectedYard == null) return [];
    return _myContainers
        .where((c) => c.yardId == _selectedYard!.yardId)
        .toList();
  }

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
              'Logged in as Customer',
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
              // Right column — container list
              Expanded(flex: 5, child: _buildContainerList()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final yardCount = _selectedYard == null
        ? 0
        : _containersInSelectedYard.length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Number of Containers\nbelonging to you',
            value: '${_myContainers.length}',
            icon: Icons.inventory_2_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: _selectedYard == null
                ? 'Select a yard to see\ncontainers in that yard'
                : 'Containers in\n${_selectedYard!.yardId == 0 ? "selected yard" : "${_myYards[_selectedYard!.yardId]?.portName ?? ""} Yard ${_selectedYard!.yardNumber}"}',
            value: _selectedYard == null ? '-' : '$yardCount',
            icon: Icons.warehouse_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildYardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Yards Where my Containers are',
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
          child: _myYards.isEmpty
              ? const Center(
                  child: Text(
                    'No containers in any yard',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _myYards.values.map((entry) {
                    final isSelected =
                        _selectedYard?.yardId == entry.yard.yardId;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedYard = null;
                          } else {
                            _selectedYard = entry.yard;
                          }
                        });
                      },
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.green.withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.green
                                : Colors.grey.shade400,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.warehouse,
                              size: 28,
                              color: isSelected
                                  ? AppColors.green
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${entry.portName}\nYard ${entry.yard.yardNumber}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.green
                                    : AppColors.textDark,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => _openYard(
                                  entry.yard,
                                  entry.portId,
                                  entry.portName,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
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

  Widget _buildContainerList() {
    final containers = _filteredContainers;
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9C27B0), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Text(
                  'List of my containers',
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
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF9C27B0),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF9C27B0),
            indicatorWeight: 2,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Undertime'),
              Tab(text: 'Due'),
              Tab(text: 'Overdue'),
            ],
          ),
          const Divider(height: 1),
          // Tab content
          SizedBox(
            height: 420,
            child: TabBarView(
              controller: _tabController,
              children: [
                // All
                containers.isEmpty
                    ? const Center(
                        child: Text(
                          'No containers found',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        itemCount: containers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) => _ContainerListTile(
                          c: containers[i],
                          myYards: _myYards,
                          portNames: _portNames,
                          blocksById: _blocksById,
                          baysById: _baysById,
                          rowsById: _rowsById,
                        ),
                      ),
                // Undertime
                const Center(
                  child: Text(
                    'Undertime',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                // Due
                const Center(
                  child: Text(
                    'Due',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                // Overdue
                const Center(
                  child: Text(
                    'Overdue',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
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

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: AppColors.green),
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

// ── Container List Tile ───────────────────────────────────────────────────────

class _ContainerListTile extends StatelessWidget {
  final ContainerModel c;
  final Map<int, ({Yard yard, String portName, int portId})> myYards;
  final Map<int, String> portNames;
  final Map<int, Block> blocksById;
  final Map<int, Bay> baysById;
  final Map<int, RowModel> rowsById;

  const _ContainerListTile({
    required this.c,
    required this.myYards,
    required this.portNames,
    required this.blocksById,
    required this.baysById,
    required this.rowsById,
  });

  void _showDetails(BuildContext context) {
    // Resolve location labels
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
    final statusLabel = c.statusId == 1 ? 'Laden' : 'Empty';
    final statusColor = c.statusId == 1
        ? Colors.amber.shade700
        : Colors.red.shade600;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E2E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CONTAINER DETAILS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              c.containerNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        color: Colors.redAccent,
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
                    _section('GENERAL'),
                    _row('Status:', statusLabel, valueColor: statusColor),
                    _row('Date Moved:', _formatDate(c.moveConfirmedDate)),
                    _row('Days in Slot:', _daysInSlot(c.moveConfirmedDate)),
                    _row('Date in Yard:', _formatDate(c.yardEntryDate)),
                    _row('Days in Yard:', _daysInSlot(c.yardEntryDate)),
                    _row('Container Type:', typeLabel),
                    if (c.containerDesc != null && c.containerDesc!.isNotEmpty)
                      _row('Description:', c.containerDesc!),
                    const SizedBox(height: 12),
                    _section('LOCATION'),
                    _row('Port:', portName),
                    _row('Yard:', yardLabel),
                    _row('Block:', blockLabel),
                    _row('Bay:', bayLabel),
                    _row('Row:', rowLabel),
                    _row('Tier:', tierLabel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '-';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  String _daysInSlot(String? isoDate) {
    if (isoDate == null) return '-';
    try {
      final dt = DateTime.parse(isoDate);
      final days = DateTime.now().difference(dt).inDays;
      return '$days day${days != 1 ? "s" : ""}';
    } catch (_) {
      return '-';
    }
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade500,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: valueColor ?? Colors.grey.shade700,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final statusColor = c.statusId == 1
        ? Colors.amber.shade700
        : Colors.red.shade600;
    final statusLabel = c.statusId == 1 ? 'Laden' : 'Empty';
    String location = 'Not in yard';
    if (c.isMovedOut) {
      location = 'Moved out${c.boundTo != null ? " → ${c.boundTo}" : ""}';
    } else if (c.yardId != null) {
      location = 'In yard';
    }

    return InkWell(
      onTap: () => _showDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
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
                const SizedBox(height: 3),
                Text(
                  location,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

