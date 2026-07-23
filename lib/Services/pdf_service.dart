import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/utils/commercial_photo_label_overrides.dart';
import 'package:claimscope_clean/utils/photo_labels.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_combiner/pdf_combiner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_combiner/models/merge_input.dart';

/// Downscale/recompress a photo for PDF embedding to reduce heap pressure.
/// Runs in an isolate via `compute()`. If the source is already small enough,
/// returns the original bytes untouched.
///
/// Target: max 1024px on the longer side, JPEG quality 75.
/// Skip: file already <= 1024px AND <= 300 KB.
Uint8List _downscaleForPdf(String path) {
  final file = File(path);
  final Uint8List original = file.readAsBytesSync();

  // Fast skip on small files (avoids decode cost).
  if (original.lengthInBytes <= 300 * 1024) {
    // Still need to verify dimensions cheaply; if decode fails, return as-is.
    final decoded = img.decodeImage(original);
    if (decoded == null) return original;
    final longSide =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longSide <= 1024) return original;
    // Fall through to resize path below with already-decoded image.
    return Uint8List.fromList(
      img.encodeJpg(_resizeToMax(decoded, 1024), quality: 75),
    );
  }

  final decoded = img.decodeImage(original);
  if (decoded == null) return original;
  final resized = _resizeToMax(decoded, 1024);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
}

img.Image _resizeToMax(img.Image src, int maxSide) {
  final int w = src.width;
  final int h = src.height;
  if (w <= maxSide && h <= maxSide) return src;
  if (w >= h) {
    return img.copyResize(src, width: maxSide);
  } else {
    return img.copyResize(src, height: maxSide);
  }
}

/// Palanca 1: flag global para pausar auto-savers (SharedPreferences)
/// mientras se genera un PDF pesado. Toggle en try/finally de
/// [PdfService.generateReports].
class PdfBusyFlag {
  static bool busy = false;
}

/// Logical unit used by the incremental Photo PDF cache.
///
/// Defines stable section identifiers and cache state for the incremental
/// Photo PDF pipeline and final ordered merge.
enum PhotoSectionType {
  residentialRoof,
  commercialRoof,
  elevation,
  globalElevation,
}

class PhotoSectionHashState {
  final String currentHash;
  final String? storedHash;
  final String partialPdfPath;
  final bool partialPdfExists;

  const PhotoSectionHashState({
    required this.currentHash,
    required this.storedHash,
    required this.partialPdfPath,
    required this.partialPdfExists,
  });

  bool get isDirty => !partialPdfExists || storedHash != currentHash;
}

class PhotoSection {
  final String id;
  final PhotoSectionType type;

  const PhotoSection._({
    required this.id,
    required this.type,
  });

  factory PhotoSection.residentialRoof() {
    return const PhotoSection._(
      id: 'residential_roof',
      type: PhotoSectionType.residentialRoof,
    );
  }

  factory PhotoSection.commercialRoof({
    required int buildingIndex,
    required int roofIndex,
  }) {
    assert(buildingIndex >= 0);
    assert(roofIndex >= 0);

    final buildingNumber = buildingIndex + 1;
    final roofToken = roofIndex == 0 ? 'mainroof' : 'roof${roofIndex + 1}';

    return PhotoSection._(
      id: 'building${buildingNumber}_$roofToken',
      type: PhotoSectionType.commercialRoof,
    );
  }

  factory PhotoSection.elevation({required String sideKey}) {
    final normalizedSide = _normalizePhotoCacheToken(sideKey);
    final sideToken = normalizedSide.isEmpty ? 'other' : normalizedSide;

    return PhotoSection._(
      id: '${sideToken}_elevation',
      type: PhotoSectionType.elevation,
    );
  }

  factory PhotoSection.globalElevation() {
    return const PhotoSection._(
      id: 'global_elevation',
      type: PhotoSectionType.globalElevation,
    );
  }
}

String _normalizePhotoCacheToken(String value) {
  var normalized = value.trim().toLowerCase();
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  normalized = normalized.replaceAll(RegExp(r'_+'), '_');
  return normalized.replaceAll(RegExp(r'^_|_$'), '');
}

/// Palanca 3: preset agresivo para commercial (multi-building/section aumenta
/// mucho el conteo de fotos). Target: max 800px, JPEG quality 65.
/// Skip: <=800px longSide AND <=150 KB.
Uint8List _downscaleForPdfCommercial(String path) {
  final file = File(path);
  final Uint8List original = file.readAsBytesSync();
  if (original.lengthInBytes <= 150 * 1024) {
    final decoded = img.decodeImage(original);
    if (decoded == null) return original;
    final longSide =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longSide <= 800) return original;
    return Uint8List.fromList(
      img.encodeJpg(_resizeToMax(decoded, 800), quality: 65),
    );
  }
  final decoded = img.decodeImage(original);
  if (decoded == null) return original;
  final resized = _resizeToMax(decoded, 800);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 65));
}


class _PdfPhotoItemBytes {
  final Uint8List bytes;
  final String label;

  const _PdfPhotoItemBytes({
    required this.bytes,
    required this.label,
  });
}

class PdfService {
  static const String photoCacheVersionFolder = 'photo_cache_v2';

  /// Builds a stable cache namespace for one inspection report.
  ///
  /// Keeping each report in its own directory prevents sections such as
  /// `building1_mainroof` from colliding across different inspections.
  static String buildPhotoCacheReportKey(InspectionReport report) {
    final parts = <String>[
      report.claimNumber,
      report.dateInspected,
      report.clientName,
      report.address,
    ].map(_normalizePhotoCacheToken).where((value) => value.isNotEmpty);

    final key = parts.join('_');
    return key.isEmpty ? 'unspecified_report' : key;
  }

