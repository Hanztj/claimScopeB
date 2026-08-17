// lib/services/stripe_service.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class StripeService {
  static const MethodChannel _externalContentLinksChannel = MethodChannel(
    'com.hfestimates.claimscope/external_content_links',
  );

  /// [plan]: 'basic' | 'premium'
  /// [yearly]: false = monthly, true = annual
  static Future<void> launchCheckout(String plan, {bool yearly = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    if (plan != 'basic' && plan != 'premium') {
      throw ArgumentError.value(plan, 'plan', 'Plan no válido');
    }

    final callable =
        FirebaseFunctions.instance.httpsCallable('createCheckoutSession');

    final result = await callable.call({
      'plan': plan,
      'billingPeriod': yearly ? 'yearly' : 'monthly',
    });

    final sessionUrl = result.data['url'] as String?;
    if (sessionUrl == null) {
      throw Exception('La función no devolvió la URL de Stripe.');
    }

    final url = Uri.parse(sessionUrl);

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final launched = await _externalContentLinksChannel.invokeMethod<bool>(
          'launchExternalCheckout',
          {'url': sessionUrl},
        );

        if (launched != true) {
          throw Exception('Google Play did not launch the checkout link.');
        }
        return;
      }

      final success = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!success) {
        throw Exception('launchUrl falló al iniciar el navegador.');
      }
    } on PlatformException catch (e) {
      throw Exception(
        'Google Play could not open Stripe Checkout: ${e.message ?? e.code}',
      );
    } catch (e) {
      throw Exception('No se pudo abrir Stripe Checkout: $e');
    }
  }
}
