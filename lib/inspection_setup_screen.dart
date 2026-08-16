import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/roof_inspection_form.dart';
import 'package:claimscope_clean/screens/commercial_buildings_screen.dart';
import 'package:claimscope_clean/screens/elevations/elevations_inspection_screen.dart';
import 'package:claimscope_clean/screens/my_reports_screen.dart';
import 'package:claimscope_clean/services/auth_plan_service.dart';
import 'package:claimscope_clean/services/stripe_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

final List<String> usStates = [
  'Alabama',
  'Alaska',
  'Arizona',
  'Arkansas',
  'California',
  'Colorado',
  'Connecticut',
  'Delaware',
  'Florida',
  'Georgia',
  'Hawaii',
  'Idaho',
  'Illinois',
  'Indiana',
  'Iowa',
  'Kansas',
  'Kentucky',
  'Louisiana',
  'Maine',
  'Maryland',
  'Massachusetts',
  'Michigan',
  'Minnesota',
  'Mississippi',
  'Missouri',
  'Montana',
  'Nebraska',
  'Nevada',
  'New Hampshire',
  'New Jersey',
  'New Mexico',
  'New York',
  'North Carolina',
  'North Dakota',
  'Ohio',
  'Oklahoma',
  'Oregon',
  'Pennsylvania',
  'Rhode Island',
  'South Carolina',
  'South Dakota',
  'Tennessee',
  'Texas',
  'Utah',
  'Vermont',
  'Virginia',
  'Washington',
  'West Virginia',
  'Wisconsin',
  'Wyoming'
];

class InspectionSetupScreen extends StatefulWidget {
  final String plan; // 'basic' o 'premium'

  const InspectionSetupScreen({super.key, required this.plan});

  @override
  State<InspectionSetupScreen> createState() => _InspectionSetupScreenState();
}

class _InspectionSetupScreenState extends State<InspectionSetupScreen> {
  static final Uri _privacyPolicyUri = Uri.parse(
    'https://www.hfestimates.com/claimscope-roof-inspection-app/privacy-policy/',
  );

  Future<void> _openPrivacyPolicy() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final opened = await launchUrl(
        _privacyPolicyUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Privacy Policy could not be opened.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Privacy Policy could not be opened.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSubscriptionAndNavigate(InspectionReport report) async {
    try {
      final plan = await getUserPlanStatus(forceRefresh: true);

      if (!mounted) return;

      if (plan != 'basic' && plan != 'premium') {
        throw Exception('The plan status could not be determined.');
      }

      final normalizedPlan = plan;

if (!inspectRoof) {
  if (report.inspectElevations) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ElevationsInspectionScreen(
          report: report,
          isCommercial: !isResidential,
          plan: normalizedPlan,
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select at least one inspection module.'),
      ),
    );
  }
  return;
}

      if (isResidential) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoofInspectionForm(
              plan: normalizedPlan,
              isCommercial: false,
              report: report,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommercialBuildingsScreen(
              plan: normalizedPlan,
              report: report,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying plan: $e')),
      );
    } 
  }

  bool isResidential = true;
  bool inspectRoof = true;
  bool inspectElevations = false;

  String? _typeOfLoss;

  final _formKey = GlobalKey<FormState>();

  final clientName = TextEditingController();
  final clientPhone = TextEditingController();
  final clientEmail = TextEditingController();
  final street = TextEditingController();
  final city = TextEditingController();
  final state = TextEditingController();
  final zip = TextEditingController();
  final claimNumber = TextEditingController();
  final policyNumber = TextEditingController();

  final dateOfLoss = TextEditingController();
  final dateInspected = TextEditingController();

  final company = TextEditingController();
  final personName = TextEditingController();
  final personPhone = TextEditingController();
  final personEmail = TextEditingController();

  final causeOfLossController = TextEditingController();
  final insuranceCompanyController = TextEditingController();

  void _proceedToInspection() {
    if (_formKey.currentState!.validate()) {
      final report = InspectionReport();

      report.clientName = clientName.text;
      report.clientPhone = clientPhone.text;
      report.email = clientEmail.text;

      report.address = street.text;
      report.city = city.text;
      report.state = state.text;
      report.zip = zip.text;

      report.claimNumber = claimNumber.text;
      report.policyNumber = policyNumber.text;

      report.dateOfLoss = dateOfLoss.text;
      report.dateInspected = dateInspected.text;

      report.insuranceCompany = insuranceCompanyController.text;
      report.typeOfLoss = _typeOfLoss ?? '';
      report.causeOfLoss = causeOfLossController.text;

      report.isResidential = isResidential;

      report.inspectorCompany = company.text;
      report.inspectorName = personName.text;
      report.inspectorPhone = personPhone.text;
      report.inspectorEmail = personEmail.text;

      report.inspectRoof = inspectRoof;
      report.inspectElevations = inspectElevations;

      _handleSubscriptionAndNavigate(report);
    }
  }

