// lib/catalogs/commercial_flashing_catalog.dart

import 'package:claimscope_clean/catalogs/roof_components_catalog.dart';

class CommercialFlashingFieldConfig {
  final List<String> options;
  final bool showLfCount;
  final bool showCount;
  final bool showFullPerimeter;
  final bool showOtherSpecify;
  final List<String> materialOptions;
  final List<String> gradeOptions;
  final List<String> finishOptions;

  const CommercialFlashingFieldConfig({
    this.options = const [],
    this.showLfCount = false,
    this.showCount = false,
    this.showFullPerimeter = false,
    this.showOtherSpecify = false,
    this.materialOptions = const [],
    this.gradeOptions = const [],
    this.finishOptions = const [],
  });
}

// ============================================================
// LEGACY (TPO) — mantener intacto, lo siguen usando archivos antiguos.
// ============================================================
const List<String> tpoFlashingTypes = [
  'Parapet Wall',
  'Curb flashing',
  'Cap flashing',
  'Metal Z Flashing',
  'Metal Z flashing / drip cap',
  'Skylight flashing kit (dome)',
  'Skylight step flashing kit',
  'Wall coping clay',
  'Other',
];

const List<String> capFlashingMaterials = ['Steel', 'Copper'];
const List<String> skylightGrades = ['Average', 'High Grade'];

const Map<String, CommercialFlashingFieldConfig> tpoFlashingConfigByType = {
  'Parapet Wall': CommercialFlashingFieldConfig(
   options: ['Up to 3\'', '3\' up to 6\''],
   showFullPerimeter: true,
  ),
  'Curb flashing': CommercialFlashingFieldConfig(
    showLfCount: true,
  ),
  'Cap flashing': CommercialFlashingFieldConfig(
    options: ['Average', 'Large'],
    materialOptions: capFlashingMaterials,
    showFullPerimeter: true,
  ),
  'Metal Z Flashing': CommercialFlashingFieldConfig(
    showFullPerimeter: true,
  ),
  'Metal Z flashing / drip cap': CommercialFlashingFieldConfig(
    showFullPerimeter: true,
  ),

  'Skylight flashing kit (dome)': CommercialFlashingFieldConfig(
    options: ['Average', 'Large'],
    gradeOptions: skylightGrades,
    showCount: true,
  ),
  'Skylight step flashing kit': CommercialFlashingFieldConfig(
    options: ['Up to 5 sf', '5.1 to 12 sf', '12.1 sf or greater'],
    showCount: true,
  ),
  'Wall coping clay': CommercialFlashingFieldConfig(
    options: ['9"', '13"', '18"'],
    showFullPerimeter: true,
  ),
  'Other': CommercialFlashingFieldConfig(
    showOtherSpecify: true,
    showCount: true,
  ),
};

// ============================================================
// NUEVO — API genérica por tipo de techo (Phase 1).
// TPO / EPDM / Modified Bitumen comparten el mismo set actual.
// Para agregar Tile / Slate en próximas fases: añadir una entrada
// nueva en ambos mapas. Si el roofType no está mapeado, cae a TPO.
// ============================================================
// ============================================================
// METAL (commercial) — reusa la lista de flashings de residential Metal.
// Solo 'Other' tiene config con showOtherSpecify; el resto cae a default
// (CommercialFlashingFieldConfig()) → solo type + photo, igual que
// el patrón que ya usa CommercialFlashingsSection en flat.
// ============================================================
// SubTypes 1:1 con residentialFlashingFieldsByType para tipos Metal.
// 'finishOptions' guarda en flashing.material (sin tocar modelo).
const Map<String, CommercialFlashingFieldConfig> metalFlashingConfigByType = {
  'Step flashing': CommercialFlashingFieldConfig(
    materialOptions: ['Metal', 'Copper'],
  ),
  'L flashing': CommercialFlashingFieldConfig(
    materialOptions: ['Galvanized', 'Color finish'],
  ),
  'Steel rake/gable trim': CommercialFlashingFieldConfig(
    finishOptions: ['Mill finish', 'Color finish'],
  ),
  'Eave trim for metal roofing': CommercialFlashingFieldConfig(
    options: ['26 gauge', '29 gauge', 'Other'],
    showOtherSpecify: true,
  ),
  'Sidewall flashing for metal roofing': CommercialFlashingFieldConfig(
    options: ['26 gauge', '29 gauge', 'Other'],
    showOtherSpecify: true,
  ),
  'Endwall flashing for metal roofing': CommercialFlashingFieldConfig(
    options: ['26 gauge', '29 gauge', 'Other'],
    showOtherSpecify: true,
  ),
  'Pitch transition flashing for metal roofing': CommercialFlashingFieldConfig(
    options: ['26 gauge', '29 gauge', 'Other'],
    showOtherSpecify: true,
  ),
  'Chimney flashing': CommercialFlashingFieldConfig(
    options: ['Small', 'Average', 'Large'],
    materialOptions: ['Metal', 'Copper'],
  ),
  'Roof window step flashing kit': CommercialFlashingFieldConfig(
    options: ['Standard', 'Large'],
  ),
  'Skylight flashing kit (dome)': CommercialFlashingFieldConfig(
    options: ['Average', 'Large'],
    gradeOptions: ['Standard', 'High grade'],
  ),
  'Other': CommercialFlashingFieldConfig(
    showOtherSpecify: true,
  ),
};

const Map<String, List<String>> commercialFlashingTypesByRoof = {
  'TPO': tpoFlashingTypes,
  'EPDM': tpoFlashingTypes,
  'Modified Bitumen': tpoFlashingTypes,
  'Metal': flashingTypesMetal,
};

const Map<String, Map<String, CommercialFlashingFieldConfig>>
    commercialFlashingConfigByRoof = {
  'TPO': tpoFlashingConfigByType,
  'EPDM': tpoFlashingConfigByType,
  'Modified Bitumen': tpoFlashingConfigByType,
  'Metal': metalFlashingConfigByType,
};

List<String> commercialFlashingTypesForRoof(String? roofType) {
  if (roofType == null) return tpoFlashingTypes;
  return commercialFlashingTypesByRoof[roofType] ?? tpoFlashingTypes;
}

CommercialFlashingFieldConfig commercialFlashingConfigForRoof(
    String? roofType, String? type) {
  if (type == null) return const CommercialFlashingFieldConfig();
  final map = (roofType == null
      ? tpoFlashingConfigByType
      : commercialFlashingConfigByRoof[roofType] ?? tpoFlashingConfigByType);
  return map[type] ?? const CommercialFlashingFieldConfig();
}
