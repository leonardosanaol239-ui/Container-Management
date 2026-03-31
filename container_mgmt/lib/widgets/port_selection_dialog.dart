import 'package:flutter/material.dart';
import '../screens/port_management_screen.dart';
import '../theme/app_theme.dart';

class PortSelectionDialog extends StatefulWidget {
  const PortSelectionDialog({super.key});

  @override
  State<PortSelectionDialog> createState() => _PortSelectionDialogState();
}

class _PortSelectionDialogState extends State<PortSelectionDialog> {
  final List<Map<String, dynamic>> _ports = [
    {'portId': 1, 'name': 'MANILA PORT', 'icon': Icons.anchor_rounded},
    {'portId': 2, 'name': 'CEBU PORT', 'icon': Icons.anchor_rounded},
    {'portId': 3, 'name': 'DAVAO PORT', 'icon': Icons.anchor_rounded},
    {'portId': 4, 'name': 'BACOLOD PORT', 'icon': Icons.anchor_rounded},
    {'portId': 5, 'name': 'CAGAYAN PORT', 'icon': Icons.anchor_rounded},
  ];
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_city_rounded,
                            color: AppColors.yellow, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SELECT PORT',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: AppColors.textDark,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              'Choose a location to manage',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                                color: AppColors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.textDark.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: AppColors.textDark, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Port list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: _ports.map((p) {
                  final isSelected = _selected == p['portId'];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selected = p['portId'] as int),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.yellow.withOpacity(0.15)
                            : const Color(0xFFF8F8F8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.yellow
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.green
                                  : AppColors.textGrey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              p['icon'] as IconData,
                              color: isSelected
                                  ? AppColors.yellow
                                  : AppColors.textGrey,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p['name'] as String,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 14,
                                color: isSelected
                                    ? AppColors.textDark
                                    : AppColors.textGrey,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.green, size: 20),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Confirm button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selected == null
                      ? null
                      : () {
                          final port = _ports.firstWhere(
                            (p) => p['portId'] == _selected,
                          );
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PortManagementScreen(
                                portId: port['portId'] as int,
                                portName: port['name'] as String,
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text(
                    'OPEN PORT',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: Colors.grey[200],
                    disabledForegroundColor: AppColors.textGrey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
