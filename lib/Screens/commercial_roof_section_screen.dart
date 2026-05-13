import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../catalogs/roof_catalog.dart';
import '../inspection_report_model.dart';
import '../utils/photo_labels.dart';
import 'commercial/hubs/commercial_flat_hub.dart';
import 'commercial/hubs/commercial_metal_hub.dart';
import 'commercial/hubs/commercial_shingles_hub.dart';
import 'commercial_building_details_screen.dart';


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

  bool _showFinishActions = false;

  Future<void> _showSubmissionOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Submission Options',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text('Commercial submission options are not implemented yet.'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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

  Future<void> _takeCommercialPhoto({
    required String buildingName,
    required String roofName,
    required String photoLabel,
    required void Function(File file) onSaved,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 80,
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
              photoLabel: '$overviewLabel additional photo',
              onSaved: (_) {},
            ),
            child: const Text('Add additional overview photo'),
          ),
          if (roof.overviewPhoto != null) ...[
            const SizedBox(height: 8),
            Image.file(roof.overviewPhoto!, height: 140, fit: BoxFit.cover),
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
              initialValue: roof.roofSubType,
              decoration: const InputDecoration(
                labelText: 'Subtype',
                border: OutlineInputBorder(),
              ),
              items: subtypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
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
          if (_isMetal)
            CommercialMetalHubForm(
              roof: roof,
              pitchController: _pitchController,
              facetCountController: _facetCountController,
              setState: setState,
              sync: _sync,
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
                  photoLabel: 'Additional Photo',
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
          const SizedBox(height: 16),
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
                            final messenger = ScaffoldMessenger.of(context);
                            final images = await _picker.pickMultiImage(
                              maxWidth: 1024,
                              imageQuality: 80,
                            );

                            if (images.isEmpty) return;

                            for (final x in images) {
                              widget.report.addPhoto(
                                File(x.path),
                                buildCommercialPhotoLabel(
                                  building: buildingName,
                                  roof: roofName,
                                  label: 'User Image',
                                ),
                              );
                            }

                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Photos added')),
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

                            await _showSubmissionOptions();
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

                    if (roof.overviewPhoto == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please add an overview photo.'),
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
                    
                       if (_isFlatSystem) {
                      if (roof.coreSamplePerformed) {
                        if (roof.coreSamplePhoto == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please add a core sample photo.'),
                              backgroundColor: Colors.red,
                            ),
                          );
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

                    if ((roof.roofType == 'Shingles' || roof.roofType == 'Metal') &&
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
                       if (roof.roofType == 'TPO') {
                      for (var i = 0; i < roof.tpoFlashings.length; i++) {
                        if (roof.tpoFlashings[i].photo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Take the main photo for Flashing ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

                      for (var i = 0; i < roof.tpoVents.length; i++) {
                        if (roof.tpoVents[i].photo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Take the main photo for Vent ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

                      for (var i = 0; i < roof.hvacUnits.length; i++) {
                        if (roof.hvacUnits[i].photo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Take the main photo for HVAC ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }
                    }
                    
                      for (var i = 0; i < roof.mechanicalUnits.length; i++) {
                        if (roof.mechanicalUnits[i].photo == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Take the main photo for Mechanical ${i + 1}.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

                    // If this roof section has multiple facets, split into separate roof sections.
                    if ((roof.roofType == 'Shingles' || roof.roofType == 'Metal') &&
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
                        r.roofSubType = roof.roofSubType;
                        r.roofSubTypeOtherSpecify = roof.roofSubTypeOtherSpecify;
                        r.pitch = roof.pitch;
                        r.hasMultipleFacets = false;
                        r.facetCount = 1;
                        r.metalStyle = roof.metalStyle;
                        r.metalHasFacets = roof.metalHasFacets;

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
                      setState(() {
                        _showFinishActions = true;
                      });
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
                          CommercialRoofSectionData()..roofLabel = 'Main Roof',
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
                  child: Text(isFinalStep ? 'Finish Inspection' : 'Save & Continue'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
