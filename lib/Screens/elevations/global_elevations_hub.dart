import 'package:flutter/material.dart';

import 'models/elevations_data.dart';

/// Orquestador de Secciones 1 (Emergency Services) y 2 (Gutters/Soffit/Fascia).
/// Estas secciones son "globales al edificio" (no dependen de la elevación activa).
///
/// Por ahora es un placeholder compilable; en el paso 3 se insertan
/// `EmergencyServicesSection` y `GuttersSoffitFasciaSection`.
class GlobalElevationsHub extends StatelessWidget {
  final ElevationsData data;
  final VoidCallback onChange;

  const GlobalElevationsHub({
    super.key,
    required this.data,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlaceholderTile(
            title: 'Emergency Services',
            subtitle: 'Coming in step 3',
          ),
          const SizedBox(height: 8),
          _PlaceholderTile(
            title: 'Gutters / Soffit / Fascia',
            subtitle: 'Coming in step 3',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PlaceholderTile({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.construction_outlined),
        title: Text(title),
        subtitle: Text(subtitle),
        dense: true,
      ),
    );
  }
}