  final phoneRegex = RegExp(r'^\+?\d{7,15}');
  final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$");

  final List<String> lossTypes = [
    'Wind',
    'Hail',
    'Wind/Hail',
    'Windstorm',
    'Hurricane',
    'Fire',
    'Earthquake',
    'Freeze',
    'Ice Or Snow',
    'Lightning',
    'Tornado',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    dateInspected.text = DateFormat('MM/dd/yyyy').format(DateTime.now());
  }

  @override
  void dispose() {
    clientName.dispose();
    clientPhone.dispose();
    clientEmail.dispose();
    street.dispose();
    city.dispose();
    state.dispose();
    zip.dispose();
    claimNumber.dispose();
    policyNumber.dispose();
    dateOfLoss.dispose();
    dateInspected.dispose();
    company.dispose();
    personName.dispose();
    personPhone.dispose();
    personEmail.dispose();
    causeOfLossController.dispose();
    insuranceCompanyController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        var obscurePassword = true;
        var isDeleting = false;
        String? passwordError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> deleteAccount() async {
              final password = passwordController.text;
              if (password.isEmpty) {
                setDialogState(() {
                  passwordError = 'Enter your password to confirm.';
                });
                return;
              }

              setDialogState(() {
                isDeleting = true;
                passwordError = null;
              });

              try {
                await deleteCurrentUserAccount(password: password);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                await FirebaseAuth.instance.signOut();

                if (!mounted) return;
                rootNavigator.popUntil((route) => route.isFirst);
              } on FirebaseAuthException catch (e) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  isDeleting = false;
                  if (e.code == 'wrong-password' ||
                      e.code == 'invalid-credential') {
                    passwordError = 'Incorrect password.';
                  } else if (e.code == 'too-many-requests') {
                    passwordError =
                        'Too many attempts. Please try again later.';
                  } else {
                    passwordError =
                        'Authentication failed. Please try again.';
                  }
                });
              } on FirebaseFunctionsException {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  isDeleting = false;
                  passwordError =
                      'Account deletion failed. Please try again.';
                });
              } catch (_) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  isDeleting = false;
                  passwordError =
                      'Account deletion failed. Please try again.';
                });
              }
            }

            return AlertDialog(
              title: const Text('Delete account?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will permanently delete your account, stored inspections, and saved payment information, and cancel any active subscription. This action cannot be undone.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    enabled: !isDeleting,
                    obscureText: obscurePassword,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password to confirm.',
                      errorText: passwordError,
                      suffixIcon: IconButton(
                        onPressed: isDeleting
                            ? null
                            : () {
                                setDialogState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    onSubmitted: isDeleting ? null : (_) => deleteAccount(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isDeleting ? null : deleteAccount,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: isDeleting
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Deleting account...'),
                          ],
                        )
                      : const Text('Delete Account'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBasic = widget.plan == 'basic';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Setup'),
        actions: [
          if (isBasic)
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await StripeService.launchCheckout('premium');
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Stripe Checkout could not be opened: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text(
                'Upgrade',
                style: TextStyle(color: Colors.white),
              ),
            ),
          // My Reports — refresca claims por si Stripe acaba de upgradear
          FutureBuilder<IdTokenResult?>(
            future: FirebaseAuth.instance.currentUser?.getIdTokenResult(true),
            builder: (context, snap) {
              final claimPlan = snap.data?.claims?['plan'] as String?;
              final isPremium = (claimPlan ?? widget.plan) == 'premium';
              if (!isPremium) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'My Reports',
                icon: const Icon(Icons.folder_open),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyReportsScreen()),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.privacy_tip_outlined),
            tooltip: 'Privacy Policy',
            onPressed: _openPrivacyPolicy,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined),
            tooltip: 'Delete Account',
            onPressed: _showDeleteAccountDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final rootNav = Navigator.of(context, rootNavigator: true);
              final confirm = await showDialog<bool>(
                context: context,
                useRootNavigator: true,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('LOGOUT')),
                  ],
                ),
              ) ?? false;
              if (!confirm) return;
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              rootNav.popUntil((route) => route.isFirst);
            },
          ),

        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: isResidential,
                    onChanged: (_) => setState(() => isResidential = true),
                  ),
                  const Text('Residential'),
                  const SizedBox(width: 20),
                  Checkbox(
                    value: !isResidential,
                    onChanged: (_) => setState(() => isResidential = false),
                  ),
                  const Text('Commercial'),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Client Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextFormField(
                controller: clientName,
                decoration: const InputDecoration(labelText: 'Client Name *'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: clientPhone,
                decoration: const InputDecoration(labelText: 'Client Phone *'),
                keyboardType: TextInputType.phone,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Client Phone is required';
                  }
                  if (!phoneRegex.hasMatch(v)) {
                    return 'Invalid phone number format';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: clientEmail,
                decoration: const InputDecoration(labelText: 'Client Email'),
                keyboardType: TextInputType.emailAddress,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    if (!emailRegex.hasMatch(v)) {
                      return 'Invalid email format';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Property Address:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextFormField(
                controller: street,
                decoration: const InputDecoration(labelText: 'Street Address *'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: city,
                decoration: const InputDecoration(labelText: 'City *'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              Autocomplete<String>(
              
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                return usStates.where((String option) {
                  return option
                      .toLowerCase()
                      .startsWith(textEditingValue.text.toLowerCase());
                });
              },
              fieldViewBuilder:
                  (context, textEditingController, focusNode, onFieldSubmitted) {
                textEditingController.text = state.text;
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                  label: RichText(
                   text: const TextSpan(
                    text: 'State',
                     style: TextStyle(fontSize: 16, color: Colors.black),
                       children: [TextSpan(text: ' *', style: TextStyle(color: Colors.orange))],
                         ),
                        ),
                 ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'State is required';
                    }
                    if (!usStates.contains(value)) {
                      return 'Please select a valid US state';
                    }
                    return null;
                  },
                  onChanged: (val) {
                    state.text = val;
                  },
                );
              },
              onSelected: (String selection) {
                state.text = selection;
              },
            ),
              TextFormField(
                controller: zip,
                decoration: const InputDecoration(labelText: 'Zip Code *'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Required';
                  if (value.length < 5) return 'Zip Code must be at least 5 digits';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Claim Information:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextFormField(
                controller: claimNumber,
                decoration: const InputDecoration(labelText: 'Claim Number'),
              ),
              TextFormField(
                controller: policyNumber,
                decoration: const InputDecoration(labelText: 'Policy Number'),
              ),
              TextFormField(
                controller: insuranceCompanyController,
                decoration: const InputDecoration(labelText: 'Insurance Company'),
              ),
              TextFormField(
                controller: dateOfLoss,
                decoration: InputDecoration(
                  labelText: 'Date of Loss *',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context, dateOfLoss),
                  ),
                ),
                readOnly: true,
                validator: (v) => v!.isEmpty ? 'Date of Loss is required' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _typeOfLoss,
                decoration: const InputDecoration(labelText: 'Type of Loss *'),
                hint: const Text('Select Type of Loss'),
                items: lossTypes
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (newValue) {
                  setState(() {
                    _typeOfLoss = newValue;
                  });
                },
                validator: (v) => v == null ? 'Type of Loss is required' : null,
              ),
              TextFormField(
                controller: causeOfLossController,
                decoration: const InputDecoration(
                  labelText: 'Cause of Loss (Comments)',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 20),
              const Text(
                'Personal Info:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextFormField(
                controller: company,
                decoration: const InputDecoration(labelText: 'Company'),
              ),
              TextFormField(
                controller: personName,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextFormField(
                controller: personPhone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    if (!phoneRegex.hasMatch(v)) {
                      return 'Invalid phone number format';
                    }
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: personEmail,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    if (!emailRegex.hasMatch(v)) {
                      return 'Invalid email format';
                    }
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: dateInspected,
                decoration: InputDecoration(
                  labelText: 'Date Inspected',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context, dateInspected),
                  ),
                ),
                readOnly: true,
                validator: (v) => v!.isEmpty ? 'Date Inspected is required' : null,
              ),
              const SizedBox(height: 20),
              const Text(
                'Inspection of:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                title: const Text('Roof Section'),
                value: inspectRoof,
                onChanged: (v) => setState(() => inspectRoof = v ?? false),
              ),
              CheckboxListTile(
                title: const Text('Elevations'),
                value: inspectElevations,
                onChanged: (v) => setState(() => inspectElevations = v ?? false),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final currentUser = FirebaseAuth.instance.currentUser;

                    if (currentUser == null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error: User not authenticated.'),
                        ),
                      );
                      return;
                    }

                    if (!_formKey.currentState!.validate()) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please correct the errors in the form.'),
                        ),
                      );
                      return;
                    }

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Checking subscription status...'),
                      ),
                    );

                    _proceedToInspection();
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
