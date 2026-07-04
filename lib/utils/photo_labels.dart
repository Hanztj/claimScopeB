String buildCommercialPhotoLabel({
  required String building,
  required String roof,
  required String label,
}) {
  return 'Bldg=$building|Roof=$roof|Label=$label';
}

({String building, String roof, String label})? tryParseCommercialPhotoLabel(
  String input,
) {
  final raw = input.trim();
  if (!raw.startsWith('Bldg=')) return null;

  final parts = raw.split('|');
  String? b;
  String? r;
  String? l;

  for (final p in parts) {
    final idx = p.indexOf('=');
    if (idx <= 0) continue;
    final key = p.substring(0, idx);
    final val = p.substring(idx + 1);

    if (key == 'Bldg') b = val;
    if (key == 'Roof') r = val;
    if (key == 'Label') l = val;
  }

  if (b == null || r == null || l == null) return null;
  return (building: b, roof: r, label: l);
}

// === Elevations photo labels (Paso 4.5b) ===============================
String buildElevationsPhotoLabel({
  required String elev,
  required String category,
  required String label,
}) {
  return 'Elev=$elev|Cat=$category|Label=$label';
}

({String elev, String category, String label})? tryParseElevationsPhotoLabel(
  String input,
) {
  final raw = input.trim();
  if (!raw.startsWith('Elev=')) return null;

  final parts = raw.split('|');
  String? e;
  String? c;
  String? l;

  for (final p in parts) {
    final idx = p.indexOf('=');
    if (idx <= 0) continue;
    final key = p.substring(0, idx);
    final val = p.substring(idx + 1);

    if (key == 'Elev') e = val;
    if (key == 'Cat') c = val;
    if (key == 'Label') l = val;
  }

  if (e == null || c == null || l == null) return null;
  return (elev: e, category: c, label: l);
}

String formatElevationsPhotoCaption(String raw) {
  final parsed = tryParseElevationsPhotoLabel(raw);
  if (parsed == null) return raw;

  if (parsed.elev == 'Global') {
    return '${parsed.category} - ${parsed.label}';
  }

  return '${parsed.elev} Elev. - ${parsed.category} - ${parsed.label}';
}
// =======================================================================

String sanitizeZipPathPart(String input) {
  var s = input.trim();
  if (s.isEmpty) return 'UNKNOWN';

  // Avoid path traversal + platform-invalid characters.
  s = s.replaceAll(RegExp(r'[\\/\:\*\?"<>\|]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.isEmpty ? 'UNKNOWN' : s;
}
