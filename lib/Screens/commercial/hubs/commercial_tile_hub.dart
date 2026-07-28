import 'dart:io';

import 'package:flutter/material.dart';

import '../../../catalogs/flashing_catalog.dart';
import '../../../catalogs/roof_components_catalog.dart';
import '../../../inspection_report_model.dart';
import '../components/commercial_hvac_mechanical_rooftop.dart';

class CommercialTileHubForm extends StatelessWidget {
  final CommercialRoofSectionData roof;
  final String buildingName;
  final String roofName;

  final TextEditingController pitchController;
  final TextEditingController facetCountController;
  final TextEditingController deckPartialSqftController;

  final void Function(VoidCallback fn) setState;
  final VoidCallback sync;

  final Future<void> Function({
    required String buildingName,
    required String roofName,
    required String photoLabel,
    required void Function(File file) onSaved,
    File? previousFile,
    List<File>? owner,
    String? singletonGroupLabel,
  }) takeCommercialPhoto;
  final void Function(Iterable<File?> files) removePhotos;
  final void Function(String baseLabel) clearSingletonPhotoGroup;

  const CommercialTileHubForm({
    super.key,
    required this.roof,
    required this.buildingName,
    required this.roofName,
    required this.pitchController,
    required this.facetCountController,
    required this.deckPartialSqftController,
    required this.setState,
    required this.sync,
    required this.takeCommercialPhoto,
    required this.removePhotos,
    required this.clearSingletonPhotoGroup,
  });

  static const List<String> _valleyMetalTypes = [
    'Valley metal Standard',
    'Valley metal W profile',
    'Valley metal W profile painted',
    'Valley metal copper',
    'Valley metal painted',
  ];

  String? _dropdownValue(String? value, List<String> options) {
    if (value == null || value.isEmpty || !options.contains(value)) {
      return null;
    }
    return value;
  }

  String? _flashingFieldValue(FlashingData flashing, String key) {
    switch (key) {
      case 'material':
        return flashing.material;
      case 'size':
        return flashing.size;
      case 'finish':
        return flashing.finish;
      case 'grade':
        return flashing.grade;
      default:
        return null;
    }
  }

  void _setFlashingField(FlashingData flashing, String key, String? value) {
    switch (key) {
      case 'material':
        flashing.material = value;
        break;
      case 'size':
        flashing.size = value;
        break;
      case 'finish':
        flashing.finish = value;
        break;
      case 'grade':
        flashing.grade = value;
        break;
    }
  }

