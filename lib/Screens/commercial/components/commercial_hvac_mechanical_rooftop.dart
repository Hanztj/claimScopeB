// lib/screens/commercial/components/commercial_hvac_mechanical_rooftop.dart

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../catalogs/commercial_hvac_mechanical_catalog.dart';
import '../../../inspection_report_model.dart';

class CommercialHvacMechanicalRooftop extends StatefulWidget {
  final List<HvacUnitData> hvacItems;
  final List<HvacUnitData> mechanicalItems;
  final Function() onChanged;
  final Future<void> Function({
    required String buildingName,
    required String roofName,
    required String photoLabel,
    required void Function(File) onSaved,
  }) takePhoto;

   final String buildingName;
  final String roofName;
  final bool showHvac;
  final bool showMechanical;

  const CommercialHvacMechanicalRooftop({
    super.key,
    required this.hvacItems,
    required this.mechanicalItems,
    required this.onChanged,
    required this.takePhoto,
    required this.buildingName,
    required this.roofName,
    this.showHvac = true,
    this.showMechanical = true,
  });

  @override
  State<CommercialHvacMechanicalRooftop> createState() => _CommercialHvacMechanicalRooftopState();
}

class _CommercialHvacMechanicalRooftopState extends State<CommercialHvacMechanicalRooftop> {
  void _addHvac() {
    setState(() {
      widget.hvacItems.add(HvacUnitData()..category = commercialHvacCategory);
    });
    widget.onChanged();
  }

  void _removeHvac(int index) {
    setState(() {
      widget.hvacItems.removeAt(index);
    });
    widget.onChanged();
  }

  Future<void> _takeMainPhoto(int index) async {
    await widget.takePhoto(
      buildingName: widget.buildingName,
      roofName: widget.roofName,
      photoLabel: 'HVAC ${index + 1} - Main Photo',
      onSaved: (file) {
       setState(() => widget.hvacItems[index].photo = file);
        widget.onChanged();
      },
    );
  }

  Future<void> _addExtraPhoto(int index) async {
    await widget.takePhoto(
      buildingName: widget.buildingName,
      roofName: widget.roofName,
      photoLabel: 'HVAC ${index + 1} - Extra Photo',
      onSaved: (file) {
              setState(() => widget.hvacItems[index].extraPhotos.add(file));
        widget.onChanged();
      },
    );
  }

  void _addMechanical() {
    setState(() {
      widget.mechanicalItems.add(HvacUnitData()..category = commercialMechanicalCategory);
    });
    widget.onChanged();
  }

  void _removeMechanical(int index) {
    setState(() {
      widget.mechanicalItems.removeAt(index);
    });
    widget.onChanged();
  }

  Future<void> _takeMechanicalMainPhoto(int index) async {
    await widget.takePhoto(
      buildingName: widget.buildingName,
      roofName: widget.roofName,
      photoLabel: 'Mechanical ${index + 1} - Main Photo',
      onSaved: (file) {
        setState(() => widget.mechanicalItems[index].photo = file);
        widget.onChanged();
      },
    );
  }

  Future<void> _addMechanicalExtraPhoto(int index) async {
    await widget.takePhoto(
      buildingName: widget.buildingName,
      roofName: widget.roofName,
      photoLabel: 'Mechanical ${index + 1} - Extra Photo',
      onSaved: (file) {
        setState(() => widget.mechanicalItems[index].extraPhotos.add(file));
        widget.onChanged();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHvac) ...[
        const Text(
          'HVAC rooftop',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF101230)),
        ),

        const SizedBox(height: 12),

        ...widget.hvacItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'HVAC ${index + 1}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF101230)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeHvac(index),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                 DropdownButtonFormField<String>(
            initialValue: item.type,
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
            items: commercialHvacTypes
            .map((t) => DropdownMenuItem(value: t,child: Text(t),))
      .toList(),
         onChanged: (val) {
               setState(() {
              item.type = val;
              if (val != 'Other') {
               item.otherSpecify = null;
               }
              });
               widget.onChanged();
              },
                ),

