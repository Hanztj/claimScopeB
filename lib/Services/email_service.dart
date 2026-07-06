
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import  'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
class EmailService {
  static Future<void> sendEmailWithReports({
    required List<String> toEmails,
    required File techPdf,
    required File photoPdf,
  }) async {
    try {
      final storage = FirebaseStorage.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final uid = user.uid;
      
      // 1. Subir archivos a Storage para obtener una URL pública
      // Usamos el nombre del archivo y un timestamp para evitar duplicados
      TaskSnapshot techUpload = await storage
          .ref('temp_reports/$uid/$timestamp/tech.pdf')
          .putFile(techPdf);
      TaskSnapshot photoUpload = await storage
          .ref('temp_reports/$uid/$timestamp/photos.pdf')
          .putFile(photoPdf);

      String techUrl = await techUpload.ref.getDownloadURL();
      String photoUrl = await photoUpload.ref.getDownloadURL();
      final techFilename = techPdf.uri.pathSegments.last;
      final photoFilename = photoPdf.uri.pathSegments.last;

      // 2. Llamar a la Cloud Function pasando las URLs
      final HttpsCallable callable = FirebaseFunctions.instance
          .httpsCallable('sendInspectionEmail');

        await callable.call({
        'toEmails': toEmails,
        'techPdfUrl': techUrl,
        'photoPdfUrl': photoUrl,
        'techFilename': techFilename,
        'photoFilename': photoFilename
      });
    } catch (e) {
      throw Exception("Error en EmailService: $e");
    }
  }
}
