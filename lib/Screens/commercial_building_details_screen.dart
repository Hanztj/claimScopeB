import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/screens/commercial_roof_section_screen.dart';
import 'package:claimscope_clean/utils/commercial_photo_cleanup.dart';
import 'package:flutter/material.dart';

class CommercialBuildingDetailScreen extends StatefulWidget {
  final String plan;
  final InspectionReport report;
  final int buildingIndex;

  const CommercialBuildingDetailScreen({
    super.key,
    required this.plan,
    required this.report,
    required this.buildingIndex,
  });

  @override
  State<CommercialBuildingDetailScreen> createState() => _CommercialBuildingDetailScreenState();
}

class _CommercialBuildingDetailScreenState extends State<CommercialBuildingDetailScreen> {
  late final CommercialBuildingData building;

  final _nameController = TextEditingController();
  final _streetController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    building = widget.report.commercialBuildings[widget.buildingIndex];

    if (building.roofs.isEmpty) {
      building.roofs.add(CommercialRoofSectionData()..roofLabel = 'Main Roof');
    } else {
      final label = (building.roofs.first.roofLabel ?? '').trim();
      if (label.isEmpty) {
        building.roofs.first.roofLabel = 'Main Roof';
      }
    }

    _nameController.text = building.name ?? '';
    _streetController.text = building.streetAddress ?? '';
    _notesController.text = building.notes ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _sync() {
    building.name = _nameController.text.trim().isEmpty
        ? null
        : _nameController.text.trim();

    building.streetAddress = _streetController.text.trim().isEmpty
        ? null
        : _streetController.text.trim();

    building.notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
  }

  void _addRoofSection() {
    _sync();
    setState(() {
      building.roofs.add(CommercialRoofSectionData());
    });
  }

  void _deleteRoofSection(int roofIndex) {
    removeCommercialRoofSectionPhotos(
      report: widget.report,
      buildingIndex: widget.buildingIndex,
      roofIndex: roofIndex,
    );
    setState(() {
      if (building.roofs.length <= 1) {
        building.roofs = [CommercialRoofSectionData()..roofLabel = 'Main Roof'];
        return;
      }

      building.roofs.removeAt(roofIndex);
      if (building.roofs.isNotEmpty) {
        final firstLabel = (building.roofs.first.roofLabel ?? '').trim();
        if (firstLabel.isEmpty) {
          building.roofs.first.roofLabel = 'Main Roof';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayName = building.displayName(widget.buildingIndex);

      if (widget.buildingIndex == 0 &&
      building.differentAddress) {
    building.differentAddress = false;
    building.streetAddress = null;
    _streetController.clear();
  }

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Building name (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _sync(),
          ),
          const SizedBox(height: 12),
           if (widget.buildingIndex > 0) ...[
            CheckboxListTile(
              title: const Text('Different address than main?'),
              value: building.differentAddress,
              onChanged: (v) {
                setState(() {
                  building.differentAddress = v ?? false;
                  if (!building.differentAddress) {
                    _streetController.clear();
                    building.streetAddress = null;
                  }
                });
              },
            ),
            if (building.differentAddress) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'Street address',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _sync(),
              ),
            ],
            const SizedBox(height: 12),
          ],

          CheckboxListTile(
            title: const Text('Does this building have more than one roof cover type?'),
            value: building.hasMultipleRoofTypes,
            onChanged: (v) {
              setState(() {
                building.hasMultipleRoofTypes = v ?? false;
                if (!building.hasMultipleRoofTypes) {
                  if (building.roofs.isEmpty) {
                    building.roofs.add(CommercialRoofSectionData()..roofLabel = 'Main Roof');
                  } else if (building.roofs.length > 1) {
                    for (var roofIndex = building.roofs.length - 1;
                        roofIndex >= 1;
                        roofIndex--) {
                      removeCommercialRoofSectionPhotos(
                        report: widget.report,
                        buildingIndex: widget.buildingIndex,
                        roofIndex: roofIndex,
                      );
                    }
                    building.roofs = [building.roofs.first];
                  }
                } else {
                  if (building.roofs.isEmpty) {
                    building.roofs.add(CommercialRoofSectionData()..roofLabel = 'Main Roof');
                  }
                }
              });
            },
          ),
          const SizedBox(height: 12),
          if (building.roofs.isNotEmpty) ...[
            const Divider(),
            const Text('Roof sections', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...building.roofs.asMap().entries.map((entry) {
              final idx = entry.key;
              final roof = entry.value;
              final roofName = (roof.roofLabel ?? '').trim().isEmpty
                  ? 'Roof ${idx + 1}'
                  : roof.roofLabel!.trim();

              final subtitle = [roof.roofType, roof.roofSubType]
                  .whereType<String>()
                  .where((s) => s.trim().isNotEmpty)
                  .join(' - ');

              return Card(
                child: ListTile(
                  title: Text(roofName),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (idx > 0)
                        IconButton(
                          tooltip: 'Delete roof section',
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) {
                                return AlertDialog(
                                  title: const Text('Delete roof section?'),
                                  content: Text('Delete $roofName?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmed != true) return;
                            if (!context.mounted) return;

                            _deleteRoofSection(idx);
                          },
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    _sync();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CommercialRoofSectionScreen(
                          plan: widget.plan,
                          report: widget.report,
                          buildingIndex: widget.buildingIndex,
                          roofIndex: idx,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
            if (building.hasMultipleRoofTypes) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _addRoofSection,
                child: const Text('Add another roof section'),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _sync();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CommercialRoofSectionScreen(
                        plan: widget.plan,
                        report: widget.report,
                        buildingIndex: widget.buildingIndex,
                        roofIndex: 0,
                      ),
                    ),
                  );
                },
                child: const Text('Continue to roof details'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Building notes (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _sync(),
          ),
        ],
      ),
    );
  }
}
