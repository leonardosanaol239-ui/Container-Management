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
  // Only customer's containers, keyed by rowId
  Map<int, List<ContainerModel>> _containersByRow = {};

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

      // Filter to only this customer's containers
      final myContainers = allContainers
          .where((c) => c.customerId == widget.customerId && !c.isMovedOut)
          .toList();

      // Fetch bays and rows in parallel
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

      // Build containersByRow from customer containers only
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
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _showContainerDetails(ContainerModel c) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CONTAINER DETAILS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.redAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    c.containerNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow('Status:', c.statusId == 1 ? 'Laden' : 'Empty'),
                _detailRow('Type:', c.type ?? '-'),
                _detailRow(
                  'Size:',
                  c.containerSizeId == 1
                      ? '20ft'
                      : c.containerSizeId == 2
                      ? '40ft'
                      : '-',
                ),
                if (c.containerDesc != null && c.containerDesc!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Description:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c.containerDesc!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
      ],
    ),
  );

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
                color: Colors.white.withOpacity(0.45),
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
      onContainerTap: _showContainerDetails,
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
  final void Function(ContainerModel) onContainerTap;

  const _ReadOnlyBlockWidget({
    required this.block,
    required this.bays,
    required this.rowsByBay,
    required this.containersByRow,
    required this.cellW,
    required this.cellH,
    required this.isVert,
    required this.scale,
    required this.onContainerTap,
  });

  @override
  Widget build(BuildContext context) {
    final blockName = block.blockName ?? 'Block ${block.blockNumber}';

    // Match admin view gaps exactly: 2.5ft between bays, 1ft between rows
    final bayGap = 2.5 * scale;
    final rowGap = 1.0 * scale;

    if (isVert) {
      // VERTICAL: matches YardBlockWidget vertical layout
      // - Block name as teal pill rotated on the LEFT (outside block)
      // - Bays stacked top-to-bottom; each bay = row of slots + bay label on right
      // - White border around the bays grid
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
              onContainerTap: onContainerTap,
            ),
          );
        }
        // Bay label on the right
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
          // Block name as teal pill rotated on the left (matches admin)
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
          // Bays grid with white border (matches admin)
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
      // HORIZONTAL: matches YardBlockWidget horizontal layout
      // - Bay labels above each column
      // - White border around the block
      // - Block name as blueGrey pill BELOW the block (matches admin)
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
              onContainerTap: onContainerTap,
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

      // Block grid with white border (matches admin)
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
          // Block name as blueGrey pill below (matches admin)
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
  final void Function(ContainerModel) onContainerTap;

  const _ReadOnlySlot({
    required this.row,
    required this.containers,
    required this.width,
    required this.height,
    required this.onContainerTap,
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

    if (topContainer != null) {
      cell = GestureDetector(
        onTap: () => onContainerTap(topContainer),
        child: cell,
      );
    }

    return cell;
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

// Constants (same as yard_screen)
const double kContainerHeight = 8.0;
const double k20ftWidth = 20.0;
const double k40ftWidth = 40.0;
