// lib/screens/commercial/components/commercial_hvac_mechanical_rooftop.dart

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../inspection_report_model.dart';

class CommercialHvacMechanicalRooftop extends StatelessWidget {
  final List<HvacUnitData> items;
  final Function() onChanged;
  final Future<void> Function({
    required String buildingName,
    required String roofName,
    required String photoLabel,
    required void Function(File) onSaved,
  }) takePhoto;

  final String buildingName;
  final String roofName;

  const CommercialHvacMechanicalRooftop({
    super.key,
    required this.items,
    required this.onChanged,
    required this.takePhoto,
    required this.buildingName,
    required this.roofName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HVAC / Mechanical rooftop',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF101230)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add HVAC'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFA7F21),
                foregroundColor: const Color(0xFF101230),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Mechanical'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFA7F21),
                foregroundColor: const Color(0xFF101230),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
