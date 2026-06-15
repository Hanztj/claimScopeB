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
// (rediseñada según docx: 3 sub-bloques opcionales + Additional Notes)
// ============================================================================
class EmergencyServicesData {
  EmergencyServicesData(); // ✅ Constructor vacío explícito

  bool enabled = false;

  // 1.A — Temporary Wall Protection
  bool twpEnabled = false;
  String twpType = '';      // 'Board' | 'Tarp'
  String twpSf = '';

  // 1.B — Temporary Window/Door Protection
  bool twdpEnabled = false;
  String twdpSf = '';

  // 1.C — Power Washing
  bool pwEnabled = false;
  String pwArea = '';       // 'Entire Elev' | 'Partial'
  String pwSf = '';

  String additionalNotes = '';

  bool get hasAnyData =>
      enabled || twpEnabled || twdpEnabled || pwEnabled ||
      twpType.isNotEmpty || twpSf.isNotEmpty ||
      twdpSf.isNotEmpty ||
      pwArea.isNotEmpty || pwSf.isNotEmpty ||
      additionalNotes.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'twpEnabled': twpEnabled,
        'twpType': twpType,
        'twpSf': twpSf,
        'twdpEnabled': twdpEnabled,
        'twdpSf': twdpSf,
        'pwEnabled': pwEnabled,
        'pwArea': pwArea,
        'pwSf': pwSf,
        'additionalNotes': additionalNotes,
      };

  factory EmergencyServicesData.fromJson(Map<String, dynamic> j) =>
      EmergencyServicesData()
        ..enabled = j['enabled'] as bool? ?? false
        ..twpEnabled = j['twpEnabled'] as bool? ?? false
        ..twpType = j['twpType'] as String? ?? ''
        ..twpSf = j['twpSf'] as String? ?? ''
        ..twdpEnabled = j['twdpEnabled'] as bool? ?? false
        ..twdpSf = j['twdpSf'] as String? ?? ''
        ..pwEnabled = j['pwEnabled'] as bool? ?? false
        ..pwArea = j['pwArea'] as String? ?? ''
        ..pwSf = j['pwSf'] as String? ?? ''
        ..additionalNotes = j['additionalNotes'] as String? ?? '';
}

// ============================================================================
// Sección 2 — Gutters / Soffit / Fascia
// ============================================================================
class GuttersSoffitFasciaData {
  GuttersSoffitFasciaData(); // ✅ Constructor vacío explícito

  // 2.A — Gutters & Downspouts
  String gutMaterial = '';
  String gutMaterialOther = '';
  String gutShape = '';
  String gutShapeOther = '';
  String gutSize = '';            // SIN opción 'Other'
  bool gutScreen = false;
  String gutScreenStyle = '';
  bool gutScupper = false;
  String gutScupperQty = '';
  String gutScope = '';
  String gutScopeOther = '';
  String gutLf = '';
  bool gutPaint = false;

  // 2.B — Fascia
  String facMaterial = '';
  String facMaterialOther = '';
  String facWoodSubtype = '';     // visible solo si facMaterial == 'Wood'
  String facSize = '';
  String facSizeOther = '';
  String facScope = '';
  String facScopeOther = '';
  String facQuantity = '';        // 'Entire perimeter' | 'Partial'
  String facLf = '';              // visible solo si facQuantity == 'Partial'
  bool facPaint = false;
  
  // 2.C — Soffit
  String sofMaterial = '';
  String sofMaterialOther = '';
  String sofSize = '';
  String sofSizeOther = '';
  String sofScope = '';
  String sofScopeOther = '';
  String sofLf = '';
  String sofQuantity = '';
  bool sofVents = false;
  String sofVentsQty = '';
  bool sofPaint = false;

  String additionalNotes = '';

