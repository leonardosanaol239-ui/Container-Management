import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/container_model.dart';
import '../models/row_model.dart';

class TierSelectionDialog extends StatefulWidget {
  final ContainerModel container;
  final RowModel row;
  final List<ContainerModel> existingContainers;
  final Function(int tier) onConfirm;

  const TierSelectionDialog({
    super.key,
    required this.container,
    required this.row,
    required this.existingContainers,
    required this.onConfirm,
  });

  @override
  State<TierSelectionDialog> createState() => _TierSelectionDialogState();
}

class _TierSelectionDialogState extends State<TierSelectionDialog> {
  int? _selectedTier;

  @override
  void initState() {
    super.initState();
    // Auto-select the next available tier
    final usedTiers = widget.existingContainers.map((c) => c.tier ?? 0).toSet();
    for (int i = 1; i <= widget.row.maxStack; i++) {
      if (!usedTiers.contains(i)) {
        _selectedTier = i;
        break;
      }
    }
  }

  List<int> get _availableTiers {
    final usedTiers = widget.existingContainers.map((c) => c.tier ?? 0).toSet();
    final available = <int>[];
    for (int i = 1; i <= widget.row.maxStack; i++) {
      if (!usedTiers.contains(i)) {
        available.add(i);
      }
    }
    return available;
  }

  @override
  Widget build(BuildContext context) {
    final availableTiers = _availableTiers;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
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
              Flexible(child: _buildContent(availableTiers)),
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
              Icons.layers_rounded,
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
                  'Select Tier',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Choose stacking position',
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
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<int> availableTiers) {
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

          // Row info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.green.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.green,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Row ${widget.row.rowNumber} • Max Stack: ${widget.row.maxStack}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tier selection
          const Text(
            'Available Tiers',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),

          if (availableTiers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.2),
                ),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.block,
                      color: AppColors.red,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No available tiers',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.red,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: availableTiers.map((tier) {
                final isSelected = _selectedTier == tier;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTier = tier),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.green
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.green
                            : AppColors.textGrey.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.green.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.layers,
                          color: isSelected ? Colors.white : AppColors.textGrey,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tier $tier',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),

          // Existing containers in this row
          if (widget.existingContainers.isNotEmpty) ...[
            const Text(
              'Existing Containers',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.existingContainers.map((c) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textGrey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Tier ${c.tier ?? '-'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c.containerNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
          ],

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
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
                    'CANCEL',
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
                  onPressed: _selectedTier == null || availableTiers.isEmpty
                      ? null
                      : () {
                          widget.onConfirm(_selectedTier!);
                          Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'CONFIRM',
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
