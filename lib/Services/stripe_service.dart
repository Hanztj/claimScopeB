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
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    var externalCheckoutPrepared = false;

    try {
      if (isAndroid) {
        final prepared = await _externalContentLinksChannel.invokeMethod<bool>(
          'prepareExternalCheckout',
        );

        if (prepared != true) {
          throw Exception('Google Play did not prepare the external checkout.');
        }
        externalCheckoutPrepared = true;
      }

      final result = await callable.call({
        'plan': plan,
        'billingPeriod': yearly ? 'yearly' : 'monthly',
      });

      final sessionUrl = result.data['url'] as String?;
      if (sessionUrl == null) {
        throw Exception('La función no devolvió la URL de Stripe.');
      }

      final url = Uri.parse(sessionUrl);

      if (isAndroid) {
        final launched = await _externalContentLinksChannel.invokeMethod<bool>(
          'launchExternalCheckout',
          {'url': sessionUrl},
        );

        if (launched != true) {
          throw Exception('Google Play did not launch the checkout link.');
        }

        externalCheckoutPrepared = false;
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
    } finally {
      if (isAndroid && externalCheckoutPrepared) {
        try {
          await _externalContentLinksChannel.invokeMethod<bool>(
            'discardExternalCheckoutPreparation',
          );
        } catch (_) {
          // Best-effort cleanup only. A new checkout always generates a new token.
        }
      }
    }
  }
}
