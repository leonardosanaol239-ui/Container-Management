import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/yard.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../models/row_model.dart';
import '../models/container_model.dart';
import '../models/size_model.dart';
import '../models/orientation_model.dart';
import '../models/truck.dart';
import '../widgets/container_holding_area.dart';

const double kContainerHeight = 8.0;
const double k20ftWidth = 20.0;
const double k40ftWidth = 40.0;
const double kYardBorderPx = 16.0; // thick yard boundary border

class YardScreen extends StatefulWidget {
  final Yard yard;
  final int portId;
  final String portName;
  const YardScreen({
    super.key,
    required this.yard,
    required this.portId,
    required this.portName,
  });
  @override
  State<YardScreen> createState() => _YardScreenState();
}

class _YardScreenState extends State<YardScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  List<Block> _blocks = [];
  Map<int, List<Bay>> _baysByBlock = {};
  Map<int, List<RowModel>> _rowsByBay = {};
  Map<int, List<ContainerModel>> _containersByRow = {};
  List<ContainerModel> _containers = [];
  List<ContainerModel> _movedOutContainers = [];
  List<SizeModel> _sizes = [];
  List<OrientationModel> _orientations = [];
  bool _loading = true;
  bool _editMode = false;
  bool _saving = false;
  int? _selectedOrientationId;
  int? _selectedSizeId;
  String? _selectedSlotEdit;
  int? _selectedSlotId;
  final Map<int, Offset> _blockOffsets = {};
  int? _tierPopupRowId;
  Offset? _tierPopupPosition;
  final _yardKey = GlobalKey();
  final _searchCtrl = TextEditingController();
  ContainerModel? _foundContainer;
  int? _highlightedRowId;
  bool _showMoveOutList = false;
  double _scale = 3.0;
  double get _canvasW => (widget.yard.yardWidth ?? 300) * _scale;
  double get _canvasH => (widget.yard.yardHeight ?? 170) * _scale;
  double get _scaleX => _scale;
  double get _scaleY => _scale;
  late AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getBlocks(widget.yard.yardId),
        _api.getContainersByPort(widget.portId),
        _api.getMovedOutContainers(widget.portId),
        _api.getSizes(),
        _api.getOrientations(),
      ]);
      final blocks = results[0] as List<Block>;
      final containers = results[1] as List<ContainerModel>;
      final movedOut = results[2] as List<ContainerModel>;
      final sizes = results[3] as List<SizeModel>;
      final orientations = results[4] as List<OrientationModel>;
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
      setState(() {
        _blocks = blocks;
        _baysByBlock = baysByBlock;
        _rowsByBay = rowsByBay;
        _containersByRow = byRow;
        _containers = containers;
        _movedOutContainers = movedOut;
        _sizes = sizes;
        _orientations = orientations;
        _loading = false;
        // Always sync offsets from DB so saved positions are reflected
        for (final b in blocks) {
          _blockOffsets[b.blockId] = Offset(
            (b.posX ?? 10).toDouble(),
            (b.posY ?? 10).toDouble(),
          );
        }
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _searchContainer() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    final c = await _api.searchContainer(q);
    setState(() {
      _foundContainer = c;
      _highlightedRowId = c?.rowId;
    });
    if (c?.rowId != null) {
      _blinkCtrl.repeat(reverse: true);
    }
  }

  void _clearSearch() {
    setState(() {
      _searchCtrl.clear();
      _foundContainer = null;
      _highlightedRowId = null;
    });
    _blinkCtrl.stop();
    _blinkCtrl.reset();
  }

  Future<void> _dropToSlot(ContainerModel container, int rowId) async {
    final existing = _containersByRow[rowId] ?? [];
    RowModel? targetRow;
    for (final rows in _rowsByBay.values) {
      for (final r in rows) {
        if (r.rowId == rowId) {
          targetRow = r;
          break;
        }
      }
      if (targetRow != null) break;
    }
    if (existing.length >= (targetRow?.maxStack ?? 5)) return;
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
        yardId: widget.yard.yardId,
        blockId: blockId,
        bayId: bayId,
        rowId: rowId,
        tier: existing.length + 1,
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

  void _toggleEditMode() {
    setState(() {
      _editMode = !_editMode;
      if (!_editMode) {
        _selectedSlotId = null;
        _selectedSlotEdit = null;
        _selectedOrientationId = null;
        _selectedSizeId = null;
      }
    });
  }

  Future<void> _saveLayout() async {
    setState(() => _saving = true);
    try {
      // Persist all current block positions to the backend
      await Future.wait(
        _blocks.map((b) {
          final pos =
              _blockOffsets[b.blockId] ??
              Offset((b.posX ?? 10).toDouble(), (b.posY ?? 10).toDouble());
          return _api.updateBlockPosition(b.blockId, pos.dx, pos.dy);
        }),
      );
    } catch (_) {}
    setState(() {
      _saving = false;
      _editMode = false;
      _selectedSlotId = null;
    });
  }

  void _showYardStats() {
    final inYard = _containers
        .where((c) => c.rowId != null && !c.isMovedOut)
        .toList();
    final laden = inYard.where((c) => c.statusId == 1).length;
    final empty = inYard.where((c) => c.statusId != 1).length;
    final ft20 = inYard
        .where((c) => c.type != null && c.type!.toLowerCase().contains('20'))
        .length;
    final ft40 = inYard
        .where((c) => c.type != null && c.type!.toLowerCase().contains('40'))
        .length;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'YARD STATS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.portName}  ›  Yard ${widget.yard.yardNumber}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const Divider(height: 24),
              _statRow('Number of Blocks', '${_blocks.length}'),
              _statRow('Containers in Yard', '${inYard.length}'),
              const SizedBox(height: 8),
              _statRow('Laden', '$laden', color: Colors.amber.shade700),
              _statRow('Empty', '$empty', color: Colors.red.shade400),
              const SizedBox(height: 8),
              _statRow('20ft', '$ft20', color: Colors.blue.shade600),
              _statRow('40ft', '$ft40', color: Colors.teal.shade600),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: (color ?? Colors.grey.shade700).withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color ?? Colors.grey.shade400),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.grey.shade800,
            ),
          ),
        ),
      ],
    ),
  );

  void _showAddBlockDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddBlockDialog(
        sizes: _sizes,
        orientations: _orientations,
        onConfirm: (name, bays, rows, orientId, sizeId, maxStack) async {
          await _api.createBlock(
            yardId: widget.yard.yardId,
            portId: widget.portId,
            blockName: name,
            numBays: bays,
            numRows: rows,
            orientationId: orientId,
            sizeId: sizeId,
            maxStack: maxStack,
            posX: 10,
            posY: 10,
          );
          await _loadAll();
        },
      ),
    );
  }

  Future<void> _applyOrientationChange(int rowId, int orientationId) async {
    await _api.updateRow(rowId, orientationId: orientationId);
    await _loadAll();
  }

  Future<void> _applySizeChange(int rowId, int sizeId) async {
    await _api.updateRow(rowId, sizeId: sizeId);
    await _loadAll();
  }

  Future<void> _applySlotEdit(String action) async {
    if (_selectedSlotId == null) return;
    if (action == 'stackMax') {
      _showStackMaxDialog(_selectedSlotId!);
    } else if (action == 'deleteRow') {
      try {
        await _api.deleteRow(_selectedSlotId!);
        setState(() => _selectedSlotId = null);
        await _loadAll();
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot delete: row has containers')),
          );
      }
    }
  }

  void _showStackMaxDialog(int rowId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set Maximum Stack'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Max Stack (e.g. 5)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(ctrl.text.trim());
              if (val == null || val < 1) return;
              Navigator.pop(context);
              await _api.updateRow(rowId, maxStack: val);
              await _loadAll();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMoveOutDialog(ContainerModel container) async {
    if (!mounted) return;
    final trucks = await _api.getTrucks();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _MoveOutDialog(
        container: container,
        trucks: trucks,
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

  void _showSlotTierPopup(int rowId, Offset globalPos) {
    if ((_containersByRow[rowId] ?? []).isEmpty) return;
    final box = _yardKey.currentContext?.findRenderObject() as RenderBox?;
    final local = box != null ? box.globalToLocal(globalPos) : globalPos;
    final sz = box?.size ?? Size.zero;
    setState(() {
      _tierPopupRowId = rowId;
      _tierPopupPosition = Offset(
        (local.dx - 10).clamp(0.0, (sz.width - 250).clamp(0.0, sz.width)),
        (local.dy - 10).clamp(0.0, (sz.height - 250).clamp(0.0, sz.height)),
      );
    });
  }

  void _closeTierPopup() => setState(() {
    _tierPopupRowId = null;
    _tierPopupPosition = null;
  });

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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              key: _yardKey,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DragTarget<ContainerModel>(
                        onWillAcceptWithDetails: (d) => d.data.yardId != null,
                        onAcceptWithDetails: (d) => _returnToHolding(d.data),
                        builder: (ctx, candidates, _) => Container(
                          decoration: candidates.isNotEmpty
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: Colors.blue,
                                    width: 4,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                )
                              : null,
                          child: ContainerHoldingArea(
                            portId: widget.portId,
                            containers: _containers,
                            onRefresh: _loadAll,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildToolbar(),
                            const SizedBox(height: 8),
                            Expanded(child: _buildCanvas()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_tierPopupRowId != null && _tierPopupPosition != null)
                  Positioned(
                    left: _tierPopupPosition!.dx,
                    top: _tierPopupPosition!.dy,
                    child: _TierPopup(
                      containers: _containersByRow[_tierPopupRowId!] ?? [],
                      onClose: _closeTierPopup,
                    ),
                  ),
                if (_foundContainer != null)
                  Positioned(
                    top: 44,
                    right: 0,
                    child: _buildSearchResultCard(),
                  ),
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
                          border: Border.all(color: Colors.red),
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

  Widget _buildToolbar() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _editMode ? _saveLayout : _toggleEditMode,
          icon: Icon(_editMode ? Icons.save : Icons.edit, size: 16),
          label: Text(
            _editMode ? (_saving ? 'Saving...' : 'Save Layout') : 'Edit Layout',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _editMode ? Colors.green : Colors.amber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        if (_editMode) ...[
          const SizedBox(width: 8),
          // Edit tools inline
          ElevatedButton.icon(
            onPressed: _showAddBlockDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Block'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          _ToolbarDropdown<int>(
            label: 'Orientation',
            value: _selectedOrientationId,
            hint: 'Select',
            items: _orientations
                .map(
                  (o) => DropdownMenuItem(
                    value: o.orientationId,
                    child: Text(
                      o.orientationDesc,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() => _selectedOrientationId = v);
              if (v != null && _selectedSlotId != null)
                _applyOrientationChange(_selectedSlotId!, v);
            },
          ),
          const SizedBox(width: 8),
          _ToolbarDropdown<int>(
            label: 'Cell Size',
            value: _selectedSizeId,
            hint: 'Select',
            items: _sizes
                .map(
                  (s) => DropdownMenuItem(
                    value: s.sizeId,
                    child: Text(
                      s.sizeDesc,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() => _selectedSizeId = v);
              if (v != null && _selectedSlotId != null)
                _applySizeChange(_selectedSlotId!, v);
            },
          ),
          const SizedBox(width: 8),
          _ToolbarDropdown<String>(
            label: 'Slot Edit',
            value: _selectedSlotEdit,
            hint: 'Select',
            items: const [
              DropdownMenuItem(
                value: 'stackMax',
                child: Text('Stack Max', style: TextStyle(fontSize: 12)),
              ),
              DropdownMenuItem(
                value: 'deleteRow',
                child: Text('Delete Row', style: TextStyle(fontSize: 12)),
              ),
            ],
            onChanged: (v) {
              setState(() => _selectedSlotEdit = v);
              if (v != null) _applySlotEdit(v);
            },
          ),
          const Spacer(),
          if (_selectedSlotId != null) ...[
            Text(
              'Row #$_selectedSlotId selected',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(width: 8),
          ],
          OutlinedButton.icon(
            onPressed: _selectedSlotId != null
                ? () async {
                    try {
                      await _api.deleteRow(_selectedSlotId!);
                      setState(() => _selectedSlotId = null);
                      await _loadAll();
                    } catch (_) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot delete: slot has containers'),
                          ),
                        );
                    }
                  }
                : null,
            icon: const Icon(Icons.delete, size: 16, color: Colors.red),
            label: const Text(
              'Delete Slot',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ] else ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _showYardStats,
            icon: const Icon(Icons.bar_chart, size: 16),
            label: const Text('Yard Stats'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          DragTarget<ContainerModel>(
            onWillAcceptWithDetails: (d) => !d.data.isMovedOut,
            onAcceptWithDetails: (d) => _showMoveOutDialog(d.data),
            builder: (ctx, candidates, _) => GestureDetector(
              onTap: () => setState(() => _showMoveOutList = !_showMoveOutList),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: candidates.isNotEmpty
                      ? Colors.red[700]
                      : Colors.red[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_shipping,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Move Out${_movedOutContainers.isNotEmpty ? " (${_movedOutContainers.length})" : ""}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
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
                        hintText: 'Search container number',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _searchContainer(),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _clearSearch,
                    ),
                  ElevatedButton(
                    onPressed: _searchContainer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Locate',
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
      ],
    );
  }

  Widget _buildSearchResultCard() {
    final c = _foundContainer!;
    String blockLabel = '-', bayLabel = '-', rowLabel = '-';
    for (final block in _blocks) {
      for (final bay in (_baysByBlock[block.blockId] ?? [])) {
        for (final row in (_rowsByBay[bay.bayId] ?? [])) {
          if (row.rowId == c.rowId) {
            blockLabel = block.blockName ?? 'Block ${block.blockNumber}';
            bayLabel = bay.bayNumber;
            rowLabel = row.rowNumber.toString();
          }
        }
      }
    }
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 220,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.containerNumber,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Text(
                        'Location',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _clearSearch,
                  child: const Icon(
                    Icons.close,
                    color: Colors.redAccent,
                    size: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _locRow('Block:', blockLabel),
            _locRow('Bay:', bayLabel),
            _locRow('Row:', rowLabel),
            _locRow('Tier:', '${c.tier ?? '-'}'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showContainerDetailsDialog(c),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'View Con. Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );

  void _showContainerDetailsDialog(ContainerModel c) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
        child: SizedBox(
          width: 340,
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
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.redAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    c.containerNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _detailRow(
                  'Container Status:',
                  c.statusId == 1 ? 'Laden' : 'Empty',
                ),
                _detailRow('Type:', c.type ?? '-'),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Container Desc:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    c.containerDesc ?? '-',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
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

  Widget _buildCanvas() {
    final yardW = (widget.yard.yardWidth ?? 300).toDouble();
    final yardH = (widget.yard.yardHeight ?? 170).toDouble();
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final availW = constraints.maxWidth == double.infinity
            ? 800.0
            : constraints.maxWidth;
        final availH = constraints.maxHeight == double.infinity
            ? 500.0
            : constraints.maxHeight;
        // Fit yard to viewport once; lock after that to prevent jumps
        final fitScale = (availW / yardW) < (availH / yardH)
            ? (availW / yardW)
            : (availH / yardH);
        if (_scale == 3.0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _scale = fitScale);
          });
        }
        final cw = yardW * _scale;
        final ch = yardH * _scale;
        // Fixed frame — InteractiveViewer zooms/pans only inside it
        return Container(
          width: availW,
          height: availH,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            border: Border.all(color: Colors.grey.shade400, width: 1),
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
                    color: Colors.grey[300],
                    border: Border.all(color: Colors.grey, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomPaint(painter: _YardGridPainter()),
                ),
                ..._blocks.map((b) => _buildPositionedBlock(b)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Returns true if two rects overlap (with 2px tolerance)

  bool _rectsOverlap(Offset aPos, Size aSize, Offset bPos, Size bSize) {
    const tol = 2.0;

    return aPos.dx < bPos.dx + bSize.width - tol &&
        aPos.dx + aSize.width - tol > bPos.dx &&
        aPos.dy < bPos.dy + bSize.height - tol &&
        aPos.dy + aSize.height - tol > bPos.dy;
  }

  // Returns the slots-only bounding rect in FEET for a block at posInFt.
  // Headers (bay labels, block name label) are excluded.
  Rect _getSlotsRect(Block block, Offset posInFt) {
    final bays = _baysByBlock[block.blockId] ?? [];
    final isVert = block.isVertical;
    final is40 = block.is40ft;
    // slot dimensions in feet
    final slotLong = (is40 ? k40ftWidth : k20ftWidth); // 20 or 40 ft
    final slotShort = kContainerHeight; // 8 ft
    final slotW = isVert ? slotShort : slotLong;
    final slotH = isVert ? slotLong : slotShort;
    int maxRows = 0;
    for (final bay in bays) {
      final rows = _rowsByBay[bay.bayId] ?? [];
      if (rows.length > maxRows) maxRows = rows.length;
    }
    final slotsW = bays.isEmpty ? slotW : bays.length * slotW;
    final slotsH = maxRows == 0 ? slotH : maxRows * slotH;
    // Header offsets in feet (convert fixed px to ft).
    // Horizontal block: bay-label row is 14px tall at top; slot area starts below it.
    // Vertical block:   block-name label (RotatedBox) sits to the left ~20px wide;
    //                   bay labels (14px) are on the RIGHT of each row so don't shift origin.
    const bayLabelPx = 14.0;
    final bayLabelFt = bayLabelPx / _scale;
    const blockNamePx = 20.0;
    final blockNameFt = blockNamePx / _scale;
    final left = isVert ? posInFt.dx + blockNameFt : posInFt.dx;
    final top = isVert ? posInFt.dy : posInFt.dy + bayLabelFt;
    return Rect.fromLTWH(left, top, slotsW, slotsH);
  }

  Offset _clampBlock(Block block, Offset pos) {
    final yardWft = (widget.yard.yardWidth ?? 300).toDouble();
    final yardHft = (widget.yard.yardHeight ?? 170).toDouble();
    final slotsRect = _getSlotsRect(block, pos);
    double dx = pos.dx;
    double dy = pos.dy;
    if (slotsRect.left < 0) dx += -slotsRect.left;
    if (slotsRect.top < 0) dy += -slotsRect.top;
    if (slotsRect.right > yardWft) dx -= slotsRect.right - yardWft;
    if (slotsRect.bottom > yardHft) dy -= slotsRect.bottom - yardHft;
    return Offset(dx, dy);
  }

  Widget _buildPositionedBlock(Block block) {
    // offset in feet -> convert to pixels for layout
    final offsetFt =
        _blockOffsets[block.blockId] ??
        Offset((block.posX ?? 10).toDouble(), (block.posY ?? 10).toDouble());
    final offset = Offset(offsetFt.dx * _scale, offsetFt.dy * _scale);

    final bw = _BlockWidget(
      block: block,
      baysByBlock: _baysByBlock,
      rowsByBay: _rowsByBay,
      containersByRow: _containersByRow,

      highlightedRowId: _highlightedRowId,
      blinkCtrl: _blinkCtrl,
      editMode: _editMode,
      selectedRowId: _selectedSlotId,

      scaleX: _scaleX,
      scaleY: _scaleY,

      onSlotTap: _editMode
          ? null
          : (rowId, pos) => _showSlotTierPopup(rowId, pos),

      onSlotDrop: _editMode ? null : _dropToSlot,

      onSelectRow: _editMode
          ? (rowId) => setState(() => _selectedSlotId = rowId)
          : null,

      onAddBay: _editMode
          ? () async {
              await _api.addBay(block.blockId);
              await _loadAll();
            }
          : null,

      onRemoveBay: _editMode
          ? () async {
              try {
                await _api.removeBay(block.blockId);
                await _loadAll();
              } catch (_) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot remove bay')),
                  );
              }
            }
          : null,

      onDeleteBlock: _editMode
          ? () async {
              try {
                await _api.deleteBlock(block.blockId);
                setState(() => _selectedSlotId = null);
                await _loadAll();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Cannot delete: $e')));
              }
            }
          : null,

      onAddRow: _editMode
          ? () async {
              try {
                await _api.addRow(block.blockId);
                await _loadAll();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cannot add row: ' + e.toString()),
                      duration: const Duration(seconds: 4),
                    ),
                  );
              }
            }
          : null,

      onRemoveRow: _editMode
          ? () async {
              try {
                await _api.removeRow(block.blockId);
                await _loadAll();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cannot remove row: ' + e.toString()),
                      duration: const Duration(seconds: 4),
                    ),
                  );
              }
            }
          : null,
    );

    if (!_editMode)
      return Positioned(left: offset.dx, top: offset.dy, child: bw);

    return Positioned(
      left: offset.dx,
      top: offset.dy,

      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            final cur = _blockOffsets[block.blockId] ?? offsetFt;

            // delta is pixels, convert to feet
            final proposed = Offset(
              cur.dx + d.delta.dx / _scale,
              cur.dy + d.delta.dy / _scale,
            );

            _blockOffsets[block.blockId] = _clampBlock(block, proposed);
          });
        },

        onPanEnd: (_) async {
          final myPos = _blockOffsets[block.blockId]!;
          // Check slots-only overlap with every other block
          final myRect = _getSlotsRect(block, myPos);
          bool overlaps = false;
          // Deflate by 1px (in feet) so touching edges / header overlap is allowed;
          // only actual cell area intersection is rejected.
          final tolFt = 1.0 / _scale;
          final myDeflated = myRect.deflate(tolFt);
          for (final other in _blocks) {
            if (other.blockId == block.blockId) continue;
            final otherPos =
                _blockOffsets[other.blockId] ??
                Offset(
                  (other.posX ?? 10).toDouble(),
                  (other.posY ?? 10).toDouble(),
                );
            final otherDeflated = _getSlotsRect(other, otherPos).deflate(tolFt);
            if (myDeflated.overlaps(otherDeflated)) {
              overlaps = true;
              break;
            }
          }
          if (overlaps) {
            setState(
              () => _blockOffsets[block.blockId] = Offset(
                (block.posX ?? 10).toDouble(),
                (block.posY ?? 10).toDouble(),
              ),
            );
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Slot areas cannot overlap'),
                  duration: Duration(seconds: 1),
                ),
              );
            return;
          }
          try {
            await _api.updateBlockPosition(block.blockId, myPos.dx, myPos.dy);
          } catch (_) {}
        },

        child: bw,
      ),
    );
  }
}

// -- _ToolbarDropdown -----------------------------------------------------
class _ToolbarDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _ToolbarDropdown({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        DropdownButton<T>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 12)),
          items: items,
          onChanged: onChanged,
          isDense: true,
          underline: Container(height: 1, color: Colors.grey),
        ),
      ],
    );
  }
}

