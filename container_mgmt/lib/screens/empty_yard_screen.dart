import 'package:flutter/material.dart';

class EmptyYardScreen extends StatelessWidget {
  final String portName;
  final int yardNumber;
  const EmptyYardScreen({
    super.key,
    required this.portName,
    required this.yardNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$portName — Yard $yardNumber')),
      body: Center(
        child: Text(
          'Manila Yard: $yardNumber',
          style: const TextStyle(fontSize: 24, color: Colors.grey),
        ),
      ),
    );
  }
}
