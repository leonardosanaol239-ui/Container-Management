import 'package:flutter/material.dart';
import '../models/bay.dart';
import '../models/block.dart';
import '../models/row_model.dart';
import '../models/container_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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
    final totalContainers =
        _containersByRow.values.fold<int>(0, (s, l) => s + l.length);

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
              '${widget.block.blockDesc ?? "Block ${widget.block.blockNumber}"} — Bay ${widget.bay.bayNumber}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppColors.textDark,
              ),
            ),
            Text(
              '$totalContainers container${totalContainers != 1 ? 's' : ''}',
              style: const TextStyle(
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
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.yellow, strokeWidth: 3))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.red)))
              : RefreshIndicator(
                  color: AppColors.yellow,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.yellow.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.yellow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.view_week_rounded,
                    color: AppColors.yellow, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Row ${row.rowNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.yellow,
                  ),
                ),
                const Spacer(),
                Text(
                  '${containers.length}/5 occupied',
                  style: TextStyle(
                    color: AppColors.yellow.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Tier slots
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
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
                final isLaden = container.statusId == 1;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 72,
                    decoration: BoxDecoration(
                      color: occupied
                          ? (isLaden
                              ? AppColors.yellow
                              : AppColors.red)
                          : const Color(0xFFF5F5F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: occupied
                            ? (isLaden
                                ? AppColors.yellowDark
                                : AppColors.redDark)
                            : AppColors.yellow.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: occupied
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  container.containerNumber,
                                  style: TextStyle(
                                    color: isLaden
                                        ? AppColors.textDark
                                        : AppColors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'T$tier',
                                  style: TextStyle(
                                    color: isLaden
                                        ? AppColors.green
                                        : AppColors.white.withOpacity(0.7),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'T$tier',
                              style: TextStyle(
                                color: AppColors.textGrey.withOpacity(0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // Legend
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                _LegendDot(color: AppColors.yellow, label: 'Laden'),
                const SizedBox(width: 16),
                _LegendDot(color: AppColors.red, label: 'Empty'),
                const Spacer(),
                Text(
                  'Row ID: ${row.rowId}',
                  style: TextStyle(
                      color: AppColors.textGrey.withOpacity(0.5),
                      fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style:
              const TextStyle(color: AppColors.textGrey, fontSize: 10),
        ),
      ],
    );
  }
}
