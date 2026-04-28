import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:claimscope_clean/services/stripe_service.dart';
import 'package:claimscope_clean/Services/pdf_service.dart';
//firebase imports here
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:claimscope_clean/Services/email_service.dart';
import 'package:claimscope_clean/inspection_report_model.dart';
//ignore unused imports for now, will be used in the future when implementing the functions
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:claimscope_clean/screens/my_reports_screen.dart';
 // Para ArchiveFile y ZipEncoder
import 'package:path_provider/path_provider.dart'; // Para getApplicationDocumentsDirectory
import 'package:share_plus/share_plus.dart'; // Para Share y XFile
import 'package:claimscope_clean/utils/labeled_photos_zip.dart';
import 'package:claimscope_clean/catalogs/roof_catalog.dart';
import 'package:claimscope_clean/catalogs/roof_components_catalog.dart';
import 'package:claimscope_clean/screens/residential/hubs/residential_shingles_hub.dart';
import 'package:claimscope_clean/screens/residential/hubs/residential_roof_accessories_hub.dart';
import 'package:claimscope_clean/screens/residential/hubs/residential_facet_inspection_hub.dart';
import 'package:claimscope_clean/catalogs/flashing_catalog.dart';



enum FacetOrientation {
  north,
  south,
  east,
  west, 
  none, // Para cuando no se ha seleccionado ninguna
}
class RoofInspectionForm extends StatefulWidget {
  
  final String plan; // Cambiado de bool isSubscribed
  final InspectionReport report;
  final bool isCommercial; // Para diferenciar residencial/comercial en cálculos y opciones


  const RoofInspectionForm({super.key, required this.plan, required this.report, required this.isCommercial});

  @override
  State<RoofInspectionForm> createState() => _RoofInspectionFormState();
}

class _RoofInspectionFormState extends State<RoofInspectionForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
                    
 // Añadir dentro de class _RoofInspectionFormState extends State<RoofInspectionForm> {

 void _showSubmissionOptions(File techPdf, File photoPdf) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Send Inspection Report'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
                            
               //Option 1: Send to HF Estimates via email (Basic and Premium) – this option WILL charge a fee
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Send to HF Estimates by email'),
                subtitle: const Text(
                  'This will create a paid estimate Order',
                ),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _confirmRushAndSendToHfByEmail(techPdf, photoPdf);
                },
              ),

              //Option 2 send to registered email (Basic and Premium) – this option is free

              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('1) Send to my email'),
                subtitle: const Text(
                  'Receive the PDF report(s) in your registered email.',
                ),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _sendReportViaEmail(techPdf, photoPdf);
                },
              ),

                 // Additional options for Premium users

              const Divider(),
              if (widget.plan == 'premium') ...[
                // sent to custom email (without HF fee)
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('2) Send to another email'),
                  subtitle: const Text(
                    'Send the reports to any email address.',
                  ),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _sendReportToCustomEmail(techPdf, photoPdf);
                  },
                ),

                // Store in Cloud (without HF fee)

                  const Divider(),
                  if (widget.plan == 'premium')
                ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text(
                    'Store in Cloud',
                  ),
                  subtitle: const Text(
                    'Save a copy of the report in your account (Cloud storage).',
                  ),
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    await _storeReportInCloud(techPdf, photoPdf);
                  },
                ),
             
                   // Download ZIP with labeled photos (without HF fee)

    const Divider(),
                        if (widget.plan == 'premium')
                     ListTile(
                     leading: const Icon(Icons.folder_zip),
                     title: const Text('Download ZIP (labeled photos)'),
                     subtitle: const Text('Creates a ZIP with labeled photos (excludes gallery images).'),
                      onTap: () async {
                      Navigator.of(dialogContext).pop();

                      final messenger = ScaffoldMessenger.of(context);
                      
                      final zip = await _generateLabeledPhotosZip();
                        if (!mounted) return;
                      await Share.shareXFiles([XFile(zip.path)], text: 'Inspection Photos ZIP');
                     try {
                     final zip = await _generateLabeledPhotosZip();
                     if (!mounted) return;

                     messenger.showSnackBar(
                     SnackBar(content: Text('ZIP created: ${zip.path}')),
                      );
                      } catch (e) {
                      if (!mounted) return;

                    messenger.showSnackBar(
                      SnackBar(
                     content: Text('Error creating ZIP: $e'),
                     backgroundColor: Colors.red,
                    ),
                    );
                     }
                      },
                    ),
                      
             
              ] 
                else
                Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextButton(
                 onPressed: () {
                 // No necesitamos await aquí; solo disparamos el checkout de Premium
                 StripeService.launchCheckout('premium');
               },
                child: Text(
                   'Upgrade to Premium to enable cloud storage,additional recipients and Downloadable ZIP with labeled photos',
                   textAlign: TextAlign.center,
                   style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                  ),
                  ),
                  ),
             
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      );
    },
  );
 }
                 
