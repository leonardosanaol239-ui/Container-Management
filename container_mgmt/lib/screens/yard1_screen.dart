import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/container_model.dart';
import '../models/customer_model.dart';
import '../models/truck.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../models/row_model.dart';
import '../widgets/container_holding_area.dart';
import '../widgets/container_details_dialog.dart';
import '../widgets/yard_map.dart';

class Yard1Screen extends StatefulWidget {
  final int portId;
  final String portName;
  const Yard1Screen({super.key, required this.portId, required this.portName});

  @override
  State<Yard1Screen> createState() => _Yard1ScreenState();
}

class _Yard1ScreenState extends State<Yard1Screen> {
  final _api = ApiService();
  List<ContainerModel> _containers = [];
  List<Block> _blocks = [];
  List<CustomerModel> _customers = [];
  Map<int, List<ContainerModel>> _containersByRow = {};
  Map<int, List<Bay>> _baysByBlock = {};
  Map<int, List<RowModel>> _rowsByBay = {};
  bool _loading = true;
  final TransformationController _transformCtrl = TransformationController();
  final _yardStackKey = GlobalKey();

  // Search
  final _searchCtrl = TextEditingController();
  ContainerModel? _foundContainer;
  int? _highlightedRowId;

  // Inline move panel state
  bool _showMovePanel = false;
  Block? _selectedBlock;
  Bay? _selectedBay;

  // Inline tier popup state
  int? _tierPopupRowId;
  Offset? _tierPopupPosition;

