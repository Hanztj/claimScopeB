/// Shared filename/path-part sanitizers for Dart-side generated artifacts.
///
/// Keep the server-side sanitizer in `functions/index.js` separate, but aligned
/// with this same rule.
String sanitizeFilename(String input, {String fallback = 'UNKNOWN'}) {
  var s = input.trim();
  if (s.isEmpty) return fallback;

  // Remove path separators and platform-invalid filename characters.
  s = s.replaceAll(RegExp(r'[\\/\:\*\?"<>\|]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  return s.isEmpty ? fallback : s;
}

String sanitizeZipPathPart(String input, {String fallback = 'UNKNOWN'}) {
  return sanitizeFilename(input, fallback: fallback);
}