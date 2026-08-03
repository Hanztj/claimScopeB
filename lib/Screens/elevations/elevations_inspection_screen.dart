import 'dart:io';

import 'package:claimscope_clean/services/pdf_service.dart';
import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/screens/elevations/building_elevations_section.dart';
import 'package:claimscope_clean/screens/elevations/global_elevations_hub.dart';
import 'package:claimscope_clean/screens/elevations/models/elevations_data.dart';
import 'package:claimscope_clean/screens/elevations/state/elevations_autosaver.dart';
import 'package:claimscope_clean/screens/elevations/widgets/elevation_tab_strip.dart';
import 'package:claimscope_clean/utils/blocking_progress_dialog.dart';
import 'package:claimscope_clean/services/inspection_submission_service.dart';
import 'package:claimscope_clean/utils/required_photo_validation.dart';
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
  bool _isSubmitting = false;

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

  String? _firstMissingElementPhotoMessage() {
    final checks = <RequiredPhotoCheck>[];

    for (final elevation in widget.report.elevations.elevations) {
      final side = elevation.side.display;

      checks.add(() {
        if (elevation.eifs.hasAnyData && elevation.eifs.photo == null) {
          return '$side Elev. - EIFS: Take the main EIFS Photo before submitting.';
        }
        return null;
      });

      for (var i = 0; i < elevation.trims.length; i++) {
        final trim = elevation.trims[i];
        checks.add(() {
          if (_trimHasAnyData(trim) && trim.photo == null) {
            return '$side Elev. - Trim ${i + 1}: Take the main Trim Photo before submitting.';
          }
          return null;
        });
      }

      for (var i = 0; i < elevation.windows.length; i++) {
        final window = elevation.windows[i];
        checks.add(() {
          if (window.hasAnyData && window.photo == null) {
            return '$side Elev. - Window ${i + 1}: Take the main Window Photo before submitting.';
          }
          return null;
        });
      }

      for (var i = 0; i < elevation.doors.length; i++) {
        final door = elevation.doors[i];
        checks.add(() {
          if (door.hasAnyData && door.photo == null) {
            return '$side Elev. - Door ${i + 1}: Take the main Door Photo before submitting.';
          }
          return null;
        });
      }

      for (var i = 0; i < elevation.accessories.length; i++) {
        final accessory = elevation.accessories[i];
        checks.add(() {
          if (accessory.hasAnyData && accessory.photo == null) {
            return '$side Elev. - Accessory ${i + 1}: Take the main Accessory Photo before submitting.';
          }
          return null;
        });
      }
    }

    return firstMissingRequiredPhoto(checks);
  }

  bool _trimHasAnyData(TrimEntry trim) {
    return trim.trimType.isNotEmpty ||
        trim.otherSpecify.isNotEmpty ||
        trim.action.isNotEmpty ||
        trim.ocpMaterial.isNotEmpty ||
        trim.ocpInsulated ||
        trim.ocpMetalGauge.isNotEmpty ||
        trim.jTrimMaterial.isNotEmpty ||
        trim.sidingTrimMaterial.isNotEmpty ||
        trim.sidingTrimSize.isNotEmpty ||
        trim.skirtingMaterial.isNotEmpty ||
        trim.skirtingSize.isNotEmpty ||
        trim.photo != null ||
        trim.extraPhoto != null;
  }

  Future<void> _submitInspection() async {
    if (_isSubmitting) return;

    final missingPhotoMessage = _firstMissingElementPhotoMessage();
    if (missingPhotoMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(missingPhotoMessage),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);

    try {
      final generationMessage = widget.isCommercial
          ? PdfService.hasLargeCommercialInspection(widget.report)
              ? 'Large commercial inspections may require additional processing time. '
                  'Keep ClaimScope open until report generation is complete.'
              : null
          : 'This may take several minutes for inspections with many photos. '
              'Keep ClaimScope open until report generation is complete.';
      final pdfs = await runWithBlockingProgress<Map<String, File>>(
        context: context,
        message: 'Generating inspection reports...',
        secondaryMessage: generationMessage,
        task: () async {
          await _saver.flush();
          widget.report.isCommercial = widget.isCommercial;
          await PdfService.buildPartialPhotoPdfsForElevations(widget.report);
          return PdfService.generateReports(widget.report);
        },
      );

      if (!mounted) return;

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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error generating PDFs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      } else {
        _isSubmitting = false;
      }
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
                  onPressed: _isSubmitting ? null : _submitInspection,
                  child: _isSubmitting
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text('Generating reports...'),
                          ],
                        )
                      : const Text('Submit Inspection'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
