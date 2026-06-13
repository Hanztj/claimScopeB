import 'dart:convert';
import 'dart:io';

// ============================================================================
// ElevationSide — sealed (Front/Right/Rear/Left/Other)
// ============================================================================
sealed class ElevationSide {
  const ElevationSide();
  String get key;
  String get display;

  Map<String, dynamic> toJson() => {'key': key, 'display': display};

  factory ElevationSide.fromJson(Map<String, dynamic> j) {
    final k = j['key'] as String;
    switch (k) {
      case 'front': return const FrontSide();
      case 'right': return const RightSide();
      case 'rear':  return const RearSide();
      case 'left':  return const LeftSide();
      default:
        if (k.startsWith('other:')) return OtherSide(k.substring(6));
        return OtherSide(j['display'] as String? ?? 'Other');
    }
  }
}

class FrontSide extends ElevationSide {
  const FrontSide();
  @override String get key => 'front';
  @override String get display => 'Front';
}
class RightSide extends ElevationSide {
  const RightSide();
  @override String get key => 'right';
  @override String get display => 'Right';
}
class RearSide extends ElevationSide {
  const RearSide();
  @override String get key => 'rear';
  @override String get display => 'Rear';
}
class LeftSide extends ElevationSide {
  const LeftSide();
  @override String get key => 'left';
  @override String get display => 'Left';
}
class OtherSide extends ElevationSide {
  final String label;
  const OtherSide(this.label);
  @override String get key => 'other:$label';
  @override String get display => label;
}

// ============================================================================
// Helpers de (de)serialización para File?
// ============================================================================
String? _fileToPath(File? f) => f?.path;
File? _pathToFile(dynamic p) => (p is String && p.isNotEmpty) ? File(p) : null;

List<String> _filesToPaths(List<File> xs) => xs.map((f) => f.path).toList();
List<File> _pathsToFiles(dynamic xs) =>
    (xs is List) ? xs.whereType<String>().map((p) => File(p)).toList() : <File>[];

// ============================================================================
// Sección 1 — Emergency Services
// ============================================================================
class EmergencyServicesData {
  EmergencyServicesData(); // ✅ Constructor vacío explícito

  bool performed = false;
  String type = '';        // Tarp, Board-up, Water mitigation, Other
  String typeOther = '';
  String contractor = '';
  String date = '';
  String notes = '';
  List<File> photos = [];

  Map<String, dynamic> toJson() => {
        'performed': performed,
        'type': type,
        'typeOther': typeOther,
        'contractor': contractor,
        'date': date,
        'notes': notes,
        'photos': _filesToPaths(photos),
      };

  factory EmergencyServicesData.fromJson(Map<String, dynamic> j) =>
      EmergencyServicesData()
        ..performed = j['performed'] as bool? ?? false
        ..type = j['type'] as String? ?? ''
        ..typeOther = j['typeOther'] as String? ?? ''
        ..contractor = j['contractor'] as String? ?? ''
        ..date = j['date'] as String? ?? ''
        ..notes = j['notes'] as String? ?? ''
        ..photos = _pathsToFiles(j['photos']);
}

// ============================================================================
// Sección 2 — Gutters / Soffit / Fascia
// ============================================================================
class GuttersSoffitFasciaData {
  GuttersSoffitFasciaData(); // ✅ Constructor vacío explícito

  // Gutters
  String guttersMaterial = '';      // Aluminum, Copper, Steel, Other
  String guttersMaterialOther = '';
  String guttersCondition = '';     // Good, Damaged, Missing
  double guttersLf = 0;
  // Downspouts
  int downspoutsQty = 0;
  String downspoutsCondition = '';
  // Soffit
  String soffitMaterial = '';       // Vinyl, Aluminum, Wood, Other
  String soffitMaterialOther = '';
  String soffitCondition = '';
  double soffitSf = 0;
  // Fascia
  String fasciaMaterial = '';
  String fasciaMaterialOther = '';
  String fasciaCondition = '';
  double fasciaLf = 0;
  String notes = '';
  List<File> photos = [];

  Map<String, dynamic> toJson() => {
        'guttersMaterial': guttersMaterial,
        'guttersMaterialOther': guttersMaterialOther,
        'guttersCondition': guttersCondition,
        'guttersLf': guttersLf,
        'downspoutsQty': downspoutsQty,
        'downspoutsCondition': downspoutsCondition,
        'soffitMaterial': soffitMaterial,
        'soffitMaterialOther': soffitMaterialOther,
        'soffitCondition': soffitCondition,
        'soffitSf': soffitSf,
        'fasciaMaterial': fasciaMaterial,
        'fasciaMaterialOther': fasciaMaterialOther,
        'fasciaCondition': fasciaCondition,
        'fasciaLf': fasciaLf,
        'notes': notes,
        'photos': _filesToPaths(photos),
      };

