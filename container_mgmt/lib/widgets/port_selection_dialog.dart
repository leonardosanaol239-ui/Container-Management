import 'package:flutter/material.dart';
import '../screens/port_management_screen.dart';

class PortSelectionDialog extends StatefulWidget {
  const PortSelectionDialog({super.key});

  @override
  State<PortSelectionDialog> createState() => _PortSelectionDialogState();
}

class _PortSelectionDialogState extends State<PortSelectionDialog> {
  final List<Map<String, dynamic>> _ports = [
    {'portId': 1, 'name': 'MANILA PORT'},
    {'portId': 2, 'name': 'CEBU PORT'},
    {'portId': 3, 'name': 'DAVAO PORT'},
    {'portId': 4, 'name': 'BACOLOD PORT'},
    {'portId': 5, 'name': 'CAGAYAN PORT'},
  ];
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'SELECT LOCATION TO MANAGE CONTAINER',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const Divider(color: Colors.amber, thickness: 2),
            ..._ports.map(
              (p) => Column(
                children: [
                  InkWell(
                    onTap: () => setState(() => _selected = p['portId']),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: _selected == p['portId']
                          ? Colors.amber.withOpacity(0.15)
                          : null,
                      child: Text(
                        p['name'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: _selected == p['portId']
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
                                portId: port['portId'],
                                portName: port['name'],
                              ),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'CONFIRM',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
