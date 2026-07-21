import 'dart:io';

import 'package:claimscope_clean/catalogs/flashing_catalog.dart';
import 'package:claimscope_clean/catalogs/roof_catalog.dart';
import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/screens/commercial/hubs/commercial_flat_hub.dart';
import 'package:claimscope_clean/screens/commercial/hubs/commercial_metal_hub.dart';
import 'package:claimscope_clean/screens/commercial/hubs/commercial_other_hub.dart';
import 'package:claimscope_clean/screens/commercial/hubs/commercial_shingles_hub.dart';
import 'package:claimscope_clean/screens/commercial/hubs/commercial_slate_hub.dart';
import 'package:claimscope_clean/screens/commercial/hubs/commercial_tile_hub.dart';
import 'package:claimscope_clean/screens/commercial_building_details_screen.dart';
import 'package:claimscope_clean/screens/elevations/elevations_inspection_screen.dart';
import 'package:claimscope_clean/services/inspection_submission_service.dart';
import 'package:claimscope_clean/services/pdf_service.dart';
import 'package:claimscope_clean/utils/gallery_photo_helper.dart';
import 'package:claimscope_clean/utils/photo_labels.dart';
import 'package:claimscope_clean/utils/required_photo_validation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CommercialRoofSectionScreen extends StatefulWidget {
  final String plan;
  final InspectionReport report;
  final int buildingIndex;
  final int roofIndex;

  const CommercialRoofSectionScreen({
    super.key,
    required this.plan,
    required this.report,
    required this.buildingIndex,
    required this.roofIndex,
  });

  @override
  State<CommercialRoofSectionScreen> createState() => _CommercialRoofSectionScreenState();
 }

 class _CommercialRoofSectionScreenState extends State<CommercialRoofSectionScreen> {
  late final CommercialRoofSectionData roof;
  bool _submitRoofOnly = false;

  final _picker = ImagePicker();

  final _roofLabelController = TextEditingController();
  final _pitchController = TextEditingController();
  final _facetCountController = TextEditingController();
  final _roofSubTypeOtherController = TextEditingController();
  final _layersCountController = TextEditingController();
  final _deckOtherController = TextEditingController();
  final _deckThicknessGaugeController = TextEditingController();
  final _deckPartialSqftController = TextEditingController();

  final _coverOtherController = TextEditingController();
  final _notesController = TextEditingController();

  final _showFinishActions = false;

  @override
  void initState() {
    super.initState();
    final building = widget.report.commercialBuildings[widget.buildingIndex];
    roof = building.roofs[widget.roofIndex];

    _roofLabelController.text = roof.roofLabel ?? '';
    _pitchController.text = roof.pitch ?? '';
    _facetCountController.text = roof.facetCount.toString();
    _roofSubTypeOtherController.text = roof.roofSubTypeOtherSpecify ?? '';
    _layersCountController.text = roof.numberOfLayers?.toString() ?? '';
    _deckOtherController.text = roof.deckTypeOtherSpecify ?? '';
    _deckThicknessGaugeController.text = roof.deckThicknessGauge ?? '';
    _deckPartialSqftController.text = roof.deckPartialReplacementSqft ?? '';

    _coverOtherController.text = roof.coverBoardOtherSpecify ?? '';
    _notesController.text = roof.notes ?? '';
  }

  @override
  void dispose() {
    _roofLabelController.dispose();
    _pitchController.dispose();
    _facetCountController.dispose();
    _roofSubTypeOtherController.dispose();
    _layersCountController.dispose();
    _deckOtherController.dispose();
    _deckThicknessGaugeController.dispose();
    _deckPartialSqftController.dispose();
    _coverOtherController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isFlatSystem => roof.roofType == 'TPO' || roof.roofType == 'EPDM' || roof.roofType == 'Modified Bitumen';
  bool get _isMetal => roof.roofType == 'Metal';
  bool get _isShingles => roof.roofType == 'Shingles';
  bool get _isTile => roof.roofType == 'Tile roofing';
  bool get _isSlate => roof.roofType == 'Slate Roof';
  bool get _isOther => roof.roofType == 'Other';

  Future<void> _takeCommercialPhoto({
    required String buildingName,
    required String roofName,
    required String photoLabel,
    required void Function(File file) onSaved,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 75,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (picked == null) return;

    final file = File(picked.path);
    final storedLabel = buildCommercialPhotoLabel(
      building: buildingName,
      roof: roofName,
      label: photoLabel,
    );

    setState(() {
      onSaved(file);
      widget.report.addPhoto(file, storedLabel);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo stored'),
        duration: Duration(seconds: 2),
      ),
    );
  }


  Future<void> _pickCommercialGalleryPhotos({
    required String buildingName,
    required String roofName,
  }) async {
    final count = await pickAndAttachGalleryPhotos(
      picker: _picker,
      report: widget.report,
      labelBuilder: () => buildCommercialPhotoLabel(
        building: buildingName,
        roof: roofName,
        label: 'User Image',
      ),
    );

    if (count == 0 || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photos added')),
    );
  }

  bool _showRequiredPhotoError(String? message) {
    if (message == null) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
    return true;
  }

  void _sync() {
    roof.roofLabel = _roofLabelController.text.trim().isEmpty
        ? null
        : _roofLabelController.text.trim();

    roof.roofSubTypeOtherSpecify = _roofSubTypeOtherController.text.trim().isEmpty
        ? null
        : _roofSubTypeOtherController.text.trim();

    final layers = int.tryParse(_layersCountController.text.trim());
    if (roof.hasMultipleLayers == true) {
      roof.numberOfLayers = layers != null && layers > 1 ? layers : null;
    } else if (roof.hasMultipleLayers == false) {
      roof.numberOfLayers = 1;
    }

    roof.pitch = _pitchController.text.trim().isEmpty
        ? null
        : _pitchController.text.trim();

    final facetCount = int.tryParse(_facetCountController.text.trim());
    if (roof.hasMultipleFacets) {
      if (facetCount != null && facetCount > 1) {
        roof.facetCount = facetCount;
      } else {
        roof.facetCount = 2;
      }
    } else {
      roof.facetCount = 1;
    }

    roof.deckTypeOtherSpecify = _deckOtherController.text.trim().isEmpty
        ? null
        : _deckOtherController.text.trim();

    roof.deckThicknessGauge = _deckThicknessGaugeController.text.trim().isEmpty
        ? null
        : _deckThicknessGaugeController.text.trim();

    roof.deckPartialReplacementSqft =
        _deckPartialSqftController.text.trim().isEmpty
            ? null
            : _deckPartialSqftController.text.trim();

    roof.coverBoardOtherSpecify = _coverOtherController.text.trim().isEmpty
        ? null
        : _coverOtherController.text.trim();

    roof.notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final building = widget.report.commercialBuildings[widget.buildingIndex];
    final buildingName = building.displayName(widget.buildingIndex);

    final roofName = (roof.roofLabel ?? '').trim().isEmpty
        ? 'Roof ${widget.roofIndex + 1}'
        : roof.roofLabel!.trim();

    final overviewLabel = 'Roof Overview Photo';

    final subtypes = subtypesForRoofType(roof.roofType);
    if (roof.roofSubType != null && !subtypes.contains(roof.roofSubType)) {
      roof.roofSubType = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$buildingName - $roofName'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _roofLabelController,
            decoration: const InputDecoration(
              labelText: 'Roof label (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _sync(),
          ),

            const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _takeCommercialPhoto(
              buildingName: buildingName,
              roofName: roofName,
              photoLabel: overviewLabel,
              onSaved: (f) => roof.overviewPhoto = f,
            ),
            child: const Text('Take overview photo'),
          ),
          TextButton(
            onPressed: () => _takeCommercialPhoto(
              buildingName: buildingName,
              roofName: roofName,
              photoLabel: '$overviewLabel - Image 2',
              onSaved: (_) {},
            ),
            child: const Text('Add additional overview photo'),
          ),
          if (roof.overviewPhoto != null) ...[
            const SizedBox(height: 8),
            Image.file(roof.overviewPhoto!, height: 140, cacheWidth: 420, fit: BoxFit.cover),
          ],

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: roof.roofType,
            decoration: const InputDecoration(
              labelText: 'Roof cover type',
              border: OutlineInputBorder(),
            ),
            items: roofTypesAll
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (val) {
              setState(() {
                roof.roofType = val;
                roof.roofSubType = null;
                roof.roofSubTypeOtherSpecify = null;

                // Reset type-specific fields when switching.
                roof.metalStyle = null;
                roof.metalHasFacets = null;
                roof.pitch = null;
                roof.hasMultipleFacets = false;
                roof.facetCount = 1;

                roof.hasMultipleLayers = null;
                roof.numberOfLayers = null;
                roof.starterRowInstalled = false;
                roof.starterEaveInstalled = false;
                roof.starterRakeInstalled = false;
                roof.starterEavePhoto = null;
                roof.starterRakePhoto = null;
                roof.hasDripEdge = false;
                roof.dripEdgeType = null;
                roof.dripEdgePhoto = null;
                roof.iceAndWaterBarrierInstalled = false;
                roof.iceAndWaterBarrierPhoto = null;
                roof.hasRidge = false;
                roof.hasRidgeVent = false;
                roof.ridgeVentType = null;
                roof.ridgeVentPhoto = null;
                roof.hasValleyMetal = false;
                roof.valleyMetalType = null;
                roof.valleyMetalPhoto = null;
                roof.shingleFlashings.clear();
                roof.hasVents = false;
                roof.shingleVents.clear();
                roof.hasHvacEquipment = false;
                roof.hasMechanicalEquipment = false;
                roof.hvacUnits.clear();
                roof.mechanicalUnits.clear();

                roof.coreSamplePerformed = false;
                roof.coreSamplePhoto = null;
                roof.insulationKnown = null;
                roof.gravelBallastPresent = false;

                roof.deckChangeRequired = false;
                roof.deckFullReplacementRequired = false;
                roof.deckPartialReplacementSqft = null;
                roof.deckType = null;
                roof.deckTypeOtherSpecify = null;
                roof.deckThicknessGauge = null;

                roof.insulationMaterial = null;
                roof.insulationThickness = null;
                roof.insulationMaterialOtherSpecify = null;
                roof.isTapered = false;
                roof.hasCoverBoard = false;
                roof.coverBoardType = null;
                roof.coverBoardThickness = null;
                roof.coverBoardOtherSpecify = null;

                roof.noCoreSampleApproach = null;

                roof.battenChangeRequired = null;

                _pitchController.clear();
                roof.hasMultipleFacets = false;
                _facetCountController.text = '1';
                _layersCountController.clear();
                _deckOtherController.clear();
                _coverOtherController.clear();

              });
            },
          ),
   if (subtypes.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true, // 👈 SOLUCIÓN 1: Obliga al Dropdown a ocupar el ancho disponible de forma segura
              initialValue: roof.roofSubType,
              decoration: const InputDecoration(
                labelText: 'Subtype',
                border: OutlineInputBorder(),
              ),
              items: subtypes
             .map((t) => DropdownMenuItem(
             value: t,
            child: Text(
            t,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
                 ),
                  ))
          .toList(),
              onChanged: (val) {
                setState(() {
                  roof.roofSubType = val;
                  if (val != 'Other') {
                    roof.roofSubTypeOtherSpecify = null;
                    _roofSubTypeOtherController.clear();
                  }
                });
              },
            ),
            if (roof.roofSubType == 'Other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _roofSubTypeOtherController,
                decoration: const InputDecoration(
                  labelText: 'Specify',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _sync(),
              ),
            ],
          ],
          if (_isOther) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _roofSubTypeOtherController,
              decoration: const InputDecoration(
                labelText: 'Specify',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _sync(),
            ),
          ],
          if (_isMetal)
            CommercialMetalHubForm(
              roof: roof,
              buildingName: buildingName,
              roofName: roofName,
              pitchController: _pitchController,
              facetCountController: _facetCountController,
              deckPartialSqftController: _deckPartialSqftController,
              setState: setState,
              sync: _sync,
              takeCommercialPhoto: _takeCommercialPhoto,
            ),
          if (_isShingles)
            CommercialShinglesHubForm(
              roof: roof,
              buildingName: buildingName,
              roofName: roofName,
              pitchController: _pitchController,
              facetCountController: _facetCountController,
              layersCountController: _layersCountController,
              deckPartialSqftController: _deckPartialSqftController,
              setState: setState,
              sync: _sync,
              takeCommercialPhoto: _takeCommercialPhoto,
            ),
          if (_isTile)
            CommercialTileHubForm(
              roof: roof,
              buildingName: buildingName,
              roofName: roofName,
              pitchController: _pitchController,
              facetCountController: _facetCountController,
              deckPartialSqftController: _deckPartialSqftController,
              setState: setState,
              sync: _sync,
              takeCommercialPhoto: _takeCommercialPhoto,
            ),
          if (_isSlate)
            CommercialSlateHubForm(
              roof: roof,
              buildingName: buildingName,
              roofName: roofName,
              pitchController: _pitchController,
              facetCountController: _facetCountController,
              deckPartialSqftController: _deckPartialSqftController,
              setState: setState,
              sync: _sync,
              takeCommercialPhoto: _takeCommercialPhoto,
            ),
          if (_isOther)
            CommercialOtherHubForm(
              roof: roof,
              buildingName: buildingName,
              roofName: roofName,
              pitchController: _pitchController,
              facetCountController: _facetCountController,
              layersCountController: _layersCountController,
              deckPartialSqftController: _deckPartialSqftController,
              setState: setState,
              sync: _sync,
              takeCommercialPhoto: _takeCommercialPhoto,
            ),
          
          
          if (_isFlatSystem)
            CommercialFlatHubForm(
              roof: roof,
              buildingName: buildingName,
              roofName: roofName,
              deckOtherController: _deckOtherController,
              deckThicknessGaugeController: _deckThicknessGaugeController,
              deckPartialSqftController: _deckPartialSqftController,
              coverOtherController: _coverOtherController,
              setState: setState,
              sync: _sync,
              takeCommercialPhoto: _takeCommercialPhoto,
            ),
            
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await _takeCommercialPhoto(
                  buildingName: buildingName,
                  roofName: roofName,
                  photoLabel: 'Additional Image',
                  onSaved: (_) {},
                );
              },
              child: const Text('Take additional images'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Roof notes (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _sync(),
          ),
                    const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await _pickCommercialGalleryPhotos(
                  buildingName: buildingName,
                  roofName: roofName,
                );
              },
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Images from Gallery'),
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final buildings = widget.report.commercialBuildings;
              final isLastBuilding = widget.buildingIndex >= buildings.length - 1;
              final building = buildings[widget.buildingIndex];
              final isLastRoof = widget.roofIndex >= building.roofs.length - 1;
              final isFinalStep = isLastBuilding && isLastRoof;

              if (!isFinalStep || !widget.report.inspectElevations) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Submit Roof inspection first/only?'),
                    value: _submitRoofOnly,
                    onChanged: (value) {
                      setState(() => _submitRoofOnly = value ?? false);
                    },
                  ),
                ],
              );
            },
          ),
          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (context) {
                final buildings = widget.report.commercialBuildings;
                final isLastBuilding = widget.buildingIndex >= buildings.length - 1;
                final building = buildings[widget.buildingIndex];
                final isLastRoof = widget.roofIndex >= building.roofs.length - 1;
                final isFinalStep = isLastBuilding && isLastRoof;

                         if (isFinalStep && _showFinishActions) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                         SizedBox(
                          width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await _pickCommercialGalleryPhotos(
                              buildingName: buildingName,
                              roofName: roofName,
                            );
                          },
                            child: const Text('Add Images from Gallery'),
                           ),
                           ),
                          const SizedBox(height: 8),
                           SizedBox(
                           width: double.infinity,
                           child: ElevatedButton(
                           onPressed: () async {
                            if (widget.report.inspectElevations) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Elevations flow not implemented yet.'),
                                ),
                              );
                              return;
                            }

                           // await _showSubmissionOptions();
                          },
                          child: const Text('Submit Inspection'),
                        ),
                      ),
                    ],
                  );
                }

                return ElevatedButton(
                  onPressed: () async {
                    _sync();
                    widget.report.isCommercial = true;
                    roof.reportType = 'commercial';

                    if (_showRequiredPhotoError(firstMissingRequiredPhoto([
                      () => roof.overviewPhoto == null
                          ? 'Please add an overview photo.'
                          : null,
                    ]))) {
                      return;
                    }
                      if (roof.roofType == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                      content: Text('Select the type of roof covering.'),
                      backgroundColor: Colors.red,
                      ),
                       );
                        return;
                       }

                    if (roof.roofSubType == 'Other' &&
                        (_roofSubTypeOtherController.text.trim().isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please specify the subtype.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (_isOther &&
                        _roofSubTypeOtherController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please specify the roof cover type.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                       if (_isFlatSystem) {
                      if (roof.coreSamplePerformed) {
                        if (_showRequiredPhotoError(firstMissingRequiredPhoto([
                          () => roof.coreSamplePhoto == null
                              ? 'Please add a core sample photo.'
                              : null,
                        ]))) {
                          return;
                        }
                      } 
                      if (roof.insulationMaterial == 'Other' && 
                     (roof.insulationMaterialOtherSpecify == null || roof.insulationMaterialOtherSpecify!.trim().isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                        content: Text('Please specify the insulation material.'),
                       backgroundColor: Colors.red,
                             ),
                               );
                              return;
                            }
                                            else {
                        if (roof.insulationKnown == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select whether the sublayer system is known.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                         
                        if (roof.insulationKnown == false &&
                            roof.noCoreSampleApproach == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a sublayer estimating approach.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

                      if (roof.coreSamplePerformed || roof.insulationKnown == true) {
                        if (roof.insulationMaterial == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select the base insulation material.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (roof.insulationThickness == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select the base insulation thickness.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }
                    }

                    if (roof.roofType == 'Shingles' && roof.hasMultipleLayers == true) {
                      final layers = int.tryParse(_layersCountController.text.trim());
                      if (layers == null || layers < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter how many layers.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                         return;
                      }
                    }

                    if (_isShingles || _isTile || _isSlate || _isOther) {
                      if (roof.hasValleyMetal &&
                          (roof.valleyMetalType == null ||
                              roof.valleyMetalType!.isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select the valley metal type.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      for (var i = 0; i < roof.shingleFlashings.length; i++) {
                        final flashing = roof.shingleFlashings[i];
                        if (flashing.type.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Select the flashing type for Flashing ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (flashing.type == 'Other' &&
                            (flashing.otherSpecify == null ||
                                flashing.otherSpecify!.trim().isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Specify the flashing type for Flashing ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        for (final field in flashingFieldsForResidentialType(flashing.type)) {
                          final value = switch (field.key) {
                            'material' => flashing.material,
                            'size' => flashing.size,
                            'finish' => flashing.finish,
                            'grade' => flashing.grade,
                            _ => null,
                          };
                          if (value == null || value.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Select ${field.label} for Flashing ${i + 1}.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                        }
                        if (_showRequiredPhotoError(firstMissingRequiredPhoto([
                          () => flashing.photo == null
                              ? 'Take the main photo for Flashing ${i + 1}.'
                              : null,
                        ]))) {
                          return;
                        }
                      }

                      if (roof.hasVents && roof.shingleVents.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add at least one vent or uncheck Has Vents.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      for (var i = 0; i < roof.shingleVents.length; i++) {
                        final vent = roof.shingleVents[i];
                        if (vent.type.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Select the vent type for Vent ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (vent.type == 'Other' &&
                            (vent.otherSpecify == null ||
                                vent.otherSpecify!.trim().isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Specify the vent type for Vent ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (_showRequiredPhotoError(firstMissingRequiredPhoto([
                          () => vent.photo == null
                              ? 'Take the main photo for Vent ${i + 1}.'
                              : null,
                        ]))) {
                          return;
                        }
                      }

                      if (roof.hasHvacEquipment && roof.hvacUnits.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add at least one HVAC item or uncheck HVAC equipment.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (roof.hasMechanicalEquipment && roof.mechanicalUnits.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add at least one mechanical equipment item or uncheck Mechanical Equipment.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      for (var i = 0; i < roof.hvacUnits.length; i++) {
                        if (_showRequiredPhotoError(firstMissingRequiredPhoto([
                          () => roof.hvacUnits[i].photo == null
                              ? 'Take the main photo for HVAC ${i + 1}.'
                              : null,
                        ]))) {
                          return;
                        }
                      }
                    }

                    if ((_isShingles || _isMetal || _isTile || _isSlate || _isOther) &&
                        roof.hasMultipleFacets &&
                        roof.facetCount <= 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter the facet count.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                        if (_isFlatSystem) {
                      for (var i = 0; i < roof.tpoFlashings.length; i++) {
                        if (_showRequiredPhotoError(firstMissingRequiredPhoto([
                          () => roof.tpoFlashings[i].photo == null
                              ? 'Take the main photo for Flashing ${i + 1}.'
                              : null,
                        ]))) {
                          return;
                        }
                      }

                      for (var i = 0; i < roof.tpoVents.length; i++) {
                        if (_showRequiredPhotoError(firstMissingRequiredPhoto([
                          () => roof.tpoVents[i].photo == null
                              ? 'Take the main photo for Vent ${i + 1}.'
                              : null,
                        ]))) {
                          return;
                        }
                      }

                      for (var i = 0; i < roof.hvacUnits.length; i++) {
                        if (_showRequiredPhotoError(firstMissingRequiredPhoto([
                          () => roof.hvacUnits[i].photo == null
                              ? 'Take the main photo for HVAC ${i + 1}.'
                              : null,
                        ]))) {
                          return;
                        }
                      }
                    }

                    if (_isMetal) {
                      for (var i = 0; i < roof.tpoFlashings.length; i++) {
                        final flashing = roof.tpoFlashings[i];
                        if (flashing.type.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Select the flashing type for Flashing ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (flashing.type == 'Other' &&
                            (flashing.otherSpecify == null ||
                                flashing.otherSpecify!.trim().isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Specify the flashing type for Flashing ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (_showRequiredPhotoError(firstMissingRequiredPhoto([
                          () => flashing.photo == null
                              ? 'Take the main photo for Flashing ${i + 1}.'
                              : null,
                        ]))) {
                          return;
                        }
                      }

                      for (var i = 0; i < roof.tpoVents.length; i++) {
                        final vent = roof.tpoVents[i];
                        if (vent.type.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Select the vent type for Vent ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (vent.type == 'Other' &&
                            (vent.otherSpecify == null ||
                                vent.otherSpecify!.trim().isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Specify the vent type for Vent ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (_showRequiredPhotoError(firstMissingRequiredPhoto([
                          () => vent.photo == null
                              ? 'Take the main photo for Vent ${i + 1}.'
                              : null,
                        ]))) {
                          return;
                        }
                      }

                      for (var i = 0; i < roof.hvacUnits.length; i++) {
                        if (_showRequiredPhotoError(firstMissingRequiredPhoto([
                          () => roof.hvacUnits[i].photo == null
                              ? 'Take the main photo for HVAC ${i + 1}.'
                              : null,
                        ]))) {
                          return;
                        }
                      }
                    }
                    
                      for (var i = 0; i < roof.mechanicalUnits.length; i++) {
                        if (_showRequiredPhotoError(firstMissingRequiredPhoto([
                          () => roof.mechanicalUnits[i].photo == null
                              ? 'Take the main photo for Mechanical ${i + 1}.'
                              : null,
                        ]))) {
                          return;
                        }
                      }

                    try {
                      await PdfService.buildPartialPhotoPdfForCommercialSection(
                        report: widget.report,
                        buildingIndex: widget.buildingIndex,
                        roofIndex: widget.roofIndex,
                        buildingName: buildingName,
                        roofName: roofName,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error saving section photos: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (!mounted) return;

                    // If this roof section has multiple facets, split into separate roof sections.
                    if ((_isShingles || _isMetal || _isTile || _isSlate || _isOther) &&
                        roof.hasMultipleFacets &&
                        !roof.facetsGenerated &&
                        roof.facetCount > 1) {
                      final total = roof.facetCount;
                      roof.facetsGenerated = true;
                      roof.facetGroupTotal = total;
                      roof.facetIndex = 1;
                      roof.hasMultipleFacets = false;
                      roof.facetCount = 1;
                      _facetCountController.text = '1';

                      final baseLabel = (roof.roofLabel ?? '').trim().isEmpty
                          ? 'Roof ${widget.roofIndex + 1}'
                          : roof.roofLabel!.trim();

                      roof.roofLabel = '$baseLabel - Facet 1';
                      _roofLabelController.text = roof.roofLabel!;

                      // Next facets require their own overview.

                      for (var i = 2; i <= total; i++) {
                        final r = CommercialRoofSectionData();
                        r.roofType = roof.roofType;
                        r.reportType = 'commercial';
                        r.roofSubType = roof.roofSubType;
                        r.roofSubTypeOtherSpecify = roof.roofSubTypeOtherSpecify;
                        r.pitch = roof.pitch;
                        r.hasMultipleFacets = false;
                        r.facetCount = 1;
                        r.metalStyle = roof.metalStyle;
                        r.metalHasFacets = roof.metalHasFacets;
                        r.metalGauge = roof.metalGauge;
                        r.metalGaugeOtherSpecify = roof.metalGaugeOtherSpecify;


                        // Shingles hub fields
                        r.hasMultipleLayers = roof.hasMultipleLayers;
                        r.numberOfLayers = roof.numberOfLayers;
                        r.starterRowInstalled = roof.starterRowInstalled;
                        r.starterEaveInstalled = roof.starterEaveInstalled;
                        r.starterRakeInstalled = roof.starterRakeInstalled;
                        r.starterEavePhoto = roof.starterEavePhoto;
                        r.starterRakePhoto = roof.starterRakePhoto;
                        r.hasDripEdge = roof.hasDripEdge;
                        r.dripEdgeType = roof.dripEdgeType;
                        r.dripEdgePhoto = roof.dripEdgePhoto;
                        r.iceAndWaterBarrierInstalled = roof.iceAndWaterBarrierInstalled;
                        r.iceAndWaterBarrierPhoto = roof.iceAndWaterBarrierPhoto;
                        r.hasRidge = roof.hasRidge;
                        r.hasRidgeVent = roof.hasRidgeVent;
                        r.ridgeVentType = roof.ridgeVentType;
                        r.ridgeVentPhoto = roof.ridgeVentPhoto;
                        r.hasValleyMetal = roof.hasValleyMetal;
                        r.valleyMetalType = roof.valleyMetalType;
                        r.hasVents = roof.hasVents;
                        r.hasHvacEquipment = roof.hasHvacEquipment;
                        r.hasMechanicalEquipment = roof.hasMechanicalEquipment;
                        r.battenChangeRequired = roof.battenChangeRequired;

                        r.facetsGenerated = true;
                        r.facetGroupTotal = total;
                        r.facetIndex = i;
                        r.facetCount = 1;
                        r.overviewPhoto = null;

                        r.roofLabel = '$baseLabel - Facet $i';

                        building.roofs.insert(widget.roofIndex + (i - 1), r);
                      }
                    }

if (isFinalStep) {
  if (widget.report.inspectElevations && !_submitRoofOnly) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ElevationsInspectionScreen(
          report: widget.report,
          isCommercial: true,
          plan: widget.plan,
        ),
      ),
    );

    return;   
  }

  await _submitCommercialReport();
  return;
}

                    final nextRoofIndex = widget.roofIndex + 1;
                    if (nextRoofIndex < building.roofs.length) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => CommercialRoofSectionScreen(
                            plan: widget.plan,
                            report: widget.report,
                            buildingIndex: widget.buildingIndex,
                            roofIndex: nextRoofIndex,
                          ),
                        ),
                      );
                      return;
                    }

                    final nextBuildingIndex = widget.buildingIndex + 1;
                    if (nextBuildingIndex < buildings.length) {
                      final nextBuilding = buildings[nextBuildingIndex];
                      if (nextBuilding.roofs.isEmpty) {
                        nextBuilding.roofs.add(
                          CommercialRoofSectionData()..roofLabel = 'Main Roof' 
                          ..reportType = 'commercial',
                        );
                      }

                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => CommercialBuildingDetailScreen(
                            plan: widget.plan,
                            report: widget.report,
                            buildingIndex: nextBuildingIndex,
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(isFinalStep ? (widget.report.inspectElevations ? (_submitRoofOnly ? 'Submit Inspection' : 'Save & Continue') : 'Submit Inspection') : 'Save & Continue'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  // === FUNCIÓN PARA ENVIAR REPORTE COMERCIAL ===
 Future<void> _submitCommercialReport() async {
  if (roof.roofType == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Select the type of roof covering.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final navigator = Navigator.of(context);
  bool loadingShown = false;

  try {
    widget.report.isCommercial = true;
    roof.reportType = 'commercial';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    loadingShown = true;

    final pdfs = await PdfService.generateReports(widget.report);

    if (!mounted) return;

    if (!pdfs.containsKey('tech') || !pdfs.containsKey('photos')) {
      throw Exception(
        'PDF generation did not return the expected reports.',
      );
    }

    if (loadingShown && navigator.canPop()) {
      navigator.pop();
      loadingShown = false;
    }

    await InspectionSubmissionService.showOptions(
      context: context,
      report: widget.report,
      plan: widget.plan,
      isCommercial: true,
      techPdf: pdfs['tech']!,
      photoPdf: pdfs['photos']!,
    );
  } catch (e) {
    if (!mounted) return;

    if (loadingShown && navigator.canPop()) {
      navigator.pop();
      loadingShown = false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error generating PDFs: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
}
