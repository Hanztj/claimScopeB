// lib/services/stripe_service.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class StripeService {
  // === Stripe Price IDs (Nov 2026 refresh) ===
  // Basic
  static const String _priceBasicMonthly = 'price_1TuUwQIV8TkU9SxHrb9ieW5i';
  static const String _priceBasicYearly  = 'price_1TuUwuIV8TkU9SxHqloMd4cx';
  // Premium
  static const String _pricePremiumMonthly = 'price_1TuV4BIV8TkU9SxHdeD5Z1Y2';
  static const String _pricePremiumYearly  = 'price_1TuV4cIV8TkU9SxHvtciIczy';

  static String _resolvePriceId(String plan, bool yearly) {
    final isPremium = plan == 'premium';
    if (isPremium) {
      return yearly ? _pricePremiumYearly : _pricePremiumMonthly;
    }
    return yearly ? _priceBasicYearly : _priceBasicMonthly;
  }

  /// [plan]: 'basic' | 'premium'
  /// [yearly]: false = monthly, true = annual
  static Future<void> launchCheckout(String plan, {bool yearly = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Usuario no autenticado");

    final callable =
        FirebaseFunctions.instance.httpsCallable('createCheckoutSession');

    final result = await callable.call({
      'priceId': _resolvePriceId(plan, yearly),
      'successUrl': 'claimscope://success',
      'cancelUrl': 'claimscope://cancel',
    });

    final sessionUrl = result.data['url'] as String?;
    if (sessionUrl == null) {
      throw Exception("La función no devolvió la URL de Stripe.");
    }

    final url = Uri.parse(sessionUrl);

    try {
      final success = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!success) {
        throw Exception("launchUrl falló al iniciar el navegador.");
      }
    } catch (e) {
      throw Exception("No se pudo abrir Stripe Checkout: $e");
    }
  }
}
