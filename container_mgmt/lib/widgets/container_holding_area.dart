import 'package:flutter/material.dart';
import '../models/container_model.dart';
import '../widgets/container_details_dialog.dart';
import '../widgets/add_container_dialog.dart';
import '../theme/app_theme.dart';

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
    final holding = containers
        .where((c) => c.yardId == null && !c.isMovedOut)
        .toList()
        .reversed
        .toList();

    return Container(
      width: 210,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.green, width: 2.5),
        borderRadius: BorderRadius.circular(14),
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: const BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inbox_rounded,
                    color: AppColors.yellow, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'HOLDING AREA',
                  style: TextStyle(
                    color: AppColors.yellow,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${holding.length}',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Add Container button
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: ElevatedButton.icon(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => AddContainerDialog(portId: portId),
                );
                onRefresh();
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'ADD CONTAINER',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow,
                foregroundColor: AppColors.textDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
            ),
          ),
          // Container list
          Expanded(
            child: holding.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 40,
                            color: AppColors.textGrey.withOpacity(0.4)),
                        const SizedBox(height: 8),
                        const Text(
                          'No containers',
                          style: TextStyle(
                              color: AppColors.textGrey, fontSize: 12),
                        ),
                      ],
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
                          builder: (_) =>
                              ContainerDetailsDialog(container: c),
                        ),
                      );
                    },
                  ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.yellow.withOpacity(0.15),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: const Text(
              'Drag to move containers',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
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
          width: 190,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: _itemContent(isLaden),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: SizedBox(width: 194, child: _itemContent(isLaden)),
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
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLaden
              ? AppColors.yellow.withOpacity(0.6)
              : AppColors.red.withOpacity(0.4),
          width: 1,
        ),
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
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            isLaden ? AppColors.yellow : AppColors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isLaden ? 'Laden' : 'Empty',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isLaden
                              ? AppColors.textDark
                              : AppColors.white,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        container.type ?? '',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textGrey,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  container.containerNumber,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
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
