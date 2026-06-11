import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/slot_allocation_service.dart';
import '../models/container_model.dart';

class VacantSlotAllocationDialog extends StatefulWidget {
  final ContainerModel container;
  final int portId;
  final Function(VacantSlot?) onAssigned;
  final VoidCallback onSkipped;

  const VacantSlotAllocationDialog({
    super.key,
    required this.container,
    required this.portId,
    required this.onAssigned,
    required this.onSkipped,
  });

  @override
  State<VacantSlotAllocationDialog> createState() =>
      _VacantSlotAllocationDialogState();
}

class _VacantSlotAllocationDialogState extends State<VacantSlotAllocationDialog> {
  final _api = ApiService();
  final _slotService = SlotAllocationService();
  bool _loading = true;
  bool _assigning = false;
  VacantSlot? _suggestedSlot;
  String? _error;

  @override
  void initState() {
    super.initState();
    _findNearestSlot();
  }

  Future<void> _findNearestSlot() async {
    try {
      final slot = await _slotService.findNearestVacantSlot(
        widget.portId,
        widget.container.containerSizeId ?? 1,
      );
      if (mounted) {
        setState(() {
          _suggestedSlot = slot;
          _loading = false;
          if (slot == null) {
            _error = 'No vacant slots available in this port.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to find vacant slot: $e';
        });
      }
    }
  }

  Future<void> _assignToSlot() async {
    if (_suggestedSlot == null) return;
    setState(() => _assigning = true);

    try {
      await _api.moveContainer(
        containerId: widget.container.containerId,
        yardId: _suggestedSlot!.yardId,
        blockId: _suggestedSlot!.blockId,
        bayId: _suggestedSlot!.bayId,
        rowId: _suggestedSlot!.rowId,
        tier: _suggestedSlot!.tier,
        locationStatusId: 3, // Move request
      );
      
      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned(_suggestedSlot);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _assigning = false;
          _error = 'Failed to assign container: $e';
        });
      }
    }
  }

  void _skipAllocation() {
    Navigator.pop(context);
    widget.onSkipped();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x28000000),
                blurRadius: 32,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: const BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vacant Slot Allocation',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Automatic slot suggestion',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _skipAllocation,
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: AppColors.green,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Finding nearest vacant slot...',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _suggestedSlot == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'No vacant slot found',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _skipAllocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Container info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.yellow.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: AppColors.textDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Container',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.container.containerNumber,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Suggested slot info
          const Text(
            'Suggested Slot Location',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.green.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.place_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _suggestedSlot!.locationString,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.straighten,
                        color: AppColors.green,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Nearest to entrance',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Message
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.blue,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A new available slot has been identified: ${_suggestedSlot!.locationString}. Would you like to automatically assign the container to this slot?',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _assigning ? null : _skipAllocation,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textGrey,
                    side: BorderSide(
                      color: AppColors.textGrey.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'NO',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _assigning ? null : _assignToSlot,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _assigning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'YES',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