  /// Creates and returns the versioned cache folder for one report.
  static Future<Directory> ensurePhotoCacheDirectory({
    required String reportCacheKey,
  }) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final normalizedReportKey = _normalizePhotoCacheToken(reportCacheKey);
    final safeReportKey = normalizedReportKey.isEmpty
        ? 'unspecified_report'
        : normalizedReportKey;
    final directory = Directory(
      '${supportDirectory.path}/$photoCacheVersionFolder/$safeReportKey',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<String> sectionPdfPath({
    required String reportCacheKey,
    required PhotoSection section,
  }) async {
    final directory = await ensurePhotoCacheDirectory(
      reportCacheKey: reportCacheKey,
    );
    return '${directory.path}/${section.id}.pdf';
  }

  static Future<String> sectionHashPath({
    required String reportCacheKey,
    required PhotoSection section,
  }) async {
    final directory = await ensurePhotoCacheDirectory(
      reportCacheKey: reportCacheKey,
    );
    return '${directory.path}/${section.id}.hash';
  }

  /// Builds a stable SHA-256 fingerprint for a section's photo payload.
  ///
  /// Only file identity and metadata are included: path, byte size, last
  /// modified timestamp, item order, and total count. Captions/labels are
  /// deliberately excluded so text-only edits do not invalidate image cache.
  /// Image bytes are never loaded into memory.
  static Future<String> hashSectionPhotoPayload(
    Iterable<File> photos,
  ) async {
    final entries = <Map<String, Object?>>[];
    var index = 0;

    for (final photo in photos) {
      final absolutePath = photo.absolute.path;
      var size = -1;
      var modifiedMicros = -1;

      try {
        final stat = await photo.stat();
        if (stat.type != FileSystemEntityType.notFound) {
          size = stat.size;
          modifiedMicros = stat.modified.microsecondsSinceEpoch;
        }
      } on FileSystemException {
        // Preserve a deterministic missing/unreadable marker. If a previously
        // readable file becomes unavailable, its metadata fingerprint changes.
      }

      entries.add({
        'index': index,
        'path': absolutePath,
        'size': size,
        'modifiedMicros': modifiedMicros,
      });
      index++;
    }

    final payload = jsonEncode({
      'schema': 'photo_section_hash_v1',
      'count': entries.length,
      'photos': entries,
    });

    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Evaluates whether a section cache must be regenerated.
  ///
  /// A section is dirty when its stored hash differs from the current photo
  /// payload, no hash has been stored yet, or the partial PDF is missing.
  /// This helper only inspects state; it does not generate or write a PDF/hash.
  static Future<PhotoSectionHashState> evaluateSectionHash({
    required String reportCacheKey,
    required PhotoSection section,
    required Iterable<File> photos,
  }) async {
    final currentHash = await hashSectionPhotoPayload(photos);
    final storedHash = await readSectionHash(
      reportCacheKey: reportCacheKey,
      section: section,
    );
    final pdfPath = await sectionPdfPath(
      reportCacheKey: reportCacheKey,
      section: section,
    );

    return PhotoSectionHashState(
      currentHash: currentHash,
      storedHash: storedHash,
      partialPdfPath: pdfPath,
      partialPdfExists: await File(pdfPath).exists(),
    );
  }

  static Future<String?> readSectionHash({
    required String reportCacheKey,
    required PhotoSection section,
  }) async {
    final path = await sectionHashPath(
      reportCacheKey: reportCacheKey,
      section: section,
    );
    final file = File(path);
    if (!await file.exists()) return null;

    final value = (await file.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  static Future<void> writeSectionHash({
    required String reportCacheKey,
    required PhotoSection section,
    required String hash,
  }) async {
    final path = await sectionHashPath(
      reportCacheKey: reportCacheKey,
      section: section,
    );
    await File(path).writeAsString(hash.trim(), flush: true);
  }

  static Map<String, String> _commercialPhotoPdfLabelOverrides(
    InspectionReport report,
  ) {
    return buildCommercialPhotoLabelOverrides(report);
  }

  static PhotoItem _commercialPhotoItemForPdf(
    PhotoItem item,
    Map<String, String> labelOverrides,
  ) {
    final label = labelOverrides[item.file.absolute.path];
    if (label == null || label == item.label) return item;
    return PhotoItem(file: item.file, label: label);
  }

  static List<PhotoItem> _commercialSectionPhotoItems({
    required InspectionReport report,
    required int buildingIndex,
    required int roofIndex,
    required String buildingName,
    required String roofName,
  }) {
    if (buildingIndex < 0 ||
        buildingIndex >= report.commercialBuildings.length) {
      throw RangeError.index(
        buildingIndex,
        report.commercialBuildings,
        'buildingIndex',
      );
    }

    final building = report.commercialBuildings[buildingIndex];
    if (roofIndex < 0 || roofIndex >= building.roofs.length) {
      throw RangeError.index(roofIndex, building.roofs, 'roofIndex');
    }

    String groupKey(String building, String roof) => '$building\u0000$roof';

    final acceptedGroups = <String>{
      groupKey(buildingName.trim(), roofName.trim()),
    };

    // The overview photo is required for every commercial roof section. Its
    // stored structured label gives us the original section caption group if
    // the editable roof label changed after photos were captured.
    final overviewPath = building.roofs[roofIndex].overviewPhoto?.absolute.path;
    if (overviewPath != null) {
      for (final item in report.photoReportItems) {
        if (item.file.absolute.path != overviewPath) continue;
        final parsed = tryParseCommercialPhotoLabel(item.label);
        if (parsed != null) {
          acceptedGroups.add(groupKey(parsed.building, parsed.roof));
        }
      }
    }

    final labelOverrides = _commercialPhotoPdfLabelOverrides(report);
    final sectionItems = <PhotoItem>[];
    for (final item in report.photoReportItems) {
      final parsed = tryParseCommercialPhotoLabel(item.label);
      if (parsed == null) continue;

      if (acceptedGroups.contains(groupKey(parsed.building, parsed.roof))) {
        sectionItems.add(_commercialPhotoItemForPdf(item, labelOverrides));
      }
    }

    return sectionItems;
  }

  /// Generates or reuses the cached Photo PDF for one commercial roof section.
  ///
  /// Used by Commercial `Save & Continue` and by the final merge safety net.
  /// It writes only the requested roof section's partial PDF and hash.
  static Future<File> buildPartialPhotoPdfForCommercialSection({
    required InspectionReport report,
    required int buildingIndex,
    required int roofIndex,
    required String buildingName,
    required String roofName,
  }) async {
    final wasBusy = PdfBusyFlag.busy;
    PdfBusyFlag.busy = true;

    try {
      final section = PhotoSection.commercialRoof(
        buildingIndex: buildingIndex,
        roofIndex: roofIndex,
      );
      final reportCacheKey = buildPhotoCacheReportKey(report);
      final photoItems = _commercialSectionPhotoItems(
        report: report,
        buildingIndex: buildingIndex,
        roofIndex: roofIndex,
        buildingName: buildingName,
        roofName: roofName,
      );

      if (photoItems.isEmpty) {
        throw StateError(
          'No commercial photos were found for $buildingName - $roofName.',
        );
      }

      final hashState = await evaluateSectionHash(
        reportCacheKey: reportCacheKey,
        section: section,
        photos: photoItems.map((item) => item.file),
      );

      final partialFile = File(hashState.partialPdfPath);
      if (!hashState.isDirty) return partialFile;

      final fontDataRegular =
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final fontDataBold =
          await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final pdfTheme = pw.ThemeData.withFont(
        base: pw.Font.ttf(fontDataRegular),
        bold: pw.Font.ttf(fontDataBold),
      );
      final partialPdf = pw.Document();

      for (var i = 0; i < photoItems.length; i += 2) {
        final firstPhoto = await _loadPdfPhotoItemBytes(
          photoItems[i],
          isCommercial: true,
        );
        final secondPhoto = i + 1 < photoItems.length
            ? await _loadPdfPhotoItemBytes(
                photoItems[i + 1],
                isCommercial: true,
              )
            : null;

        partialPdf.addPage(
          pw.Page(
            theme: pdfTheme,
            build: (context) => pw.Column(
              children: [
                _buildPhotoFrame(firstPhoto),
                if (secondPhoto != null) ...[
                  pw.SizedBox(height: 20),
                  _buildPhotoFrame(secondPhoto),
                ],
              ],
            ),
          ),
        );
      }

      final tempFile = File('${hashState.partialPdfPath}.tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      await tempFile.writeAsBytes(await partialPdf.save(), flush: true);

      if (await partialFile.exists()) {
        await partialFile.delete();
      }
      await tempFile.rename(partialFile.path);

      await writeSectionHash(
        reportCacheKey: reportCacheKey,
        section: section,
        hash: hashState.currentHash,
      );

      return partialFile;
    } finally {
      PdfBusyFlag.busy = wasBusy;
    }
  }

  static List<PhotoItem> _elevationPhotoItems({
    required InspectionReport report,
    required String elevationName,
  }) {
    final items = <PhotoItem>[];
    for (final item in report.photoReportItems) {
      final parsed = tryParseElevationsPhotoLabel(item.label);
      if (parsed != null && parsed.elev == elevationName) {
        items.add(item);
      }
    }
    return items;
  }

  static Future<void> _removeCachedPhotoSection({
    required String reportCacheKey,
    required PhotoSection section,
  }) async {
    final pdfPath = await sectionPdfPath(
      reportCacheKey: reportCacheKey,
      section: section,
    );
    final hashPath = await sectionHashPath(
      reportCacheKey: reportCacheKey,
      section: section,
    );

    for (final file in <File>[
      File(pdfPath),
      File('$pdfPath.tmp'),
      File(hashPath),
    ]) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<File?> _buildPartialPhotoPdfSection({
    required String reportCacheKey,
    required PhotoSection section,
    required List<PhotoItem> photoItems,
    required bool isCommercial,
    required pw.ThemeData pdfTheme,
  }) async {
    if (photoItems.isEmpty) {
      await _removeCachedPhotoSection(
        reportCacheKey: reportCacheKey,
        section: section,
      );
      return null;
    }

    final hashState = await evaluateSectionHash(
      reportCacheKey: reportCacheKey,
      section: section,
      photos: photoItems.map((item) => item.file),
    );
    final partialFile = File(hashState.partialPdfPath);
    if (!hashState.isDirty) return partialFile;

    final partialPdf = pw.Document();
    for (var i = 0; i < photoItems.length; i += 2) {
      final firstPhoto = await _loadPdfPhotoItemBytes(
        photoItems[i],
        isCommercial: isCommercial,
      );
      final secondPhoto = i + 1 < photoItems.length
          ? await _loadPdfPhotoItemBytes(
              photoItems[i + 1],
              isCommercial: isCommercial,
            )
          : null;

      partialPdf.addPage(
        pw.Page(
          theme: pdfTheme,
          build: (context) => pw.Column(
            children: [
              _buildPhotoFrame(firstPhoto),
              if (secondPhoto != null) ...[
                pw.SizedBox(height: 20),
                _buildPhotoFrame(secondPhoto),
              ],
            ],
          ),
        ),
      );
    }

    final tempFile = File('${hashState.partialPdfPath}.tmp');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    await tempFile.writeAsBytes(await partialPdf.save(), flush: true);

    if (await partialFile.exists()) {
      await partialFile.delete();
    }
    await tempFile.rename(partialFile.path);

    await writeSectionHash(
      reportCacheKey: reportCacheKey,
      section: section,
      hash: hashState.currentHash,
    );

    return partialFile;
  }

  /// Generates or reuses all cached Elevations Photo PDF sections.
  ///
  /// Global photos and every building elevation are independent cache units.
  /// Used by Elevations submit and by the final merge safety net.
  static Future<List<File>> buildPartialPhotoPdfsForElevations(
    InspectionReport report,
  ) async {
    final wasBusy = PdfBusyFlag.busy;
    PdfBusyFlag.busy = true;

    try {
      final reportCacheKey = buildPhotoCacheReportKey(report);
      final isCommercial =
          report.isCommercial == true || report.commercialBuildings.isNotEmpty;
      final fontDataRegular =
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final fontDataBold =
          await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final pdfTheme = pw.ThemeData.withFont(
        base: pw.Font.ttf(fontDataRegular),
        bold: pw.Font.ttf(fontDataBold),
      );
      final partialFiles = <File>[];

      final globalFile = await _buildPartialPhotoPdfSection(
        reportCacheKey: reportCacheKey,
        section: PhotoSection.globalElevation(),
        photoItems: _elevationPhotoItems(
          report: report,
          elevationName: 'Global',
        ),
        isCommercial: isCommercial,
        pdfTheme: pdfTheme,
      );
      if (globalFile != null) partialFiles.add(globalFile);

      for (final elevation in report.elevations.elevations) {
        final partialFile = await _buildPartialPhotoPdfSection(
          reportCacheKey: reportCacheKey,
          section: PhotoSection.elevation(sideKey: elevation.side.key),
          photoItems: _elevationPhotoItems(
            report: report,
            elevationName: elevation.side.display,
          ),
          isCommercial: isCommercial,
          pdfTheme: pdfTheme,
        );
        if (partialFile != null) partialFiles.add(partialFile);
      }

      return partialFiles;
    } finally {
      PdfBusyFlag.busy = wasBusy;
    }
  }

  static List<PhotoItem> _residentialRoofPhotoItems(
    InspectionReport report,
  ) {
    return report.photoReportItems
        .where((item) => tryParseElevationsPhotoLabel(item.label) == null)
        .toList(growable: false);
  }

  /// Generates or reuses the cached Residential roof Photo PDF section.
  ///
  /// Elevations photos are intentionally excluded because they are cached and
  /// merged as independent sections.
  static Future<File?> buildPartialPhotoPdfForResidentialRoof(
    InspectionReport report,
  ) async {
    final wasBusy = PdfBusyFlag.busy;
    PdfBusyFlag.busy = true;

    try {
      final reportCacheKey = buildPhotoCacheReportKey(report);
      final section = PhotoSection.residentialRoof();
      final photoItems = _residentialRoofPhotoItems(report);

      if (photoItems.isEmpty) {
        await _removeCachedPhotoSection(
          reportCacheKey: reportCacheKey,
          section: section,
        );
        return null;
      }

      final fontDataRegular =
          await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final fontDataBold =
          await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      final pdfTheme = pw.ThemeData.withFont(
        base: pw.Font.ttf(fontDataRegular),
        bold: pw.Font.ttf(fontDataBold),
      );

      return _buildPartialPhotoPdfSection(
        reportCacheKey: reportCacheKey,
        section: section,
        photoItems: photoItems,
        isCommercial: false,
        pdfTheme: pdfTheme,
      );
    } finally {
      PdfBusyFlag.busy = wasBusy;
    }
  }

  static Future<void> _validatePartialPhotoPdf(
    File file, {
    required String sectionName,
  }) async {
    if (!await file.exists()) {
      throw StateError('Missing Photo PDF section: $sectionName.');
    }
    if (await file.length() <= 0) {
      throw StateError('Empty Photo PDF section: $sectionName.');
    }
  }

  /// Safety net for the final Photo PDF.
  ///
  /// Every current section is re-evaluated before merge. Missing or dirty
  /// partials are regenerated, while valid cached partials are reused.
  static Future<List<File>> _buildOrderedPartialPhotoPdfsForMerge(
    InspectionReport report,
  ) async {
    final partialFiles = <File>[];
    final reportCacheKey = buildPhotoCacheReportKey(report);
    final isCommercial =
        report.isCommercial == true || report.commercialBuildings.isNotEmpty;

    if (isCommercial) {
      for (var buildingIndex = 0;
          buildingIndex < report.commercialBuildings.length;
          buildingIndex++) {
        final building = report.commercialBuildings[buildingIndex];
        final buildingName = building.displayName(buildingIndex);

        for (var roofIndex = 0;
            roofIndex < building.roofs.length;
            roofIndex++) {
          final roof = building.roofs[roofIndex];
          final roofName = (roof.roofLabel ?? '').trim().isEmpty
              ? 'Roof ${roofIndex + 1}'
              : roof.roofLabel!.trim();
          final section = PhotoSection.commercialRoof(
            buildingIndex: buildingIndex,
            roofIndex: roofIndex,
          );
          final photoItems = _commercialSectionPhotoItems(
            report: report,
            buildingIndex: buildingIndex,
            roofIndex: roofIndex,
            buildingName: buildingName,
            roofName: roofName,
          );

          if (photoItems.isEmpty) {
            await _removeCachedPhotoSection(
              reportCacheKey: reportCacheKey,
              section: section,
            );
            continue;
          }

          final partialFile =
              await buildPartialPhotoPdfForCommercialSection(
            report: report,
            buildingIndex: buildingIndex,
            roofIndex: roofIndex,
            buildingName: buildingName,
            roofName: roofName,
          );
          await _validatePartialPhotoPdf(
            partialFile,
            sectionName: '$buildingName - $roofName',
          );
          partialFiles.add(partialFile);
        }
      }
    } else {
      final residentialFile =
          await buildPartialPhotoPdfForResidentialRoof(report);
      if (residentialFile != null) {
        await _validatePartialPhotoPdf(
          residentialFile,
          sectionName: 'Residential Roof',
        );
        partialFiles.add(residentialFile);
      }
    }

    final elevationFiles = await buildPartialPhotoPdfsForElevations(report);
    for (final elevationFile in elevationFiles) {
      await _validatePartialPhotoPdf(
        elevationFile,
        sectionName: elevationFile.uri.pathSegments.last,
      );
      partialFiles.add(elevationFile);
    }

    if (partialFiles.isEmpty) {
      throw StateError(
        'No inspection photos are available to generate the Photo PDF.',
      );
    }

    return partialFiles;
  }

  static Future<void> _replaceFileSafely({
    required File preparedFile,
    required File destinationFile,
  }) async {
    final backupFile = File('${destinationFile.path}.previous');
    if (await backupFile.exists()) {
      if (!await destinationFile.exists()) {
        await backupFile.rename(destinationFile.path);
      } else {
        await backupFile.delete();
      }
    }

    var previousMoved = false;
    try {
      if (await destinationFile.exists()) {
        await destinationFile.rename(backupFile.path);
        previousMoved = true;
      }

      await preparedFile.rename(destinationFile.path);

      if (previousMoved && await backupFile.exists()) {
        await backupFile.delete();
      }
    } catch (_) {
      if (await destinationFile.exists()) {
        await destinationFile.delete();
      }
      if (previousMoved && await backupFile.exists()) {
        await backupFile.rename(destinationFile.path);
      }
      rethrow;
    }
  }

  static Future<void> _mergePartialPhotoPdfs({
    required List<File> partialFiles,
    required File outputFile,
  }) async {
    if (partialFiles.isEmpty) {
      throw StateError('Cannot merge an empty Photo PDF section list.');
    }

    for (final partialFile in partialFiles) {
      await _validatePartialPhotoPdf(
        partialFile,
        sectionName: partialFile.uri.pathSegments.last,
      );
    }

    final tempFile = File('${outputFile.path}.merge.tmp.pdf');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    try {
      if (partialFiles.length == 1) {
        await partialFiles.single.copy(tempFile.path);
      } else {
        final mergedPath = await PdfCombiner.mergeMultiplePDFs(
          inputs: partialFiles
              .map((file) => MergeInput.path(file.absolute.path))
              .toList(growable: false),
          outputPath: tempFile.absolute.path,
        );

        final pluginOutput = File(mergedPath);
        if (pluginOutput.absolute.path != tempFile.absolute.path &&
            await pluginOutput.exists()) {
          await pluginOutput.copy(tempFile.path);
        }
      }

      if (!await tempFile.exists() || await tempFile.length() <= 0) {
        throw StateError('The merged Photo PDF was not created correctly.');
      }

      await _replaceFileSafely(
        preparedFile: tempFile,
        destinationFile: outputFile,
      );
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  static Future<Map<String, File>> generateReports(InspectionReport report) async {
    // Palanca 1: pausar auto-savers durante la generación pesada.
    PdfBusyFlag.busy = true;
    try {

    // 1️⃣ CARGAR FUENTES DESDE ASSETS (Evita crasheos por caracteres como ≤)
    final fontDataRegular = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final fontDataBold = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");

    final myFontRegular = pw.Font.ttf(fontDataRegular);
    final myFontBold = pw.Font.ttf(fontDataBold);

    // 2️⃣ CREAR TEMA UNIFICADO CON LAS FUENTES NUEVAS
    final pdfTheme = pw.ThemeData.withFont(
      base: myFontRegular,
      bold: myFontBold,
    );

    // Palanca 2: pdfTech nullable para liberarlo antes del loop de fotos.
    pw.Document? pdfTech = pw.Document();
      // Determinar si es comercial
  final isCommercial = report.isCommercial == true || report.commercialBuildings.isNotEmpty;

    // Palanca 2: hoist de rutas — necesarias para escribir pdfTech
    // ANTES de encolar las fotos (libera heap del pdf técnico).
    String sanitizeFilename(String input) {
    var s = input.trim();
    if (s.isEmpty) return 'UNKNOWN';
    s = s.replaceAll(RegExp(r'[\/\\\:\*\?\"\<\>\|]'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? 'UNKNOWN' : s;
    }
    final dir = await getApplicationDocumentsDirectory();
    final claim = report.claimNumber.trim().isEmpty
        ? 'NOCLAIM'
        : sanitizeFilename(report.claimNumber);
    final insured = report.clientName.trim().isEmpty
        ? 'UNKNOWN'
        : sanitizeFilename(report.clientName);
    final techName = isCommercial
        ? '$claim - $insured - Commercial Inspection Report.pdf'
        : '$claim - $insured - Inspection Report.pdf';
    final photoName = isCommercial
        ? '$claim - $insured - Commercial Inspection Photos.pdf'
        : '$claim - $insured - Inspection Photos.pdf';
    final techFile = File('${dir.path}/$techName');
    final photoFile = File('${dir.path}/$photoName');

  if(isCommercial){
          
        // --- PDF TÉCNICO COMERCIAL ---
        pdfTech.addPage(
        pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pdfTheme,
        build: (context) => [
          _buildHeader("COMMERCIAL ROOF INSPECTION REPORT - TECHNICAL"),
          
          // SECCIÓN 1: CLIENT & CLAIM (mismo que residential)
          _buildSectionTitle("CLIENT & CLAIM INFORMATION"),
          _buildDataRow("Client Name", report.clientName),
          _buildDataRow("Client Phone", report.clientPhone),
          _buildDataRow("Client Email", report.email),
          _buildDataRow("Street Address", report.address),
          _buildDataRow("City", report.city),
          _buildDataRow("State", report.state),
          _buildDataRow("Zip Code", report.zip),
          _buildDataRow("Claim #", report.claimNumber),
          _buildDataRow("Policy #", report.policyNumber),
          _buildDataRow("Date of Loss", report.dateOfLoss),
          _buildDataRow("Insurance Co.", report.insuranceCompany),
          _buildDataRow("Type of Loss", report.typeOfLoss),
          _buildDataRow("Cause of Loss", report.causeOfLoss),
          pw.SizedBox(height: 10),

           // SECCIÓN 2: INSPECTOR (mismo que residential)
          _buildSectionTitle("INSPECTOR INFORMATION"),
          _buildDataRow("Inspector Company", report.inspectorCompany),
          _buildDataRow("Inspector Name", report.inspectorName),
          _buildDataRow("Phone", report.inspectorPhone),
          _buildDataRow("Email", report.inspectorEmail),
          _buildDataRow("Date Inspected", report.dateInspected),
          pw.SizedBox(height: 10),
 
          // SECCIÓN 3: SCOPE (mismo que residential)
          _buildSectionTitle("INSPECTION SCOPE"),
          _buildDataRow("Roof estimate", report.inspectRoof ? "Yes" : "No"),
          _buildDataRow("Elevations", report.inspectElevations ? "Yes" : "No"),
           pw.SizedBox(height: 10),

                     // SECCIÓN 4: BUILDINGS & ROOFS (comercial)
          _buildSectionTitle("BUILDINGS & ROOF SECTIONS"),
          _buildDataRow("Occupancy Type", "Commercial"),
           pw.SizedBox(height: 5),   
          
           // Listar cada edificio
           ...List.generate(report.commercialBuildings.length, (i) {
           final building = report.commercialBuildings[i];
           return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
             _buildDataRow("  Building ${i + 1} Name", building.name ?? "N/A"),
             _buildDataRow("  Building ${i + 1} Address", building.streetAddress ?? report.address),
             _buildDataRow("  Building ${i + 1} Roof Sections", building.roofs.length.toString()),
             pw.SizedBox(height: 5),
              // Listar cada roof section dentro del edificio
              ...List.generate(building.roofs.length, (j) {
                final roof = building.roofs[j];
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildDataRow("    Roof ${j + 1} Label", roof.roofLabel?? "N/A"), 
                    _buildDataRow("    Roof ${j + 1} Cover Type", roof.roofType ?? "N/A"),
                    _buildDataRow("    Roof ${j + 1} Subtype", roof.roofSubType ?? "N/A"),
                     ..._buildCommercialRoofDetails(roof),
                    pw.SizedBox(height: 3),
                  ],
                );
              }),
              pw.SizedBox(height: 10),
            ],
           );
          }),
          ..._buildElevationsUnderlaymentDetails(report),
        ],
        ),  
        );
    // Palanca 2 (commercial): guardar y liberar pdfTech antes de encolar fotos.
    await techFile.writeAsBytes(await pdfTech.save());
    pdfTech = null;
    // Photo PDF sections are generated and merged after the technical PDF.

            
  } 
  else {
       // --- PDF TÉCNICO: ORDENADO Residential---
        pdfTech.addPage(
       pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
         margin: const pw.EdgeInsets.all(32),
         theme: pdfTheme,
          build: (context) => [
          _buildHeader("TECHNICAL INSPECTION REPORT"),
          
          // SECCIÓN 1: CLIENT & CLAIM
          _buildSectionTitle("CLIENT & CLAIM INFORMATION"),
          _buildDataRow("Client Name", report.clientName),
          _buildDataRow("Client Phone", report.clientPhone),
          _buildDataRow("Client Email", report.email),
          _buildDataRow("Street Address", report.address),
          _buildDataRow("City", report.city),
          _buildDataRow("State", report.state),
          _buildDataRow("Zip Code", report.zip),
          _buildDataRow("Claim #", report.claimNumber),
          _buildDataRow("Policy #", report.policyNumber),
          _buildDataRow("Date of Loss", report.dateOfLoss),
          _buildDataRow("Insurance Co.", report.insuranceCompany),
          _buildDataRow("Type of Loss", report.typeOfLoss),
          _buildDataRow("Cause of Loss", report.causeOfLoss),
            pw.SizedBox(height: 10),

          // SECCIÓN 2: INSPECTOR
          _buildSectionTitle("INSPECTOR INFORMATION"),
          _buildDataRow("Inspector Company", report.inspectorCompany),
          _buildDataRow("Inspector Name", report.inspectorName),
          _buildDataRow("Phone", report.inspectorPhone),
          _buildDataRow("Email", report.inspectorEmail),
          _buildDataRow("Date Inspected", report.dateInspected),
          pw.SizedBox(height: 10),

               // SECCION 3: SCOPE
            _buildSectionTitle("INSPECTION SCOPE"),
            _buildDataRow("Roof estimate", report.inspectRoof ? "Yes" : "No"),
            _buildDataRow("Elevations", report.inspectElevations ? "Yes" : "No"),
             pw.SizedBox(height: 10),

                    // SECCIÓN 4: ROOF DETAILS
            ..._buildResidentialRoofDetails(report),
            ..._buildElevationsUnderlaymentDetails(report),
        ],
       ),
     );
    // Palanca 2 (residential): guardar y liberar pdfTech antes de encolar fotos.
    await techFile.writeAsBytes(await pdfTech.save());
    pdfTech = null;
                      
    // Photo PDF sections are generated and merged after the technical PDF.
    }

    final partialPhotoPdfs =
        await _buildOrderedPartialPhotoPdfsForMerge(report);
    await _mergePartialPhotoPdfs(
      partialFiles: partialPhotoPdfs,
      outputFile: photoFile,
    );

    // Palanca 2: pdfTech ya fue guardado y liberado en cada rama.
   return {'tech': techFile, 'photos': photoFile};
    } finally {
      // Palanca 1: reactivar auto-savers pase lo que pase.
      PdfBusyFlag.busy = false;
    }
    }

     
    // Retained only for Patch 6 comparison/cleanup. The final Photo PDF now
    // comes exclusively from cached section PDFs and the merge pipeline.
    // ignore: unused_element
    static Future<pw.Document> _buildMonolithicPhotoPdfLegacy({
      required InspectionReport report,
      required pw.ThemeData pdfTheme,
      required bool isCommercial,
    }) async {
      final pdfPhotos = pw.Document();

      if (isCommercial) {
        final commercialPhotoLabelOverrides =
            _commercialPhotoPdfLabelOverrides(report);
        for (var i = 0; i < report.photoReportItems.length; i += 2) {
          final firstPhoto = await _loadPdfPhotoItemBytes(
            _commercialPhotoItemForPdf(
              report.photoReportItems[i],
              commercialPhotoLabelOverrides,
            ),
            isCommercial: true,
          );
          final secondPhoto = i + 1 < report.photoReportItems.length
              ? await _loadPdfPhotoItemBytes(
                  _commercialPhotoItemForPdf(
                    report.photoReportItems[i + 1],
                    commercialPhotoLabelOverrides,
                  ),
                  isCommercial: true,
                )
              : null;

          pdfPhotos.addPage(
            pw.Page(
              theme: pdfTheme,
              build: (context) => pw.Column(
                children: [
                  _buildPhotoFrame(firstPhoto),
                  if (secondPhoto != null) ...[
                    pw.SizedBox(height: 20),
                    _buildPhotoFrame(secondPhoto),
                  ],
                ],
              ),
            ),
          );
        }
      } else {
        for (var i = 0; i < report.photoReportItems.length; i += 2) {
          final firstPhoto =
              await _loadPdfPhotoItemBytes(report.photoReportItems[i]);
          final secondPhoto = i + 1 < report.photoReportItems.length
              ? await _loadPdfPhotoItemBytes(report.photoReportItems[i + 1])
              : null;

          pdfPhotos.addPage(
            pw.Page(
              theme: pdfTheme,
              build: (context) => pw.Column(
                children: [
                  _buildPhotoFrame(firstPhoto),
                  if (secondPhoto != null) ...[
                    pw.SizedBox(height: 20),
                    _buildPhotoFrame(secondPhoto),
                  ],
                ],
              ),
            ),
          );
        }
      }

      return pdfPhotos;
    }

    static List<pw.Widget> _buildResidentialRoofDetails(InspectionReport report) {
      return [
        _buildSectionTitle("ROOF SYSTEM DETAILS"),
        _buildDataRow("Occupancy Type", "Residential"),
        _buildDataRow("Roof Cover Type", report.roofCoverType ?? "N/A"),
        _buildDataRow("Subtype", report.roofSubType ?? "N/A"),
        ..._buildResidentialHubDetails(report),
        pw.SizedBox(height: 10),
        ..._buildResidentialFacetOrSectionDetails(report),
        pw.SizedBox(height: 10),
      ];
    }

    static List<pw.Widget> _buildResidentialHubDetails(InspectionReport report) {
      if (_isRollRoofing(report.roofCoverType)) {
        return _buildResidentialRollRoofingDetails(report);
      }
      if (_isMetalRoof(report.roofCoverType)) {
        return _buildResidentialMetalDetails(report);
      }
      if (_isHeavyResidentialRoof(report.roofCoverType)) {
        return _buildResidentialHeavyRoofDetails(report);
      }
      return _buildResidentialShinglesDetails(report);
    }

    static List<pw.Widget> _buildResidentialShinglesDetails(InspectionReport report) {
      return [
        ..._buildResidentialReplacementRows(report),
        _buildDataRow(
          "Estimated Age",
          report.estimatedAge != null && report.estimatedAge! > 0
              ? "${report.estimatedAge} years"
              : "N/A"
        ),
        _buildDataRow(
          "Number of Layers",
          report.numLayers != null ? report.numLayers.toString() : "N/A",
        ),
        _buildDataRow(
          "Ice & Water Barrier",
          report.iceAndWaterBarrierInstalled ? "Yes" : "No",
        ),
        _buildDataRow(
          "Starter Row Installed",
          report.starterRowInstalled ? "Yes" : "No",
        ),
        if (report.starterRowInstalled) ...[
          _buildDataRow(
            "Starter Row at Eave",
            report.starterEaveInstalled ? "Yes" : "No",
          ),
          _buildDataRow(
            "Starter Row at Rake",
            report.starterRakeInstalled ? "Yes" : "No",
          ),
        ],
        ..._buildResidentialCommonExteriorRows(report),
      ];
    }

    static List<pw.Widget> _buildResidentialHeavyRoofDetails(InspectionReport report) {
      return [
        ..._buildResidentialReplacementRows(report),
        _buildDataRow(
          "Batten system needs to be changed",
          report.battenSystemNeedsReplacement ?? "N/A",
        ),
        _buildDataRow(
          "Ice & Water Barrier",
          report.iceAndWaterBarrierInstalled ? "Yes" : "No",
        ),
        ..._buildResidentialCommonExteriorRows(report),
      ];
    }

    static List<pw.Widget> _buildResidentialMetalDetails(InspectionReport report) {
      final gauge = report.selectedGauge == 'Other'
          ? "Other (${_textOrNA(report.metalGaugeOtherSpecify)})"
          : _textOrNA(report.selectedGauge);

      return [
        if (report.roofSubType == 'Other')
          _buildDataRow(
            "Other metal subtype",
            _textOrNA(report.metalSubTypeOtherSpecify),
          ),
        _buildDataRow("Gauge", gauge),
        _buildDataRow(
          "Does the roof have a deck",
          _yesNo(report.residentialMetalHasDeck),
        ),
        if (report.residentialMetalHasDeck == true) ...[
          _buildDataRow(
            "Deck requires replacement",
            _yesNo(report.residentialMetalDeckRequiresReplacement),
          ),
          if (report.residentialMetalDeckRequiresReplacement == true) ...[
            _buildDataRow(
              "Deck full replacement required",
              _yesNo(report.residentialMetalDeckFullReplacementRequired),
            ),
            if (report.residentialMetalDeckFullReplacementRequired != true)
              _buildDataRow(
                "Deck partial replacement (SF)",
                _textOrNA(report.residentialMetalDeckPartialReplacementSqft),
              ),
            _buildDataRow(
              "Roof support base",
              _textOrNA(report.residentialMetalRoofSupportBase),
            ),
            _buildDataRow(
              "Deck size",
              _textOrNA(report.residentialMetalDeckSize),
            ),
            _buildDataRow(
              "Ice & Water Barrier Installed",
              _yesNo(report.residentialMetalIceWaterBarrierInstalled),
            ),
            if (report.residentialMetalIceWaterBarrierInstalled == true)
              _buildDataRow(
                "Ice & Water Barrier Type",
                _textOrNA(report.residentialMetalIceWaterBarrierType),
              ),
            if (report.residentialMetalIceWaterBarrierInstalled == false)
              _buildDataRow(
                "No Ice & Water Barrier Approach",
                _textOrNA(report.residentialMetalNoIceWaterBarrierApproach),
              ),
          ],
        ],
        ..._buildResidentialAdditionalStructureRows(report),
      ];
    }

    static List<pw.Widget> _buildResidentialRollRoofingDetails(InspectionReport report) {
      return [
        _buildDataRow("Exposure", _textOrNA(report.rollExposure)),
        _buildDataRow("Number of Plies", _textOrNA(report.rollNumberOfPlies)),
        _buildDataRow("Fastening Method", _textOrNA(report.rollFasteningMethod)),
        if (report.rollFasteningMethod == 'Mechanical') ...[
          _buildDataRow(
            "Fastener Pull Test performed",
            _yesNo(report.rollFastenerPullTestPerformed),
          ),
          if (report.rollFastenerPullTestPerformed == true)
            _buildDataRow(
              "Fastener Pull Test Result",
              _textOrNA(report.rollFastenerPullTestResult),
            ),
        ],
        _buildDataRow("Underlayment Type", _textOrNA(report.rollUnderlaymentType)),
        _buildDataRow("Insulation Type", _textOrNA(report.rollInsulationType)),
        _buildDataRow("Insulation Size", _textOrNA(report.rollInsulationSize)),
        _buildDataRow(
          "Deck requires replacement",
          _yesNo(report.rollDeckRequiresReplacement),
        ),
        if (report.rollDeckRequiresReplacement == true) ...[
          _buildDataRow(
            "Deck full replacement required",
            _yesNo(report.rollDeckFullReplacementRequired),
          ),
          if (report.rollDeckFullReplacementRequired != true)
            _buildDataRow(
              "Deck partial replacement (SF)",
              _textOrNA(report.rollDeckPartialReplacementSqft),
            ),
        ],
        _buildDataRow(
          "Ice & Water Barrier",
          _yesNo(report.rollIceWaterBarrierInstalled),
        ),
        _buildDataRow(
          "Drip Edge",
          _yesNo(report.rollDripEdgeInstalled),
        ),
        if (report.rollDripEdgeInstalled == true)
          _buildDataRow("Drip Edge Type", _textOrNA(report.rollDripEdgeType)),
        _buildDataRow(
          "Gravel ballast present",
          report.rollGravelBallastPresent ? "Yes" : "No",
        ),
        ..._buildResidentialAdditionalStructureRows(report),
      ];
    }

    static List<pw.Widget> _buildResidentialReplacementRows(InspectionReport report) {
      return [
        _buildDataRow(
          "Full roof replacement required",
          report.fullRoofReplacementRequired ? "Yes" : "No",
        ),
        if (!report.fullRoofReplacementRequired)
          _buildDataRow(
            "Partial replacement (SF)",
            report.partialReplacementSqft ?? "N/A",
          ),
        _buildDataRow(
          "Sheathing replacement required",
          report.sheathingRequiredToBeChanged ? "Yes" : "No",
        ),
        if (report.sheathingRequiredToBeChanged) ...[
          _buildDataRow(
            "Sheathing full replacement required",
            report.sheathingFullReplacementRequired ? "Yes" : "No",
          ),
          if (!report.sheathingFullReplacementRequired)
            _buildDataRow(
              "Sheathing partial replacement (SF)",
              report.sheathingPartialReplacementSqft ?? "N/A",
            ),
          _buildDataRow("Sheathing type", report.sheathingType ?? "N/A"),
          _buildDataRow("Sheathing size", report.sheathingSize ?? "N/A"),
        ],
      ];
    }

    static List<pw.Widget> _buildResidentialCommonExteriorRows(InspectionReport report) {
      return [
        _buildDataRow(
          "Drip Edge",
          report.hasDripEdge ? "Yes (${report.dripEdgeType ?? 'Type N/A'})" : "No",
        ),
        ..._buildResidentialAdditionalStructureRows(report),
      ];
    }

    static List<pw.Widget> _buildResidentialAdditionalStructureRows(InspectionReport report) {
      return [
        _buildDataRow(
          "Shed requiring replacement (≤ 6 SQ)",
          report.hasShed ? "Yes" : "No",
        ),
        _buildDataRow(
          "Larger/detached structure requiring replacement",
          report.hasDetachedStructure ? "Yes" : "No",
        ),
      ];
    }

    static List<pw.Widget> _buildResidentialFacetOrSectionDetails(InspectionReport report) {
      if (_isRollRoofing(report.roofCoverType)) {
        return _buildResidentialRollRoofSectionDetails(report);
      }
      return _buildResidentialFacetDetails(report);
    }

    static List<pw.Widget> _buildResidentialFacetDetails(InspectionReport report) {
      final isHeavy = _isHeavyResidentialRoof(report.roofCoverType);
      final isMetal = _isMetalRoof(report.roofCoverType);
      final isShingles = _isShinglesRoof(report.roofCoverType);

      return [
        _buildSectionTitle("FACET BREAKDOWN"),
        if (report.facets.isEmpty)
          pw.Text(
            "No facet data recorded.",
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _buildTableCell("Facet Name", isHeader: true),
                  _buildTableCell("Orientation", isHeader: true),
                  _buildTableCell("Pitch", isHeader: true),
                ],
              ),
              ...report.facets.map(
                (facet) => pw.TableRow(
                  children: [
                    _buildTableCell(facet.name),
                    _buildTableCell(facet.orientation),
                    _buildTableCell(_formatPitch(facet.pitch)),
                  ],
                ),
              ),
            ],
          ),
        pw.SizedBox(height: 10),
        _buildSectionTitle("FACET DETAILS"),
        if (report.facets.isEmpty)
          pw.Text(
            "No facet details recorded.",
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
          )
        else
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: report.facets.map((facet) {
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Facet: ${facet.name} (${facet.orientation})",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (!isHeavy && !isMetal)
                      _buildDataRow(
                        "Ridge Vent",
                        facet.hasRidgeVent
                            ? "Yes (${facet.ridgeVentType ?? 'Type N/A'})"
                            : "No",
                      ),
                    if (isShingles) ...[
                      _buildDataRow(
                        "ATR Performed",
                        facet.atrPerformed ? "Yes" : "No",
                      ),
                      if (facet.atrPerformed)
                        _buildDataRow("ATR Result", facet.atrResult ?? "N/A"),
                    ],
                    _buildDataRow(
                      "Has Valley Metal",
                      facet.hasValleyMetal ? "Yes" : "No",
                    ),
                    if (facet.hasValleyMetal)
                      _buildDataRow(
                        "Valley Metal Type",
                        facet.valleyMetalType ?? "N/A",
                      ),
                    ..._buildResidentialFacetCommonElementRows(facet),
                    pw.SizedBox(height: 6),
                  ],
                ),
              );
            }).toList(),
          ),
      ];
    }

    static List<pw.Widget> _buildResidentialRollRoofSectionDetails(InspectionReport report) {
      return [
        _buildSectionTitle("ROOF SECTION DETAILS"),
        if (report.facets.isEmpty)
          pw.Text(
            "No roof section details recorded.",
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
          )
        else
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: report.facets.map((section) {
              final sectionName = section.name.trim().isEmpty
                  ? "Roof Section"
                  : section.name.trim();
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      sectionName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    ..._buildResidentialFacetCommonElementRows(section),
                    pw.SizedBox(height: 6),
                  ],
                ),
              );
            }).toList(),
          ),
      ];
    }

    static List<pw.Widget> _buildResidentialFacetCommonElementRows(FacetData facet) {
      return [
        if (facet.flashings.isEmpty)
          _buildDataRow("Flashings", "None recorded")
        else ...[
          _buildDataRow("Flashings", ""),
          ...facet.flashings.map((f) => _buildDataRow(
                "  - ${_describeFlashing(f)}",
                "Should be changed: ${f.shouldBeChanged ? 'Yes' : 'No'}",
              )),
        ],
        if (facet.vents.isEmpty)
          _buildDataRow("Vents", "None recorded")
        else ...[
          _buildDataRow("Vents", ""),
          ...facet.vents.map((v) => _buildDataRow(
                "  - ${_describeVent(v)}",
                "Should be changed: ${v.shouldBeChanged ? 'Yes' : 'No'}",
              )),
        ],
        if (facet.otherElements.isEmpty)
          _buildDataRow("Other Elements", "None recorded")
        else ...[
          _buildDataRow("Other Elements", ""),
          ...facet.otherElements.map((e) => _buildDataRow(
                "  - ${_describeOtherElement(e)}",
                "",
              )),
        ],
        if (facet.comment != null && facet.comment!.trim().isNotEmpty)
          _buildDataRow("Additional comment", facet.comment!),
      ];
    }

    static String _describeOtherElement(OtherElementData element) {
      final base = element.type == 'Other'
          ? 'Other: ${element.otherSpecify ?? ''}'
          : element.type;
      final count = element.count != null && element.count!.trim().isNotEmpty
          ? ' x${element.count}'
          : '';
      final actions = <String>[];
      if (element.shouldBeChanged) actions.add('change');
      if (element.detachAndResetOnly) actions.add('detach & reset only');
      if (actions.isEmpty) actions.add('no change');
      return '$base$count (${actions.join(', ')})';
    }

    static bool _isShinglesRoof(String? roofType) {
      return roofType?.toLowerCase().trim() == 'shingles' ||
          roofType?.toLowerCase().trim() == 'other';
    }

    static bool _isHeavyResidentialRoof(String? roofType) {
      final normalized = roofType?.toLowerCase().trim() ?? '';
      return normalized.contains('tile') ||
          normalized.contains('slate') ||
          normalized.contains('shake');
    }

    static bool _isMetalRoof(String? roofType) {
      return (roofType ?? '').toLowerCase().trim().contains('metal');
    }

    static bool _isRollRoofing(String? roofType) {
      return (roofType ?? '').toLowerCase().trim().contains('roll');
    }

    static String _yesNo(bool? value) {
      if (value == null) return "N/A";
      return value ? "Yes" : "No";
    }

    static String _textOrNA(String? value) {
      if (value == null || value.trim().isEmpty) return "N/A";
      return value.trim();
    }

    static String _formatPitch(String? pitch) {
      final rawValue = pitch?.trim() ?? '';
      if (rawValue.isEmpty) return "N/A";
      if (rawValue.toUpperCase() == "N/A") return "N/A";

      final normalizedValue = rawValue.replaceAll(RegExp(r'\s+'), '');
      if (normalizedValue.isEmpty) return "N/A";

      if (normalizedValue.contains('/')) {
        final parts = normalizedValue.split('/');
        final rise = parts.first.trim();
        if (rise.isEmpty) return "N/A";
        if (parts.length == 1 || parts[1].trim().isEmpty) {
          return "$rise/12";
        }
        return normalizedValue;
      }

      return "$normalizedValue/12";
    }

    static List<pw.Widget> _buildElevationsUnderlaymentDetails(InspectionReport report) {
      if (!report.inspectElevations) return [];

      final rows = <pw.Widget>[];
      final globalRows = _buildGlobalElevationsRows(report);
      if (globalRows.isNotEmpty) {
        rows.addAll(globalRows);
      }

      for (final elevation in report.elevations.elevations) {
        final siding = elevation.siding.sidingMain;
        final underlayment = elevation.underlayment;
        final substrate = elevation.substrate;
        final eifs = elevation.eifs;
        final hasSidingScope = _hasElevationSidingScopeData(elevation.siding);
        final hasPanelInsulationData =
            _hasElevationPanelInsulationData(elevation.siding);
        final trims = elevation.trims;
        final windows = elevation.windows;
        final doors = elevation.doors;
        final accessories = elevation.accessories;
        final hasTrims = trims.any(_trimHasAnyData);
        final hasWindows = windows.any((w) => w.hasAnyData == true);
        final hasDoors = doors.any((d) => d.hasAnyData == true);
        final hasAccessories = accessories.any((a) => a.hasAnyData == true);
        if (!underlayment.hasAnyData &&
            !hasSidingScope &&
            !hasPanelInsulationData &&
            !substrate.hasAnyData &&
            !eifs.hasAnyData &&
            !hasTrims &&
            !hasWindows &&
            !hasDoors &&
            !hasAccessories) {
          continue;
        }
        if (!_isUnderlaymentApplicableSiding(siding) &&
            !hasSidingScope &&
            !hasPanelInsulationData &&
            !substrate.hasAnyData &&
            !eifs.hasAnyData &&
            !hasTrims &&
            !hasWindows &&
            !hasDoors &&
            !hasAccessories) {
          continue;
        }

        rows.addAll([
          pw.Text(
            "${elevation.side.display} Elevation",
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          _buildDataRow("Siding Type", _textOrNA(siding)),
          ..._buildElevationSidingScopeRows(elevation.siding),
          if (_isUnderlaymentApplicableSiding(siding) &&
              (underlayment.hasAnyData || hasPanelInsulationData))
            ..._buildElevationUnderlaymentRows(elevation.siding, underlayment),
          if (substrate.hasAnyData) ..._buildElevationSubstrateRows(substrate),
          if (eifs.hasAnyData) ..._buildElevationEifsRows(eifs),
          if (hasTrims) ..._buildElevationTrimRows(trims),
          if (hasWindows) ..._buildElevationWindowRows(windows),
          if (hasDoors) ..._buildElevationDoorRows(doors),
          if (hasAccessories) ..._buildElevationAccessoryRows(accessories),
          pw.SizedBox(height: 6),
        ]);
      }

      if (rows.isEmpty) return [];

      return [
        _buildSectionTitle("ELEVATIONS"),
        pw.SizedBox(height: 5),
        ...rows,
        pw.SizedBox(height: 10),
      ];
    }

    static List<pw.Widget> _buildGlobalElevationsRows(InspectionReport report) {
      final rows = <pw.Widget>[];
      final emergencyServices = report.elevations.emergencyServices;
      final guttersSoffitFascia = report.elevations.guttersSoffitFascia;

      final emergencyRows = _buildEmergencyServicesRows(emergencyServices);
      final guttersRows = _buildGuttersAndDownspoutsRows(guttersSoffitFascia);
      final fasciaRows = _buildFasciaRows(guttersSoffitFascia);
      final soffitRows = _buildSoffitRows(guttersSoffitFascia);
      final notes = (guttersSoffitFascia.additionalNotes as String?) ?? '';

      if (emergencyRows.isEmpty &&
          guttersRows.isEmpty &&
          fasciaRows.isEmpty &&
          soffitRows.isEmpty &&
          notes.trim().isEmpty) {
        return rows;
      }

      rows.add(pw.Text(
        "Global Elevation Items",
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ));
      rows.add(pw.SizedBox(height: 3));
      rows.addAll(emergencyRows);
      rows.addAll(guttersRows);
      rows.addAll(fasciaRows);
      rows.addAll(soffitRows);
      if (notes.trim().isNotEmpty) {
        rows.add(_buildDataRow("Additional Notes", notes.trim()));
      }
      rows.add(pw.SizedBox(height: 6));

      return rows;
    }

    static List<pw.Widget> _buildEmergencyServicesRows(dynamic emergencyServices) {
      if (emergencyServices.hasAnyData != true) return [];

      final rows = <pw.Widget>[
        pw.Text("Emergency Services", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        _buildDataRow(
          "Emergency Services performed",
          emergencyServices.enabled == true ? "Yes" : "No",
        ),
      ];

      if (emergencyServices.twpEnabled == true) {
        rows.add(_buildDataRow("Temporary Wall Protection", "Yes"));
        rows.add(_buildDataRow("Type", _textOrNA(emergencyServices.twpType)));
        if (emergencyServices.twpSf.trim().isNotEmpty) {
          rows.add(_buildDataRow("How many SF", emergencyServices.twpSf.trim()));
        }
      }

      if (emergencyServices.twdpEnabled == true) {
        rows.add(_buildDataRow("Temporary Window/Door Protection", "Yes"));
        if (emergencyServices.twdpSf.trim().isNotEmpty) {
          rows.add(_buildDataRow("How many SF", emergencyServices.twdpSf.trim()));
        }
      }

      if (emergencyServices.pwEnabled == true) {
        rows.add(_buildDataRow("Power Washing required", "Yes"));
        rows.add(_buildDataRow("Area", _textOrNA(emergencyServices.pwArea)));
        if (emergencyServices.pwArea == 'Partial' &&
            emergencyServices.pwSf.trim().isNotEmpty) {
          rows.add(_buildDataRow("How many SF", emergencyServices.pwSf.trim()));
        }
      }

      if (emergencyServices.additionalNotes.trim().isNotEmpty) {
        rows.add(_buildDataRow(
          "Additional Notes",
          emergencyServices.additionalNotes.trim(),
        ));
      }

      rows.add(pw.SizedBox(height: 5));
      return rows;
    }

    static List<pw.Widget> _buildGuttersAndDownspoutsRows(dynamic data) {
      if (data.guttersHasData != true) return [];

      final rows = <pw.Widget>[
        pw.Text("Gutters & Downspouts", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        _buildDataRow("Material Type", _textOrNA(data.gutMaterial)),
      ];

      if (data.gutMaterial == 'Other' && data.gutMaterialOther.trim().isNotEmpty) {
        rows.add(_buildDataRow("Specify Other Material", data.gutMaterialOther.trim()));
      }

      rows.add(_buildDataRow("Shape Type", _textOrNA(data.gutShape)));
      rows.add(_buildDataRow("Size", _textOrNA(data.gutSize)));
      rows.add(_buildDataRow("Has gutter screen?", data.gutScreen == true ? "Yes" : "No"));
      if (data.gutScreen == true) {
        rows.add(_buildDataRow("Gutter screen style", _textOrNA(data.gutScreenStyle)));
      }
      rows.add(_buildDataRow("Has Scupper?", data.gutScupper == true ? "Yes" : "No"));
      if (data.gutScupper == true && data.gutScupperQty.trim().isNotEmpty) {
        rows.add(_buildDataRow("Scupper quantity", data.gutScupperQty.trim()));
      }
      rows.add(_buildDataRow("Scope of Work", _textOrNA(data.gutScope)));
      if (data.gutLf.trim().isNotEmpty) {
        rows.add(_buildDataRow("How many LF", data.gutLf.trim()));
      }
      rows.add(_buildDataRow("Requires painting?", data.gutPaint == true ? "Yes" : "No"));
      rows.add(pw.SizedBox(height: 5));

      return rows;
    }

    static List<pw.Widget> _buildFasciaRows(dynamic data) {
      if (data.fasciaHasData != true) return [];

      final rows = <pw.Widget>[
        pw.Text("Fascia", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        _buildDataRow("Material Type", _textOrNA(data.facMaterial)),
      ];

      if (data.facMaterial == 'Wood') {
        rows.add(_buildDataRow("Wood Subtype", _textOrNA(data.facWoodSubtype)));
      }
      rows.add(_buildDataRow("Size", _textOrNA(data.facSize)));
      rows.add(_buildDataRow("Scope of Work", _textOrNA(data.facScope)));
      rows.add(_buildDataRow("Quantity", _textOrNA(data.facQuantity)));
      if (data.facQuantity == 'Partial' && data.facLf.trim().isNotEmpty) {
        rows.add(_buildDataRow("How many LF", data.facLf.trim()));
      }
      rows.add(_buildDataRow("Requires painting?", data.facPaint == true ? "Yes" : "No"));
      rows.add(pw.SizedBox(height: 5));

      return rows;
    }

    static List<pw.Widget> _buildSoffitRows(dynamic data) {
      if (data.soffitHasData != true) return [];

      final rows = <pw.Widget>[
        pw.Text("Soffit", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        _buildDataRow("Material Type", _textOrNA(data.sofMaterial)),
      ];

      if (data.sofMaterial == 'Other' && data.sofMaterialOther.trim().isNotEmpty) {
        rows.add(_buildDataRow("Specify Other Material", data.sofMaterialOther.trim()));
      }
      rows.add(_buildDataRow("Size", _textOrNA(data.sofSize)));
      if (data.sofSize == 'Other' && data.sofSizeOther.trim().isNotEmpty) {
        rows.add(_buildDataRow("Specify Other Size", data.sofSizeOther.trim()));
      }
      rows.add(_buildDataRow("Scope of Work", _textOrNA(data.sofScope)));
      rows.add(_buildDataRow("Quantity", _textOrNA(data.sofQuantity)));
      if (data.sofQuantity == 'Partial' && data.sofLf.trim().isNotEmpty) {
        rows.add(_buildDataRow("How many LF", data.sofLf.trim()));
      }
      rows.add(_buildDataRow("Has Vents?", data.sofVents == true ? "Yes" : "No"));
      if (data.sofVents == true && data.sofVentsQty.trim().isNotEmpty) {
        rows.add(_buildDataRow("Vents quantity", data.sofVentsQty.trim()));
      }
      rows.add(_buildDataRow("Requires painting?", data.sofPaint == true ? "Yes" : "No"));
      rows.add(pw.SizedBox(height: 5));

      return rows;
    }

    static List<pw.Widget> _buildElevationSidingScopeRows(dynamic siding) {
      final rows = <pw.Widget>[];
      final sidingType = (siding.sidingMain as String?) ?? '';

      void addSidingNotes() {
        if (siding.additionalNotes.trim().isNotEmpty) {
          rows.add(_buildDataRow("Siding Notes", siding.additionalNotes.trim()));
        }
      }

      if (sidingType == 'Stucco') {
        final scope = (siding.stuccoScope as String?) ?? '';
        if (scope.trim().isNotEmpty) {
          rows.add(_buildDataRow("Siding Scope of Work", scope.trim()));

          if (scope == 'Small repair' && siding.stuccoSmallRepairSf.trim().isNotEmpty) {
            rows.add(_buildDataRow("Stucco small repair", "${siding.stuccoSmallRepairSf.trim()} SF"));
          }
          if (scope == 'Crack repair' && siding.stuccoCrackRepairLf.trim().isNotEmpty) {
            rows.add(_buildDataRow("Stucco crack repair", "${siding.stuccoCrackRepairLf.trim()} LF"));
          }
          if (scope == 'Fog coat application') {
            rows.add(_buildDataRow("Fog coat entire elevation", siding.stuccoFogCoatEntireElev ? "Yes" : "No"));
            if (!siding.stuccoFogCoatEntireElev && siding.stuccoFogCoatSf.trim().isNotEmpty) {
              rows.add(_buildDataRow("Fog coat area", "${siding.stuccoFogCoatSf.trim()} SF"));
            }
          }
          if (scope == 'Redash') {
            rows.add(_buildDataRow("Redash entire elevation", siding.stuccoRedashEntireElev ? "Yes" : "No"));
            if (!siding.stuccoRedashEntireElev && siding.stuccoRedashSf.trim().isNotEmpty) {
              rows.add(_buildDataRow("Redash area", "${siding.stuccoRedashSf.trim()} SF"));
            }
            if (siding.stuccoRedashTexture.trim().isNotEmpty) {
              rows.add(_buildDataRow("Redash texture", siding.stuccoRedashTexture.trim()));
            }
          }
          if (scope == 'Whole replacement' && siding.stuccoWholeReplacementCoats.trim().isNotEmpty) {
            rows.add(_buildDataRow("How many coats", siding.stuccoWholeReplacementCoats.trim()));
          }
        }
        addSidingNotes();
        return rows;
      }

      if (siding.changeWholeElevation) {
        rows.add(_buildDataRow("Siding Scope of Work", "Change whole elevation siding"));
      } else if (siding.howManySf.trim().isNotEmpty) {
        rows.add(_buildDataRow("Siding Scope of Work", "Partial replacement (${siding.howManySf.trim()} SF)"));
      }

      addSidingNotes();
      return rows;
    }

    static bool _hasElevationSidingScopeData(dynamic siding) {
      final sidingType = (siding.sidingMain as String?) ?? '';
      if (siding.additionalNotes.trim().isNotEmpty) return true;
      if (sidingType == 'Stucco') {
        return siding.stuccoScope.trim().isNotEmpty;
      }
      return siding.changeWholeElevation || siding.howManySf.trim().isNotEmpty;
    }

    static bool _hasElevationPanelInsulationData(dynamic siding) {
      return siding.sidingMain == 'Wall/roof panel' &&
          (siding.panelHasInsulation == true ||
              siding.panelInsulation.trim().isNotEmpty);
    }

    static List<pw.Widget> _buildElevationUnderlaymentRows(
      dynamic sidingData,
      dynamic underlayment,
    ) {
      final rows = <pw.Widget>[];
      final siding = (sidingData.sidingMain as String?) ?? '';

      if (siding == 'Wall/roof panel' &&
          (sidingData.panelHasInsulation == true ||
              sidingData.panelInsulation.trim().isNotEmpty)) {
        rows.add(_buildDataRow(
          "Is there insulation?",
          sidingData.panelHasInsulation == true ? "Yes" : "No",
        ));
        if (sidingData.panelHasInsulation == true &&
            sidingData.panelInsulation.trim().isNotEmpty) {
          rows.add(_buildDataRow("Insulation", sidingData.panelInsulation.trim()));
        }
      }

      if (_showsElevationFanfoldInsulation(siding)) {
        rows.add(_buildDataRow(
          "Add Fanfold Insulation",
          underlayment.addFanfoldInsulation ? "Yes" : "No",
        ));
        if (underlayment.addFanfoldInsulation) {
          rows.add(_buildDataRow(
            "Thickness",
            _textOrNA(underlayment.fanfoldThickness),
          ));
        }
      }

      if (_isElevationVeneerSiding(siding)) {
        rows.add(_buildDataRow(
          "Add Foil Insulation / Radiant Barrier",
          underlayment.addFoilInsulationRadiantBarrier ? "Yes" : "No",
        ));
      }

      if (_showsElevationHouseWrap(siding)) {
        rows.add(_buildDataRow(
          "Add House Wrap (WRB)",
          underlayment.addHouseWrapWrb ? "Yes" : "No",
        ));
      }

      rows.add(_buildDataRow(
        "Use Rainscreen/Furring Strips",
        underlayment.useRainscreenFurringStrips ? "Yes" : "No",
      ));

      if (!_isElevationVeneerSiding(siding) &&
          _showsElevationFoilInsulation(siding, underlayment)) {
        rows.add(_buildDataRow(
          "Add Foil Insulation / Radiant Barrier",
          underlayment.addFoilInsulationRadiantBarrier ? "Yes" : "No",
        ));
      }

      if (underlayment.additionalNotes.trim().isNotEmpty) {
        rows.add(_buildDataRow(
          "Additional Notes",
          underlayment.additionalNotes.trim(),
        ));
      }

      return rows;
    }

    static List<pw.Widget> _buildElevationSubstrateRows(dynamic substrate) {
      final rows = <pw.Widget>[];

      rows.add(_buildDataRow(
        "Substrate Repair / Replacement Needed",
        substrate.substrateRepairReplacementNeeded ? "Yes" : "No",
      ));

      if (substrate.substrateRepairReplacementNeeded) {
        rows.add(_buildDataRow(
          "Substrate Material Type",
          _textOrNA(substrate.substrateMaterialType),
        ));
        rows.add(_buildDataRow(
          "Substrate Thickness",
          _textOrNA(substrate.substrateThickness),
        ));
        rows.add(_buildDataRow(
          "Replace Quantity",
          substrate.entireElevation
              ? "Entire elevation"
              : (substrate.howManySf.trim().isNotEmpty
                  ? "${substrate.howManySf.trim()} SF"
                  : "N/A"),
        ));
      }

      if (substrate.additionalNotes.trim().isNotEmpty) {
        rows.add(_buildDataRow(
          "Additional Notes",
          substrate.additionalNotes.trim(),
        ));
      }

      return rows;
    }

    static List<pw.Widget> _buildElevationEifsRows(dynamic eifs) {
      final rows = <pw.Widget>[
        _buildDataRow(
          "EIFS / External Insulation Finishing System",
          eifs.present ? "Yes" : "No",
        ),
      ];

      if (eifs.present) {
        if (eifs.wholeReplacement) {
          rows.add(_buildDataRow("EIFS Scope of Work", "Whole elevation"));
        } else if (eifs.partialRepair) {
          rows.add(_buildDataRow("EIFS Scope of Work", "Partial Repair"));
          rows.add(_buildDataRow(
            "Partial Repair Area",
            eifs.partialRepairSf.trim().isNotEmpty
                ? "${eifs.partialRepairSf.trim()} SF"
                : "N/A",
          ));
        }

        rows.add(_buildDataRow("Substrate", _textOrNA(eifs.substrate)));

        if (eifs.substrate == 'OSB' || eifs.substrate == 'Plywood') {
          rows.add(_buildDataRow(
            "Requires to be replaced?",
            eifs.substrateRequiresReplacement == null
                ? "N/A"
                : (eifs.substrateRequiresReplacement ? "Yes" : "No"),
          ));
        }

        rows.add(_buildDataRow(
          "Final Texture Finish",
          _textOrNA(eifs.finalTextureFinish),
        ));
        rows.add(_buildDataRow("Finish", _textOrNA(eifs.finish)));
      }

      if (eifs.additionalNotes.trim().isNotEmpty) {
        rows.add(_buildDataRow(
          "Additional Notes",
          eifs.additionalNotes.trim(),
        ));
      }

      return rows;
    }

 static bool _trimHasAnyData(dynamic trim) {
  return trim.trimType.trim().isNotEmpty ||
      trim.otherSpecify.trim().isNotEmpty ||
      trim.action.trim().isNotEmpty ||
      trim.ocpMaterial.trim().isNotEmpty ||
      trim.ocpInsulated == true ||
      trim.ocpMetalGauge.trim().isNotEmpty ||
      trim.jTrimMaterial.trim().isNotEmpty ||
      trim.sidingTrimMaterial.trim().isNotEmpty ||
      trim.sidingTrimSize.trim().isNotEmpty ||
      trim.skirtingMaterial.trim().isNotEmpty ||
      trim.skirtingSize.trim().isNotEmpty ||
      trim.photo != null ||
      trim.extraPhoto != null;
}

 static List<pw.Widget> _buildElevationTrimRows(Iterable trims) {
  final rows = <pw.Widget>[];
  final activeTrims = trims.where(_trimHasAnyData);

  if (activeTrims.isEmpty) return rows;

  rows.add(pw.Text("Trim", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));

  int i = 1;
  for (final trim in activeTrims) {
    rows.add(_buildDataRow("Trim $i", ""));
    rows.add(_buildDataRow("Trim Type", _textOrNA(trim.trimType)));

    if (trim.trimType == 'Other' && trim.otherSpecify.trim().isNotEmpty) {
      rows.add(_buildDataRow("Specify Other Trim", trim.otherSpecify.trim()));
    }

    rows.add(_buildDataRow("Action", _textOrNA(trim.action)));

    if (trim.action == 'Replace') {
      if (trim.trimType == 'Outside corner post') {
        rows.add(_buildDataRow("Material", _textOrNA(trim.ocpMaterial)));
        if (trim.ocpMaterial == 'Vinyl' || trim.ocpMaterial == 'Metal') {
          rows.add(_buildDataRow("Insulated?", trim.ocpInsulated == true ? "Yes" : "No"));
        }
        if (trim.ocpMaterial == 'Metal') {
          rows.add(_buildDataRow("Gauge", _textOrNA(trim.ocpMetalGauge)));
        }
      } else if (trim.trimType == 'J-trim') {
        rows.add(_buildDataRow("Material", _textOrNA(trim.jTrimMaterial)));
      } else if (trim.trimType == 'Siding trim') {
        rows.add(_buildDataRow("Material", _textOrNA(trim.sidingTrimMaterial)));
        rows.add(_buildDataRow("Size", _textOrNA(trim.sidingTrimSize)));
      } else if (trim.trimType == 'Skirting') {
        rows.add(_buildDataRow("Material", _textOrNA(trim.skirtingMaterial)));
        rows.add(_buildDataRow("Size", _textOrNA(trim.skirtingSize)));
      }
    }

    i++;
  }

  return rows;
}

 static List<pw.Widget> _buildElevationWindowRows(Iterable windows) {
  final rows = <pw.Widget>[];

  // .where() no crea una lista nueva, solo filtra al vuelo (Lazy Evaluation). Cero impacto en RAM.
  final activeWindows = windows.where((w) => w.hasAnyData == true);

  if (activeWindows.isEmpty) return rows;

  rows.add(pw.Text("Windows", style: pw.TextStyle(fontWeight: pw.FontWeight.bold),));

  int i = 1;
  // Iteramos directamente sobre el flujo original
  for (final window in activeWindows) {
    rows.add(_buildDataRow("Window $i", ""));
    rows.add(_buildDataRow("Window Type", _textOrNA(window.windowType)));
    rows.add(_buildDataRow("Material Type", _textOrNA(window.materialType)));

    if (window.glassEfficiencySelections?.isNotEmpty == true) {
      rows.add(_buildDataRow(
        "Glass & Efficiency",
        window.glassEfficiencySelections.join(', '),
      ));
    }

    if (window.componentsSelections?.isNotEmpty == true) {
      rows.add(_buildDataRow(
        "Components & Accessories",
        window.componentsSelections.join(', '),
      ));
    }

    if (window.componentOtherSpecify != null && window.componentOtherSpecify.trim().isNotEmpty) {
      rows.add(_buildDataRow(
        "Specify Other Component",
        window.componentOtherSpecify.trim(),
      ));
    }

    if (window.widthInches != null && window.widthInches.trim().isNotEmpty) {
      rows.add(_buildDataRow("Width", "${window.widthInches.trim()} inches"));
    }

    if (window.heightInches != null && window.heightInches.trim().isNotEmpty) {
      rows.add(_buildDataRow("Height", "${window.heightInches.trim()} inches"));
    }

    if (window.quantity != null && window.quantity.trim().isNotEmpty) {
      rows.add(_buildDataRow("Quantity", window.quantity.trim()));
    }

    if (window.scopeOfWork != null && window.scopeOfWork.trim().isNotEmpty) {
      rows.add(_buildDataRow("Scope of work", window.scopeOfWork.trim()));
    }

    rows.add(_buildDataRow(
      "Shutters Installed",
      window.hasShuttersInstalled == true ? "Yes" : "No",
    ));

    if (window.hasShuttersInstalled == true) {
      rows.add(_buildDataRow(
        "Shutters Scope of work",
        _textOrNA(window.shuttersScopeOfWork),
      ));

      if (window.shuttersScopeOfWork == 'Replace') {
        rows.add(_buildDataRow(
          "Shutters Material",
          _textOrNA(window.shuttersMaterial),
        ));

        // Nuevo campo 'Specify' para Shutters
        if (window.shuttersMaterial == 'Other' && window.shuttersMaterialSpecify != null && window.shuttersMaterialSpecify.trim().isNotEmpty) {
          rows.add(_buildDataRow(
            "Specify Shutters Material",
            window.shuttersMaterialSpecify.trim(),
          ));
        }

        rows.add(_buildDataRow(
          "Shutters Size",
          _textOrNA(window.shuttersSize),
        ));
      }
    }

    if (window.additionalNotes != null && window.additionalNotes.trim().isNotEmpty) {
      rows.add(_buildDataRow(
        "Additional Notes",
        window.additionalNotes.trim(),
      ));
    }
    
    i++; // Incrementamos el contador manual
  }

  return rows;
}

 static List<pw.Widget> _buildElevationDoorRows(Iterable doors) {
  final rows = <pw.Widget>[];
  final activeDoors = doors.where((d) => d.hasAnyData == true);

  if (activeDoors.isEmpty) return rows;

  rows.add(pw.Text("Doors", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));

  int i = 1;
  for (final door in activeDoors) {
    rows.add(_buildDataRow("Door $i", ""));
    rows.add(_buildDataRow("Door / Type", _textOrNA(door.doorType)));
    if (door.entryQuantity != null && door.entryQuantity.trim().isNotEmpty) {
      rows.add(_buildDataRow("Count", door.entryQuantity.trim()));
    }

    if (door.doorType == 'Sliding Patio Door') {
      rows.add(_buildDataRow("Material", _textOrNA(door.patioMaterial)));
      if (door.patioMaterial == 'Aluminum') {
        rows.add(_buildDataRow("Aluminum Finish", _textOrNA(door.patioAluminumFinish)));
      }
      rows.add(_buildDataRow("Stile", _textOrNA(door.patioStyle)));
      rows.add(_buildDataRow("Size", _textOrNA(door.patioSize)));
      rows.add(_buildDataRow("Scope of work", _textOrNA(door.patioScopeOfWork)));
    }

    if (door.doorType == 'Exterior Door / Entry Door') {
      rows.add(_buildDataRow("Entry/Exterior Door", _textOrNA(door.entryDoorType)));
      rows.add(_buildDataRow("Material", _textOrNA(door.entryMaterial)));
      rows.add(_buildDataRow("Style", _textOrNA(door.entryStyle)));
      if (door.entryDoorType != 'Storm Door') {
        rows.add(_buildDataRow("Is a French Door", door.isFrenchDoor == true ? "Yes" : "No"));
      }
      rows.add(_buildDataRow("Scope of work", _textOrNA(door.entryScopeOfWork)));
      if (door.entryDoorType != 'Storm Door') {
        rows.add(_buildDataRow("Has lite", door.hasLite == true ? "Yes" : "No"));
        if (door.hasLite == true) {
          rows.add(_buildDataRow("Lite Type", _textOrNA(door.liteType)));
          rows.add(_buildDataRow("Lite Scope of work", _textOrNA(door.liteScopeOfWork)));
        }
      }
      if (door.entryDoorType == 'Single Exterior Door') {
        rows.add(_buildDataRow("Has Screen", door.hasScreen == true ? "Yes" : "No"));
        if (door.hasScreen == true) {
          rows.add(_buildDataRow("Screen Scope of work", _textOrNA(door.screenScopeOfWork)));
        }
      }
    }

    if (door.doorType == 'Garage Door') {
      rows.add(_buildDataRow("Style", _textOrNA(door.garageStyle)));
      rows.add(_buildDataRow("With Windows", door.garageWithWindows == true ? "Yes" : "No"));
      if (door.garageWithWindows == true && door.garageWindowsCount.trim().isNotEmpty) {
        rows.add(_buildDataRow("How many windows", door.garageWindowsCount.trim()));
      }
      rows.add(_buildDataRow("Garage Door Size", _textOrNA(door.garageDoorSize)));
      rows.add(_buildDataRow("Scope of work", _textOrNA(door.garageScopeOfWork)));
      if (door.garageScopeOfWork == 'Panel Only / Section Replacement' &&
          door.garagePanelSectionCount.trim().isNotEmpty) {
        rows.add(_buildDataRow("Panel / Section Count", door.garagePanelSectionCount.trim()));
      }
    }

    if (door.doorType == 'Storefront door') {
      rows.add(_buildDataRow("Sliding door", door.storefrontSlidingDoor == true ? "Yes" : "No"));
      rows.add(_buildDataRow("Oversize", door.storefrontOversize == true ? "Yes" : "No"));
      if (door.storefrontOversize == true && door.storefrontOversizeInputSize.trim().isNotEmpty) {
        rows.add(_buildDataRow("Input size", door.storefrontOversizeInputSize.trim()));
      }
      rows.add(_buildDataRow("Type", _textOrNA(door.storefrontType)));
      rows.add(_buildDataRow("Curved", door.storefrontCurved == true ? "Yes" : "No"));
      rows.add(_buildDataRow("Scope of work", _textOrNA(door.storefrontScopeOfWork)));
    }

    if (door.doorType == 'Roll-up Door') {
      rows.add(_buildDataRow("Material Door Gauge", _textOrNA(door.rollupGauge)));
      if (door.rollupGauge == 'Other' && door.rollupGaugeOtherSpecify.trim().isNotEmpty) {
        rows.add(_buildDataRow("Gauge Specify", door.rollupGaugeOtherSpecify.trim()));
      }
      rows.add(_buildDataRow("Roll-up Door Size", _textOrNA(door.rollupSize)));
      if (door.rollupSize == 'Other' && door.rollupSizeOtherSpecify.trim().isNotEmpty) {
        rows.add(_buildDataRow("Size Specify", door.rollupSizeOtherSpecify.trim()));
      }
      rows.add(_buildDataRow("Scope of Work", _textOrNA(door.rollupScopeOfWork)));
    }

    if (door.additionalNotes != null && door.additionalNotes.trim().isNotEmpty) {
      rows.add(_buildDataRow("Additional Notes", door.additionalNotes.trim()));
    }

    i++;
  }

  return rows;
}


 static List<pw.Widget> _buildElevationAccessoryRows(Iterable accessories) {
  final rows = <pw.Widget>[];
  final activeAccessories = accessories.where((a) => a.hasAnyData == true);

  if (activeAccessories.isEmpty) return rows;

  rows.add(pw.Text("Accessories", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));

  int i = 1;
  for (final accessory in activeAccessories) {
    rows.add(_buildDataRow("Accessory $i", ""));
    rows.add(_buildDataRow("Accessory Type", _textOrNA(accessory.accessoryType)));

    if (accessory.accessoryType == 'Other' &&
        accessory.accessoryOtherSpecify.trim().isNotEmpty) {
      rows.add(_buildDataRow(
        "Specify",
        accessory.accessoryOtherSpecify.trim(),
      ));
    }

    rows.add(_buildDataRow("Scope of work", _textOrNA(accessory.scopeOfWork)));

    if (accessory.count.trim().isNotEmpty) {
      rows.add(_buildDataRow("Count", accessory.count.trim()));
    }

    if (accessory.additionalNotes.trim().isNotEmpty) {
      rows.add(_buildDataRow("Additional Notes", accessory.additionalNotes.trim()));
    }

    i++;
  }

  return rows;
}

    static bool _isUnderlaymentApplicableSiding(String siding) {
      return siding.trim().isNotEmpty && siding != 'Stucco';
    }

    static bool _showsElevationFanfoldInsulation(String siding) {
      return siding == 'Vinyl' || siding == 'Aluminum';
    }

    static bool _showsElevationHouseWrap(String siding) {
      return siding == 'Vinyl' ||
          siding == 'Aluminum' ||
          siding == 'Fiber-Cement' ||
          siding == 'Wood' ||
          siding == 'Steel' ||
          _isElevationVeneerSiding(siding);
    }

    static bool _showsElevationFoilInsulation(String siding, dynamic underlayment) {
      return _isElevationVeneerSiding(siding) ||
          underlayment.useRainscreenFurringStrips;
    }

    static bool _isElevationVeneerSiding(String siding) {
      return siding == 'Brick Veneer' ||
          siding == 'Stone Veneer' ||
          siding == 'Tone Veneer';
    }

    static List<pw.Widget> _buildCommercialRoofDetails(CommercialRoofSectionData roof) {
      final widgets = <pw.Widget>[];

      if (_isCommercialDetailedRoofType(roof.roofType)) {
        widgets.addAll(_buildCommercialPrimaryRoofRows(roof));
      }

      widgets.addAll(_buildCommercialAccessoryDetails(roof));

      return widgets;
    }

    static bool _isCommercialDetailedRoofType(String? roofType) {
      return roofType == 'Metal' ||
          roofType == 'Shingles' ||
          roofType == 'Tile roofing' ||
          roofType == 'Slate Roof' ||
          roofType == 'Other' ||
          roofType == 'TPO' ||
          roofType == 'EPDM' ||
          roofType == 'Modified Bitumen';
    }

    static List<pw.Widget> _buildCommercialPrimaryRoofRows(CommercialRoofSectionData roof) {
      switch (roof.roofType) {
        case 'Metal':
          return _buildCommercialMetalRoofRows(roof);
        case 'Shingles':
          return _buildCommercialShinglesLikeRows(roof);
        case 'Other':
          return _buildCommercialShinglesLikeRows(roof);
        case 'Tile roofing':
          return _buildCommercialTileSlateRows(roof);
        case 'Slate Roof':
          return _buildCommercialTileSlateRows(roof);
        case 'TPO':
        case 'EPDM':
        case 'Modified Bitumen':
          return _buildCommercialFlatRoofRows(roof);
        default:
          return [];
      }
    }

    static List<pw.Widget> _buildCommercialShinglesLikeRows(CommercialRoofSectionData roof) {
      final rows = <pw.Widget>[
        _buildDataRow('    More than 1 layer installed?', _yesNo(roof.hasMultipleLayers)),
      ];

      if (roof.hasMultipleLayers == true) {
        rows.add(_buildDataRow('    How many layers?', roof.numberOfLayers?.toString() ?? 'N/A'));
      }

      rows.addAll(_buildCommercialStarterRowRows(roof));
      rows.addAll(_buildCommercialDripIceValleyRows(roof));
      rows.addAll(_buildCommercialRidgeRows(roof));
      rows.addAll(_buildCommercialBasicDeckRows(roof));
      rows.addAll(_buildCommercialFacetPitchRows(roof));

      return rows;
    }

    static List<pw.Widget> _buildCommercialTileSlateRows(CommercialRoofSectionData roof) {
      final rows = <pw.Widget>[
        _buildDataRow(
          '    Does the batten system need to be replaced?',
          _textOrNA(roof.battenChangeRequired),
        ),
      ];

      rows.addAll(_buildCommercialDripIceValleyRows(roof));
      rows.addAll(_buildCommercialBasicDeckRows(roof));
      rows.addAll(_buildCommercialFacetPitchRows(roof));

      return rows;
    }

    static List<pw.Widget> _buildCommercialMetalRoofRows(CommercialRoofSectionData roof) {
      final metalGauge = roof.metalGauge == 'Other'
          ? 'Other (${_textOrNA(roof.metalGaugeOtherSpecify)})'
          : _textOrNA(roof.metalGauge);

      final rows = <pw.Widget>[
        _buildDataRow('    Metal style', _textOrNA(roof.metalStyle)),
        if (roof.metalStyle == 'Other')
          _buildDataRow('    Has facets?', _yesNo(roof.metalHasFacets)),
        if (roof.metalStyle == 'Gable' || roof.metalHasFacets == true)
          _buildDataRow('    Facet count', roof.facetCount.toString()),
        if (roof.metalStyle != 'Flat')
          _buildDataRow('    Pitch', _formatPitch(roof.pitch)),
        _buildDataRow('    Gauge', metalGauge),
        _buildDataRow('    Does the roof have a deck?', _yesNo(roof.hasDeck)),
      ];

      if (roof.hasDeck) {
        rows.addAll(_buildCommercialMetalDeckRows(roof));
      }

      rows.add(_buildDataRow('    Does the roof have insulation?', _yesNo(roof.hasInsulation)));
      if (roof.hasInsulation) {
        rows.add(_buildDataRow('    Insulation Type', _textOrNA(roof.insulationType)));
      }

      return rows;
    }

    static List<pw.Widget> _buildCommercialFlatRoofRows(CommercialRoofSectionData roof) {
      final rows = <pw.Widget>[
        _buildDataRow('    Core sample performed?', _yesNo(roof.coreSamplePerformed)),
      ];

      if (!roof.coreSamplePerformed) {
        rows.add(_buildDataRow('    Is the sublayer system known?', _yesNo(roof.insulationKnown)));
      }

      if (roof.roofType == 'EPDM' || roof.roofType == 'Modified Bitumen') {
        rows.add(_buildDataRow('    Gravel ballast present?', _yesNo(roof.gravelBallastPresent)));
      }

      if (roof.coreSamplePerformed || roof.insulationKnown == true) {
        rows.add(_buildDataRow('    Base insulation material', _textOrNA(roof.insulationMaterial)));
        if (roof.insulationMaterial == 'Other') {
          rows.add(_buildDataRow('    Specify insulation material', _textOrNA(roof.insulationMaterialOtherSpecify)));
        }
        rows.add(_buildDataRow('    Base insulation thickness', _textOrNA(roof.insulationThickness)));
        rows.add(_buildDataRow('    Is tapered?', _yesNo(roof.isTapered)));
        rows.add(_buildDataRow('    Has cover board?', _yesNo(roof.hasCoverBoard)));

        if (roof.hasCoverBoard) {
          rows.add(_buildDataRow('    Cover board type', _textOrNA(roof.coverBoardType)));
          if (roof.coverBoardType == 'Other') {
            rows.add(_buildDataRow('    Specify cover board type', _textOrNA(roof.coverBoardOtherSpecify)));
          }
          rows.add(_buildDataRow('    Cover board thickness', _textOrNA(roof.coverBoardThickness)));
        }
      }

      if (roof.coreSamplePerformed == false && roof.insulationKnown == false) {
        rows.add(_buildDataRow('    Sublayer estimating approach', _textOrNA(roof.noCoreSampleApproach)));
      }

      rows.add(_buildDataRow('    Deck required to be changed?', _yesNo(roof.deckChangeRequired)));
      if (roof.deckChangeRequired) {
        rows.add(_buildDataRow('    Deck full replacement required?', _yesNo(roof.deckFullReplacementRequired)));
        if (!roof.deckFullReplacementRequired) {
          rows.add(_buildDataRow(
            '    How many SF of decking require replacement?',
            _textOrNA(roof.deckPartialReplacementSqft),
          ));
        }

        rows.add(_buildDataRow('    Deck type', _textOrNA(roof.deckType)));
        if (roof.deckType == 'Other') {
          rows.add(_buildDataRow('    Specify deck type', _textOrNA(roof.deckTypeOtherSpecify)));
        }
        if (roof.deckType == 'Metal' || roof.deckType == 'Wood') {
          rows.add(_buildDataRow('    Deck thickness / gauge', _textOrNA(roof.deckThicknessGauge)));
        }
      }

      return rows;
    }

    static List<pw.Widget> _buildCommercialStarterRowRows(CommercialRoofSectionData roof) {
      final rows = <pw.Widget>[
        _buildDataRow('    Starter row installed?', _yesNo(roof.starterRowInstalled)),
      ];

      if (roof.starterRowInstalled) {
        rows.add(_buildDataRow('    Starter row at eave?', _yesNo(roof.starterEaveInstalled)));
        rows.add(_buildDataRow('    Starter row at rake?', _yesNo(roof.starterRakeInstalled)));
      }

      return rows;
    }

    static List<pw.Widget> _buildCommercialDripIceValleyRows(CommercialRoofSectionData roof) {
      final rows = <pw.Widget>[
        _buildDataRow('    Drip edge installed?', _yesNo(roof.hasDripEdge)),
      ];

      if (roof.hasDripEdge) {
        rows.add(_buildDataRow('    Drip edge type', _textOrNA(roof.dripEdgeType)));
      }

      rows.add(_buildDataRow('    Ice & Water Barrier installed?', _yesNo(roof.iceAndWaterBarrierInstalled)));
      rows.add(_buildDataRow('    Has Valley?', _yesNo(roof.hasValleyMetal)));

      if (roof.hasValleyMetal) {
        rows.add(_buildDataRow('    Valley Metal Type', _textOrNA(roof.valleyMetalType)));
      }

      return rows;
    }

    static List<pw.Widget> _buildCommercialRidgeRows(CommercialRoofSectionData roof) {
      final rows = <pw.Widget>[
        _buildDataRow('    Has ridge?', _yesNo(roof.hasRidge)),
      ];

      if (roof.hasRidge) {
        rows.add(_buildDataRow('    Has ridge vent?', _yesNo(roof.hasRidgeVent)));
      }

      if (roof.hasRidgeVent) {
        rows.add(_buildDataRow('    Ridge vent type', _textOrNA(roof.ridgeVentType)));
      }

      return rows;
    }

    static List<pw.Widget> _buildCommercialBasicDeckRows(CommercialRoofSectionData roof) {
      final rows = <pw.Widget>[
        _buildDataRow('    Roof deck required to be changed?', _yesNo(roof.deckChangeRequired)),
      ];

      if (roof.deckChangeRequired) {
        rows.add(_buildDataRow(
          '    Roof deck full replacement required?',
          _yesNo(roof.deckFullReplacementRequired),
        ));

        if (!roof.deckFullReplacementRequired) {
          rows.add(_buildDataRow(
            '    How many SF of roof deck require replacement?',
            _textOrNA(roof.deckPartialReplacementSqft),
          ));
        }
      }

      return rows;
    }

    static List<pw.Widget> _buildCommercialMetalDeckRows(CommercialRoofSectionData roof) {
      final rows = <pw.Widget>[
        _buildDataRow('    Does the deck require replacement?', _yesNo(roof.deckChangeRequired)),
      ];

      if (roof.deckChangeRequired) {
        rows.add(_buildDataRow(
          '    Deck full replacement required?',
          _yesNo(roof.deckFullReplacementRequired),
        ));

        if (!roof.deckFullReplacementRequired) {
          rows.add(_buildDataRow(
            '    How many SF of deck require replacement?',
            _textOrNA(roof.deckPartialReplacementSqft),
          ));
        }

        rows.add(_buildDataRow('    What is the roof support base?', _textOrNA(roof.deckType)));
        if (roof.deckType != null) {
          rows.add(_buildDataRow('    Deck Size', _textOrNA(roof.deckThicknessGauge)));
        }
      }

      return rows;
    }

    static List<pw.Widget> _buildCommercialFacetPitchRows(CommercialRoofSectionData roof) {
      final rows = <pw.Widget>[
        _buildDataRow('    Is there more than one facet?', _yesNo(roof.hasMultipleFacets)),
      ];

      if (roof.hasMultipleFacets) {
        rows.add(_buildDataRow('    Facet count', roof.facetCount.toString()));
      }

      rows.add(_buildDataRow('    Pitch', _formatPitch(roof.pitch)));

      return rows;
    }

    static List<pw.Widget> _buildCommercialAccessoryDetails(CommercialRoofSectionData roof) {
      final rows = <pw.Widget>[];

      final hasFlashings = roof.shingleFlashings.isNotEmpty || roof.tpoFlashings.isNotEmpty;
      final hasVents = roof.shingleVents.isNotEmpty || roof.tpoVents.isNotEmpty;
      final hasHvac = roof.hvacUnits.isNotEmpty;
      final hasMechanical = roof.mechanicalUnits.isNotEmpty;

      if (hasFlashings) {
        rows.add(_buildDataRow('    Flashings', 'Recorded'));

        var index = 1;
        for (final flashing in roof.shingleFlashings) {
          rows.addAll(_buildShingleFlashingRows(flashing, index));
          index++;
        }
        for (final flashing in roof.tpoFlashings) {
          rows.addAll(_buildCommercialFlashingRows(flashing, index));
          index++;
        }
      }

      if (hasVents) {
        rows.add(_buildDataRow('    Vents', 'Recorded'));

        var index = 1;
        for (final vent in roof.shingleVents) {
          rows.addAll(_buildShingleVentRows(vent, index));
          index++;
        }
        for (final vent in roof.tpoVents) {
          rows.addAll(_buildCommercialVentRows(vent, index));
          index++;
        }
      }

      if (hasHvac) {
        rows.add(_buildDataRow('    HVAC rooftop equipment', 'Recorded'));
        for (var i = 0; i < roof.hvacUnits.length; i++) {
          rows.addAll(_buildHvacUnitRows(roof.hvacUnits[i], i + 1, 'HVAC'));
        }
      }

      if (hasMechanical) {
        rows.add(_buildDataRow('    Mechanical rooftop equipment', 'Recorded'));
        for (var i = 0; i < roof.mechanicalUnits.length; i++) {
          rows.addAll(_buildHvacUnitRows(roof.mechanicalUnits[i], i + 1, 'Mechanical'));
        }
      }

      return rows;
    }

    static List<pw.Widget> _buildShingleFlashingRows(FlashingData flashing, int index) {
      final rows = <pw.Widget>[
        _buildDataRow('      Flashing $index Type', _displayOther(flashing.type, flashing.otherSpecify)),
      ];

      _addOptionalDataRow(rows, '      Flashing $index Size', flashing.size);
      _addOptionalDataRow(rows, '      Flashing $index Material', flashing.material);
      _addOptionalDataRow(rows, '      Flashing $index Finish', flashing.finish);
      _addOptionalDataRow(rows, '      Flashing $index Grade', flashing.grade);
      _addOptionalDataRow(rows, '      Flashing $index Count', flashing.count);
      rows.add(_buildDataRow('      Flashing $index Should be changed?', flashing.shouldBeChanged ? 'Yes' : 'No'));
      if (flashing.changeFlueCap) {
        rows.add(_buildDataRow('      Flashing $index Change flue cap?', 'Yes'));
      }
      if (flashing.changeChaseCover) {
        rows.add(_buildDataRow('      Flashing $index Change chase cover?', 'Yes'));
        _addOptionalDataRow(rows, '      Flashing $index Chase cover material', flashing.chaseCoverMaterial);
      }

      return rows;
    }

    static List<pw.Widget> _buildCommercialFlashingRows(CommercialFlashingData flashing, int index) {
      final rows = <pw.Widget>[
        _buildDataRow('      Flashing $index Type', _displayOther(flashing.type, flashing.otherSpecify)),
      ];

      _addOptionalDataRow(rows, '      Flashing $index Size', flashing.size);
      _addOptionalDataRow(rows, '      Flashing $index Material', flashing.material);
      _addOptionalDataRow(rows, '      Flashing $index Grade', flashing.grade);
      _addOptionalDataRow(rows, '      Flashing $index How many LF', flashing.lfCount);
      _addOptionalDataRow(rows, '      Flashing $index Count', flashing.count);
      if (flashing.fullPerimeter != null) {
        rows.add(_buildDataRow('      Flashing $index Full perimeter?', flashing.fullPerimeter == true ? 'Yes' : 'No'));
      }

      return rows;
    }

    static List<pw.Widget> _buildShingleVentRows(VentData vent, int index) {
      final rows = <pw.Widget>[
        _buildDataRow('      Vent $index Type', _displayOther(vent.type, vent.otherSpecify)),
      ];

      _addOptionalDataRow(rows, '      Vent $index Count', vent.count);
      rows.add(_buildDataRow('      Vent $index Should be changed?', vent.shouldBeChanged ? 'Yes' : 'No'));
      if (vent.includeSplitBoot) {
        rows.add(_buildDataRow('      Vent $index Include split boot?', 'Yes'));
      }
      if (vent.includeLead) {
        rows.add(_buildDataRow('      Vent $index Include lead?', 'Yes'));
      }

      return rows;
    }

    static List<pw.Widget> _buildCommercialVentRows(CommercialVentData vent, int index) {
      final rows = <pw.Widget>[
        _buildDataRow('      Vent $index Type', _displayOther(vent.type, vent.otherSpecify)),
      ];

      _addOptionalDataRow(rows, '      Vent $index Size', vent.size);
      _addOptionalDataRow(rows, '      Vent $index Throat dimension', vent.throatDimension);
      _addOptionalDataRow(rows, '      Vent $index Specify throat dimension', vent.throatDimensionOtherSpecify);
      _addOptionalDataRow(rows, '      Vent $index Shape', vent.shape);
      _addOptionalDataRow(rows, '      Vent $index Count', vent.count);

      return rows;
    }

    static List<pw.Widget> _buildHvacUnitRows(HvacUnitData item, int index, String label) {
      final rows = <pw.Widget>[
        _buildDataRow('      $label $index Type', _displayOther(item.type, item.otherSpecify)),
      ];

      _addOptionalDataRow(rows, '      $label $index Subtype', item.subtype);
      _addOptionalDataRow(rows, '      $label $index Specify subtype', item.subtypeOtherSpecify);
      _addOptionalDataRow(rows, '      $label $index Capacity', item.capacityText);
      _addOptionalDataRow(rows, '      $label $index Count', item.count);
      _addOptionalDataRow(rows, '      $label $index Impeller diameter', item.impellerDiameter);
      rows.add(_buildDataRow('      $label $index Action', _textOrNa(item.action)));
      _addOptionalDataRow(rows, '      $label $index Notes', item.notes);

      return rows;
    }

    static void _addOptionalDataRow(List<pw.Widget> rows, String label, String? value) {
      if (_hasText(value)) {
        rows.add(_buildDataRow(label, value!.trim()));
      }
    }

    static String _displayOther(String? value, String? otherSpecify) {
      final base = _textOrNa(value);
      if (base == 'Other' && _hasText(otherSpecify)) {
        return 'Other: ${otherSpecify!.trim()}';
      }
      return base;
    }

    static bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

    static String _textOrNa(String? value) => _hasText(value) ? value!.trim() : 'N/A';

    static String _describeFlashing(FlashingData flashing) {
      final base = flashing.type == 'Other'
          ? 'Other: ${flashing.otherSpecify ?? ''}'
          : flashing.type;
      final parts = <String>[];
      if (flashing.size != null && flashing.size!.trim().isNotEmpty) {
        parts.add(flashing.size!);
      }
      if (flashing.material != null && flashing.material!.trim().isNotEmpty) {
        parts.add(flashing.material!);
      }
      if (flashing.finish != null && flashing.finish!.trim().isNotEmpty) {
        parts.add(flashing.finish!);
      }
      if (flashing.grade != null && flashing.grade!.trim().isNotEmpty) {
        parts.add(flashing.grade!);
      }
      if (flashing.count != null && flashing.count!.trim().isNotEmpty) {
        parts.add('x${flashing.count!.trim()}');
      }
      if (flashing.changeFlueCap) {
        parts.add('change flue cap');
      }
      if (flashing.changeChaseCover) {
        final material = flashing.chaseCoverMaterial;
        parts.add(
          material != null && material.trim().isNotEmpty
              ? 'change chase cover: ${material.trim()}'
              : 'change chase cover',
        );
      }
      final action = flashing.shouldBeChanged ? 'change' : 'no change';
      return parts.isEmpty ? '$base ($action)' : '$base (${parts.join(', ')}, $action)';
    }

    static String _describeVent(VentData vent) {
      final base = vent.type == 'Other'
          ? 'Other: ${vent.otherSpecify ?? ''}'
          : vent.type;
      final extras = <String>[];
      if (vent.count != null && vent.count!.trim().isNotEmpty) {
        extras.add('x${vent.count}');
      }
      if (vent.includeSplitBoot) extras.add('Split boot');
      if (vent.includeLead) extras.add('Lead');
      extras.add(vent.shouldBeChanged ? 'change' : 'no change');
      return extras.isEmpty ? base : '$base (${extras.join(', ')})';
    }

    static pw.Widget _buildHeader(String title) {
     return pw.Header(level: 0, child: pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)));
    }

    static pw.Widget _buildSectionTitle(String title) {
     return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(5),
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    );
    }

    static pw.Widget _buildDataRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(children: [
        pw.Expanded(flex: 2, child: pw.Text("$label:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Expanded(flex: 3, child: pw.Text(value)),
      ]),
      );
     }

    static Future<_PdfPhotoItemBytes> _loadPdfPhotoItemBytes(
      PhotoItem item, {
      bool isCommercial = false,
    }) async {
      // Palanca 3: preset agresivo (800px/q65) para commercial vs 1024px/q75
      // en residential. Ambos corren en isolate via compute(). Sin caches:
      // cada PhotoItem se procesa en serie y se libera al terminar el frame.
      final Uint8List bytes = await compute(
        isCommercial ? _downscaleForPdfCommercial : _downscaleForPdf,
        item.file.path,
      );
      return _PdfPhotoItemBytes(
        bytes: bytes,
        label: item.label,
      );
    }

    static pw.Widget _buildPhotoFrame(_PdfPhotoItemBytes item) {
    // Paso 4.5b: mostrar labels estructurados de Elevations como texto legible.
    // Commercial/residential existentes conservan su fallback original.
    final caption = formatElevationsPhotoCaption(item.label);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(caption, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Container(
          height: 300, // Altura optimizada para 2 por página A4
          width: double.infinity,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
          child: pw.Image(pw.MemoryImage(item.bytes), fit: pw.BoxFit.cover),
        ),
      ],
      );
      }
     static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
      return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
   }
   }
