import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EmailService {
  static Future<void> sendEmailWithReports({
    String? extraEmail,
    required File techPdf,
    required File photoPdf,
  }) async {
    try {
      final storage = FirebaseStorage.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final uid = user.uid;

      final techUpload = await storage
          .ref('temp_reports/$uid/$timestamp/tech.pdf')
          .putFile(techPdf);
      final photoUpload = await storage
          .ref('temp_reports/$uid/$timestamp/photos.pdf')
          .putFile(photoPdf);

      final techUrl = await techUpload.ref.getDownloadURL();
      final photoUrl = await photoUpload.ref.getDownloadURL();
      final techFilename = techPdf.uri.pathSegments.last;
      final photoFilename = photoPdf.uri.pathSegments.last;

      final callable =
          FirebaseFunctions.instance.httpsCallable('sendInspectionEmail');

      await callable.call({
        'extraEmail': extraEmail?.trim(),
        'techPdfUrl': techUrl,
        'photoPdfUrl': photoUrl,
        'techFilename': techFilename,
        'photoFilename': photoFilename,
      });
    } catch (e) {
      throw Exception('Error en EmailService: $e');
    }
  }
}
