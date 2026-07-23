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
// Helpers de (de)serialización optimizados (Sin toList innecesario)
// ============================================================================
/// Clase utilitaria para evitar "unused declaration" y encapsular lógica de archivos
class FileHelper {
  static String? fileToPath(File? f) => f?.path;

  static File? pathToFile(dynamic p) => (p is String && p.isNotEmpty) ? File(p) : null;

  static Iterable<String> filesToPaths(List<File> xs) => xs.map((f) => f.path);

  static Iterable<File> pathsToFiles(dynamic xs) =>
      (xs is List) ? xs.whereType<String>().map((p) => File(p)) : <File>[];
}

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
  String gutQuantity = '';        // 'All Installed' | 'Partial'
  String gutLf = '';              // visible solo si gutQuantity == 'Partial'
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
      gutScreen || gutScupper || gutScope.isNotEmpty ||
      gutQuantity.isNotEmpty || gutLf.isNotEmpty || gutPaint;
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
        'gutQuantity': gutQuantity,
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
      ..gutQuantity = s('gutQuantity')
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
  String panelCorrugatedGaugeOther = ''; // si panelCorrugatedGauge == 'Other'
  bool   panelCorrugatedGalvanized = false;
  String panelRibbedGauge = '';          // si panelType == 'Ribbed'
  String panelRibbedGaugeOther = '';     // si panelRibbedGauge == 'Other'
  bool panelHasInsulation = false;
  String panelInsulation = '';

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
      sidingMain.isNotEmpty ||
      panelHasInsulation ||
      panelInsulation.isNotEmpty ||
      additionalNotes.isNotEmpty;

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
        'panelCorrugatedGaugeOther': panelCorrugatedGaugeOther,
        'panelCorrugatedGalvanized': panelCorrugatedGalvanized,
        'panelRibbedGauge': panelRibbedGauge,
        'panelRibbedGaugeOther': panelRibbedGaugeOther,
        'panelHasInsulation': panelHasInsulation,
        'panelInsulation': panelInsulation,
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
      ..panelCorrugatedGaugeOther = s('panelCorrugatedGaugeOther')
      ..panelCorrugatedGalvanized = b('panelCorrugatedGalvanized')
      ..panelRibbedGauge = s('panelRibbedGauge')
      ..panelRibbedGaugeOther = s('panelRibbedGaugeOther')
      ..panelHasInsulation = b('panelHasInsulation')
      ..panelInsulation = s('panelInsulation')
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

  bool addFanfoldInsulation = false;
  String fanfoldThickness = '';
  bool addHouseWrapWrb = false;
  bool addFoilInsulationRadiantBarrier = false;
  bool useRainscreenFurringStrips = false;
  String additionalNotes = '';

  bool get hasAnyData =>
      addFanfoldInsulation ||
      fanfoldThickness.isNotEmpty ||
      addHouseWrapWrb ||
      addFoilInsulationRadiantBarrier ||
      useRainscreenFurringStrips ||
      additionalNotes.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'addFanfoldInsulation': addFanfoldInsulation,
        'fanfoldThickness': fanfoldThickness,
        'addHouseWrapWrb': addHouseWrapWrb,
        'addFoilInsulationRadiantBarrier': addFoilInsulationRadiantBarrier,
        'useRainscreenFurringStrips': useRainscreenFurringStrips,
        'additionalNotes': additionalNotes,
      };
      
  factory UnderlaymentInsulationData.fromJson(Map<String, dynamic> j) =>
      UnderlaymentInsulationData()
        ..addFanfoldInsulation =
            j['addFanfoldInsulation'] as bool? ?? false
        ..fanfoldThickness = j['fanfoldThickness'] as String? ?? ''
        ..addHouseWrapWrb = j['addHouseWrapWrb'] as bool? ?? false
        ..addFoilInsulationRadiantBarrier =
            j['addFoilInsulationRadiantBarrier'] as bool? ?? false
        ..useRainscreenFurringStrips =
            j['useRainscreenFurringStrips'] as bool? ?? false
        ..additionalNotes = j['additionalNotes'] as String? ?? '';
}

