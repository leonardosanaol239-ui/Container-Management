import 'package:flutter/material.dart';
import '../models/block.dart';
import '../models/bay.dart';
import '../services/api_service.dart';
import 'bay_detail_screen.dart';

class BlockDetailScreen extends StatefulWidget {
  final Block block;
  const BlockDetailScreen({super.key, required this.block});

  @override
  State<BlockDetailScreen> createState() => _BlockDetailScreenState();
}

class _BlockDetailScreenState extends State<BlockDetailScreen> {
  final _api = ApiService();
  List<Bay> _bays = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bays = await _api.getBays(widget.block.blockId);
      setState(() {
        _bays = bays;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    return Scaffold(
      appBar: AppBar(
        title: Text(block.blockDesc ?? 'Block ${block.blockNumber}'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: _bays.length,
                itemBuilder: (ctx, i) {
                  final bay = _bays[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BayDetailScreen(bay: bay, block: block),
                      ),
                    ),
                    child: Card(
                      color: Colors.blueGrey[50],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.grid_view,
                              color: Colors.blueGrey[700],
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Bay ${bay.bayNumber}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