// -- _YardGridPainter -----------------------------------------------------
class _YardGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
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

// -- _BlockWidget ---------------------------------------------------------
class _BlockWidget extends StatelessWidget {
  final Block block;
  final Map<int, List<Bay>> baysByBlock;
  final Map<int, List<RowModel>> rowsByBay;
  final Map<int, List<ContainerModel>> containersByRow;
  final int? highlightedRowId;
  final AnimationController blinkCtrl;
  final bool editMode;
  final int? selectedRowId;
  final double scaleX, scaleY;
  final void Function(int rowId, Offset pos)? onSlotTap;
  final Future<void> Function(ContainerModel c, int rowId)? onSlotDrop;
  final void Function(int rowId)? onSelectRow;
  final VoidCallback? onAddBay;
  final VoidCallback? onRemoveBay;
  final VoidCallback? onDeleteBlock;
  final VoidCallback? onAddRow;
  final VoidCallback? onRemoveRow;

  const _BlockWidget({
    required this.block,
    required this.baysByBlock,
    required this.rowsByBay,
    required this.containersByRow,
    required this.highlightedRowId,
    required this.blinkCtrl,
    required this.editMode,
    required this.selectedRowId,
    required this.scaleX,
    required this.scaleY,
    this.onSlotTap,
    this.onSlotDrop,
    this.onSelectRow,
    this.onAddBay,
    this.onRemoveBay,
    this.onDeleteBlock,
    this.onAddRow,
    this.onRemoveRow,
  });

