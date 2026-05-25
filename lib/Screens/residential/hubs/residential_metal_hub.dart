import 'package:flutter/material.dart';

class ResidentialMetalHubForm extends StatelessWidget {
  final void Function(VoidCallback fn) setState;

  final String? roofCoverType;

  // Has deck variables
  final bool? hasDeck;
  final void Function(bool? value) onHasDeckChanged;
  final bool? deckRequiresReplacement;
  final void Function(bool? value) onDeckRequiresReplacementChanged;
  final bool? deckFullReplacementRequired;
  final void Function(bool? value) onDeckFullReplacementRequiredChanged;
  final String? roofSupportBase;
  final String? howManySFDeckRequireReplacementVisible;
  final String? plywoodDeck;
  final String? osbdeck;
  final String? spacedWoodPlankDeck;
  final String? deckSize;
  final bool? iceWaterBarrierInstalled;
  final void Function(bool? value) onIceWaterBarrierInstalledChanged;
  final String? hightemp;
  final String? doubleFelt;
  final void Function(String? value) onIceWaterBarrierOptionChanged;
  final String? ordinanceandlawapproach;
  final String? noAction;
  final String? biditemblank;
  final void Function(String? value) onNoIceWaterBarrierApproachChanged;
  final void Function(String? value) onRoofSupportBaseChanged;
  final void Function(String? value) onDeckSizeChanged;
  final void Function(String? value) onHowManySFDeckRequireReplacementChanged;

  final Future<void> Function(
    String label, {
    bool isFacetPhoto,
    int? facetIndex,
    bool isGlobal,
    int? ventIndex,
    int? flashingIndex,
    int? otherElementIndex,
  }) takePhoto;
  final Future<void> Function(String label) takeExtraPhotoForLabel;

  final Widget Function(
    String label,
    List<String> options,
    String? value,
    Function(String?) onChanged, {
    bool requiredField,
  }) buildDropdown;

  const ResidentialMetalHubForm({
    super.key,
    required this.setState,
    required this.roofCoverType,
    required this.hasDeck,
    required this.onHasDeckChanged,
    required this.deckRequiresReplacement,
    required this.onDeckRequiresReplacementChanged,
    required this.deckFullReplacementRequired,
    required this.onDeckFullReplacementRequiredChanged,
    required this.osbdeck,
    required this.plywoodDeck,
    required this.spacedWoodPlankDeck,
    required this.deckSize,
    required this.onDeckSizeChanged,
    required this.onHowManySFDeckRequireReplacementChanged,
    required this.onRoofSupportBaseChanged,
    required this.doubleFelt,
    required this.hightemp,
    required this.roofSupportBase,
    required this.howManySFDeckRequireReplacementVisible,
    required this.iceWaterBarrierInstalled,
    required this.onIceWaterBarrierOptionChanged,
    required this.onIceWaterBarrierInstalledChanged,
    required this.takePhoto,
    required this.takeExtraPhotoForLabel,
    required this.buildDropdown,
    required this.biditemblank,
    required this.ordinanceandlawapproach,
    required this.noAction,
    required this.onNoIceWaterBarrierApproachChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMetalRoof = roofCoverType != null &&
        roofCoverType!.toLowerCase().trim().contains('metal');

    if (!isMetalRoof) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('Does the roof have a deck?'),
          value: hasDeck ?? false,
          onChanged: onHasDeckChanged,
        ),

        if (hasDeck == true) ...[
          CheckboxListTile(
            title: const Text('Does the deck require replacement?'),
            value: deckRequiresReplacement ?? false,
            onChanged: onDeckRequiresReplacementChanged,
          ),

          if (deckRequiresReplacement == true) ...[
            CheckboxListTile(
              title: const Text('Deck full replacement required?'),
              value: deckFullReplacementRequired ?? false,
              onChanged: onDeckFullReplacementRequiredChanged,
            ),

            // Visible mientras NO esté marcado "full replacement"
            if (deckFullReplacementRequired != true) ...[
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'How many SF of deck require replacement?',
                ),
                initialValue: howManySFDeckRequireReplacementVisible,
                keyboardType: TextInputType.number,
                onChanged: onHowManySFDeckRequireReplacementChanged,
              ),
            ],

            const SizedBox(height: 12),

            buildDropdown(
              'What is the roof support base?',
              const ['Plywood', 'OSB', 'Spaced Wood Plank'],
              roofSupportBase,
              onRoofSupportBaseChanged,
              requiredField: true,
            ),

            if (roofSupportBase != null) ...[
              const SizedBox(height: 12),
              buildDropdown(
                'Deck Size',
                const ['1/2"', '5/8"', '1x6"', '1x8"'],
                deckSize,
                onDeckSizeChanged,
                requiredField: true,
              ),
            ],

            const SizedBox(height: 12),

            buildDropdown(
              'Ice & Water Barrier Installed?',
              const ['Yes', 'No'],
              iceWaterBarrierInstalled == null
                  ? null
                  : (iceWaterBarrierInstalled! ? 'Yes' : 'No'),
              (val) {
                onIceWaterBarrierInstalledChanged(val == 'Yes');
              },
              requiredField: true,
            ),

            if (iceWaterBarrierInstalled == true) ...[
              const SizedBox(height: 12),
              buildDropdown(
                'Ice & Water Barrier Type',
                const ['High-Temp', 'Double felt'],
                hightemp ?? doubleFelt,
                onIceWaterBarrierOptionChanged,
                requiredField: true,
              ),
            ],

            if (iceWaterBarrierInstalled == false) ...[
              const SizedBox(height: 12),
              buildDropdown(
                'No Ice & Water Barrier Approach',
                const [
                  'Ordinance & Law approach',
                  'Bid Item blank',
                  'No action',
                ],
                ordinanceandlawapproach ?? biditemblank ?? noAction,
                onNoIceWaterBarrierApproachChanged,
                requiredField: true,
              ),
            ],
          ],
        ],
      ],
    );
  }
}
