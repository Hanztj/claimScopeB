// lib/screens/commercial/components/commercial_tpo_flashings.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:claimscope_clean/inspection_report_model.dart';
import '../../../catalogs/commercial_flashing_catalog.dart';

class CommercialTpoFlashings extends StatefulWidget {
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

  const CommercialTpoFlashings({
    super.key,
    required this.flashings,
    required this.onChanged,
    required this.takePhoto,
    required this.buildingName,
    required this.roofName,
  });

  @override
  State<CommercialTpoFlashings> createState() => _CommercialTpoFlashingsState();
}

class _CommercialTpoFlashingsState extends State<CommercialTpoFlashings> {
  final _picker = ImagePicker();

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
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() {
      widget.flashings[index].extraPhotos.add(File(picked.path));
    });
    widget.onChanged();
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

        // Lista de Flashings
        ...widget.flashings.asMap().entries.map((entry) {
          final index = entry.key;
          final flashing = entry.value;
          final typeOptions = tpoFlashingOptions[flashing.type] ?? [];

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
                    value: flashing.type,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                    items: tpoFlashingOptions.keys
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => flashing.type = val);
                        widget.onChanged();
                      }
                    },
                  ),

                  // Campos dinámicos
                  if (typeOptions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: flashing.size,
                      decoration: const InputDecoration(labelText: 'Size', border: OutlineInputBorder()),
                      items: typeOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        setState(() => flashing.size = val);
                        widget.onChanged();
                      },
                    ),
                  ],

                  if (flashing.type == 'Curb flashing') ...[
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

                  if (flashing.type == 'Cap flashing') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: flashing.material,
                      decoration: const InputDecoration(labelText: 'Material', border: OutlineInputBorder()),
                      items: capFlashingMaterials.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (val) {
                        setState(() => flashing.material = val);
                        widget.onChanged();
                      },
                    ),
                  ],

                  if (flashing.type == 'Skylight flashing kit (dome)') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: flashing.grade,
                      decoration: const InputDecoration(labelText: 'Grade', border: OutlineInputBorder()),
                      items: skylightGrades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (val) {
                        setState(() => flashing.grade = val);
                        widget.onChanged();
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Main Photo
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
                          child: Image.file(flashing.photo!, height: 160, width: double.infinity, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _takeMainPhoto(index),
                          child: const Text('Replace Main Photo'),
                        ),
                      ],
                    ),

                  const SizedBox(height: 8),

                  // Extra Photos
                  TextButton.icon(
                    onPressed: () => _addExtraPhoto(index),
                    icon: const Icon(Icons.add_a_photo, size: 20),
                    label: const Text('Add extra flashing photo'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF101230),
                      textStyle: const TextStyle(fontSize: 15),
                    ),
                  ),

                  if (flashing.extraPhotos.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: flashing.extraPhotos
                          .map((f) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(f, height: 90),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),
          );
        }),

// BOTÓN "ADD FLASHING" ALINEADO A LA IZQUIERDA (ESTILO RESIDENTIAL)
Align(
  alignment: Alignment.centerLeft, // Esto lo mantiene a la izquierda
  child: ElevatedButton.icon(
    onPressed: () => _showAddFlashingDialog(),
    icon: const Icon(Icons.add, size: 18),
    label: const Text('Add Flashing'),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFFA7F21),
      foregroundColor: const Color(0xFF101230),
      textStyle: const TextStyle(
        fontSize: 14, // Tamaño de fuente consistente con Shingles
        fontWeight: FontWeight.w600,
      ),
      // Al no poner double.infinity, el botón solo ocupa lo necesario
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: tpoFlashingOptions.keys.map((type) {
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
