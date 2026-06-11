import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/container_model.dart';
import '../models/session.dart';
import '../models/yard.dart';
import '../widgets/container_holding_area.dart';
import 'yard_screen.dart';

// ── Brand tokens (Gothong Southern) ──────────────────────────────────────────
class _C {
  static const navBg = Color(0xFF0B3D0F); // dark nav green
  static const green = Color(0xFF0B560D); // Lincoln Green (primary)
  static const greenLight = Color(0xFF98F29B); // Live Green (secondary)
  static const yellow = Color(0xFFFFD300); // Cyber Yellow (brand accent)
  static const red = Color(0xFFFF2800); // Scarlet Red
  static const bg = Color(0xFFF0F2EE); // page background
  static const surface = Color(0xFFFFFFFF); // card surface
  static const border = Color(0xFFE8EAE4); // subtle border
  static const textD = Color(0xFF1A1A0A); // dark text
  static const textM = Color(0xFF4A4A4A); // medium text
  static const textL = Color(0xFF757575); // light text
}

// ── PortManagementScreen ──────────────────────────────────────────────────────
class PortManagementScreen extends StatefulWidget {
  final int portId;
  final String portName;
  final Session? session;
  const PortManagementScreen({
    super.key,
    required this.portId,
    required this.portName,
    this.session,
  });

  @override
  State<PortManagementScreen> createState() => _PortManagementScreenState();
}

