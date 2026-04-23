import 'package:flutter/material.dart';
import '../models/yard.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../models/row_model.dart';
import '../models/container_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class CustomerYardViewScreen extends StatefulWidget {
  final Yard yard;
  final int portId;
  final String portName;
  final int customerId;

  const CustomerYardViewScreen({
    super.key,
    required this.yard,
    required this.portId,
    required this.portName,
    required this.customerId,
  });

  @override
  State<CustomerYardViewScreen> createState() => _CustomerYardViewScreenState();
}

class _CustomerYardViewScreenState extends State<CustomerYardViewScreen> {
  final _api = ApiService();
  bool _loading = true;

  late Yard _yard;
  List<Block> _blocks = [];
  Map<int, List<Bay>> _baysByBlock = {};
  Map<int, List<RowModel>> _rowsByBay = {};
  Map<int, List<ContainerModel>> _containersByRow = {};

  // Lookup maps for full details dialog
  Map<int, Bay> _baysById = {};
  Map<int, RowModel> _rowsById = {};

  double _scale = 3.0;

  @override
  void initState() {
    super.initState();
    _yard = widget.yard;
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final blocks = await _api.getBlocks(widget.yard.yardId);
      final allContainers = await _api.getContainersByPort(widget.portId);

      final myContainers = allContainers
          .where((c) => c.customerId == widget.customerId && !c.isMovedOut)
          .toList();

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

      // Build flat lookup maps
      final Map<int, Bay> baysById = {
        for (final bay in allBays) bay.bayId: bay,
      };
      final Map<int, RowModel> rowsById = {
        for (final rows in rowsByBay.values)
          for (final row in rows) row.rowId: row,
      };

      final Map<int, List<ContainerModel>> byRow = {};
      for (final c in myContainers) {
        if (c.rowId != null) {
          byRow.putIfAbsent(c.rowId!, () => []).add(c);
        }
      }
      for (final list in byRow.values) {
        list.sort((a, b) => (a.tier ?? 0).compareTo(b.tier ?? 0));
      }

      setState(() {
        _blocks = blocks;
        _baysByBlock = baysByBlock;
        _rowsByBay = rowsByBay;
        _containersByRow = byRow;
        _baysById = baysById;
        _rowsById = rowsById;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // Step 1: Show tier list popup (if multiple containers stacked)
  void _showSlotTap(List<ContainerModel> stacked, Offset globalPos) {
    if (stacked.isEmpty) return;
    if (stacked.length == 1) {
      _showQuickView(stacked.first, globalPos);
      return;
    }
    // Multiple containers — show tier list
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => _TierPopup(
        containers: stacked,
        onClose: () => Navigator.pop(ctx),
        onSelect: (c) {
          Navigator.pop(ctx);
          _showQuickView(c, globalPos);
        },
      ),
    );
  }

  // Step 2: Quick view card (matches admin _buildDetails)
  void _showQuickView(ContainerModel c, Offset globalPos) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => _QuickViewPopup(
        container: c,
        onClose: () => Navigator.pop(ctx),
        onViewFull: () {
          Navigator.pop(ctx);
          _showFullDetails(c);
        },
      ),
    );
  }

  // Step 3: Full details dialog (matches admin YardContainerDetailsDialog)
  void _showFullDetails(ContainerModel c) {
    showDialog(
      context: context,
      builder: (_) => _FullDetailsDialog(
        container: c,
        portName: widget.portName,
        yardNumber: widget.yard.yardNumber,
        blocks: _blocks,
        baysById: _baysById,
        rowsById: _rowsById,
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
                'View Only',
                style: TextStyle(fontSize: 11, color: Colors.white),
              ),
              backgroundColor: AppColors.green,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildCanvas(),
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
    final bays = _baysByBlock[block.blockId] ?? [];
    final isVert = block.isVertical;
    final is40 = block.is40ft;

    final slotLong = (is40 ? k40ftWidth : k20ftWidth) * _scale;
    final slotShort = kContainerHeight * _scale;
    final cellW = isVert ? slotShort : slotLong;
    final cellH = isVert ? slotLong : slotShort;

    Widget blockWidget = _ReadOnlyBlockWidget(
      block: block,
      bays: bays,
      rowsByBay: _rowsByBay,
      containersByRow: _containersByRow,
      cellW: cellW,
      cellH: cellH,
      isVert: isVert,
      scale: _scale,
      onSlotTap: _showSlotTap,
    );

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Transform.rotate(angle: rotation, child: blockWidget),
    );
  }
}