  factory GuttersSoffitFasciaData.fromJson(Map<String, dynamic> j) =>
      GuttersSoffitFasciaData()
        ..guttersMaterial = j['guttersMaterial'] as String? ?? ''
        ..guttersMaterialOther = j['guttersMaterialOther'] as String? ?? ''
        ..guttersCondition = j['guttersCondition'] as String? ?? ''
        ..guttersLf = (j['guttersLf'] as num?)?.toDouble() ?? 0
        ..downspoutsQty = j['downspoutsQty'] as int? ?? 0
        ..downspoutsCondition = j['downspoutsCondition'] as String? ?? ''
        ..soffitMaterial = j['soffitMaterial'] as String? ?? ''
        ..soffitMaterialOther = j['soffitMaterialOther'] as String? ?? ''
        ..soffitCondition = j['soffitCondition'] as String? ?? ''
        ..soffitSf = (j['soffitSf'] as num?)?.toDouble() ?? 0
        ..fasciaMaterial = j['fasciaMaterial'] as String? ?? ''
        ..fasciaMaterialOther = j['fasciaMaterialOther'] as String? ?? ''
        ..fasciaCondition = j['fasciaCondition'] as String? ?? ''
        ..fasciaLf = (j['fasciaLf'] as num?)?.toDouble() ?? 0
        ..notes = j['notes'] as String? ?? ''
        ..photos = _pathsToFiles(j['photos']);
}

// ============================================================================
// Sección 3 — Siding Damages (cuerpo de la elevación)
// ============================================================================
class SidingDamagesData {
  SidingDamagesData(); // ✅ Constructor vacío explícito

  String sidingType = '';         // catalog key (Vinyl, Stucco, Wood, Brick, Other)
  String sidingSubtype = '';      // profile/finish
  String sidingTypeOther = '';
  String condition = '';          // Good, Minor, Major, Total loss
  double affectedSf = 0;
  String causeOfLoss = '';        // Wind, Hail, Impact, Other
  String causeOfLossOther = '';
  String notes = '';
  List<File> photos = [];

  Map<String, dynamic> toJson() => {
        'sidingType': sidingType,
        'sidingSubtype': sidingSubtype,
        'sidingTypeOther': sidingTypeOther,
        'condition': condition,
        'affectedSf': affectedSf,
        'causeOfLoss': causeOfLoss,
        'causeOfLossOther': causeOfLossOther,
        'notes': notes,
        'photos': _filesToPaths(photos),
      };

  factory SidingDamagesData.fromJson(Map<String, dynamic> j) =>
      SidingDamagesData()
        ..sidingType = j['sidingType'] as String? ?? ''
        ..sidingSubtype = j['sidingSubtype'] as String? ?? ''
        ..sidingTypeOther = j['sidingTypeOther'] as String? ?? ''
        ..condition = j['condition'] as String? ?? ''
        ..affectedSf = (j['affectedSf'] as num?)?.toDouble() ?? 0
        ..causeOfLoss = j['causeOfLoss'] as String? ?? ''
        ..causeOfLossOther = j['causeOfLossOther'] as String? ?? ''
        ..notes = j['notes'] as String? ?? ''
        ..photos = _pathsToFiles(j['photos']);
}

// ============================================================================
// Sección 4 — Underlayment / Insulation
// ============================================================================
class UnderlaymentInsulationData {
  UnderlaymentInsulationData(); // ✅ Constructor vacío explícito

  bool exposed = false;
  String underlaymentType = '';      // House wrap, Felt, Foam board, Other
  String underlaymentTypeOther = '';
  String underlaymentCondition = ''; // Intact, Torn, Missing
  String insulationType = '';        // Batt, Spray foam, Rigid, None, Other
  String insulationTypeOther = '';
  String insulationCondition = '';
  String notes = '';
  List<File> photos = [];

  Map<String, dynamic> toJson() => {
        'exposed': exposed,
        'underlaymentType': underlaymentType,
        'underlaymentTypeOther': underlaymentTypeOther,
        'underlaymentCondition': underlaymentCondition,
        'insulationType': insulationType,
        'insulationTypeOther': insulationTypeOther,
        'insulationCondition': insulationCondition,
        'notes': notes,
        'photos': _filesToPaths(photos),
      };

