import 'package:flutter/material.dart';

import '../../../inspection_report_model.dart';

class CommercialMetalHubForm extends StatelessWidget {
  final CommercialRoofSectionData roof;
  final TextEditingController pitchController;
  final TextEditingController facetCountController;
  final void Function(VoidCallback fn) setState;
  final VoidCallback sync;

  const CommercialMetalHubForm({
    super.key,
    required this.roof,
    required this.pitchController,
    required this.facetCountController,
    required this.setState,
    required this.sync,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: roof.metalStyle,
          decoration: const InputDecoration(
            labelText: 'Metal style',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Flat', child: Text('Flat')),
            DropdownMenuItem(value: 'Gable', child: Text('Gable')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (val) {
            setState(() {
              roof.metalStyle = val;
              if (val == 'Gable') {
                roof.facetCount = 2;
                facetCountController.text = '2';
              }
              if (val == 'Flat') {
                roof.facetCount = 1;
                facetCountController.text = '1';
                roof.metalHasFacets = null;
              }
            });
          },
        ),
        if (roof.metalStyle == 'Other') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<bool>(
            initialValue: roof.metalHasFacets,
            decoration: const InputDecoration(
              labelText: 'Has facets?',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: true, child: Text('Yes')),
              DropdownMenuItem(value: false, child: Text('No')),
            ],
            onChanged: (val) {
              setState(() {
                roof.metalHasFacets = val;
                if (val == true && roof.facetCount <= 1) {
                  roof.facetCount = 2;
                  facetCountController.text = '2';
                }
                if (val != true) {
                  roof.facetCount = 1;
                  facetCountController.text = '1';
                }
              });
            },
          ),
        ],
        if (roof.metalStyle == 'Gable' || roof.metalHasFacets == true) ...[
          const SizedBox(height: 12),
          TextField(
            controller: facetCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Facet count',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => sync(),
          ),
        ],
        if (roof.metalStyle != 'Flat') ...[
          const SizedBox(height: 12),
          TextField(
            controller: pitchController,
            decoration: const InputDecoration(
              labelText: 'Pitch (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => sync(),
          ),
        ],
      ],
    );
  }
}
