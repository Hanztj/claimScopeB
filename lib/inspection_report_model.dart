import 'dart:io';
import 'dart:typed_data';

import 'package:claimscope_clean/screens/elevations/models/elevations_data.dart';

class InspectionReport {
  // CLIENT & CLAIM
  String clientName = '';
  String clientPhone = '';
  String email = '';
  String address = '';
  String city = '';
  String state = '';
  String zip = '';
  String claimNumber = '';
  String policyNumber = '';
  String dateOfLoss = '';
  String dateInspected = '';
  String insuranceCompany = '';
  String typeOfLoss = '';
  String causeOfLoss = '';
  bool isResidential = true;
  bool isCommercial = false;

  // INSPECTOR
  String inspectorCompany = '';
  String inspectorName = '';
  String inspectorPhone = '';
  String inspectorEmail = '';

  // INSPECTION SCOPE
  bool inspectRoof = true;
  bool inspectElevations = false;
  bool isBasePricePaid = false;
  String? battenSystemNeedsReplacement;
  String? sheathingRequired;

  // ROOF FORM (residential legacy)
  String? roofCoverType;
  String? roofSubType;
  int? estimatedAge;
  int? numLayers;

  bool hasDripEdge = false;
  String? dripEdgeType;

  bool hasShed = false;
  bool hasDetachedStructure = false;

    // Additional Structures photos (extras via addPhoto/_takeExtraPhotoForLabel)
  File? shedPhoto;
  File? largeStructurePhoto;

  File? frontElevationPhoto;
  File? dripEdgePhoto;

  bool iceAndWaterBarrierInstalled = false;
  File? iceAndWaterBarrierPhoto;

  bool starterRowInstalled = false;
  bool starterEaveInstalled = false;
  bool starterRakeInstalled = false;

  File? starterEavePhoto;
  File? starterRakePhoto;

  bool fullRoofReplacementRequired = false;
  String? partialReplacementSqft;

  bool sheathingRequiredToBeChanged = false;
  bool sheathingFullReplacementRequired = false;
  String? sheathingPartialReplacementSqft;
  String? sheathingType;
  String? sheathingSize;
  double? squareFootageToReplace;

  // RESIDENTIAL TILE / SLATE / WOOD SHAKE
// Uses existing battenSystemNeedsReplacement field above.

// RESIDENTIAL METAL
String? selectedGauge;
String? metalGaugeOtherSpecify;
String? metalSubTypeOtherSpecify;
bool? residentialMetalHasDeck;
bool? residentialMetalDeckRequiresReplacement;
bool? residentialMetalDeckFullReplacementRequired;
String? residentialMetalDeckPartialReplacementSqft;
String? residentialMetalRoofSupportBase;
String? residentialMetalDeckSize;
bool? residentialMetalIceWaterBarrierInstalled;
String? residentialMetalIceWaterBarrierType;
String? residentialMetalNoIceWaterBarrierApproach;

// RESIDENTIAL ROLL ROOFING
String? rollExposure;
String? rollNumberOfPlies;
String? rollFasteningMethod;
bool? rollFastenerPullTestPerformed;
String? rollFastenerPullTestResult;
String? rollUnderlaymentType;
String? rollInsulationType;
String? rollInsulationSize;
bool? rollDeckRequiresReplacement;
bool? rollDeckFullReplacementRequired;
String? rollDeckPartialReplacementSqft;
bool? rollIceWaterBarrierInstalled;
bool? rollDripEdgeInstalled;
String? rollDripEdgeType;
bool rollGravelBallastPresent = false;
  
  // Cambia el "final elevations = ElevationsData();" por:
late ElevationsData elevations = ElevationsData.fromJson({});


  // REPORT CONTENT
  final List<PhotoItem> photoReportItems = [];

  // Partial photo PDFs generated on Save & Continue per section.
  // Key: 'bldg:<i>|roof:<j>' for commercial, 'elev:<Side>' for elevations.
  final Map<String, Uint8List> partialPhotoPdfs = {};
  final Map<String, String> partialPhotoPdfHashes = {};
  List<FacetData> facets = [];

  // COMMERCIAL
  List<CommercialBuildingData> commercialBuildings = [];

  void addPhoto(File file, String label) {
    photoReportItems.add(PhotoItem(file: file, label: label));
  }

  void replacePhoto(
    File file,
    String label, {
    File? previousFile,
    bool deduplicateLabel = false,
  }) {
    var targetIndex = -1;

    if (previousFile != null) {
      targetIndex = photoReportItems.indexWhere(
        (item) => item.file.absolute.path == previousFile.absolute.path,
      );
    }

    if (targetIndex < 0 && deduplicateLabel) {
      targetIndex = photoReportItems.indexWhere((item) => item.label == label);
    }

    if (targetIndex < 0) {
      addPhoto(file, label);
      return;
    }

    photoReportItems[targetIndex] = PhotoItem(file: file, label: label);

    for (var i = photoReportItems.length - 1; i >= 0; i--) {
      if (i == targetIndex) continue;

      final item = photoReportItems[i];
      final samePreviousPath = previousFile != null &&
          item.file.absolute.path == previousFile.absolute.path;
      final sameUniqueLabel = deduplicateLabel && item.label == label;

      if (samePreviousPath || sameUniqueLabel) {
        photoReportItems.removeAt(i);
        if (i < targetIndex) targetIndex--;
      }
    }
  }

