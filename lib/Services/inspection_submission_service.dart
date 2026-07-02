import 'dart:io';

import 'package:claimscope_clean/Screens/widgets/submission_options_dialog.dart';
import 'package:claimscope_clean/Services/email_service.dart';
import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/utils/hf_pricing_helper.dart';
import 'package:claimscope_clean/utils/labeled_photos_zip.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InspectionSubmissionService {
  const InspectionSubmissionService._();

  static Future<void> showOptions({
    required BuildContext context,
    required InspectionReport report,
    required String plan,
    required bool isCommercial,
    required File techPdf,
    required File photoPdf,
  }) {
    return showSubmissionOptions(
      context: context,
      techPdf: techPdf,
      photoPdf: photoPdf,
      plan: plan,
      onSendToHf: (tech, photo) => _confirmRushAndSendToHfByEmail(
        context: context,
        report: report,
        plan: plan,
        isCommercial: isCommercial,
        techPdf: tech,
        photoPdf: photo,
      ),
      onSendToMyEmail: (tech, photo) => _sendReportViaEmail(
        context: context,
        report: report,
        plan: plan,
        techPdf: tech,
        photoPdf: photo,
      ),
      onSendToCustomEmail: (tech, photo) => _sendReportToCustomEmail(
        context: context,
        report: report,
        plan: plan,
        techPdf: tech,
        photoPdf: photo,
      ),
      onStoreInCloud: (tech, photo) => _storeReportInCloud(
        context: context,
        report: report,
        techPdf: tech,
        photoPdf: photo,
      ),
      onGenerateLabeledZip: () => generateLabeledPhotosZip(report),
    );
  }

  static Future<T> _runWithBlockingProgress<T>(
    BuildContext context,
    String message,
    Future<T> Function() task,
  ) async {
    // CORRECCIÓN: Extraemos el Navigator antes del await.
    // Esto asegura que el diálogo siempre se cerrará, incluso si el context original muere.
    final navigator = Navigator.of(context, rootNavigator: true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
        },
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
      // Usamos el navigator guardado en lugar del context.
      navigator.pop();
    }
  }

  static Future<bool> _askStoreReportInCloud({
    required BuildContext context,
    required String plan,
  }) async {
    if (plan != 'premium') return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Store report in Cloud?'),
        content: const Text(
          'Do you want to store this inspection report in your account (Cloud)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  static Future<void> _storeReportInCloud({
    required BuildContext context,
    required InspectionReport report,
    required File techPdf,
    required File photoPdf,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
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

    try {
      // CORRECCIÓN: Reutilizamos tu método _runWithBlockingProgress para estandarizar
      // la UI de carga y evitar el manejo manual y propenso a errores del showDialog.
      await _runWithBlockingProgress<void>(
        context,
        'Storing report in Cloud...',
        () async {
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
            'claimNumber': report.claimNumber,
            'clientName': report.clientName,
            'techPath': techPath,
            'photoPath': photoPath,
          });
        },
      );

      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Report stored in Cloud.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error storing report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> _sendReportViaEmail({
    required BuildContext context,
    required InspectionReport report,
    required String plan,
    required File techPdf,
    required File photoPdf,
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
    if (plan == 'premium' &&
        extraEmail != null &&
        extraEmail.trim().isNotEmpty) {
      toEmails.add(extraEmail.trim());
    }

    try {
      await _runWithBlockingProgress<void>(
        context,
        'Sending email...',
        () => EmailService.sendEmailWithReports(
          toEmails: toEmails,
          techPdf: techPdf,
          photoPdf: photoPdf,
        ),
      );

      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Email sent successfully')),
      );

      final shouldStore = await _askStoreReportInCloud(
        context: context,
        plan: plan,
      );
      if (!context.mounted) return;

      if (shouldStore) {
        await _storeReportInCloud(
          context: context,
          report: report,
          techPdf: techPdf,
          photoPdf: photoPdf,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error sending email: $e')),
      );
    }
  }

 static void _sendReportToCustomEmail({
    required BuildContext context,
    required InspectionReport report,
    required String plan,
    required File techPdf,
    required File photoPdf,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => _CustomEmailDialog(
        report: report,
        plan: plan,
        techPdf: techPdf,
        photoPdf: photoPdf,
        // Pasamos la función de envío como callback para no perder el alcance (scope)
        onSend: (String extraEmail) async {
          if (!context.mounted) return;
          await _sendReportViaEmail(
            context: context,
            report: report,
            plan: plan,
            techPdf: techPdf,
            photoPdf: photoPdf,
            extraEmail: extraEmail,
          );
        },
      ),
    );
  }

  static double? _calculateHfEmailPrice({
    required InspectionReport report,
    required bool rushOrder,
    required String plan,
    required bool isCommercial,
  }) {
    if (isCommercial) {
      return calculateCommercialHfEstimatePrice(
        report: report,
        rushOrder: rushOrder,
        plan: plan,
      );
    }

    return calculateResidentialHfEstimatePrice(
      report: report,
      rushOrder: rushOrder,
      plan: plan,
    );
  }

  static void _confirmRushAndSendToHfByEmail({
    required BuildContext context,
    required InspectionReport report,
    required String plan,
    required bool isCommercial,
    required File techPdf,
    required File photoPdf,
  }) {
    bool rush = false;
    final hostContext = context;
    final rushTitle = isCommercial ? 'Rush Order? (+\$25)' : 'Rush Order? (+\$15)';
    final rushText = isCommercial
        ? 'Is this a rush order? (+\$25)'
        : 'Is this a rush order? (+\$15)';

    showDialog(
      context: context,
      builder: (rushDialogContext) {
        return StatefulBuilder(
          builder: (_, setState) {
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
                    _sendToHfByEmail(
                      context: hostContext,
                      report: report,
                      plan: plan,
                      isCommercial: isCommercial,
                      techPdf: techPdf,
                      photoPdf: photoPdf,
                      rushOrder: rush,
                    );
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

  static Future<void> _sendToHfByEmail({
    required BuildContext context,
    required InspectionReport report,
    required String plan,
    required bool isCommercial,
    required File techPdf,
    required File photoPdf,
    required bool rushOrder,
  }) async {
    final shouldStore = await _askStoreReportInCloud(
      context: context,
      plan: plan,
    );
    if (!context.mounted) return;

    if (shouldStore) {
      await _storeReportInCloud(
        context: context,
        report: report,
        techPdf: techPdf,
        photoPdf: photoPdf,
      );
      if (!context.mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    // CORRECCIÓN: Guardamos la instancia del rootNavigator
    final navigator = Navigator.of(context, rootNavigator: true);
    final total = _calculateHfEmailPrice(
      report: report,
      rushOrder: rushOrder,
      plan: plan,
      isCommercial: isCommercial,
    );

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
            "Preparing HF order... Total: \$${total?.toStringAsFixed(2) ?? 'N/A'}",
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }

      final storage = FirebaseStorage.instance;
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final techUploadTask = await storage
          .ref('temp_reports/${user.uid}/hf_orders/$timeStamp/tech.pdf')
          .putFile(techPdf);
      final photoUploadTask = await storage
          .ref('temp_reports/${user.uid}/hf_orders/$timeStamp/photos.pdf')
          .putFile(photoPdf);

      final techUrl = await techUploadTask.ref.getDownloadURL();
      final photoUrl = await photoUploadTask.ref.getDownloadURL();
      final callable = FirebaseFunctions.instance
          .httpsCallable('createHfEstimatesCheckoutSession');

      final roofSectionsCount = report.commercialBuildings.fold<int>(
        0,
        (totalSections, building) => totalSections + building.roofs.length,
      );
      final additionalBuildingsCount =
          report.commercialBuildings.length > 1
              ? report.commercialBuildings.length - 1
              : 0;

      final result = await callable.call({
        'techPdfUrl': techUrl,
        'photoPdfUrl': photoUrl,
        'rushOrder': rushOrder,
        'isCommercial': isCommercial,
        'roofSectionsCount': roofSectionsCount,
        'additionalBuildingsCount': additionalBuildingsCount,
        'hasShed': report.hasShed,
        'hasDetachedStructure': report.hasDetachedStructure,
        'plan': plan,
        'userEmail': user.email,
        'clientName': report.clientName,
        'claimNumber': report.claimNumber,
        'address': '${report.address}, ${report.city}, ${report.state} ${report.zip}',
        'dateInspected': report.dateInspected,
        'report': report.toHfPricingPayload(),
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
      report.isBasePricePaid = true;
    } catch (e) {
      debugPrint('Send to HF failed: $e');
      // No necesitamos verificar context.mounted porque estamos usando un messenger ya cacheado
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: const Color.fromARGB(255, 244, 54, 54),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      // CORRECCIÓN: Usamos el navigator cacheado, lo que asegura que el loader siempre desaparezca
      navigator.pop();
    }
  }
}
class _CustomEmailDialog extends StatefulWidget {
  final InspectionReport report;
  final String plan;
  final File techPdf;
  final File photoPdf;
  final Future<void> Function(String) onSend;

  const _CustomEmailDialog({
    required this.report,
    required this.plan,
    required this.techPdf,
    required this.photoPdf,
    required this.onSend,
  });

  @override
  State<_CustomEmailDialog> createState() => _CustomEmailDialogState();
}

class _CustomEmailDialogState extends State<_CustomEmailDialog> {
  late final TextEditingController _extraEmailController;

  @override
  void initState() {
    super.initState();
    _extraEmailController = TextEditingController();
  }

  @override
  void dispose() {
    // Ahora el dispose se maneja de forma segura por el ciclo de vida del widget
    _extraEmailController.dispose();
    super.dispose();
  }

  // Asumo que esta función ya la tienes en tu archivo, la copio aquí para referencia
  bool _isProbablyValidEmail(String email) {
    final RegExp emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send to another email'),
      content: TextField(
        controller: _extraEmailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Recipient email'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final extraEmail = _extraEmailController.text.trim();

            if (!_isProbablyValidEmail(extraEmail)) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid email.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Primero cerramos el diálogo y dejamos que termine su animación
            if (mounted) {
              Navigator.of(context).pop();
            }

            // Luego ejecutamos la lógica de envío llamando al callback
            await widget.onSend(extraEmail);
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}