  bool get guttersHasData =>
      gutMaterial.isNotEmpty || gutShape.isNotEmpty || gutSize.isNotEmpty ||
      gutScreen || gutScupper || gutScope.isNotEmpty || gutLf.isNotEmpty || gutPaint;
  bool get fasciaHasData =>
      facMaterial.isNotEmpty || facWoodSubtype.isNotEmpty || facSize.isNotEmpty ||
      facScope.isNotEmpty || facQuantity.isNotEmpty || facLf.isNotEmpty || facPaint;
  bool get soffitHasData =>
      sofMaterial.isNotEmpty || sofSize.isNotEmpty || sofScope.isNotEmpty ||
      sofLf.isNotEmpty || sofVents || sofPaint;
  bool get hasAnyData =>
      guttersHasData || fasciaHasData || soffitHasData || additionalNotes.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'gutMaterial': gutMaterial, 'gutMaterialOther': gutMaterialOther,
        'gutShape': gutShape, 'gutShapeOther': gutShapeOther,
        'gutSize': gutSize,
        'gutScreen': gutScreen, 
        'gutScupper': gutScupper,
        'gutScope': gutScope, 'gutScopeOther': gutScopeOther,
        'gutLf': gutLf, 'gutPaint': gutPaint,
        'facMaterial': facMaterial, 'facMaterialOther': facMaterialOther,
        'facWoodSubtype': facWoodSubtype,
        'facSize': facSize, 'facSizeOther': facSizeOther,
        'facScope': facScope, 'facScopeOther': facScopeOther,
        'facQuantity': facQuantity, 'facLf': facLf, 'facPaint': facPaint,
        'sofMaterial': sofMaterial, 'sofMaterialOther': sofMaterialOther,
        'sofSize': sofSize, 'sofSizeOther': sofSizeOther,
        'sofScope': sofScope, 'sofScopeOther': sofScopeOther,
        'sofLf': sofLf, 'sofVents': sofVents, 
        'sofPaint': sofPaint,
        'additionalNotes': additionalNotes,
      };

  factory GuttersSoffitFasciaData.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k] as String? ?? '';
    bool  b(String k) => j[k] as bool?   ?? false;
    return GuttersSoffitFasciaData()
      ..gutMaterial = s('gutMaterial')..gutMaterialOther = s('gutMaterialOther')
      ..gutShape = s('gutShape')..gutShapeOther = s('gutShapeOther')
      ..gutSize = s('gutSize')
      ..gutScreen = b('gutScreen')..gutScreenStyle = s('gutScreenStyle')
      ..gutScupper = b('gutScupper')..gutScupperQty = s('gutScupperQty')
      ..gutScope = s('gutScope')..gutScopeOther = s('gutScopeOther')
      ..gutLf = s('gutLf')..gutPaint = b('gutPaint')
      ..facMaterial = s('facMaterial')..facMaterialOther = s('facMaterialOther')
      ..facWoodSubtype = s('facWoodSubtype')
      ..facSize = s('facSize')..facSizeOther = s('facSizeOther')
      ..facScope = s('facScope')..facScopeOther = s('facScopeOther')
      ..facQuantity = s('facQuantity')..facLf = s('facLf')..facPaint = b('facPaint')
      ..sofMaterial = s('sofMaterial')..sofMaterialOther = s('sofMaterialOther')
      ..sofSize = s('sofSize')..sofSizeOther = s('sofSizeOther')
      ..sofScope = s('sofScope')..sofScopeOther = s('sofScopeOther')
      ..sofLf = s('sofLf')..sofVents = b('sofVents')..sofVentsQty = s('sofVentsQty')
      ..sofPaint = b('sofPaint')
      ..additionalNotes = s('additionalNotes');
  }
}