  void removePhotosByFiles(Iterable<File?> files) {
    final paths = files
        .whereType<File>()
        .map((file) => file.absolute.path)
        .toSet();
    if (paths.isEmpty) return;

    photoReportItems.removeWhere(
      (item) => paths.contains(item.file.absolute.path),
    );
  }

  void removePhotosWhere(bool Function(PhotoItem item) test) {
    photoReportItems.removeWhere(test);
  }

  Map<String, dynamic> toHfPricingPayload() => {
        'isBasePricePaid': isBasePricePaid,
        'isCommercial': isCommercial,
        'hasShed': hasShed,
        'hasDetachedStructure': hasDetachedStructure,
        'commercialBuildings': commercialBuildings
            .map((building) => {
                  'roofs': building.roofs.map((roof) => {}).toList(),
                })
            .toList(),
        'elevations': elevations.toJson(),
      };
}

class PhotoItem {
  final File file;
  final String label;
  PhotoItem({required this.file, required this.label});
}

class CommercialBuildingData {
  String? name;
  bool differentAddress = false;
  String? streetAddress;

  bool hasMultipleRoofTypes = false;
  List<CommercialRoofSectionData> roofs = [];

  String? notes;

  CommercialBuildingData();

  String displayName(int index) {
  if (name != null && name!.trim().isNotEmpty) {
    return name!.trim();
  }

  if (index == 0) {
    return "Main Building";
  }

  return "Building ${index + 1}";
}
}

class CommercialRoofSectionData {
  String? roofLabel;
  String? roofType;
  String? roofSubType;
  String? roofSubTypeOtherSpecify;
  String? reportType;

  // When shingles/metal uses facets, we split into multiple roof sections.
  bool facetsGenerated = false;
  int? facetGroupTotal;
  int? facetIndex;

  // Shingles/Metal simplification
  String? pitch;
  bool hasMultipleFacets = false;
  int facetCount = 1;

  // Shingles hub fields (per roof section)
  bool? hasMultipleLayers;
  int? numberOfLayers;

  bool starterRowInstalled = false;
  bool starterEaveInstalled = false;
  bool starterRakeInstalled = false;
  File? starterEavePhoto;
  File? starterRakePhoto;
  List<File> starterEaveExtraPhotos = [];
  List<File> starterRakeExtraPhotos = [];

  bool hasDripEdge = false;
  String? dripEdgeType;
  File? dripEdgePhoto;
  List<File> dripEdgeExtraPhotos = [];

  bool iceAndWaterBarrierInstalled = false;
  File? iceAndWaterBarrierPhoto;
  List<File> iceAndWaterBarrierExtraPhotos = [];

  bool hasRidge = false;
  bool hasRidgeVent = false;
  String? ridgeVentType;
  File? ridgeVentPhoto;
  List<File> ridgeVentExtraPhotos = [];

  bool hasValleyMetal = false;
  String? valleyMetalType;
  File? valleyMetalPhoto;
  List<File> valleyMetalExtraPhotos = [];

  List<FlashingData> shingleFlashings = [];
  bool hasVents = false;
  List<VentData> shingleVents = [];

  bool hasHvacEquipment = false;
  bool hasMechanicalEquipment = false;

  // Tile / Slate hubs (Phase 3) — "Does the batten system need to be replaced?" Yes/No.
  String? battenChangeRequired;
  // Metal
  String? metalStyle; // Flat / Gable / Other
  bool? metalHasFacets; // Only used when metalStyle == 'Other'

    // Metal gauge (commercial metal) — mismas opciones/lógica que residential metal
  String? metalGauge;            // '24' | '26' | '29' | 'Other'
  String? metalGaugeOtherSpecify;

    // Commercial Metal — bloque Deck/Insulation propios (no mezclar con flat)
  bool hasDeck = false;
  bool hasInsulation = false;
  String? insulationType;
  
  // Flat systems
  bool coreSamplePerformed = false;
  File? coreSamplePhoto;
  List<File> coreSampleExtraPhotos = [];

  bool? insulationKnown;

  bool gravelBallastPresent = false;

  // Deck replacement (flat systems)
  bool deckChangeRequired = false;
  bool deckFullReplacementRequired = false;
  String? deckPartialReplacementSqft;

  String? deckType; // Metal/Wood/Other
  String? deckTypeOtherSpecify;
  String? deckThicknessGauge;

  String? insulationMaterial; // ISO/EPS/XPS/Mineral Wool
  String? insulationThickness;
  String? insulationMaterialOtherSpecify;
  bool isTapered = false;

