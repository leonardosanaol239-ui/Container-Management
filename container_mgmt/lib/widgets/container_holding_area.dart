import 'dart:async';
import 'package:flutter/material.dart';
import '../models/container_model.dart';
import '../services/api_service.dart';
import '../widgets/add_container_dialog.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ContainerHoldingArea
//
// Flow:
//   Checker taps START  → container appears in INBOUND (black & white)
//   Driver clicks "Operation Confirm" → locationStatusId becomes 1
//   Holding area polls API every 5 s  → detects locationStatusId == 1
//   Inbound item COLORIZES             → checker can now "End Movement"
//   Checker taps END MOVEMENT          → item removed from inbound
// ─────────────────────────────────────────────────────────────────────────────

class ContainerHoldingArea extends StatefulWidget {
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
  State<ContainerHoldingArea> createState() => _ContainerHoldingAreaState();
}

class _ContainerHoldingAreaState extends State<ContainerHoldingArea> {
  final _api = ApiService();

  /// IDs the checker has "started" — shows them in the Inbound section
  final Set<int> _startedIds = {};

  /// IDs confirmed by the driver (locationStatusId == 1 seen from poll)
  final Set<int> _confirmedIds = {};

  /// Latest container snapshots used to check locationStatusId
  final Map<int, ContainerModel> _liveContainers = {};

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _seedLiveContainers();
    // Poll every 5 seconds for driver confirmations
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void didUpdateWidget(ContainerHoldingArea old) {
    super.didUpdateWidget(old);
    _seedLiveContainers();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Pre-populate live map from parent's container list
  void _seedLiveContainers() {
    for (final c in widget.containers) {
      _liveContainers[c.containerId] = c;
    }
  }

  /// Poll the API for current container states for started containers only.
  /// - locationStatusId == 3 → driver hasn't confirmed yet (stay grey)
  /// - locationStatusId == 1 → driver confirmed → colorize
  Future<void> _poll() async {
    if (_startedIds.isEmpty) return;
    try {
      final fresh = await _api.getContainersByPort(widget.portId);
      if (!mounted) return;
      bool changed = false;
      for (final c in fresh) {
        if (!_startedIds.contains(c.containerId)) continue;
        final prev = _liveContainers[c.containerId];
        _liveContainers[c.containerId] = c;
        // locationStatusId 1 = confirmed by driver
        if (c.locationStatusId == 1 && !_confirmedIds.contains(c.containerId)) {
          _confirmedIds.add(c.containerId);
          changed = true;
        }
        // If status changed at all, rebuild
        if (prev?.locationStatusId != c.locationStatusId) changed = true;
      }
      if (changed) setState(() {});
    } catch (_) {}
  }

  // ── Computed lists ──────────────────────────────────────────────────────────
  List<ContainerModel> get _holding => widget.containers
      .where(
        (c) =>
            !c.isMovedOut &&
            (c.yardId == null ||
                (widget.yardId != null &&
                    c.yardId == widget.yardId &&
                    c.rowId == null)),
      )
      .toList()
      .reversed
      .toList();

  List<ContainerModel> get _inbound {
    // Use live snapshots if available (so we get up-to-date locationStatusId),
    // otherwise fall back to the parent's container list.
    return _startedIds
        .map((id) {
          return _liveContainers[id] ??
              widget.containers.firstWhere(
                (c) => c.containerId == id,
                orElse: () => widget.containers.first,
              );
        })
        .where(
          (c) =>
              widget.containers.any((wc) => wc.containerId == c.containerId) ||
              _liveContainers.containsKey(c.containerId),
        )
        .toList();
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  /// Called when checker taps START.
  /// Sets locationStatusId = 3 (move request) so the driver sees it,
  /// then adds to _startedIds so it appears in the Inbound section.
  Future<void> _startContainer(ContainerModel c) async {
    // Close the dialog first
    Navigator.of(context, rootNavigator: true).pop();
    try {
      await _api.setMoveRequest(c.containerId);
    } catch (_) {
      // Even if the API call fails, still show it locally
    }
    if (mounted) setState(() => _startedIds.add(c.containerId));
  }

  /// Called when checker taps END MOVEMENT (only available after driver confirms).
  void _endMovement(int containerId) {
    setState(() {
      _startedIds.remove(containerId);
      _confirmedIds.remove(containerId);
    });
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _showHoldingDetails(BuildContext ctx, ContainerModel c) {
    final isStarted = _startedIds.contains(c.containerId);
    showDialog(
      context: ctx,
      builder: (_) => _HoldingDetailsDialog(
        container: c,
        isStarted: isStarted,
        onStart: () => _startContainer(c),
      ),
    );
  }

  void _showInboundDetails(BuildContext ctx, ContainerModel c) {
    final confirmed = _confirmedIds.contains(c.containerId);
    showDialog(
      context: ctx,
      builder: (_) => _InboundDetailsDialog(
        container: c,
        driverConfirmed: confirmed,
        onEndMovement: () => _endMovement(c.containerId),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final holding = _holding;
    final inbound = _inbound;

    return Container(
      width: 216,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ══ TOP: HOLDING AREA ══════════════════════════════════════
          _SectionHeader(
            icon: Icons.inbox_rounded,
            title: 'HOLDING AREA',
            count: holding.length,
          ),

          // Add Container button
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: GestureDetector(
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (_) => AddContainerDialog(portId: widget.portId),
                );
                widget.onRefresh();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(10),
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

          _divider(),

          // Holding list
          SizedBox(
            height: 280,
            child: holding.isEmpty
                ? _emptyState('No containers', 'Add one above')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    itemCount: holding.length,
                    itemBuilder: (ctx, i) {
                      final c = holding[i];
                      final started = _startedIds.contains(c.containerId);
                      return _HoldingItem(
                        container: c,
                        started: started,
                        onTap: () => _showHoldingDetails(ctx, c),
                      );
                    },
                  ),
          ),

          _footer(
            icon: Icons.drag_indicator_rounded,
            label: 'Start a container to drag it',
          ),

          // ══ SEPARATOR ═══════════════════════════════════════════════
          Container(height: 6, color: AppColors.green.withValues(alpha: 0.08)),

          // ══ BOTTOM: INBOUND AREA ════════════════════════════════════
          _SectionHeader(
            icon: Icons.move_to_inbox_rounded,
            title: 'INBOUND AREA',
            count: inbound.length,
            accent: const Color(0xFF1565C0),
          ),

          _divider(),

          // Inbound list — tap to see details + End Movement
          Expanded(
            child: inbound.isEmpty
                ? _emptyState('No inbound containers', 'Start containers above')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    itemCount: inbound.length,
                    itemBuilder: (ctx, i) {
                      final c = inbound[i];
                      final confirmed = _confirmedIds.contains(c.containerId);
                      return _InboundItem(
                        container: c,
                        driverConfirmed: confirmed,
                        onTap: () => _showInboundDetails(ctx, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────
  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Divider(
      height: 1,
      thickness: 1,
      color: AppColors.green.withValues(alpha: 0.1),
    ),
  );

  Widget _footer({required IconData icon, required String label}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
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
        Icon(icon, size: 13, color: AppColors.green.withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.green.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _emptyState(String title, String sub) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.inbox_outlined,
            size: 28,
            color: AppColors.green.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.green.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          sub,
          style: TextStyle(
            color: AppColors.green.withValues(alpha: 0.35),
            fontSize: 9,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section Header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color? accent;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final bg = accent ?? AppColors.green;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      color: bg,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: AppColors.yellow, size: 14),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Holding Item — greyed out until started, draggable once started
// ─────────────────────────────────────────────────────────────────────────────
class _HoldingItem extends StatelessWidget {
  final ContainerModel container;
  final bool started;
  final VoidCallback onTap;

  const _HoldingItem({
    required this.container,
    required this.started,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLaden = container.statusId == 1;
    final statusColor = isLaden ? AppColors.laden : AppColors.empty;
    final desc = container.containerDesc;

    final content = _content(isLaden, statusColor, desc);

    if (!started) {
      return GestureDetector(
        onTap: onTap,
        child: Opacity(opacity: 0.5, child: content),
      );
    }

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
            child: _content(isLaden, statusColor, desc),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.25,
          child: SizedBox(
            width: 196,
            child: _content(isLaden, statusColor, desc),
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _content(bool isLaden, Color statusColor, String? desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: started
            ? (isLaden
                  ? AppColors.laden.withValues(alpha: 0.05)
                  : AppColors.empty.withValues(alpha: 0.05))
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: started
              ? statusColor.withValues(alpha: 0.3)
              : const Color(0xFFDDDDDD),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 56,
            decoration: BoxDecoration(
              color: started ? statusColor : const Color(0xFFBBBBBB),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: started
                              ? statusColor.withValues(alpha: 0.15)
                              : const Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isLaden ? 'Laden' : 'Empty',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: started
                                ? statusColor
                                : const Color(0xFF999999),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!started)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEEEE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'TAP TO START',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF888888),
                              letterSpacing: 0.3,
                            ),
                          ),
                        )
                      else
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
                    style: TextStyle(
                      fontSize: 12,
                      color: started
                          ? AppColors.textDark
                          : const Color(0xFF888888),
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
                        color: started
                            ? AppColors.green.withValues(alpha: 0.45)
                            : const Color(0xFFAAAAAA),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Inbound Item
//    • driverConfirmed = false  → black & white (greyscale)
//    • driverConfirmed = true   → full color + "END MOVEMENT" hint
// ─────────────────────────────────────────────────────────────────────────────
class _InboundItem extends StatelessWidget {
  final ContainerModel container;
  final bool driverConfirmed;
  final VoidCallback onTap;

  const _InboundItem({
    required this.container,
    required this.driverConfirmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLaden = container.statusId == 1;
    final desc = container.containerDesc;

    // Confirmed → full color; waiting → greyscale
    final stripeColor = driverConfirmed
        ? (isLaden ? AppColors.laden : AppColors.empty)
        : const Color(0xFFBBBBBB);
    final bgColor = driverConfirmed
        ? (isLaden
              ? AppColors.laden.withValues(alpha: 0.07)
              : AppColors.empty.withValues(alpha: 0.07))
        : const Color(0xFFF5F5F5);
    final borderColor = driverConfirmed
        ? stripeColor.withValues(alpha: 0.25)
        : const Color(0xFFDDDDDD);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            // Stripe
            Container(
              width: 5,
              height: 58,
              decoration: BoxDecoration(
                color: stripeColor,
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
                        // Status label
                        _badge(
                          driverConfirmed
                              ? (isLaden ? 'Laden' : 'Empty')
                              : 'WAITING',
                          driverConfirmed
                              ? stripeColor
                              : const Color(0xFF999999),
                          driverConfirmed
                              ? stripeColor.withValues(alpha: 0.15)
                              : const Color(0xFFEEEEEE),
                        ),
                        const SizedBox(width: 5),
                        // Confirmation badge
                        if (driverConfirmed)
                          _badge(
                            'CONFIRMED',
                            const Color(0xFF1B8A3C),
                            const Color(0xFFE8F5E9),
                          )
                        else
                          _badge(
                            'PENDING DRIVER',
                            const Color(0xFF888888),
                            const Color(0xFFF0F0F0),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Container number — grey when unconfirmed, dark when confirmed
                    Text(
                      container.containerNumber,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: driverConfirmed
                            ? AppColors.textDark
                            : const Color(0xFF888888),
                      ),
                    ),
                    if (desc != null && desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 9,
                          color: driverConfirmed
                              ? AppColors.green.withValues(alpha: 0.45)
                              : const Color(0xFFAAAAAA),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (driverConfirmed) ...[
                      const SizedBox(height: 4),
                      // "Tap to end movement" hint
                      Row(
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 10,
                            color: AppColors.green.withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Tap to end movement',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.green.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Right icon
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                driverConfirmed
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_empty_rounded,
                size: 15,
                color: driverConfirmed
                    ? const Color(0xFF1B8A3C)
                    : const Color(0xFFBBBBBB),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color textColor, Color bgColor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 7.5,
        fontWeight: FontWeight.w900,
        color: textColor,
        letterSpacing: 0.3,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Holding Details Dialog — container info + START button
// ─────────────────────────────────────────────────────────────────────────────
class _HoldingDetailsDialog extends StatelessWidget {
  final ContainerModel container;
  final bool isStarted;
  final VoidCallback onStart;

  const _HoldingDetailsDialog({
    required this.container,
    required this.isStarted,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final isLaden = container.statusId == 1;
    final statusColor = isLaden ? AppColors.laden : AppColors.empty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogHeader(container.containerNumber),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statusBadgeRow(isLaden, statusColor),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 10),
                  _infoRow('Container', container.containerNumber),
                  if (container.containerDesc?.isNotEmpty == true)
                    _infoRow('Description', container.containerDesc!),
                  _infoRow(
                    'Status',
                    isLaden ? 'Laden' : 'Empty',
                    valueColor: statusColor,
                  ),
                  if (container.boundTo != null)
                    _infoRow('Bound To', container.boundTo!),
                  _infoRow(
                    'Location',
                    container.yardId == null ? 'Unassigned' : 'Yard assigned',
                  ),
                  if (isStarted) ...[
                    const SizedBox(height: 8),
                    _infoChip(
                      icon: Icons.check_circle_outline,
                      label: 'Already started — visible in Inbound Area',
                      color: AppColors.laden,
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (!isStarted)
                    _actionButton(
                      label: 'START',
                      icon: Icons.play_arrow_rounded,
                      color: AppColors.green,
                      onPressed: onStart,
                    )
                  else
                    _outlineButton(
                      label: 'Close',
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── shared builders ─────────────────────────────────────────────────────────
  Widget _statusBadgeRow(bool isLaden, Color statusColor) => Row(
    children: [
      _pill(
        isLaden ? 'Laden' : 'Empty',
        statusColor,
        statusColor.withValues(alpha: 0.15),
      ),
      if (container.type != null) ...[
        const SizedBox(width: 8),
        _pill(
          container.type!,
          AppColors.green.withValues(alpha: 0.7),
          AppColors.green.withValues(alpha: 0.08),
        ),
      ],
    ],
  );

  Widget _pill(String label, Color textColor, Color bgColor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: textColor.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Inbound Details Dialog — shows status + END MOVEMENT button if confirmed
// ─────────────────────────────────────────────────────────────────────────────
class _InboundDetailsDialog extends StatelessWidget {
  final ContainerModel container;
  final bool driverConfirmed;
  final VoidCallback onEndMovement;

  const _InboundDetailsDialog({
    required this.container,
    required this.driverConfirmed,
    required this.onEndMovement,
  });

  @override
  Widget build(BuildContext context) {
    final isLaden = container.statusId == 1;
    final statusColor = isLaden ? AppColors.laden : AppColors.empty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogHeader(container.containerNumber),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _pill(
                        isLaden ? 'Laden' : 'Empty',
                        statusColor,
                        statusColor.withValues(alpha: 0.15),
                      ),
                      _pill(
                        driverConfirmed
                            ? 'Driver Confirmed ✓'
                            : 'Awaiting Driver',
                        driverConfirmed
                            ? const Color(0xFF1B8A3C)
                            : const Color(0xFF888888),
                        driverConfirmed
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFF0F0F0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 10),
                  _infoRow('Container', container.containerNumber),
                  if (container.containerDesc?.isNotEmpty == true)
                    _infoRow('Description', container.containerDesc!),
                  _infoRow(
                    'Status',
                    isLaden ? 'Laden' : 'Empty',
                    valueColor: statusColor,
                  ),
                  if (container.boundTo != null)
                    _infoRow('Bound To', container.boundTo!),
                  const SizedBox(height: 8),
                  // State info chip
                  _infoChip(
                    icon: driverConfirmed
                        ? Icons.check_circle_outline
                        : Icons.hourglass_empty_rounded,
                    label: driverConfirmed
                        ? 'Driver confirmed — you can now end the movement'
                        : 'Waiting for driver to confirm the operation',
                    color: driverConfirmed
                        ? const Color(0xFF1B8A3C)
                        : const Color(0xFF888888),
                  ),
                  const SizedBox(height: 18),
                  if (driverConfirmed)
                    _actionButton(
                      label: 'END MOVEMENT',
                      icon: Icons.check_rounded,
                      color: const Color(0xFF1B8A3C),
                      onPressed: onEndMovement,
                    )
                  else
                    _outlineButton(
                      label: 'Close',
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color textColor, Color bgColor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: textColor.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared dialog helpers (top-level functions so both dialog classes can use)
// ─────────────────────────────────────────────────────────────────────────────
Widget _dialogHeader(String title) => Container(
  padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
  decoration: const BoxDecoration(
    color: AppColors.green,
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  child: Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.inbox_rounded,
          color: AppColors.yellow,
          size: 16,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),
      Builder(
        builder: (ctx) => GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: const Icon(Icons.close, color: Colors.white70, size: 18),
        ),
      ),
    ],
  ),
);

Widget _infoRow(String label, String value, {Color? valueColor}) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 80,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF757575),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: valueColor ?? AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  ),
);

Widget _infoChip({
  required IconData icon,
  required String label,
  required Color color,
}) => Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: color.withValues(alpha: 0.3)),
  ),
  child: Row(
    children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  ),
);

Widget _actionButton({
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onPressed,
}) => SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
    ),
  ),
);

Widget _outlineButton({
  required String label,
  required IconData icon,
  required VoidCallback onPressed,
}) => SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 16),
    label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.green,
      side: BorderSide(color: AppColors.green.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
);
