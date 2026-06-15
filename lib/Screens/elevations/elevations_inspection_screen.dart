import 'package:flutter/material.dart';

import 'package:claimscope_clean/screens/elevations/models/elevations_data.dart'; //  CORRECTO
import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/screens/elevations/building_elevations_section.dart';
import 'package:claimscope_clean/screens/elevations/global_elevations_hub.dart';
import 'package:claimscope_clean/screens/elevations/state/elevations_autosaver.dart';
import 'package:claimscope_clean/screens/elevations/widgets/elevation_tab_strip.dart';

/// Shell único para residential + commercial.
/// Diferencia solo el título del AppBar; la estructura es idéntica.
///
/// Anti-rebuild: `IndexedStack` mantiene cada `BuildingElevationsSection`
/// montada. Cambiar de tab NO destruye controllers ni scroll.
class ElevationsInspectionScreen extends StatefulWidget {
  
  final InspectionReport report;
  final bool isCommercial;
  
  const ElevationsInspectionScreen({
    super.key,
    required this.report,
    required this.isCommercial,
  });

  @override
  State<ElevationsInspectionScreen> createState() =>
      _ElevationsInspectionScreenState();
 }

 class _ElevationsInspectionScreenState
    extends State<ElevationsInspectionScreen> {
  late final ElevationsAutoSaver _saver;
  int _activeIdx = 0;
  bool _showElevationStrip = false;
  // ID estable para el draft. Si más adelante el modelo expone un id real,
  // reemplaza esta línea por `widget.report.id`.
  String get _reportId =>
      '${widget.report.claimNumber}_${widget.report.dateInspected}';

  @override
  void initState() {
    super.initState();
    _saver = ElevationsAutoSaver(
      reportId: _reportId,
      data: widget.report.elevations,
    )..mount();
    // Rehidratar borrador asincrónicamente.
    _saver.restoreInto(widget.report.elevations).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _saver.flushAndDispose();
    super.dispose();
  }

  void _onChange() => _saver.markDirty();

  Future<void> _promptAddOther() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add elevation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Side name',
            hintText: 'e.g. Northwest, Courtyard',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;
    setState(() {
      widget.report.elevations.elevations
          .add(BuildingElevation(OtherSide(label)));
      _activeIdx = widget.report.elevations.elevations.length - 1;
    });
    _onChange();
  }

  @override
 Widget build(BuildContext context) {
  final elevations = widget.report.elevations.elevations;
  final title = widget.isCommercial
      ? 'Commercial Elevations'
      : 'Residential Elevations';

  // Clamp por seguridad si se eliminó una elevación.
  final safeIdx = _activeIdx.clamp(0, elevations.length - 1);

  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: Column(
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: GlobalElevationsHub(
              data: widget.report.elevations,
              onChange: _onChange,
            ),
          ),
Card(
  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
  child: Column(
    children: [
      ListTile(
        title: const Text(
          'Elevations',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: () {
          setState(() {
            _showElevationStrip = !_showElevationStrip;
          });
        },
        trailing: IconButton(
          icon: Icon(
            _showElevationStrip
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
          ),
          onPressed: () {
            setState(() {
              _showElevationStrip = !_showElevationStrip;
            });
          },
        ),
      ),

      if (_showElevationStrip) ...[
        ElevationTabStrip(
          elevations: elevations,
          activeIdx: safeIdx,
          onTap: (i) => setState(() => _activeIdx = i),
          onAddOther: _promptAddOther,
          allowAddOther: true,
        ),

        SizedBox(
         height: (MediaQuery.of(context).size.height * 0.70 -
        MediaQuery.of(context).viewInsets.bottom)
    .clamp(250.0, MediaQuery.of(context).size.height * 0.70),
          child: IndexedStack(
            index: safeIdx,
            children: [
              for (final e in elevations)
                BuildingElevationsSection(
                  key: ValueKey(e.side.key),
                  elevation: e,
                  onChange: _onChange,
                ),
            ],
          ),
        ),
      ],
    ],
  ),
),
        ],
      ),
    ),
  );
 }
}