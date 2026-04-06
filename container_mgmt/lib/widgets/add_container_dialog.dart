import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AddContainerDialog extends StatefulWidget {
  final int portId;
  const AddContainerDialog({super.key, required this.portId});

  @override
  State<AddContainerDialog> createState() => _AddContainerDialogState();
}

class _AddContainerDialogState extends State<AddContainerDialog> {
  final _api = ApiService();
  final _descCtrl = TextEditingController();
  int _statusId = 2; // default Empty
  int _sizeId = 1; // default 20ft
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.createContainer(
        statusId: _statusId,
        containerSizeId: _sizeId,
        desc: _descCtrl.text.trim(),
        portId: widget.portId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
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
            // ── Header ────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_box_rounded,
                      color: AppColors.yellow,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ADD CONTAINER',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: AppColors.textDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Fill in the container details',
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
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textDark,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Form ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status selector
                  _FieldLabel(
                    icon: Icons.radio_button_checked_rounded,
                    label: 'Container Status',
                  ),
                  const SizedBox(height: 8),
                  // Status toggle buttons
                  Row(
                    children: [
                      _StatusButton(
                        label: 'Empty',
                        selected: _statusId == 2,
                        color: AppColors.red,
                        onTap: () => setState(() => _statusId = 2),
                      ),
                      const SizedBox(width: 10),
                      _StatusButton(
                        label: 'Laden',
                        selected: _statusId == 1,
                        color: AppColors.yellow,
                        textColor: AppColors.textDark,
                        onTap: () => setState(() => _statusId = 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _FieldLabel(
                    icon: Icons.straighten_rounded,
                    label: 'Container Size',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatusButton(
                        label: '20ft',
                        selected: _sizeId == 1,
                        color: AppColors.green,
                        onTap: () => setState(() => _sizeId = 1),
                      ),
                      const SizedBox(width: 10),
                      _StatusButton(
                        label: '40ft',
                        selected: _sizeId == 2,
                        color: AppColors.green,
                        onTap: () => setState(() => _sizeId = 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _FieldLabel(
                    icon: Icons.notes_rounded,
                    label: 'Container Description',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Optional description…',
                      hintStyle: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 13,
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.red.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded, size: 20),
                      label: Text(
                        _loading ? 'SAVING…' : 'ADD CONTAINER',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
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

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FieldLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.green, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.selected,
    required this.color,
    this.textColor = AppColors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: selected ? textColor : AppColors.textGrey,
            ),
          ),
        ),
      ),
    );
  }
}
