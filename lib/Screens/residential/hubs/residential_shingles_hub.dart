import 'package:flutter/material.dart';

class ResidentialShinglesHubForm extends StatelessWidget {
  final void Function(VoidCallback fn) setState;

  final bool fullRoofReplacementRequired;
  final void Function(bool value) onFullRoofReplacementRequiredChanged;
  final TextEditingController partialReplacementSqftController;
  final void Function(String? value) onPartialReplacementSqftSaved;

  final bool sheathingRequiredToBeChanged;
  final void Function(bool value) onSheathingRequiredToBeChangedChanged;

  final bool sheathingFullReplacementRequired;
  final void Function(bool value) onSheathingFullReplacementRequiredChanged;
  final TextEditingController sheathingPartialSqftController;
  final void Function(String? value) onSheathingPartialReplacementSqftSaved;

  final String? sheathingType;
  final void Function(String? value) onSheathingTypeChanged;

  final String? sheathingSize;
  final void Function(String? value) onSheathingSizeChanged;

  final Widget Function(
    String label,
    List<String> options,
    String? value,
    Function(String?) onChanged, {
    bool requiredField,
  }) buildDropdown;

  const ResidentialShinglesHubForm({
    super.key,
    required this.setState,
    required this.fullRoofReplacementRequired,
    required this.onFullRoofReplacementRequiredChanged,
    required this.partialReplacementSqftController,
    required this.onPartialReplacementSqftSaved,
    required this.sheathingRequiredToBeChanged,
    required this.onSheathingRequiredToBeChangedChanged,
    required this.sheathingFullReplacementRequired,
    required this.onSheathingFullReplacementRequiredChanged,
    required this.sheathingPartialSqftController,
    required this.onSheathingPartialReplacementSqftSaved,
    required this.sheathingType,
    required this.onSheathingTypeChanged,
    required this.sheathingSize,
    required this.onSheathingSizeChanged,
    required this.buildDropdown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        RichText(
          text: const TextSpan(
            text: 'Roof Replacement Scope',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            children: [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ),
        ),
        const Divider(),

        // Full roof replacement (roof cover)
        CheckboxListTile(
          title: const Text('Required full roof replacement?'),
          value: fullRoofReplacementRequired,
          onChanged: (val) {
            setState(() {
              onFullRoofReplacementRequiredChanged(val ?? false);
              if (val == true) {
                partialReplacementSqftController.clear();
                onPartialReplacementSqftSaved(null);
              }
            });
          },
        ),

        if (!fullRoofReplacementRequired)
          TextFormField(
            controller: partialReplacementSqftController,
            decoration: const InputDecoration(
              labelText: 'How many SF roof cover require replacement?',
            ),
            keyboardType: TextInputType.number,
            onSaved: onPartialReplacementSqftSaved,
          ),
        const SizedBox(height: 10),

        // Sheathing
        CheckboxListTile(
          title: const Text('Sheathing required to be changed?'),
          value: sheathingRequiredToBeChanged,
          onChanged: (val) {
            setState(() {
              onSheathingRequiredToBeChangedChanged(val ?? false);
              if (val != true) {
                onSheathingFullReplacementRequiredChanged(false);
                sheathingPartialSqftController.clear();
                onSheathingPartialReplacementSqftSaved(null);
                onSheathingTypeChanged(null);
                onSheathingSizeChanged(null);
              }
            });
          },
        ),

        if (sheathingRequiredToBeChanged)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheathing full/partial
              CheckboxListTile(
                title: const Text('Sheathing full replacement required?'),
                value: sheathingFullReplacementRequired,
                onChanged: (val) {
                  setState(() {
                    onSheathingFullReplacementRequiredChanged(val ?? false);
                    if (val == true) {
                      sheathingPartialSqftController.clear();
                      onSheathingPartialReplacementSqftSaved(null);
                    }
                  });
                },
              ),
              if (!sheathingFullReplacementRequired)
                TextFormField(
                  controller: sheathingPartialSqftController,
                  decoration: const InputDecoration(
                    labelText: 'How many SF of sheathing require replacement?',
                  ),
                  keyboardType: TextInputType.number,
                  onSaved: onSheathingPartialReplacementSqftSaved,
                ),

              const SizedBox(height: 10),

              buildDropdown(
                'Sheathing type',
                ['OSB', 'CDX'],
                sheathingType,
                (val) => setState(() => onSheathingTypeChanged(val)),
              ),
              buildDropdown(
                'Sheathing size',
                ['1/2"', '5/8"'],
                sheathingSize,
                (val) => setState(() => onSheathingSizeChanged(val)),
              ),
            ],
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
