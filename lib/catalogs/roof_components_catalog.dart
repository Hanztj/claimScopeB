const List<String> ventTypesShingles = [
  'Turtle vent Metal',
  'Turtle vent Plastic',
  'Pipe T-top vent',
  'Flat tile vent',
  'Dormer type vent',
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

const List<String> ventTypesMetal = [
  'Turtle vent Metal',
  'Turtle vent Plastic',
  'Pipe jack w/Neoprene flashing for metal roofing',
  'Pipe jack aluminum lead flashing for metal roofing',
  'Exhaust through the roof up to 4”',
  'Exhaust through the roof 6” to 8”',
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

const List<String> flashingTypesMetal = [
  'Step flashing',
  'Flashing kick-out divert',
  'Hip/ridge cap for metal roofing',
  'L flashing',
  'Steel rake/gable trim',
  'Eave trim for metal roofing',
  'Sidewall flashing for metal roofing',
  'Endwall flashing for metal roofing',
  'Pitch transition flashing for metal roofing',
  'Closure strips for metal roofing - inside and/or outside',
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
  'Metal': ventTypesMetal,
  'Roll Roofing': ventTypesShingles,
  'Other': ventTypesShingles,
};

const Map<String, List<String>> flashingTypesByRoofType = {
  'Shingles': flashingTypesShingles,
  'Tile roofing': flashingTypesShingles,
  'Wood Shake': flashingTypesShingles,
  'Slate Roof': flashingTypesShingles,
  'Metal': flashingTypesMetal,
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
