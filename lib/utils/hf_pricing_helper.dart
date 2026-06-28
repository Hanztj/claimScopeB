import 'package:claimscope_clean/inspection_report_model.dart';

const double hfElevationsAddon = 55.0;

bool hasChargeableElevationDetails(InspectionReport report) {
  return report.elevations.elevations.any((elevation) => elevation.hasAnyData);
}

double _applyPlanDiscount(double total, String plan) {
  if (plan == 'basic') return total * 0.90;
  if (plan == 'premium') return total * 0.85;
  return total;
}

double calculateResidentialHfEstimatePrice({
  required InspectionReport report,
  required bool rushOrder,
  required String plan,
}) {
  const double basePrice = 70.0;
  const double shedAddon = 10.0;
  const double structureAddon = 15.0;
  const double rushFee = 15.0;

  double total = 0;

  if (!report.isBasePricePaid) {
    total += basePrice;
    if (report.hasShed) total += shedAddon;
    if (report.hasDetachedStructure) total += structureAddon;
  }

  if (hasChargeableElevationDetails(report)) {
    total += hfElevationsAddon;
  }

  if (rushOrder) total += rushFee;

  return _applyPlanDiscount(total, plan);
}

double? calculateCommercialHfEstimatePrice({
  required InspectionReport report,
  required bool rushOrder,
  required String plan,
}) {
  const double basePrice = 100.0;
  const double rushOrderFee = 25.0;
  const double perSectionFee = 30.0;
  const double sectionsCapFee = 120.0;
  const double perBuildingAddon = 50.0;
  const int buildingsLimit = 4;

  final buildingsCount = report.commercialBuildings.length;
  final hasBaseCharge = !report.isBasePricePaid;

  if (hasBaseCharge && buildingsCount == 0) return null;
  if (hasBaseCharge && buildingsCount >= buildingsLimit) return null;

  double total = 0;

  if (hasBaseCharge) {
    total += basePrice;

    for (final building in report.commercialBuildings) {
      final roofSections = building.roofs.length;
      if (roofSections >= 4) {
        total += sectionsCapFee;
      } else if (roofSections > 0) {
        total += roofSections * perSectionFee;
      }
    }

    if (buildingsCount > 1) {
      total += (buildingsCount - 1) * perBuildingAddon;
    }
  }

  if (hasChargeableElevationDetails(report)) {
    total += hfElevationsAddon;
  }

  if (rushOrder) total += rushOrderFee;

  return _applyPlanDiscount(total, plan);
}
