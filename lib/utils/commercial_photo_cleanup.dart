import 'dart:io';

import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/utils/photo_labels.dart';

typedef CommercialPhotoGroup = ({String building, String roof});

String commercialRoofDisplayName(
  CommercialRoofSectionData roof,
  int roofIndex,
) {
  final customName = (roof.roofLabel ?? '').trim();
  return customName.isEmpty ? 'Roof ${roofIndex + 1}' : customName;
}

Iterable<File?> commercialRoofOwnedPhotos(CommercialRoofSectionData roof) sync* {
  yield roof.overviewPhoto;
  yield roof.starterEavePhoto;
  yield* roof.starterEaveExtraPhotos;
  yield roof.starterRakePhoto;
  yield* roof.starterRakeExtraPhotos;
  yield roof.dripEdgePhoto;
  yield* roof.dripEdgeExtraPhotos;
  yield roof.iceAndWaterBarrierPhoto;
  yield* roof.iceAndWaterBarrierExtraPhotos;
  yield roof.ridgeVentPhoto;
  yield* roof.ridgeVentExtraPhotos;
  yield roof.valleyMetalPhoto;
  yield* roof.valleyMetalExtraPhotos;
  yield roof.coreSamplePhoto;
  yield* roof.coreSampleExtraPhotos;

  for (final flashing in roof.shingleFlashings) {
    yield flashing.photo;
    yield* flashing.extraPhotos;
  }
  for (final flashing in roof.tpoFlashings) {
    yield flashing.photo;
    yield* flashing.extraPhotos;
  }
  for (final vent in roof.shingleVents) {
    yield vent.photo;
    yield* vent.extraPhotos;
  }
  for (final vent in roof.tpoVents) {
    yield vent.photo;
    yield* vent.extraPhotos;
  }
  for (final unit in roof.hvacUnits) {
    yield unit.photo;
    yield unit.nameplatePhoto;
    yield* unit.extraPhotos;
  }
  for (final unit in roof.mechanicalUnits) {
    yield unit.photo;
    yield unit.nameplatePhoto;
    yield* unit.extraPhotos;
  }
}

Set<CommercialPhotoGroup> commercialRoofPhotoGroups({
  required InspectionReport report,
  required int buildingIndex,
  required int roofIndex,
}) {
  final building = report.commercialBuildings[buildingIndex];
  final roof = building.roofs[roofIndex];
  final groups = <CommercialPhotoGroup>{
    (
      building: building.displayName(buildingIndex),
      roof: commercialRoofDisplayName(roof, roofIndex),
    ),
  };

  final overviewPath = roof.overviewPhoto?.absolute.path;
  if (overviewPath != null) {
    for (final item in report.photoReportItems) {
      if (item.file.absolute.path != overviewPath) continue;
      final parsed = tryParseCommercialPhotoLabel(item.label);
      if (parsed != null) {
        groups.add((building: parsed.building, roof: parsed.roof));
      }
      return groups;
    }
  }

  // Defensive fallback for a section renamed before an overview was captured
  // or for an inspection already contaminated by legacy photo ownership.
  final ownedPaths = commercialRoofOwnedPhotos(roof)
      .whereType<File>()
      .map((file) => file.absolute.path)
      .toSet();
  if (ownedPaths.isEmpty) return groups;

  for (final item in report.photoReportItems) {
    if (!ownedPaths.contains(item.file.absolute.path)) continue;
    final parsed = tryParseCommercialPhotoLabel(item.label);
    if (parsed != null) {
      groups.add((building: parsed.building, roof: parsed.roof));
    }
  }

  return groups;
}

void removeCommercialSingletonPhotoItems({
  required InspectionReport report,
  required int buildingIndex,
  required int roofIndex,
  required String baseLabel,
}) {
  final groups = commercialRoofPhotoGroups(
    report: report,
    buildingIndex: buildingIndex,
    roofIndex: roofIndex,
  );
  final imagePattern = RegExp(
    '^${RegExp.escape(baseLabel.trim())} - Image [0-9]+\$',
  );

  report.removePhotosWhere((item) {
    final parsed = tryParseCommercialPhotoLabel(item.label);
    if (parsed == null || !imagePattern.hasMatch(parsed.label.trim())) {
      return false;
    }
    return groups.contains((building: parsed.building, roof: parsed.roof));
  });
}

void removeCommercialRoofSectionPhotos({
  required InspectionReport report,
  required int buildingIndex,
  required int roofIndex,
}) {
  final building = report.commercialBuildings[buildingIndex];
  final roof = building.roofs[roofIndex];
  final groups = commercialRoofPhotoGroups(
    report: report,
    buildingIndex: buildingIndex,
    roofIndex: roofIndex,
  );

  report.removePhotosByFiles(commercialRoofOwnedPhotos(roof));
  report.removePhotosWhere((item) {
    final parsed = tryParseCommercialPhotoLabel(item.label);
    return parsed != null &&
        groups.contains((building: parsed.building, roof: parsed.roof));
  });
}

void removeCommercialBuildingPhotos({
  required InspectionReport report,
  required int buildingIndex,
}) {
  final building = report.commercialBuildings[buildingIndex];
  for (var roofIndex = building.roofs.length - 1;
      roofIndex >= 0;
      roofIndex--) {
    removeCommercialRoofSectionPhotos(
      report: report,
      buildingIndex: buildingIndex,
      roofIndex: roofIndex,
    );
  }
}