  void _resetFlashingDetails(FlashingData flashing) {
    flashing.material = null;
    flashing.size = null;
    flashing.finish = null;
    flashing.grade = null;
    flashing.otherSpecify = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Text('Tile roofing (roof section)', style: TextStyle(fontWeight: FontWeight.bold)),

        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: roof.battenChangeRequired,
          decoration: const InputDecoration(
            labelText: 'Does the batten system need to be replaced?',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'No', child: Text('No')),
            DropdownMenuItem(value: 'Yes', child: Text('Yes')),
          ],
          onChanged: (val) {
            setState(() {
              roof.battenChangeRequired = val;
              sync();
            });
          },
        ),

        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('Drip edge installed?'),
          value: roof.hasDripEdge,
          onChanged: (val) {
            setState(() {
              roof.hasDripEdge = val ?? false;
              if (!roof.hasDripEdge) {
                clearSingletonPhotoGroup('Drip Edge');
                roof.dripEdgeType = null;
                roof.dripEdgePhoto = null;
              }
            });
          },
        ),
        if (roof.hasDripEdge) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: roof.dripEdgeType,
            decoration: const InputDecoration(
              labelText: 'Drip edge type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Standard', child: Text('Standard')),
              DropdownMenuItem(value: 'Gutter Apron', child: Text('Gutter Apron')),
              DropdownMenuItem(value: 'Copper', child: Text('Copper')),
            ],
            onChanged: (val) {
              setState(() {
                roof.dripEdgeType = val;
              });
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => takeCommercialPhoto(
              buildingName: buildingName,
              roofName: roofName,
              photoLabel: 'Drip Edge - Image 1',
              previousFile: roof.dripEdgePhoto,
              singletonGroupLabel: 'Drip Edge',
              onSaved: (f) => roof.dripEdgePhoto = f,
            ),
            child: const Text('Take Drip Edge Photo'),
          ),
          TextButton(
            onPressed: () => takeCommercialPhoto(
              buildingName: buildingName,
              roofName: roofName,
              photoLabel: 'Drip Edge - Image 2',
              owner: roof.dripEdgeExtraPhotos,
              onSaved: (_) {},
            ),
            child: const Text('Add extra Drip Edge photo'),
          ),
          if (roof.dripEdgePhoto != null) ...[
            const SizedBox(height: 8),
            Image.file(roof.dripEdgePhoto!, height: 140, fit: BoxFit.cover, cacheWidth: 420),
          ],
        ],

        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('Ice & Water Barrier installed?'),
          value: roof.iceAndWaterBarrierInstalled,
          onChanged: (val) {
            setState(() {
              roof.iceAndWaterBarrierInstalled = val ?? false;
              if (!roof.iceAndWaterBarrierInstalled) {
                clearSingletonPhotoGroup('Ice & Water Barrier');
                roof.iceAndWaterBarrierPhoto = null;
              }
            });
          },
        ),
        if (roof.iceAndWaterBarrierInstalled) ...[
          ElevatedButton(
            onPressed: () => takeCommercialPhoto(
              buildingName: buildingName,
              roofName: roofName,
              photoLabel: 'Ice & Water Barrier - Image 1',
              previousFile: roof.iceAndWaterBarrierPhoto,
              singletonGroupLabel: 'Ice & Water Barrier',
              onSaved: (f) => roof.iceAndWaterBarrierPhoto = f,
            ),
            child: const Text('Take Ice & Water Barrier Photo'),
          ),
          TextButton(
            onPressed: () => takeCommercialPhoto(
              buildingName: buildingName,
              roofName: roofName,
              photoLabel: 'Ice & Water Barrier - Image 2',
              owner: roof.iceAndWaterBarrierExtraPhotos,
              onSaved: (_) {},
            ),
            child: const Text('Add extra Ice & Water Barrier photo'),
          ),
          if (roof.iceAndWaterBarrierPhoto != null) ...[
            const SizedBox(height: 8),
            Image.file(roof.iceAndWaterBarrierPhoto!, height: 140, fit: BoxFit.cover, cacheWidth: 420),
          ],
        ],

        const SizedBox(height: 12),
                CheckboxListTile(
          title: const Text('Has Valley?'),
          value: roof.hasValleyMetal,
          onChanged: (val) {
            setState(() {
              roof.hasValleyMetal = val ?? false;
              if (!roof.hasValleyMetal) {
                clearSingletonPhotoGroup('Valley Metal');
                roof.valleyMetalType = null;
                roof.valleyMetalPhoto = null;
              }
            });
          },
        ),
        if (roof.hasValleyMetal) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _dropdownValue(roof.valleyMetalType, _valleyMetalTypes),
            decoration: const InputDecoration(
              labelText: 'Valley Metal Type',
              border: OutlineInputBorder(),
            ),
            items: _valleyMetalTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (val) {
              setState(() {
                roof.valleyMetalType = val;
              });
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => takeCommercialPhoto(
              buildingName: buildingName,
              roofName: roofName,
              photoLabel: 'Valley Metal - Image 1',
              previousFile: roof.valleyMetalPhoto,
              singletonGroupLabel: 'Valley Metal',
              onSaved: (f) => roof.valleyMetalPhoto = f,
            ),
            child: const Text('Take Valley Metal Photo'),
          ),
          TextButton(
            onPressed: () => takeCommercialPhoto(
              buildingName: buildingName,
              roofName: roofName,
              photoLabel: 'Valley Metal - Image 2',
              owner: roof.valleyMetalExtraPhotos,
              onSaved: (_) {},
            ),
            child: const Text('Add extra Valley Metal photo'),
          ),
          if (roof.valleyMetalPhoto != null) ...[
            const SizedBox(height: 8),
            Image.file(roof.valleyMetalPhoto!, height: 140, fit: BoxFit.cover, cacheWidth: 420),
          ],
        ],

        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('Roof deck required to be changed?'),
          value: roof.deckChangeRequired,
          onChanged: (val) {
            setState(() {
              roof.deckChangeRequired = val ?? false;
              if (!roof.deckChangeRequired) {
                roof.deckFullReplacementRequired = false;
                roof.deckPartialReplacementSqft = null;
                deckPartialSqftController.clear();
              }
            });
          },
        ),
        if (roof.deckChangeRequired) ...[
          CheckboxListTile(
            title: const Text('Roof deck full replacement required?'),
            value: roof.deckFullReplacementRequired,
            onChanged: (val) {
              setState(() {
                roof.deckFullReplacementRequired = val ?? false;
                if (roof.deckFullReplacementRequired) {
                  roof.deckPartialReplacementSqft = null;
                  deckPartialSqftController.clear();
                }
              });
            },
          ),
          if (!roof.deckFullReplacementRequired)
            TextField(
              controller: deckPartialSqftController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'How many SF of roof deck require replacement?',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => sync(),
            ),
        ],

        const SizedBox(height: 12),
        Align(
           alignment: Alignment.centerLeft,
           child: Padding(
           padding: const EdgeInsets.only(bottom: 6, left: 12),
           child: Text(
           'Is there more than one facet?',
            style: TextStyle(
            fontSize: 16,
            color: const Color.fromARGB(255, 1, 1, 1),
      ),
    ),
  ),
),

