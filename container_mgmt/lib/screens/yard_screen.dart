import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/session.dart';
import '../models/yard.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../models/row_model.dart';
import '../models/container_model.dart';
import '../models/size_model.dart';
import '../models/customer_model.dart';
import '../models/orientation_model.dart';
import '../models/truck.dart';
import '../widgets/container_holding_area.dart';

const double kContainerHeight = 8.0;
const double k20ftWidth = 20.0;
const double k40ftWidth = 40.0;
const double kYardBorderPx = 16.0;

class YardScreen extends StatefulWidget {
  final Yard yard;
  final int portId;
  final String portName;
  final int? highlightRowId;
  final Session? session;
  const YardScreen({
    super.key,
    required this.yard,
    required this.portId,
    required this.portName,
    this.highlightRowId,
    this.session,
  });
  @override
  State<YardScreen> createState() => _YardScreenState();
}

class _YardScreenState extends State<YardScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late Yard _yard;
  List<Block> _blocks = [];
  Map<int, List<Bay>> _baysByBlock = {};
  Map<int, List<RowModel>> _rowsByBay = {};
  Map<int, List<ContainerModel>> _containersByRow = {};
  Map<int, List<ContainerModel>> _confirmedContainersByRow = {};
  Map<int, List<ContainerModel>> _requestContainersByRow = {};
  List<ContainerModel> _containers = [];
  List<ContainerModel> _movedOutContainers = [];
  List<SizeModel> _sizes = [];
  List<CustomerModel> _customers = [];
  List<OrientationModel> _orientations = [];
  bool _loading = true;
  bool _editMode = false;
  bool _saving = false;
  int? _selectedOrientationId;
  int? _selectedSizeId;
  String? _selectedSlotEdit;
  int? _selectedSlotId;
  final Map<int, Offset> _blockOffsets = {};
  final Map<int, double> _blockRotations = {}; // rotation in radians
  final Map<int, GlobalKey> _blockKeys = {}; // for getting block center
  int? _tierPopupRowId;
  Offset? _tierPopupPosition;
  final _yardKey = GlobalKey();
  final _searchCtrl = TextEditingController();
  ContainerModel? _foundContainer;
  int? _highlightedRowId;
  bool _showMoveOutList = false;
  bool _showCheckerView = true;
  double _scale = 3.0;
  Timer? _pollTimer;
  double get _canvasW => (_yard.yardWidth ?? 300) * _scale;
  double get _canvasH => (_yard.yardHeight ?? 170) * _scale;
  double get _scaleX => _scale;
  double get _scaleY => _scale;
  late AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _yard = widget.yard;
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    if (widget.highlightRowId != null) {
      _highlightedRowId = widget.highlightRowId;
      _blinkCtrl.repeat(reverse: true);
    }
    _loadAll();
    // Auto-refresh every 5s — uses silent refresh to avoid flicker
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_editMode) _silentRefresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _blinkCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    if (!mounted) return;
    try {
      final results = await Future.wait([
        _api.getBlocks(widget.yard.yardId),
        _api.getContainersByPort(widget.portId),
        _api.getMovedOutContainers(widget.portId),
        _api.getSizes(),
        _api.getOrientations(),
        _api.getYardById(widget.yard.yardId),
        _api.getCustomers(),
      ]);
      final blocks = results[0] as List<Block>;
      final containers = results[1] as List<ContainerModel>;
      final movedOut = results[2] as List<ContainerModel>;
      final sizes = results[3] as List<SizeModel>;
      final orientations = results[4] as List<OrientationModel>;
      final freshYard = results[5] as Yard?;
      final customers = results[6] as List<CustomerModel>;

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

      final Map<int, List<ContainerModel>> confirmedByRow = {};
      final Map<int, List<ContainerModel>> requestByRow = {};
      for (final c in containers) {
        if (c.rowId != null && !c.isMovedOut) {
          if (c.locationStatusId == 1) {
            confirmedByRow.putIfAbsent(c.rowId!, () => []).add(c);
          }
          if (c.locationStatusId == 3 || c.locationStatusId == 1) {
            requestByRow.putIfAbsent(c.rowId!, () => []).add(c);
          }
        }
      }
      for (final list in confirmedByRow.values) {
        list.sort((a, b) => (a.tier ?? 0).compareTo(b.tier ?? 0));
      }
      for (final list in requestByRow.values) {
        list.sort((a, b) => (a.tier ?? 0).compareTo(b.tier ?? 0));
      }

      if (!mounted) return;
      setState(() {
        if (freshYard != null) _yard = freshYard;
        _blocks = blocks;
        _baysByBlock = baysByBlock;
        _rowsByBay = rowsByBay;
        _containersByRow = _showCheckerView ? requestByRow : confirmedByRow;
        _confirmedContainersByRow = confirmedByRow;
        _requestContainersByRow = requestByRow;
        _containers = containers;
        _movedOutContainers = movedOut;
        _sizes = sizes;
        _orientations = orientations;
        _customers = customers;
        // Sync block positions
        for (final b in blocks) {
          _blockOffsets[b.blockId] = Offset(
            (b.posX ?? 10).toDouble(),
            (b.posY ?? 10).toDouble(),
          );
          _blockRotations[b.blockId] = b.rotation;
        }
      });
    } catch (_) {}
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
        _api.getYardById(widget.yard.yardId),
        _api.getCustomers(),
      ]);
      final blocks = results[0] as List<Block>;
      final containers = results[1] as List<ContainerModel>;
      final movedOut = results[2] as List<ContainerModel>;
      final sizes = results[3] as List<SizeModel>;
      final orientations = results[4] as List<OrientationModel>;
      final freshYard = results[5] as Yard?;
      final customers = results[6] as List<CustomerModel>;
      final Map<int, List<Bay>> baysByBlock = {};
      final Map<int, List<RowModel>> rowsByBay = {};
      // Fetch all bays in parallel
      final bayResults = await Future.wait(
        blocks.map((block) => _api.getBays(block.blockId)),
      );
      for (int i = 0; i < blocks.length; i++) {
        baysByBlock[blocks[i].blockId] = bayResults[i];
      }
      // Fetch all rows in parallel across all bays
      final allBays = bayResults.expand((b) => b).toList();
      final rowResults = await Future.wait(
        allBays.map((bay) => _api.getRows(bay.bayId)),
      );
      for (int i = 0; i < allBays.length; i++) {
        rowsByBay[allBays[i].bayId] = rowResults[i];
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
      // Confirmed view: only locationStatusId == 1 (In Yard)
      final Map<int, List<ContainerModel>> confirmedByRow = {};
      // Checker view: locationStatusId == 3 (Move Request) + 1 (In Yard)
      final Map<int, List<ContainerModel>> requestByRow = {};
      for (final c in containers) {
        if (c.rowId != null && !c.isMovedOut) {
          if (c.locationStatusId == 1) {
            confirmedByRow.putIfAbsent(c.rowId!, () => []).add(c);
          }
          if (c.locationStatusId == 3 || c.locationStatusId == 1) {
            requestByRow.putIfAbsent(c.rowId!, () => []).add(c);
          }
        }
      }
      for (final list in confirmedByRow.values) {
        list.sort((a, b) => (a.tier ?? 0).compareTo(b.tier ?? 0));
      }
      for (final list in requestByRow.values) {
        list.sort((a, b) => (a.tier ?? 0).compareTo(b.tier ?? 0));
      }
      setState(() {
        if (freshYard != null) _yard = freshYard;
        _blocks = blocks;
        debugPrint('Yard imagePath: ${_yard.imagePath}');
        _baysByBlock = baysByBlock;
        _rowsByBay = rowsByBay;
        _containersByRow = requestByRow; // default to checker view
        _confirmedContainersByRow = confirmedByRow;
        _requestContainersByRow = requestByRow;
        _containers = containers;
        _movedOutContainers = movedOut;
        _sizes = sizes;
        _orientations = orientations;
        _customers = customers;
        _loading = false;
        // Always sync offsets from DB so saved positions are reflected
        for (final b in blocks) {
          _blockOffsets[b.blockId] = Offset(
            (b.posX ?? 10).toDouble(),
            (b.posY ?? 10).toDouble(),
          );
          _blockRotations[b.blockId] = b.rotation;
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
    // Size match: container's sizeId must match the slot's sizeId
    final slotSizeId = targetRow?.sizeId;
    final containerSizeId = container.containerSizeId;
    if (slotSizeId != null &&
        containerSizeId != null &&
        slotSizeId != containerSizeId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Size mismatch: slot is ${slotSizeId == 1 ? "20ft" : "40ft"}, container is ${containerSizeId == 1 ? "20ft" : "40ft"}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
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
        locationStatusId: 3,
      );
      // Explicitly set locationStatusId = 3 (Move Request) in case
      // the backend's /location endpoint doesn't save locationStatusId
      try {
        await _api.setMoveRequest(container.containerId);
      } catch (_) {}
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
      await Future.wait([
        ..._blocks.map((b) {
          final pos =
              _blockOffsets[b.blockId] ??
              Offset((b.posX ?? 10).toDouble(), (b.posY ?? 10).toDouble());
          return _api.updateBlockPosition(b.blockId, pos.dx, pos.dy);
        }),
        ..._blocks.map((b) {
          final rot = _blockRotations[b.blockId] ?? b.rotation;
          return _api.updateBlockRotation(b.blockId, rot);
        }),
      ]);
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
    final empty = inYard.where((c) => c.statusId == 2).length;
    final ft20 = inYard.where((c) => c.containerSizeId == 1).length;
    final ft40 = inYard.where((c) => c.containerSizeId == 2).length;

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
                '${widget.portName}  �  Yard ${widget.yard.yardNumber}',
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

  void _showTransferDialog(ContainerModel container) {
    showDialog(
      context: context,
      builder: (_) => _TransferDialog(
        container: container,
        portId: widget.portId,
        currentYardId: _yard.yardId,
        api: _api,
        onTransferred: _loadAll,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot delete: row has containers')),
          );
        }
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
      body: Stack(
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
                            border: Border.all(color: Colors.blue, width: 4),
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
              child: YardTierPopup(
                containers: _containersByRow[_tierPopupRowId!] ?? [],
                onClose: _closeTierPopup,
                customers: _customers,
                portName: widget.portName,
                yardNumber: _yard.yardNumber,
                blocks: _blocks,
                baysById: {
                  for (final list in _baysByBlock.values)
                    for (final b in list) b.bayId: b,
                },
                rowsById: {
                  for (final list in _rowsByBay.values)
                    for (final r in list) r.rowId: r,
                },
              ),
            ),
          if (_foundContainer != null)
            Positioned(top: 44, right: 0, child: _buildSearchResultCard()),
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
                    separatorBuilder: (_, _) => const Divider(height: 1),
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
                          c.boundTo != null ? 'Bound to: ${c.boundTo}' : '',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          // Semi-transparent loading overlay
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
              if (v != null && _selectedSlotId != null) {
                _applyOrientationChange(_selectedSlotId!, v);
              }
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
              if (v != null && _selectedSlotId != null) {
                _applySizeChange(_selectedSlotId!, v);
              }
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
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot delete: slot has containers'),
                          ),
                        );
                      }
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
            onWillAcceptWithDetails: (d) =>
                !d.data.isMovedOut && d.data.rowId != null,
            onAcceptWithDetails: (d) => _showTransferDialog(d.data),
            builder: (ctx, candidates, _) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: candidates.isNotEmpty
                    ? Colors.blue[700]
                    : Colors.blue[600],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Transfer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
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
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.search_rounded,
                      color: AppColors.textGrey,
                      size: 18,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search container number',
                        hintStyle: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _searchContainer(),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: _clearSearch,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  GestureDetector(
                    onTap: _searchContainer,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.yellow,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(7),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Locate',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.textDark,
                        ),
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
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => YardContainerDetailsDialog(
                    container: c,
                    customers: _customers,
                    portName: widget.portName,
                    yardNumber: _yard.yardNumber,
                    blocks: _blocks,
                    baysById: {
                      for (final list in _baysByBlock.values)
                        for (final b in list) b.bayId: b,
                    },
                    rowsById: {
                      for (final list in _rowsByBay.values)
                        for (final r in list) r.rowId: r,
                    },
                  ),
                ),
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
                  'View Full Details',
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
        // Fit yard to viewport once; lock after that to prevent jumps
        final fitScale = (availW / yardW) < (availH / yardH)
            ? (availW / yardW)
            : (availH / yardH);
        if (_scale == 3.0) {
          // Set immediately so all child widgets use the correct scale on first frame
          _scale = fitScale;
        }
        final cw = yardW * _scale;
        final ch = yardH * _scale;
        // Fixed frame � InteractiveViewer zooms/pans only inside it
        return Stack(
          children: [
            Container(
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
                        color: _yard.imagePath != null
                            ? null
                            : Colors.grey[300],
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
                      child: CustomPaint(painter: _YardGridPainter()),
                    ),
                    ..._blocks.map((b) => _buildPositionedBlock(b)),
                  ],
                ),
              ),
            ),
            // View Full + Toggle overlay
            Positioned(
              top: 8,
              left: 8,
              child: Row(
                children: [
                  // Toggle: Checker / Confirmed
                  GestureDetector(
                    onTap: () => setState(() {
                      _showCheckerView = !_showCheckerView;
                      _containersByRow = _showCheckerView
                          ? _requestContainersByRow
                          : _confirmedContainersByRow;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _showCheckerView
                            ? Colors.blue.withOpacity(0.8)
                            : Colors.green.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showCheckerView
                                ? Icons.pending_actions
                                : Icons.check_circle,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showCheckerView ? 'Checker View' : 'Confirmed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // View Full button
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _FullScreenYardView(
                          yard: _yard,
                          blocks: _blocks,
                          baysByBlock: _baysByBlock,
                          rowsByBay: _rowsByBay,
                          containersByRow: _containersByRow,
                          blockOffsets: Map.from(_blockOffsets),
                          blockRotations: Map.from(_blockRotations),
                          scale: _scale,
                          portName: widget.portName,
                          customers: _customers,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'View Full',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    final slotLong = (is40 ? k40ftWidth : k20ftWidth);
    final slotShort = kContainerHeight;
    final slotW = isVert ? slotShort : slotLong;
    final slotH = isVert ? slotLong : slotShort;
    int maxRows = 0;
    for (final bay in bays) {
      final rows = _rowsByBay[bay.bayId] ?? [];
      if (rows.length > maxRows) maxRows = rows.length;
    }
    final numBays = bays.length;
    // Vertical block: bays stack vertically, rows stack horizontally
    // Horizontal block: bays stack horizontally, rows stack vertically
    final totalW = isVert
        ? (maxRows == 0 ? slotW : maxRows * slotW) +
              (maxRows > 1 ? (maxRows - 1) * 1.0 : 0)
        : (numBays == 0 ? slotW : numBays * slotW) +
              (numBays > 1 ? (numBays - 1) * 2.5 : 0);
    final totalH = isVert
        ? (numBays == 0 ? slotH : numBays * slotH) +
              (numBays > 1 ? (numBays - 1) * 2.5 : 0)
        : (maxRows == 0 ? slotH : maxRows * slotH) +
              (maxRows > 1 ? (maxRows - 1) * 1.0 : 0);
    // For vertical blocks the left column (buttons+name) is outside the slot grid.
    // posInFt is the widget top-left; slot grid starts after the left column (~40px).
    // For horizontal blocks the bay-label row (14px) is above the slots.
    const leftColPx = 40.0; // approx width of vertical block's left column
    final left = isVert ? posInFt.dx + leftColPx / _scale : posInFt.dx;
    // Labels/buttons are allowed outside yard � clamp only on raw posInFt.dy
    final top = posInFt.dy;
    return Rect.fromLTWH(left, top, totalW, totalH);
  }

  Offset _clampBlock(Block block, Offset pos) {
    final yardWft = (_yard.yardWidth ?? 300).toDouble();
    final yardHft = (_yard.yardHeight ?? 170).toDouble();
    final slotsRect = _getSlotsRect(block, pos);
    double dx = pos.dx;
    double dy = pos.dy;
    // Only prevent slots from going past the top/left edges.
    // Bottom/right: allow blocks to reach the yard edge freely.
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
    final rotation = _blockRotations[block.blockId] ?? block.rotation;
    final blockKey = _blockKeys.putIfAbsent(block.blockId, () => GlobalKey());

    final bw = YardBlockWidget(
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
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot remove bay')),
                  );
                }
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
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Cannot delete: $e')));
                }
              }
            }
          : null,

      onAddRow: _editMode
          ? () async {
              try {
                await _api.addRow(block.blockId);
                await _loadAll();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cannot add row: $e'),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            }
          : null,

      onRemoveRow: _editMode
          ? () async {
              try {
                await _api.removeRow(block.blockId);
                await _loadAll();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cannot remove row: $e'),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            }
          : null,
      rotateHandle: _editMode
          ? Listener(
              onPointerMove: (e) {
                final b =
                    blockKey.currentContext?.findRenderObject() as RenderBox?;
                if (b == null) return;
                final center = b.localToGlobal(
                  Offset(b.size.width / 2, b.size.height / 2),
                );
                final angle = (e.position - center).direction;
                final prevAngle = (e.position - e.delta - center).direction;
                setState(() {
                  final cur = _blockRotations[block.blockId] ?? block.rotation;
                  _blockRotations[block.blockId] = cur + (angle - prevAngle);
                });
              },
              onPointerUp: (_) async {
                final rot = _blockRotations[block.blockId] ?? block.rotation;
                try {
                  await _api.updateBlockRotation(block.blockId, rot);
                } catch (_) {}
              },
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rotate_right,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            )
          : null,
    );

    if (!_editMode) {
      return Positioned(
        left: offset.dx,
        top: offset.dy,
        child: Transform.rotate(angle: rotation, child: bw),
      );
    }
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Transform.rotate(
        angle: rotation,
        child: Stack(
          key: blockKey,
          clipBehavior: Clip.none,
          children: [
            // Block with drag gesture
            GestureDetector(
              onPanUpdate: (d) {
                setState(() {
                  final cur = _blockOffsets[block.blockId] ?? offsetFt;
                  final proposed = Offset(
                    cur.dx + d.delta.dx / _scale,
                    cur.dy + d.delta.dy / _scale,
                  );
                  _blockOffsets[block.blockId] = _clampBlock(block, proposed);
                });
              },
              onPanEnd: (_) async {
                final myPos = _blockOffsets[block.blockId]!;
                final myRect = _getSlotsRect(block, myPos);
                bool overlaps = false;
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
                  final otherDeflated = _getSlotsRect(
                    other,
                    otherPos,
                  ).deflate(tolFt);
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
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Slot areas cannot overlap'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                  return;
                }
                try {
                  await _api.updateBlockPosition(
                    block.blockId,
                    myPos.dx,
                    myPos.dy,
                  );
                } catch (_) {}
              },
              child: bw,
            ),
            // Rotate handle is now inside _BlockWidget's bay +/- column
          ],
        ),
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

// -- _BlockWidget ---------------------------------------------------------
class YardBlockWidget extends StatelessWidget {
  final Block block;
  final Map<int, List<Bay>> baysByBlock;
  final Map<int, List<RowModel>> rowsByBay;
  final Map<int, List<ContainerModel>> containersByRow;
  final int? highlightedRowId;
  final Color?
  highlightColor; // custom blink color (null = default yellow/orange)
  final bool highlightOnly; // render only the highlighted slot, rest invisible
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
  final Widget? rotateHandle;
  final VoidCallback? onAddRow;
  final VoidCallback? onRemoveRow;

  const YardBlockWidget({super.key, 
    required this.block,
    required this.baysByBlock,
    required this.rowsByBay,
    required this.containersByRow,
    required this.highlightedRowId,
    this.highlightColor,
    this.highlightOnly = false,
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
    this.rotateHandle,
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
    final slotW = isVert ? cellH : cellW;
    final slotH = isVert ? cellW : cellH;

    // highlightOnly: render ONLY the highlighted slot, everything else transparent
    // This avoids double-rendering block borders/labels
    if (highlightOnly && highlightedRowId != null) {
      return YardHighlightSlot(
        bays: bays,
        rowsByBay: rowsByBay,
        highlightedRowId: highlightedRowId!,
        highlightColor: highlightColor ?? Colors.orange,
        slotW: slotW,
        slotH: slotH,
        isVert: isVert,
        blinkCtrl: blinkCtrl,
        scaleX: scaleX,
        scaleY: scaleY,
      );
    }
    final borderColor = highlightOnly ? Colors.transparent : Colors.white;
    final bgColor = Colors.transparent;
    final headerBg = Colors.transparent;
    final blockLabel = block.blockName ?? 'Block ${block.blockNumber}';

    Widget slotCell(RowModel row) => _SlotCell(
      row: row,
      containers: containersByRow[row.rowId] ?? [],
      width: slotW,
      height: slotH,
      isHighlighted: row.rowId == highlightedRowId,
      highlightColor: highlightColor,
      highlightOnly: highlightOnly,
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
      final bayGapH = 2.5 * scaleY; // 2.5ft gap between bays
      final rowGapW = 1.0 * scaleX; // 1ft gap between rows
      final bayRows = bays.map((bay) {
        // reversed so row 1 is rightmost (closest to bay label)
        final rows = (rowsByBay[bay.bayId] ?? []).reversed.toList();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(width: rowGapW),
              slotCell(rows[i]),
            ],
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

      // Interleave bay gap between bay rows
      final bayRowsWithGaps = <Widget>[];
      for (int i = 0; i < bayRows.length; i++) {
        if (i > 0) bayRowsWithGaps.add(SizedBox(height: bayGapH));
        bayRowsWithGaps.add(bayRows[i]);
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDE: row +/- on top, block name below (both outside the block)
          Visibility(
            visible: !highlightOnly,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (editMode) ...[
                  GestureDetector(
                    onTap: onAddRow,
                    child: const Icon(
                      Icons.add_circle,
                      size: 20,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: onRemoveRow,
                    child: const Icon(
                      Icons.remove_circle,
                      size: 20,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                // Block name rotated, sticking out on the left
                RotatedBox(
                  quarterTurns: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          blockLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
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
              ],
            ),
          ), // end Visibility
          // Bays grid + bay +/- below
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: bayRowsWithGaps,
                ),
              ),
              if (editMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onAddBay,
                      child: const Icon(
                        Icons.add_circle,
                        size: 20,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 2),
                    GestureDetector(
                      onTap: onRemoveBay,
                      child: const Icon(
                        Icons.remove_circle,
                        size: 20,
                        color: Colors.orange,
                      ),
                    ),
                    if (rotateHandle != null) ...[
                      const SizedBox(width: 2),
                      rotateHandle!,
                    ],
                  ],
                ),
            ],
          ),
        ],
      );
    } else {
      // HORIZONTAL: bay labels above each column, block name at bottom, +/- top-right
      final bayGapW = 2.5 * scaleX; // 2.5ft gap between bays
      final rowGapH = 1.0 * scaleY; // 1ft gap between rows
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
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: rowGapH),
              slotCell(rows[i]),
            ],
          ],
        );
      }).toList();

      // Interleave bay gap between columns
      final colsWithGaps = <Widget>[];
      for (int i = 0; i < cols.length; i++) {
        if (i > 0) colsWithGaps.add(SizedBox(width: bayGapW));
        colsWithGaps.add(cols[i]);
      }

      // HORIZONTAL layout:
      // - Bay +/- on the RIGHT side (stacked vertically, outside border)
      // - Row +/- on the BOTTOM LEFT (outside border)
      final blockWidget = Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: colsWithGaps),
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Block + bay buttons on right
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              blockWidget,
              if (editMode) ...[
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onAddBay,
                      child: const Icon(
                        Icons.add_circle,
                        size: 20,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: onRemoveBay,
                      child: const Icon(
                        Icons.remove_circle,
                        size: 20,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ?rotateHandle,
                  ],
                ),
              ],
            ],
          ),
          // Block name � highlighted label sticking out below the block
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  blockLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade700,
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
          // Row +/- below block on the left
          if (editMode)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onAddRow,
                  child: const Icon(
                    Icons.add_circle,
                    size: 20,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: onRemoveRow,
                  child: const Icon(
                    Icons.remove_circle,
                    size: 20,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
        ],
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
  final Color? highlightColor;
  final bool highlightOnly;
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
    this.highlightColor,
    this.highlightOnly = false,
    this.onTap,
    this.onDrop,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // In highlightOnly mode, non-highlighted slots are fully invisible
    if (highlightOnly && !isHighlighted) {
      return SizedBox(width: width, height: height);
    }
    final inYard = containers.where((c) => !c.isMovedOut).toList()
      ..sort((a, b) => (a.tier ?? 0).compareTo(b.tier ?? 0));

    final maxT = row.maxStack;

    final topContainer = inYard.isNotEmpty ? inYard.last : null;

    final Color border = isSelected
        ? Colors.yellow
        : isHighlighted
        ? Colors.orange
        : Colors.white;

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
            !editMode &&
            !d.data.isMovedOut &&
            inYard.length < maxT &&
            // Size match: if both slot and container have a sizeId, they must match
            (row.sizeId == null ||
                d.data.containerSizeId == null ||
                row.sizeId == d.data.containerSizeId),

        onAcceptWithDetails: (d) {
          onDrop?.call(d.data);
        },

        builder: (ctx, candidates, _) {
          final highlight = candidates.isNotEmpty;

          final bgColor = topContainer == null
              ? (highlight
                    ? Colors.green.withAlpha(60)
                    : isHighlighted
                    ? Colors.yellow.withAlpha(80)
                    : Colors.transparent)
              : topContainer.locationStatusId == 3
              ? Colors
                    .blue
                    .shade300 // Move Request � pending confirmation
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

                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white70,
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
                        (topContainer.locationStatusId == 3
                                ? Colors.blue.shade300
                                : topContainer.statusId == 1
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
                  builder: (_, _) {
                    final t = blinkCtrl.value;
                    // Use custom color if provided, otherwise default yellow/orange
                    final Color pulseColor;
                    if (highlightColor != null) {
                      pulseColor = highlightColor!.withValues(
                        alpha: 0.5 + t * 0.5,
                      );
                    } else {
                      pulseColor = Color.lerp(
                        const Color(0xFFFFEB3B), // bright yellow
                        const Color(0xFFFF5722), // deep orange-red
                        t,
                      )!;
                    }
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

// -- YardHighlightSlot -------------------------------------------------------
// Renders only the highlighted slot at its correct position within a block,
// with everything else invisible. Used for blink overlays in driver view.
class YardHighlightSlot extends StatelessWidget {
  final List<Bay> bays;
  final Map<int, List<RowModel>> rowsByBay;
  final int highlightedRowId;
  final Color highlightColor;
  final double slotW, slotH;
  final bool isVert;
  final AnimationController blinkCtrl;
  final double scaleX, scaleY;

  const YardHighlightSlot({super.key, 
    required this.bays,
    required this.rowsByBay,
    required this.highlightedRowId,
    required this.highlightColor,
    required this.slotW,
    required this.slotH,
    required this.isVert,
    required this.blinkCtrl,
    required this.scaleX,
    required this.scaleY,
  });

  @override
  Widget build(BuildContext context) {
    final bayGapH = 2.5 * scaleY;
    final bayGapW = 2.5 * scaleX;
    final rowGapW = 1.0 * scaleX;
    final rowGapH = 1.0 * scaleY;
    const border = 1.5; // Border.all(width: 1.5) in YardBlockWidget
    const bayLabelH = 14.0; // bay label height in horizontal blocks
    final leftColW = 14 * scaleX / 3; // block name column in vertical blocks

    // Find which bay/row contains the highlighted row
    for (int bayIdx = 0; bayIdx < bays.length; bayIdx++) {
      final rows = rowsByBay[bays[bayIdx].bayId] ?? [];
      for (int rowIdx = 0; rowIdx < rows.length; rowIdx++) {
        if (rows[rowIdx].rowId != highlightedRowId) continue;

        double dx, dy;
        if (isVert) {
          // Vertical: rows reversed (row 1 rightmost), bays top-to-bottom
          final reversedIdx = rows.length - 1 - rowIdx;
          dx = border + leftColW + reversedIdx * (slotW + rowGapW);
          dy = border + bayIdx * (slotH + bayGapH);
        } else {
          // Horizontal: bay label (14px) above slots, bays left-to-right
          dx = border + bayIdx * (slotW + bayGapW);
          dy = border + bayLabelH + rowIdx * (slotH + rowGapH);
        }

        // Total block size for the SizedBox wrapper
        final totalW = isVert
            ? border * 2 +
                  leftColW +
                  rows.length * slotW +
                  (rows.length - 1) * rowGapW +
                  bayLabelH
            : border * 2 + bays.length * slotW + (bays.length - 1) * bayGapW;
        final totalH = isVert
            ? border * 2 + bays.length * slotH + (bays.length - 1) * bayGapH
            : border * 2 +
                  bayLabelH +
                  rows.length * slotH +
                  (rows.length - 1) * rowGapH;

        return SizedBox(
          width: totalW,
          height: totalH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: dx,
                top: dy,
                child: AnimatedBuilder(
                  animation: blinkCtrl,
                  builder: (_, _) => Container(
                    width: slotW,
                    height: slotH,
                    decoration: BoxDecoration(
                      color: highlightColor.withValues(
                        alpha: blinkCtrl.value * 0.75,
                      ),
                      border: Border.all(color: highlightColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: highlightColor.withValues(
                            alpha: blinkCtrl.value * 0.6,
                          ),
                          blurRadius: 6 * blinkCtrl.value,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
    // Row not in this block � render nothing
    return const SizedBox.shrink();
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
                          initialValue: _orientId,
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
                          initialValue: _sizeId,
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
        _sizeId == null) {
      return;
    }
    setState(() => _loading = true);
    await widget.onConfirm(name, bays, rows, _orientId!, _sizeId!, stack);
    if (mounted) Navigator.pop(context);
  }
}

// -- Tier Popup ----------------------------------------------------------------
class YardTierPopup extends StatefulWidget {
  final List<ContainerModel> containers;
  final VoidCallback onClose;
  final List<CustomerModel> customers;
  final String portName;
  final int yardNumber;
  final List<Block> blocks;
  final Map<int, Bay> baysById;
  final Map<int, RowModel> rowsById;

  const YardTierPopup({super.key, 
    required this.containers,
    required this.onClose,
    required this.customers,
    required this.portName,
    required this.yardNumber,
    required this.blocks,
    required this.baysById,
    required this.rowsById,
  });
  @override
  State<YardTierPopup> createState() => _YardTierPopupState();
}

class _YardTierPopupState extends State<YardTierPopup> {
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
        _infoRow('Date Moved:', _fmtDate(c.moveConfirmedDate)),
        _infoRow('Days in Slot:', _fmtDays(c.moveConfirmedDate)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              widget.onClose();
              showDialog(
                context: context,
                builder: (_) => YardContainerDetailsDialog(
                  container: c,
                  customers: widget.customers,
                  portName: widget.portName,
                  yardNumber: widget.yardNumber,
                  blocks: widget.blocks,
                  baysById: widget.baysById,
                  rowsById: widget.rowsById,
                ),
              );
            },
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
    );
  }

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

// -- Full Container Details Dialog --------------------------------------------
class YardContainerDetailsDialog extends StatelessWidget {
  final ContainerModel container;
  final List<CustomerModel> customers;
  final String portName;
  final int yardNumber;
  final List<Block> blocks;
  final Map<int, Bay> baysById;
  final Map<int, RowModel> rowsById;

  const YardContainerDetailsDialog({super.key, 
    required this.container,
    required this.customers,
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
    final customer = c.customerId != null
        ? customers.where((cu) => cu.customerId == c.customerId).firstOrNull
        : null;
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
                    _row('Customer:', customer?.fullName ?? '-'),
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

// -- Transfer Dialog -------------------------------------------------------
class _TransferDialog extends StatefulWidget {
  final ContainerModel container;
  final int portId;
  final int currentYardId;
  final ApiService api;
  final VoidCallback onTransferred;
  const _TransferDialog({
    required this.container,
    required this.portId,
    required this.currentYardId,
    required this.api,
    required this.onTransferred,
  });
  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  List<Yard> _yards = [];
  List<Block> _blocks = [];
  List<Bay> _bays = [];
  List<RowModel> _rows = [];

  Yard? _selYard;
  Block? _selBlock;
  Bay? _selBay;
  RowModel? _selRow;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadYards();
  }

  Future<void> _loadYards() async {
    final yards = await widget.api.getYards(widget.portId);
    setState(() {
      _yards = yards
          .where((y) => y.yardId != widget.currentYardId && y.hasLayout)
          .toList();
      _loading = false;
    });
  }

  Future<void> _onYardSelected(Yard yard) async {
    setState(() {
      _selYard = yard;
      _selBlock = null;
      _selBay = null;
      _selRow = null;
      _blocks = [];
      _bays = [];
      _rows = [];
    });
    final blocks = await widget.api.getBlocks(yard.yardId);
    setState(() => _blocks = blocks);
  }

  Future<void> _onBlockSelected(Block block) async {
    setState(() {
      _selBlock = block;
      _selBay = null;
      _selRow = null;
      _bays = [];
      _rows = [];
    });
    final bays = await widget.api.getBays(block.blockId);
    setState(() => _bays = bays);
  }

  Future<void> _onBaySelected(Bay bay) async {
    setState(() {
      _selBay = bay;
      _selRow = null;
      _rows = [];
    });
    final rows = await widget.api.getRows(bay.bayId);
    setState(() => _rows = rows.where((r) => !r.isDeleted).toList());
  }

  Future<void> _confirm() async {
    if (_selYard == null ||
        _selBlock == null ||
        _selBay == null ||
        _selRow == null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Find next available tier in target row
      final existing = await widget.api.getContainersByLocation(
        yardId: _selYard!.yardId,
        blockId: _selBlock!.blockId,
        bayId: _selBay!.bayId,
        rowId: _selRow!.rowId,
      );
      final nextTier = existing.length + 1;
      if (nextTier > _selRow!.maxStack) throw Exception('Target slot is full');
      await widget.api.moveContainer(
        containerId: widget.container.containerId,
        yardId: _selYard!.yardId,
        blockId: _selBlock!.blockId,
        bayId: _selBay!.bayId,
        rowId: _selRow!.rowId,
        tier: nextTier,
      );
      // Transfer creates a move request � driver at destination yard must confirm
      try {
        await widget.api.setMoveRequest(widget.container.containerId);
      } catch (_) {}
      widget.onTransferred();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Transfer Container',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.container.containerNumber,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 20),
                    _label('Select Yard'),
                    _drop<Yard>(
                      value: _selYard,
                      items: _yards,
                      display: (y) => 'Yard ${y.yardNumber}',
                      onChanged: (y) {
                        if (y != null) _onYardSelected(y);
                      },
                    ),
                    if (_blocks.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _label('Select Block'),
                      _drop<Block>(
                        value: _selBlock,
                        items: _blocks,
                        display: (b) => b.blockName ?? 'Block ${b.blockNumber}',
                        onChanged: (b) {
                          if (b != null) _onBlockSelected(b);
                        },
                      ),
                    ],
                    if (_bays.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _label('Select Bay'),
                      _drop<Bay>(
                        value: _selBay,
                        items: _bays,
                        display: (b) => 'Bay ${b.bayNumber}',
                        onChanged: (b) {
                          if (b != null) _onBaySelected(b);
                        },
                      ),
                    ],
                    if (_rows.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _label('Select Row'),
                      _drop<RowModel>(
                        value: _selRow,
                        items: _rows,
                        display: (r) => 'Row ${r.rowNumber}',
                        onChanged: (r) => setState(() => _selRow = r),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_selRow != null && !_saving)
                            ? _confirm
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Confirm Transfer',
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

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      t,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );

  Widget _drop<T>({
    required T? value,
    required List<T> items,
    required String Function(T) display,
    required ValueChanged<T?> onChanged,
  }) => DropdownButtonFormField<T>(
    initialValue: value,
    isDense: true,
    decoration: const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(),
    ),
    hint: const Text('Select', style: TextStyle(fontSize: 12)),
    items: items
        .map(
          (i) => DropdownMenuItem(
            value: i,
            child: Text(display(i), style: const TextStyle(fontSize: 12)),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );
}

// -- Full Screen Yard View ----------------------------------------------------

class _FullScreenYardView extends StatefulWidget {
  final Yard yard;
  final List<Block> blocks;
  final Map<int, List<Bay>> baysByBlock;
  final Map<int, List<RowModel>> rowsByBay;
  final Map<int, List<ContainerModel>> containersByRow;
  final Map<int, Offset> blockOffsets;
  final Map<int, double> blockRotations;
  final double scale;
  final String portName;
  final List<CustomerModel> customers;

  const _FullScreenYardView({
    required this.yard,
    required this.blocks,
    required this.baysByBlock,
    required this.rowsByBay,
    required this.containersByRow,
    required this.blockOffsets,
    required this.blockRotations,
    required this.scale,
    required this.portName,
    required this.customers,
  });

  @override
  State<_FullScreenYardView> createState() => _FullScreenYardViewState();
}

class _FullScreenYardViewState extends State<_FullScreenYardView>
    with SingleTickerProviderStateMixin {
  late double _scale;
  late AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _scale = widget.scale;
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  void _showContainersList() {
    final allContainers =
        widget.containersByRow.values
            .expand((list) => list)
            .where((c) => !c.isMovedOut)
            .toList()
          ..sort((a, b) => a.containerNumber.compareTo(b.containerNumber));

    // Build flat lookup maps
    final Map<int, Block> blocksById = {
      for (final b in widget.blocks) b.blockId: b,
    };
    final Map<int, Bay> baysById = {
      for (final list in widget.baysByBlock.values)
        for (final bay in list) bay.bayId: bay,
    };
    final Map<int, RowModel> rowsById = {
      for (final list in widget.rowsByBay.values)
        for (final row in list) row.rowId: row,
    };

    showDialog(
      context: context,
      builder: (_) => _YardContainersDialog(
        containers: allContainers,
        yard: widget.yard,
        portName: widget.portName,
        blocksById: blocksById,
        baysById: baysById,
        rowsById: rowsById,
        customers: widget.customers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final yardW = (widget.yard.yardWidth ?? 300).toDouble();
    final yardH = (widget.yard.yardHeight ?? 170).toDouble();

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.portName}  >  Yard ${widget.yard.yardNumber}  �  Full View',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showContainersList,
            icon: const Icon(Icons.list_alt, size: 16, color: AppColors.green),
            label: const Text(
              'Containers List',
              style: TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),
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
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final availW = constraints.maxWidth;
          final availH = constraints.maxHeight;
          final fitScale = (availW / yardW) < (availH / yardH)
              ? (availW / yardW)
              : (availH / yardH);
          if (_scale == widget.scale) _scale = fitScale;
          final cw = yardW * _scale;
          final ch = yardH * _scale;

          return InteractiveViewer(
            minScale: 0.2,
            maxScale: 8.0,
            panEnabled: true,
            constrained: false,
            boundaryMargin: EdgeInsets.symmetric(
              horizontal: availW * 0.5,
              vertical: availH * 0.5,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: cw,
                  height: ch,
                  decoration: BoxDecoration(
                    color: widget.yard.imagePath != null
                        ? null
                        : Colors.grey[300],
                    border: Border.all(color: Colors.grey, width: 1),
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
                  child: CustomPaint(painter: _YardGridPainter()),
                ),
                ...widget.blocks.map((b) {
                  final offsetFt =
                      widget.blockOffsets[b.blockId] ??
                      Offset(
                        (b.posX ?? 10).toDouble(),
                        (b.posY ?? 10).toDouble(),
                      );
                  final offset = Offset(
                    offsetFt.dx * _scale,
                    offsetFt.dy * _scale,
                  );
                  final rotation =
                      widget.blockRotations[b.blockId] ?? b.rotation;

                  return Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    child: Transform.rotate(
                      angle: rotation,
                      child: YardBlockWidget(
                        block: b,
                        baysByBlock: widget.baysByBlock,
                        rowsByBay: widget.rowsByBay,
                        containersByRow: widget.containersByRow,
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
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -- Yard Containers List Dialog ----------------------------------------------

class _YardContainersDialog extends StatefulWidget {
  final List<ContainerModel> containers;
  final Yard yard;
  final String portName;
  final Map<int, Block> blocksById;
  final Map<int, Bay> baysById;
  final Map<int, RowModel> rowsById;
  final List<CustomerModel> customers;

  const _YardContainersDialog({
    required this.containers,
    required this.yard,
    required this.portName,
    required this.blocksById,
    required this.baysById,
    required this.rowsById,
    required this.customers,
  });

  @override
  State<_YardContainersDialog> createState() => _YardContainersDialogState();
}

class _YardContainersDialogState extends State<_YardContainersDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ContainerModel> get _filtered {
    if (_searchQuery.isEmpty) return widget.containers;
    final q = _searchQuery.toLowerCase();
    return widget.containers
        .where((c) => c.containerNumber.toLowerCase().contains(q))
        .toList();
  }

  void _showDetails(BuildContext context, ContainerModel c) {
    final block = c.blockId != null ? widget.blocksById[c.blockId] : null;
    final blockLabel =
        block?.blockName ??
        (block != null ? 'Block ${block.blockNumber}' : '-');
    final bay = c.bayId != null ? widget.baysById[c.bayId] : null;
    final bayLabel = bay?.bayNumber ?? '-';
    final row = c.rowId != null ? widget.rowsById[c.rowId] : null;
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
    final customer = c.customerId != null
        ? widget.customers
              .where((cu) => cu.customerId == c.customerId)
              .firstOrNull
        : null;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: 360,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('GENERAL'),
                      _detailRow('Customer:', customer?.fullName ?? '-'),
                      _detailRow(
                        'Status:',
                        statusLabel,
                        valueColor: statusColor,
                      ),
                      _detailRow(
                        'Date Moved:',
                        _formatDate(c.moveConfirmedDate),
                      ),
                      _detailRow(
                        'Days in Slot:',
                        _daysInSlot(c.moveConfirmedDate),
                      ),
                      _detailRow('Date in Yard:', _formatDate(c.yardEntryDate)),
                      _detailRow('Days in Yard:', _daysInSlot(c.yardEntryDate)),
                      _detailRow('Container Type:', typeLabel),
                      _detailRow('Description:', c.containerDesc ?? '-'),
                      const SizedBox(height: 12),
                      _sectionLabel('LOCATION'),
                      _detailRow('Port:', widget.portName),
                      _detailRow('Yard:', 'Yard ${widget.yard.yardNumber}'),
                      _detailRow('Block:', blockLabel),
                      _detailRow('Bay:', bayLabel),
                      _detailRow('Row:', rowLabel),
                      _detailRow('Tier:', tierLabel),
                    ],
                  ),
                ), // end SingleChildScrollView
              ), // end Expanded
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

  Widget _sectionLabel(String title) => Padding(
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

  Widget _detailRow(String label, String value, {Color? valueColor}) => Padding(
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
    final containers = _filtered;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: SizedBox(
        width: 520,
        height: 560,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  const Text(
                    'Containers in Yard',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 180,
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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabCtrl,
              labelColor: AppColors.green,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.green,
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
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  containers.isEmpty
                      ? const Center(
                          child: Text(
                            'No containers in yard',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: containers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, i) => _YardContainerTile(
                            c: containers[i],
                            onTap: () => _showDetails(ctx, containers[i]),
                          ),
                        ),
                  const Center(
                    child: Text(
                      'Undertime',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'Due',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
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
      ),
    );
  }
}

class _YardContainerTile extends StatelessWidget {
  final ContainerModel c;
  final VoidCallback onTap;
  const _YardContainerTile({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = c.statusId == 1
        ? Colors.amber.shade700
        : Colors.red.shade600;
    final statusLabel = c.statusId == 1 ? 'Laden' : 'Empty';
    final typeLabel = c.containerSizeId == 1
        ? '20ft'
        : c.containerSizeId == 2
        ? '40ft'
        : (c.type ?? '-');

    return InkWell(
      onTap: onTap,
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
            Text(
              typeLabel,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 10),
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
          ],
        ),
      ),
    );
  }
}
