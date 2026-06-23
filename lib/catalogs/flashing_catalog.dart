class FlashingFieldConfig {
  final String key;
  final String label;
  final List<String> options;

  const FlashingFieldConfig({
    required this.key,
    required this.label,
    required this.options,
  });
}

const Map<String, List<FlashingFieldConfig>> residentialFlashingFieldsByType = {
  'Step flashing': [
    FlashingFieldConfig(
      key: 'material',
      label: 'Material',
      options: ['Metal', 'Copper'],
    ),
  ],
  'Ridge flashing': [
    FlashingFieldConfig(
      key: 'material',
      label: 'Material',
      options: ['Metal', 'Copper'],
    ),
  ],
  'Counter/Apron flashing': [
    FlashingFieldConfig(
      key: 'material',
      label: 'Material',
      options: ['Standard', 'Copper'],
    ),
  ],
  'Wide flashing': [
    FlashingFieldConfig(
      key: 'size',
      label: 'Size',
      options: ['14"', '20"'],
    ),
    FlashingFieldConfig(
      key: 'material',
      label: 'Material',
      options: ['Standard', 'Copper'],
    ),
  ],
  'Sidewall/Endwall flashing': [
    FlashingFieldConfig(
      key: 'finish',
      label: 'Finish',
      options: ['Mill finish', 'Color finish'],
    ),
  ],
  'L flashing': [
    FlashingFieldConfig(
      key: 'material',
      label: 'Material / Finish',
      options: ['Galvanized', 'Color finish'],
    ),
  ],
  'Hip/ridge cap for metal roofing'
  'Steel rake/gable trim': [
    FlashingFieldConfig(
      key: 'finish',
      label: 'Finish',
      options: ['Mill finish', 'Color finish'],
    ),
  ],
  'Eave trim for metal roofing': [
    FlashingFieldConfig(
      key: 'size',
      label: 'Size',
      options: ['26 gauge', '29 gauge', 'Other'],
    ),
  ],
  'Sidewall flashing for metal roofing': [
    FlashingFieldConfig(
      key: 'size',
      label: 'Size',
      options: ['26 gauge', '29 gauge', 'Other'],
    ),
  ],
  'Endwall flashing for metal roofing': [
    FlashingFieldConfig(
      key: 'size',
      label: 'Size',
      options: ['26 gauge', '29 gauge', 'Other'],
    ),
  ],
  'Pitch transition flashing for metal roofing': [
    FlashingFieldConfig(
      key: 'size',
      label: 'Size',
      options: ['26 gauge', '29 gauge', 'Other'],
    ),
  ],
  'Closure strips for metal roofing - inside and/or outside'
  'Chimney flashing': [
    FlashingFieldConfig(
      key: 'size',
      label: 'Size',
      options: ['Average (32"-36")', 'Small (24"-24")', 'Large (32"-60")'],
    ),
    FlashingFieldConfig(
      key: 'material',
      label: 'Material',
      options: ['Metal', 'Copper'],
    ),
  ],
  'Roof window step flashing kit': [
    FlashingFieldConfig(
      key: 'size',
      label: 'Size',
      options: ['Standard', 'Large'],
    ),
  ],
  'Skylight flashing kit (dome)': [
    FlashingFieldConfig(
      key: 'size',
      label: 'Size',
      options: ['Average', 'Large'],
    ),
    FlashingFieldConfig(
      key: 'grade',
      label: 'Grade',
      options: ['Standard', 'High grade'],
    ),
  ],
};

List<FlashingFieldConfig> flashingFieldsForResidentialType(String? type) {
  if (type == null) return const [];
  return residentialFlashingFieldsByType[type] ?? const [];
}
