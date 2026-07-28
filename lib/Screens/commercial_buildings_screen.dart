import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/screens/commercial_building_details_screen.dart';
import 'package:claimscope_clean/utils/commercial_photo_cleanup.dart';
import 'package:flutter/material.dart';

class CommercialBuildingsScreen extends StatefulWidget {
  final String plan;
  final InspectionReport report;

  const CommercialBuildingsScreen({
    super.key,
    required this.plan,
    required this.report,
  });

  @override
  State<CommercialBuildingsScreen> createState() => _CommercialBuildingsScreenState();
}

class _CommercialBuildingsScreenState extends State<CommercialBuildingsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.report.commercialBuildings.isEmpty) {
      widget.report.commercialBuildings.add(CommercialBuildingData());
    }
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommercialBuildingDetailScreen(
          plan: widget.plan,
          report: widget.report,
          buildingIndex: 0,
        ),
      ),
    );
  }

  void _addAnotherBuilding() {
    setState(() {
      widget.report.commercialBuildings.add(CommercialBuildingData());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commercial Buildings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buildings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: widget.report.commercialBuildings.length,
                itemBuilder: (ctx, idx) {
                  final b = widget.report.commercialBuildings[idx];
                  return Card(
                    child: ListTile(
                      title: Text(b.displayName(idx)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (idx > 0)
                            IconButton(
                              tooltip: 'Delete building',
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) {
                                    return AlertDialog(
                                      title: const Text('Delete building?'),
                                      content: Text('Delete ${b.displayName(idx)}?'),
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
                                if (!mounted) return;

                                removeCommercialBuildingPhotos(
                                  report: widget.report,
                                  buildingIndex: idx,
                                );
                                setState(() {
                                  widget.report.commercialBuildings.removeAt(idx);
                                });
                              },
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CommercialBuildingDetailScreen(
                              plan: widget.plan,
                              report: widget.report,
                              buildingIndex: idx,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _addAnotherBuilding,
              child: const Text('Add another building'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _continue,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