// ============================================================================
// Sección 5 — Substrate
// ============================================================================
class SubstrateData {
  SubstrateData();

  bool substrateRepairReplacementNeeded = false;
  String substrateMaterialType = '';
  String substrateThickness = '';
  bool entireElevation = false;
  String howManySf = '';
  String additionalNotes = '';

  bool get hasAnyData =>
      substrateRepairReplacementNeeded ||
      substrateMaterialType.isNotEmpty ||
      substrateThickness.isNotEmpty ||
      entireElevation ||
      howManySf.trim().isNotEmpty ||
      additionalNotes.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'substrateRepairReplacementNeeded': substrateRepairReplacementNeeded,
        'substrateMaterialType': substrateMaterialType,
        'substrateThickness': substrateThickness,
        'entireElevation': entireElevation,
        'howManySf': howManySf,
        'additionalNotes': additionalNotes,
      };

  factory SubstrateData.fromJson(Map<String, dynamic> j) => SubstrateData()
    ..substrateRepairReplacementNeeded =
        j['substrateRepairReplacementNeeded'] as bool? ?? false
    ..substrateMaterialType = j['substrateMaterialType'] as String? ?? ''
    ..substrateThickness = j['substrateThickness'] as String? ?? ''
    ..entireElevation = j['entireElevation'] as bool? ?? false
    ..howManySf = j['howManySf'] as String? ?? ''
    ..additionalNotes = j['additionalNotes'] as String? ?? '';
}

// ============================================================================
// EIFS / External Insulation Finishing System
// ============================================================================
class EifsData {
  EifsData();

  bool present = false;

  // Scope of work — mutually exclusive in UI.
  bool wholeReplacement = false;
  bool partialRepair = false;
  String partialRepairSf = '';

  String substrate = ''; // 'OSB' | 'Plywood' | 'CMU'
  bool? substrateRequiresReplacement; // Only for OSB / Plywood
  String finalTextureFinish = '';
  String finish = '';
  String additionalNotes = '';

  File? photo;
  File? extraPhoto;
  List<File> extraPhotos = [];

  bool get hasAnyData =>
      present ||
      wholeReplacement ||
      partialRepair ||
      partialRepairSf.trim().isNotEmpty ||
      substrate.trim().isNotEmpty ||
      substrateRequiresReplacement != null ||
      finalTextureFinish.trim().isNotEmpty ||
      finish.trim().isNotEmpty ||
      additionalNotes.trim().isNotEmpty ||
      photo != null ||
      extraPhoto != null ||
      extraPhotos.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'present': present,
        'wholeReplacement': wholeReplacement,
        'partialRepair': partialRepair,
        'partialRepairSf': partialRepairSf,
        'substrate': substrate,
        'substrateRequiresReplacement': substrateRequiresReplacement,
        'finalTextureFinish': finalTextureFinish,
        'finish': finish,
        'additionalNotes': additionalNotes,
        'photo': FileHelper.fileToPath(photo),
        'extraPhoto': FileHelper.fileToPath(extraPhoto),
        'extraPhotos': FileHelper.filesToPaths(extraPhotos).toList(),
      };

  factory EifsData.fromJson(Map<String, dynamic> j) => EifsData()
    ..present = j['present'] as bool? ?? false
    ..wholeReplacement = j['wholeReplacement'] as bool? ?? false
    ..partialRepair = j['partialRepair'] as bool? ?? false
    ..partialRepairSf = j['partialRepairSf'] as String? ?? ''
    ..substrate = j['substrate'] as String? ?? ''
    ..substrateRequiresReplacement = j['substrateRequiresReplacement'] as bool?
    ..finalTextureFinish = j['finalTextureFinish'] as String? ?? ''
    ..finish = j['finish'] as String? ?? ''
    ..additionalNotes = j['additionalNotes'] as String? ?? ''
    ..photo = FileHelper.pathToFile(j['photo'])
    ..extraPhoto = FileHelper.pathToFile(j['extraPhoto'])
    ..extraPhotos = FileHelper.pathsToFiles(j['extraPhotos']).toList();
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
  List<File> extraPhotos = [];

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
        'photo': FileHelper.fileToPath(photo),
        'extraPhoto': FileHelper.fileToPath(extraPhoto),
        'extraPhotos': FileHelper.filesToPaths(extraPhotos).toList(),
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
      ..photo = FileHelper.pathToFile(j['photo'])
      ..extraPhoto = FileHelper.pathToFile(j['extraPhoto'])
      ..extraPhotos = FileHelper.pathsToFiles(j['extraPhotos']).toList();
  }
}

