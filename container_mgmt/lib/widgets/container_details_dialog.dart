import 'package:flutter/material.dart';
import '../models/container_model.dart';
import '../theme/app_theme.dart';

class ContainerDetailsDialog extends StatelessWidget {
  final ContainerModel container;
  const ContainerDetailsDialog({super.key, required this.container});

  @override
  Widget build(BuildContext context) {
    final isLaden = container.statusId == 1;
    final statusColor = isLaden ? AppColors.yellow : AppColors.red;
    final statusTextColor = isLaden ? AppColors.textDark : AppColors.white;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: const BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded,
                      color: AppColors.yellow, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'CONTAINER DETAILS',
                      style: TextStyle(
                        color: AppColors.yellow,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            // ── Container Number Badge ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.yellow.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  container.containerNumber,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: AppColors.textDark,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            // ── Details ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Status row
                  _DetailRow(
                    icon: Icons.radio_button_checked_rounded,
                    label: 'Status',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isLaden ? 'LADEN' : 'EMPTY',
                        style: TextStyle(
                          color: statusTextColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Type row
                  _DetailRow(
                    icon: Icons.category_rounded,
                    label: 'Type',
                    child: Text(
                      container.type ?? '—',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Description
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(Icons.notes_rounded,
                            color: AppColors.green, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Description',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDE7),
                      border: Border.all(
                          color: AppColors.yellow.withOpacity(0.4), width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      container.containerDesc?.isNotEmpty == true
                          ? container.containerDesc!
                          : 'No description provided.',
                      style: const TextStyle(
                          color: AppColors.textDark, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.green, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textGrey,
          ),
        ),
        const SizedBox(width: 12),
        child,
      ],
    );
  }
}
