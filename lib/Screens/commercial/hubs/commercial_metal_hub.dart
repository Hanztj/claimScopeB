import 'dart:io';

import 'package:flutter/material.dart';

import '../../../inspection_report_model.dart';
import '../components/commercial_hvac_mechanical_rooftop.dart';
import '../components/commercial_flashings_section.dart';
import '../components/commercial_vents_section.dart';

class CommercialMetalHubForm extends StatelessWidget {
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
  }) takeCommercialPhoto;

  const CommercialMetalHubForm({
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─────────────────────────────────────────────────────────
        // EXISTENTE — Style / Has facets / Facet count / Pitch
        // (no tocar)
        // ─────────────────────────────────────────────────────────
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: roof.metalStyle,
          decoration: const InputDecoration(
            labelText: 'Metal style',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Flat', child: Text('Flat')),
            DropdownMenuItem(value: 'Gable', child: Text('Gable')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (val) {
            setState(() {
              roof.metalStyle = val;
              if (val == 'Gable') {
                roof.facetCount = 2;
                facetCountController.text = '2';
              }
              if (val == 'Flat') {
                roof.facetCount = 1;
                facetCountController.text = '1';
                roof.metalHasFacets = null;
              }
            });
          },
        ),
        if (roof.metalStyle == 'Other') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<bool>(
            initialValue: roof.metalHasFacets,
            decoration: const InputDecoration(
              labelText: 'Has facets?',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: true, child: Text('Yes')),
              DropdownMenuItem(value: false, child: Text('No')),
            ],
            onChanged: (val) {
              setState(() {
                roof.metalHasFacets = val;
                if (val == true && roof.facetCount <= 1) {
                  roof.facetCount = 2;
                  facetCountController.text = '2';
                }
                if (val != true) {
                  roof.facetCount = 1;
                  facetCountController.text = '1';
                }
              });
            },
          ),
        ],
        if (roof.metalStyle == 'Gable' || roof.metalHasFacets == true) ...[
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
        if (roof.metalStyle != 'Flat') ...[
          const SizedBox(height: 12),
          TextField(
            controller: pitchController,
            decoration: const InputDecoration(
              labelText: 'Pitch (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => sync(),
          ),
        ],

        // ─────────────────────────────────────────────────────────
        // NUEVO — Bloque Deck (copia 1:1 de residential_metal_hub)
        // ─────────────────────────────────────────────────────────
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('Does the roof have a deck?'),
          value: roof.hasDeck,
          onChanged: (val) {
            setState(() {
              roof.hasDeck = val ?? false;
              if (!roof.hasDeck) {
                roof.deckChangeRequired = false;
                roof.deckFullReplacementRequired = false;
                roof.deckPartialReplacementSqft = null;
                deckPartialSqftController.clear();
                roof.deckType = null;
                roof.deckThicknessGauge = null;
              }
            });
          },
        ),
        if (roof.hasDeck) ...[
          CheckboxListTile(
            title: const Text('Does the deck require replacement?'),
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
              title: const Text('Deck full replacement required?'),
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
                  labelText: 'How many SF of deck require replacement?',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => sync(),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: roof.deckType,
              decoration: const InputDecoration(
                labelText: 'What is the roof support base?',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Plywood', child: Text('Plywood')),
                DropdownMenuItem(value: 'OSB', child: Text('OSB')),
                DropdownMenuItem(value: 'Spaced Wood Plank', child: Text('Spaced Wood Plank')),
              ],
              onChanged: (val) {
                setState(() {
                  roof.deckType = val;
                  roof.deckThicknessGauge = null;
                });
              },
            ),
            if (roof.deckType != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: roof.deckThicknessGauge,
                decoration: const InputDecoration(
                  labelText: 'Deck Size',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '1/2"', child: Text('1/2"')),
                  DropdownMenuItem(value: '5/8"', child: Text('5/8"')),
                  DropdownMenuItem(value: '1x6"', child: Text('1x6"')),
                  DropdownMenuItem(value: '1x8"', child: Text('1x8"')),
                ],
                onChanged: (val) {
                  setState(() {
                    roof.deckThicknessGauge = val;
                  });
                },
              ),
            ],
          ],
        ],

        // ─────────────────────────────────────────────────────────
        // NUEVO — Bloque Insulation (commercial Metal)
        // ─────────────────────────────────────────────────────────
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('Does the roof have insulation?'),
          value: roof.hasInsulation,
          onChanged: (val) {
            setState(() {
              roof.hasInsulation = val ?? false;
              if (!roof.hasInsulation) {
                roof.insulationType = null;
              }
            });
          },
        ),
        if (roof.hasInsulation) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: roof.insulationType,
            decoration: const InputDecoration(
              labelText: 'Insulation type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Fiberglass with vinyl facing',
                child: Text('Fiberglass with vinyl facing'),
              ),
              DropdownMenuItem(value: 'Rigid board', child: Text('Rigid board')),
              DropdownMenuItem(value: 'Spray foam', child: Text('Spray foam')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (val) {
              setState(() {
                roof.insulationType = val;
              });
            },
          ),
        ],

        // ─────────────────────────────────────────────────────────
        // NUEVO — Flashings / Vents / HVAC+Mechanical
        // Reusa los widgets genéricos de Fase 1 con roofType: 'Metal'.
        // Listas (flashingTypesMetal / ventTypesMetal) idénticas a
        // residential Metal; Card/UI/flujo = los de commercial flat.
        // ─────────────────────────────────────────────────────────
        const SizedBox(height: 16),
        CommercialFlashingsSection(
          roofType: 'Metal',
          flashings: roof.tpoFlashings,
          onChanged: sync,
          takePhoto: takeCommercialPhoto,
          buildingName: buildingName,
          roofName: roofName,
        ),
        const SizedBox(height: 16),
        CommercialVentsSection(
          roofType: 'Metal',
          vents: roof.tpoVents,
          onChanged: sync,
          takePhoto: takeCommercialPhoto,
          buildingName: buildingName,
          roofName: roofName,
        ),
        const SizedBox(height: 16),
        CommercialHvacMechanicalRooftop(
          hvacItems: roof.hvacUnits,
          mechanicalItems: roof.mechanicalUnits,
          onChanged: sync,
          takePhoto: takeCommercialPhoto,
          buildingName: buildingName,
          roofName: roofName,
        ),
      ],
    );
  }
}