class WindowEntry {
  WindowEntry();

  String windowType = '';
  String materialType = '';
  List<String> glassEfficiencySelections = [];
  List<String> componentsSelections = [];
  String componentOtherSpecify = '';
  String widthInches = '';
  String heightInches = '';
  String quantity = '';
  String scopeOfWork = '';
  bool hasShuttersInstalled = false;
  String shuttersScopeOfWork = '';
  String shuttersMaterial = '';
  String shuttersMaterialSpecify = '';
  String shuttersSize = '';
  String additionalNotes = '';
  File? photo;
  File? extraPhoto;
  List<File> extraPhotos = [];

  bool get hasAnyData =>
      windowType.isNotEmpty ||
      materialType.isNotEmpty ||
      glassEfficiencySelections.isNotEmpty ||
      componentsSelections.isNotEmpty ||
      componentOtherSpecify.isNotEmpty ||
      widthInches.isNotEmpty ||
      heightInches.isNotEmpty ||
      quantity.isNotEmpty ||
      scopeOfWork.isNotEmpty ||
      hasShuttersInstalled ||
      shuttersScopeOfWork.isNotEmpty ||
      shuttersMaterial.isNotEmpty ||
      shuttersSize.isNotEmpty ||
      additionalNotes.isNotEmpty ||
      photo != null ||
      extraPhoto != null ||
      extraPhotos.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'windowType': windowType,
        'materialType': materialType,
        'glassEfficiencySelections': glassEfficiencySelections,
        'componentsSelections': componentsSelections,
        'componentOtherSpecify': componentOtherSpecify,
        'widthInches': widthInches,
        'heightInches': heightInches,
        'quantity': quantity,
        'scopeOfWork': scopeOfWork,
        'hasShuttersInstalled': hasShuttersInstalled,
        'shuttersScopeOfWork': shuttersScopeOfWork,
        'shuttersMaterial': shuttersMaterial,
        'shuttersMaterialSpecify': shuttersMaterialSpecify,
        'shuttersSize': shuttersSize,
        'additionalNotes': additionalNotes,
        'photo': FileHelper.fileToPath(photo),
        'extraPhoto': FileHelper.fileToPath(extraPhoto),
        'extraPhotos': FileHelper.filesToPaths(extraPhotos).toList(),
      };

  factory WindowEntry.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k] as String? ?? '';
    bool b(String k) => j[k] as bool? ?? false;
    List<String> list(String k) =>
        ((j[k] as List?) ?? []).whereType<String>().toList();

    return WindowEntry()
      ..windowType = s('windowType')
      ..materialType = s('materialType')
      ..glassEfficiencySelections = list('glassEfficiencySelections')
      ..componentsSelections = list('componentsSelections')
      ..componentOtherSpecify = s('componentOtherSpecify')
      ..widthInches = s('widthInches')
      ..heightInches = s('heightInches')
      ..quantity = s('quantity')
      ..scopeOfWork = s('scopeOfWork')
      ..hasShuttersInstalled = b('hasShuttersInstalled')
      ..shuttersScopeOfWork = s('shuttersScopeOfWork')
      ..shuttersMaterial = s('shuttersMaterial')
      ..shuttersMaterialSpecify = j['shuttersMaterialSpecify'] ?? ''
      ..shuttersSize = s('shuttersSize')
      ..additionalNotes = s('additionalNotes')
      ..photo = FileHelper.pathToFile(j['photo'])
      ..extraPhoto = FileHelper.pathToFile(j['extraPhoto'])
      ..extraPhotos = FileHelper.pathsToFiles(j['extraPhotos']).toList();
  }
}