// ============================================================================
// Sección 3 — Siding Damages (cuerpo de la elevación)
// ============================================================================
 class SidingDamagesData {
  SidingDamagesData();

  // Main category (Dropdown)
  // 'Vinyl' | 'Aluminum' | 'Wood' | 'Fiber-Cement' | 'Steel' |
  // 'Wall/roof panel' | 'Stucco' | 'Brick Veneer' | 'Tone Veneer'
  String sidingMain = '';

  // 1. Vinyl
  String vinylType = '';

  // 2. Aluminum
  String aluminumType = '';

  // 3. Wood
  String woodType = '';            // incluye 'Hardboard'
  String woodHardboardSize = '';   // solo si woodType == 'Hardboard'
  String woodMaterial = '';        // oculto si woodType == 'Hardboard'
  String woodMaterialOther = '';   // si woodMaterial == 'Other'



  // 4. Fiber-Cement
  String fiberCementType = '';
  String fiberCementSize = '';     // solo si fiberCementType == 'Clapboard/Lap'

  // 5. Steel
  String steelType = '';
  String steelInsulatedSize = '';        // solo si steelType == 'Insulated Metal Panel'
  String steelInsulatedSizeOther = '';   // si steelInsulatedSize == 'Other'

  // 6. Wall/roof panel
  String panelType = '';                 // 'Ribbed' | 'Corrugated'
  String panelCorrugatedGauge = '';      // si panelType == 'Corrugated'
  bool   panelCorrugatedGalvanized = false;
  String panelRibbedGauge = '';          // si panelType == 'Ribbed'

  // Conditional Gauge & Height (debajo de la rama principal)
  String steelSidingGauge = '';          // solo si sidingMain == 'Steel' (no condicional, puede vacío)
  String sidingHeight = '';              // Vinyl/Aluminum/Wood (excepto Hardboard)

  // Scope of Work (todos excepto Stucco)
  bool   changeWholeElevation = false;
  String howManySf = '';                 // oculto si changeWholeElevation == true

  // Stucco scope (Radio Buttons excluyentes)
  // 'Small repair' | 'Crack repair' | 'Fog coat application' | 'Redash' | 'Whole replacement'
  String stuccoScope = '';
  String stuccoSmallRepairSf = '';
  String stuccoCrackRepairLf = '';
  bool   stuccoFogCoatEntireElev = false;
  String stuccoFogCoatSf = '';
  bool   stuccoRedashEntireElev = false;
  String stuccoRedashSf = '';
  String stuccoRedashTexture = '';       // 'Smooth/Flat' | 'Fine Sand' | 'Medium/Coarse'
  String stuccoWholeReplacementCoats = '';

  // Stucco extras (siempre visibles dentro del bloque Stucco)
  bool   stuccoMoistureBarrier = false;
  bool   stuccoExpansionJoints = false;
  String stuccoFinalTextureFinish = '';  // 'Smooth/Flat' | 'Sand float' | 'Fine Sand' | 'Medium/Coarse'
  String stuccoFinish = '';              // 'Painted' | 'natural gray'

  // Una única Additional Notes al final de la sección Siding (NO colapsable)
  String additionalNotes = '';

  bool get hasAnyData =>
      sidingMain.isNotEmpty || additionalNotes.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'sidingMain': sidingMain,
        'vinylType': vinylType,
        'aluminumType': aluminumType,
        'woodType': woodType,
        'woodHardboardSize': woodHardboardSize,
        'woodMaterial': woodMaterial,
        'woodMaterialOther': woodMaterialOther,
        'fiberCementType': fiberCementType,
        'fiberCementSize': fiberCementSize,
        'steelType': steelType,
        'steelInsulatedSize': steelInsulatedSize,
        'steelInsulatedSizeOther': steelInsulatedSizeOther,
        'panelType': panelType,
        'panelCorrugatedGauge': panelCorrugatedGauge,
        'panelCorrugatedGalvanized': panelCorrugatedGalvanized,
        'panelRibbedGauge': panelRibbedGauge,
        'steelSidingGauge': steelSidingGauge,
        'sidingHeight': sidingHeight,
        'changeWholeElevation': changeWholeElevation,
        'howManySf': howManySf,
        'stuccoScope': stuccoScope,
        'stuccoSmallRepairSf': stuccoSmallRepairSf,
        'stuccoCrackRepairLf': stuccoCrackRepairLf,
        'stuccoFogCoatEntireElev': stuccoFogCoatEntireElev,
        'stuccoFogCoatSf': stuccoFogCoatSf,
        'stuccoRedashEntireElev': stuccoRedashEntireElev,
        'stuccoRedashSf': stuccoRedashSf,
        'stuccoRedashTexture': stuccoRedashTexture,
        'stuccoWholeReplacementCoats': stuccoWholeReplacementCoats,
        'stuccoMoistureBarrier': stuccoMoistureBarrier,
        'stuccoExpansionJoints': stuccoExpansionJoints,
        'stuccoFinalTextureFinish': stuccoFinalTextureFinish,
        'stuccoFinish': stuccoFinish,
        'additionalNotes': additionalNotes,
      };

  factory SidingDamagesData.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k] as String? ?? '';
    bool   b(String k) => j[k] as bool?   ?? false;
    return SidingDamagesData()
      ..sidingMain = s('sidingMain')
      ..vinylType = s('vinylType')
      ..aluminumType = s('aluminumType')
      ..woodType = s('woodType')
      ..woodHardboardSize = s('woodHardboardSize')
      ..woodMaterial = s('woodMaterial')
      ..woodMaterialOther = s('woodMaterialOther')
      ..fiberCementType = s('fiberCementType')
      ..fiberCementSize = s('fiberCementSize')
      ..steelType = s('steelType')
      ..steelInsulatedSize = s('steelInsulatedSize')
      ..steelInsulatedSizeOther = s('steelInsulatedSizeOther')
      ..panelType = s('panelType')
      ..panelCorrugatedGauge = s('panelCorrugatedGauge')
      ..panelCorrugatedGalvanized = b('panelCorrugatedGalvanized')
      ..panelRibbedGauge = s('panelRibbedGauge')
      ..steelSidingGauge = s('steelSidingGauge')
      ..sidingHeight = s('sidingHeight')
      ..changeWholeElevation = b('changeWholeElevation')
      ..howManySf = s('howManySf')
      ..stuccoScope = s('stuccoScope')
      ..stuccoSmallRepairSf = s('stuccoSmallRepairSf')
      ..stuccoCrackRepairLf = s('stuccoCrackRepairLf')
      ..stuccoFogCoatEntireElev = b('stuccoFogCoatEntireElev')
      ..stuccoFogCoatSf = s('stuccoFogCoatSf')
      ..stuccoRedashEntireElev = b('stuccoRedashEntireElev')
      ..stuccoRedashSf = s('stuccoRedashSf')
      ..stuccoRedashTexture = s('stuccoRedashTexture')
      ..stuccoWholeReplacementCoats = s('stuccoWholeReplacementCoats')
      ..stuccoMoistureBarrier = b('stuccoMoistureBarrier')
      ..stuccoExpansionJoints = b('stuccoExpansionJoints')
      ..stuccoFinalTextureFinish = s('stuccoFinalTextureFinish')
      ..stuccoFinish = s('stuccoFinish')
      ..additionalNotes = s('additionalNotes');
  }
}

