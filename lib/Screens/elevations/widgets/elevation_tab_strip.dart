import 'package:flutter/material.dart';

// Borra: import '../models/elevations_data.dart';
// Y pega esto:
import 'package:claimscope_clean/screens/elevations/models/elevations_data.dart';
import 'section_status_dot.dart';

/// Strip horizontal de chips: Front | Right | Rear | Left | + Other.
///
/// - Mantiene scroll horizontal si el catálogo crece (commercial con varios "Other").
/// - El padre decide qué pasa al pulsar `+`: típicamente abrir dialog y pushear
///   `BuildingElevation(OtherSide(label))` a `data.elevations`.
class ElevationTabStrip extends StatelessWidget {
  final List<BuildingElevation> elevations;
  final int activeIdx;
  final ValueChanged<int> onTap;
  final VoidCallback onAddOther;
  final bool allowAddOther;

  const ElevationTabStrip({
    super.key,
    required this.elevations,
    required this.activeIdx,
    required this.onTap,
    required this.onAddOther,
    this.allowAddOther = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
        height: 68,
       margin: const EdgeInsets.fromLTRB(14, 12, 12, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
     borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            for (var i = 0; i < elevations.length; i++) ...[
              _SideChip(
                label: elevations[i].side.display,
                active: i == activeIdx,
                hasData: elevations[i].hasAnyData,
                onTap: () => onTap(i),
              ),
              const SizedBox(width: 8),
            ],
            if (allowAddOther)
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Other'),
                onPressed: onAddOther,
              ),
          ],
        ),
      ),
    );
  }
}

class _SideChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool hasData;
  final VoidCallback onTap;

  const _SideChip({
    required this.label,
    required this.active,
    required this.hasData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      selected: active,
      onSelected: (_) => onTap(),
      selectedColor: cs.primary,
      labelStyle: TextStyle(
        color: active ? cs.onPrimary : cs.onSurface,
        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (hasData) ...[
            const SizedBox(width: 6),
            SectionStatusDot(
              status: SectionStatus.partial,
              size: 6,
            ),
          ],
        ],
      ),
    );
  }
}
