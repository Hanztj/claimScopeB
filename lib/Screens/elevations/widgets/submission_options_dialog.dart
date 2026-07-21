import 'dart:io';

import 'package:claimscope_clean/utils/blocking_progress_dialog.dart';
import 'package:claimscope_clean/services/stripe_service.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';


Future<void> showSubmissionOptions({
  required BuildContext context,
  required File techPdf,
  required File photoPdf,
  required String plan,
  required void Function(File tech, File photo) onSendToHf,
  required void Function(File tech, File photo) onSendToMyEmail,
  required void Function(File tech, File photo) onSendToCustomEmail,
  required Future<void> Function(File tech, File photo) onStoreInCloud,
  required Future<File> Function() onGenerateLabeledZip,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Send Inspection Report'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Send to HF Estimates by email'),
                subtitle: const Text('This will create a paid estimate order.'),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  onSendToHf(techPdf, photoPdf);
                },
              ),
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('1) Send to my email'),
                subtitle: const Text(
                  'Receive the PDF report(s) in your registered email.',
                ),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  onSendToMyEmail(techPdf, photoPdf);
                },
              ),
              const Divider(),
              if (plan == 'premium') ...[
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('2) Send to another email'),
                  subtitle: const Text('Send the reports to any email address.'),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    onSendToCustomEmail(techPdf, photoPdf);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text('Store in Cloud'),
                  subtitle: const Text(
                    'Save a copy of the report in your account (Cloud storage).',
                  ),
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    await onStoreInCloud(techPdf, photoPdf);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.folder_zip),
                  title: const Text('Download ZIP (labeled photos)'),
                  subtitle: const Text(
                    'Creates a ZIP with labeled photos (excludes gallery images).',
                  ),
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final zip = await runWithBlockingProgress<File>(
                        context: context,
                        message: 'Preparing labeled ZIP...',
                        task: onGenerateLabeledZip,
                      );
                      await Share.shareXFiles(
                        [XFile(zip.path)],
                        text: 'Inspection Photos ZIP',
                      );
                    }  catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error creating ZIP: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextButton(
                    onPressed: () => StripeService.launchCheckout('premium'),
                    child: Text(
                      'Upgrade to Premium to enable cloud storage, additional recipients and downloadable ZIP with labeled photos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}
