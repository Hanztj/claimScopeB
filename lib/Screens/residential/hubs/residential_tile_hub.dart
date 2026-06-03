import 'package:flutter/material.dart';

class ResidentialTileHubForm extends StatelessWidget {
  final void Function(VoidCallback fn) setState;
  final String roofCoverType;

  final bool fullRoofReplacementRequired;
  final void Function(bool value) onFullRoofReplacementRequiredChanged;
  final TextEditingController partialReplacementSqftController;
  final void Function(String? value) onPartialReplacementSqftSaved;

  final String? battenSystemNeedsReplacement;
  final void Function(String? value) onBattenSystemNeedsReplacementChanged;

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

  const ResidentialTileHubForm({
    super.key,
    required this.setState,
    required this.roofCoverType,
    required this.fullRoofReplacementRequired,
    required this.onFullRoofReplacementRequiredChanged,
    required this.partialReplacementSqftController,
    required this.onPartialReplacementSqftSaved,
    required this.battenSystemNeedsReplacement,
    required this.onBattenSystemNeedsReplacementChanged,
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            children: [TextSpan(text: ' *', style: TextStyle(color: Colors.orange))],
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
              labelText: 'How many SF of roof cover require replacement?',
            ),
            keyboardType: TextInputType.number,
            onSaved: onPartialReplacementSqftSaved,
          ),
        const SizedBox(height: 10),
       
        buildDropdown(
          'The batten system needs to be changed?',
          ['Yes', 'No'],
          battenSystemNeedsReplacement,
          (val) => setState(() => onBattenSystemNeedsReplacementChanged(val)),
        ),

        const SizedBox(height: 10),

        CheckboxListTile(
          title: const Text('Sheathing required to be changed?'),
          value: sheathingRequiredToBeChanged,
          onChanged: (val) {
            setState(() {
              onSheathingRequiredToBeChangedChanged(val ?? false);
            });
          },
        ),

        if (sheathingRequiredToBeChanged)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                title: const Text('Sheathing full replacement required?'),
                value: sheathingFullReplacementRequired,
                onChanged: (val) {
                  setState(() {
                    onSheathingFullReplacementRequiredChanged(val ?? false);
                  });
                },
              ),
              if (!sheathingFullReplacementRequired) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 6, left: 12),
                    child: Text(
                      'How many SF of roof cover require replacement?',
                      style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 13, 13, 13)),
                    ),
                  ),
                ),
                TextFormField(
                  controller: sheathingPartialSqftController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => onSheathingPartialReplacementSqftSaved(val),
                ),
              ],

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