Widget _buildFlashingSubfields(Map<String, dynamic> data) {
  final String? type = data['type'];

  if (type == null) return const SizedBox.shrink();

  final fields = flashingFieldsForResidentialType(type);
  if (fields.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: fields.map((field) {
      return buildDropdown(
        field.label,
        field.options,
        data[field.key],
        (val) => setState(() => data[field.key] = val),
      );
    }).toList(),
  );
}
     
 // Paso adicional: preguntar por Rush Order ANTES de calcular precio / cobrar / enviar
 void _confirmRushAndSendToHfByEmail(File techPdf, File photoPdf) {
  bool rush = false;

  showDialog(
    context: context,
    builder: (rushDialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Rush Order? (+\$15)'),
            content: CheckboxListTile(
              title: const Text('Is this a rush order? (+\$15)'),
              value: rush,
              onChanged: (val) {
                setState(() {
                  rush = val ?? false;
                });
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(rushDialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(rushDialogContext).pop();
   
                  _sendToHfByEmail(techPdf, photoPdf, rushOrder: rush);
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    },
  );
 } 


 // Function helper email 
  bool _isProbablyValidEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return false;
  if (email.contains(' ')) return false;

  final at = email.indexOf('@');
  if (at <= 0) return false; // no puede empezar con @
  if (at != email.lastIndexOf('@')) return false; // solo un @

  final dot = email.lastIndexOf('.');
  if (dot <= at + 1) return false; // debe haber un . después del @
  if (dot == email.length - 1) return false; // no termina con .

  return true;
}

// here was te fucntions _sanitizedPhotoBaseName and _generateLabeledPhotosZip, moved to utils/labeled_photos_zip.dart
String _sanitizeFilename(String input) {
  var s = input.trim();
  if (s.isEmpty) return 'UNKNOWN';
  s = s.replaceAll(RegExp(r'[\/\\\:\*\?\"\<\>\|]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.isEmpty ? 'UNKNOWN' : s;
}

Future<File> _generateLabeledPhotosZip() async {
  // Excluir imágenes de galería (se agregan como label 'User Image')
  final items = widget.report.photoReportItems.where((p) {
    return p.label.trim() != 'User Image';
  }).toList();

  final archive = buildLabeledPhotosArchive(items);
  final zipBytes = encodeZipBytes(archive);

  final claim = widget.report.claimNumber.trim().isEmpty
      ? 'NOCLAIM'
      : _sanitizeFilename(widget.report.claimNumber);

  final insured = widget.report.clientName.trim().isEmpty
      ? 'UNKNOWN'
      : _sanitizeFilename(widget.report.clientName);

  final dir = await getApplicationDocumentsDirectory();
  final filename = '$claim - $insured - Inspection Photos (ZIP).zip';

  final zipFile = await writeZipToFile(
    zipBytes: zipBytes,
    outputDir: dir,
    filename: filename,
  );

  return zipFile;
}

 // Solo Premium+Extra : preguntar si quiere almacenar en la nube (sin cobro HF)

Future<bool> _askStoreReportInCloud() async {
  if (widget.plan != 'premium') return false;

  final navigator = Navigator.of(context);

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Store report in Cloud?'),
      content: const Text(
        'Do you want to store this inspection report in your account (Cloud)?',
      ),
      actions: [
        TextButton(
          onPressed: () => navigator.pop(false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => navigator.pop(true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );

  return result ?? false;
}
Future<void> _storeReportInCloud(File techPdf, File photoPdf) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('User not authenticated.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 16),
          Expanded(child: Text('Storing report in Cloud...')),
        ],
      ),
    ),
  );

  try {
    final firestore = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;

    final reportRef = firestore
        .collection('users')
        .doc(user.uid)
        .collection('inspectionReports')
        .doc(); // doc().id generado

    final reportId = reportRef.id;
    final techFilename = techPdf.uri.pathSegments.last;
    final photoFilename = photoPdf.uri.pathSegments.last;

    final techPath = 'user_reports/${user.uid}/$reportId/$techFilename';
    final photoPath = 'user_reports/${user.uid}/$reportId/$photoFilename';

    await storage.ref(techPath).putFile(techPdf);
    await storage.ref(photoPath).putFile(photoPdf);

    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 60)),
    );

    await reportRef.set({
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
      'claimNumber': widget.report.claimNumber,
      'clientName': widget.report.clientName,
      'techPath': techPath,
      'photoPath': photoPath,
    });

    if (!mounted) return;
    navigator.pop();

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Report stored in Cloud.'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!mounted) return;
    navigator.pop();

    messenger.showSnackBar(
      SnackBar(
        content: Text('Error storing report: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

 Future<void> _sendReportViaEmail(File techPdf, File photoPdf, {String? extraEmail}) async {
                // Aquí se llamara un servicio backend
                               final messenger = ScaffoldMessenger.of(context);
                               final user = FirebaseAuth.instance.currentUser;
                               if (user == null || user.email == null || user.email!.isEmpty) {
                                     messenger.showSnackBar(
                                const SnackBar(content: Text('User not authenticated')),
                                );
                               return;
                                }
                                    
                                    final toEmails = <String>[user.email!];
                                if (widget.plan == 'premium' && extraEmail != null && extraEmail.trim().isNotEmpty) {
                                 toEmails.add(extraEmail.trim());
                               }     
                                    
                                   messenger.showSnackBar(
                               const SnackBar(content: Text('Sending email...')),
                                );
                                  try {
                               await EmailService.sendEmailWithReports(
                               toEmails: toEmails,
                               techPdf: techPdf,
                               photoPdf: photoPdf,
                                 );

                               if (!mounted) return;

                              messenger.showSnackBar(
                               const SnackBar(content: Text('Email sent successfully')),
                              );
                               final shouldStore = await _askStoreReportInCloud();
                               if (shouldStore) {
                               await _storeReportInCloud(techPdf, photoPdf);
                              }
                               
                               } catch (e) {
                              if (!mounted) return;

                               messenger.showSnackBar(
                               SnackBar(content: Text('Error sending email: $e')),
                             );
                              }
       }
   // Solo Premium: enviar a otros correos (sin cobro HF)
void _sendReportToCustomEmail(File techPdf, File photoPdf) {
  final extraEmailController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Send to another email'),
      content: TextField(
        controller: extraEmailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Recipient email',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final extraEmail = extraEmailController.text.trim();
            Navigator.pop(ctx);
            if (!_isProbablyValidEmail(extraEmail)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid email.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            await _sendReportViaEmail(techPdf, photoPdf, extraEmail: extraEmail);
          },
          child: const Text('Send'),
        ),
      ],
    ),
  );
}
   // Solo Premium: almacenar + email (sin cobro HF)
   // HF Estimates por email (Basic & Premium) – aquí sí habrá cobro HF
 //--Helper price calculation function
        double _calculateHfEmailPrice({required bool rushOrder}) {
    
                          const double basePrice = 70.0;        // precio base por roof estimate
                          const double shedAddon = 10.0;        // extra si hay shed
                          const double structureAddon = 15.0;   // extra si hay estructura grande
                          const double rushFee = 15.0;          // rush order
                          const double commercialExtra = 20.0;  // extra para comercial
  
                                double total = basePrice;
  
                                if (hasShed) {total += shedAddon;
                                }
                                if (hasDetachedStructure) {total += structureAddon;
                                }
                                if (widget.isCommercial) {total += commercialExtra;
                                }
                                if (rushOrder) {total += rushFee;
                                }
  
                          // Descuento 10% para el plan básico, 15% para el premium (aplicado al total después de sumar addons y rush)
                            if (widget.plan == 'basic') total *= 0.90;   // 10%
                            if (widget.plan == 'premium') total *= 0.85; // 15% total
  
                              return total;
                              }

   Future<void> _sendToHfByEmail(File techPdf, File photoPdf,
        {required bool rushOrder}) async{  
            final shouldStore = await _askStoreReportInCloud();
  if (!mounted) return;

  if (shouldStore) {
    await _storeReportInCloud(techPdf, photoPdf);
    if (!mounted) return;
  }

             final messenger = ScaffoldMessenger.of(context);
             final total = _calculateHfEmailPrice(rushOrder: rushOrder);
            
  showDialog(
  context: context,
  barrierDismissible: false,
  builder: (_) => const AlertDialog(
    content: Row(
      children: [
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Expanded(child: Text('Please wait… preparing checkout')),
      ],
    ),
  ),
);
        try{    
  messenger.showSnackBar(
    SnackBar(content: Text('Preparing HF order... Total: \$${total.toStringAsFixed(2)}',
      ),
      duration: const Duration(seconds: 3),
    ),
  );
  
       //Upload PDFs to cloud storage and get URLs (placeholder logic, implement with Firebase Storage or similar)
  final storage =  FirebaseStorage.instance;
  final timeStamp = DateTime.now().millisecondsSinceEpoch;
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final techUploadTask = await storage.ref('temp_reports/$uid/hf_orders/$timeStamp/tech.pdf').putFile(techPdf);
  final photoUploadTask = await storage.ref('temp_reports/$uid/hf_orders/$timeStamp/photos.pdf').putFile(photoPdf);

  final techUrl = await techUploadTask.ref.getDownloadURL();
  final photoUrl = await photoUploadTask.ref.getDownloadURL();

    // Llamar a backend para crear orden en HF Estimates (puede ser una Cloud Function que luego llama a la API de Xactimate)
  final callable = FirebaseFunctions.instance.httpsCallable('createHfEstimatesCheckoutSession');

       final result = await callable.call({
    'techPdfUrl': techUrl,
    'photoPdfUrl': photoUrl,
    'rushOrder': rushOrder,
    'isCommercial': widget.isCommercial,
    'hasShed': hasShed,
    'hasDetachedStructure': hasDetachedStructure,
    'plan': widget.plan, // 'basic' / 'premium'
    'userEmail': FirebaseAuth.instance.currentUser?.email,
    'clientName': widget.report.clientName,
    'claimNumber': widget.report.claimNumber,
    'address': '${widget.report.address}, ${widget.report.city}, ${widget.report.state} ${widget.report.zip}',
    'dateInspected': widget.report.dateInspected,
    'successUrl': 'claimscope://success',
    'cancelUrl': 'claimscope://cancel',
  });
     final sessionUrl = result.data['url'] as String?;
     if (sessionUrl == null) {
    throw Exception("The function did not return the Stripe URL.");
  }

  // Abrir la URL de Stripe Checkout
        final url = Uri.parse(sessionUrl);
        final success= await launchUrl(url, mode: LaunchMode.externalApplication);
          if (!success) {
            throw Exception("Stripe Checkout could not be opened.");
          }
               } catch (e) {
      debugPrint('HF Xactimate failed: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: const Color.fromARGB(255, 244, 54, 54),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
    } finally {if (mounted) Navigator.of(context, rootNavigator: true).pop();
   }
        }

       Future<void> _takeExtraPhotoForLabel(String label) async {
  await _takePhoto(
    label,
    isFacetPhoto: false,
  );
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Photo stored'),
      duration: Duration(seconds: 2),
    ),
  );
  }
         
   // Input variables for main form
    // Input variables for main form
   String? roofCoverType;
   String? roofSubType;
   String? selectedGauge;
   int? estimatedAge;
   int? numLayers;
 
   bool hasDripEdge = false;
   String? dripEdgeType;
   File? dripEdgePhoto;

   File? frontElevationPhoto;

   bool _currentHasRidgeVent = false;
   String? _currentRidgeVentType;
   File? _currentRidgeVentPhoto;

   bool gravelBallastPresent = false;

   bool hasShed = false;
   bool hasDetachedStructure = false;

  bool fullRoofReplacementRequired = false;
  String? partialReplacementSqft;

  bool sheathingRequiredToBeChanged = false;
  bool sheathingFullReplacementRequired = false;
  String? sheathingPartialReplacementSqft;
  String? sheathingType;
  String? sheathingSize;

  final TextEditingController _partialReplacementSqftController =
      TextEditingController();
  final TextEditingController _sheathingPartialSqftController =
      TextEditingController();

   // Fotos para thumbnails al final (además de widget.report.photoReportItems)
   final List<File> photoReportImages = [];

   // Si ya no usas inspectionData para el PDF, puedes eliminarlo o dejarlo
   // solo para la parte visual. Como en tu thumbnail lo usas, mantenlo:
   final List<Map<String, String>> inspectionData = [];
    // --- VARIABLES DE INTERFAZ (Sincronizadas con widget.report) ---
   final TextEditingController otherRoofCoverTypeController = TextEditingController();
   final TextEditingController otherMetalSubTypeController = TextEditingController();
   final TextEditingController otherGaugeController = TextEditingController();

   // Facet Management (Se mantienen para la lógica de la UI de facetas)
   final List<Map<String, dynamic>> _facets = [];
   int _currentFacetIndex = 0;
   final TextEditingController _currentFacetNameController = TextEditingController();
   FacetOrientation _currentFacetOrientation = FacetOrientation.none;
   File? _currentFacetOverviewPhoto;
   final TextEditingController _currentReferenceMeasuredController = TextEditingController();
   final TextEditingController _currentPitchFacetController = TextEditingController();
  
   bool starterRowInstalled = false;
   bool starterEaveInstalled = false;
   File? starterEavePhoto;
   bool starterRakeInstalled = false;
   File? starterRakePhoto;

   bool iceAndWaterBarrierInstalled = false;
   File? iceAndWaterBarrierPhoto;

   bool _currentAtrPerformed = false;
   String? _currentAtrResult;
   File? _currentAtrPhoto;
   bool _currentHasValleyMetal = false;
   String? _currentValleyMetalType;
   File? _currentValleyMetalPhoto;

   final List<Map<String, dynamic>> _currentFacetVentsData = [];
   final List<TextEditingController> _currentVentCountControllers = [];
   final List<TextEditingController> _currentOtherVentSpecifyControllers = [];

    // Flashings por faceta (similar a vents)
   final List<Map<String, dynamic>> _currentFacetFlashingsData = [];
   final List<TextEditingController> _currentFlashingOtherControllers = [];

     // Other elements on the roof (por faceta)
  final List<Map<String, dynamic>> _currentFacetOtherElementsData = [];
  final List<TextEditingController> _currentOtherElementCountControllers = [];
  final List<TextEditingController> _currentOtherElementSpecifyControllers = [];
  
   bool _isLastFacet = false;

   final TextEditingController _currentFacetCommentController =
    TextEditingController();

   String _generateNextFacetName(FacetOrientation orientation) {
   final existingFacetsOfOrientation = _facets
      .where((f) => f['facetOrientation'] == orientation)
      .length;
    return '${orientation.name.substring(0, 1).toUpperCase()}'
      '${orientation.name.substring(1)}-${existingFacetsOfOrientation + 1}';
         }
    
      String? _validateCurrentFacetBeforeAdvance() {
    if (_currentFacetOrientation == FacetOrientation.none) {
      return 'Select the facet orientation before continuing.';
    }

    if (_currentFacetOverviewPhoto == null) {
      return 'Take the main overview photo for this facet before continuing.';
    }

    for (var i = 0; i < _currentFacetFlashingsData.length; i++) {
      final flashing = _currentFacetFlashingsData[i];
      final type = flashing['type'] as String?;

      if (type == null || type.isEmpty) {
        return 'Select the flashing type for Flashing ${i + 1}.';
      }

      if (type == 'Other') {
        final otherValue =
            (flashing['otherController'] as TextEditingController).text.trim();
        if (otherValue.isEmpty) {
          return 'Specify the flashing type for Flashing ${i + 1}.';
        }
      }

      if (flashing['photo'] == null) {
        return 'Take the main photo for Flashing ${i + 1} before continuing.';
      }

      final requiredFields = flashingFieldsForResidentialType(type);
      for (final field in requiredFields) {
        final value = flashing[field.key] as String?;
        if (value == null || value.isEmpty) {
          return 'Select ${field.label} for Flashing ${i + 1}.';
        }
      }
    }

    return null;
  }

  void _attemptAddNextFacet() {
    final validationError = _validateCurrentFacetBeforeAdvance();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _addNextFacet();
  }

     void _addNextFacet() {
      
    _formKey.currentState!.save();
    _saveCurrentFacetData();
    setState(() {
      _facets.add(_createNewFacetData());
      _currentFacetIndex = _facets.length - 1;
      _initializeCurrentFacet();
      _isLastFacet = false;
    });
   
   }
   Map<String, dynamic> _createNewVentData() {
    final countController = TextEditingController();
   final otherSpecifyController = TextEditingController();

   return {
    'type': null,
    'shouldBeChanged': false,
    'count': '',
    'includeSplitBoot': false,
    'includeLead': false,
    'otherSpecify': '',
    'photo': null,
    'countController': countController,
    'otherSpecifyController': otherSpecifyController,
  };
 }

 Map<String, dynamic> _createNewFlashingData() {
  final otherController = TextEditingController();
  return {
    'type': null,
    'material': null,
    'size': null,
    'finish': null,
    'grade': null,
    'shouldBeChanged': false,
    'otherSpecify': '',
    'photo': null,
    'otherController': otherController,
  };
 }

 Map<String, dynamic> _createNewOtherElementData() {
  final countController = TextEditingController();
  final otherSpecifyController = TextEditingController();
  return {
    'type': null,
    'count': '',
    'shouldBeChanged': false,
    'detachAndResetOnly': false,
    'otherSpecify': '',
    'photo': null,
    'countController': countController,
    'otherSpecifyController': otherSpecifyController,
  };
 }

 void _addAnotherVentToCurrentFacet() {
  setState(() {
    final newVent = _createNewVentData();
    _currentFacetVentsData.add(newVent);
    _currentVentCountControllers.add(newVent['countController']);
    _currentOtherVentSpecifyControllers.add(newVent['otherSpecifyController']);
  });
 }

  @override
  void initState() {
    super.initState();
    _initializeCurrentFacet();
  }
 Future<void> _pickImagesFromGallery() async {
  final pickedFiles = await picker.pickMultiImage(
    maxWidth: 1024,
    imageQuality: 80,
  );
  setState(() {
    for (var pickedFile in pickedFiles) {
      final img = File(pickedFile.path);
      photoReportImages.add(img);
      inspectionData.add({'label': 'User Image', 'path': img.path});
      widget.report.addPhoto(img, 'User Image');
    }
  });
 }
  // --- NUEVA FUNCIÓN DE FOTOS LIMPIA ---
 Future<void> _takePhoto(
  String label, {
  bool isFacetPhoto = false,
  int? facetIndex,
  bool isGlobal = false,
  int? ventIndex,
  int? flashingIndex,
 }) async {
  final pickedFile = await picker.pickImage(
    source: ImageSource.camera,
    maxWidth: 1024,
    imageQuality: 80,
  );

  if (pickedFile == null) return;

  final img = File(pickedFile.path);

  setState(() {
    // 1) Añadir siempre al modelo de reporte (para PDF de fotos)
    widget.report.addPhoto(img, label);

    // 2) Añadir a la lista local para thumbnails (si las sigues usando)
    photoReportImages.add(img);
    inspectionData.add({'label': label, 'path': img.path});

    // 3) Asignar según el contexto de la foto
    if (isGlobal) {
      if (label == 'Front Elevation Photo') {
        frontElevationPhoto = img;
        widget.report.frontElevationPhoto = img;
      } else if (label == 'Drip Edge Photo') {
        dripEdgePhoto = img;
        widget.report.dripEdgePhoto = img;
      } else if (label == 'Ridge Vent Photo') {
      } else if (label == 'Starter Row Eave Photo') {
        starterEavePhoto = img;
      } else if (label == 'Starter Row Rake Photo') {
        starterRakePhoto = img;
      } else if (label == 'Ice & Water Barrier Photo') {
        iceAndWaterBarrierPhoto = img;
        widget.report.iceAndWaterBarrierPhoto = img;
      }

    } else if (isFacetPhoto && facetIndex != null) {
      // Fotos asociadas a una faceta concreta
      if (label == 'Facet Overview Photo') {
        _facets[facetIndex]['overviewPicture'] = img;
        _currentFacetOverviewPhoto = img;
      }   
      else if (label == 'ATR Photo') {
        _facets[facetIndex]['atrPhoto'] = img;
        _currentAtrPhoto = img;
      } else if (label == 'Valley Metal Photo') {
        _facets[facetIndex]['valleyMetalPhoto'] = img;
        _currentValleyMetalPhoto = img;
      }
    } else if (ventIndex != null && ventIndex < _currentFacetVentsData.length) {
      // Foto asociada a un vent específico
      _currentFacetVentsData[ventIndex]['photo'] = img;
    }
     else if (flashingIndex != null &&
        flashingIndex < _currentFacetFlashingsData.length) {
      // Foto asociada a un flashing específico
      _currentFacetFlashingsData[flashingIndex]['photo'] = img;
    }
  });
 }

  // --- SUBMIT FORM CORREGIDO ---
  void submitForm() async {
         
    if (frontElevationPhoto == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Take the main Front Elevation Photo before submitting.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

          // Validación personalizada de reemplazo de techo/sheathing
  if (roofCoverType == 'Shingles') {
    final partialShinglesText =
        _partialReplacementSqftController.text.trim();

    final hasFullShingles = fullRoofReplacementRequired;
    final hasPartialShingles = partialShinglesText.isNotEmpty;

    if (!hasFullShingles && !hasPartialShingles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Select full roof replacement or enter SF of shingles to replace.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (sheathingRequiredToBeChanged) {
      final partialSheathingText =
          _sheathingPartialSqftController.text.trim();

      final hasFullSheathing = sheathingFullReplacementRequired;
      final hasPartialSheathing = partialSheathingText.isNotEmpty;

      if (!hasFullSheathing && !hasPartialSheathing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Select full sheathing replacement or enter SF of sheathing to replace.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
  }
    
  final isValid = _formKey.currentState!.validate();
   debugPrint('Roof form validate() = $isValid');

if (!isValid) {
  _showRequiredFieldsWarning(); // o reemplaza por el SnackBar anterior
  return;
}

_formKey.currentState!.save();
      _saveCurrentFacetData(); // Guardar faceta actual en la lista
          // Sincronizar campos simples con el modelo
    widget.report.numLayers = numLayers;
    widget.report.estimatedAge = estimatedAge;
    widget.report.roofCoverType = roofCoverType;
    widget.report.roofSubType = roofSubType;
    widget.report.hasDripEdge = hasDripEdge;
    widget.report.dripEdgeType = dripEdgeType;
    widget.report.iceAndWaterBarrierInstalled = iceAndWaterBarrierInstalled;
    widget.report.starterRowInstalled = starterRowInstalled;
    widget.report.starterEaveInstalled = starterEaveInstalled;
    widget.report.starterRakeInstalled = starterRakeInstalled;
    //
    widget.report.hasShed = hasShed;
    widget.report.hasDetachedStructure = hasDetachedStructure;

      widget.report.fullRoofReplacementRequired = fullRoofReplacementRequired;
      widget.report.partialReplacementSqft =
      _partialReplacementSqftController.text.trim().isEmpty
          ? null
          : _partialReplacementSqftController.text.trim();
      widget.report.sheathingRequiredToBeChanged =
      sheathingRequiredToBeChanged;
      widget.report.sheathingFullReplacementRequired =
      sheathingFullReplacementRequired;
      widget.report.sheathingPartialReplacementSqft =
      _sheathingPartialSqftController.text.trim().isEmpty
          ? null
          : _sheathingPartialSqftController.text.trim();
       widget.report.sheathingType = sheathingType;
      widget.report.sheathingSize = sheathingSize;
      // Mostrar Cargando
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      try {
        // Generar PDFs usando el servicio externo
        final pdfs = await PdfService.generateReports(widget.report);
        
        if (!mounted) return;
        Navigator.pop(context); // Quitar Cargando

        // Mostrar opciones de envío
        _showSubmissionOptions(pdfs['tech']!, pdfs['photos']!);
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDFs: $e')),
        );
      }
    
  }
  // --- LOGICA DE FACETAS (Mantenida para funcionamiento) ---
  void _initializeCurrentFacet() {
    if (_facets.isEmpty) _facets.add(_createNewFacetData());
    final currentFacetData = _facets[_currentFacetIndex];
    _currentFacetNameController.text = currentFacetData['facetName'] ?? '';
    _currentFacetOrientation = currentFacetData['facetOrientation'] ?? FacetOrientation.none;
    _currentFacetOverviewPhoto = currentFacetData['overviewPicture'];
    _currentHasRidgeVent = currentFacetData['hasRidgeVent'] ?? false;
    _currentRidgeVentType = currentFacetData['ridgeVentType'];
    _currentRidgeVentPhoto = currentFacetData['ridgeVentPhoto'];
    _currentPitchFacetController.text = currentFacetData['pitchFacetValue'] ?? '';
    _currentAtrPerformed = currentFacetData['atrPerformed'] ?? false;
    _currentAtrResult = currentFacetData['atrResult'];
    _currentAtrPhoto = currentFacetData['atrPhoto'];
    _currentHasValleyMetal = currentFacetData['hasValleyMetal'] ?? false;
    _currentValleyMetalType = currentFacetData['valleyMetalType'];
    _currentValleyMetalPhoto = currentFacetData['valleyMetalPhoto'];
    _currentFacetCommentController.text = currentFacetData['comment'] ?? '';
                            // Vents: limpiar y recargar SIEMPRE
  _currentFacetVentsData.clear();
  _currentVentCountControllers.clear();
  _currentOtherVentSpecifyControllers.clear();

  final List<dynamic> loadedVents = currentFacetData['vents'] ?? [];
  for (final v in loadedVents) {
    final map = Map<String, dynamic>.from(v);
    final countController =
        TextEditingController(text: map['count'] ?? '');
    final otherSpecifyController =
        TextEditingController(text: map['otherSpecify'] ?? '');
    map['countController'] = countController;
    map['otherSpecifyController'] = otherSpecifyController;

    _currentFacetVentsData.add(map);
    _currentVentCountControllers.add(countController);
    _currentOtherVentSpecifyControllers.add(otherSpecifyController);
  }               
             // Flashings
    _currentFacetFlashingsData.clear();
    _currentFlashingOtherControllers.clear();
    final List<dynamic> loadedFlashings = currentFacetData['flashings'] ?? [];
    for (var f in loadedFlashings) {
      final map = Map<String, dynamic>.from(f);
      final otherController =
          TextEditingController(text: map['otherSpecify'] ?? '');
      map['otherController'] = otherController;
      _currentFacetFlashingsData.add(map);
      _currentFlashingOtherControllers.add(otherController);
    }
                // OTHER ELEMENTS
  _currentFacetOtherElementsData.clear();
  _currentOtherElementCountControllers.clear();
  _currentOtherElementSpecifyControllers.clear();
  final List<dynamic> loadedOther = currentFacetData['otherElements'] ?? [];
  for (final e in loadedOther) {
    final map = Map<String, dynamic>.from(e);
    final countController =
        TextEditingController(text: map['count'] ?? '');
    final otherSpecifyController =
        TextEditingController(text: map['otherSpecify'] ?? '');
    map['countController'] = countController;
    map['otherSpecifyController'] = otherSpecifyController;
    _currentFacetOtherElementsData.add(map);
    _currentOtherElementCountControllers.add(countController);
    _currentOtherElementSpecifyControllers.add(otherSpecifyController);
  }
  _currentFacetCommentController.text =
      currentFacetData['comment'] ?? '';
         }
         void _saveCurrentFacetData() {
        // Antes de guardar, sincronizar textos de 'Other' flashings
    for (int i = 0; i < _currentFacetFlashingsData.length; i++) {
      _currentFacetFlashingsData[i]['otherSpecify'] =
          _currentFlashingOtherControllers[i].text;
    }
                         // Sincronizar textos de 'Other' vents (si los tienes)
  for (int i = 0; i < _currentFacetVentsData.length; i++) {
    final vent = _currentFacetVentsData[i];
    if (vent['type'] == 'Other') {
      _currentFacetVentsData[i]['otherSpecify'] = _currentOtherVentSpecifyControllers[i].text;
          }
  }
                   for (int i = 0; i < _currentFacetOtherElementsData.length; i++) {
  _currentFacetOtherElementsData[i]['count'] =
      _currentOtherElementCountControllers[i].text;
  _currentFacetOtherElementsData[i]['otherSpecify'] =
      _currentOtherElementSpecifyControllers[i].text;
 }
  _facets[_currentFacetIndex] = {
    'facetName': _currentFacetNameController.text,
    'facetOrientation': _currentFacetOrientation,
    'overviewPicture': _currentFacetOverviewPhoto,
    'referenceMeasured': _currentReferenceMeasuredController.text,
    'hasRidgeVent': _currentHasRidgeVent,
    'ridgeVentType': _currentRidgeVentType,
    'ridgeVentPhoto': _currentRidgeVentPhoto,
    'pitchFacetValue': _currentPitchFacetController.text,
    'atrPerformed': _currentAtrPerformed,
    'atrResult': _currentAtrResult,
    'atrPhoto': _currentAtrPhoto,
    'hasValleyMetal': _currentHasValleyMetal,
    'valleyMetalType': _currentValleyMetalType,
    'valleyMetalPhoto': _currentValleyMetalPhoto,
             'vents': _currentFacetVentsData
      .map((m) => Map<String, dynamic>.from(m))
      .toList(),
       'flashings': _currentFacetFlashingsData
      .map((m) {
        final copy = Map<String, dynamic>.from(m);
        // No queremos guardar los controllers dentro del map persistente
        copy.remove('otherController');
        return copy;
      })
      .toList(),

      'otherElements': _currentFacetOtherElementsData
        .map((m) {
          final copy = Map<String, dynamic>.from(m);
          copy.remove('countController');
          copy.remove('otherSpecifyController');
          return copy;
        })
        .toList(),
      'comment': _currentFacetCommentController.text,
  };
  widget.report.facets = _facets.map((f) {
    final orientation = f['facetOrientation'] as FacetOrientation;
                // Construir lista de FlashingData a partir del map
 final List<dynamic> rawFlashings = f['flashings'] ?? [];
 final flashings = rawFlashings.map((m) {
  final map = m as Map<String, dynamic>;
  return FlashingData(
    type: map['type'] ?? '',
    material: map['material'] as String?,
    size: map['size'] as String?,
    finish: map['finish'] as String?,
    grade: map['grade'] as String?,
    otherSpecify: map['otherSpecify'] as String?,
    shouldBeChanged: map['shouldBeChanged'] ?? false,
  );
 }).toList();
           // Vents
    final List<dynamic> rawVents = f['vents'] ?? [];
    final vents = rawVents.map((m) {
      final map = m as Map<String, dynamic>;
      return VentData(
        type: map['type'] ?? '',
        count: map['count'] as String?,
        shouldBeChanged: map['shouldBeChanged'] ?? false,
        includeSplitBoot: map['includeSplitBoot'] ?? false,
        includeLead: map['includeLead'] ?? false,
        otherSpecify: map['otherSpecify'] as String?,
      );
    }).toList();

    final List<dynamic> rawOther = f['otherElements'] ?? [];
 final otherElements = rawOther.map((m) {
  final map = m as Map<String, dynamic>;
  return OtherElementData(
    type: map['type'] ?? '',
    count: map['count'] as String?,
    shouldBeChanged: map['shouldBeChanged'] ?? false,
    detachAndResetOnly: map['detachAndResetOnly'] ?? false,
    otherSpecify: map['otherSpecify'] as String?,
  );
 }).toList();

    return FacetData(
      name: f['facetName'] ?? '',
      orientation: orientation.name,
      pitch: f['pitchFacetValue'] as String?,
      atrPerformed: f['atrPerformed'] ?? false,
      atrResult: f['atrResult'] as String?,
      hasValleyMetal: f['hasValleyMetal'] ?? false,
      valleyMetalType: f['valleyMetalType'] as String?,
      flashings: flashings,
      vents: vents,
      otherElements: otherElements,
      comment: f['comment'] as String?,
      hasRidgeVent: f['hasRidgeVent'] ?? false,
      ridgeVentType: f['ridgeVentType'] as String?,
      ridgeVentPhoto: f['ridgeVentPhoto'] as File?,
    );
  }).toList();
 }
             
  Map<String, dynamic> _createNewFacetData() {
    return {
      'facetName': '',
      'facetOrientation': FacetOrientation.none,
      'overviewPicture': null,
      'vents': [],
      'flashings': [],
      'otherElements': <Map<String, dynamic>>[], 
      'hasRidgeVent': false,
      'ridgeVentType': null,
      'ridgeVentPhoto': null,
    };
  }

  Widget buildDropdownOne(String label, List<String> options, String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
      items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
    );
  }

  @override
  void dispose() {
    otherRoofCoverTypeController.dispose();
    otherMetalSubTypeController.dispose();
    otherGaugeController.dispose();
    _currentFacetNameController.dispose();
    _currentReferenceMeasuredController.dispose();
    _currentPitchFacetController.dispose();
    _currentFacetCommentController.dispose();
    _partialReplacementSqftController.dispose();
    _sheathingPartialSqftController.dispose();

      for (var controller in _currentOtherElementCountControllers) {
    controller.dispose();
  }
  for (var controller in _currentOtherElementSpecifyControllers) {
    controller.dispose();
  }

    // Dispose controllers for dynamically added vents
    for (var controller in _currentVentCountControllers) {
      controller.dispose();
    }
    for (var controller in _currentOtherVentSpecifyControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    final List<String> roofTypes = roofTypesForFlow(isCommercial: widget.isCommercial);
    final Map<String, List<String>> subTypes = roofSubtypesByType;

    final List<String> gaugeOptions = ['24', '26', '29', 'Other'];

    final List<String> ridgeVentTypes = ['Aluminum', 'Shingle over stile'];
    final List<String> atrResults = ['Passed', 'Failed'];
    final List<String> valleyMetalTypes = [
      'Valley metal Standard',
      'Valley metal W profile',
      'Valley metal W profile painted',
      'Valley metal copper',
      'Valley metal painted'
    ];
    

  final isBasico = widget.plan != 'premium'; // muestra Upgrade para free/básico

  return Scaffold(
    appBar: AppBar(
      title: const Text('Roof Inspection'),
      actions: [
        if (isBasico)
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
                try {
                await StripeService.launchCheckout('premium');
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content:
                        Text('Stripe Checkout could not be opened: $e'),
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

             if (widget.plan == 'premium')
               IconButton(
               tooltip: 'My Reports',
               icon: const Icon(Icons.folder_open),
               onPressed: () {
               Navigator.of(context).push(
               MaterialPageRoute(builder: (_) => const MyReportsScreen()),
             );
              },
             ),

        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            final navigator = Navigator.of(context);
              bool confirm = await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Logout"),
                content: const Text("Are you sure you want to sign out?"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("LOGOUT")),
                ],
              ),
            ) ?? false;

            if (confirm) {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              navigator.popUntil((route) => route.isFirst);
            }
          },
        ),
      ],
    ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              ElevatedButton(
                onPressed: () => _takePhoto('Front Elevation Photo', isGlobal: true),
                child: const Text("Take Front Elevation Photo"),
              ),
              const SizedBox(height: 20),
              const Text('Roof Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black,)),
              const Divider(),

              // Type of Roof Cover Dropdown
              buildDropdown('Type of Roof Cover', roofTypes, roofCoverType,
                 
                  (val) {
                    widget.report.roofCoverType = val; // Sincronizar con el modelo
                    widget.report.roofSubType = null;
                    
                setState(() {
                  roofCoverType = val;
                  roofSubType = null;
                  selectedGauge = null;
                  otherRoofCoverTypeController.clear();
                  otherMetalSubTypeController.clear();
                  otherGaugeController.clear();
                  gravelBallastPresent = false;
                  _facets.clear();
                  _currentFacetIndex = 0;
                  _initializeCurrentFacet();
                  _isLastFacet = false; // Reset when adding a new facet
                });
              }),

              // TextField for 'Other' Roof Cover Type
              if (roofCoverType == 'Other')
                TextFormField(
                  controller: otherRoofCoverTypeController,
                  decoration: const InputDecoration(labelText: 'Specify Other Roof Type'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),

              // Subtype Dropdown (second dropdown)
              if (roofCoverType != null && subTypes.containsKey(roofCoverType))
                buildDropdown('Subtype', subTypes[roofCoverType]!, roofSubType,
                    (val) {
                  setState(() {
                    roofSubType = val;
                    widget.report.roofSubType = val; // Sincronizar con el modelo
                    otherMetalSubTypeController.clear();
                    selectedGauge = null;
                    otherGaugeController.clear();
                  });
                }),


 if (roofCoverType == 'Shingles')
                ResidentialShinglesHubForm(
                  setState: setState,
                  fullRoofReplacementRequired: fullRoofReplacementRequired,
                  onFullRoofReplacementRequiredChanged: (val) {
                    fullRoofReplacementRequired = val;
                  },
                  partialReplacementSqftController: _partialReplacementSqftController,
                  onPartialReplacementSqftSaved: (val) {
                    partialReplacementSqft = val;
                  },
                  sheathingRequiredToBeChanged: sheathingRequiredToBeChanged,
                  onSheathingRequiredToBeChangedChanged: (val) {
                    sheathingRequiredToBeChanged = val;
                  },
                  sheathingFullReplacementRequired: sheathingFullReplacementRequired,
                  onSheathingFullReplacementRequiredChanged: (val) {
                    sheathingFullReplacementRequired = val;
                  },
                  sheathingPartialSqftController: _sheathingPartialSqftController,
                  onSheathingPartialReplacementSqftSaved: (val) {
                    sheathingPartialReplacementSqft = val;
                  },
                  sheathingType: sheathingType,
                  onSheathingTypeChanged: (val) {
                    sheathingType = val;
                  },
                  sheathingSize: sheathingSize,
                  onSheathingSizeChanged: (val) {
                    sheathingSize = val;
                  },
                  buildDropdown: buildDropdown,
                ),
              // TextField for 'Other' Metal Subtype
              if (roofCoverType == 'Metal' && roofSubType == 'Other')
                TextFormField(
                  controller: otherMetalSubTypeController,
                  decoration: const InputDecoration(labelText: 'Specify Other Metal Subtype'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),

              // Gauge Dropdown (third dropdown, only for Metal)
              if (roofCoverType == 'Metal' && roofSubType != null)
                buildDropdown('Gauge', gaugeOptions, selectedGauge, (val) {
                  setState(() {
                    selectedGauge = val;
                    otherGaugeController.clear();
                  });
                }),

              // TextField for 'Other' Gauge
              if (selectedGauge == 'Other')
                TextFormField(
                  controller: otherGaugeController,
                  decoration: const InputDecoration(labelText: 'Specify Other Gauge'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                  
                ),

              // How many Layers Installed (Conditional)
              if (['Shingles', 'Modified Bitumen', 'Roll Roofing'].contains(roofCoverType))
      TextFormField(
  decoration: InputDecoration(
    label: _requiredLabel('How Many Layers Installed', requiredField: true),
    hintText: 'Enter number of layers (e.g., 1, 2, 3)',
  ),
  keyboardType: TextInputType.number,
  onSaved: (val) => numLayers = int.tryParse(val ?? '0') ?? 0,
  validator: (v) => v!.isEmpty ? 'Required' : null,
),
               if (['Shingles'].contains(roofCoverType))
              TextFormField(
                decoration: const InputDecoration(labelText: 'Estimated Roof Age'),
                keyboardType: TextInputType.number,
                onSaved: (val) => estimatedAge = int.tryParse(val ?? '0') ?? 0,
              ),
                    if (widget.report.isResidential == true)
                   const SizedBox(height: 20),
                   const Text(
                        'Additional Structures',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black,),
                     ),
                   const Divider(),

                   CheckboxListTile(
                    title: const Text(
                           'There is a shed requiring roofing cover replacement up to 6 SQ)'),
                  value: hasShed,
                   onChanged: (val) {
                   setState(() {
                   hasShed = val ?? false;
                   widget.report.hasShed = hasShed;
             });
            },
          ),

 CheckboxListTile(
  title: const Text(
      'There is a larger structure or detached garage requiring roofing cover replacement'),
  value: hasDetachedStructure,
  onChanged: (val) {
    setState(() {
      hasDetachedStructure = val ?? false;
      widget.report.hasDetachedStructure = hasDetachedStructure;
    });
  },
 ),
              

           ResidentialRoofAccessoriesHub(
                setState: setState,
                roofCoverType: roofCoverType,
                isCommercial: widget.isCommercial,
                starterRowInstalled: starterRowInstalled,
                onStarterRowInstalledChanged: (val) {
                  starterRowInstalled = val;
                  if (!starterRowInstalled) {
                    starterEaveInstalled = false;
                    starterEavePhoto = null;
                    starterRakeInstalled = false;
                    starterRakePhoto = null;
                  }
                },
                starterEaveInstalled: starterEaveInstalled,
                onStarterEaveInstalledChanged: (val) {
                  starterEaveInstalled = val;
                  if (!starterEaveInstalled) starterEavePhoto = null;
                },
                starterEavePhoto: starterEavePhoto,
                starterRakeInstalled: starterRakeInstalled,
                onStarterRakeInstalledChanged: (val) {
                  starterRakeInstalled = val;
                  if (!starterRakeInstalled) starterRakePhoto = null;
                },
                starterRakePhoto: starterRakePhoto,
                hasDripEdge: hasDripEdge,
                onHasDripEdgeChanged: (val) {
                  hasDripEdge = val;
                },
                dripEdgeType: dripEdgeType,
                onDripEdgeTypeChanged: (val) {
                  dripEdgeType = val;
                  widget.report.dripEdgeType = val;
                },
                dripEdgePhoto: dripEdgePhoto,
                onClearDripEdge: () {
                  dripEdgeType = null;
                  dripEdgePhoto = null;
                  widget.report.dripEdgeType = null;
                  widget.report.dripEdgePhoto = null;
                },
                iceAndWaterBarrierInstalled: iceAndWaterBarrierInstalled,
                onIceAndWaterBarrierInstalledChanged: (val) {
                  iceAndWaterBarrierInstalled = val;
                  if (!iceAndWaterBarrierInstalled) {
                    iceAndWaterBarrierPhoto = null;
                  }
                },
                iceAndWaterBarrierPhoto: iceAndWaterBarrierPhoto,
                takePhoto: (label, {isGlobal = false}) => _takePhoto(
                  label,
                  isGlobal: isGlobal,
                ),
                takeExtraPhotoForLabel: _takeExtraPhotoForLabel,
                buildDropdown: buildDropdown,
              ),

              // Gravel ballast present checkbox (only for specific roof types)
              if (['Modified Bitumen', 'EPDM', 'Roll Roofing'].contains(roofCoverType))
                CheckboxListTile(
                  title: const Text('Gravel ballast present?'),
                  value: gravelBallastPresent,
                  onChanged: (bool? val) {
                    setState(() {
                      gravelBallastPresent = val!;
                     // widget.report.gravelBallastPresent = gravelBallastPresent;
                    });
                  },
                ),

              const SizedBox(height: 20),

              // --- Facet Inspection Section ---
              if (roofCoverType == 'Shingles' ||
                  roofCoverType == 'Tile roofing' ||
                  roofCoverType == 'Wood Shake' ||
                  roofCoverType == 'Slate Roof' ||
                  roofCoverType == 'TPO' ||
                  roofCoverType == 'Modified Bitumen' ||
                  roofCoverType == 'EPDM' ||
                  roofCoverType == 'Roll Roofing')
                ResidentialFacetInspectionHub(
                  setState: setState,
                  roofCoverType: roofCoverType,
                  facets: _facets,
                  currentFacetIndex: _currentFacetIndex,
                  onPreviousFacet: () {
                    _saveCurrentFacetData();
                    setState(() {
                      _currentFacetIndex--;
                      _initializeCurrentFacet();
                    });
                  },
                  onNextFacet: () {
                    _saveCurrentFacetData();
                    setState(() {
                      _currentFacetIndex++;
                      _initializeCurrentFacet();
                    });
                  },
                  currentFacetNameController: _currentFacetNameController,
                  currentFacetOrientationName: _currentFacetOrientation == FacetOrientation.none
                      ? null
                      : _currentFacetOrientation.name,
                  facetOrientationOptions: FacetOrientation.values
                      .map((e) => e.name)
                      .where((name) => name != 'none')
                      .toList(),
                  onFacetOrientationChanged: (val) {
                    setState(() {
                      _currentFacetOrientation = FacetOrientation.values
                          .firstWhere((e) => e.name == val);
                      if (val != null) {
                        _currentFacetNameController.text =
                            _generateNextFacetName(_currentFacetOrientation);
                      }
                    });
                  },
                  currentPitchFacetController: _currentPitchFacetController,
                  currentFacetOverviewPhoto: _currentFacetOverviewPhoto,
                  currentHasRidgeVent: _currentHasRidgeVent,
                  onCurrentHasRidgeVentChanged: (val) {
                    _currentHasRidgeVent = val;
                    if (!_currentHasRidgeVent) {
                      _currentRidgeVentType = null;
                      _currentRidgeVentPhoto = null;
                      _facets[_currentFacetIndex]['ridgeVentType'] = null;
                      _facets[_currentFacetIndex]['ridgeVentPhoto'] = null;
                    }
                    _facets[_currentFacetIndex]['hasRidgeVent'] = _currentHasRidgeVent;
                  },
                  ridgeVentTypes: ridgeVentTypes,
                  currentRidgeVentType: _currentRidgeVentType,
                  onCurrentRidgeVentTypeChanged: (val) {
                    _currentRidgeVentType = val;
                    _facets[_currentFacetIndex]['ridgeVentType'] = val;
                  },
                  currentRidgeVentPhoto: _currentRidgeVentPhoto,
                  currentAtrPerformed: _currentAtrPerformed,
                  onCurrentAtrPerformedChanged: (val) {
                    _currentAtrPerformed = val;
                    if (!val) {
                      _currentAtrResult = null;
                      _currentAtrPhoto = null;
                    }
                  },
                  atrResults: atrResults,
                  currentAtrResult: _currentAtrResult,
                  onCurrentAtrResultChanged: (val) {
                    _currentAtrResult = val;
                  },
                  currentAtrPhoto: _currentAtrPhoto,
                  currentHasValleyMetal: _currentHasValleyMetal,
                  onCurrentHasValleyMetalChanged: (val) {
                    _currentHasValleyMetal = val;
                    if (!val) {
                      _currentValleyMetalType = null;
                      _currentValleyMetalPhoto = null;
                    }
                  },
                  valleyMetalTypes: valleyMetalTypes,
                  currentValleyMetalType: _currentValleyMetalType,
                  onCurrentValleyMetalTypeChanged: (val) {
                    _currentValleyMetalType = val;
                  },
                  currentValleyMetalPhoto: _currentValleyMetalPhoto,
                  currentFacetFlashingsData: _currentFacetFlashingsData,
                  currentFlashingOtherControllers: _currentFlashingOtherControllers,
                  onRemoveFlashing: (idx) {
                    final data = _currentFacetFlashingsData[idx];
                    data['otherController'].dispose();
                    _currentFlashingOtherControllers.removeAt(idx);
                    _currentFacetFlashingsData.removeAt(idx);
                  },
                  onAddFlashing: () {
                    final f = _createNewFlashingData();
                    _currentFacetFlashingsData.add(f);
                    _currentFlashingOtherControllers.add(f['otherController']);
                  },
                  flashingTypes: flashingTypesForRoofType(roofCoverType),
                  buildFlashingSubfields: _buildFlashingSubfields,
                  currentFacetVentsData: _currentFacetVentsData,
                  currentVentCountControllers: _currentVentCountControllers,
                  currentOtherVentSpecifyControllers: _currentOtherVentSpecifyControllers,
                  onRemoveVent: (ventIndex) {
                    final ventData = _currentFacetVentsData[ventIndex];
                    ventData['countController'].dispose();
                    ventData['otherSpecifyController'].dispose();
                    _currentVentCountControllers.removeAt(ventIndex);
                    _currentOtherVentSpecifyControllers.removeAt(ventIndex);
                    _currentFacetVentsData.removeAt(ventIndex);
                  },
                  onAddVent: _addAnotherVentToCurrentFacet,
                  ventTypes: ventTypesForRoofType(roofCoverType),
                  currentFacetOtherElementsData: _currentFacetOtherElementsData,
                  currentOtherElementCountControllers: _currentOtherElementCountControllers,
                  currentOtherElementSpecifyControllers: _currentOtherElementSpecifyControllers,
                  onRemoveOtherElement: (idx) {
                    final data = _currentFacetOtherElementsData[idx];
                    data['countController'].dispose();
                    data['otherSpecifyController'].dispose();
                    _currentOtherElementCountControllers.removeAt(idx);
                    _currentOtherElementSpecifyControllers.removeAt(idx);
                    _currentFacetOtherElementsData.removeAt(idx);
                  },
                  onAddOtherElement: () {
                    final e = _createNewOtherElementData();
                    _currentFacetOtherElementsData.add(e);
                    _currentOtherElementCountControllers.add(e['countController']);
                    _currentOtherElementSpecifyControllers.add(e['otherSpecifyController']);
                  },
                  onTakeAdditionalFacetPhoto: () {
                    final facetName = _currentFacetNameController.text.isNotEmpty
                        ? _currentFacetNameController.text
                        : 'Unnamed facet';
                    _takeExtraPhotoForLabel('Facet $facetName - additional photo');
                  },
                  currentFacetCommentController: _currentFacetCommentController,
                  isLastFacet: _isLastFacet,
                  onIsLastFacetChanged: (val) {
                    _isLastFacet = val;
                  },
                  pickImagesFromGallery: _pickImagesFromGallery,
                  photoReportImages: photoReportImages,
                  inspectionData: inspectionData,
                  onRemoveGalleryImage: (imageFile) {
                    photoReportImages.remove(imageFile);
                    inspectionData.removeWhere(
                      (element) =>
                          element['path'] == imageFile.path &&
                          element['label'] == 'User Image',
                    );
                  },
                  addNextFacet: _attemptAddNextFacet,
                  submitForm: submitForm,
                  takePhoto: _takePhoto,
                  takeExtraPhotoForLabel: _takeExtraPhotoForLabel,
                  buildDropdown: buildDropdown,
                ),
              ], // final children of Column
          ),// final Scaffold body
        ),// final Scaffold
      ),// final Form
    );// final return of build
  }// final build method

Widget _requiredLabel(String text, {required bool requiredField}) {
  final base = (Theme.of(context).inputDecorationTheme.labelStyle ??
          const TextStyle(fontSize: 16.5))
      .copyWith(
        color: Theme.of(context).hintColor,
        decoration: TextDecoration.none,
      );

  return RichText(
    text: TextSpan(
      text: text,
      style: base,
      children: [
        if (requiredField)
          const TextSpan(
            text: ' *',
            style: TextStyle(
              color: Colors.orange,
              decoration: TextDecoration.none,
            ),
          ),
      ],
    ),
  );
}
  void _showRequiredFieldsWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please fill out the required fields.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget buildDropdown(
    String label,
    List<String> options,
    String? value,
    Function(String?) onChanged, {
    bool requiredField = false,
  }) {
return DropdownButtonFormField<String>(
  initialValue: value,
  onChanged: onChanged,
      decoration: InputDecoration(
        label: _requiredLabel(label, requiredField: requiredField),
      ),
      validator: requiredField
          ? (v) => (v == null || v.isEmpty) ? 'Required' : null
          : null,
      items: options
          .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
          .toList(),
    );
  }

}