// ============================================================================
// Sección 4 — Underlayment / Insulation  (sin cambios — paso 5)
// ============================================================================
class UnderlaymentInsulationData {
  UnderlaymentInsulationData(); 

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
// Sección 5 — Substrate (sin cambios — paso 5)
// ============================================================================
class SubstrateData {
  SubstrateData(); 

  bool exposed = false;
  String sheathingType = '';      // OSB, Plywood, Gypsum, Other
  String sheathingTypeOther = '';
  String sheathingCondition = ''; 
  bool studsExposed = false;// Dry/intact, Wet, Damaged, Rotted
  String studsCondition = '';     // Intact, Damaged, Rotted
  String notes = '';
  List<File> photos = [];

  Map<String, dynamic> toJson() => {
        'exposed': exposed,
        'sheathingType': sheathingType,
        'sheathingTypeOther': sheathingTypeOther,
        'sheathingCondition': sheathingCondition,
        'studsExposed': studsExposed,
        'studsCondition': studsCondition,
        'notes': notes,
        'photos': _filesToPaths(photos),
      };

  factory SubstrateData.fromJson(Map<String, dynamic> j) => SubstrateData()
    ..exposed = j['exposed'] as bool? ?? false
    ..sheathingType = j['sheathingType'] as String? ?? ''
    ..sheathingTypeOther = j['sheathingTypeOther'] as String? ?? ''
    ..sheathingCondition = j['sheathingCondition'] as String? ?? ''
    ..studsExposed = j['studsExposed'] as bool? ?? false
    ..studsCondition = j['studsCondition'] as String? ?? ''
    ..notes = j['notes'] as String? ?? ''
    ..photos = _pathsToFiles(j['photos']);
}

// ============================================================================
// EIFS (sin cambios — paso 5)
// ============================================================================
class EifsData {
  EifsData();

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
// TrimEntry — RECONSTRUIDO literal según diseño "Add trim to Inspection"
// ============================================================================
 class TrimEntry {
  TrimEntry();

