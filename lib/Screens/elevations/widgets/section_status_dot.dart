import 'package:flutter/material.dart';

/// Indicador discreto para encabezados de `ExpansionTile`:
/// - gris  → vacío
/// - ámbar → parcial (hay datos pero no completos)
/// - verde → completo
///
/// Se mantiene minimal (8px) para no saturar la UI; la integramos como
/// `trailing` o junto al `title` de cada sección colapsable.
enum SectionStatus { empty, partial, complete }

class SectionStatusDot extends StatelessWidget {
  final SectionStatus status;
  final double size;

  const SectionStatusDot({
    super.key,
    required this.status,
    this.size = 8,
  });

  Color _color(BuildContext c) {
    switch (status) {
      case SectionStatus.empty:
        return Theme.of(c).disabledColor.withOpacity(0.4);
      case SectionStatus.partial:
        return Colors.amber.shade600;
      case SectionStatus.complete:
        return Colors.green.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color(context),
        shape: BoxShape.circle,
      ),
    );
  }
}
