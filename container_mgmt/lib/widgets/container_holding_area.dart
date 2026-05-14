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
              (
              // Unassigned (no yard yet)
              c.yardId == null ||
                  // Transferred to this yard's holding area (yardId set, no slot)
                  (yardId != null && c.yardId == yardId && c.rowId == null)),
        )
        .toList()
        .reversed
        .toList();

    return Container(
      width: 216,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.green, Color(0xFF1A7A1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withValues(alpha: 0.18),
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
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.yellow.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
              color: Colors.grey.shade100,
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
                            color: Colors.grey.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.inbox_outlined,
                            size: 32,
                            color: Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No containers',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add one above',
                          style: TextStyle(
                            color: Colors.grey.shade300,
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
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade100, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 13,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  'Drag to move containers',
                  style: TextStyle(
                    color: Colors.grey.shade400,
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
            elevation: 12,
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
    final desc = container.containerDesc;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
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
                          color: statusColor.withValues(alpha: 0.12),
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
                          color: Colors.grey.shade400,
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
                        color: Colors.grey.shade400,
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