  factory UnderlaymentInsulationData.fromJson(Map<String, dynamic> j) =>
      UnderlaymentInsulationData()
        ..exposed = j['exposed'] as bool? ?? false
        ..underlaymentType = j['underlaymentType'] as String? ?? ''
        ..underlaymentTypeOther = j['underlaymentTypeOther'] as String? ?? ''
        ..underlaymentCondition = j['underlaymentCondition'] as String? ?? ''
        ..insulationType = j['insulationType'] as String? ?? ''
        ..insulationTypeOther = j['insulationTypeOther'] as String? ?? ''
        ..insulationCondition = j['insulationCondition'] as String? ?? ''
        ..notes = j['notes'] as String? ?? ''
        ..photos = _pathsToFiles(j['photos']);
}

// ============================================================================
// Sección 5 — Substrate (sheathing / studs)
// ============================================================================
class SubstrateData {
  SubstrateData(); // ✅ Constructor vacío explícito

  bool exposed = false;
  String sheathingType = '';      // OSB, Plywood, Gypsum, Other
  String sheathingTypeOther = '';
  String sheathingCondition = ''; // Dry/intact, Wet, Damaged, Rotted
  String studsCondition = '';     // Intact, Damaged, Rotted
  String notes = '';
  List<File> photos = [];

  Map<String, dynamic> toJson() => {
        'exposed': exposed,
        'sheathingType': sheathingType,
        'sheathingTypeOther': sheathingTypeOther,
        'sheathingCondition': sheathingCondition,
        'studsCondition': studsCondition,
        'notes': notes,
        'photos': _filesToPaths(photos),
      };

  factory SubstrateData.fromJson(Map<String, dynamic> j) => SubstrateData()
    ..exposed = j['exposed'] as bool? ?? false
    ..sheathingType = j['sheathingType'] as String? ?? ''
    ..sheathingTypeOther = j['sheathingTypeOther'] as String? ?? ''
    ..sheathingCondition = j['sheathingCondition'] as String? ?? ''
    ..studsCondition = j['studsCondition'] as String? ?? ''
    ..notes = j['notes'] as String? ?? ''
    ..photos = _pathsToFiles(j['photos']);
}

// ============================================================================
// EIFS
// ============================================================================
class EifsData {
  EifsData(); // ✅ Constructor vacío explícito

  bool present = false;
  String finishType = '';       // Smooth, Sand, Knockdown, Other
  String finishTypeOther = '';
  String condition = '';        // Good, Cracked, Delaminated, Impact damage
  double affectedSf = 0;
  String notes = '';
  List<File> photos = [];

  Map<String, dynamic> toJson() => {
        'present': present,
        'finishType': finishType,
        'finishTypeOther': finishTypeOther,
        'condition': condition,
        'affectedSf': affectedSf,
        'notes': notes,
        'photos': _filesToPaths(photos),
      };

  factory EifsData.fromJson(Map<String, dynamic> j) => EifsData()
    ..present = j['present'] as bool? ?? false
    ..finishType = j['finishType'] as String? ?? ''
    ..finishTypeOther = j['finishTypeOther'] as String? ?? ''
    ..condition = j['condition'] as String? ?? ''
    ..affectedSf = (j['affectedSf'] as num?)?.toDouble() ?? 0
    ..notes = j['notes'] as String? ?? ''
    ..photos = _pathsToFiles(j['photos']);
}

// ============================================================================
// Card entries (Trim / Window / Door / Accessory)
// ============================================================================
class TrimEntry {
  TrimEntry(); // ✅ Constructor vacío explícito

  String type = '';          // J-channel, Corner, Frieze, Other
  String typeOther = '';
  String material = '';      // Vinyl, Aluminum, Wood, Other
  String materialOther = '';
  double qty = 0;
  String unit = 'LF';        // LF | SF | EA
  String condition = '';
  String notes = '';
  File? photo;

  Map<String, dynamic> toJson() => {
        'type': type, 'typeOther': typeOther,
        'material': material, 'materialOther': materialOther,
        'qty': qty, 'unit': unit,
        'condition': condition, 'notes': notes,
        'photo': _fileToPath(photo),
      };

