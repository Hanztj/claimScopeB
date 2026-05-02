import 'dart:io';

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

  // INSPECTOR
  String inspectorCompany = '';
  String inspectorName = '';
  String inspectorPhone = '';
  String inspectorEmail = '';

  // INSPECTION SCOPE
  bool inspectRoof = true;
  bool inspectElevations = false;
  bool inspectInterior = false;
  String interiorScope = '';

  // ROOF FORM (residential legacy)
  String? roofCoverType;
  String? roofSubType;
  int? estimatedAge;
  int? numLayers;

  bool hasDripEdge = false;
  String? dripEdgeType;

  bool hasShed = false;
  bool hasDetachedStructure = false;

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

  // REPORT CONTENT
  final List<PhotoItem> photoReportItems = [];
  List<FacetData> facets = [];

  // COMMERCIAL
  List<CommercialBuildingData> commercialBuildings = [];

  void addPhoto(File file, String label) {
    photoReportItems.add(PhotoItem(file: file, label: label));
  }
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
    final n = (name ?? '').trim();
    return n.isEmpty ? 'Building ${index + 1}' : n;
  }
}

class CommercialRoofSectionData {
  String? roofLabel;
  String? roofType;
  String? roofSubType;
  String? roofSubTypeOtherSpecify;

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

  bool hasDripEdge = false;
  String? dripEdgeType;
  File? dripEdgePhoto;

  bool iceAndWaterBarrierInstalled = false;
  File? iceAndWaterBarrierPhoto;

  bool hasRidge = false;
  bool hasRidgeVent = false;
  String? ridgeVentType;
  File? ridgeVentPhoto;

  // Metal
  String? metalStyle; // Flat / Gable / Other
  bool? metalHasFacets; // Only used when metalStyle == 'Other'

  // Flat systems
  bool coreSamplePerformed = false;
  File? coreSamplePhoto;

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
  bool isTapered = false;

  bool hasCoverBoard = false;
  String? coverBoardType; // DensDeck/HD ISO/Wood Fiber/Other
  String? coverBoardOtherSpecify;
  String? coverBoardThickness; // 1/4" / 1/2"

  // Only when coreSamplePerformed == false && insulationKnown == false
  String? noCoreSampleApproach; // 'EnergyCode' or 'BidItem'

  File? overviewPhoto;

  List<AccessoryItemData> accessories = [];
  List<HvacUnitData> hvacUnits = [];

  String? notes;

  // ✅ NUEVO
  List<CommercialFlashingData> tpoFlashings = [];
  List<CommercialVentData> tpoVents = [];
  
  // Para futuros tipos (metal, epdm, etc.)
  // List<CommercialFlashingData> metalFlashings = [];


}

class AccessoryItemData {
  String? type;
  String? otherSpecify;

  String? count;
  bool shouldBeChanged = false;
  bool detachAndResetOnly = false;

  File? photo;
  List<File> extraPhotos = [];

  String? notes;
}

class HvacUnitData {
  String? type; // AC Unit / RTU / Other
  String? otherSpecify;

  String action = 'No action required';

  bool capacityKnown = false;
  String? capacityText;

  bool nameplatePhotoCaptured = false;
  File? nameplatePhoto;
  List<File> extraPhotos = [];

  String? notes;
}

class FlashingData {
  String type;
  String? material;
  String? size;
  String? finish;
  String? grade;
  String? otherSpecify;
  bool shouldBeChanged;

  FlashingData({
    required this.type,
    this.material,
    this.size,
    this.finish,
    this.grade,
    this.otherSpecify,
    this.shouldBeChanged = false,
  });
}

class VentData {
  String type;
  String? count;
  bool shouldBeChanged;
  bool includeSplitBoot;
  bool includeLead;
  String? otherSpecify;

  VentData({
    required this.type,
    this.count,
    this.shouldBeChanged = false,
    this.includeSplitBoot = false,
    this.includeLead = false,
    this.otherSpecify,
  });
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
    this.throatDimension,
    this.throatDimensionOtherSpecify,
    this.shape,
    this.count,
    this.otherSpecify,
    this.photo,
  });
}
