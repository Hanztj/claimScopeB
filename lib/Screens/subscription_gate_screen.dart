// lib/screens/subscription_gate_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:claimscope_clean/services/stripe_service.dart';
import 'package:claimscope_clean/inspection_setup_screen.dart';
import '../theme.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();


class SubscriptionGateScreen extends StatefulWidget {
  const SubscriptionGateScreen({super.key});

  @override
  State<SubscriptionGateScreen> createState() =>
      _SubscriptionGateScreenState();
}

class _SubscriptionGateScreenState extends State<SubscriptionGateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String? userPlan;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _checkUserPlan();
  }

  Future<void> _checkUserPlan() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (mounted) Navigator.of(context).pop();
    return;
  }

  try {
    await user.reload();
    final token = await user.getIdTokenResult();
    final plan = token.claims?['plan'] as String?;

    if (!mounted) return;

    setState(() {
      userPlan = plan ?? 'free';
      loading = false;
    });

    _controller.forward();

    if (userPlan != 'free' && mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              InspectionSetupScreen(plan: userPlan!),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
        ),
      );
    }
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;

    if (e.code == 'too-many-requests') {
      loading = false;
      setState(() {});
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Too many requests to Firebase. Please wait a moment and try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error checking subscription: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Unexpected error checking plan: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.mainColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              children: [
                // Icono de la app en lugar de Icons.shield
                Image.asset(
                  'assets/Icon/logo.png', // <-- ajusta esta ruta a tu logo real
                  height: 70,
                ),
                const SizedBox(height: 16),
                Text(
                  "Choose your plan",
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  "Professional tools for insurance inspections",
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _PlanCard(
                          title: "Basic",
                          price: "\$9.99",
                          period: "/month",
                          features: const [
                            "Unlimited inspections",
                            "Send PDFs via e-mail",
                            "Send projects to HF Estimates (10% off)",
                          ],
                          color: AppColors.mainColor,
                          onTap: () =>
                              StripeService.launchCheckout('basic'),
                        ),
                        const SizedBox(height: 16),
                        _PlanCard(
                          title: "Premium",
                          price: "\$29.99",
                          period: "/month",
                          isPopular: true,
                          features: const [
                            "Everything in Basic + (15% off)",
                            "60 days of free storage for all inspections",
                            "Assignments via XactAnalysis to HF Estimates",
                            "Assignments to any XactNet account",
                          ],
                          color: AppColors.darkBlue,
                          textColor: Colors.white,
                          onTap: () =>
                              StripeService.launchCheckout('premium'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Try for free 7 days · Cancel anytime",
                  style: TextStyle(
                    color: AppColors.darkGray,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);

                    await FirebaseAuth.instance.signOut();
                    if (!mounted) return;

                    navigator.popUntil((route) => route.isFirst);
                  },
                  child: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final List<String> features;
  final Color color;
  final Color? textColor;
  final bool isPopular;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.color,
    this.textColor,
    this.isPopular = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: const Color.fromARGB(77, 255, 255, 255),
        highlightColor: const Color.fromARGB(26, 255, 255, 255),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: isPopular
                ? Border.all(color: AppColors.mainColor, width: 3)
                : null,
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(20, 0, 0, 0),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mainColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "MOST POPULAR",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (isPopular) const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$price$period",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: textColor ?? Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...features.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: textColor ?? Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor ?? Colors.white,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Start now",
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

