import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ----------------------------------------------------------------------
// FUNCIÓN CLAVE: Leer el Custom Claim del token
// ----------------------------------------------------------------------

/// Obtiene el estado actual del plan del usuario (basic, premium, anonimo).
///
/// [forceRefresh] debe ser TRUE cuando se espera un cambio de plan 
/// (ej: justo después del login, o después de un pago con Stripe).
Future<String> getUserPlanStatus({bool forceRefresh = false}) async {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    return 'anonimo'; 
  }

  try {
    // Esto hace la llamada a Firebase para obtener la información más reciente del token,
    // incluyendo el Custom Claim 'plan'.
    final idTokenResult = await user.getIdTokenResult(forceRefresh); 

    // Leer el valor del claim 'plan'
    final userPlan = idTokenResult.claims?['plan'] as String?; 
    
    // Si no hay claim de plan, no inventa un plan por defecto.
    return userPlan ?? 'free'; 
    
  } catch (e) {
    debugPrint('Error al obtener el plan del usuario: $e');
    return 'error';
  }
}

/// Reautentica al usuario, elimina su cuenta y datos remotos, y limpia los
/// archivos privados y preferencias almacenados por ClaimScope en el equipo.
Future<void> deleteCurrentUserAccount({required String password}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw FirebaseAuthException(
      code: 'no-current-user',
      message: 'No authenticated user was found.',
    );
  }

  final email = user.email;
  if (email == null || email.trim().isEmpty) {
    throw FirebaseAuthException(
      code: 'missing-email',
      message: 'The account does not have an email address.',
    );
  }

  final credential = EmailAuthProvider.credential(
    email: email.trim(),
    password: password,
  );

  await user.reauthenticateWithCredential(credential);
  await user.getIdTokenResult(true);

  final callable = FirebaseFunctions.instance.httpsCallable('deleteAccount');
  await callable.call();

  await _clearLocalAccountData();
}

Future<void> _clearLocalAccountData() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
  } catch (e) {
    debugPrint('Could not clear SharedPreferences after account deletion: $e');
  }

  try {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    await _deleteEntity(
      Directory('${documentsDirectory.path}/inspection_photos_v1'),
    );
    await _deleteGeneratedDocuments(documentsDirectory);
  } catch (e) {
    debugPrint('Could not clear ClaimScope documents: $e');
  }

  try {
    final supportDirectory = await getApplicationSupportDirectory();
    await _deleteEntity(Directory('${supportDirectory.path}/photo_cache_v4'));
  } catch (e) {
    debugPrint('Could not clear the ClaimScope photo cache: $e');
  }

  try {
    final temporaryDirectory = await getTemporaryDirectory();
    await _deleteDirectoryContents(temporaryDirectory);
  } catch (e) {
    debugPrint('Could not clear temporary ClaimScope data: $e');
  }
}

Future<void> _deleteGeneratedDocuments(Directory directory) async {
  if (!await directory.exists()) return;

  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) continue;

    final filename = entity.path.toLowerCase();
    if (filename.endsWith('.pdf') || filename.endsWith('.zip')) {
      await _deleteEntity(entity);
    }
  }
}

Future<void> _deleteDirectoryContents(Directory directory) async {
  if (!await directory.exists()) return;

  await for (final entity in directory.list(followLinks: false)) {
    await _deleteEntity(entity);
  }
}

Future<void> _deleteEntity(FileSystemEntity entity) async {
  try {
    if (await entity.exists()) {
      await entity.delete(recursive: true);
    }
  } catch (e) {
    debugPrint('Could not delete local account data at ${entity.path}: $e');
  }
}
