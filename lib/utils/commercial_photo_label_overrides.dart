import 'dart:io';

import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/utils/photo_labels.dart';

/// Builds current Commercial photo labels keyed by absolute file path.
///
/// Element numbering is derived from the current model order, so labels remain
/// aligned after a Flashing, Vent, HVAC, or Mechanical item is deleted.
Map<String, String> buildCommercialPhotoLabelOverrides(
  InspectionReport report,
) {
  final overrides = <String, String>{};

  void addIndexedPhotoGroup({
    required String buildingName,
    required String roofName,
    required String elementName,
    required int elementIndex,
    required File? mainPhoto,
    required List<File> extraPhotos,
  }) {
    final baseLabel = '$elementName ${elementIndex + 1}';

    if (mainPhoto != null) {
      overrides[mainPhoto.absolute.path] = buildCommercialPhotoLabel(
        building: buildingName,
        roof: roofName,
        label: '$baseLabel - Image 1',
      );
    }

    for (var photoIndex = 0;
        photoIndex < extraPhotos.length;
        photoIndex++) {
      final photo = extraPhotos[photoIndex];
      overrides[photo.absolute.path] = buildCommercialPhotoLabel(
        building: buildingName,
        roof: roofName,
        label: '$baseLabel - Image ${photoIndex + 2}',
      );
    }
  }

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

      for (var i = 0; i < roof.shingleFlashings.length; i++) {
        final flashing = roof.shingleFlashings[i];
        addIndexedPhotoGroup(
          buildingName: buildingName,
          roofName: roofName,
          elementName: 'Flashing',
          elementIndex: i,
          mainPhoto: flashing.photo,
          extraPhotos: flashing.extraPhotos,
        );
      }

      for (var i = 0; i < roof.tpoFlashings.length; i++) {
        final flashing = roof.tpoFlashings[i];
        addIndexedPhotoGroup(
          buildingName: buildingName,
          roofName: roofName,
          elementName: 'Flashing',
          elementIndex: i,
          mainPhoto: flashing.photo,
          extraPhotos: flashing.extraPhotos,
        );
      }

      for (var i = 0; i < roof.shingleVents.length; i++) {
        final vent = roof.shingleVents[i];
        addIndexedPhotoGroup(
          buildingName: buildingName,
          roofName: roofName,
          elementName: 'Vent',
          elementIndex: i,
          mainPhoto: vent.photo,
          extraPhotos: vent.extraPhotos,
        );
      }

      for (var i = 0; i < roof.tpoVents.length; i++) {
        final vent = roof.tpoVents[i];
        addIndexedPhotoGroup(
          buildingName: buildingName,
          roofName: roofName,
          elementName: 'Vent',
          elementIndex: i,
          mainPhoto: vent.photo,
          extraPhotos: vent.extraPhotos,
        );
      }

      for (var i = 0; i < roof.hvacUnits.length; i++) {
        final unit = roof.hvacUnits[i];
        addIndexedPhotoGroup(
          buildingName: buildingName,
          roofName: roofName,
          elementName: 'HVAC',
          elementIndex: i,
          mainPhoto: unit.photo,
          extraPhotos: unit.extraPhotos,
        );
      }

      for (var i = 0; i < roof.mechanicalUnits.length; i++) {
        final unit = roof.mechanicalUnits[i];
        addIndexedPhotoGroup(
          buildingName: buildingName,
          roofName: roofName,
          elementName: 'Mechanical',
          elementIndex: i,
          mainPhoto: unit.photo,
          extraPhotos: unit.extraPhotos,
        );
      }
    }
  }

  return overrides;
}
