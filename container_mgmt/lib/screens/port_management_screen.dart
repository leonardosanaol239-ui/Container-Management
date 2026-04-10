import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/container_model.dart';
import '../models/yard.dart';
import '../widgets/container_holding_area.dart';
import '../theme/app_theme.dart';
import 'yard_screen.dart';

class PortManagementScreen extends StatefulWidget {
  final int portId;
  final String portName;
  const PortManagementScreen({
    super.key,
    required this.portId,
    required this.portName,
  });

  @override
  State<PortManagementScreen> createState() => _PortManagementScreenState();
}

class _PortManagementScreenState extends State<PortManagementScreen> {
  final _api = ApiService();
  List<ContainerModel> _containers = [];
  List<Yard> _yards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create yard: $e')));
      }
    }
  }

  void _openYard(Yard yard) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YardScreen(
          yard: yard,
          portId: widget.portId,
          portName: widget.portName,
        ),
      ),
    ).then((_) => _loadAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.portName,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppColors.textDark,
              ),
            ),
            const Text(
              'Container Management',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: AppColors.green,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAll,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.yellow,
                strokeWidth: 3,
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
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warehouse_rounded,
                                color: AppColors.yellow,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'YARDS',
                                style: TextStyle(
                                  color: AppColors.yellow,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _addYard,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.yellow,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add,
                                        size: 14,
                                        color: AppColors.textDark,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'ADD YARD',
                                        style: TextStyle(
                                          color: AppColors.textDark,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.yellow,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_yards.length}',
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
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
                                      Icon(
                                        Icons.warehouse_outlined,
                                        size: 64,
                                        color: AppColors.yellow.withOpacity(
                                          0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No yards found',
                                        style: TextStyle(
                                          color: AppColors.textGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
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
                                    );
                                  },
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

class _YardCard extends StatelessWidget {
  final Yard yard;
  final VoidCallback? onTap;
  const _YardCard({required this.yard, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled
                ? AppColors.yellow
                : AppColors.textGrey.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(14),
          color: enabled ? AppColors.white : const Color(0xFFF5F5F5),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.yellow.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // Top accent bar
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: enabled ? AppColors.yellow : Colors.grey[300],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
            ),
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
                              color: Colors.grey[400],
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No layout',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: enabled ? AppColors.yellow : Colors.grey[200],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Text(
                'YARD ${yard.yardNumber}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: enabled ? AppColors.textDark : AppColors.textGrey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniYardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.green.withOpacity(0.5)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = AppColors.yellow.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    double cellW = size.width / 8;
    double cellH = size.height / 6;

    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 7; col++) {
        final rect = Rect.fromLTWH(
          col * cellW,
          row * cellH,
          cellW - 1,
          cellH - 1,
        );
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, paint);
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
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
