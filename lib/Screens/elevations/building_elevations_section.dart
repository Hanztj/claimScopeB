import 'package:flutter/material.dart';

import 'models/elevations_data.dart';

/// Orquestador de Secciones 3 (Siding + cards Trim/Window/Door/Accessory),
/// 4 (Underlayment/Insulation), 5 (Substrate) y EIFS — scope: la elevación
/// recibida. Se monta una instancia POR elevación dentro del `IndexedStack`
/// del shell, así cambiar de tab no destruye state ni controllers.
///
/// Placeholder compilable; las secciones reales se enchufan en pasos 4-5.
class BuildingElevationsSection extends StatelessWidget {
  final BuildingElevation elevation;
  final VoidCallback onChange;

  const BuildingElevationsSection({
    super.key,
    required this.elevation,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${elevation.side.display} elevation',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final s in const [
          'Siding & Damages (with Trim / Window / Door / Accessory cards)',
          'Underlayment & Insulation',
          'Substrate',
          'EIFS',
        ])
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.construction_outlined),
              title: Text(s),
              subtitle: const Text('Coming in steps 4-5'),
              dense: true,
            ),
          ),
      ],
    );
  }
}
