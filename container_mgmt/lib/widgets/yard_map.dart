import 'package:flutter/material.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../models/row_model.dart';
import '../models/container_model.dart';

class YardMap extends StatefulWidget {
  final int yardNumber; // Add yard number to determine background
  final String? yardImagePath; // Optional image path from database
  final List<Block> blocks;
  final Map<int, List<Bay>> baysByBlock;
  final Map<int, List<RowModel>> rowsByBay;
  final Map<int, List<ContainerModel>> containersByRow;
  final int? highlightedRowId;
  final void Function(BuildContext, int, Offset) onSlotTap;
  final Future<void> Function(ContainerModel, int) onContainerDropped;

  const YardMap({
    super.key,
    required this.yardNumber,
    this.yardImagePath,
    required this.blocks,
    required this.baysByBlock,
    required this.rowsByBay,
    required this.containersByRow,
    required this.highlightedRowId,
    required this.onSlotTap,
    required this.onContainerDropped,
  });

  @override
  State<YardMap> createState() => _YardMapState();
}

class _YardMapState extends State<YardMap> with SingleTickerProviderStateMixin {
  late AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use imagePath from database, fallback to yard-specific images
    String backgroundImage;

    if (widget.yardImagePath != null && widget.yardImagePath!.isNotEmpty) {
      // Use the image path from database
      backgroundImage = 'assets/${widget.yardImagePath}';
    } else {
      // Fallback: Use yard-specific images based on yard number
      if (widget.yardNumber == 1) {
        backgroundImage = 'assets/Y1.png';
      } else if (widget.yardNumber == 2) {
        backgroundImage = 'assets/Y2.png';
      } else if (widget.yardNumber == 3) {
        backgroundImage = 'assets/Y3.png';
      } else if (widget.yardNumber == 4) {
        backgroundImage = 'assets/Y4.png';
      } else {
        backgroundImage = 'assets/Y4.png'; // Default fallback
      }
    }