                  if (item.type == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Specify', border: OutlineInputBorder()),
                      onChanged: (val) {
                        item.otherSpecify = val;
                        widget.onChanged();
                      },
                    ),
                  ],

                     const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: item.action,
                    decoration: const InputDecoration(labelText: 'Action', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'No action required', child: Text('No action required')),
                      DropdownMenuItem(value: 'Replace', child: Text('Replace')),
                      DropdownMenuItem(value: 'Detach & reset', child: Text('Detach & reset')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        item.action = val ?? 'No action required';
                      });
                      widget.onChanged();
                    },
                  ),

                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: item.capacityText,
                    decoration: const InputDecoration(labelText: 'Capacity', border: OutlineInputBorder()),
                    items: commercialHvacCapacityOptions
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        item.capacityText = val;
                        item.capacityKnown = val != null && val != 'Other';
                      });
                      widget.onChanged();
                    },
                  ),

                  if (item.capacityText == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Capacity text', border: OutlineInputBorder()),
                      onChanged: (val) {
                        item.notes = val;
                        widget.onChanged();
                      },
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(labelText: 'How many', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      item.count = val;
                      widget.onChanged();
                    },
                  ),

                  const SizedBox(height: 16),

                  if (item.photo == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _takeMainPhoto(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFA7F21),
                          foregroundColor: const Color(0xFF101230),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Take HVAC Photo (Required)'),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                         child: Image.file(item.photo!, height: 160, width: double.infinity, fit: BoxFit.cover, cacheWidth: 480), 
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _takeMainPhoto(index),
                          child: const Text('Replace Main Photo'),
                        ),
                      ],
                    ),

                  const SizedBox(height: 8),

                  TextButton.icon(
                    onPressed: () => _addExtraPhoto(index),
                    icon: const Icon(Icons.add_a_photo, size: 20),
                    label: const Text('Add extra HVAC photo'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF101230),
                      textStyle: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: _addHvac,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add HVAC'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFA7F21),
              foregroundColor: const Color(0xFF101230),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
 ),
          ),
        ),
        ],

        if (widget.showMechanical) ...[
        const SizedBox(height: 20),
        const Text(
          'Mechanical rooftop equipment',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF101230)),
        ),
        const SizedBox(height: 12),

        ...widget.mechanicalItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Mechanical ${index + 1}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF101230)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeMechanical(index),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    initialValue: item.type,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                    items: commercialMechanicalTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        item.type = val;
                        if (val != 'Other') {
                          item.otherSpecify = null;
                        }
                        if (val != 'Centrifugal Filtered Supply Fans') {
                          item.subtype = null;
                          item.subtypeOtherSpecify = null;
                          item.impellerDiameter = null;
                        }
                      });
                      widget.onChanged();
                    },
                  ),

                  if (item.type == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Specify', border: OutlineInputBorder()),
                      onChanged: (val) {
                        item.otherSpecify = val;
                        widget.onChanged();
                      },
                    ),
                  ],

                  if (item.type == 'Centrifugal Filtered Supply Fans') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: item.subtype,
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                      items: commercialCentrifugalFanSubtypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          item.subtype = val;
                          if (val != 'Other') {
                            item.subtypeOtherSpecify = null;
                          }
                        });
                        widget.onChanged();
                      },
                    ),
                      if (item.subtype == 'Other') ...[
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Specify type', border: OutlineInputBorder()),
                        onChanged: (val) {
                          item.subtypeOtherSpecify = val;
                          widget.onChanged();
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Impeller diameter', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        item.impellerDiameter = val;
                        widget.onChanged();
                      },
                    ),
                  ],

                  if (item.type == 'Upblast exhaust fan' ||
                      item.type == 'Downblast exhaust fan' ||
                      item.type == 'Propeller Upblast') ...[
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Capacity / nameplate', border: OutlineInputBorder()),
                      onChanged: (val) {
                        item.capacityText = val;
                        widget.onChanged();
                      },
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(labelText: 'How many', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      item.count = val;
                      widget.onChanged();
                    },
                  ),

                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: item.action,
                    decoration: const InputDecoration(labelText: 'Action', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'No action required', child: Text('No action required')),
                      DropdownMenuItem(value: 'Replace', child: Text('Replace')),
                      DropdownMenuItem(value: 'Detach & reset', child: Text('Detach & reset')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        item.action = val ?? 'No action required';
                      });
                      widget.onChanged();
                    },
                  ),

                  const SizedBox(height: 16),

                  if (item.photo == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _takeMechanicalMainPhoto(index),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFA7F21),
                          foregroundColor: const Color(0xFF101230),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Take Mechanical Photo (Required)'),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(item.photo!, height: 160, width: double.infinity, fit: BoxFit.cover, cacheWidth: 480),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _takeMechanicalMainPhoto(index),
                          child: const Text('Replace Main Photo'),
                        ),
                      ],
                    ),

                  const SizedBox(height: 8),

                  TextButton.icon(
                    onPressed: () => _addMechanicalExtraPhoto(index),
                    icon: const Icon(Icons.add_a_photo, size: 20),
                    label: const Text('Add extra Mechanical photo'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF101230),
                      textStyle: const TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

       Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: _addMechanical,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Mechanical'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFA7F21),
              foregroundColor: const Color(0xFF101230),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
                  ),
          ),
        ),
        ],
      ],
    );
  }
}


