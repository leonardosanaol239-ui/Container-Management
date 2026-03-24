import 'package:flutter/material.dart';
import '../models/container_model.dart';
import '../widgets/container_details_dialog.dart';
import '../widgets/add_container_dialog.dart';

class ContainerHoldingArea extends StatelessWidget {
  final int portId;
  final List<ContainerModel> containers;
  final VoidCallback onRefresh;

  const ContainerHoldingArea({
    super.key,
    required this.portId,
    required this.containers,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // Only show containers NOT in a yard and NOT moved out
    final holding = containers
        .where((c) => c.yardId == null && !c.isMovedOut)
        .toList()
        .reversed
        .toList();

    return Container(
      width: 200,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green, width: 3),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Add Container button
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => AddContainerDialog(portId: portId),
                );
                onRefresh();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'ADD CONTAINER',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Container list
          Expanded(
            child: holding.isEmpty
                ? const Center(
                    child: Text(
                      'No containers',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: holding.length,
                    itemBuilder: (ctx, i) {
                      final c = holding[i];
                      return _ContainerListItem(
                        container: c,
                        onTap: () => showDialog(
                          context: ctx,
                          builder: (_) => ContainerDetailsDialog(container: c),
                        ),
                      );
                    },
                  ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Container list',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContainerListItem extends StatelessWidget {
  final ContainerModel container;
  final VoidCallback onTap;

  const _ContainerListItem({required this.container, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLaden = container.statusId == 1;
    return GestureDetector(
      onTap: onTap,
      child: Draggable<ContainerModel>(
        data: container,
        rootOverlay: false,
        feedback: SizedBox(
          width: 180,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: _itemContent(isLaden),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: SizedBox(width: 184, child: _itemContent(isLaden)),
        ),
        child: _itemContent(isLaden),
      ),
    );
  }

  Widget _itemContent(bool isLaden) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isLaden ? Colors.amber : Colors.red,
              borderRadius: BorderRadius.circular(3),
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
                    Text(
                      isLaden ? 'Laden' : 'Empty',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'Type: ${container.type ?? ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Con#: ${container.containerNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
