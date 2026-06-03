import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../catalogs/roof_catalog.dart';
import '../inspection_report_model.dart';
import '../utils/photo_labels.dart';
import 'commercial/hubs/commercial_flat_hub.dart';
import 'commercial/hubs/commercial_metal_hub.dart';
import 'commercial/hubs/commercial_shingles_hub.dart';
import 'commercial_building_details_screen.dart';
import 'package:claimscope_clean/Services/pdf_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:claimscope_clean/Services/email_service.dart';
import '../utils/labeled_photos_zip.dart';
import '../Screens/widgets/submission_options_dialog.dart'; 
import '../catalogs/flashing_catalog.dart'; 

class CommercialRoofSectionScreen extends StatefulWidget {
  final String plan;
  final InspectionReport report;
  final int buildingIndex;
  final int roofIndex;

  const CommercialRoofSectionScreen({
    super.key,
    required this.plan,
    required this.report,
    required this.buildingIndex,
    required this.roofIndex,
  });

  @override
  State<CommercialRoofSectionScreen> createState() => _CommercialRoofSectionScreenState();
}

class BuildingPricing {
  /// Roof sections con cubierta DISTINTA a la principal de ESTE edificio.
  final int extraRoofSections;
  const BuildingPricing({required this.extraRoofSections});
}

class _CommercialRoofSectionScreenState extends State<CommercialRoofSectionScreen> {
  late final CommercialRoofSectionData roof;

Future<void> _showSubmissionOptions(File techPdf, File photoPdf) {
  return showSubmissionOptions(
    context: context,
    techPdf: techPdf,
    photoPdf: photoPdf,
    plan: widget.plan,
    onSendToHf: _confirmRushAndSendToHfByEmail,
    onSendToMyEmail: _sendReportViaEmail,
    onSendToCustomEmail: _sendReportToCustomEmail,
    onStoreInCloud: _storeReportInCloud,
    onGenerateLabeledZip: () => generateLabeledPhotosZip(widget.report),
  );
}

  final _picker = ImagePicker();

  final _roofLabelController = TextEditingController();
  final _pitchController = TextEditingController();
  final _facetCountController = TextEditingController();
  final _roofSubTypeOtherController = TextEditingController();
  final _layersCountController = TextEditingController();
  final _deckOtherController = TextEditingController();
  final _deckThicknessGaugeController = TextEditingController();
  final _deckPartialSqftController = TextEditingController();

  final _coverOtherController = TextEditingController();
  final _notesController = TextEditingController();

  final _showFinishActions = false;