// ── Read-only block widget ────────────────────────────────────────────────────

class _ReadOnlyBlockWidget extends StatelessWidget {
  final Block block;
  final List<Bay> bays;
  final Map<int, List<RowModel>> rowsByBay;
  final Map<int, List<ContainerModel>> containersByRow;
  final double cellW, cellH;
  final bool isVert;
  final double scale;
  final void Function(List<ContainerModel> stacked, Offset globalPos) onSlotTap;

  const _ReadOnlyBlockWidget({
    required this.block,
    required this.bays,
    required this.rowsByBay,
    required this.containersByRow,
    required this.cellW,
    required this.cellH,
    required this.isVert,
    required this.scale,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final blockName = block.blockName ?? 'Block ${block.blockNumber}';
    final bayGap = 2.5 * scale;
    final rowGap = 1.0 * scale;

    if (isVert) {
      final bayRows = bays.map((bay) {
        final rows = (rowsByBay[bay.bayId] ?? []).reversed.toList();
        final slotWidgets = <Widget>[];
        for (int i = 0; i < rows.length; i++) {
          if (i > 0) slotWidgets.add(SizedBox(width: rowGap));
          slotWidgets.add(
            _ReadOnlySlot(
              row: rows[i],
              containers: containersByRow[rows[i].rowId] ?? [],
              width: cellW,
              height: cellH,
              onSlotTap: onSlotTap,
            ),
          );
        }
        slotWidgets.add(
          Container(
            width: 14,
            alignment: Alignment.center,
            child: RotatedBox(
              quarterTurns: 1,
              child: Text(
                bay.bayNumber,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
        return Row(mainAxisSize: MainAxisSize.min, children: slotWidgets);
      }).toList();

      final bayRowsWithGaps = <Widget>[];
      for (int i = 0; i < bayRows.length; i++) {
        if (i > 0) bayRowsWithGaps.add(SizedBox(height: bayGap));
        bayRowsWithGaps.add(bayRows[i]);
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RotatedBox(
            quarterTurns: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.teal.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                blockName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: bayRowsWithGaps,
            ),
          ),
        ],
      );
    } else {
      final cols = bays.map((bay) {
        final rows = rowsByBay[bay.bayId] ?? [];
        final slotWidgets = <Widget>[
          SizedBox(
            width: cellW,
            height: 14,
            child: Center(
              child: Text(
                bay.bayNumber,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ];
        for (int i = 0; i < rows.length; i++) {
          if (i > 0) slotWidgets.add(SizedBox(height: rowGap));
          slotWidgets.add(
            _ReadOnlySlot(
              row: rows[i],
              containers: containersByRow[rows[i].rowId] ?? [],
              width: cellW,
              height: cellH,
              onSlotTap: onSlotTap,
            ),
          );
        }
        return Column(mainAxisSize: MainAxisSize.min, children: slotWidgets);
      }).toList();

      final colsWithGaps = <Widget>[];
      for (int i = 0; i < cols.length; i++) {
        if (i > 0) colsWithGaps.add(SizedBox(width: bayGap));
        colsWithGaps.add(cols[i]);
      }

      final blockGrid = Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: colsWithGaps),
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          blockGrid,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              blockName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade700,
              ),
            ),
          ),
        ],
      );
    }
  }
}

// ── Read-only slot cell ───────────────────────────────────────────────────────

class _ReadOnlySlot extends StatelessWidget {
  final RowModel row;
  final List<ContainerModel> containers;
  final double width, height;
  final void Function(List<ContainerModel> stacked, Offset globalPos) onSlotTap;