class DoorEntry {
  DoorEntry();

  String doorType = '';
  File? photo;
  File? extraPhoto;
  List<File> extraPhotos = [];

  // Exterior Door / Entry Door
  String entryDoorType = '';
  String entryMaterial = '';
  String entryStyle = '';
  bool isFrenchDoor = false;
  String entryScopeOfWork = '';
  bool hasLite = false;
  String liteType = '';
  String liteScopeOfWork = '';
  bool hasScreen = false;
  String screenScopeOfWork = '';
  String entryQuantity = '';

  // Sliding Patio Door
  String patioMaterial = '';
  String patioAluminumFinish = '';
  String patioStyle = '';
  String patioSize = '';
  String patioScopeOfWork = '';

  // Garage Door
  String garageStyle = '';
  bool garageWithWindows = false;
  String garageWindowsCount = '';
  String garageDoorSize = '';
  String garageScopeOfWork = '';
  String garagePanelSectionCount = '';

  // Roll-up Door
  String rollupGauge = '';
  String rollupGaugeOtherSpecify = '';
  String rollupSize = '';
  String rollupSizeOtherSpecify = '';
  String rollupScopeOfWork = '';

  // Storefront door
  bool storefrontSlidingDoor = false;
  bool storefrontOversize = false;
  String storefrontOversizeInputSize = '';
  String storefrontType = '';
  bool storefrontCurved = false;
  String storefrontScopeOfWork = '';

  String additionalNotes = '';

