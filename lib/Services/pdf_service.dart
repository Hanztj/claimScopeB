import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/utils/photo_labels.dart'; 

class _PdfPhotoItemBytes {
  final Uint8List bytes;
  final String label;

  const _PdfPhotoItemBytes({
    required this.bytes,
    required this.label,
  });
}

class PdfService {

  static Future<Map<String, File>> generateReports(InspectionReport report) async {

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

    final pdfTech = pw.Document();
    final pdfPhotos = pw.Document();
      // Determinar si es comercial
  final isCommercial = report.isCommercial == true || report.commercialBuildings.isNotEmpty;
  
  if(isCommercial){
          
        // --- PDF TÉCNICO COMERCIAL ---
        pdfTech.addPage(
        pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
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
                          // --- PDF DE FOTOS COMERCIAL ---
// Recolectar todas las fotos comerciales
    final List<PhotoItem> commercialPhotos = [];

for (var building in report.commercialBuildings) {
  for (var roof in building.roofs) {
    if (roof.overviewPhoto != null) {
      commercialPhotos.add(PhotoItem(
        file: roof.overviewPhoto!,
        label: '${building.name ?? 'Building'} - ${roof.roofLabel ?? 'Roof'} - Overview',
      ));
    }
    if (roof.coreSamplePhoto != null) {
      commercialPhotos.add(PhotoItem(
        file: roof.coreSamplePhoto!,
        label: '${building.name ?? 'Building'} - ${roof.roofLabel ?? 'Roof'} - Core Sample',
      ));
    }
    if (roof.valleyMetalPhoto != null) {
      commercialPhotos.add(PhotoItem(
        file: roof.valleyMetalPhoto!,
        label: '${building.name ?? 'Building'} - ${roof.roofLabel ?? 'Roof'} - Valley Metal',
      ));
    }
    for (var flashing in roof.shingleFlashings) {
      if (flashing.photo != null) {
        commercialPhotos.add(PhotoItem(
          file: flashing.photo!,
          label: '${building.name ?? 'Building'} - ${roof.roofLabel ?? 'Roof'} - Flashing: ${_describeFlashing(flashing)}',
        ));
      }
      for (var extraPhoto in flashing.extraPhotos) {
        commercialPhotos.add(PhotoItem(
          file: extraPhoto,
          label: '${building.name ?? 'Building'} - ${roof.roofLabel ?? 'Roof'} - Flashing extra: ${_describeFlashing(flashing)}',
        ));
      }
    }
    for (var vent in roof.shingleVents) {
      if (vent.photo != null) {
        commercialPhotos.add(PhotoItem(
          file: vent.photo!,
          label: '${building.name ?? 'Building'} - ${roof.roofLabel ?? 'Roof'} - Vent: ${_describeVent(vent)}',
        ));
      }
      for (var extraPhoto in vent.extraPhotos) {
        commercialPhotos.add(PhotoItem(
          file: extraPhoto,
          label: '${building.name ?? 'Building'} - ${roof.roofLabel ?? 'Roof'} - Vent extra: ${_describeVent(vent)}',
        ));
      }
    }
for (var flashing in roof.tpoFlashings) {
  if (flashing.photo != null) {
    commercialPhotos.add(PhotoItem(
      file: flashing.photo!,
      label: '${building.name ?? 'Building'} - ${roof.roofLabel ?? 'Roof'} - Flashing: ${flashing.type}',
    ));
  }
}
for (var vent in roof.tpoVents) {
  if (vent.photo != null) {
    commercialPhotos.add(PhotoItem(
      file: vent.photo!,
      label: '${building.name ?? 'Building'} - ${roof.roofLabel ?? 'Roof'} - Vent: ${vent.type}',
    ));
  }
}
    for (var hvac in roof.hvacUnits) {
      if (hvac.photo != null) {
        commercialPhotos.add(PhotoItem(
          file: hvac.photo!,
          label: '${building.name ?? 'Building'} - ${roof.roofLabel ?? 'Roof'} - HVAC: ${hvac.type ?? 'Unknown'}',
        ));
      }
    }
    for (var mechanical in roof.mechanicalUnits) {
      if (mechanical.photo != null) {
        commercialPhotos.add(PhotoItem(
          file: mechanical.photo!,
          label: '${building.name ?? 'Building'} - ${roof.roofLabel ?? 'Roof'} - Mechanical: ${mechanical.type ?? 'Unknown'}',
        ));
      }
    }
  }
}

for (var i = 0; i < commercialPhotos.length; i += 2) {
  final firstPhoto = await _loadPdfPhotoItemBytes(commercialPhotos[i]);
  final secondPhoto = i + 1 < commercialPhotos.length
      ? await _loadPdfPhotoItemBytes(commercialPhotos[i + 1])
      : null;

  pdfPhotos.addPage(
    pw.Page(
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
                      
             // --- PDF DE FOTOS: 2 POR PÁGINA ---
     for (var i = 0; i < report.photoReportItems.length; i += 2) {
      final firstPhoto = await _loadPdfPhotoItemBytes(report.photoReportItems[i]);
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
    }}
     // Guardar archivos PDF
    String sanitizeFilename(String input) {
    var s = input.trim();
    if (s.isEmpty) return 'UNKNOWN';
    s = s.replaceAll(RegExp(r'[\/\\\:\*\?\"\<\>\|]'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? 'UNKNOWN' : s;
    }

    // Guardar archivos PDF
    // Guardar archivos PDF - Versión unificada
    final dir = await getApplicationDocumentsDirectory();

    final claim = report.claimNumber.trim().isEmpty
        ? 'NOCLAIM'
        : sanitizeFilename(report.claimNumber);

    final insured = report.clientName.trim().isEmpty
        ? 'UNKNOWN'
        : sanitizeFilename(report.clientName);

    // Determinar nombre según tipo de reporte

    final techName = isCommercial
        ? '$claim - $insured - Commercial Inspection Report.pdf'
        : '$claim - $insured - Inspection Report.pdf';

    final photoName = isCommercial
        ? '$claim - $insured - Commercial Inspection Photos.pdf'
        : '$claim - $insured - Inspection Photos.pdf';

    final techFile = File('${dir.path}/$techName');
    final photoFile = File('${dir.path}/$photoName');

    await techFile.writeAsBytes(await pdfTech.save());
    await photoFile.writeAsBytes(await pdfPhotos.save());

   return {'tech': techFile, 'photos': photoFile};
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
          report.estimatedAge != null ? "${report.estimatedAge} years" : "N/A",
        ),
        _buildDataRow(
          "Number of Layers",
          report.numLayers != null ? report.numLayers.toString() : "N/A",
        ),
        _buildDataRow(
          "Ridge Vent",
          report.facets.any((f) => f.hasRidgeVent)
              ? "Yes (${report.facets.where((f) => f.hasRidgeVent).map((f) => '${f.name}: ${f.ridgeVentType ?? 'Type N/A'}').join(', ')})"
              : "No",
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
          "Sheathing required to be changed",
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
                    _buildTableCell(facet.pitch ?? "N/A"),
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

    static List<pw.Widget> _buildElevationsUnderlaymentDetails(InspectionReport report) {
      if (!report.inspectElevations) return [];

      final rows = <pw.Widget>[];
      for (final elevation in report.elevations.elevations) {
        final siding = elevation.siding.sidingMain;
        final underlayment = elevation.underlayment;
        final substrate = elevation.substrate;
        final eifs = elevation.eifs;
        final hasSidingScope = _hasElevationSidingScopeData(elevation.siding);
        final windows = elevation.windows;
        final doors = elevation.doors;
        final hasWindows = windows.any((w) => w.hasAnyData == true);
        final hasDoors = doors.any((d) => d.hasAnyData == true);
        if (!underlayment.hasAnyData &&
            !hasSidingScope &&
            !substrate.hasAnyData &&
            !eifs.hasAnyData &&
            !hasWindows &&
            !hasDoors) {
          continue;
        }
        if (!_isUnderlaymentApplicableSiding(siding) &&
            !hasSidingScope &&
            !substrate.hasAnyData &&
            !eifs.hasAnyData &&
            !hasWindows &&
            !hasDoors) {
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
              underlayment.hasAnyData)
            ..._buildElevationUnderlaymentRows(siding, underlayment),
          if (substrate.hasAnyData) ..._buildElevationSubstrateRows(substrate),
          if (eifs.hasAnyData) ..._buildElevationEifsRows(eifs),
          if (hasWindows) ..._buildElevationWindowRows(windows),
          if (hasDoors) ..._buildElevationDoorRows(doors),
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

    static List<pw.Widget> _buildElevationSidingScopeRows(dynamic siding) {
      final rows = <pw.Widget>[];
      final sidingType = (siding.sidingMain as String?) ?? '';

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
        return rows;
      }

      if (siding.changeWholeElevation) {
        rows.add(_buildDataRow("Siding Scope of Work", "Change whole elevation siding"));
      } else if (siding.howManySf.trim().isNotEmpty) {
        rows.add(_buildDataRow("Siding Scope of Work", "Partial replacement (${siding.howManySf.trim()} SF)"));
      }

      return rows;
    }

    static bool _hasElevationSidingScopeData(dynamic siding) {
      final sidingType = (siding.sidingMain as String?) ?? '';
      if (sidingType == 'Stucco') {
        return siding.stuccoScope.trim().isNotEmpty;
      }
      return siding.changeWholeElevation || siding.howManySf.trim().isNotEmpty;
    }

    static List<pw.Widget> _buildElevationUnderlaymentRows(
      String siding,
      dynamic underlayment,
    ) {
      final rows = <pw.Widget>[];

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
      if (door.entryQuantity != null && door.entryQuantity.trim().isNotEmpty) {
        rows.add(_buildDataRow("Quantity", door.entryQuantity.trim()));
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

      if (roof.roofType == 'Shingles') {
        widgets.addAll([
          _buildDataRow("    Pitch", roof.pitch ?? "N/A"),
          _buildDataRow(
            "    Multiple layers",
            roof.hasMultipleLayers == true
                ? "Yes (${roof.numberOfLayers ?? 'N/A'})"
                : "No",
          ),
          _buildDataRow("    Starter row installed", roof.starterRowInstalled ? "Yes" : "No"),
          if (roof.starterRowInstalled) ...[
            _buildDataRow("    Starter row at eave", roof.starterEaveInstalled ? "Yes" : "No"),
            _buildDataRow("    Starter row at rake", roof.starterRakeInstalled ? "Yes" : "No"),
          ],
          _buildDataRow(
            "    Drip edge",
            roof.hasDripEdge ? "Yes (${roof.dripEdgeType ?? 'Type N/A'})" : "No",
          ),
          _buildDataRow("    Ice & Water Barrier", roof.iceAndWaterBarrierInstalled ? "Yes" : "No"),
          _buildDataRow("    Has ridge", roof.hasRidge ? "Yes" : "No"),
          if (roof.hasRidge)
            _buildDataRow(
              "    Ridge vent",
              roof.hasRidgeVent ? "Yes (${roof.ridgeVentType ?? 'Type N/A'})" : "No",
            ),
          _buildDataRow(
            "    Has valley",
            roof.hasValleyMetal ? "Yes (${roof.valleyMetalType ?? 'Type N/A'})" : "No",
          ),
          _buildDataRow(
            "    Roof deck replacement",
            roof.deckChangeRequired
                ? (roof.deckFullReplacementRequired
                    ? "Full replacement"
                    : "Partial (${roof.deckPartialReplacementSqft ?? 'N/A'} SF)")
                : "No",
          ),
          _buildDataRow(
            "    Flashings",
            roof.shingleFlashings.isEmpty
                ? "None recorded"
                : roof.shingleFlashings.map(_describeFlashing).join("; "),
          ),
          _buildDataRow(
            "    Vents",
            roof.shingleVents.isEmpty
                ? "None recorded"
                : roof.shingleVents.map(_describeVent).join("; "),
          ),
          _buildDataRow("    HVAC equipment", roof.hvacUnits.isEmpty ? "None recorded" : roof.hvacUnits.length.toString()),
          _buildDataRow("    Mechanical equipment", roof.mechanicalUnits.isEmpty ? "None recorded" : roof.mechanicalUnits.length.toString()),
        ]);
      }

      return widgets;
    }

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

    static Future<_PdfPhotoItemBytes> _loadPdfPhotoItemBytes(PhotoItem item) async {
      return _PdfPhotoItemBytes(
        bytes: await item.file.readAsBytes(),
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