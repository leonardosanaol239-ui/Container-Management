import 'package:flutter/material.dart';
import '../models/bay.dart';
import '../models/block.dart';
import '../models/row_model.dart';
import '../models/container_model.dart';
import '../services/api_service.dart';

class BayDetailScreen extends StatefulWidget {
  final Bay bay;
  final Block block;
  const BayDetailScreen({super.key, required this.bay, required this.block});

  @override
  State<BayDetailScreen> createState() => _BayDetailScreenState();
}

class _BayDetailScreenState extends State<BayDetailScreen> {
  final _api = ApiService();
  List<RowModel> _rows = [];
  Map<int, List<ContainerModel>> _containersByRow = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _api.getRows(widget.bay.bayId);
      final containers = await _api.getContainersByLocation(
        bayId: widget.bay.bayId,
      );

      final Map<int, List<ContainerModel>> byRow = {};
      for (final r in rows) {
        byRow[r.rowId] = containers.where((c) => c.rowId == r.rowId).toList()
          ..sort((a, b) => (a.tier ?? 0).compareTo(b.tier ?? 0));
      }

      setState(() {
        _rows = rows;
        _containersByRow = byRow;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.block.blockDesc ?? "Block ${widget.block.blockNumber}"} — Bay ${widget.bay.bayNumber}',
        ),
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
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _rows.length,
                itemBuilder: (ctx, i) {
                  final row = _rows[i];
                  final containers = _containersByRow[row.rowId] ?? [];
                  return _RowTierWidget(row: row, containers: containers);
                },
              ),
            ),
    );
  }
}

class _RowTierWidget extends StatelessWidget {
  final RowModel row;
  final List<ContainerModel> containers;
  const _RowTierWidget({required this.row, required this.containers});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Row ${row.rowNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            // Tiers displayed bottom-up (tier 1 at bottom, tier 5 at top)
            Row(
              children: List.generate(5, (i) {
                final tier = i + 1;
                final container = containers.firstWhere(
                  (c) => c.tier == tier,
                  orElse: () => ContainerModel(
                    containerId: -1,
                    containerNumber: '',
                    statusId: 0,
                    currentPortId: 0,
                    createdDate: '',
                  ),
                );
                final occupied = container.containerId != -1;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 60,
                    decoration: BoxDecoration(
                      color: occupied ? Colors.blueGrey[600] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blueGrey[300]!),
                    ),
                    child: Center(
                      child: occupied
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  container.containerNumber,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  'T$tier',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'T$tier',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${containers.length}/5 occupied',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  'Row ID: ${row.rowId}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
