// lib/screens/commercial/components/commercial_flashings_section.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:claimscope_clean/inspection_report_model.dart';
import '../../../catalogs/commercial_flashing_catalog.dart';

class CommercialFlashingsSection extends StatefulWidget {
  final String roofType;
  final List<CommercialFlashingData> flashings;
  final Function() onChanged;
  final Future<void> Function({
    required String buildingName,
    required String roofName,
    required String photoLabel,
    required void Function(File) onSaved,
  }) takePhoto;

  final String buildingName;
  final String roofName;

  const CommercialFlashingsSection({
    super.key,
    required this.roofType,
    required this.flashings,
    required this.onChanged,
    required this.takePhoto,
    required this.buildingName,
    required this.roofName,
  });

  @override
  State<CommercialFlashingsSection> createState() => _CommercialFlashingsSectionState();
}

class _CommercialFlashingsSectionState extends State<CommercialFlashingsSection> {
  List<String> get _typeOptions => commercialFlashingTypesForRoof(widget.roofType);

  void _addFlashing(String type) {
    setState(() {
      widget.flashings.add(CommercialFlashingData(type: type));
    });
    widget.onChanged();
  }

  void _removeFlashing(int index) {
    setState(() {
      widget.flashings.removeAt(index);
    });
    widget.onChanged();
  }

  Future<void> _takeMainPhoto(int index) async {
    await widget.takePhoto(
      buildingName: widget.buildingName,
      roofName: widget.roofName,
      photoLabel: 'Flashing ${index + 1} - Main Photo',
      onSaved: (file) {
        setState(() => widget.flashings[index].photo = file);
        widget.onChanged();
      },
    );
  }

  Future<void> _addExtraPhoto(int index) async {
    await widget.takePhoto(
      buildingName: widget.buildingName,
      roofName: widget.roofName,
      photoLabel: 'Flashing ${index + 1} - Extra Photo',
      onSaved: (file) {
        setState(() => widget.flashings[index].extraPhotos.add(file));
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
          'Flashings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF101230)),
        ),
        const SizedBox(height: 12),

        ...widget.flashings.asMap().entries.map((entry) {
          final index = entry.key;
          final flashing = entry.value;
          final typeConfig =
              commercialFlashingConfigForRoof(widget.roofType, flashing.type);

          final typeOptions = typeConfig.options;

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
                        'Flashing ${index + 1}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF101230)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeFlashing(index),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: flashing.type,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                    items: _typeOptions
                        .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          flashing.type = val;
                          flashing.size = null;
                          flashing.material = null;
                          flashing.grade = null;
                          flashing.lfCount = null;
                          flashing.count = null;
                          flashing.fullPerimeter = null;
                          flashing.otherSpecify = null;
                        });
                        widget.onChanged();
                      }
                    },
                  ),

                  if (typeOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: flashing.size,
                      decoration: const InputDecoration(labelText: 'Size', border: OutlineInputBorder()),
                      items: typeOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        setState(() => flashing.size = val);
                        widget.onChanged();
                      },
                    ),
                  ],

                  if (typeConfig.showLfCount) ...[
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'How many LF', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        flashing.lfCount = val;
                        widget.onChanged();
                      },
                    ),
                  ],
                  if (typeConfig.showFullPerimeter) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<bool>(
                      initialValue: flashing.fullPerimeter,
                      decoration: const InputDecoration(labelText: 'Full perimeter?', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Yes')),
                        DropdownMenuItem(value: false, child: Text('No')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          flashing.fullPerimeter = val;
                          if (val == true) {
                            flashing.lfCount = null;
                          }
                        });
                        widget.onChanged();
                      },
                    ),
                    if (flashing.fullPerimeter == false) ...[
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(labelText: 'How many LF', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          flashing.lfCount = val;
                          widget.onChanged();
                        },
                      ),
                    ],
                  ],

                  if (typeConfig.materialOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: flashing.material,
                      decoration: const InputDecoration(labelText: 'Material', border: OutlineInputBorder()),
                      items: typeConfig.materialOptions
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (val) {
                        setState(() => flashing.material = val);
                        widget.onChanged();
                      },
                    ),
                  ],
                  if (typeConfig.showOtherSpecify &&
                      (typeConfig.options.isEmpty || flashing.size == 'Other')) ...[
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Specify', border: OutlineInputBorder()),
                      onChanged: (val) {
                        flashing.otherSpecify = val;
                        widget.onChanged();
                      },
                    ),
                  ],

                  if (typeConfig.showCount) ...[
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'How many', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        flashing.count = val;
                        widget.onChanged();
                      },
                    ),
                  ],

                  if (typeConfig.gradeOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: flashing.grade,
                      decoration: const InputDecoration(labelText: 'Grade', border: OutlineInputBorder()),
                      items: typeConfig.gradeOptions
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) {
                        setState(() => flashing.grade = val);
                        widget.onChanged();
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  if (flashing.photo == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _takeMainPhoto(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFA7F21),
                          foregroundColor: const Color(0xFF101230),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Take Flashing Photo (Required)'),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(flashing.photo!, height: 100, fit: BoxFit.cover, cacheWidth: 300)
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
                    label: const Text('Add extra flashing photo'),
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
            onPressed: () => _showAddFlashingDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Flashing'),
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

  void _showAddFlashingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Choose Flashing Type'),
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
          _addFlashing(type);
        },
      );
    }).toList(),
    ),
   ),
      ),
    );
  }
}