DropdownButtonFormField<bool>(
  initialValue: roof.hasMultipleFacets,
  decoration: const InputDecoration(
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  ),
          items: const [
            DropdownMenuItem(value: false, child: Text('No')),
            DropdownMenuItem(value: true, child: Text('Yes')),
          ],
          onChanged: (val) {
            setState(() {
              roof.hasMultipleFacets = val ?? false;
              if (roof.hasMultipleFacets) {
                if (roof.facetCount <= 1) {
                  roof.facetCount = 2;
                  facetCountController.text = '2';
                } else {
                  facetCountController.text = roof.facetCount.toString();
                }
              } else {
                roof.facetCount = 1;
                facetCountController.text = '1';
              }
            });
          },
        ),
        if (roof.hasMultipleFacets) ...[
          const SizedBox(height: 12),
          TextField(
            controller: facetCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Facet count',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => sync(),
          ),
        ],

        const SizedBox(height: 12),
        TextField(
          controller: pitchController,
          decoration: const InputDecoration(
            labelText: 'Pitch (optional)',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => sync(),
        ),

        const SizedBox(height: 20),
        const Text(
          'Flashings on Roof Section',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Divider(),
        ...roof.shingleFlashings.asMap().entries.map((entry) {
          final idx = entry.key;
          final flashing = entry.value;
          final fieldConfigs = flashingFieldsForResidentialType(flashing.type);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Flashing ${idx + 1}',
                                           style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          final flashing = roof.shingleFlashings[idx];
                          removePhotos([flashing.photo, ...flashing.extraPhotos]);
                          setState(() {
                            roof.shingleFlashings.removeAt(idx);
                            sync();
                          });
                        },
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _dropdownValue(
                      flashing.type,
                      flashingTypesShingles,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Flashing Type',
                      border: OutlineInputBorder(),
                    ),
                    items: flashingTypesShingles
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        flashing.type = val ?? '';
                        _resetFlashingDetails(flashing);
                        sync();
                      });
                    },
                  ),
                  if (flashing.type == 'Other') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: flashing.otherSpecify,
                      decoration: const InputDecoration(
                        labelText: 'Specify Other Flashing',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        flashing.otherSpecify =
                            val.trim().isEmpty ? null : val.trim();
                        sync();
                      },
                    ),
                  ],
                  ...fieldConfigs.map((field) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: _dropdownValue(
                          _flashingFieldValue(flashing, field.key),
                          field.options,
                        ),
                        decoration: InputDecoration(
                          labelText: field.label,
                          border: const OutlineInputBorder(),
                        ),
                        items: field.options
                            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _setFlashingField(flashing, field.key, val);
                            sync();
                          });
                        },
                      ),
                    );
                  }),

                    ElevatedButton(
                    onPressed: () => takeCommercialPhoto(
                      buildingName: buildingName,
                      roofName: roofName,
                      photoLabel: 'Flashing ${idx + 1} - Image 1',
                      previousFile: flashing.photo,
                      onSaved: (f) => flashing.photo = f,
                    ),
                    child: const Text('Take Flashing Photo'),
                  ),
                  TextButton(
                    onPressed: () => takeCommercialPhoto(
                      buildingName: buildingName,
                      roofName: roofName,
                      photoLabel: 'Flashing ${idx + 1} - Image 2',
                      onSaved: (f) => flashing.extraPhotos.add(f),
                    ),
                    child: const Text('Add extra Flashing photo'),
                  ),
                  if (flashing.photo != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Image.file(flashing.photo!, height: 100, cacheWidth: 300),
                    ),
                ],
              ),
            ),
          );
        }),
        ElevatedButton(
          onPressed: () {
            setState(() {
              roof.shingleFlashings.add(FlashingData(type: ''));
              sync();
            });
          },
          child: const Text('Add Flashing'),
        ),

        const SizedBox(height: 20),
        CheckboxListTile(
           title: const Text('Has Vents (Is there vent installed)?'),
          value: roof.hasVents,
          onChanged: (val) {
            setState(() {
              roof.hasVents = val ?? false;
              if (!roof.hasVents) {
                roof.shingleVents.clear();
              }
              sync();
            });
          },
        ),
        if (roof.hasVents) ...[
          const Text(
            'Vents on Roof Section',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const Divider(),
          ...roof.shingleVents.asMap().entries.map((entry) {
            final ventIndex = entry.key;
            final vent = entry.value;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Vent ${ventIndex + 1}',
                                             style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            final vent = roof.shingleVents[ventIndex];
                            removePhotos([vent.photo, ...vent.extraPhotos]);
                            setState(() {
                              roof.shingleVents.removeAt(ventIndex);
                              sync();
                            });
                          },
                        ),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _dropdownValue(vent.type, ventTypesShingles),
                      decoration: const InputDecoration(
                        labelText: 'Vent Type',
                        border: OutlineInputBorder(),
                      ),
                      items: ventTypesShingles
                                              .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          vent.type = val ?? '';
                          if (vent.type != 'Other') {
                            vent.otherSpecify = null;
                          }
                          if (vent.type != 'Pipe jack') {
                            vent.includeSplitBoot = false;
                            vent.includeLead = false;
                          }
                          sync();
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Should be Changed?'),
                      value: vent.shouldBeChanged,
                      onChanged: (val) {
                        setState(() {
                          vent.shouldBeChanged = val ?? false;
                          sync();
                        });
                      },
                    ),
                    if (vent.type != 'Other') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: vent.count ?? '1',
                        decoration: InputDecoration(
                          labelText: 'Count of ${vent.type.isEmpty ? 'vent' : vent.type}',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          vent.count = val;
                          sync();
                        },
                      ),
                    ],
                    if (vent.type == 'Pipe jack')
                      Column(
                        children: [
                          CheckboxListTile(
                            title: const Text('Include Split Boot?'),
                            value: vent.includeSplitBoot,
                            onChanged: (val) {
                              setState(() {
                                vent.includeSplitBoot = val ?? false;
                                sync();
                              });
                            },
                          ),
                          CheckboxListTile(
                            title: const Text('Include Lead?'),
                            value: vent.includeLead,
                            onChanged: (val) {
                              setState(() {
                                vent.includeLead = val ?? false;
                                sync();
                              });
                            },
                          ),
                        ],
                      ),
                    if (vent.type == 'Other') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: vent.otherSpecify,
                        decoration: const InputDecoration(
                          labelText: 'Specify Other Vent',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          vent.otherSpecify =
                              val.trim().isEmpty ? null : val.trim();
                          sync();
                        },
                      ),
                    ],
                    ElevatedButton(
                      onPressed: () => takeCommercialPhoto(
                        buildingName: buildingName,
                        roofName: roofName,
                        photoLabel: 'Vent ${ventIndex + 1} - Image 1',
                        previousFile: vent.photo,
                        onSaved: (f) => vent.photo = f,
                      ),
                      child: const Text('Take Vent Photo'),
                    ),
                    TextButton(
                      onPressed: () => takeCommercialPhoto(
                        buildingName: buildingName,
                        roofName: roofName,
                        photoLabel: 'Vent ${ventIndex + 1} - Image 2',
                        onSaved: (f) => vent.extraPhotos.add(f),
                      ),
                      child: const Text('Add extra Vent photo'),
                    ),
                    if (vent.photo != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Image.file(vent.photo!, height: 100, cacheWidth: 300),
                      ),
                  ],
                ),
              ),
            );
          }),
          ElevatedButton(
            onPressed: () {
              setState(() {
                roof.shingleVents.add(VentData(type: '', count: '1'));
                sync();
              });
            },
            child: const Text('Add Vent'),
          ),
        ],

        const SizedBox(height: 12),
        CheckboxListTile(
            title: const Text('Is there HVAC equipment installed?'),
          value: roof.hasHvacEquipment,
          onChanged: (val) {
            setState(() {
              roof.hasHvacEquipment = val ?? false;
              if (!roof.hasHvacEquipment) {
                roof.hvacUnits.clear();
              }
              sync();
            });
          },
        ),
        CheckboxListTile(
           title: const Text('Is there mechanical equipment installed?'),
          value: roof.hasMechanicalEquipment,
          onChanged: (val) {
            setState(() {
              roof.hasMechanicalEquipment = val ?? false;
              if (!roof.hasMechanicalEquipment) {
                roof.mechanicalUnits.clear();
              }
              sync();
            });
          },
        ),
        if (roof.hasHvacEquipment || roof.hasMechanicalEquipment) ...[
          const SizedBox(height: 16),
          CommercialHvacMechanicalRooftop(
            hvacItems: roof.hvacUnits,
            mechanicalItems: roof.mechanicalUnits,
            onChanged: sync,
            takePhoto: takeCommercialPhoto,
            removePhotos: removePhotos,
            buildingName: buildingName,
            roofName: roofName,
            showHvac: roof.hasHvacEquipment,
            showMechanical: roof.hasMechanicalEquipment,
          ),
        ],
      ],
    );
  }
}