    print('🖼️ Loading yard background: $backgroundImage');
    print('🖼️ Yard Number: ${widget.yardNumber}');
    print('🖼️ Yard Image Path from DB: ${widget.yardImagePath}');

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          // ── Aerial photo background ──
          Positioned.fill(
            child:
                widget.yardNumber == 1 ||
                    widget.yardNumber == 2 ||
                    widget.yardNumber == 3 ||
                    widget.yardNumber == 4
                ? Image.asset(
                    backgroundImage,
                    fit: BoxFit.fill,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load: $backgroundImage',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : RotatedBox(
                    quarterTurns: 1,
                    child: Image.asset(
                      backgroundImage,
                      fit: BoxFit.fill,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load: $backgroundImage',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          // ── Grid content ──
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(60, 30, 60, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column: Block1, gap, Block2+3, gap, Block4
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBlock(1),
                            const SizedBox(height: 50),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildBlock(2)),
                                const SizedBox(width: 24),
                                Expanded(child: _buildBlock(3)),
                              ],
                            ),
                            const SizedBox(height: 50),
                            _buildBlock(4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right column: Block 5 aligned to middle row
                      Column(
                        children: [
                          // Spacer to push block5 down to align with block2/3 row
                          SizedBox(height: _block1Height()),
                          const SizedBox(height: 50),
                          _buildBlock5(),
                        ],
                      ),
                    ],
                  ),
                ],
              ), // Column
            ), // Padding
          ), // Positioned.fill
        ],
      ),
    );
  }

  // Approximate height of block1 so block5 aligns with block2/3
  double _block1Height() {
    final block = widget.blocks.firstWhere(
      (b) => b.blockNumber == 1,
      orElse: () => Block(blockId: -1, blockNumber: 1, yardId: 1, portId: 1),
    );
    if (block.blockId == -1) return 60;
    final rows = _rowCount(block.blockId);
    // header row ~14 + each row ~20 + label ~18 + padding 12
    return 14 + rows * 20 + 18 + 12.0;
  }

  Widget _buildBlock(int blockNumber) {
    final block = widget.blocks.firstWhere(
      (b) => b.blockNumber == blockNumber,
      orElse: () =>
          Block(blockId: -1, blockNumber: blockNumber, yardId: 1, portId: 1),
    );
    if (block.blockId == -1) return const SizedBox.shrink();

    final bays = widget.baysByBlock[block.blockId] ?? [];

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bay number headers
          Row(
            children: [
              const SizedBox(width: 14),
              ...bays.map(
                (bay) => SizedBox(
                  width: 60.6,
                  height: 24.4,
                  child: Center(
                    child: Text(
                      bay.bayNumber,
                      style: const TextStyle(fontSize: 8, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Rows
          ...List.generate(_rowCount(block.blockId), (rowIdx) {
            return Row(
              children: [
                SizedBox(
                  width: 14,
                  child: Text(
                    '${rowIdx + 1}',
                    style: const TextStyle(fontSize: 8, color: Colors.white),
                  ),
                ),
                ...bays.map((bay) {
                  final rows = widget.rowsByBay[bay.bayId] ?? [];
                  if (rowIdx >= rows.length) {
                    return const SizedBox(width: 24.4);
                  }
                  final row = rows[rowIdx];
                  return SizedBox(
                    width: 60.6,
                    height: 24.4,
                    child: _SlotCell(
                      row: row,
                      containers: widget.containersByRow[row.rowId] ?? [],
                      isHighlighted: widget.highlightedRowId == row.rowId,
                      blinkCtrl: _blinkCtrl,
                      onTap: (offset) =>
                          widget.onSlotTap(context, row.rowId, offset),
                      onDrop: (c) => widget.onContainerDropped(c, row.rowId),
                    ),
                  );
                }),
              ],
            );
          }),
          const SizedBox(height: 3),
          Center(
            child: Text(
              block.blockDesc ?? 'Block $blockNumber',
              style: const TextStyle(fontSize: 8, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlock5() {
    final block = widget.blocks.firstWhere(
      (b) => b.blockNumber == 5,
      orElse: () => Block(blockId: -1, blockNumber: 5, yardId: 1, portId: 1),
    );
    if (block.blockId == -1) return const SizedBox.shrink();

    final bays = widget.baysByBlock[block.blockId] ?? [];

    return Container(
      width: 62.8,
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bay headers as columns
          Row(
            children: [
              const SizedBox(width: 14),
              ...bays.map(
                (bay) => SizedBox(
                  width: 60.6,
                  height: 24.4,
                  child: Center(
                    child: Text(
                      bay.bayNumber,
                      style: const TextStyle(fontSize: 7, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ...List.generate(_rowCount(block.blockId), (rowIdx) {
            return Row(
              children: [
                SizedBox(
                  width: 14,
                  child: Text(
                    '${rowIdx + 1}',
                    style: const TextStyle(fontSize: 7, color: Colors.white),
                  ),
                ),
                ...bays.map((bay) {
                  final rows = widget.rowsByBay[bay.bayId] ?? [];
                  if (rowIdx >= rows.length) {
                    return const SizedBox(width: 24.4);
                  }
                  final row = rows[rowIdx];
                  return SizedBox(
                    width: 60.6,
                    height: 24.4,
                    child: _SlotCell(
                      row: row,
                      containers: widget.containersByRow[row.rowId] ?? [],
                      isHighlighted: widget.highlightedRowId == row.rowId,
                      blinkCtrl: _blinkCtrl,
                      onTap: (offset) =>
                          widget.onSlotTap(context, row.rowId, offset),
                      onDrop: (c) => widget.onContainerDropped(c, row.rowId),
                    ),
                  );
                }),
              ],
            );
          }),
          const SizedBox(height: 3),
          RotatedBox(
            quarterTurns: 1,
            child: Text(
              block.blockDesc ?? 'Block 5',
              style: const TextStyle(fontSize: 7, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  int _rowCount(int blockId) {
    final bays = widget.baysByBlock[blockId] ?? [];
    if (bays.isEmpty) return 0;
    return (widget.rowsByBay[bays.first.bayId] ?? []).length;
  }
}

// ── Slot Cell ────────────────────────────────────────────────────────────────
class _SlotCell extends StatelessWidget {
  final RowModel row;
  final List<ContainerModel> containers;
  final bool isHighlighted;
  final AnimationController blinkCtrl;
  final void Function(Offset) onTap;
  final Future<void> Function(ContainerModel) onDrop;

  const _SlotCell({
    required this.row,
    required this.containers,
    required this.isHighlighted,
    required this.blinkCtrl,
    required this.onTap,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final topContainer = containers.isNotEmpty ? containers.last : null;
    final isOccupied = topContainer != null;
    final isLaden = topContainer?.statusId == 1;

    Widget cell = DragTarget<ContainerModel>(
      onWillAcceptWithDetails: (details) =>
          details.data.containerId != topContainer?.containerId &&
          containers.length < 5,
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (ctx, candidates, rejected) {
        final isDragOver = candidates.isNotEmpty;
        Widget inner = GestureDetector(
          onTapUp: (details) => onTap(details.globalPosition),
          child: Container(
            margin: const EdgeInsets.all(1),
            height: 18,
            decoration: BoxDecoration(
              color: isDragOver
                  ? Colors.blue.withValues(alpha: 0.5)
                  : isOccupied
                  ? (isLaden ? Colors.yellow[700] : Colors.red[400])
                  : Colors.transparent,
              border: Border.all(color: Colors.white, width: 0.8),
              borderRadius: BorderRadius.circular(2),
            ),
            child: isOccupied
                ? Center(
                    child: Text(
                      topContainer.containerNumber,
                      style: const TextStyle(
                        fontSize: 6,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : null,
          ),
        );

        if (isOccupied) {
          return Draggable<ContainerModel>(
            data: topContainer,
            rootOverlay: false,
            feedback: SizedBox(
              width: 120,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isLaden ? Colors.yellow[700] : Colors.red[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    topContainer.containerNumber,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            childWhenDragging: Container(
              margin: const EdgeInsets.all(1),
              height: 18,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            child: inner,
          );
        }
        return inner;
      },
    );

    if (isHighlighted) {
      return AnimatedBuilder(
        animation: blinkCtrl,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            color: blinkCtrl.value > 0.5
                ? Colors.yellowAccent
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: blinkCtrl.value > 0.5 ? Colors.yellow : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
        child: cell,
      );
    }

    return cell;
  }
}
