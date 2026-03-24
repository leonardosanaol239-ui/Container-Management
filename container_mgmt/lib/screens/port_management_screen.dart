import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/container_model.dart';
import '../models/yard.dart';
import '../widgets/container_holding_area.dart';
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

  void _openYard(Yard yard) {
    if (!yard.hasLayout) return;
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.portName} CONTAINER MANAGEMENT',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                  const SizedBox(width: 24),
                  Expanded(
                    child: _yards.isEmpty
                        ? const Center(child: Text('No yards found'))
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.1,
                                ),
                            itemCount: _yards.length,
                            itemBuilder: (ctx, i) {
                              final yard = _yards[i];
                              return _YardCard(
                                yard: yard,
                                onTap: yard.hasLayout
                                    ? () => _openYard(yard)
                                    : null,
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

class _YardCard extends StatelessWidget {
  final Yard yard;
  final VoidCallback? onTap;
  const _YardCard({required this.yard, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? Colors.black : Colors.grey[400]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: enabled ? Colors.white : Colors.grey[100],
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: enabled
                    ? CustomPaint(
                        painter: _MiniYardPainter(),
                        size: Size.infinite,
                      )
                    : Center(
                        child: Icon(
                          Icons.lock_outline,
                          color: Colors.grey[400],
                          size: 32,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'YARD ${yard.yardNumber}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: enabled ? Colors.black : Colors.grey[500],
                ),
              ),
            ),
            if (!enabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No layout set',
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
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
      ..color = Colors.grey[400]!
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    double cellW = size.width / 8;
    double cellH = size.height / 6;

    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 7; col++) {
        canvas.drawRect(
          Rect.fromLTWH(col * cellW, row * cellH, cellW - 1, cellH - 1),
          paint,
        );
      }
    }
    for (int row = 3; row < 6; row++) {
      for (int col = 0; col < 7; col++) {
        canvas.drawRect(
          Rect.fromLTWH(col * cellW, row * cellH, cellW - 1, cellH - 1),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