  bool get hasAnyData =>
      doorType.isNotEmpty ||
      photo != null ||
      extraPhoto != null ||
      extraPhotos.isNotEmpty ||
      entryDoorType.isNotEmpty ||
      entryMaterial.isNotEmpty ||
      entryStyle.isNotEmpty ||
      isFrenchDoor ||
      entryScopeOfWork.isNotEmpty ||
      hasLite ||
      liteType.isNotEmpty ||
      liteScopeOfWork.isNotEmpty ||
      hasScreen ||
      screenScopeOfWork.isNotEmpty ||
      entryQuantity.isNotEmpty ||
      patioMaterial.isNotEmpty ||
      patioAluminumFinish.isNotEmpty ||
      patioStyle.isNotEmpty ||
      patioSize.isNotEmpty ||
      patioScopeOfWork.isNotEmpty ||
      garageStyle.isNotEmpty ||
      garageWithWindows ||
      garageWindowsCount.isNotEmpty ||
      garageDoorSize.isNotEmpty ||
      garageScopeOfWork.isNotEmpty ||
      garagePanelSectionCount.isNotEmpty ||
      rollupGauge.isNotEmpty ||
      rollupGaugeOtherSpecify.isNotEmpty ||
      rollupSize.isNotEmpty ||
      rollupSizeOtherSpecify.isNotEmpty ||
      rollupScopeOfWork.isNotEmpty ||
      storefrontSlidingDoor ||
      storefrontOversize ||
      storefrontOversizeInputSize.isNotEmpty ||
      storefrontType.isNotEmpty ||
      storefrontCurved ||
      storefrontScopeOfWork.isNotEmpty ||
      additionalNotes.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'doorType': doorType,
        'photo': FileHelper.fileToPath(photo),
        'extraPhoto': FileHelper.fileToPath(extraPhoto),
        'extraPhotos': FileHelper.filesToPaths(extraPhotos).toList(),
        'entryDoorType': entryDoorType,
        'entryMaterial': entryMaterial,
        'entryStyle': entryStyle,
        'isFrenchDoor': isFrenchDoor,
        'entryScopeOfWork': entryScopeOfWork,
        'hasLite': hasLite,
        'liteType': liteType,
        'liteScopeOfWork': liteScopeOfWork,
        'hasScreen': hasScreen,
        'screenScopeOfWork': screenScopeOfWork,
        'entryQuantity': entryQuantity,
        'patioMaterial': patioMaterial,
        'patioAluminumFinish': patioAluminumFinish,
        'patioStyle': patioStyle,
        'patioSize': patioSize,
        'patioScopeOfWork': patioScopeOfWork,
        'garageStyle': garageStyle,
        'garageWithWindows': garageWithWindows,
        'garageWindowsCount': garageWindowsCount,
        'garageDoorSize': garageDoorSize,
        'garageScopeOfWork': garageScopeOfWork,
        'garagePanelSectionCount': garagePanelSectionCount,
        'rollupGauge': rollupGauge,
        'rollupGaugeOtherSpecify': rollupGaugeOtherSpecify,
        'rollupSize': rollupSize,
        'rollupSizeOtherSpecify': rollupSizeOtherSpecify,
        'rollupScopeOfWork': rollupScopeOfWork,
        'storefrontSlidingDoor': storefrontSlidingDoor,
        'storefrontOversize': storefrontOversize,
        'storefrontOversizeInputSize': storefrontOversizeInputSize,
        'storefrontType': storefrontType,
        'storefrontCurved': storefrontCurved,
        'storefrontScopeOfWork': storefrontScopeOfWork,
        'additionalNotes': additionalNotes,
      };

  factory DoorEntry.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k] as String? ?? '';
    bool b(String k) => j[k] as bool? ?? false;

    final storedDoorType = s('doorType');
    final normalizedDoorType = storedDoorType == 'Exterior Door / Entry Door Type'
        ? 'Exterior Door / Entry Door'
        : storedDoorType;

    return DoorEntry()
      ..doorType = normalizedDoorType
      ..photo = FileHelper.pathToFile(j['photo'])
      ..extraPhoto = FileHelper.pathToFile(j['extraPhoto'])
      ..extraPhotos = FileHelper.pathsToFiles(j['extraPhotos']).toList()
      ..entryDoorType = s('entryDoorType')
      ..entryMaterial = s('entryMaterial')
      ..entryStyle = s('entryStyle')
      ..isFrenchDoor = b('isFrenchDoor')
      ..entryScopeOfWork = s('entryScopeOfWork')
      ..hasLite = b('hasLite')
      ..liteType = s('liteType')
      ..liteScopeOfWork = s('liteScopeOfWork')
      ..hasScreen = b('hasScreen')
      ..screenScopeOfWork = s('screenScopeOfWork')
      ..entryQuantity = s('entryQuantity')
      ..patioMaterial = s('patioMaterial')
      ..patioAluminumFinish = s('patioAluminumFinish')
      ..patioStyle = s('patioStyle')
      ..patioSize = s('patioSize')
      ..patioScopeOfWork = s('patioScopeOfWork')
      ..garageStyle = s('garageStyle')
      ..garageWithWindows = b('garageWithWindows')
      ..garageWindowsCount = s('garageWindowsCount')
      ..garageDoorSize = s('garageDoorSize')
      ..garageScopeOfWork = s('garageScopeOfWork')
      ..garagePanelSectionCount = s('garagePanelSectionCount')
      ..rollupGauge = s('rollupGauge')
      ..rollupGaugeOtherSpecify = s('rollupGaugeOtherSpecify')
      ..rollupSize = s('rollupSize')
      ..rollupSizeOtherSpecify = s('rollupSizeOtherSpecify')
      ..rollupScopeOfWork = s('rollupScopeOfWork')
      ..storefrontSlidingDoor = b('storefrontSlidingDoor')
      ..storefrontOversize = b('storefrontOversize')
      ..storefrontOversizeInputSize = s('storefrontOversizeInputSize')
      ..storefrontType = s('storefrontType')
      ..storefrontCurved = b('storefrontCurved')
      ..storefrontScopeOfWork = s('storefrontScopeOfWork')
      ..additionalNotes = s('additionalNotes');
  }
}

