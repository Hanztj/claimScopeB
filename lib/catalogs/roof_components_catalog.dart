const List<String> ventTypesShingles = [
  'Turtle vent Metal',
  'Turtle vent Plastic',
  'Pipe jack',
  'Exhaust through the roof up to 4”',
  'Exhaust through the roof 6” to 8”',
  'Off ridge type 2”',
  'Off ridge type 4”',
  'Power attic vent',
  'Furnace Vent 5”',
  'Furnace Vent 6”',
  'Furnace Vent 8”',
  'Turbine type',
  'Other',
];

const List<String> flashingTypesShingles = [
  'Step flashing',
  'Flashing kick-out divert',
  'Ridge flashing',
  'Counter/Apron flashing',
  'Wide flashing',
  'Sidewall/Endwall flashing',
  'L flashing',
  'Chimney flashing',
  'Roof window step flashing kit',
  'Skylight flashing kit (dome)',
  'Other',
];

// Initial implementation: all residential roof types reuse the Shingles lists.
// We can safely prune/adjust per type later.
const Map<String, List<String>> ventTypesByRoofType = {
  'Shingles': ventTypesShingles,
  'Tile roofing': ventTypesShingles,
  'Wood Shake': ventTypesShingles,
  'Slate Roof': ventTypesShingles,
  'Metal': ventTypesShingles,
  'TPO': ventTypesShingles,
  'Modified Bitumen': ventTypesShingles,
  'EPDM': ventTypesShingles,
  'Roll Roofing': ventTypesShingles,
  'Other': ventTypesShingles,
};

const Map<String, List<String>> flashingTypesByRoofType = {
  'Shingles': flashingTypesShingles,
  'Tile roofing': flashingTypesShingles,
  'Wood Shake': flashingTypesShingles,
  'Slate Roof': flashingTypesShingles,
  'Metal': flashingTypesShingles,
  'TPO': flashingTypesShingles,
  'Modified Bitumen': flashingTypesShingles,
  'EPDM': flashingTypesShingles,
  'Roll Roofing': flashingTypesShingles,
  'Other': flashingTypesShingles,
};

List<String> ventTypesForRoofType(String? roofType) {
  if (roofType == null) return const [];
  return ventTypesByRoofType[roofType] ?? ventTypesShingles;
}

List<String> flashingTypesForRoofType(String? roofType) {
  if (roofType == null) return const [];
  return flashingTypesByRoofType[roofType] ?? flashingTypesShingles;
}

