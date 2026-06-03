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

CommercialVentFieldConfig commercialVentConfigForType(String? type) {
  if (type == null) return const CommercialVentFieldConfig();
  return commercialVentConfigByType[type] ?? const CommercialVentFieldConfig();
}