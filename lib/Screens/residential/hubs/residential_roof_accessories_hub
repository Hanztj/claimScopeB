import 'dart:io';

import 'package:flutter/material.dart';

class ResidentialRoofAccessoriesHub extends StatelessWidget {
  final void Function(VoidCallback fn) setState;

  final String? roofCoverType;

  final bool isCommercial;

  // Starter row
  final bool starterRowInstalled;
  final void Function(bool value) onStarterRowInstalledChanged;
  final bool starterEaveInstalled;
  final void Function(bool value) onStarterEaveInstalledChanged;
  final File? starterEavePhoto;
  final bool starterRakeInstalled;
  final void Function(bool value) onStarterRakeInstalledChanged;
  final File? starterRakePhoto;

  // Drip edge
  final bool hasDripEdge;
  final void Function(bool value) onHasDripEdgeChanged;
  final String? dripEdgeType;
  final void Function(String? value) onDripEdgeTypeChanged;
  final File? dripEdgePhoto;
  final VoidCallback onClearDripEdge;

  // Ice & Water
  final bool iceAndWaterBarrierInstalled;
  final void Function(bool value) onIceAndWaterBarrierInstalledChanged;
  final File? iceAndWaterBarrierPhoto;

  final Future<void> Function(String label, {bool isGlobal}) takePhoto;
  final Future<void> Function(String label) takeExtraPhotoForLabel;

  final Widget Function(
    String label,
    List<String> options,
    String? value,
    Function(String?) onChanged, {
    bool requiredField,
  }) buildDropdown;

  const ResidentialRoofAccessoriesHub({
    super.key,
    required this.setState,
    required this.roofCoverType,
    required this.isCommercial,
    required this.starterRowInstalled,
    required this.onStarterRowInstalledChanged,
    required this.starterEaveInstalled,
    required this.onStarterEaveInstalledChanged,
    required this.starterEavePhoto,
    required this.starterRakeInstalled,
    required this.onStarterRakeInstalledChanged,
    required this.starterRakePhoto,
    required this.hasDripEdge,
    required this.onHasDripEdgeChanged,
    required this.dripEdgeType,
    required this.onDripEdgeTypeChanged,
    required this.dripEdgePhoto,
    required this.onClearDripEdge,
    required this.iceAndWaterBarrierInstalled,
    required this.onIceAndWaterBarrierInstalledChanged,
    required this.iceAndWaterBarrierPhoto,
    required this.takePhoto,
    required this.takeExtraPhotoForLabel,
    required this.buildDropdown,
  });

  @override
  Widget build(BuildContext context) {

    final bool isHeavyRoof = roofCoverType != null && (
      roofCoverType!.toLowerCase().trim().contains('tile') || 
      roofCoverType!.toLowerCase().trim().contains('slate') || 
      roofCoverType!.toLowerCase().trim().contains('shake')
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Starter Row Questions (GLOBAL)
          if (!isHeavyRoof && starterRowInstalled)
        CheckboxListTile(
          title: const Text('Starter Row Installed?'),
          value: starterRowInstalled,
          onChanged: (val) {
            setState(() {
              onStarterRowInstalledChanged(val ?? false);
              if (val != true) {
                onStarterEaveInstalledChanged(false);
                onStarterRakeInstalledChanged(false);
              }
            });
          },
        ),

        if (!isHeavyRoof && starterRowInstalled)
          Column(
            children: [
              CheckboxListTile(
                title: const Text('Starter Row at Eave?'),
                value: starterEaveInstalled,
                onChanged: (val) {
                  setState(() {
                    onStarterEaveInstalledChanged(val ?? false);
                  });
                },
              ),
              if (starterEaveInstalled)
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => takePhoto('Starter Row Eave Photo', isGlobal: true),
                      child: const Text("Take Starter Row Eave Photo"),
                    ),
                    TextButton(
                      onPressed: () => takeExtraPhotoForLabel('Starter row at Eave extra photo'),
                      child: const Text('Add extra Starter row at Eave photo'),
                    ),
                    if (starterEavePhoto != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Image.file(starterEavePhoto!, height: 100),
                      ),
                  ],
                ),
              CheckboxListTile(
                title: const Text('Starter Row at Rake?'),
                value: starterRakeInstalled,
                onChanged: (val) {
                  setState(() {
                    onStarterRakeInstalledChanged(val ?? false);
                  });
                },
              ),
              if (starterRakeInstalled)
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => takePhoto('Starter Row Rake Photo', isGlobal: true),
                      child: const Text("Take Starter Row Rake Photo"),
                    ),
                    TextButton(
                      onPressed: () => takeExtraPhotoForLabel('Starter row at Rake extra photo'),
                      child: const Text('Add extra Starter row at Rake photo'),
                    ),
                    if (starterRakePhoto != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Image.file(starterRakePhoto!, height: 100),
                      ),
                  ],
                ),
            ],
          ),

      // Modificado: Ahora se muestra si es Shingles O si es HeavyRoof
      if (!isCommercial && (['Shingles'].contains(roofCoverType) || isHeavyRoof))
          CheckboxListTile(
            title: const Text('Drip Edge Installed?'),
            value: hasDripEdge,
            onChanged: (val) {
              setState(() {
                onHasDripEdgeChanged(val ?? false);
                if (val != true) {
                  onClearDripEdge();
                }
              });
            },
          ),

        if (!isCommercial && (['Shingles'].contains(roofCoverType) || isHeavyRoof) && hasDripEdge)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildDropdown(
                'Drip Edge Type',
                ['Standard', 'Gutter Apron', 'Copper'],
                dripEdgeType,
                (val) => setState(() => onDripEdgeTypeChanged(val)),
              ),
              ElevatedButton(
                onPressed: () => takePhoto('Drip Edge Photo', isGlobal: true),
                child: const Text("Take Drip Edge Photo"),
              ),
              TextButton(
                onPressed: () => takeExtraPhotoForLabel('Drip Edge extra photo'),
                child: const Text('Add extra Drip Edge photo'),
              ),
              if (dripEdgePhoto != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Image.file(dripEdgePhoto!, height: 100),
                ),
            ],
          ),

        // Ice & Water Barrier (currently only used for Shingles)
        if (!isCommercial && (['Shingles'].contains(roofCoverType)|| isHeavyRoof))
          CheckboxListTile(
            title: const Text('Ice & Water Barrier Installed?'),
            value: iceAndWaterBarrierInstalled,
            onChanged: (val) {
              setState(() {
                onIceAndWaterBarrierInstalledChanged(val ?? false);
              });
            },
          ),

        if (!isCommercial && (['Shingles'].contains(roofCoverType) || isHeavyRoof) && iceAndWaterBarrierInstalled)
          Column(
            children: [
              ElevatedButton(
                onPressed: () => takePhoto('Ice & Water Barrier Photo', isGlobal: true),
                child: const Text("Take Ice & Water Barrier Photo"),
              ),
              TextButton(
                onPressed: () => takeExtraPhotoForLabel('Ice & Water Barrier extra photo'),
                child: const Text('Add extra Ice & Water Barrier photo'),
              ),
              if (iceAndWaterBarrierPhoto != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Image.file(iceAndWaterBarrierPhoto!, height: 100),
                ),
            ],
          ),
      ],
    );
  }
}