  bool hasCoverBoard = false;
  String? coverBoardType; // DensDeck/HD ISO/Wood Fiber/Other
  String? coverBoardOtherSpecify;
  String? coverBoardThickness; // 1/4" / 1/2"

  // Only when coreSamplePerformed == false && insulationKnown == false
  String? noCoreSampleApproach; // 'EnergyCode' or 'BidItem'

  File? overviewPhoto;

  List<HvacUnitData> hvacUnits = [];
  List<HvacUnitData> mechanicalUnits = [];

  String? notes;

  // ✅ NUEVO
  List<CommercialFlashingData> tpoFlashings = [];
   List<CommercialVentData> tpoVents = [];

  // Para futuros tipos (metal, epdm, etc.)
  // List<CommercialFlashingData> metalFlashings = [];

}

class HvacUnitData {
  String? type; // AC Unit / RTU / Other
  String? otherSpecify;
  String? category;
  String? subtype;
  String? subtypeOtherSpecify;
  String? count;
  String? impellerDiameter;
  bool shouldBeReplaced = false;
  bool detachAndResetOnly = false;

  String action = 'No action required';

  bool capacityKnown = false;
  String? capacityText;

  bool nameplatePhotoCaptured = false;
  File? nameplatePhoto;
  File? photo;
  List<File> extraPhotos = [];

  String? notes;
}

class FlashingData {
  String type;
  String? material;
  String? size;
  String? finish;
  String? grade;
  String? count;
  String? otherSpecify;
  bool shouldBeChanged;
  bool changeFlueCap;
  bool changeChaseCover;
  String? chaseCoverMaterial;
  File? photo;
  List<File> extraPhotos;

  FlashingData({
    required this.type,
    this.material,
    this.size,
    this.finish,
    this.grade,
    this.count,
    this.otherSpecify,
    this.shouldBeChanged = false,
    this.changeFlueCap = false,
    this.changeChaseCover = false,
    this.chaseCoverMaterial,
    this.photo,
    List<File>? extraPhotos,
  }) : extraPhotos = extraPhotos ?? [];
}

class VentData {
  String type;
  String? count;
  bool shouldBeChanged;
  bool includeSplitBoot;
  bool includeLead;
  String? otherSpecify;
  File? photo;
  List<File> extraPhotos;

  VentData({
    required this.type,
    this.count,
    this.shouldBeChanged = false,
    this.includeSplitBoot = false,
    this.includeLead = false,
    this.otherSpecify,
    this.photo,
    List<File>? extraPhotos,
  }) : extraPhotos = extraPhotos ?? [];
}

class FacetData {
  String name;
  String orientation;
  String? pitch;

  bool hasRidgeVent;
  String? ridgeVentType;
  File? ridgeVentPhoto;

  bool atrPerformed;
  String? atrResult;

  bool hasValleyMetal;
  String? valleyMetalType;
  List<FlashingData> flashings;
  List<VentData> vents;

  List<OtherElementData> otherElements;

  String? comment;

  FacetData({
    required this.name,
    required this.orientation,
    this.pitch,
    this.hasRidgeVent = false,
    this.ridgeVentType,
    this.ridgeVentPhoto,
    this.atrPerformed = false,
    this.atrResult,
    this.hasValleyMetal = false,
    this.valleyMetalType,
    this.flashings = const [],
    this.vents = const [],
    this.otherElements = const [],
    this.comment,
  });
}

class OtherElementData {
  String type;
  String? count;
  bool shouldBeChanged;
  bool detachAndResetOnly;
  String? otherSpecify;

  OtherElementData({
    required this.type,
    this.count,
    this.shouldBeChanged = false,
    this.detachAndResetOnly = false,
    this.otherSpecify,
  });
}
// ==================== COMMERCIAL FLASHINGS ====================

class CommercialFlashingData {
 
  String type;                    // Ej: "Flash Parapet wall"
  String? size;
  String? material;
  String? grade;
  String? lfCount;                // Solo para Curb Flashing
  String? otherSpecify;
  String? count;
  bool? fullPerimeter;

  File? photo;                    // Primera foto (obligatoria)
  List<File> extraPhotos = [];

  CommercialFlashingData({
    required this.type,
    this.size,
    this.material,
    this.grade,
    this.lfCount,
    this.otherSpecify,
    this.count,
    this.fullPerimeter,
    this.photo,
  });
}

class CommercialVentData {
  String type;
  String? size;
  String? sizeOtherSpecify;
  String? throatDimension;
  String? throatDimensionOtherSpecify;
  String? shape;
  String? count;
  String? otherSpecify;

  File? photo;
  List<File> extraPhotos = [];

  CommercialVentData({
    required this.type,
    this.size,
    this.sizeOtherSpecify,
    this.throatDimension,
    this.throatDimensionOtherSpecify,
    this.shape,
    this.count,
    this.otherSpecify,
    this.photo,
  });
}
