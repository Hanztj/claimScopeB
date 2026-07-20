// lib/screens/commercial/components/commercial_vents_section.dart

import 'dart:io';

import 'package:claimscope_clean/catalogs/commercial_vent_catalog.dart';
import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:flutter/material.dart';

class CommercialVentsSection extends StatefulWidget {
  final String roofType;
  final List<CommercialVentData> vents;
  final Function() onChanged;
  final Future<void> Function({
    required String buildingName,
    required String roofName,
    required String photoLabel,
    required void Function(File) onSaved,
  }) takePhoto;

  final String buildingName;
  final String roofName;

  const CommercialVentsSection({
    super.key,
    required this.roofType,
    required this.vents,
    required this.onChanged,
    required this.takePhoto,
    required this.buildingName,
    required this.roofName,
  });

  @override
  State<CommercialVentsSection> createState() => _CommercialVentsSectionState();
}

class _CommercialVentsSectionState extends State<CommercialVentsSection> {
  List<String> get _typeOptions => commercialVentTypesForRoof(widget.roofType);

  void _addVent(String type) {
    setState(() {
      widget.vents.add(CommercialVentData(type: type));
    });
    widget.onChanged();
  }

  void _removeVent(int index) {
    setState(() {
      widget.vents.removeAt(index);
    });
    widget.onChanged();
  }

  Future<void> _takeMainPhoto(int index) async {
    await widget.takePhoto(
      buildingName: widget.buildingName,
      roofName: widget.roofName,
      photoLabel: 'Vent ${index + 1} - Image 1',
      onSaved: (file) {
        setState(() => widget.vents[index].photo = file);
        widget.onChanged();
      },
    );
  }

  Future<void> _addExtraPhoto(int index) async {
    await widget.takePhoto(
      buildingName: widget.buildingName,
      roofName: widget.roofName,
      photoLabel: 'Vent ${index + 1} - Image 2',
      onSaved: (file) {
        setState(() => widget.vents[index].extraPhotos.add(file));
        widget.onChanged();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vents',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF101230)),
        ),
        const SizedBox(height: 12),

        ...widget.vents.asMap().entries.map((entry) {
          final index = entry.key;
          final vent = entry.value;
          final typeConfig = commercialVentConfigForRoof(widget.roofType, vent.type);

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
                        'Vent ${index + 1}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF101230)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeVent(index),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: vent.type,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                    items: _typeOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          vent.type = val;
                          vent.size = null;
                          vent.throatDimension = null;
                          vent.throatDimensionOtherSpecify = null;
                          vent.shape = null;
                          vent.otherSpecify = null;
                        });
                        widget.onChanged();
                      }
                    },
                  ),

                  if (typeConfig.sizeOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: vent.size,
                      decoration: const InputDecoration(labelText: 'Size', border: OutlineInputBorder()),
                      items: typeConfig.sizeOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) {
                        setState(() => vent.size = val);
                        widget.onChanged();
                      },
                    ),
                  ],

                  if (typeConfig.throatDimensionOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: vent.throatDimension,
                      decoration: const InputDecoration(labelText: 'Throat dimension', border: OutlineInputBorder()),
                      items: typeConfig.throatDimensionOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          vent.throatDimension = val;
                          if (val != 'Other') {
                            vent.throatDimensionOtherSpecify = null;
                          }
                        });
                        widget.onChanged();
                      },
                    ),
                  ],

                  if (typeConfig.showThroatDimensionOtherSpecify && vent.throatDimension == 'Other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Specify throat dimension', border: OutlineInputBorder()),
                      onChanged: (val) {
                        vent.throatDimensionOtherSpecify = val;
                        widget.onChanged();
                      },
                    ),
                  ],

                  if (typeConfig.shapeOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: vent.shape,
                      decoration: const InputDecoration(labelText: 'Shape', border: OutlineInputBorder()),
                      items: typeConfig.shapeOptions
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) {
                        setState(() => vent.shape = val);
                        widget.onChanged();
                      },
                    ),
                  ],

                  if (typeConfig.showOtherSpecify) ...[
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Specify', border: OutlineInputBorder()),
                      onChanged: (val) {
                        vent.otherSpecify = val;
                        widget.onChanged();
                      },
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(labelText: 'How many', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      vent.count = val;
                      widget.onChanged();
                    },
                  ),

                  const SizedBox(height: 16),

                  if (vent.photo == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _takeMainPhoto(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFA7F21),
                          foregroundColor: const Color(0xFF101230),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Take Vent Photo (Required)'),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                         child: Image.file(vent.photo!, height: 100, fit: BoxFit.cover, cacheWidth: 300),
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
                    label: const Text('Add extra Vent photo'),
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
            onPressed: () => _showAddVentDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Vent'),
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
    );
  }

  void _showAddVentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Choose Vent Type'),
content: SizedBox(
  width: double.maxFinite,
  height: 500,
  child: ListView(
    shrinkWrap: true,
    children: _typeOptions.map((type) {
      return ListTile(
        title: Text(type),
        onTap: () {
          Navigator.pop(context);
          _addVent(type);
        },
      );
    }).toList(),
  ),
),
      ),
    );
  }
}
