import 'package:flutter/material.dart';

class ResidentialRollRoofingHubForm extends StatelessWidget {
  final void Function(VoidCallback fn) setState;

  final String? roofCoverType;

  // Roll Roofing
final String? rollExposure;
  final void Function(String? value) onRollExposureChanged;

  final String? numberOfPlies;
  final void Function(String? value) onNumberOfPliesChanged;

  // Fastening
  final String? fasteningMethod;
  final void Function(String? value) onFasteningMethodChanged;

  final bool? fastenerPullTestPerformed;
  final void Function(bool? value) onFastenerPullTestPerformedChanged;

  final String? fastenerPullTestResult;
  final void Function(String? value)
      onFastenerPullTestResultChanged;

  // Underlayment
  final String? underlaymentType;
  final void Function(String? value)
      onUnderlaymentTypeChanged;

  // Insulation
  final String? insulationType;
  final void Function(String? value)
      onInsulationTypeChanged;

  final String? insulationSize;
  final void Function(String? value)
      onInsulationSizeChanged;

  // Deck
  final bool? deckRequiresReplacement;
  final void Function(bool? value)
      onDeckRequiresReplacementChanged;

  final bool? deckFullReplacementRequired;
  final void Function(bool? value)
      onDeckFullReplacementRequiredChanged;

  final String? howManySFDeckRequireReplacementVisible;
  final void Function(String? value)
      onHowManySFDeckRequireReplacementChanged;

  // Ice & Water
  final bool? iceWaterBarrierInstalled;
  final void Function(bool? value)
      onIceWaterBarrierInstalledChanged;

  // Drip Edge
  final bool? dripEdgeInstalled;
  final void Function(bool? value)
      onDripEdgeInstalledChanged;

  final String? dripEdgeType;
  final void Function(String? value)
      onDripEdgeTypeChanged;

  // Photos
  final Future<void> Function(
    String label, {
    bool isFacetPhoto,
    int? facetIndex,
    bool isGlobal,
    int? ventIndex,
    int? flashingIndex,
    int? otherElementIndex,
  }) takePhoto;

  final Future<void> Function(String label)
      takeExtraPhotoForLabel;

  // Shared dropdown builder
  final Widget Function(
    String label,
    List<String> options,
    String? value,
    Function(String?) onChanged, {
    bool requiredField,
  }) buildDropdown;

  const ResidentialRollRoofingHubForm({
    super.key,
    required this.setState,
    required this.roofCoverType,

    // Roll type
    required this.rollExposure,
    required this.onRollExposureChanged,

    required this.numberOfPlies,
    required this.onNumberOfPliesChanged,

    // Fastening
    required this.fasteningMethod,
    required this.onFasteningMethodChanged,

    required this.fastenerPullTestPerformed,
    required this.onFastenerPullTestPerformedChanged,

    required this.fastenerPullTestResult,
    required this.onFastenerPullTestResultChanged,

    // Underlayment
    required this.underlaymentType,
    required this.onUnderlaymentTypeChanged,

    // Insulation
    required this.insulationType,
    required this.onInsulationTypeChanged,

    required this.insulationSize,
    required this.onInsulationSizeChanged,

    // Deck
    required this.deckRequiresReplacement,
    required this.onDeckRequiresReplacementChanged,

    required this.deckFullReplacementRequired,
    required this.onDeckFullReplacementRequiredChanged,

    required this.howManySFDeckRequireReplacementVisible,
    required this.onHowManySFDeckRequireReplacementChanged,

    // Ice & water
    required this.iceWaterBarrierInstalled,
    required this.onIceWaterBarrierInstalledChanged,

    // Drip edge
    required this.dripEdgeInstalled,
    required this.onDripEdgeInstalledChanged,

    required this.dripEdgeType,
    required this.onDripEdgeTypeChanged,

    // Photos
    required this.takePhoto,
    required this.takeExtraPhotoForLabel,

    // Shared UI
    required this.buildDropdown,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRollRoof = roofCoverType != null &&
        roofCoverType!
            .toLowerCase()
            .trim()
            .contains('roll');

    if (!isRollRoof) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const SizedBox(height: 16),

        const Text(
          'Roof Replacement Scope',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 12),

        ElevatedButton.icon(
          onPressed: () async {
            await takePhoto(
              'Roof Overview Photo',
              isGlobal: true,
            );
          },
          icon: const Icon(Icons.camera_alt),
          label: const Text('Take Roof Overview Photo'),
        ),

        const SizedBox(height: 12),

        // Exposure
        buildDropdown(
          'Exposure',
          const [
            '30 - 32 in',
            '50% overlap',
          ],
          rollExposure,
          onRollExposureChanged,
          requiredField: true,
        ),

        const SizedBox(height: 12),

        // Number of Plies
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Number of Plies',
          ),
          initialValue: numberOfPlies,
          keyboardType: TextInputType.number,
          onChanged: onNumberOfPliesChanged,
        ),

