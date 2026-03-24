import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddContainerDialog extends StatefulWidget {
  final int portId;
  const AddContainerDialog({super.key, required this.portId});

  @override
  State<AddContainerDialog> createState() => _AddContainerDialogState();
}

class _AddContainerDialogState extends State<AddContainerDialog> {
  final _api = ApiService();
  final _typeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _statusId = 2; // default Empty
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _typeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_typeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Type is required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.createContainer(
        statusId: _statusId,
        type: _typeCtrl.text.trim(),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Fill Container Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Container Status:'),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _statusId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 2, child: Text('Empty')),
                DropdownMenuItem(value: 1, child: Text('Laden')),
              ],
              onChanged: (v) => setState(() => _statusId = v!),
            ),
            const SizedBox(height: 14),
            const Text('Type:'),
            const SizedBox(height: 6),
            TextField(
              controller: _typeCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            const Text('Container Desc:'),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'ADD CONTAINER',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