  const _ReadOnlySlot({
    required this.row,
    required this.containers,
    required this.width,
    required this.height,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final inYard = containers.where((c) => !c.isMovedOut).toList()
      ..sort((a, b) => (a.tier ?? 0).compareTo(b.tier ?? 0));
    final topContainer = inYard.isNotEmpty ? inYard.last : null;

    final bgColor = topContainer == null
        ? Colors.transparent
        : (topContainer.statusId == 1
              ? Colors.amber.shade300
              : Colors.red.shade300);

    Widget cell = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: topContainer == null
          ? Center(
              child: Text(
                '${row.rowNumber}',
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Stack(
              children: [
                Center(
                  child: Text(
                    topContainer.containerNumber,
                    style: const TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (inYard.length > 1)
                  Positioned(
                    top: 1,
                    right: 2,
                    child: Text(
                      '${inYard.length}/${row.maxStack}',
                      style: TextStyle(
                        fontSize: 6,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
    );

    if (inYard.isNotEmpty) {
      cell = GestureDetector(
        onTapUp: (d) => onSlotTap(inYard, d.globalPosition),
        child: cell,
      );
    }

    return cell;
  }
}

// ── Tier list popup (Step 1) ──────────────────────────────────────────────────

class _TierPopup extends StatelessWidget {
  final List<ContainerModel> containers;
  final VoidCallback onClose;
  final void Function(ContainerModel) onSelect;

  const _TierPopup({
    required this.containers,
    required this.onClose,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tier',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(Icons.close, color: Colors.red, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...containers.map(
                (c) => GestureDetector(
                  onTap: () => onSelect(c),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${c.tier}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: c.statusId == 1 ? Colors.amber : Colors.red,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.containerNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick view popup (Step 2) ─────────────────────────────────────────────────

class _QuickViewPopup extends StatelessWidget {
  final ContainerModel container;
  final VoidCallback onClose;
  final VoidCallback onViewFull;

  const _QuickViewPopup({
    required this.container,
    required this.onClose,
    required this.onViewFull,
  });

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  String _fmtDays(String? iso) {
    if (iso == null) return '-';
    try {
      final days = DateTime.now().difference(DateTime.parse(iso)).inDays;
      return '$days day${days != 1 ? "s" : ""}';
    } catch (_) {
      return '-';
    }
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = container;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(Icons.close, color: Colors.red, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  c.containerNumber,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _infoRow('Status:', c.statusId == 1 ? 'Laden' : 'Empty'),
              _infoRow(
                'Type:',
                c.containerSizeId == 1
                    ? '20ft'
                    : c.containerSizeId == 2
                    ? '40ft'
                    : (c.type ?? '-'),
              ),
              _infoRow('Tier:', '${c.tier ?? '-'}'),
              _infoRow('Date Moved:', _fmtDate(c.moveConfirmedDate)),
              _infoRow('Days in Slot:', _fmtDays(c.moveConfirmedDate)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onViewFull,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'View Full Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Full details dialog (Step 3) ──────────────────────────────────────────────

class _FullDetailsDialog extends StatelessWidget {
  final ContainerModel container;
  final String portName;
  final int yardNumber;
  final List<Block> blocks;
  final Map<int, Bay> baysById;
  final Map<int, RowModel> rowsById;

  const _FullDetailsDialog({
    required this.container,
    required this.portName,
    required this.yardNumber,
    required this.blocks,
    required this.baysById,
    required this.rowsById,
  });

  String _fmt(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  String _days(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.now().difference(DateTime.parse(iso)).inDays;
      return '$d day${d != 1 ? "s" : ""}';
    } catch (_) {
      return '-';
    }
  }

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
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

  @override
  Widget build(BuildContext context) {
    final c = container;
    final block = c.blockId != null
        ? blocks.where((b) => b.blockId == c.blockId).firstOrNull
        : null;
    final blockLabel =
        block?.blockName ??
        (block != null ? 'Block ${block.blockNumber}' : '-');
    final bay = c.bayId != null ? baysById[c.bayId] : null;
    final row = c.rowId != null ? rowsById[c.rowId] : null;
    final typeLabel = c.containerSizeId == 1
        ? '20ft'
        : c.containerSizeId == 2
        ? '40ft'
        : (c.type ?? '-');
    final statusLabel = c.statusId == 1 ? 'Laden' : 'Empty';
    final statusColor = c.statusId == 1
        ? Colors.amber.shade700
        : Colors.red.shade600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 360,
        ),
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section('GENERAL'),
                    _row('Status:', statusLabel, valueColor: statusColor),
                    _row('Date Moved:', _fmt(c.moveConfirmedDate)),
                    _row('Days in Slot:', _days(c.moveConfirmedDate)),
                    _row('Date in Yard:', _fmt(c.yardEntryDate)),
                    _row('Days in Yard:', _days(c.yardEntryDate)),
                    _row('Container Type:', typeLabel),
                    _row('Description:', c.containerDesc ?? '-'),
                    const SizedBox(height: 12),
                    _section('LOCATION'),
                    _row('Port:', portName),
                    _row('Yard:', 'Yard $yardNumber'),
                    _row('Block:', blockLabel),
                    _row('Bay:', bay?.bayNumber ?? '-'),
                    _row('Row:', row != null ? '${row.rowNumber}' : '-'),
                    _row('Tier:', c.tier != null ? '${c.tier}' : '-'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid painter ─────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(60)
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

// Constants
const double kContainerHeight = 8.0;
const double k20ftWidth = 20.0;
const double k40ftWidth = 40.0;
