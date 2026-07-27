import 'dart:io';

import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/utils/persistent_photo_storage.dart';
import 'package:image_picker/image_picker.dart';

typedef GalleryPhotoAttachedCallback = void Function(File file, String label);

Future<int> pickAndAttachGalleryPhotos({
  required ImagePicker picker,
  required InspectionReport report,
  required String Function() labelBuilder,
  GalleryPhotoAttachedCallback? onPhotoAttached,
}) async {
  final pickedFiles = await picker.pickMultiImage(
    maxWidth: 1024,
    imageQuality: 75,
  );

  if (pickedFiles.isEmpty) return 0;

  for (final pickedFile in pickedFiles) {
    final file = await persistInspectionPhoto(
      report: report,
      sourcePath: pickedFile.path,
    );
    final label = labelBuilder();
    report.addPhoto(file, label);
    onPhotoAttached?.call(file, label);
  }

  return pickedFiles.length;
}
