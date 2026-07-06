import 'package:claimscope_clean/catalogs/roof_components_catalog.dart';

class CommercialVentFieldConfig {
  final List<String> sizeOptions;
  final List<String> throatDimensionOptions;
  final List<String> shapeOptions;
  final bool showOtherSpecify;
  final bool showThroatDimensionOtherSpecify;

  const CommercialVentFieldConfig({
    this.sizeOptions = const [],
    this.throatDimensionOptions = const [],
    this.shapeOptions = const [],
    this.showOtherSpecify = false,
    this.showThroatDimensionOtherSpecify = false,
  });
}

// ============================================================
// LEGACY — mantener intacto.
// ============================================================
const List<String> commercialVentTypes = [
  'TPO Pipe jack Boot',
  'Vent Pipe High Wind Cap',
  'Furnace Vent',
  'TPO T-top Vent',
  'TPO Flat Roof Breather Vent',
  'Exhaust Vent/Cap Gooseneck',
  'Turbine vent',
  'Gravity relief/intake Ventilator',
  'Other',
];

const Map<String, CommercialVentFieldConfig> commercialVentConfigByType = {
  'Vent Pipe High Wind Cap': CommercialVentFieldConfig(
    sizeOptions: ['8"', '10"', '12"', '14"'],
  ),
  'Furnace Vent': CommercialVentFieldConfig(
    sizeOptions: ['5"', '6"', '8"'],
  ),
  'Exhaust Vent/Cap Gooseneck': CommercialVentFieldConfig(
    sizeOptions: ['8"', '12"'],
  ),
  'Gravity relief/intake Ventilator': CommercialVentFieldConfig(
    throatDimensionOptions: ['12"', '14"', '16"', '18"', '20"', '24"', '26"', 'Other'],
    shapeOptions: ['Square', 'Round', 'Hood', 'Louvered'],
    showThroatDimensionOtherSpecify: true,
  ),
  'Other': CommercialVentFieldConfig(
    showOtherSpecify: true,
  ),
};

// ============================================================
// NUEVO — API genérica por tipo de techo (Phase 1).
// ============================================================
// METAL (commercial) — reusa lista de vents de residential Metal.
// Solo 'Other' tiene config; el resto cae a default (solo type + photo).
const Map<String, CommercialVentFieldConfig> metalVentConfigByType = {
  'Other': CommercialVentFieldConfig(
    showOtherSpecify: true,
  ),
};

const Map<String, List<String>> commercialVentTypesByRoof = {
  'TPO': commercialVentTypes,
  'EPDM': commercialVentTypes,
  'Modified Bitumen': commercialVentTypes,
  'Metal': ventTypesMetal,
};

const Map<String, Map<String, CommercialVentFieldConfig>>
    commercialVentConfigByRoof = {
  'TPO': commercialVentConfigByType,
  'EPDM': commercialVentConfigByType,
  'Modified Bitumen': commercialVentConfigByType,
  'Metal': metalVentConfigByType,
};

List<String> commercialVentTypesForRoof(String? roofType) {
  if (roofType == null) return commercialVentTypes;
  return commercialVentTypesByRoof[roofType] ?? commercialVentTypes;
}

CommercialVentFieldConfig commercialVentConfigForRoof(
    String? roofType, String? type) {
  if (type == null) return const CommercialVentFieldConfig();
  final map = (roofType == null
      ? commercialVentConfigByType
      : commercialVentConfigByRoof[roofType] ?? commercialVentConfigByType);
  return map[type] ?? const CommercialVentFieldConfig();
}