        const SizedBox(height: 12),

        // Fastening Method
        buildDropdown(
          'Fastening Method',
          const [
            'Mechanical',
            'Autoadhered',
            'Hot moped',
          ],
          fasteningMethod,
          onFasteningMethodChanged,
          requiredField: true,
        ),

        // Mechanical only
        if (fasteningMethod == 'Mechanical') ...[

          const SizedBox(height: 12),

          CheckboxListTile(
            title: const Text(
              'Fastener Pull Test performed?',
            ),
            value:
                fastenerPullTestPerformed ?? false,
            onChanged:
                onFastenerPullTestPerformedChanged,
          ),

          if (fastenerPullTestPerformed == true) ...[

            const SizedBox(height: 12),

            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Result',
              ),
              initialValue:
                  fastenerPullTestResult,
              onChanged:
                  onFastenerPullTestResultChanged,
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () async {
                await takePhoto(
                  'Fastener Pull Test',
                  isGlobal: true,
                );
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text(
                'Take Fastener Pull Test Photo',
              ),
            ),
            TextButton(
              onPressed: () =>
                  takeExtraPhotoForLabel('Fastener Pull Test extra photo'),
              child: const Text('Add extra Fastener Pull Test photo'),
            ),
          ],
        ],

        const SizedBox(height: 12),

        // Underlayment
        buildDropdown(
          'Underlayment Type',
          const [
            'Peel stick',
            'Synthetic',
          ],
          underlaymentType,
          onUnderlaymentTypeChanged,
          requiredField: true,
        ),

        const SizedBox(height: 12),

        // Insulation
        buildDropdown(
          'Insulation Type',
          const [
            'Poliisocianurato (ISO)',
            'Poliestireno Extruido (XPS)',
            'Poliestireno Expandido (EPS)',
            'Perlite',
          ],
          insulationType,
          onInsulationTypeChanged,
          requiredField: true,
        ),

        const SizedBox(height: 12),

        buildDropdown(
          'Insulation Size',
          const [
            '1/2"',
            '1"',
            '1.5"',
            '2"',
            '2.5"',
            '3"',
            '3.5"',
            '4"',
          ],
          insulationSize,
          onInsulationSizeChanged,
          requiredField: true,
        ),

        const SizedBox(height: 12),

        // Deck
        CheckboxListTile(
          title: const Text(
            'Does the deck need to be replaced?',
          ),
          value:
              deckRequiresReplacement ?? false,
          onChanged:
              onDeckRequiresReplacementChanged,
        ),

        if (deckRequiresReplacement == true) ...[

          CheckboxListTile(
            title: const Text(
              'Deck full replacement required',
            ),
            value:
                deckFullReplacementRequired ??
                    false,
            onChanged:
                onDeckFullReplacementRequiredChanged,
          ),

          if (deckFullReplacementRequired !=
              true) ...[

            const SizedBox(height: 12),

            TextFormField(
              decoration: const InputDecoration(
                labelText:
                    'How many SF of deck require replacement',
              ),
              initialValue:
                  howManySFDeckRequireReplacementVisible,
              keyboardType:
                  TextInputType.number,
              onChanged:
                  onHowManySFDeckRequireReplacementChanged,
            ),
          ],
        ],

        const SizedBox(height: 12),

        // Ice & Water
        CheckboxListTile(
          title:
              const Text('Ice & Water Barrier'),
          value:
              iceWaterBarrierInstalled ??
                  false,
          onChanged:
              onIceWaterBarrierInstalledChanged,
        ),

        if (iceWaterBarrierInstalled ==
            true) ...[

          ElevatedButton.icon(
            onPressed: () async {
              await takePhoto(
                'Ice & Water Barrier Photo',
                isGlobal: true,
              );
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text(
              'Take Ice & Water Barrier Photo',
            ),
          ),
          TextButton(
            onPressed: () =>
                takeExtraPhotoForLabel('Ice & Water Barrier extra photo'),
            child: const Text('Add extra Ice & Water Barrier photo'),
          ),
        ],
        const SizedBox(height: 12),

        // Drip Edge
        CheckboxListTile(
          title: const Text('Drip Edge'),
          value: dripEdgeInstalled ?? false,
          onChanged: onDripEdgeInstalledChanged,
        ),

        if (dripEdgeInstalled == true) ...[

          const SizedBox(height: 12),

          buildDropdown(
            'Drip Edge Type',
            const [
              'Metal',
              'Aluminum',
              'Galvanized',
            ],
            dripEdgeType,
            onDripEdgeTypeChanged,
            requiredField: true,
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: () async {
              await takePhoto(
                'Drip Edge Photo',
                isGlobal: true,
              );
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text(
              'Take Drip Edge Photo',
            ),
          ),
          TextButton(
            onPressed: () => takeExtraPhotoForLabel('Drip Edge extra photo'),
            child: const Text('Add extra Drip Edge photo'),
          ),
        ],
      ],
    );
  }
}