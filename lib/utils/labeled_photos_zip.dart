import 'dart:io';

import 'package:archive/archive.dart';
import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/utils/photo_labels.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

String _sanitizePhotoBaseName(
  String label, {
  bool removeGenericPhotoWord = false,
})   {
  var s = label.trim();

  s = s.replaceAll(
    RegExp(r'\s*[-–—]?\s*\bmain photo\b', caseSensitive: false),
    '',
  );
  s = s.replaceAll(
    RegExp(r'\s*[-–—]?\s*\bextra photo\b', caseSensitive: false),
    '',
  );
  s = s.replaceAll(
    RegExp(r'\s*[-–—]?\s*\badditional photo\b', caseSensitive: false),
    '',
  );
  s = s.replaceAll(RegExp(r'\badditional\b', caseSensitive: false), '');

  if (removeGenericPhotoWord) {
    s = s.replaceAll(RegExp(r'\bphoto\b', caseSensitive: false), '');
  }
  
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  s = s.replaceAll(RegExp(r'[^A-Za-z0-9\-\s_]'), '');
  s = s.replaceAll(RegExp(r'_+'), '_');
  s = s.replaceAll(RegExp(r'^_+|_+$'), '');
  s = s.replaceAll(' ', '_');
  s = s.replaceAll(RegExp(r'_+'), '_');

  if (s.isEmpty) return 'Image';
  return s;
}

int _clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

List<int> _readLandscapeZipPhotoBytes(File file) {
  final originalBytes = file.readAsBytesSync();
  final decoded = img.decodeImage(originalBytes);

  if (decoded == null) {
    return originalBytes;
  }

  if (decoded.width > decoded.height) {
    return originalBytes;
  }

  final targetHeight = _clampInt(
    ((decoded.width * 3) / 4).round(),
    1,
    decoded.height,
  );
  final cropY = ((decoded.height - targetHeight) / 2).round();

  final landscapeImage = img.copyCrop(
    decoded,
    x: 0,
    y: cropY,
    width: decoded.width,
    height: targetHeight,
  );

  return img.encodeJpg(landscapeImage, quality: 85);
}

/// Creates a ZIP with labeled photos.
///
/// - If a [PhotoItem.label] matches `Bldg=...|Roof=...|Label=...`, files are
///   placed under Building/Roof folders and use Element_ImageN names.
/// - Otherwise, files are placed under the "Roof" folder.
Archive buildLabeledPhotosArchive(List<PhotoItem> items) {
  final counts = <String, int>{};
  final archive = Archive();

  for (final item in items) {
    final parsed = tryParseCommercialPhotoLabel(item.label);
    final parsedElev = tryParseElevationsPhotoLabel(item.label);

    late final String folder;
    late final String displayLabel;
    var isRoofPhoto = false;

    if (parsed != null) {
      folder =
          '${sanitizeZipPathPart(parsed.building)}/${sanitizeZipPathPart(parsed.roof)}';
      displayLabel = parsed.label;
      isRoofPhoto = true;
    } else if (parsedElev != null) {
      // ✨ CORRECCIÓN ELEVATIONS:
      final elevFolder = parsedElev.elev == 'Global'
          ? 'Global'
          : sanitizeZipPathPart(parsedElev.elev);
      
      final categoryFolder = sanitizeZipPathPart(parsedElev.category);
      folder = 'Elevations/$elevFolder/$categoryFolder';
      
      // 🔥 En vez de usar parsedElev.label (que es "Photo 1"), 
      // usamos la categoría ("Siding", "Trim") para el nombre del archivo.
      displayLabel = parsedElev.category; 
    } else {
      // ✨ CAMBIO: De 'General' a 'Roof' como preferías
      folder = 'Roof';
      displayLabel = item.label;
      isRoofPhoto = true;
    }

    final base = _sanitizePhotoBaseName(
      displayLabel,
      removeGenericPhotoWord: isRoofPhoto,
    );
    final key = '$folder/$base';
    final n = (counts[key] ?? 0) + 1;
    counts[key] = n;

    final filename = '$folder/${base}_Image$n.jpg';
    final bytes = _readLandscapeZipPhotoBytes(item.file);

    archive.addFile(ArchiveFile(filename, bytes.length, bytes));
  }

  return archive;
}

List<int> encodeZipBytes(Archive archive) {
  final zipBytes = ZipEncoder().encode(archive);
  if (zipBytes == null) {
    throw Exception('Could not generate zip.');
  }
  return zipBytes;
}

Future<File> writeZipToFile({
  required List<int> zipBytes,
  required Directory outputDir,
  required String filename,
}) async {
  final safeName = sanitizeZipPathPart(filename);
  final out = File('${outputDir.path}/$safeName');
  await out.writeAsBytes(zipBytes, flush: true);
  return out;
}
String sanitizeFilename(String input) {
  var s = input.trim();

  if (s.isEmpty) return 'UNKNOWN';

  s = s.replaceAll(RegExp(r'[\/\\\:\*\?\"\<\>\|]'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

  return s.isEmpty ? 'UNKNOWN' : s;
}

Future<File> generateLabeledPhotosZip(
  InspectionReport report,
) async {
  // Excluir imágenes de galería
  final items = report.photoReportItems.where((p) {
    return p.label.trim() != 'User Image';
  }).toList();

  final archive = buildLabeledPhotosArchive(items);

  final zipBytes = encodeZipBytes(archive);

  final claim = report.claimNumber.trim().isEmpty
      ? 'NOCLAIM'
      : sanitizeFilename(report.claimNumber);

  final insured = report.clientName.trim().isEmpty
      ? 'UNKNOWN'
      : sanitizeFilename(report.clientName);

  final dir = await getApplicationDocumentsDirectory();

  final filename =
      '$claim - $insured - Inspection Photos (ZIP).zip';

  final zipFile = await writeZipToFile(
    zipBytes: zipBytes,
    outputDir: dir,
    filename: filename,
  );

  return zipFile;
}