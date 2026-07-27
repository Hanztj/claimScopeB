import 'dart:io';

import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:path_provider/path_provider.dart';

const String _inspectionPhotosFolderName = 'inspection_photos_v1';
int _photoSequence = 0;

String _sanitizePathPart(String value) {
  var sanitized = value.trim();
  sanitized = sanitized.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
  sanitized = sanitized.replaceAll(RegExp(r'\s+'), '_');
  sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');
  sanitized = sanitized.replaceAll(RegExp(r'^_+|_+$'), '');
  if (sanitized.isEmpty) return 'draft_inspection';
  return sanitized.length <= 120 ? sanitized : sanitized.substring(0, 120);
}

String _inspectionFolderName(InspectionReport report) {
  final parts = <String>[
    report.claimNumber,
    report.clientName,
    report.address,
    report.dateInspected,
  ].where((value) => value.trim().isNotEmpty).toList(growable: false);

  return _sanitizePathPart(
    parts.isEmpty ? 'draft_inspection' : parts.join('_'),
  );
}

String _fileExtension(String path) {
  final filename = path.split(RegExp(r'[\\/]')).last;
  final dotIndex = filename.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == filename.length - 1) {
    return '.jpg';
  }

  final extension = filename.substring(dotIndex).toLowerCase();
  if (!RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension)) {
    return '.jpg';
  }
  return extension;
}

bool _isInsideDirectory(String filePath, String directoryPath) {
  final separator = Platform.pathSeparator;
  final normalizedDirectory = directoryPath.endsWith(separator)
      ? directoryPath
      : '$directoryPath$separator';
  return filePath == directoryPath || filePath.startsWith(normalizedDirectory);
}

/// Copies an image-picker result into ClaimScope's persistent private storage.
///
/// The copy is performed by the file system and does not load the full image
/// into Dart memory. The returned [File] is the only path that should be stored
/// in the inspection model.
Future<File> persistInspectionPhoto({
  required InspectionReport report,
  required String sourcePath,
}) async {
  final source = File(sourcePath);
  if (!await source.exists()) {
    throw FileSystemException(
      'The selected photo is no longer available.',
      sourcePath,
    );
  }

  final documentsDirectory = await getApplicationDocumentsDirectory();
  final rootDirectory = Directory(
    '${documentsDirectory.path}/$_inspectionPhotosFolderName',
  );
  await rootDirectory.create(recursive: true);

  final sourceAbsolutePath = source.absolute.path;
  final rootAbsolutePath = rootDirectory.absolute.path;
  if (_isInsideDirectory(sourceAbsolutePath, rootAbsolutePath)) {
    return source;
  }

  final inspectionDirectory = Directory(
    '${rootDirectory.path}/${_inspectionFolderName(report)}',
  );
  await inspectionDirectory.create(recursive: true);

  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final sequence = _photoSequence++;
  final extension = _fileExtension(sourcePath);
  final destination = File(
    '${inspectionDirectory.path}/${timestamp}_$sequence$extension',
  );
  final temporary = File('${destination.path}.tmp');

  try {
    if (await temporary.exists()) {
      await temporary.delete();
    }
    await source.copy(temporary.path);
    return await temporary.rename(destination.path);
  } finally {
    if (await temporary.exists()) {
      await temporary.delete();
    }
  }
}

class MissingInspectionPhotosException implements Exception {
  final List<PhotoItem> missingItems;

  const MissingInspectionPhotosException(this.missingItems);

  @override
  String toString() {
    final uniqueLabels = <String>[];
    final seenLabels = <String>{};
    for (final item in missingItems) {
      final label = item.label.trim().isEmpty ? 'Unlabeled photo' : item.label;
      if (seenLabels.add(label)) {
        uniqueLabels.add(label);
      }
    }

    final visibleLabels = uniqueLabels.take(5).join(', ');
    final remaining = uniqueLabels.length - 5;
    final suffix = remaining > 0 ? ' and $remaining more' : '';

    return 'Some inspection photos are no longer available: '
        '$visibleLabels$suffix. Please retake the missing photos before '
        'generating or sending the report.';
  }
}

Future<void> validatePhotoItems(Iterable<PhotoItem> items) async {
  final missingItems = <PhotoItem>[];
  final checkedPaths = <String, bool>{};

  for (final item in items) {
    final path = item.file.absolute.path;
    var exists = checkedPaths[path];
    if (exists == null) {
      exists = await item.file.exists();
      checkedPaths[path] = exists;
    }
    if (!exists) {
      missingItems.add(item);
    }
  }

  if (missingItems.isNotEmpty) {
    throw MissingInspectionPhotosException(missingItems);
  }
}

/// Stops report/ZIP/email work before heavy processing if any referenced photo
/// has disappeared from storage.
Future<void> validateInspectionPhotoFiles(InspectionReport report) {
  return validatePhotoItems(report.photoReportItems);
}