  factory TrimEntry.fromJson(Map<String, dynamic> j) => TrimEntry()
    ..type = j['type'] as String? ?? ''
    ..typeOther = j['typeOther'] as String? ?? ''
    ..material = j['material'] as String? ?? ''
    ..materialOther = j['materialOther'] as String? ?? ''
    ..qty = (j['qty'] as num?)?.toDouble() ?? 0
    ..unit = j['unit'] as String? ?? 'LF'
    ..condition = j['condition'] as String? ?? ''
    ..notes = j['notes'] as String? ?? ''
    ..photo = _pathToFile(j['photo']);
}

class WindowEntry {
  WindowEntry(); // ✅ Constructor vacío explícito

  String type = '';          // Single-hung, Double-hung, Casement, Picture, Other
  String typeOther = '';
  String frameMaterial = ''; // Vinyl, Aluminum, Wood, Clad, Other
  String frameMaterialOther = '';
  String size = '';          // free text e.g. 36x60
  int qty = 1;
  String condition = '';     // Good, Glass broken, Frame damaged, Total loss
  String notes = '';
  File? photo;

  Map<String, dynamic> toJson() => {
        'type': type, 'typeOther': typeOther,
        'frameMaterial': frameMaterial, 'frameMaterialOther': frameMaterialOther,
        'size': size, 'qty': qty,
        'condition': condition, 'notes': notes,
        'photo': _fileToPath(photo),
      };

  factory WindowEntry.fromJson(Map<String, dynamic> j) => WindowEntry()
    ..type = j['type'] as String? ?? ''
    ..typeOther = j['typeOther'] as String? ?? ''
    ..frameMaterial = j['frameMaterial'] as String? ?? ''
    ..frameMaterialOther = j['frameMaterialOther'] as String? ?? ''
    ..size = j['size'] as String? ?? ''
    ..qty = j['qty'] as int? ?? 1
    ..condition = j['condition'] as String? ?? ''
    ..notes = j['notes'] as String? ?? ''
    ..photo = _pathToFile(j['photo']);
}

class DoorEntry {
  DoorEntry(); // ✅ Constructor vacío explícito

  String type = '';          // Entry, Patio, Sliding, Garage, Other
  String typeOther = '';
  String material = '';      // Steel, Fiberglass, Wood, Aluminum, Other
  String materialOther = '';
  String size = '';
  int qty = 1;
  String condition = '';
  String notes = '';
  File? photoBefore;
  File? photoAfter;
  File? photoCloseup;

  Map<String, dynamic> toJson() => {
        'type': type, 'typeOther': typeOther,
        'material': material, 'materialOther': materialOther,
        'size': size, 'qty': qty,
        'condition': condition, 'notes': notes,
        'photoBefore': _fileToPath(photoBefore),
        'photoAfter': _fileToPath(photoAfter),
        'photoCloseup': _fileToPath(photoCloseup),
      };

  factory DoorEntry.fromJson(Map<String, dynamic> j) => DoorEntry()
    ..type = j['type'] as String? ?? ''
    ..typeOther = j['typeOther'] as String? ?? ''
    ..material = j['material'] as String? ?? ''
    ..materialOther = j['materialOther'] as String? ?? ''
    ..size = j['size'] as String? ?? ''
    ..qty = j['qty'] as int? ?? 1
    ..condition = j['condition'] as String? ?? ''
    ..notes = j['notes'] as String? ?? ''
    ..photoBefore = _pathToFile(j['photoBefore'])
    ..photoAfter = _pathToFile(j['photoAfter'])
    ..photoCloseup = _pathToFile(j['photoCloseup']);
}

class AccessoryEntry {
  AccessoryEntry(); // ✅ Constructor vacío explícito

  String type = '';          // Shutter, Light fixture, Vent, House number, Hose bib, Other
  String typeOther = '';
  int qty = 1;
  String condition = '';
  String notes = '';
  File? photo;

  Map<String, dynamic> toJson() => {
        'type': type, 'typeOther': typeOther,
        'qty': qty,
        'condition': condition, 'notes': notes,
        'photo': _fileToPath(photo),
      };

  factory AccessoryEntry.fromJson(Map<String, dynamic> j) => AccessoryEntry()
    ..type = j['type'] as String? ?? ''
    ..typeOther = j['typeOther'] as String? ?? ''
    ..qty = j['qty'] as int? ?? 1
    ..condition = j['condition'] as String? ?? ''
    ..notes = j['notes'] as String? ?? ''
    ..photo = _pathToFile(j['photo']);
}