  // Move-out state
  List<ContainerModel> _movedOutContainers = [];
  bool _showMoveOutList = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final containers = await _api.getContainersByPort(widget.portId);
      final blocks = await _api.getBlocks(1);
      final Map<int, List<Bay>> baysByBlock = {};
      final Map<int, List<RowModel>> rowsByBay = {};
      for (final block in blocks) {
        final bays = await _api.getBays(block.blockId);
        baysByBlock[block.blockId] = bays;
        for (final bay in bays) {
          rowsByBay[bay.bayId] = await _api.getRows(bay.bayId);
        }
      }
      final Map<int, List<ContainerModel>> byRow = {};
      for (final c in containers) {
        if (c.rowId != null && !c.isMovedOut) {
          byRow.putIfAbsent(c.rowId!, () => []).add(c);
        }
      }
      for (final list in byRow.values) {
        list.sort((a, b) => (a.tier ?? 0).compareTo(b.tier ?? 0));
      }
      final movedOut = await _api.getMovedOutContainers(widget.portId);
      final customers = await _api.getCustomers();
      setState(() {
        _containers = containers;
        _blocks = blocks;
        _baysByBlock = baysByBlock;
        _rowsByBay = rowsByBay;
        _containersByRow = byRow;
        _movedOutContainers = movedOut;
        _customers = customers;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _searchContainer() async {
    final num = _searchCtrl.text.trim();
    if (num.isEmpty) return;
    final c = await _api.searchContainer(num);
    setState(() {
      _foundContainer = c;
      _highlightedRowId = c?.rowId;
    });
  }

  void _clearSearch() => setState(() {
    _searchCtrl.clear();
    _foundContainer = null;
    _highlightedRowId = null;
  });

  void _closeMovePanel() => setState(() {
    _showMovePanel = false;
    _selectedBlock = null;
    _selectedBay = null;
  });

  String get _breadcrumb {
    String b = '${widget.portName} > Yard 1';
    if (_selectedBlock != null)
      b +=
          ' > ${_selectedBlock!.blockDesc ?? "Block ${_selectedBlock!.blockNumber}"}';
    if (_selectedBay != null) b += ' > Bay ${_selectedBay!.bayNumber}';
    return b;
  }

  Future<void> _dropToSlot(ContainerModel container, int rowId) async {
    final existing = _containersByRow[rowId] ?? [];
    if (existing.length >= 5) return;
    final nextTier = existing.length + 1;
    int? blockId, bayId;
    for (final e in _rowsByBay.entries) {
      for (final r in e.value) {
        if (r.rowId == rowId) {
          bayId = e.key;
          break;
        }
      }
      if (bayId != null) break;
    }
    for (final e in _baysByBlock.entries) {
      for (final b in e.value) {
        if (b.bayId == bayId) {
          blockId = e.key;
          break;
        }
      }
      if (blockId != null) break;
    }
    if (blockId == null || bayId == null) return;
    try {
      await _api.moveContainer(
        containerId: container.containerId,
        yardId: 1,
        blockId: blockId,
        bayId: bayId,
        rowId: rowId,
        tier: nextTier,
      );
      await _loadAll();
    } catch (_) {}
  }

  Future<void> _returnToHolding(ContainerModel container) async {
    try {
      await _api.removeContainerFromSlot(container.containerId);
      await _loadAll();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.portName} Container Management  >  Yard 1',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              key: _yardStackKey,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Left: Holding Area (always visible, draggable source) ──
                      _HoldingAreaWithReturn(
                        portId: widget.portId,
                        containers: _containers,
                        onRefresh: _loadAll,
                        onReturnDrop: _returnToHolding,
                      ),
                      const SizedBox(width: 16),
                      // ── Right: Yard area ──
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () => setState(() {
                                    _showMovePanel = true;
                                    _selectedBlock = null;
                                    _selectedBay = null;
                                  }),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                  ),
                                  child: const Text(
                                    'Move Container to Yard',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // ── Move Out drop zone ──
                                _MoveOutDropZone(
                                  movedOutContainers: _movedOutContainers,
                                  showList: _showMoveOutList,
                                  onToggleList: () => setState(
                                    () => _showMoveOutList = !_showMoveOutList,
                                  ),
                                  onDrop: (container) async {
                                    await _showMoveOutDialog(container);
                                  },
                                ),
                                const SizedBox(width: 12),
                                // ── Yard Stats button ──
                                ElevatedButton.icon(
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => _YardStatsDialog(
                                      blocks: _blocks,
                                      baysByBlock: _baysByBlock,
                                      rowsByBay: _rowsByBay,
                                      containers: _containers,
                                    ),
                                  ),
                                  icon: const Icon(Icons.bar_chart, size: 18),
                                  label: const Text(
                                    'Yard Stats',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _searchCtrl,
                                            decoration: const InputDecoration(
                                              hintText:
                                                  'Search Container Location Via container number',
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              isDense: true,
                                            ),
                                            onSubmitted: (_) =>
                                                _searchContainer(),
                                          ),
                                        ),
                                        if (_searchCtrl.text.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 18,
                                            ),
                                            onPressed: _clearSearch,
                                          ),
                                        ElevatedButton(
                                          onPressed: _searchContainer,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber,
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: const Text(
                                            'Locate Container',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Stack(
                                children: [
                                  InteractiveViewer(
                                    transformationController: _transformCtrl,
                                    minScale: 0.5,
                                    maxScale: 3.0,
                                    child: YardMap(
                                      blocks: _blocks,
                                      baysByBlock: _baysByBlock,
                                      rowsByBay: _rowsByBay,
                                      containersByRow: _containersByRow,
                                      highlightedRowId: _highlightedRowId,
                                      onSlotTap: _showSlotPopup,
                                      onContainerDropped: _dropToSlot,
                                    ),
                                  ),
                                  if (_foundContainer != null &&
                                      _foundContainer!.rowId != null)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: _SearchResultPopup(
                                        container: _foundContainer!,
                                        blocks: _blocks,
                                        baysByBlock: _baysByBlock,
                                        rowsByBay: _rowsByBay,
                                        onClose: _clearSearch,
                                        customers: _customers,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Inline Move Panel overlay (same layer as holding area) ──
                if (_showMovePanel)
                  Positioned(
                    left: 220,
                    top: 60,
                    right: 16,
                    bottom: 16,
                    child: _InlineMovePanel(
                      breadcrumb: _breadcrumb,
                      portName: widget.portName,
                      blocks: _blocks,
                      baysByBlock: _baysByBlock,
                      rowsByBay: _rowsByBay,
                      containersByRow: _containersByRow,
                      selectedBlock: _selectedBlock,
                      selectedBay: _selectedBay,
                      onSelectBlock: (b) => setState(() {
                        _selectedBlock = b;
                        _selectedBay = null;
                      }),
                      onSelectBay: (b) => setState(() => _selectedBay = b),
                      onClose: _closeMovePanel,
                      onDrop: (container, rowId) async {
                        await _dropToSlot(container, rowId);
                      },
                      onSlotTap: (rowId) {
                        final containers = _containersByRow[rowId] ?? [];
                        if (containers.isEmpty) return;
                        // Position the popup centered over the move panel area
                        final RenderBox? box =
                            _yardStackKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        final size = box?.size ?? Size.zero;
                        setState(() {
                          _tierPopupRowId = rowId;
                          _tierPopupPosition = Offset(
                            (size.width / 2 - 115).clamp(220, size.width - 250),
                            (size.height / 2 - 120).clamp(
                              60,
                              size.height - 250,
                            ),
                          );
                        });
                      },
                    ),
                  ),

                // ── Inline Tier Stack popup (top of all layers) ──
                if (_tierPopupRowId != null && _tierPopupPosition != null)
                  Positioned(
                    left: _tierPopupPosition!.dx,
                    top: _tierPopupPosition!.dy,
                    child: _InlineTierPopup(
                      containers: _containersByRow[_tierPopupRowId!] ?? [],
                      onClose: _closeTierPopup,
                      customers: _customers,
                    ),
                  ),

                // ── Moved Out list overlay ──
                if (_showMoveOutList && _movedOutContainers.isNotEmpty)
                  Positioned(
                    left: 220,
                    top: 56,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 240,
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[300]!),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _movedOutContainers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final c = _movedOutContainers[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                c.containerNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                c.boundTo != null
                                    ? 'Bound to: ${c.boundTo}'
                                    : '',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () {
                                setState(() => _showMoveOutList = false);
                                showDialog(
                                  context: context,
                                  builder: (_) =>
                                      _MovedOutDetailsDialog(container: c),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _showSlotPopup(BuildContext ctx, int rowId, Offset position) {
    final containers = _containersByRow[rowId] ?? [];
    if (containers.isEmpty) return;
    // Convert global tap position to local coords of the outer body Stack
    final RenderBox? stackBox =
        _yardStackKey.currentContext?.findRenderObject() as RenderBox?;
    Offset local = stackBox != null
        ? stackBox.globalToLocal(position)
        : position;
    final size = stackBox?.size ?? Size.zero;
    final dx = (local.dx - 10).clamp(
      0.0,
      (size.width - 250).clamp(0.0, size.width),
    );
    final dy = (local.dy - 10).clamp(
      0.0,
      (size.height - 250).clamp(0.0, size.height),
    );
    setState(() {
      _tierPopupRowId = rowId;
      _tierPopupPosition = Offset(dx, dy);
    });
  }

  void _closeTierPopup() => setState(() {
    _tierPopupRowId = null;
    _tierPopupPosition = null;
  });

  Future<void> _showMoveOutDialog(ContainerModel container) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _MoveOutDialog(
        container: container,
        api: _api,
        onConfirm: (truckId, boundTo) async {
          await _api.moveOutContainer(
            containerId: container.containerId,
            truckId: truckId,
            boundTo: boundTo,
          );
          await _loadAll();
        },
      ),
    );
  }
}

// ── Holding area that also accepts drops (return to holding) ─────────────────
class _HoldingAreaWithReturn extends StatelessWidget {
  final int portId;
  final List<ContainerModel> containers;
  final VoidCallback onRefresh;
  final Future<void> Function(ContainerModel) onReturnDrop;

  const _HoldingAreaWithReturn({
    required this.portId,
    required this.containers,
    required this.onRefresh,
    required this.onReturnDrop,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<ContainerModel>(
      onWillAcceptWithDetails: (d) =>
          d.data.yardId != null, // only accept yard containers
      onAcceptWithDetails: (d) => onReturnDrop(d.data),
      builder: (ctx, candidates, _) {
        final isDragOver = candidates.isNotEmpty;
        return Container(
          decoration: isDragOver
              ? BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 4),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: ContainerHoldingArea(
            portId: portId,
            containers: containers,
            onRefresh: onRefresh,
          ),
        );
      },
    );
  }
}

// ── Inline Move Panel ────────────────────────────────────────────────────────
class _InlineMovePanel extends StatelessWidget {
  final String breadcrumb;
  final String portName;
  final List<Block> blocks;
  final Map<int, List<Bay>> baysByBlock;
  final Map<int, List<RowModel>> rowsByBay;
  final Map<int, List<ContainerModel>> containersByRow;
  final Block? selectedBlock;
  final Bay? selectedBay;
  final void Function(Block) onSelectBlock;
  final void Function(Bay) onSelectBay;
  final VoidCallback onClose;
  final Future<void> Function(ContainerModel, int) onDrop;
  final void Function(int rowId) onSlotTap;

  const _InlineMovePanel({
    required this.breadcrumb,
    required this.portName,
    required this.blocks,
    required this.baysByBlock,
    required this.rowsByBay,
    required this.containersByRow,
    required this.selectedBlock,
    required this.selectedBay,
    required this.onSelectBlock,
    required this.onSelectBay,
    required this.onClose,
    required this.onDrop,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with breadcrumb + close
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      breadcrumb,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.amber, thickness: 2, height: 1),
            // Content
            Flexible(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (selectedBay != null && selectedBlock != null) {
      final rows = rowsByBay[selectedBay!.bayId] ?? [];
      return _SlotDropArea(
        bay: selectedBay!,
        block: selectedBlock!,
        rows: rows,
        containersByRow: containersByRow,
        onDrop: onDrop,
        onSlotTap: onSlotTap,
      );
    }
    if (selectedBlock != null) {
      final bays = baysByBlock[selectedBlock!.blockId] ?? [];
      return _SelectionList(
        title: 'Select Bay to Place Container',
        items: bays
            .map((b) => _Item('BAY ${b.bayNumber}', () => onSelectBay(b)))
            .toList(),
      );
    }
    return _SelectionList(
      title: 'Select Block to Place Container',
      items: blocks
          .map(
            (b) => _Item(
              b.blockDesc?.toUpperCase() ?? 'BLOCK ${b.blockNumber}',
              () => onSelectBlock(b),
            ),
          )
          .toList(),
    );
  }
}

class _Item {
  final String label;
  final VoidCallback onTap;
  _Item(this.label, this.onTap);
}

class _SelectionList extends StatelessWidget {
  final String title;
  final List<_Item> items;
  const _SelectionList({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
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
      ),
    );
  }
}

// ── Slot drop area (same overlay layer — drag works!) ────────────────────────
class _SlotDropArea extends StatelessWidget {
  final Bay bay;
  final Block block;
  final List<RowModel> rows;
  final Map<int, List<ContainerModel>> containersByRow;
  final Future<void> Function(ContainerModel, int) onDrop;
  final void Function(int rowId) onSlotTap;

  const _SlotDropArea({
    required this.bay,
    required this.block,
    required this.rows,
    required this.containersByRow,
    required this.onDrop,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Drag Container To Slots',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 30),
              Expanded(
                child: Center(
                  child: Text(
                    bay.bayNumber,
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
          ...rows.map((row) {
            final containers = containersByRow[row.rowId] ?? [];
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
                      onWillAcceptWithDetails: (d) =>
                          d.data.containerId != topContainer?.containerId &&
                          containers.length < 5,
                      onAcceptWithDetails: (d) => onDrop(d.data, row.rowId),
                      builder: (ctx, candidates, _) {
                        final isDragOver = candidates.isNotEmpty;
                        Widget slotContent = Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDragOver
                                ? Colors.blue[100]
                                : topContainer != null
                                ? Colors.amber[300]
                                : Colors.grey[200],
                            border: Border.all(
                              color: isDragOver
                                  ? Colors.blue
                                  : Colors.grey[400]!,
                              width: isDragOver ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: topContainer != null
                                ? Text(
                                    topContainer.containerNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : Text(
                                    '${containers.length}/5',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                          ),
                        );

                        if (topContainer != null) {
                          return GestureDetector(
                            onTap: () => onSlotTap(row.rowId),
                            child: Draggable<ContainerModel>(
                              data: topContainer,
                              rootOverlay: false,
                              feedback: SizedBox(
                                width: 180,
                                child: Material(
                                  elevation: 6,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber[300],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      topContainer.containerNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              childWhenDragging: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  border: Border.all(
                                    color: Colors.grey[400]!,
                                    style: BorderStyle.solid,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${containers.length - 1}/5',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                ),
                              ),
                              child: slotContent,
                            ),
                          );
                        }
                        return slotContent;
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

// ── Inline Tier Stack Popup ──────────────────────────────────────────────────
class _InlineTierPopup extends StatefulWidget {
  final List<ContainerModel> containers;
  final VoidCallback onClose;
  final List<CustomerModel> customers;

  const _InlineTierPopup({
    required this.containers,
    required this.onClose,
    this.customers = const [],
  });

  @override
  State<_InlineTierPopup> createState() => _InlineTierPopupState();
}

class _InlineTierPopupState extends State<_InlineTierPopup> {
  ContainerModel? _selectedContainer;
  List<CustomerModel> _localCustomers = [];

  @override
  void initState() {
    super.initState();
    _localCustomers = widget.customers;
    if (_localCustomers.isEmpty) _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    try {
      final list = await ApiService().getCustomers();
      if (mounted) setState(() => _localCustomers = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: _selectedContainer != null
            ? _buildDetails(_selectedContainer!)
            : _buildTierList(),
      ),
    );
  }

  Widget _buildTierList() {
    return Column(
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
              onTap: widget.onClose,
              child: const Icon(Icons.close, color: Colors.red, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...widget.containers.map((c) {
          final isLaden = c.statusId == 1;
          return GestureDetector(
            onTap: () => setState(() => _selectedContainer = c),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      color: isLaden ? Colors.amber : Colors.red,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.containerNumber,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDetails(ContainerModel c) {
    final isLaden = c.statusId == 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() => _selectedContainer = null),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white70,
                size: 18,
              ),
            ),
            GestureDetector(
              onTap: widget.onClose,
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
        _detailRow('Status:', isLaden ? 'Laden' : 'Empty'),
        _detailRow('Type:', c.type ?? '-'),
        _detailRow('Tier:', '${c.tier ?? '-'}'),
        if (c.customerId != null)
          Builder(
            builder: (_) {
              final cu = _localCustomers
                  .where((x) => x.customerId == c.customerId)
                  .firstOrNull;
              return cu != null
                  ? _detailRow('Customer:', cu.fullName)
                  : const SizedBox.shrink();
            },
          ),
        const SizedBox(height: 6),
        const Text(
          'Description:',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            c.containerDesc ?? '-',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );
}

// ── Search Result Popup ──────────────────────────────────────────────────────
class _SearchResultPopup extends StatelessWidget {
  final ContainerModel container;
  final List<Block> blocks;
  final Map<int, List<Bay>> baysByBlock;
  final Map<int, List<RowModel>> rowsByBay;
  final VoidCallback onClose;

  const _SearchResultPopup({
    required this.container,
    required this.blocks,
    required this.baysByBlock,
    required this.rowsByBay,
    required this.onClose,
    this.customers = const [],
  });

  final List<CustomerModel> customers;

  String _blockName() {
    final b = blocks.firstWhere(
      (b) => b.blockId == container.blockId,
      orElse: () => Block(blockId: 0, blockNumber: 0, yardId: 0, portId: 0),
    );
    return b.blockDesc ?? 'Block ${b.blockNumber}';
  }

  String _bayNumber() {
    for (final bays in baysByBlock.values) {
      for (final bay in bays) {
        if (bay.bayId == container.bayId) return bay.bayNumber;
      }
    }
    return '-';
  }

  String _rowNumber() {
    for (final rows in rowsByBay.values) {
      for (final row in rows) {
        if (row.rowId == container.rowId) return '${row.rowNumber}';
      }
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
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
              Text(
                container.containerNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, color: Colors.red, size: 18),
              ),
            ],
          ),
          const Text(
            'Location',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 6),
          _row('Block:', _blockName()),
          _row('Bay:', _bayNumber()),
          _row('Row:', _rowNumber()),
          _row('Tier:', '${container.tier}'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) {
                  final customer = container.customerId != null
                      ? customers
                            .where(
                              (cu) => cu.customerId == container.customerId,
                            )
                            .firstOrNull
                      : null;
                  return ContainerDetailsDialog(
                    container: container,
                    customerName: customer?.fullName,
                  );
                },
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'View Con. Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}

// ── Move Out Drop Zone ───────────────────────────────────────────────────────
class _MoveOutDropZone extends StatelessWidget {
  final List<ContainerModel> movedOutContainers;
  final bool showList;
  final VoidCallback onToggleList;
  final Future<void> Function(ContainerModel) onDrop;

  const _MoveOutDropZone({
    required this.movedOutContainers,
    required this.showList,
    required this.onToggleList,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<ContainerModel>(
      onWillAcceptWithDetails: (d) => !d.data.isMovedOut,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (ctx, candidates, _) {
        final isDragOver = candidates.isNotEmpty;
        return GestureDetector(
          onTap: onToggleList,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDragOver ? Colors.red[700] : Colors.red[600],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDragOver ? Colors.red[900]! : Colors.red[800]!,
                width: isDragOver ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Move Out${movedOutContainers.isNotEmpty ? ' (${movedOutContainers.length})' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  showList ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Move Out Dialog ──────────────────────────────────────────────────────────
class _MoveOutDialog extends StatefulWidget {
  final ContainerModel container;
  final ApiService api;
  final Future<void> Function(int truckId, String boundTo) onConfirm;

  const _MoveOutDialog({
    required this.container,
    required this.api,
    required this.onConfirm,
  });

  @override
  State<_MoveOutDialog> createState() => _MoveOutDialogState();
}

class _MoveOutDialogState extends State<_MoveOutDialog> {
  Truck? _selectedTruck;
  final _boundToCtrl = TextEditingController();
  bool _loading = false;
  List<Truck> _trucks = [];
  bool _loadingTrucks = true;

  @override
  void initState() {
    super.initState();
    _loadTrucks();
  }

  Future<void> _loadTrucks() async {
    try {
      final trucks = await widget.api.getTrucks();
      if (mounted)
        setState(() {
          _trucks = trucks;
          _loadingTrucks = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingTrucks = false);
    }
  }

  @override
  void dispose() {
    _boundToCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Move Out Container',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 4),
            Text(
              widget.container.containerNumber,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Select Truck:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            _loadingTrucks
                ? const Center(
                    child: SizedBox(
                      height: 40,
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _trucks.isEmpty
                ? const Text(
                    'No trucks available',
                    style: TextStyle(color: Colors.red, fontSize: 13),
                  )
                : DropdownButton<Truck>(
                    value: _selectedTruck,
                    hint: const Text('Choose a truck'),
                    isExpanded: true,
                    underline: Container(height: 1, color: Colors.grey[400]),
                    items: _trucks
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.truckName),
                          ),
                        )
                        .toList(),
                    onChanged: (t) => setState(() => _selectedTruck = t),
                  ),
            const SizedBox(height: 14),
            const Text(
              'Bound To:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _boundToCtrl,
              decoration: InputDecoration(
                hintText: 'Enter destination',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        if (_selectedTruck == null) return;
                        if (_boundToCtrl.text.trim().isEmpty) return;
                        setState(() => _loading = true);
                        await widget.onConfirm(
                          _selectedTruck!.truckId,
                          _boundToCtrl.text.trim(),
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm Move Out',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Moved Out Details Dialog ─────────────────────────────────────────────────
class _MovedOutDetailsDialog extends StatelessWidget {
  final ContainerModel container;
  const _MovedOutDetailsDialog({required this.container});

  @override
  Widget build(BuildContext context) {
    final isLaden = container.statusId == 1;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    container.containerNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row('Status:', isLaden ? 'Laden' : 'Empty'),
            _row('Type:', container.type ?? '-'),
            _row('Truck:', 'Truck ID ${container.truckId ?? '-'}'),
            _row('Bound To:', container.boundTo ?? '-'),
            if (container.containerDesc != null &&
                container.containerDesc!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  container.containerDesc!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

// ── Yard Stats Dialog ────────────────────────────────────────────────────────
class _YardStatsDialog extends StatelessWidget {
  final List<Block> blocks;
  final Map<int, List<Bay>> baysByBlock;
  final Map<int, List<RowModel>> rowsByBay;
  final List<ContainerModel> containers;

  const _YardStatsDialog({
    required this.blocks,
    required this.baysByBlock,
    required this.rowsByBay,
    required this.containers,
  });

  @override
  Widget build(BuildContext context) {
    // Compute stats
    final totalBlocks = blocks.length;

    int totalSlots = 0;
    for (final block in blocks) {
      final bays = baysByBlock[block.blockId] ?? [];
      for (final bay in bays) {
        totalSlots += (rowsByBay[bay.bayId] ?? []).length;
      }
    }

    final totalCapacity = totalSlots * 5; // max 5 tiers per slot

    final inYard = containers
        .where((c) => c.isInYard && !c.isMovedOut)
        .toList();
    final laden = inYard.where((c) => c.statusId == 1).length;
    final empty = inYard.where((c) => c.statusId == 2).length;
    final occupiedSlots = inYard.map((c) => c.rowId).toSet().length;
    final occupancyPct = totalSlots > 0
        ? (occupiedSlots / totalSlots * 100).toStringAsFixed(1)
        : '0.0';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Text(
                      'Yard Stats',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 4),
            _section('Layout'),
            _row('Blocks', '$totalBlocks'),
            _row('Total Slots', '$totalSlots'),
            _row('Total Capacity (5 tiers)', '$totalCapacity containers'),
            const SizedBox(height: 10),
            _section('Occupancy'),
            _row(
              'Slots in use',
              '$occupiedSlots / $totalSlots ($occupancyPct%)',
            ),
            _row('Containers in yard', '${inYard.length}'),
            const SizedBox(height: 10),
            _section('Container Types'),
            _rowColored('Laden', '$laden', Colors.amber[700]!),
            _rowColored('Empty', '$empty', Colors.red[600]!),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _rowColored(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    ),
  );
}
