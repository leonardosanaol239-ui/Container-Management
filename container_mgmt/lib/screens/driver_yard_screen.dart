import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/session.dart';
import '../models/yard.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../models/row_model.dart';
import '../models/container_model.dart';
import '../models/customer_model.dart';
import 'yard_screen.dart' show YardBlockWidget;

class DriverYardScreen extends StatefulWidget {
  final Yard yard;
  final int portId;
  final String portName;
  final Session session;

  const DriverYardScreen({
    super.key,
    required this.yard,
    required this.portId,
    required this.portName,
    required this.session,
  });

  @override
  State<DriverYardScreen> createState() => _DriverYardScreenState();
}

class _DriverYardScreenState extends State<DriverYardScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  bool _loading = true;

  late Yard _yard;
  List<Block> _blocks = [];
  Map<int, List<Bay>> _baysByBlock = {};
  Map<int, List<RowModel>> _rowsByBay = {};
  // Confirmed containers (locationStatusId == 1) for the yard map
  Map<int, List<ContainerModel>> _confirmedByRow = {};
  // Move requests (locationStatusId == 3) sorted oldest first
  List<ContainerModel> _moveRequests = [];
  List<CustomerModel> _customers = [];

  double _scale = 3.0;
  late AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _yard = widget.yard;
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final blocks = await _api.getBlocks(widget.yard.yardId);
      final allContainers = await _api.getContainersByPort(widget.portId);
      final customers = await _api.getCustomers();

      final bayResults = await Future.wait(
        blocks.map((b) => _api.getBays(b.blockId)),
      );
      final Map<int, List<Bay>> baysByBlock = {};
      for (int i = 0; i < blocks.length; i++) {
        baysByBlock[blocks[i].blockId] = bayResults[i];
      }
      final allBays = bayResults.expand((b) => b).toList();
      final rowResults = await Future.wait(
        allBays.map((bay) => _api.getRows(bay.bayId)),
      );
      final Map<int, List<RowModel>> rowsByBay = {};
      for (int i = 0; i < allBays.length; i++) {
        rowsByBay[allBays[i].bayId] = rowResults[i];
      }

      // Confirmed map — only locationStatusId == 1
      final Map<int, List<ContainerModel>> confirmedByRow = {};
      for (final c in allContainers) {
        if (c.rowId != null &&
            c.yardId == widget.yard.yardId &&
            c.locationStatusId == 1) {
          confirmedByRow.putIfAbsent(c.rowId!, () => []).add(c);
        }
      }
      for (final list in confirmedByRow.values) {
        list.sort((a, b) => (a.tier ?? 0).compareTo(b.tier ?? 0));
      }

      // Move requests for this yard — oldest first by moveRequestDate
      final moveRequests =
          allContainers
              .where(
                (c) =>
                    c.locationStatusId == 3 && c.yardId == widget.yard.yardId,
              )
              .toList()
            ..sort((a, b) {
              final da = a.moveRequestDate;
              final db = b.moveRequestDate;
              if (da == null && db == null)
                return a.containerId.compareTo(b.containerId);
              if (da == null) return 1;
              if (db == null) return -1;
              return da.compareTo(db);
            });

      setState(() {
        _blocks = blocks;
        _baysByBlock = baysByBlock;
        _rowsByBay = rowsByBay;
        _confirmedByRow = confirmedByRow;
        _moveRequests = moveRequests;
        _customers = customers;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmRequest(ContainerModel c) async {
    try {
      await _api.confirmMoveRequest(c.containerId);
      await _loadAll();
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

  void _showRequestDetails(ContainerModel c) {
    showDialog(
      context: context,
      builder: (_) => _MoveRequestDetailDialog(
        container: c,
        yard: _yard,
        blocks: _blocks,
        baysByBlock: _baysByBlock,
        rowsByBay: _rowsByBay,
        confirmedByRow: _confirmedByRow,
        customers: _customers,
        onConfirm: () => _confirmRequest(c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.portName}  >  Yard ${widget.yard.yardNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              label: const Text(
                'Driver View',
                style: TextStyle(fontSize: 11, color: Colors.white),
              ),
              backgroundColor: Colors.blue.shade700,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Move Requests queue
                _buildMoveRequestsPanel(),
                const SizedBox(width: 16),
                // Right: Confirmed yard map
                Expanded(child: _buildCanvas()),
              ],
            ),
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.45),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.yellow,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoveRequestsPanel() {
    return Container(
      width: 210,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade700, width: 2.5),
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.pending_actions,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Move Requests',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_moveRequests.length}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _moveRequests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 40,
                          color: Colors.grey.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No pending requests',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    itemCount: _moveRequests.length,
                    itemBuilder: (ctx, i) {
                      final c = _moveRequests[i];
                      return _MoveRequestItem(
                        container: c,
                        onTap: () => _showRequestDetails(c),
                      );
                    },
                  ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(11),
              ),
            ),
            child: const Text(
              'Tap to view & confirm',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    final yardW = (_yard.yardWidth ?? 300).toDouble();
    final yardH = (_yard.yardHeight ?? 170).toDouble();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final availW = constraints.maxWidth == double.infinity
            ? 800.0
            : constraints.maxWidth;
        final availH = constraints.maxHeight == double.infinity
            ? 500.0
            : constraints.maxHeight;
        final fitScale = (availW / yardW) < (availH / yardH)
            ? (availW / yardW)
            : (availH / yardH);
        if (_scale == 3.0) _scale = fitScale;
        final cw = yardW * _scale;
        final ch = yardH * _scale;

        return Container(
          width: availW,
          height: availH,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.hardEdge,
          child: InteractiveViewer(
            minScale: 0.3,
            maxScale: 6.0,
            panEnabled: true,
            constrained: false,
            boundaryMargin: EdgeInsets.symmetric(
              horizontal: availW * 0.4,
              vertical: availH * 0.4,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: cw,
                  height: ch,
                  decoration: BoxDecoration(
                    color: _yard.imagePath != null ? null : Colors.grey[300],
                    border: Border.all(color: Colors.grey, width: 1),
                    borderRadius: BorderRadius.circular(8),
                    image: _yard.imagePath != null
                        ? DecorationImage(
                            image: NetworkImage(
                              '${ApiService.baseUrl.replaceAll('/api', '')}${_yard.imagePath}',
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: CustomPaint(painter: _GridPainter()),
                ),
                ..._blocks.map((b) => _buildBlock(b)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlock(Block block) {
    final offsetFt = Offset(
      (block.posX ?? 10).toDouble(),
      (block.posY ?? 10).toDouble(),
    );
    final offset = Offset(offsetFt.dx * _scale, offsetFt.dy * _scale);
    final rotation = block.rotation;

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Transform.rotate(
        angle: rotation,
        child: YardBlockWidget(
          block: block,
          baysByBlock: _baysByBlock,
          rowsByBay: _rowsByBay,
          containersByRow: _confirmedByRow,
          highlightedRowId: null,
          blinkCtrl: _blinkCtrl,
          editMode: false,
          selectedRowId: null,
          scaleX: _scale,
          scaleY: _scale,
          onSlotTap: null,
          onSlotDrop: null,
          onSelectRow: null,
          onAddBay: null,
          onRemoveBay: null,
          onDeleteBlock: null,
          rotateHandle: null,
          onAddRow: null,
          onRemoveRow: null,
        ),
      ),
    );
  }
}

// ── Move Request Item ─────────────────────────────────────────────────────────

class _MoveRequestItem extends StatelessWidget {
  final ContainerModel container;
  final VoidCallback onTap;

  const _MoveRequestItem({required this.container, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLaden = container.statusId == 1;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 40,
              decoration: BoxDecoration(
                color: isLaden ? AppColors.yellow : AppColors.red,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isLaden ? AppColors.yellow : AppColors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isLaden ? 'Laden' : 'Empty',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isLaden ? AppColors.textDark : Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        container.type ?? '',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Con#: ${container.containerNumber}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid Painter ──────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Move Request Detail Dialog ────────────────────────────────────────────────

class _MoveRequestDetailDialog extends StatefulWidget {
  final ContainerModel container;
  final Yard yard;
  final List<Block> blocks;
  final Map<int, List<Bay>> baysByBlock;
  final Map<int, List<RowModel>> rowsByBay;
  final Map<int, List<ContainerModel>> confirmedByRow;
  final List<CustomerModel> customers;
  final VoidCallback onConfirm;

  const _MoveRequestDetailDialog({
    required this.container,
    required this.yard,
    required this.blocks,
    required this.baysByBlock,
    required this.rowsByBay,
    required this.confirmedByRow,
    required this.customers,
    required this.onConfirm,
  });

  @override
  State<_MoveRequestDetailDialog> createState() =>
      _MoveRequestDetailDialogState();
}

class _MoveRequestDetailDialogState extends State<_MoveRequestDetailDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkCtrl;
  double _scale = 3.0;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  // Resolve helpers
  Block? _findBlock(int? blockId) => blockId == null
      ? null
      : widget.blocks.where((b) => b.blockId == blockId).firstOrNull;

  Bay? _findBay(int? bayId) {
    if (bayId == null) return null;
    for (final list in widget.baysByBlock.values) {
      for (final b in list) {
        if (b.bayId == bayId) return b;
      }
    }
    return null;
  }

  RowModel? _findRow(int? rowId) {
    if (rowId == null) return null;
    for (final list in widget.rowsByBay.values) {
      for (final r in list) {
        if (r.rowId == rowId) return r;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.container;
    final fromHolding = c.prevYardId == null && c.prevBlockId == null;

    final toBlock = _findBlock(c.blockId);
    final toBay = _findBay(c.bayId);
    final toRow = _findRow(c.rowId);

    final fromBlock = _findBlock(c.prevBlockId);
    final fromBay = _findBay(c.prevBayId);
    final fromRow = _findRow(c.prevRowId);

    final customer = c.customerId != null
        ? widget.customers
              .where((cu) => cu.customerId == c.customerId)
              .firstOrNull
        : null;
    final typeLabel = c.containerSizeId == 1
        ? '20ft'
        : c.containerSizeId == 2
        ? '40ft'
        : (c.type ?? '-');

    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  const Text(
                    'Move Request for:',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    c.containerNumber,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
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
            const SizedBox(height: 12),
            // Body: left panel + map
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: details panel
                  SizedBox(
                    width: 220,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Move To
                          _sectionHeader('Move To', Colors.red.shade600),
                          const SizedBox(height: 8),
                          _locRow('Yard:', 'Yard ${widget.yard.yardNumber}'),
                          _locRow(
                            'Block:',
                            toBlock?.blockName ??
                                (toBlock != null
                                    ? 'Block ${toBlock.blockNumber}'
                                    : '-'),
                          ),
                          _locRow('Bay:', toBay?.bayNumber ?? '-'),
                          _locRow(
                            'Row:',
                            toRow != null ? '${toRow.rowNumber}' : '-',
                          ),
                          _locRow('Tier:', c.tier != null ? '${c.tier}' : '-'),
                          const SizedBox(height: 16),
                          // Move From
                          _sectionHeader(
                            'Move From',
                            fromHolding ? Colors.grey.shade600 : Colors.green,
                          ),
                          const SizedBox(height: 8),
                          if (fromHolding) ...[
                            _locRow('Yard:', '-', grayed: true),
                            _locRow('Block:', '-', grayed: true),
                            _locRow('Bay:', '-', grayed: true),
                            _locRow('Row:', '-', grayed: true),
                            _locRow('Tier:', '-', grayed: true),
                            const Text(
                              '(Holding Area)',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ] else ...[
                            _locRow('Yard:', 'Yard ${widget.yard.yardNumber}'),
                            _locRow(
                              'Block:',
                              fromBlock?.blockName ??
                                  (fromBlock != null
                                      ? 'Block ${fromBlock.blockNumber}'
                                      : '-'),
                            ),
                            _locRow('Bay:', fromBay?.bayNumber ?? '-'),
                            _locRow(
                              'Row:',
                              fromRow != null ? '${fromRow.rowNumber}' : '-',
                            ),
                            _locRow(
                              'Tier:',
                              c.prevTier != null ? '${c.prevTier}' : '-',
                            ),
                          ],
                          const SizedBox(height: 16),
                          _locRow('Customer:', customer?.fullName ?? '-'),
                          _locRow('Type:', typeLabel),
                          _locRow('Desc:', c.containerDesc ?? '-'),
                        ],
                      ),
                    ),
                  ),
                  // Right: interactive map
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
                      child: _buildMap(c),
                    ),
                  ),
                ],
              ),
            ),
            // Confirm button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );

  Widget _locRow(String label, String value, {bool grayed = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              color: grayed ? Colors.grey : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: grayed ? Colors.grey.shade600 : Colors.white60,
              fontSize: 11,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildMap(ContainerModel c) {
    final yardW = (widget.yard.yardWidth ?? 300).toDouble();
    final yardH = (widget.yard.yardHeight ?? 170).toDouble();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final availW = constraints.maxWidth;
        final availH = constraints.maxHeight;
        final fitScale = (availW / yardW) < (availH / yardH)
            ? (availW / yardW)
            : (availH / yardH);
        if (_scale == 3.0) _scale = fitScale;
        final cw = yardW * _scale;
        final ch = yardH * _scale;

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade700),
          ),
          clipBehavior: Clip.hardEdge,
          child: InteractiveViewer(
            minScale: 0.3,
            maxScale: 8.0,
            panEnabled: true,
            constrained: false,
            boundaryMargin: EdgeInsets.symmetric(
              horizontal: availW * 0.4,
              vertical: availH * 0.4,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Yard background
                Container(
                  width: cw,
                  height: ch,
                  decoration: BoxDecoration(
                    color: widget.yard.imagePath != null
                        ? null
                        : Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                    image: widget.yard.imagePath != null
                        ? DecorationImage(
                            image: NetworkImage(
                              '${ApiService.baseUrl.replaceAll('/api', '')}${widget.yard.imagePath}',
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: CustomPaint(painter: _GridPainter()),
                ),
                // Base confirmed map — Move To slot blinks red via highlightedRowId
                ...widget.blocks.map(
                  (b) => _buildMapBlock(b, c, c.rowId, Colors.red, false),
                ),
                // Move From slot — green blink overlay
                if (c.prevRowId != null &&
                    !(c.prevYardId == null && c.prevBlockId == null))
                  ...widget.blocks.map(
                    (b) =>
                        _buildMapBlock(b, c, c.prevRowId, Colors.green, true),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapBlock(
    Block block,
    ContainerModel c,
    int? highlightedRowId,
    Color? highlightColor,
    bool highlightOnly,
  ) {
    final offsetFt = Offset(
      (block.posX ?? 10).toDouble(),
      (block.posY ?? 10).toDouble(),
    );
    final offset = Offset(offsetFt.dx * _scale, offsetFt.dy * _scale);

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Transform.rotate(
        angle: block.rotation,
        child: YardBlockWidget(
          block: block,
          baysByBlock: widget.baysByBlock,
          rowsByBay: widget.rowsByBay,
          containersByRow: widget.confirmedByRow,
          highlightedRowId: highlightedRowId,
          highlightColor: highlightColor,
          highlightOnly: highlightOnly,
          blinkCtrl: _blinkCtrl,
          editMode: false,
          selectedRowId: null,
          scaleX: _scale,
          scaleY: _scale,
          onSlotTap: null,
          onSlotDrop: null,
          onSelectRow: null,
          onAddBay: null,
          onRemoveBay: null,
          onDeleteBlock: null,
          rotateHandle: null,
          onAddRow: null,
          onRemoveRow: null,
        ),
      ),
    );
  }
}
