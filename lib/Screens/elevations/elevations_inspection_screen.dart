import 'package:claimscope_clean/Services/pdf_service.dart';
import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/screens/elevations/building_elevations_section.dart';
import 'package:claimscope_clean/screens/elevations/global_elevations_hub.dart';
import 'package:claimscope_clean/screens/elevations/models/elevations_data.dart';
import 'package:claimscope_clean/screens/elevations/state/elevations_autosaver.dart';
import 'package:claimscope_clean/screens/elevations/widgets/elevation_tab_strip.dart';
import 'package:claimscope_clean/services/inspection_submission_service.dart';
import 'package:flutter/material.dart';

/// Shell único para residential + commercial.
/// Diferencia solo el título del AppBar; la estructura es idéntica.
///
/// Anti-rebuild: `IndexedStack` mantiene cada `BuildingElevationsSection`
/// montada. Cambiar de tab NO destruye controllers ni scroll.
class ElevationsInspectionScreen extends StatefulWidget {
  final InspectionReport report;
  final bool isCommercial;
  final String plan;

  const ElevationsInspectionScreen({
    super.key,
    required this.report,
    required this.isCommercial,
    required this.plan,
  });

  @override
  State<ElevationsInspectionScreen> createState() =>
      _ElevationsInspectionScreenState();
}

class _ElevationsInspectionScreenState extends State<ElevationsInspectionScreen> {
  late final ElevationsAutoSaver _saver;
  int _activeIdx = 0;
  bool _showElevationStrip = false;

  String get _reportId =>
      '${widget.report.claimNumber}_${widget.report.dateInspected}';

  @override
  void initState() {
    super.initState();
    _saver = ElevationsAutoSaver(
      reportId: _reportId,
      data: widget.report.elevations,
    )..mount();
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

  Future<void> _submitInspection() async {
    final navigator = Navigator.of(context);
    bool loadingShown = false;

    try {
      await _saver.flush();
      if (!mounted) return;

      widget.report.isCommercial = widget.isCommercial;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      loadingShown = true;

      final pdfs = await PdfService.generateReports(widget.report);
      if (!mounted) return;

      if (loadingShown && navigator.canPop()) {
        navigator.pop();
        loadingShown = false;
      }

      await InspectionSubmissionService.showOptions(
        context: context,
        report: widget.report,
        plan: widget.plan,
        isCommercial: widget.isCommercial,
        techPdf: pdfs['tech']!,
        photoPdf: pdfs['photos']!,
      );
    } catch (e) {
      if (!mounted) return;
      if (loadingShown && navigator.canPop()) {
        navigator.pop();
        loadingShown = false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDFs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
    controller.dispose();
    if (label == null || label.isEmpty) return;
    setState(() {
      widget.report.elevations.elevations.add(BuildingElevation(OtherSide(label)));
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
    final safeIdx = _activeIdx.clamp(0, elevations.length - 1);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    GlobalElevationsHub(
                      data: widget.report.elevations,
                      report: widget.report,
                      onChange: _onChange,
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
                              setState(() =>
                                  _showElevationStrip = !_showElevationStrip);
                            },
                            trailing: IconButton(
                              icon: Icon(
                                _showElevationStrip
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                              ),
                              onPressed: () {
                                setState(() =>
                                    _showElevationStrip = !_showElevationStrip);
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
                              height:
                                  (MediaQuery.of(context).size.height * 0.70 -
                                          MediaQuery.of(context)
                                              .viewInsets
                                              .bottom)
                                      .clamp(
                                250.0,
                                MediaQuery.of(context).size.height * 0.70,
                              ),
                              child: IndexedStack(
                                index: safeIdx,
                                children: [
                                  for (final e in elevations)
                                    BuildingElevationsSection(
                                      key: ValueKey(e.side.key),
                                      elevation: e,
                                      report: widget.report,
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
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitInspection,
                  child: const Text('Submit Inspection'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