class AccessoryEntry {
  AccessoryEntry();

  String accessoryType = '';
  String accessoryOtherSpecify = '';
  String scopeOfWork = '';
  String count = '';
  String additionalNotes = '';
  File? photo;
  File? extraPhoto;
  List<File> extraPhotos = [];

  bool get hasAnyData =>
      accessoryType.isNotEmpty ||
      accessoryOtherSpecify.isNotEmpty ||
      scopeOfWork.isNotEmpty ||
      count.isNotEmpty ||
      additionalNotes.isNotEmpty ||
      photo != null ||
      extraPhoto != null ||
      extraPhotos.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'accessoryType': accessoryType,
        'accessoryOtherSpecify': accessoryOtherSpecify,
        'scopeOfWork': scopeOfWork,
        'count': count,
        'additionalNotes': additionalNotes,
        'photo': FileHelper.fileToPath(photo),
        'extraPhoto': FileHelper.fileToPath(extraPhoto),
        'extraPhotos': FileHelper.filesToPaths(extraPhotos).toList(),
      };

  factory AccessoryEntry.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k] as String? ?? '';
    return AccessoryEntry()
      ..accessoryType = s('accessoryType')
      ..accessoryOtherSpecify = s('accessoryOtherSpecify')
      ..scopeOfWork = s('scopeOfWork')
      ..count = s('count')
      ..additionalNotes = s('additionalNotes')
      ..photo = FileHelper.pathToFile(j['photo'])
      ..extraPhoto = FileHelper.pathToFile(j['extraPhoto'])
      ..extraPhotos = FileHelper.pathsToFiles(j['extraPhotos']).toList();
  }
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
        underlayment.hasAnyData ||
        substrate.hasAnyData ||
        eifs.hasAnyData;
  }

  Map<String, dynamic> toJson() => {
        'side': side.toJson(),
        'overviewPhoto': FileHelper.fileToPath(overviewPhoto), // Usando FileHelper
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
    // 1. Instanciamos el objeto 'b'
    final b = BuildingElevation(
      ElevationSide.fromJson(j['side'] as Map<String, dynamic>),
    )
      ..overviewPhoto = FileHelper.pathToFile(j['overviewPhoto']) // Usando FileHelper
      ..siding = SidingDamagesData.fromJson(
          (j['siding'] as Map?)?.cast<String, dynamic>() ?? {})
      ..underlayment = UnderlaymentInsulationData.fromJson(
          (j['underlayment'] as Map?)?.cast<String, dynamic>() ?? {})
      ..substrate = SubstrateData.fromJson(
          (j['substrate'] as Map?)?.cast<String, dynamic>() ?? {})
      ..eifs = EifsData.fromJson(
          (j['eifs'] as Map?)?.cast<String, dynamic>() ?? {})
      ..notes = j['notes'] as String? ?? '';

    // 2. Asignamos las listas
    b.trims = List<TrimEntry>.from(
      ((j['trims'] as List?) ?? []).map((e) => TrimEntry.fromJson((e as Map).cast<String, dynamic>()))
    );
    b.windows = List<WindowEntry>.from(
      ((j['windows'] as List?) ?? []).map((e) => WindowEntry.fromJson((e as Map).cast<String, dynamic>()))
    );
    b.doors = List<DoorEntry>.from(
      ((j['doors'] as List?) ?? []).map((e) => DoorEntry.fromJson((e as Map).cast<String, dynamic>()))
    );
    b.accessories = List<AccessoryEntry>.from(
      ((j['accessories'] as List?) ?? []).map((e) => AccessoryEntry.fromJson((e as Map).cast<String, dynamic>()))
    );

    // 3. RETORNO OBLIGATORIO (Soluciona el error del null)
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
