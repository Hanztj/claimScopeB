import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:claimscope_clean/inspection_report_model.dart';


class PdfService {

  static Future<Map<String, File>> generateReports(InspectionReport report) async {
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
                    pw.SizedBox(height: 3),
                  ],
                );
              }),
              pw.SizedBox(height: 10),
            ],
           );
          }),
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
  pdfPhotos.addPage(
    pw.Page(
      build: (context) => pw.Column(
        children: [
          _buildPhotoFrame(commercialPhotos[i]),
          if (i + 1 < commercialPhotos.length) ...[
            pw.SizedBox(height: 20),
            _buildPhotoFrame(commercialPhotos[i + 1]),
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
   _buildSectionTitle("ROOF SYSTEM DETAILS"),
   _buildDataRow("Occupancy Type", "Residential"),
   _buildDataRow("Roof Cover Type", report.roofCoverType ?? "N/A"),
   _buildDataRow("Subtype", report.roofSubType ?? "N/A"),

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
   _buildDataRow(
    "Sheathing type",
    report.sheathingType ?? "N/A",
   ),
   _buildDataRow(
    "Sheathing size",
    report.sheathingSize ?? "N/A",
    ),
   ],

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
   _buildDataRow(
   "Drip Edge",
   report.hasDripEdge
      ? "Yes (${report.dripEdgeType ?? 'Type N/A'})"
      : "No",
   ),
   _buildDataRow(
   "Shed requiring replacement (≤ 6 SQ)",
   report.hasShed ? "Yes" : "No",
   ),
   _buildDataRow(
    "Larger/detached structure requiring replacement",
   report.hasDetachedStructure ? "Yes" : "No",
    ),
     pw.SizedBox(height: 10),
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


   // NUEVO: DETALLES POR FACET
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
              
              _buildDataRow(
              "Ridge Vent",
               facet.hasRidgeVent
               ? "Yes (${facet.ridgeVentType ?? 'Type N/A'})"
               : "No",
               ),
               
            _buildDataRow(
              "ATR Performed",
              facet.atrPerformed ? "Yes" : "No",
            ),
            if (facet.atrPerformed)
              _buildDataRow(
                "ATR Result",
                facet.atrResult ?? "N/A",
              ),
            _buildDataRow(
              "Has Valley Metal",
              facet.hasValleyMetal ? "Yes" : "No",
            ),
            if (facet.hasValleyMetal)
              _buildDataRow(
                "Valley Metal Type",
                facet.valleyMetalType ?? "N/A",
               ),

    ...facet.flashings.map((f) {
     // base: tipo u "Other: ..."
    String desc;
    if (f.type == 'Other') {
    desc = 'Other: ${f.otherSpecify ?? ''}';
    } else {
     desc = f.type;
     }

    // añadir size/material/finish/grade si existen
    final parts = <String>[];
    if (f.size != null && f.size!.trim().isNotEmpty) {
     parts.add(f.size!);
   }
    if (f.material != null && f.material!.trim().isNotEmpty) {
     parts.add(f.material!);
    }
    if (f.finish != null && f.finish!.trim().isNotEmpty) {
     parts.add(f.finish!);
    }
    if (f.grade != null && f.grade!.trim().isNotEmpty) {
     parts.add(f.grade!);
   }

    if (parts.isNotEmpty) {
    desc = '$desc (${parts.join(', ')})';
    }

    final change = f.shouldBeChanged ? "Yes" : "No";

    return _buildDataRow(
    "  - $desc",
    "Should be changed: $change",
    );
   }),

                                // NUEVO: Vents
            if (facet.vents.isEmpty)
              _buildDataRow("Vents", "None recorded")
            else ...[
              _buildDataRow("Vents", ""),
              ...facet.vents.map((v) {
                // Descripción básica
                String desc;
                if (v.type == 'Other') {
                  desc = 'Other: ${v.otherSpecify ?? ''}';
                } else {
                  desc = v.type;
                }

                final count = (v.count != null && v.count!.isNotEmpty)
                    ? v.count
                    : '0';

                // Extras para Pipe jack
                String extras = '';
                if (v.type == 'Pipe jack') {
                  final split = v.includeSplitBoot ? 'Split boot' : null;
                  final lead = v.includeLead ? 'Lead' : null;
                  final extraList = [split, lead].whereType<String>().toList();
                  if (extraList.isNotEmpty) {
                    extras = ' (${extraList.join(', ')})';
                  }
                }
                
                final change = v.shouldBeChanged ? "Yes" : "No";

                return _buildDataRow(
                  "  - $desc$extras x$count",
                  "Should be changed: $change",
                );
              }),
            ],
                        if (facet.comment != null &&
                facet.comment!.trim().isNotEmpty)
              _buildDataRow(
                "Additional comment",
                facet.comment!,
              ),


            pw.SizedBox(height: 6),
          ],
        ),
      );
       }).toList(),
        ),
       pw.SizedBox(height: 10),
        ],
       ),
     );
                      
             // --- PDF DE FOTOS: 2 POR PÁGINA ---
     for (var i = 0; i < report.photoReportItems.length; i += 2) {
      pdfPhotos.addPage(
        pw.Page(
          build: (context) => pw.Column(
            children: [
              _buildPhotoFrame(report.photoReportItems[i]),
              if (i + 1 < report.photoReportItems.length) ...[ 
                  pw.SizedBox(height: 20),
                _buildPhotoFrame(report.photoReportItems[i + 1]),
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

    static pw.Widget _buildPhotoFrame(PhotoItem item) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(item.label, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Container(
          height: 300, // Altura optimizada para 2 por página A4
          width: double.infinity,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
          child: pw.Image(pw.MemoryImage(item.file.readAsBytesSync()), fit: pw.BoxFit.cover),
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
