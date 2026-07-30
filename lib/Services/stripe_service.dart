// lib/services/stripe_service.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class StripeService {
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
      final success = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!success) {
        throw Exception('launchUrl falló al iniciar el navegador.');
      }
    } catch (e) {
      throw Exception('No se pudo abrir Stripe Checkout: $e');
    }
  }
}
