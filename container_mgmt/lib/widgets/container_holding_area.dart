import 'package:flutter/material.dart';
import '../models/container_model.dart';
import '../widgets/container_details_dialog.dart';
import '../widgets/add_container_dialog.dart';
import '../theme/app_theme.dart';

class ContainerHoldingArea extends StatelessWidget {
  final int portId;
  final int? yardId;
  final List<ContainerModel> containers;
  final VoidCallback onRefresh;

  const ContainerHoldingArea({
    super.key,
    required this.portId,
    this.yardId,
    required this.containers,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final holding = containers
        .where(
          (c) =>
              !c.isMovedOut &&
              (c.yardId == null ||
                  (yardId != null && c.yardId == yardId && c.rowId == null)),
        )
        .toList()
        .reversed
        .toList();

    return Container(
      width: 216,
      decoration: BoxDecoration(
        // Slightly warm off-white — distinct from the page background
        color: const Color(0xFFFAFAF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.18),
          width: 1.5,
        ),
        // No shadow — clean flat look
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            color: AppColors.green,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inbox_rounded,
                    color: AppColors.yellow,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'HOLDING AREA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(20),
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

          // ── Add Container button ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: GestureDetector(
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (_) => AddContainerDialog(portId: portId),
                );
                onRefresh();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(10),
                  // No shadow
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 15,
                      color: AppColors.textDark,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ADD CONTAINER',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: AppColors.textDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Divider ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.green.withValues(alpha: 0.1),
            ),
          ),

          // ── Container list ───────────────────────────────────────────
          Expanded(
            child: holding.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.inbox_outlined,
                            size: 32,
                            color: AppColors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No containers',
                          style: TextStyle(
                            color: AppColors.green.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add one above',
                          style: TextStyle(
                            color: AppColors.green.withValues(alpha: 0.35),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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

          // ── Footer ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.06),
              border: Border(
                top: BorderSide(
                  color: AppColors.green.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 13,
                  color: AppColors.green.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  'Drag to move containers',
                  style: TextStyle(
                    color: AppColors.green.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
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

// ── Container list item ───────────────────────────────────────────────────────

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
          width: 196,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            shadowColor: Colors.black26,
            child: _itemContent(isLaden),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.25,
          child: SizedBox(width: 196, child: _itemContent(isLaden)),
        ),
        child: _itemContent(isLaden),
      ),
    );
  }

  Widget _itemContent(bool isLaden) {
    final statusColor = isLaden ? AppColors.laden : AppColors.empty;
    final bgColor = isLaden
        ? AppColors.laden.withValues(alpha: 0.05)
        : AppColors.empty.withValues(alpha: 0.05);
    final desc = container.containerDesc;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
        // No shadow
      ),
      child: Row(
        children: [
          // Status stripe
          Container(
            width: 5,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isLaden ? 'Laden' : 'Empty',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        container.type ?? '',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.green.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    container.containerNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.green.withValues(alpha: 0.45),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