// ============================================================================
// BuildingElevation — agrupa secciones 3, 4, 5 + EIFS por lado
// ============================================================================
class BuildingElevation {
  ElevationSide side;
  File? overviewPhoto;
  SidingDamagesData siding = SidingDamagesData();
  List<TrimEntry> trims = [];
  List<WindowEntry> windows = [];
  List<DoorEntry> doors = [];
  List<AccessoryEntry> accessories = [];
  UnderlaymentInsulationData underlayment = UnderlaymentInsulationData();
  SubstrateData substrate = SubstrateData();
  EifsData eifs = EifsData();
  String notes = '';

  BuildingElevation(this.side);

  bool get hasAnyData {
    return overviewPhoto != null ||
        notes.isNotEmpty ||
        trims.isNotEmpty ||
        windows.isNotEmpty ||
        doors.isNotEmpty ||
        accessories.isNotEmpty ||
        siding.sidingType.isNotEmpty ||
        underlayment.exposed ||
        substrate.exposed ||
        eifs.present;
  }

  Map<String, dynamic> toJson() => {
        'side': side.toJson(),
        'overviewPhoto': _fileToPath(overviewPhoto),
        'siding': siding.toJson(),
        'trims': trims.map((e) => e.toJson()).toList(),
        'windows': windows.map((e) => e.toJson()).toList(),
        'doors': doors.map((e) => e.toJson()).toList(),
        'accessories': accessories.map((e) => e.toJson()).toList(),
        'underlayment': underlayment.toJson(),
        'substrate': substrate.toJson(),
        'eifs': eifs.toJson(),
        'notes': notes,
      };

  factory BuildingElevation.fromJson(Map<String, dynamic> j) {
    final b = BuildingElevation(
      ElevationSide.fromJson(j['side'] as Map<String, dynamic>),
    )
      ..overviewPhoto = _pathToFile(j['overviewPhoto'])
      ..siding = SidingDamagesData.fromJson(
          (j['siding'] as Map?)?.cast<String, dynamic>() ?? {})
      ..underlayment = UnderlaymentInsulationData.fromJson(
          (j['underlayment'] as Map?)?.cast<String, dynamic>() ?? {})
      ..substrate = SubstrateData.fromJson(
          (j['substrate'] as Map?)?.cast<String, dynamic>() ?? {})
      ..eifs = EifsData.fromJson(
          (j['eifs'] as Map?)?.cast<String, dynamic>() ?? {})
      ..notes = j['notes'] as String? ?? '';
    b.trims = ((j['trims'] as List?) ?? [])
        .map((e) => TrimEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    b.windows = ((j['windows'] as List?) ?? [])
        .map((e) => WindowEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    b.doors = ((j['doors'] as List?) ?? [])
        .map((e) => DoorEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    b.accessories = ((j['accessories'] as List?) ?? [])
        .map((e) => AccessoryEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return b;
  }
}

// ============================================================================
// ElevationsData — raíz que vive en InspectionReport.elevations
// ============================================================================
class ElevationsData {
  ElevationsData(); // ✅ Constructor vacío explícito

  EmergencyServicesData emergencyServices = EmergencyServicesData();
  GuttersSoffitFasciaData guttersSoffitFascia = GuttersSoffitFasciaData();
  List<BuildingElevation> elevations = [
    BuildingElevation(const FrontSide()),
    BuildingElevation(const RightSide()),
    BuildingElevation(const RearSide()),
    BuildingElevation(const LeftSide()),
  ];

  void assignFrom(ElevationsData other) {
    emergencyServices   = other.emergencyServices;
    guttersSoffitFascia = other.guttersSoffitFascia;
    elevations
      ..clear()
      ..addAll(other.elevations);
  }

  Map<String, dynamic> toJson() => {
        'emergencyServices': emergencyServices.toJson(),
        'guttersSoffitFascia': guttersSoffitFascia.toJson(),
        'elevations': elevations.map((e) => e.toJson()).toList(),
      };

  factory ElevationsData.fromJson(Map<String, dynamic> j) {
    final d = ElevationsData()
      ..emergencyServices = EmergencyServicesData.fromJson(
          (j['emergencyServices'] as Map?)?.cast<String, dynamic>() ?? {})
      ..guttersSoffitFascia = GuttersSoffitFasciaData.fromJson(
          (j['guttersSoffitFascia'] as Map?)?.cast<String, dynamic>() ?? {});
    final list = (j['elevations'] as List?) ?? const [];
    if (list.isNotEmpty) {
      d.elevations = list
          .map((e) =>
              BuildingElevation.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }
    return d;
  }

  String encode() => jsonEncode(toJson());
  static ElevationsData decode(String s) =>
      ElevationsData.fromJson(jsonDecode(s) as Map<String, dynamic>);
}