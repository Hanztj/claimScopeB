import 'package:claimscope_clean/inspection_setup_screen.dart';
import 'package:claimscope_clean/screens/subscription_gate_screen.dart';
import 'package:claimscope_clean/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

    // Keep decoded image thumbnails from growing without bounds on long inspections.
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 80;
  imageCache.maximumSizeBytes = 40 * 1024 * 1024;
  
  await Firebase.initializeApp();
  debugPrint("Firebase inicializado correctamente");
  runApp(const MyApp());
}

// main.dart global key for ScaffoldMessenger
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final ValueNotifier<int> authRefresh = ValueNotifier(0);

// Nuevo código en main.dart (o en un archivo wrapper.dart)

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: authRefresh,
      builder: (context, _, __) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final user = snapshot.data;

            // 1️⃣ No logueado
            if (user == null) {
              return const AuthScreen();
            }

            // 2️⃣ Logueado pero no verificado
            if (!user.emailVerified) {
              return const EmailVerificationPendingScreen();
            }

            // 3️⃣ Logueado + verificado → ver plan
            return FutureBuilder<IdTokenResult>(
              future: user.getIdTokenResult(true),
              builder: (context, tokenSnapshot) {
                if (tokenSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final plan =
                    tokenSnapshot.data?.claims?['plan'] as String?;

                if (plan == 'premium' || plan == 'basic') {
                  return InspectionSetupScreen(plan: plan!);
                } else {
                  return const SubscriptionGateScreen();
                }
              },
            );
          },
        );
      },
    );
  }
}

/// ---------------- PANTALLA DE ESPERA (NUEVA) ----------------
class EmailVerificationPendingScreen extends StatefulWidget {
  const EmailVerificationPendingScreen({super.key});

  @override
  State<EmailVerificationPendingScreen> createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends State<EmailVerificationPendingScreen> {
  bool _resending = false;

  Future<void> _resendLink() async {
    if (_resending) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _resending = true);
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("Verification link sent. Please check your inbox."),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'too-many-requests'
          ? "Too many requests. Please wait a moment and try again."
          : "Could not resend link: ${e.message ?? e.code}";
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text("Unexpected error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mail_lock, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                "Verify your email",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text(
                "You're logged in, but we need you to click the link in your email.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // 1️⃣ BOTÓN "I ALREADY VERIFIED IT"
              ElevatedButton(
                onPressed: () async {
                  final userBefore = FirebaseAuth.instance.currentUser;
                  if (userBefore == null) return;
                  await userBefore.reload();
                  final userAfter = FirebaseAuth.instance.currentUser;
                  if (userAfter != null && userAfter.emailVerified) {
                    authRefresh.value++;
                  } else {
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Email not verified yet. Please check your inbox.",
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: const Text("I already verified it"),
              ),
              const SizedBox(height: 8),

              // 2️⃣ BOTÓN "RESEND LINK"
              OutlinedButton.icon(
                onPressed: _resending ? null : _resendLink,
                icon: _resending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_resending ? "Sending..." : "Resend Link"),
              ),

              // 3️⃣ BOTÓN "SIGN OUT"
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text(
                  "Sign Out / Use another email",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(scaffoldMessengerKey: scaffoldMessengerKey, // ⭐️ AÑADE ESTO
      debugShowCheckedModeBanner: false,
      title: 'Insurance Inspection',
      theme: appTheme, 
      home: const AuthGate(),
     
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscureText = true;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

// ---------------- LOGIN ----------------
void signIn() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // 1. Solo hacemos el login. 
      // 2. El AuthGate decidirá si mandarlo a la App o a la pantalla de espera.
      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      
      // Forzamos un reload rápido para capturar el estado del email
      await _auth.currentUser?.reload();

    } on FirebaseAuthException catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed'), backgroundColor: Colors.red),
      );
    }
  }
  // ---------------- REGISTER ----------------
void register() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await userCredential.user?.sendEmailVerification();
      
      // NO hacemos signOut(). 
      // Dejamos que el AuthGate lo mande a la pantalla de espera.
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text("Account created. Check your email!"), backgroundColor: Colors.green),
      );

    } on FirebaseAuthException catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Registration failed'), backgroundColor: Colors.red),
      );
    }
  }
  // ---------------- RESET PASSWORD ----------------
  void resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reset email sent."), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
      );
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Authentication')),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: emailController, 
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: passwordController,
                obscureText: _obscureText, // Variable para alternar visibilidad
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: signIn, child: const Text('Login')),
              ElevatedButton(onPressed: register, child: const Text('Sign up')),
              TextButton(onPressed: resetPassword, child: const Text('Forgot my password')),
              const SizedBox(height: 30),
                 ],
          ),
        ),
      ),
    ),
  );
}}



