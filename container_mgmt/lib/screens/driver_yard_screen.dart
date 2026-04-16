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

const double _kContainerH = 8.0;
const double _k20ftW = 20.0;
const double _k40ftW = 40.0;

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

class _DriverYardScreenState extends State<DriverYardScreen> {
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

      // Move requests for this yard — oldest first (by containerId as proxy)
      final moveRequests =
          allContainers
              .where(
                (c) =>
                    c.locationStatusId == 3 && c.yardId == widget.yard.yardId,
              )
              .toList()
            ..sort((a, b) => a.containerId.compareTo(b.containerId));

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
    // Resolve location labels
    Block? block;
    Bay? bay;
    RowModel? row;
    for (final b in _blocks) {
      if (b.blockId == c.blockId) {
        block = b;
        break;
      }
    }
    for (final list in _baysByBlock.values) {
      for (final b in list) {
        if (b.bayId == c.bayId) {
          bay = b;
          break;
        }
      }
      if (bay != null) break;
    }
    for (final list in _rowsByBay.values) {
      for (final r in list) {
        if (r.rowId == c.rowId) {
          row = r;
          break;
        }
      }
      if (row != null) break;
    }
    final customer = c.customerId != null
        ? _customers.where((cu) => cu.customerId == c.customerId).firstOrNull
        : null;
    final typeLabel = c.containerSizeId == 1
        ? '20ft'
        : c.containerSizeId == 2
        ? '40ft'
        : (c.type ?? '-');

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 80),
        child: SizedBox(
          width: 380,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Move Request for:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Container Number: ${c.containerNumber}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _infoRow('Yard:', 'Yard ${_yard.yardNumber}'),
                _infoRow(
                  'Block:',
                  block?.blockName ??
                      (block != null ? 'Block ${block.blockNumber}' : '-'),
                ),
                _infoRow('Bay:', bay?.bayNumber ?? '-'),
                _infoRow('Row:', row != null ? '${row.rowNumber}' : '-'),
                _infoRow('Tier:', c.tier != null ? '${c.tier}' : '-'),
                const SizedBox(height: 16),
                _infoRow('Customer:', customer?.fullName ?? '-'),
                _infoRow('Container Type:', typeLabel),
                _infoRow('Container Desc:', c.containerDesc ?? '-'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmRequest(c);
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
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
    final bays = _baysByBlock[block.blockId] ?? [];
    final isVert = block.isVertical;
    final is40 = block.is40ft;
    final slotLong = (is40 ? _k40ftW : _k20ftW) * _scale;
    final slotShort = _kContainerH * _scale;
    final cellW = isVert ? slotShort : slotLong;
    final cellH = isVert ? slotLong : slotShort;
    final blockName = block.blockName ?? 'Block ${block.blockNumber}';

    Widget blockWidget;
    if (isVert) {
      blockWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14 * _scale / 3,
            color: AppColors.green.withValues(alpha: 0.85),
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                blockName,
                style: TextStyle(
                  fontSize: 7 * _scale / 3,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: bays.map((bay) {
              final rows = _rowsByBay[bay.bayId] ?? [];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: rows
                    .map((row) => _buildSlot(row, cellW, cellH))
                    .toList(),
              );
            }).toList(),
          ),
        ],
      );
    } else {
      blockWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            color: AppColors.green.withValues(alpha: 0.85),
            child: Text(
              blockName,
              style: TextStyle(
                fontSize: 7 * _scale / 3,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bays.map((bay) {
              final rows = _rowsByBay[bay.bayId] ?? [];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: rows
                    .map((row) => _buildSlot(row, cellW, cellH))
                    .toList(),
              );
            }).toList(),
          ),
        ],
      );
    }

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: Transform.rotate(angle: block.rotation, child: blockWidget),
    );
  }

  Widget _buildSlot(RowModel row, double width, double height) {
    final containers = _confirmedByRow[row.rowId] ?? [];
    final inYard = containers.where((c) => !c.isMovedOut).toList()
      ..sort((a, b) => (a.tier ?? 0).compareTo(b.tier ?? 0));
    final top = inYard.isNotEmpty ? inYard.last : null;

    final bgColor = top == null
        ? Colors.transparent
        : top.statusId == 1
        ? Colors.amber.shade300
        : Colors.red.shade300;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: top == null
          ? Center(
              child: Text(
                '${row.rowNumber}',
                style: const TextStyle(fontSize: 8, color: Colors.white38),
              ),
            )
          : Stack(
              children: [
                Center(
                  child: Text(
                    top.containerNumber,
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
