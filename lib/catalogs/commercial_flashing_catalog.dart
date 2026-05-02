// lib/catalogs/commercial_flashing_catalog.dart

class CommercialFlashingFieldConfig {
  final List<String> options;
  final bool showLfCount;
  final List<String> materialOptions;
  final List<String> gradeOptions;

  const CommercialFlashingFieldConfig({
    this.options = const [],
    this.showLfCount = false,
    this.materialOptions = const [],
    this.gradeOptions = const [],
  });
}

const List<String> tpoFlashingTypes = [
  'Flash Parapet wall',
  'Curb flashing',
  'Cap flashing',
  'Skylight flashing kit (dome)',
  'Skylight Step Flashing',
];

const List<String> capFlashingMaterials = ['Metal', 'Copper', 'Steel'];
const List<String> skylightGrades = ['Standard', 'High grade'];

const Map<String, CommercialFlashingFieldConfig> tpoFlashingConfigByType = {
  'Flash Parapet wall': CommercialFlashingFieldConfig(
    options: ['Up to 3\'', 'Over 3\' up to 6\''],
  ),
  'Curb flashing': CommercialFlashingFieldConfig(
    showLfCount: true,
  ),
  'Cap flashing': CommercialFlashingFieldConfig(
    options: ['Average', 'Large'],
    materialOptions: capFlashingMaterials,
  ),
  'Skylight flashing kit (dome)': CommercialFlashingFieldConfig(
    options: ['Average', 'Large'],
    gradeOptions: skylightGrades,
  ),
  'Skylight Step Flashing': CommercialFlashingFieldConfig(
    options: ['Up to 5 sf', '5.1 to 12 sf', '12.1 sf or greater'],
  ),
};

CommercialFlashingFieldConfig commercialTpoFlashingConfigForType(String? type) {
  if (type == null) return const CommercialFlashingFieldConfig();
  return tpoFlashingConfigByType[type] ?? const CommercialFlashingFieldConfig();
}