  void _confirmRushAndSendToHfByEmail(File techPdf, File photoPdf) {
  bool rush = false;

  showDialog(
    context: context,
    builder: (rushDialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Rush Order? (+\$25)'),
            content: CheckboxListTile(
              title: const Text('Is this a rush order? (+\$25)'),
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
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Store in Cloud'),
        content: const Text(
          'This will save a copy of both reports (Technical and Photographic) '
          'to your cloud storage. You can access them anytime from your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  throw Exception('User not logged in');
                }
                
                final userId = user.uid;
                final reportId = widget.report.claimNumber.isEmpty 
                    ? DateTime.now().millisecondsSinceEpoch.toString() 
                    : widget.report.claimNumber;
                
                final storageRef = FirebaseStorage.instance
                    .ref()
                    .child('users/$userId/reports/$reportId');
                
                final techRef = storageRef.child('technical_report.pdf');
                await techRef.putFile(techPdf);
                final techUrl = await techRef.getDownloadURL();
                
                final photoRef = storageRef.child('photographic_report.pdf');
                await photoRef.putFile(photoPdf);
                final photoUrl = await photoRef.getDownloadURL();
                
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('stored_reports')
                    .doc(reportId)
                    .set({
                  'reportId': reportId,
                  'propertyAddress': '${widget.report.address}, ${widget.report.city}, ${widget.report.state} ${widget.report.zip}',
                  'technicalPdfUrl': techUrl,
                  'photographicPdfUrl': photoUrl,
                  'storedAt': FieldValue.serverTimestamp(),
                  'reportType': 'commercial',
                  'isCommercial': true,
                });
                
                if (!mounted) return;
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reports stored successfully in cloud'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error storing in cloud: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Store in Cloud'),
          ),
        ],
      );
    },
  );
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
       double? _calculateHfEmailPrice({
  required bool rushOrder,
  required List<BuildingPricing> buildings,
}) {
  const double basePrice        = 100.0; // UNA sola vez
  const double rushOrderFee     = 25.0;
  const double perSectionFee    = 30.0;  // por sección extra (por edificio)
  const double sectionsCapFee   = 120.0; // 4+ secciones extra en un edificio (fijo)
  const double perBuildingAddon = 50.0;  // por edificio adicional (2do, 3ro)
  const int    buildingsLimit   = 4;     // 4+ edificios → web

  final int buildingsCount = buildings.length;
  if (buildingsCount == 0) return null;
  if (buildingsCount >= buildingsLimit) return null; // redirigir a HF web

  double total = basePrice;

  // Secciones de cubierta distinta, por edificio (cap 4+ por edificio = $120)
  for (final b in buildings) {
    if (b.extraRoofSections >= 4) {
      total += sectionsCapFee;
    } else if (b.extraRoofSections > 0) {
      total += b.extraRoofSections * perSectionFee;
    }
  }

  // Edificios adicionales (a partir del 2do, hasta 3 adicionales)
  if (buildingsCount > 1) {
    total += (buildingsCount - 1) * perBuildingAddon;
  }

  if (rushOrder) total += rushOrderFee;

  if (widget.plan == 'basic')   total *= 0.90;
  if (widget.plan == 'premium') total *= 0.85;

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
             final total = _calculateHfEmailPrice(
  rushOrder: rushOrder,
  buildings: widget.report.commercialBuildings.map((b) => 
    BuildingPricing(
      extraRoofSections: b.roofs.length,
    )
  ).toList(),
);
            
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
  SnackBar(
    content: Text(
      'Preparing HF order... Total: \$${total?.toStringAsFixed(2) ?? 'N/A'}',
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
        'isCommercial': true,
        // Comercial: usar roofSections y additionalBuildings en lugar de hasShed/hasDetachedStructure
        'roofSectionsCount': widget.report.commercialBuildings.fold(0, (bldgSectsum, b) => bldgSectsum + b.roofs.length),
        'additionalBuildingsCount': widget.report.commercialBuildings.length - 1,
        'plan': widget.plan,
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

  @override
  void initState() {
    super.initState();
    final building = widget.report.commercialBuildings[widget.buildingIndex];
    roof = building.roofs[widget.roofIndex];

    _roofLabelController.text = roof.roofLabel ?? '';
    _pitchController.text = roof.pitch ?? '';
    _facetCountController.text = roof.facetCount.toString();
    _roofSubTypeOtherController.text = roof.roofSubTypeOtherSpecify ?? '';
    _layersCountController.text = roof.numberOfLayers?.toString() ?? '';
    _deckOtherController.text = roof.deckTypeOtherSpecify ?? '';
    _deckThicknessGaugeController.text = roof.deckThicknessGauge ?? '';
    _deckPartialSqftController.text = roof.deckPartialReplacementSqft ?? '';

    _coverOtherController.text = roof.coverBoardOtherSpecify ?? '';
    _notesController.text = roof.notes ?? '';
  }

  @override
  void dispose() {
    _roofLabelController.dispose();
    _pitchController.dispose();
    _facetCountController.dispose();
    _roofSubTypeOtherController.dispose();
    _layersCountController.dispose();
    _deckOtherController.dispose();
    _deckThicknessGaugeController.dispose();
    _deckPartialSqftController.dispose();
    _coverOtherController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isFlatSystem => roof.roofType == 'TPO' || roof.roofType == 'EPDM' || roof.roofType == 'Modified Bitumen';

  bool get _isMetal => roof.roofType == 'Metal';

  bool get _isShingles => roof.roofType == 'Shingles';

  Future<void> _takeCommercialPhoto({
    required String buildingName,
    required String roofName,
    required String photoLabel,
    required void Function(File file) onSaved,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (picked == null) return;

    final file = File(picked.path);
    final storedLabel = buildCommercialPhotoLabel(
      building: buildingName,
      roof: roofName,
      label: photoLabel,
    );

    setState(() {
      onSaved(file);
      widget.report.addPhoto(file, storedLabel);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo stored'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _sync() {
    roof.roofLabel = _roofLabelController.text.trim().isEmpty
        ? null
        : _roofLabelController.text.trim();

    roof.roofSubTypeOtherSpecify = _roofSubTypeOtherController.text.trim().isEmpty
        ? null
        : _roofSubTypeOtherController.text.trim();

    final layers = int.tryParse(_layersCountController.text.trim());
    if (roof.hasMultipleLayers == true) {
      roof.numberOfLayers = layers != null && layers > 1 ? layers : null;
    } else if (roof.hasMultipleLayers == false) {
      roof.numberOfLayers = 1;
    }

    roof.pitch = _pitchController.text.trim().isEmpty
        ? null
        : _pitchController.text.trim();

    final facetCount = int.tryParse(_facetCountController.text.trim());
    if (roof.hasMultipleFacets) {
      if (facetCount != null && facetCount > 1) {
        roof.facetCount = facetCount;
      } else {
        roof.facetCount = 2;
      }
    } else {
      roof.facetCount = 1;
    }

    roof.deckTypeOtherSpecify = _deckOtherController.text.trim().isEmpty
        ? null
        : _deckOtherController.text.trim();

    roof.deckThicknessGauge = _deckThicknessGaugeController.text.trim().isEmpty
        ? null
        : _deckThicknessGaugeController.text.trim();

    roof.deckPartialReplacementSqft =
        _deckPartialSqftController.text.trim().isEmpty
            ? null
            : _deckPartialSqftController.text.trim();

    roof.coverBoardOtherSpecify = _coverOtherController.text.trim().isEmpty
        ? null
        : _coverOtherController.text.trim();

    roof.notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final building = widget.report.commercialBuildings[widget.buildingIndex];
    final buildingName = building.displayName(widget.buildingIndex);

    final roofName = (roof.roofLabel ?? '').trim().isEmpty
        ? 'Roof ${widget.roofIndex + 1}'
        : roof.roofLabel!.trim();

    final overviewLabel = 'Roof Overview Photo';

    final subtypes = subtypesForRoofType(roof.roofType);
    if (roof.roofSubType != null && !subtypes.contains(roof.roofSubType)) {
      roof.roofSubType = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$buildingName - $roofName'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _roofLabelController,
            decoration: const InputDecoration(
              labelText: 'Roof label (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _sync(),
          ),

            const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _takeCommercialPhoto(
              buildingName: buildingName,
              roofName: roofName,
              photoLabel: overviewLabel,
              onSaved: (f) => roof.overviewPhoto = f,
            ),
            child: const Text('Take overview photo'),
          ),
          TextButton(
            onPressed: () => _takeCommercialPhoto(
              buildingName: buildingName,
              roofName: roofName,
              photoLabel: '$overviewLabel additional photo',
              onSaved: (_) {},
            ),
            child: const Text('Add additional overview photo'),
          ),
          if (roof.overviewPhoto != null) ...[
            const SizedBox(height: 8),
            Image.file(roof.overviewPhoto!, height: 140, fit: BoxFit.cover),
          ],

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: roof.roofType,
            decoration: const InputDecoration(
              labelText: 'Roof cover type',
              border: OutlineInputBorder(),
            ),
            items: roofTypesAll
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (val) {
              setState(() {
                roof.roofType = val;
                roof.roofSubType = null;
                roof.roofSubTypeOtherSpecify = null;

                // Reset type-specific fields when switching.
                roof.metalStyle = null;
                roof.metalHasFacets = null;
                roof.pitch = null;
                roof.hasMultipleFacets = false;
                roof.facetCount = 1;

                roof.hasMultipleLayers = null;
                roof.numberOfLayers = null;
                roof.starterRowInstalled = false;
                roof.starterEaveInstalled = false;
                roof.starterRakeInstalled = false;
                roof.starterEavePhoto = null;
                roof.starterRakePhoto = null;
                roof.hasDripEdge = false;
                roof.dripEdgeType = null;
                roof.dripEdgePhoto = null;
                roof.iceAndWaterBarrierInstalled = false;
                roof.iceAndWaterBarrierPhoto = null;
                roof.hasRidge = false;
                roof.hasRidgeVent = false;
                roof.ridgeVentType = null;
                roof.ridgeVentPhoto = null;
                roof.hasValleyMetal = false;
                roof.valleyMetalType = null;
                roof.valleyMetalPhoto = null;
                roof.shingleFlashings.clear();
                roof.hasVents = false;
                roof.shingleVents.clear();
                roof.hasHvacEquipment = false;
                roof.hasMechanicalEquipment = false;
                roof.hvacUnits.clear();
                roof.mechanicalUnits.clear();

                roof.coreSamplePerformed = false;
                roof.coreSamplePhoto = null;
                roof.insulationKnown = null;
                roof.gravelBallastPresent = false;

                roof.deckChangeRequired = false;
                roof.deckFullReplacementRequired = false;
                roof.deckPartialReplacementSqft = null;
                roof.deckType = null;
                roof.deckTypeOtherSpecify = null;
                roof.deckThicknessGauge = null;

                roof.insulationMaterial = null;
                roof.insulationThickness = null;
                roof.insulationMaterialOtherSpecify = null;
                roof.isTapered = false;
                roof.hasCoverBoard = false;
                roof.coverBoardType = null;
                roof.coverBoardThickness = null;
                roof.coverBoardOtherSpecify = null;

                roof.noCoreSampleApproach = null;

                _pitchController.clear();
                roof.hasMultipleFacets = false;
                _facetCountController.text = '1';
                _layersCountController.clear();
                _deckOtherController.clear();
                _coverOtherController.clear();

              });
            },
          ),
   if (subtypes.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true, // 👈 SOLUCIÓN 1: Obliga al Dropdown a ocupar el ancho disponible de forma segura
              initialValue: roof.roofSubType,
              decoration: const InputDecoration(
                labelText: 'Subtype',
                border: OutlineInputBorder(),
              ),
              items: subtypes
             .map((t) => DropdownMenuItem(
             value: t,
            child: Text(
            t,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
                 ),
                  ))
          .toList(),
              onChanged: (val) {
                setState(() {
                  roof.roofSubType = val;
                  if (val != 'Other') {
                    roof.roofSubTypeOtherSpecify = null;
                    _roofSubTypeOtherController.clear();
                  }
                });
              },
            ),
            if (roof.roofSubType == 'Other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _roofSubTypeOtherController,
                decoration: const InputDecoration(
                  labelText: 'Specify',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _sync(),
              ),
            ],
          ],
          if (_isMetal)
            CommercialMetalHubForm(
              roof: roof,
              pitchController: _pitchController,
              facetCountController: _facetCountController,
              setState: setState,
              sync: _sync,
            ),
          if (_isShingles)
            CommercialShinglesHubForm(
              roof: roof,
              buildingName: buildingName,
              roofName: roofName,
              pitchController: _pitchController,
              facetCountController: _facetCountController,
              layersCountController: _layersCountController,
              deckPartialSqftController: _deckPartialSqftController,
              setState: setState,
              sync: _sync,
              takeCommercialPhoto: _takeCommercialPhoto,
            ),
          
          if (_isFlatSystem)
            CommercialFlatHubForm(
              roof: roof,
              buildingName: buildingName,
              roofName: roofName,
              deckOtherController: _deckOtherController,
              deckThicknessGaugeController: _deckThicknessGaugeController,
              deckPartialSqftController: _deckPartialSqftController,
              coverOtherController: _coverOtherController,
              setState: setState,
              sync: _sync,
              takeCommercialPhoto: _takeCommercialPhoto,
            ),
            
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await _takeCommercialPhoto(
                  buildingName: buildingName,
                  roofName: roofName,
                  photoLabel: 'Additional Photo',
                  onSaved: (_) {},
                );
              },
              child: const Text('Take additional images'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Roof notes (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _sync(),
          ),
                    const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final images = await _picker.pickMultiImage(
                  maxWidth: 1024,
                  imageQuality: 80,
                );

                if (images.isEmpty) return;

                for (final x in images) {
                  widget.report.addPhoto(
                    File(x.path),
                    buildCommercialPhotoLabel(
                      building: buildingName,
                      roof: roofName,
                      label: 'User Image',
                    ),
                  );
                }

                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Photos added')),
                );
              },
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Images from Gallery'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (context) {
                final buildings = widget.report.commercialBuildings;
                final isLastBuilding = widget.buildingIndex >= buildings.length - 1;
                final building = buildings[widget.buildingIndex];
                final isLastRoof = widget.roofIndex >= building.roofs.length - 1;
                final isFinalStep = isLastBuilding && isLastRoof;

                if (isFinalStep && _showFinishActions) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final images = await _picker.pickMultiImage(
                              maxWidth: 1024,
                              imageQuality: 80,
                            );

                            if (images.isEmpty) return;

                            for (final x in images) {
                              widget.report.addPhoto(
                                File(x.path),
                                buildCommercialPhotoLabel(
                                  building: buildingName,
                                  roof: roofName,
                                  label: 'User Image',
                                ),
                              );
                            }

                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Photos added')),
                            );
                          },
                          child: const Text('Add Images from Gallery'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (widget.report.inspectElevations) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Elevations flow not implemented yet.'),
                                ),
                              );
                              return;
                            }

                           // await _showSubmissionOptions();
                          },
                          child: const Text('Submit Inspection'),
                        ),
                      ),
                    ],
                  );
                }

                return ElevatedButton(
                  onPressed: () async {
                    _sync();
                    widget.report.isCommercial = true;
                    roof.reportType = 'commercial';

                    if (roof.overviewPhoto == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please add an overview photo.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                      if (roof.roofType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                      content: Text('Select the type of roof covering.'),
                      backgroundColor: Colors.red,
                      ),
                       );
                        return;
                       }

                    if (roof.roofSubType == 'Other' &&
                        (_roofSubTypeOtherController.text.trim().isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please specify the subtype.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                       if (_isFlatSystem) {
                      if (roof.coreSamplePerformed) {
                        if (roof.coreSamplePhoto == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please add a core sample photo.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      } 
                      if (roof.insulationMaterial == 'Other' && 
                     (roof.insulationMaterialOtherSpecify == null || roof.insulationMaterialOtherSpecify!.trim().isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                        content: Text('Please specify the insulation material.'),
                       backgroundColor: Colors.red,
                             ),
                               );
                              return;
                            }
                                            else {
                        if (roof.insulationKnown == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select whether the sublayer system is known.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                         
                        if (roof.insulationKnown == false &&
                            roof.noCoreSampleApproach == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a sublayer estimating approach.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

                      if (roof.coreSamplePerformed || roof.insulationKnown == true) {
                        if (roof.insulationMaterial == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select the base insulation material.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (roof.insulationThickness == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select the base insulation thickness.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }
                    }

                    if (roof.roofType == 'Shingles' && roof.hasMultipleLayers == true) {
                      final layers = int.tryParse(_layersCountController.text.trim());
                      if (layers == null || layers < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter how many layers.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                         return;
                      }
                    }

                    if (roof.roofType == 'Shingles') {
                      if (roof.hasValleyMetal &&
                          (roof.valleyMetalType == null ||
                              roof.valleyMetalType!.isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select the valley metal type.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      for (var i = 0; i < roof.shingleFlashings.length; i++) {
                        final flashing = roof.shingleFlashings[i];
                        if (flashing.type.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Select the flashing type for Flashing ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (flashing.type == 'Other' &&
                            (flashing.otherSpecify == null ||
                                flashing.otherSpecify!.trim().isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Specify the flashing type for Flashing ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        for (final field in flashingFieldsForResidentialType(flashing.type)) {
                          final value = switch (field.key) {
                            'material' => flashing.material,
                            'size' => flashing.size,
                            'finish' => flashing.finish,
                            'grade' => flashing.grade,
                            _ => null,
                          };
                          if (value == null || value.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Select ${field.label} for Flashing ${i + 1}.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                        }
                        if (flashing.photo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Take the main photo for Flashing ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

                      if (roof.hasVents && roof.shingleVents.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add at least one vent or uncheck Has Vents.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      for (var i = 0; i < roof.shingleVents.length; i++) {
                        final vent = roof.shingleVents[i];
                        if (vent.type.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Select the vent type for Vent ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (vent.type == 'Other' &&
                            (vent.otherSpecify == null ||
                                vent.otherSpecify!.trim().isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Specify the vent type for Vent ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (vent.photo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Take the main photo for Vent ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

                      if (roof.hasHvacEquipment && roof.hvacUnits.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add at least one HVAC item or uncheck HVAC equipment.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (roof.hasMechanicalEquipment && roof.mechanicalUnits.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add at least one mechanical equipment item or uncheck Mechanical Equipment.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      for (var i = 0; i < roof.hvacUnits.length; i++) {
                        if (roof.hvacUnits[i].photo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Take the main photo for HVAC ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }
                    }

                    if ((roof.roofType == 'Shingles' || roof.roofType == 'Metal') &&
                        roof.hasMultipleFacets &&
                        roof.facetCount <= 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter the facet count.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                        if (_isFlatSystem) {
                      for (var i = 0; i < roof.tpoFlashings.length; i++) {
                        if (roof.tpoFlashings[i].photo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Take the main photo for Flashing ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

                      for (var i = 0; i < roof.tpoVents.length; i++) {
                        if (roof.tpoVents[i].photo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Take the main photo for Vent ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

                      for (var i = 0; i < roof.hvacUnits.length; i++) {
                        if (roof.hvacUnits[i].photo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Take the main photo for HVAC ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }
                    }
                    
                      for (var i = 0; i < roof.mechanicalUnits.length; i++) {
                        if (roof.mechanicalUnits[i].photo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Take the main photo for Mechanical ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

                    // If this roof section has multiple facets, split into separate roof sections.
                    if ((roof.roofType == 'Shingles' || roof.roofType == 'Metal') &&
                        roof.hasMultipleFacets &&
                        !roof.facetsGenerated &&
                        roof.facetCount > 1) {
                      final total = roof.facetCount;
                      roof.facetsGenerated = true;
                      roof.facetGroupTotal = total;
                      roof.facetIndex = 1;
                      roof.hasMultipleFacets = false;
                      roof.facetCount = 1;
                      _facetCountController.text = '1';

                      final baseLabel = (roof.roofLabel ?? '').trim().isEmpty
                          ? 'Roof ${widget.roofIndex + 1}'
                          : roof.roofLabel!.trim();

                      roof.roofLabel = '$baseLabel - Facet 1';
                      _roofLabelController.text = roof.roofLabel!;

                      // Next facets require their own overview.

                      for (var i = 2; i <= total; i++) {
                        final r = CommercialRoofSectionData();
                        r.roofType = roof.roofType;
                        r.reportType = 'commercial';
                        r.roofSubType = roof.roofSubType;
                        r.roofSubTypeOtherSpecify = roof.roofSubTypeOtherSpecify;
                        r.pitch = roof.pitch;
                        r.hasMultipleFacets = false;
                        r.facetCount = 1;
                        r.metalStyle = roof.metalStyle;
                        r.metalHasFacets = roof.metalHasFacets;

                        // Shingles hub fields
                        r.hasMultipleLayers = roof.hasMultipleLayers;
                        r.numberOfLayers = roof.numberOfLayers;
                        r.starterRowInstalled = roof.starterRowInstalled;
                        r.starterEaveInstalled = roof.starterEaveInstalled;
                        r.starterRakeInstalled = roof.starterRakeInstalled;
                        r.starterEavePhoto = roof.starterEavePhoto;
                        r.starterRakePhoto = roof.starterRakePhoto;
                        r.hasDripEdge = roof.hasDripEdge;
                        r.dripEdgeType = roof.dripEdgeType;
                        r.dripEdgePhoto = roof.dripEdgePhoto;
                        r.iceAndWaterBarrierInstalled = roof.iceAndWaterBarrierInstalled;
                        r.iceAndWaterBarrierPhoto = roof.iceAndWaterBarrierPhoto;
                        r.hasRidge = roof.hasRidge;
                        r.hasRidgeVent = roof.hasRidgeVent;
                        r.ridgeVentType = roof.ridgeVentType;
                        r.ridgeVentPhoto = roof.ridgeVentPhoto;
                        r.hasValleyMetal = roof.hasValleyMetal;
                        r.valleyMetalType = roof.valleyMetalType;
                        r.hasVents = roof.hasVents;
                        r.hasHvacEquipment = roof.hasHvacEquipment;
                        r.hasMechanicalEquipment = roof.hasMechanicalEquipment;

                        r.facetsGenerated = true;
                        r.facetGroupTotal = total;
                        r.facetIndex = i;
                        r.facetCount = 1;
                        r.overviewPhoto = null;

                        r.roofLabel = '$baseLabel - Facet $i';

                        building.roofs.insert(widget.roofIndex + (i - 1), r);
                      }
                    }

                   if (isFinalStep) {
                   await _submitCommercialReport();
                   return;
                     }

                    final nextRoofIndex = widget.roofIndex + 1;
                    if (nextRoofIndex < building.roofs.length) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => CommercialRoofSectionScreen(
                            plan: widget.plan,
                            report: widget.report,
                            buildingIndex: widget.buildingIndex,
                            roofIndex: nextRoofIndex,
                          ),
                        ),
                      );
                      return;
                    }

                    final nextBuildingIndex = widget.buildingIndex + 1;
                    if (nextBuildingIndex < buildings.length) {
                      final nextBuilding = buildings[nextBuildingIndex];
                      if (nextBuilding.roofs.isEmpty) {
                        nextBuilding.roofs.add(
                          CommercialRoofSectionData()..roofLabel = 'Main Roof' 
                          ..reportType = 'commercial',
                        );
                      }

                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => CommercialBuildingDetailScreen(
                            plan: widget.plan,
                            report: widget.report,
                            buildingIndex: nextBuildingIndex,
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(isFinalStep ? 'Finish Inspection' : 'Save & Continue'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  // === FUNCIÓN PARA ENVIAR REPORTE COMERCIAL ===
Future<void> _submitCommercialReport() async {
  if (roof.roofType == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Select the type of roof covering.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final navigator = Navigator.of(context);
  bool loadingShown = false;

  try {
    widget.report.isCommercial = true;
    roof.reportType = 'commercial';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    loadingShown = true;

    final pdfs = await PdfService.generateReports(widget.report);

    if (!mounted) return;

    if (!pdfs.containsKey('tech') || !pdfs.containsKey('photos')) {
      throw Exception(
        'PDF generation did not return the expected reports.',
      );
    }

    if (loadingShown && navigator.canPop()) {
      navigator.pop();
      loadingShown = false;
    }

    await _showSubmissionOptions(
      pdfs['tech']!,
      pdfs['photos']!,
    );
  } catch (e) {
    if (!mounted) return;

    if (loadingShown && navigator.canPop()) {
      navigator.pop();
      loadingShown = false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error generating PDFs: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
}