  @override
  Widget build(BuildContext context) {
    final bays = baysByBlock[block.blockId] ?? [];
    final isVert = block.isVertical;
    final is40 = block.is40ft;
    final cellW = (is40 ? k40ftWidth : k20ftWidth) * scaleX;
    final cellH = kContainerHeight * scaleY;

    // Horizontal: wide+short slots. Vertical: narrow+tall slots (rotated 90deg)
    final slotW = isVert ? cellH : cellW;
    final slotH = isVert ? cellW : cellH;

    final borderColor = isVert
        ? Colors.teal.shade700
        : Colors.blueGrey.shade700;
    final bgColor = isVert ? Colors.teal.shade50 : Colors.blueGrey.shade50;
    final headerBg = isVert ? Colors.teal.shade100 : Colors.blueGrey.shade100;
    final blockLabel = block.blockName ?? 'Block ${block.blockNumber}';

    Widget slotCell(RowModel row) => _SlotCell(
      row: row,
      containers: containersByRow[row.rowId] ?? [],
      width: slotW,
      height: slotH,
      isHighlighted: row.rowId == highlightedRowId,
      isSelected: row.rowId == selectedRowId,
      blinkCtrl: blinkCtrl,
      editMode: editMode,
      onTap: onSlotTap == null ? null : (pos) => onSlotTap!(row.rowId, pos),
      onDrop: onSlotDrop == null ? null : (c) => onSlotDrop!(c, row.rowId),
      onSelect: onSelectRow == null ? null : () => onSelectRow!(row.rowId),
    );

    if (isVert) {
      // VERTICAL layout:
      // - Row +/- at TOP-LEFT (adds/removes a column of slots on the left)
      // - Block name rotated on left side
      // - Bays stacked top-to-bottom; each bay row = slots (right-to-left = row1 rightmost) + bay label on right
      // - Bay +/- at BOTTOM-RIGHT (adds/removes a bay row at the bottom)

      // Each bay = one horizontal row of slot cells + bay label on right
      final bayRows = bays.map((bay) {
        // reversed so row 1 is rightmost (closest to bay label)
        final rows = (rowsByBay[bay.bayId] ?? []).reversed.toList();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...rows.map((row) => slotCell(row)),
            // Bay label on the right
            Container(
              width: 14,
              color: headerBg,
              alignment: Alignment.center,
              child: RotatedBox(
                quarterTurns: 1,
                child: Text(
                  bay.bayNumber,
                  style: TextStyle(
                    fontSize: 9,
                    color: borderColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList();

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TOP-LEFT: row +/- buttons
          if (editMode)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onAddRow,
                  child: const Icon(
                    Icons.add_circle,
                    size: 18,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: onRemoveRow,
                  child: const Icon(
                    Icons.remove_circle,
                    size: 18,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          // Middle: block name on left + bays grid
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Block name rotated on the left
              RotatedBox(
                quarterTurns: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  color: headerBg,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        blockLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: borderColor,
                        ),
                      ),
                      if (editMode) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: onDeleteBlock,
                          child: const Icon(
                            Icons.delete_forever,
                            size: 14,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Bays grid
              Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: bayRows,
                ),
              ),
            ],
          ),
          // BOTTOM-RIGHT: bay +/- buttons
          if (editMode)
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onAddBay,
                  child: const Icon(
                    Icons.add_circle,
                    size: 18,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: onRemoveBay,
                  child: const Icon(
                    Icons.remove_circle,
                    size: 18,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
        ],
      );
    } else {
      // HORIZONTAL: bay labels above each column, block name at bottom, +/- top-right
      final cols = bays.map((bay) {
        final rows = rowsByBay[bay.bayId] ?? [];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bay label above column
            SizedBox(
              width: slotW,
              height: 14,
              child: Center(
                child: Text(
                  bay.bayNumber,
                  style: TextStyle(
                    fontSize: 9,
                    color: borderColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            ...rows.map((row) => slotCell(row)),
          ],
        );
      }).toList();

      // HORIZONTAL layout:
      // - Bay +/- buttons at TOP-RIGHT
      // - Bay labels + slots
      // - Block name at bottom
      // - Row +/- buttons at BOTTOM-LEFT
      return Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row: bay +/- on right
            if (editMode)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onAddBay,
                    child: const Icon(
                      Icons.add_circle,
                      size: 18,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 2),
                  GestureDetector(
                    onTap: onRemoveBay,
                    child: const Icon(
                      Icons.remove_circle,
                      size: 18,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            // Columns with bay labels + slots
            Row(mainAxisSize: MainAxisSize.min, children: cols),
            // Block name at bottom
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              color: headerBg,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    blockLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: borderColor,
                    ),
                  ),
                  if (editMode) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onDeleteBlock,
                      child: const Icon(
                        Icons.delete_forever,
                        size: 14,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Bottom row: row +/- on left
            if (editMode)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: onAddRow,
                    child: const Icon(
                      Icons.add_circle,
                      size: 18,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 2),
                  GestureDetector(
                    onTap: onRemoveRow,
                    child: const Icon(
                      Icons.remove_circle,
                      size: 18,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    }
  }
}

// -- _SlotCell -----------------------------------------------------------------
class _SlotCell extends StatelessWidget {
  final RowModel row;

  final List<ContainerModel> containers;

  final double width, height;

  final bool isHighlighted, isSelected, editMode;

  final AnimationController blinkCtrl;

  final void Function(Offset pos)? onTap;

  final Future<void> Function(ContainerModel c)? onDrop;

  final VoidCallback? onSelect;

  const _SlotCell({
    required this.row,

    required this.containers,

    required this.width,

    required this.height,

    required this.isHighlighted,

    required this.isSelected,

    required this.blinkCtrl,

    required this.editMode,

    this.onTap,

    this.onDrop,

    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final inYard = containers.where((c) => !c.isMovedOut).toList()
      ..sort((a, b) => (a.tier ?? 0).compareTo(b.tier ?? 0));

    final maxT = row.maxStack;

    final topContainer = inYard.isNotEmpty ? inYard.last : null;

    final Color border = isSelected
        ? Colors.yellow
        : isHighlighted
        ? Colors.orange
        : Colors.grey.shade400;

    return GestureDetector(
      onTapUp: editMode
          ? (d) {
              onSelect?.call();
            }
          : (d) {
              onTap?.call(d.globalPosition);
            },

      child: DragTarget<ContainerModel>(
        onWillAcceptWithDetails: (d) =>
            !editMode && !d.data.isMovedOut && inYard.length < maxT,

        onAcceptWithDetails: (d) {
          onDrop?.call(d.data);
        },

        builder: (ctx, candidates, _) {
          final highlight = candidates.isNotEmpty;

          final bgColor = topContainer == null
              ? (highlight
                    ? Colors.green.shade100
                    : isHighlighted
                    ? Colors.yellow.shade200
                    : Colors.white)
              : (topContainer.statusId == 1
                    ? Colors.amber.shade300
                    : Colors.red.shade300);

          Widget cellContent = Container(
            width: width,

            height: height,

            decoration: BoxDecoration(
              color: bgColor,

              border: Border.all(
                color: highlight ? Colors.green : border,

                width: isSelected ? 2 : 1,
              ),
            ),

            child: topContainer == null
                ? Center(
                    child: Text(
                      '${row.rowNumber}',

                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey.shade500,
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
                            '${inYard.length}/$maxT',

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

          if (topContainer != null && !editMode) {
            cellContent = Draggable<ContainerModel>(
              data: topContainer,

              rootOverlay: false,

              feedback: Material(
                color: Colors.transparent,

                child: Container(
                  width: width,

                  height: height,

                  decoration: BoxDecoration(
                    color:
                        (topContainer.statusId == 1
                                ? Colors.amber.shade300
                                : Colors.red.shade300)
                            .withAlpha(200),

                    borderRadius: BorderRadius.circular(3),
                  ),

                  child: Center(
                    child: Text(
                      topContainer.containerNumber,

                      style: const TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              childWhenDragging: Container(
                width: width,

                height: height,

                decoration: BoxDecoration(
                  color: Colors.grey.shade200,

                  border: Border.all(color: border, width: isSelected ? 2 : 1),
                ),

                child: inYard.length > 1
                    ? Center(
                        child: Text(
                          inYard[inYard.length - 2].containerNumber,

                          style: TextStyle(
                            fontSize: 7,
                            color: Colors.grey.shade600,
                          ),

                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : null,
              ),

              child: cellContent,
            );
          }

          return isHighlighted
              ? AnimatedBuilder(
                  animation: blinkCtrl,
                  builder: (_, __) {
                    final t = blinkCtrl.value;
                    // Pulse between a bright yellow-green and deep orange border
                    final pulseColor = Color.lerp(
                      const Color(0xFFFFEB3B), // bright yellow
                      const Color(0xFFFF5722), // deep orange-red
                      t,
                    )!;
                    final glowColor = pulseColor.withAlpha((180 * t).round());
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: pulseColor, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: glowColor,
                            blurRadius: 8 * t,
                            spreadRadius: 2 * t,
                          ),
                        ],
                      ),
                      child: cellContent,
                    );
                  },
                )
              : cellContent;
        },
      ),
    );
  }
}

// -- Add Block Dialog ----------------------------------------------------------
class _AddBlockDialog extends StatefulWidget {
  final List<SizeModel> sizes;
  final List<OrientationModel> orientations;
  final Future<void> Function(
    String name,
    int bays,
    int rows,
    int orientId,
    int sizeId,
    int maxStack,
  )
  onConfirm;
  const _AddBlockDialog({
    required this.sizes,
    required this.orientations,
    required this.onConfirm,
  });
  @override
  State<_AddBlockDialog> createState() => _AddBlockDialogState();
}

class _AddBlockDialogState extends State<_AddBlockDialog> {
  final _nameCtrl = TextEditingController();
  final _baysCtrl = TextEditingController(text: '2');
  final _rowsCtrl = TextEditingController(text: '4');
  final _stackCtrl = TextEditingController(text: '5');
  int? _orientId;
  int? _sizeId;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _baysCtrl.dispose();
    _rowsCtrl.dispose();
    _stackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Block',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const Divider(height: 14),
              // 2-column grid for numeric fields
              Row(
                children: [
                  Expanded(
                    child: _compactField(
                      'Block Name',
                      _nameCtrl,
                      hint: 'e.g. Block A',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _compactField(
                      'Bays',
                      _baysCtrl,
                      hint: '2',
                      numeric: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _compactField(
                      'Rows',
                      _rowsCtrl,
                      hint: '4',
                      numeric: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _compactField(
                      'Max Stack',
                      _stackCtrl,
                      hint: '5',
                      numeric: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Orientation',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        DropdownButtonFormField<int>(
                          value: _orientId,
                          isDense: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text(
                            'Select',
                            style: TextStyle(fontSize: 12),
                          ),
                          items: widget.orientations
                              .map(
                                (o) => DropdownMenuItem(
                                  value: o.orientationId,
                                  child: Text(
                                    o.orientationDesc,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _orientId = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Size',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        DropdownButtonFormField<int>(
                          value: _sizeId,
                          isDense: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text(
                            'Select',
                            style: TextStyle(fontSize: 12),
                          ),
                          items: widget.sizes
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.sizeId,
                                  child: Text(
                                    s.sizeDesc,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _sizeId = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Block',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    bool numeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        TextField(
          controller: ctrl,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            border: const OutlineInputBorder(),
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final bays = int.tryParse(_baysCtrl.text.trim()) ?? 0;
    final rows = int.tryParse(_rowsCtrl.text.trim()) ?? 0;
    final stack = int.tryParse(_stackCtrl.text.trim()) ?? 5;
    if (name.isEmpty ||
        bays < 1 ||
        rows < 1 ||
        _orientId == null ||
        _sizeId == null)
      return;
    setState(() => _loading = true);
    await widget.onConfirm(name, bays, rows, _orientId!, _sizeId!, stack);
    if (mounted) Navigator.pop(context);
  }
}

// -- Tier Popup ----------------------------------------------------------------
class _TierPopup extends StatefulWidget {
  final List<ContainerModel> containers;
  final VoidCallback onClose;
  const _TierPopup({required this.containers, required this.onClose});
  @override
  State<_TierPopup> createState() => _TierPopupState();
}

class _TierPopupState extends State<_TierPopup> {
  ContainerModel? _selected;

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
        child: _selected != null ? _buildDetails(_selected!) : _buildList(),
      ),
    );
  }

  Widget _buildList() {
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
        ...widget.containers.map(
          (c) => GestureDetector(
            onTap: () => setState(() => _selected = c),
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
                      color: c.statusId == 1 ? Colors.amber : Colors.red,
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
          ),
        ),
      ],
    );
  }

  Widget _buildDetails(ContainerModel c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() => _selected = null),
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
        _infoRow('Status:', c.statusId == 1 ? 'Laden' : 'Empty'),
        _infoRow('Type:', c.type ?? '-'),
        _infoRow('Tier:', '${c.tier ?? '-'}'),
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
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            c.containerDesc ?? '-',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
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
  }
}

// -- Move Out Dialog -----------------------------------------------------------
class _MoveOutDialog extends StatefulWidget {
  final ContainerModel container;
  final List<Truck> trucks;
  final Future<void> Function(int truckId, String boundTo) onConfirm;
  const _MoveOutDialog({
    required this.container,
    required this.trucks,
    required this.onConfirm,
  });
  @override
  State<_MoveOutDialog> createState() => _MoveOutDialogState();
}

class _MoveOutDialogState extends State<_MoveOutDialog> {
  int? _truckId;
  final _boundCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _boundCtrl.dispose();
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
            Text(
              widget.container.containerNumber,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Truck:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            DropdownButton<int>(
              value: _truckId,
              isExpanded: true,
              hint: const Text('Select truck'),
              items: widget.trucks
                  .map(
                    (t) => DropdownMenuItem(
                      value: t.truckId,
                      child: Text(t.truckName),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _truckId = v),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bound To:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _boundCtrl,
              decoration: const InputDecoration(
                hintText: 'Destination / consignee',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading || _truckId == null ? null : _submit,
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

  Future<void> _submit() async {
    if (_truckId == null) return;
    setState(() => _loading = true);
    await widget.onConfirm(_truckId!, _boundCtrl.text.trim());
    if (mounted) Navigator.pop(context);
  }
}