  // Tipo de trim (selección del catálogo del diseño)
  // 'Outside corner post' | 'Inside corner post' | 'J-trim' | 'Siding trim' | 'Skirting' | 'Other'
  String trimType = '';
  String otherSpecify = '';                // si trimType == 'Other'

  // Acción común a todos los trims
  // 'Replace' | 'D&R only'
  String action = '';

  // Campos por tipo (solo visibles si action == 'Replace')
  // Outside corner post
  String ocpMaterial = '';                 // 'Vinyl' | 'Metal' | 'Hardwood'
  bool   ocpInsulated = false;             // si ocpMaterial == 'Vinyl' || 'Metal'
  String ocpMetalGauge = '';               // si ocpMaterial == 'Metal'

  // J-trim
  String jTrimMaterial = '';               // 'Vinyl' | 'Metal'

  // Siding trim
  String sidingTrimMaterial = '';          // 'Hardboard' | 'PVC' | 'Wood'
  String sidingTrimSize = '';              // TextField

  // Skirting
  String skirtingMaterial = '';            // 'Vinyl/Plastic' | 'Metal'
  String skirtingSize = '';                // '24" to 36"' | '37" to 48"'

  // Fotos (Photo + ExtraPhoto, igual que residential Add Flashing/Add Vent)
  File? photo;
  File? extraPhoto;

  Map<String, dynamic> toJson() => {
        'trimType': trimType,
        'otherSpecify': otherSpecify,
        'action': action,
        'ocpMaterial': ocpMaterial,
        'ocpInsulated': ocpInsulated,
        'ocpMetalGauge': ocpMetalGauge,
        'jTrimMaterial': jTrimMaterial,
        'sidingTrimMaterial': sidingTrimMaterial,
        'sidingTrimSize': sidingTrimSize,
        'skirtingMaterial': skirtingMaterial,
        'skirtingSize': skirtingSize,
        'photo': _fileToPath(photo),
        'extraPhoto': _fileToPath(extraPhoto),
      };

  factory TrimEntry.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k] as String? ?? '';
    bool   b(String k) => j[k] as bool?   ?? false;
    return TrimEntry()
      ..trimType = s('trimType')
      ..otherSpecify = s('otherSpecify')
      ..action = s('action')
      ..ocpMaterial = s('ocpMaterial')
      ..ocpInsulated = b('ocpInsulated')
      ..ocpMetalGauge = s('ocpMetalGauge')
      ..jTrimMaterial = s('jTrimMaterial')
      ..sidingTrimMaterial = s('sidingTrimMaterial')
      ..sidingTrimSize = s('sidingTrimSize')
      ..skirtingMaterial = s('skirtingMaterial')
      ..skirtingSize = s('skirtingSize')
      ..photo = _pathToFile(j['photo'])
      ..extraPhoto = _pathToFile(j['extraPhoto']);
  }
}

class WindowEntry {
  WindowEntry(); 

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
  DoorEntry(); 

  String type = '';          // Entry, Patio, Sliding, Garage, Other
  String typeOther = '';
  String material = '';      // Steel, Fiberglass, Wood, Aluminum, Other
  String materialOther = '';
  String size = '';
  int qty = 0;
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
  AccessoryEntry();

  String type = '';          // Shutter, Light fixture, Vent, House number, Hose bib, Other
  String typeOther = '';
  int qty = 0;
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
      //  siding.sidingType.isNotEmpty ||
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