import 'package:flutter/material.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../models/row_model.dart';
import '../models/container_model.dart';
import '../services/api_service.dart';
import '../widgets/container_details_dialog.dart';

class MoveContainerDialog extends StatefulWidget {
  final String portName;
  final List<Block> blocks;
  final Map<int, List<Bay>> baysByBlock;
  final Map<int, List<RowModel>> rowsByBay;
  final Map<int, List<ContainerModel>> containersByRow;
  final List<ContainerModel> holdingContainers;
  final VoidCallback onMoved;

  const MoveContainerDialog({
    super.key,
    required this.portName,
    required this.blocks,
    required this.baysByBlock,
    required this.rowsByBay,
    required this.containersByRow,
    required this.holdingContainers,
    required this.onMoved,
  });

  @override
  State<MoveContainerDialog> createState() => _MoveContainerDialogState();
}

class _MoveContainerDialogState extends State<MoveContainerDialog> {
  Block? _selectedBlock;
  Bay? _selectedBay;

  String get _breadcrumb {
    String b = '${widget.portName} > Yard 1';
    if (_selectedBlock != null)
      b +=
          ' > ${_selectedBlock!.blockDesc ?? "Block ${_selectedBlock!.blockNumber}"}';
    if (_selectedBay != null) b += ' > Bay ${_selectedBay!.bayNumber}';
    return b;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Breadcrumb
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                _breadcrumb,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const Divider(color: Colors.amber, thickness: 2, height: 1),
            // Content
            Flexible(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_selectedBay != null) {
      return _SlotDropView(
        bay: _selectedBay!,
        rows: widget.rowsByBay[_selectedBay!.bayId] ?? [],
        containersByRow: widget.containersByRow,
        holdingContainers: widget.holdingContainers,
        block: _selectedBlock!,
        onMoved: () {
          widget.onMoved();
          Navigator.pop(context);
        },
      );
    }

    if (_selectedBlock != null) {
      final bays = widget.baysByBlock[_selectedBlock!.blockId] ?? [];
      return _SelectionList(
        title: 'Select Bay to Place Container',
        items: bays
            .map(
              (b) => _SelectItem(
                label: 'BAY ${b.bayNumber}',
                onTap: () {
                  setState(() => _selectedBay = b);
                },
              ),
            )
            .toList(),
      );
    }

    return _SelectionList(
      title: 'Select Block to Place Container',
      items: widget.blocks
          .map(
            (b) => _SelectItem(
              label: b.blockDesc?.toUpperCase() ?? 'BLOCK ${b.blockNumber}',
              onTap: () => setState(() => _selectedBlock = b),
            ),
          )
          .toList(),
    );
  }
}

class _SelectionList extends StatelessWidget {
  final String title;
  final List<_SelectItem> items;
  const _SelectionList({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        ...items.map(
          (item) => Column(
            children: [
              InkWell(
                onTap: item.onTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectItem {
  final String label;
  final VoidCallback onTap;
  _SelectItem({required this.label, required this.onTap});
}

// ── Slot drop view ───────────────────────────────────────────────────────────
class _SlotDropView extends StatefulWidget {
  final Bay bay;
  final Block block;
  final List<RowModel> rows;
  final Map<int, List<ContainerModel>> containersByRow;
  final List<ContainerModel> holdingContainers;
  final VoidCallback onMoved;

  const _SlotDropView({
    required this.bay,
    required this.block,
    required this.rows,
    required this.containersByRow,
    required this.holdingContainers,
    required this.onMoved,
  });

  @override
  State<_SlotDropView> createState() => _SlotDropViewState();
}

class _SlotDropViewState extends State<_SlotDropView> {
  final _api = ApiService();
  late Map<int, List<ContainerModel>> _localContainersByRow;

  @override
  void initState() {
    super.initState();
    _localContainersByRow = Map.from(widget.containersByRow);
  }

  Future<void> _drop(ContainerModel container, int rowId) async {
    final existing = _localContainersByRow[rowId] ?? [];
    if (existing.length >= 5) return;
    final nextTier = existing.length + 1;

    try {
      await _api.moveContainer(
        containerId: container.containerId,
        yardId: 1,
        blockId: widget.block.blockId,
        bayId: widget.bay.bayId,
        rowId: rowId,
        tier: nextTier,
      );
      setState(() {
        final updated = List<ContainerModel>.from(existing)
          ..add(container.copyWith(tier: nextTier, rowId: rowId));
        _localContainersByRow[rowId] = updated;
      });
      widget.onMoved();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Drag Container To Slots',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 16),
          // Bay column header
          Row(
            children: [
              const SizedBox(width: 30),
              Expanded(
                child: Center(
                  child: Text(
                    widget.bay.bayNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Rows as drop targets
          ...widget.rows.map((row) {
            final containers = _localContainersByRow[row.rowId] ?? [];
            final topContainer = containers.isNotEmpty ? containers.last : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${row.rowNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: DragTarget<ContainerModel>(
                      onWillAcceptWithDetails: (d) => containers.length < 5,
                      onAcceptWithDetails: (d) => _drop(d.data, row.rowId),
                      builder: (ctx, candidates, _) {
                        final isDragOver = candidates.isNotEmpty;
                        return GestureDetector(
                          onTap: topContainer != null
                              ? () => showDialog(
                                  context: context,
                                  builder: (_) => ContainerDetailsDialog(
                                    container: topContainer,
                                  ),
                                )
                              : null,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: isDragOver
                                  ? Colors.blue[100]
                                  : topContainer != null
                                  ? Colors.amber[300]
                                  : Colors.grey[200],
                              border: Border.all(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: topContainer != null
                                  ? Text(
                                      topContainer.containerNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    )
                                  : Text(
                                      '${containers.length}/5',
                                      style: TextStyle(color: Colors.grey[400]),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

extension _ContainerCopy on ContainerModel {
  ContainerModel copyWith({int? tier, int? rowId}) => ContainerModel(
    containerId: containerId,
    containerNumber: containerNumber,
    statusId: statusId,
    type: type,
    containerDesc: containerDesc,
    currentPortId: currentPortId,
    yardId: yardId,
    blockId: blockId,
    bayId: bayId,
    rowId: rowId ?? this.rowId,
    tier: tier ?? this.tier,
    createdDate: createdDate,
  );
}