class _PortManagementScreenState extends State<PortManagementScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  List<ContainerModel> _containers = [];
  List<Yard> _yards = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  int? _blinkingYardId;
  late AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _loadAll();
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _api.getContainersByPort(widget.portId),
        _api.getYards(widget.portId),
      ]);
      setState(() {
        _containers = results[0] as List<ContainerModel>;
        _yards = results[1] as List<Yard>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addYard() async {
    try {
      await _api.createYard(widget.portId);
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create yard: $e'),
            backgroundColor: _C.red,
          ),
        );
      }
    }
  }

  void _showDeleteYardDialog() {
    if (_yards.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => _DeleteYardDialog(
        yards: _yards,
        onDelete: (yard) async {
          Navigator.pop(ctx);
          final deleted = await _api.deleteYard(yard.yardId);
          if (!mounted) return;
          if (deleted) {
            await _loadAll();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Yard ${yard.yardNumber} deleted.'),
                backgroundColor: _C.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cannot delete Yard ${yard.yardNumber}: it still has containers.',
                ),
                backgroundColor: _C.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
      ),
    );
  }

  void _openYard(Yard yard) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YardScreen(
          yard: yard,
          portId: widget.portId,
          portName: widget.portName,
          session: widget.session,
        ),
      ),
    ).then((_) => _loadAll());
  }

  Future<void> _searchContainer() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    final container = await _api.searchContainer(q);
    if (!mounted) return;

    if (container == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Container "$q" not found.'),
          backgroundColor: _C.red,
        ),
      );
      return;
    }
    if (container.currentPortId != widget.portId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$q" is not in ${widget.portName}. Search within the correct port.',
          ),
          backgroundColor: _C.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    if (container.yardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$q" is in ${widget.portName} but not placed in a yard.',
          ),
          backgroundColor: _C.red,
        ),
      );
      return;
    }
    setState(() => _blinkingYardId = container.yardId);
    final yard = _yards.firstWhere(
      (y) => y.yardId == container.yardId,
      orElse: () => _yards.first,
    );
    showDialog(
      context: context,
      builder: (_) => _ContainerLocationDialog(
        container: container,
        yard: yard,
        portId: widget.portId,
        portName: widget.portName,
        onViewInYard: () => _searchCtrl.clear(),
      ),
    ).then((_) => setState(() => _blinkingYardId = null));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: _C.green,
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading ${widget.portName}...',
                    style: const TextStyle(
                      color: _C.textL,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContainerHoldingArea(
                    portId: widget.portId,
                    containers: _containers,
                    onRefresh: _loadAll,
                    onContainerAssigned: (slot) {
                      // In port management screen, we don't have yard layout to highlight
                      // Just refresh to show the container is no longer in holding area
                      _loadAll();
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildYardsPanel()),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        color: _C.navBg,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SafeArea(
          child: Row(
            children: [
              // Back button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Port icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.anchor, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              // Title
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.portName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const Text(
                    'Container Management',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Search bar
              Container(
                width: 220,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search container...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _searchContainer,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  onSubmitted: (_) => _searchContainer(),
                ),
              ),
              const SizedBox(width: 8),
              // Refresh button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loadAll,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.refresh_rounded, color: _C.green, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Refresh',
                          style: TextStyle(
                            color: _C.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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

  Widget _buildYardsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _C.green,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warehouse_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'YARDS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_yards.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              // Add Yard button
              _headerBtn(icon: Icons.add, label: 'Add Yard', onTap: _addYard),
              const SizedBox(width: 8),
              // Delete Yard button
              _headerBtn(
                icon: Icons.delete_outline,
                label: 'Delete Yard',
                onTap: _showDeleteYardDialog,
                danger: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _yards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warehouse_outlined,
                          size: 48,
                          color: _C.green,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No yards found',
                        style: TextStyle(
                          color: _C.textM,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap "Add Yard" to create one',
                        style: TextStyle(color: _C.textL, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _yards.length,
                  itemBuilder: (ctx, i) {
                    final yard = _yards[i];
                    return _YardCard(
                      yard: yard,
                      onTap: () => _openYard(yard),
                      isBlinking: _blinkingYardId == yard.yardId,
                      blinkCtrl: _blinkCtrl,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _headerBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: danger ? _C.red.withValues(alpha: 0.15) : _C.green,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Yard Card ─────────────────────────────────────────────────────────────────
class _YardCard extends StatelessWidget {
  final Yard yard;
  final VoidCallback? onTap;
  final bool isBlinking;
  final AnimationController? blinkCtrl;
  const _YardCard({
    required this.yard,
    this.onTap,
    this.isBlinking = false,
    this.blinkCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    Widget card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? _C.green : _C.border,
              width: enabled ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top accent bar
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: enabled ? _C.green : _C.border,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
              ),
              // Mini yard preview
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: enabled
                      ? CustomPaint(
                          painter: _MiniYardPainter(),
                          size: Size.infinite,
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                color: _C.textL,
                                size: 26,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'No layout',
                                style: TextStyle(fontSize: 9, color: _C.textL),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              // Bottom label
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: enabled ? _C.green : _C.border,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
                ),
                child: Text(
                  'YARD ${yard.yardNumber}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: enabled ? Colors.white : _C.textL,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isBlinking && blinkCtrl != null) {
      return AnimatedBuilder(
        animation: blinkCtrl!,
        builder: (_, _) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _C.green.withValues(alpha: 0.5 * blinkCtrl!.value),
                blurRadius: 16 * blinkCtrl!.value,
                spreadRadius: 4 * blinkCtrl!.value,
              ),
            ],
          ),
          child: card,
        ),
      );
    }
    return card;
  }
}

// ── Mini Yard Painter ─────────────────────────────────────────────────────────
class _MiniYardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _C.green.withValues(alpha: 0.45)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = _C.green.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final cellW = size.width / 8;
    final cellH = size.height / 6;

    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 7; col++) {
        final rect = Rect.fromLTWH(
          col * cellW,
          row * cellH,
          cellW - 1,
          cellH - 1,
        );
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
      }
    }
    for (int row = 3; row < 6; row++) {
      for (int col = 0; col < 7; col++) {
        final rect = Rect.fromLTWH(
          col * cellW,
          row * cellH,
          cellW - 1,
          cellH - 1,
        );
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Container Location Dialog ─────────────────────────────────────────────────
class _ContainerLocationDialog extends StatefulWidget {
  final ContainerModel container;
  final Yard yard;
  final int portId;
  final String portName;
  final VoidCallback? onViewInYard;
  const _ContainerLocationDialog({
    required this.container,
    required this.yard,
    required this.portId,
    required this.portName,
    this.onViewInYard,
  });

  @override
  State<_ContainerLocationDialog> createState() =>
      _ContainerLocationDialogState();
}

class _ContainerLocationDialogState extends State<_ContainerLocationDialog> {
  final _api = ApiService();
  String _blockLabel = '-';
  String _bayLabel = '-';
  String _rowLabel = '-';

  @override
  void initState() {
    super.initState();
    _resolveLabels();
  }

  Future<void> _resolveLabels() async {
    final c = widget.container;
    if (c.yardId == null || c.blockId == null) return;
    try {
      final blocks = await _api.getBlocks(c.yardId!);
      final block = blocks.where((b) => b.blockId == c.blockId).firstOrNull;
      if (block != null && mounted) {
        setState(
          () => _blockLabel = block.blockName ?? 'Block ${block.blockNumber}',
        );
      }
      final bays = await _api.getBays(c.blockId!);
      final bay = bays.where((b) => b.bayId == c.bayId).firstOrNull;
      if (bay != null && mounted) {
        setState(() => _bayLabel = bay.bayNumber);
        final rows = await _api.getRows(bay.bayId);
        final row = rows.where((r) => r.rowId == c.rowId).firstOrNull;
        if (row != null && mounted) {
          setState(() => _rowLabel = '${row.rowNumber}');
        }
      }
    } catch (_) {}
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: _C.textM,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: _C.green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final container = widget.container;
    final yard = widget.yard;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: _C.green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Container Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _C.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        container.containerNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: _C.border),
                  const SizedBox(height: 8),
                  _infoRow('Yard:', 'Yard ${yard.yardNumber}'),
                  _infoRow('Block:', _blockLabel),
                  _infoRow('Bay:', _bayLabel),
                  _infoRow('Row:', _rowLabel),
                  _infoRow(
                    'Tier:',
                    container.tier != null ? '${container.tier}' : '-',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => YardScreen(
                              yard: yard,
                              portId: widget.portId,
                              portName: widget.portName,
                              highlightRowId: container.rowId,
                            ),
                          ),
                        );
                        widget.onViewInYard?.call();
                      },
                      icon: const Icon(Icons.location_searching, size: 16),
                      label: const Text(
                        'View in Yard',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
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

// ── Delete Yard Dialog ────────────────────────────────────────────────────────
class _DeleteYardDialog extends StatelessWidget {
  final List<Yard> yards;
  final void Function(Yard yard) onDelete;
  const _DeleteYardDialog({required this.yards, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: _C.green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Delete a Yard',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Select a yard to delete. Yards with active containers cannot be deleted.',
                style: const TextStyle(fontSize: 12, color: _C.textL),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(color: _C.border, height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: yards.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final yard = yards[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _C.border),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _C.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warehouse_outlined,
                          color: _C.green,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        'Yard ${yard.yardNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: _C.textD,
                        ),
                      ),
                      trailing: GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            title: const Text(
                              'Confirm Delete',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _C.textD,
                              ),
                            ),
                            content: Text(
                              'Are you sure you want to delete Yard ${yard.yardNumber}? '
                              'This cannot be undone.',
                              style: const TextStyle(color: _C.textM),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: _C.textL),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  onDelete(yard);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _C.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _C.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _C.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 13,
                                color: _C.red,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _C.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
