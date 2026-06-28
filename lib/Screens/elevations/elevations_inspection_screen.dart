import 'dart:io';

import 'package:claimscope_clean/Services/email_service.dart';
import 'package:claimscope_clean/Services/pdf_service.dart';
import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/screens/elevations/building_elevations_section.dart';
import 'package:claimscope_clean/screens/elevations/global_elevations_hub.dart';
import 'package:claimscope_clean/screens/elevations/models/elevations_data.dart';
import 'package:claimscope_clean/screens/elevations/state/elevations_autosaver.dart';
import 'package:claimscope_clean/screens/elevations/widgets/elevation_tab_strip.dart';
import 'package:claimscope_clean/screens/widgets/submission_options_dialog.dart';
import 'package:claimscope_clean/utils/hf_pricing_helper.dart';
import 'package:claimscope_clean/utils/labeled_photos_zip.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  bool _isProbablyValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty || email.contains(' ')) return false;
    final at = email.indexOf('@');
    if (at <= 0 || at != email.lastIndexOf('@')) return false;
    final dot = email.lastIndexOf('.');
    if (dot <= at + 1 || dot == email.length - 1) return false;
    return true;
  }

  Future<T> _runWithBlockingProgress<T>(
    String message,
    Future<T> Function() task,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );

    try {
      return await task();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<bool> _askStoreReportInCloud() async {
    if (widget.plan != 'premium') return false;

    final navigator = Navigator.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Store report in Cloud?'),
        content: const Text(
          'Do you want to store this inspection report in your account (Cloud)?',
        ),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => navigator.pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _storeReportInCloud(File techPdf, File photoPdf) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('User not authenticated.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Storing report in Cloud...')),
          ],
        ),
      ),
    );

    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;
      final reportRef = firestore
          .collection('users')
          .doc(user.uid)
          .collection('inspectionReports')
          .doc();

      final reportId = reportRef.id;
      final techFilename = techPdf.uri.pathSegments.last;
      final photoFilename = photoPdf.uri.pathSegments.last;
      final techPath = 'user_reports/${user.uid}/$reportId/$techFilename';
      final photoPath = 'user_reports/${user.uid}/$reportId/$photoFilename';

      await storage.ref(techPath).putFile(techPdf);
      await storage.ref(photoPath).putFile(photoPdf);

      await reportRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 60)),
        ),
        'claimNumber': widget.report.claimNumber,
        'clientName': widget.report.clientName,
        'techPath': techPath,
        'photoPath': photoPath,
      });

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Report stored in Cloud.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error storing report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendReportViaEmail(
    File techPdf,
    File photoPdf, {
    String? extraEmail,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null || user.email!.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final toEmails = <String>[user.email!];
    if (widget.plan == 'premium' &&
        extraEmail != null &&
        extraEmail.trim().isNotEmpty) {
      toEmails.add(extraEmail.trim());
    }

    try {
      await _runWithBlockingProgress<void>(
        'Sending email...',
        () => EmailService.sendEmailWithReports(
          toEmails: toEmails,
          techPdf: techPdf,
          photoPdf: photoPdf,
        ),
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Email sent successfully')),
      );

      final shouldStore = await _askStoreReportInCloud();
      if (shouldStore) await _storeReportInCloud(techPdf, photoPdf);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error sending email: $e')),
      );
    }
  }

  void _sendReportToCustomEmail(File techPdf, File photoPdf) {
    final extraEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send to another email'),
        content: TextField(
          controller: extraEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Recipient email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final extraEmail = extraEmailController.text.trim();
              Navigator.pop(ctx);
              if (!_isProbablyValidEmail(extraEmail)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid email.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              await _sendReportViaEmail(
                techPdf,
                photoPdf,
                extraEmail: extraEmail,
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    ).whenComplete(extraEmailController.dispose);
  }

  double? _calculateHfEmailPrice({required bool rushOrder}) {
    if (widget.isCommercial) {
      return calculateCommercialHfEstimatePrice(
        report: widget.report,
        rushOrder: rushOrder,
        plan: widget.plan,
      );
    }

    return calculateResidentialHfEstimatePrice(
      report: widget.report,
      rushOrder: rushOrder,
      plan: widget.plan,
    );
  }

  void _confirmRushAndSendToHfByEmail(File techPdf, File photoPdf) {
    bool rush = false;
    final rushTitle = widget.isCommercial ? 'Rush Order? (+\$25)' : 'Rush Order? (+\$15)';
    final rushText = widget.isCommercial
        ? 'Is this a rush order? (+\$25)'
        : 'Is this a rush order? (+\$15)';

    showDialog(
      context: context,
      builder: (rushDialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(rushTitle),
              content: CheckboxListTile(
                title: Text(rushText),
                value: rush,
                onChanged: (val) => setState(() => rush = val ?? false),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(rushDialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(rushDialogContext).pop();
                    _sendToHfByEmail(techPdf, photoPdf, rushOrder: rush);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendToHfByEmail(
    File techPdf,
    File photoPdf, {
    required bool rushOrder,
  }) async {
    final shouldStore = await _askStoreReportInCloud();
    if (!mounted) return;

    if (shouldStore) {
      await _storeReportInCloud(techPdf, photoPdf);
      if (!mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final total = _calculateHfEmailPrice(rushOrder: rushOrder);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Please wait… preparing checkout')),
          ],
        ),
      ),
    );

    try {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Preparing HF order... Total: \$${total?.toStringAsFixed(2) ?? 'N/A'}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      final storage = FirebaseStorage.instance;
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final techUploadTask = await storage
          .ref('temp_reports/$uid/hf_orders/$timeStamp/tech.pdf')
          .putFile(techPdf);
      final photoUploadTask = await storage
          .ref('temp_reports/$uid/hf_orders/$timeStamp/photos.pdf')
          .putFile(photoPdf);

      final techUrl = await techUploadTask.ref.getDownloadURL();
      final photoUrl = await photoUploadTask.ref.getDownloadURL();
      final callable = FirebaseFunctions.instance
          .httpsCallable('createHfEstimatesCheckoutSession');

      final result = await callable.call({
        'techPdfUrl': techUrl,
        'photoPdfUrl': photoUrl,
        'rushOrder': rushOrder,
        'isCommercial': widget.isCommercial,
        'roofSectionsCount': widget.report.commercialBuildings.fold<int>(
          0,
          (totalSections, building) => totalSections + building.roofs.length,
        ),
        'additionalBuildingsCount': widget.report.commercialBuildings.length - 1,
        'hasShed': widget.report.hasShed,
        'hasDetachedStructure': widget.report.hasDetachedStructure,
        'plan': widget.plan,
        'userEmail': FirebaseAuth.instance.currentUser?.email,
        'clientName': widget.report.clientName,
        'claimNumber': widget.report.claimNumber,
        'address': '${widget.report.address}, ${widget.report.city}, ${widget.report.state} ${widget.report.zip}',
        'dateInspected': widget.report.dateInspected,
        'report': widget.report.toHfPricingPayload(),
        'successUrl': 'claimscope://success',
        'cancelUrl': 'claimscope://cancel',
      });

      final sessionUrl = result.data['url'] as String?;
      if (sessionUrl == null) {
        throw Exception('The function did not return the Stripe URL.');
      }

      final url = Uri.parse(sessionUrl);
      final success = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!success) {
        throw Exception('Stripe Checkout could not be opened.');
      }
      widget.report.isBasePricePaid = true;
    } catch (e) {
      debugPrint('Send to HF failed: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color.fromARGB(255, 244, 54, 54),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _showSubmissionOptions(File techPdf, File photoPdf) {
    return showSubmissionOptions(
      context: context,
      techPdf: techPdf,
      photoPdf: photoPdf,
      plan: widget.plan,
      onSendToHf: _confirmRushAndSendToHfByEmail,
      onSendToMyEmail: _sendReportViaEmail,
      onSendToCustomEmail: _sendReportToCustomEmail,
      onStoreInCloud: _storeReportInCloud,
      onGenerateLabeledZip: () => generateLabeledPhotosZip(widget.report),
    );
  }

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

      await _showSubmissionOptions(pdfs['tech']!, pdfs['photos']!);
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
