import 'dart:io';
import 'package:claimscope_clean/screens/elevations/elevations_inspection_screen.dart';
import 'package:flutter/material.dart';
import 'package:claimscope_clean/inspection_report_model.dart';

class ResidentialFacetInspectionHub extends StatelessWidget {
  final void Function(VoidCallback fn) setState;
 
 final InspectionReport report;

  final String? roofCoverType;

  final List<Map<String, dynamic>> facets;
  final int currentFacetIndex;
  final VoidCallback onPreviousFacet;
  final VoidCallback onNextFacet;

  final TextEditingController currentFacetNameController;
  final String? currentFacetOrientationName;
  final List<String> facetOrientationOptions;
  final void Function(String? value) onFacetOrientationChanged;

  final TextEditingController currentPitchFacetController;
  final File? currentFacetOverviewPhoto;

  final bool currentHasRidgeVent;
  final void Function(bool value) onCurrentHasRidgeVentChanged;
  final List<String> ridgeVentTypes;
  final String? currentRidgeVentType;
  final void Function(String? value) onCurrentRidgeVentTypeChanged;
  final File? currentRidgeVentPhoto;

  final bool currentAtrPerformed;
  final void Function(bool value) onCurrentAtrPerformedChanged;
  final List<String> atrResults;
  final String? currentAtrResult;
  final void Function(String? value) onCurrentAtrResultChanged;
  final File? currentAtrPhoto;

  final bool currentHasValleyMetal;
  final void Function(bool value) onCurrentHasValleyMetalChanged;
  final List<String> valleyMetalTypes;
  final String? currentValleyMetalType;
  final void Function(String? value) onCurrentValleyMetalTypeChanged;
  final File? currentValleyMetalPhoto;

  final List<Map<String, dynamic>> currentFacetFlashingsData;
  final List<TextEditingController> currentFlashingOtherControllers;
  final void Function(int idx) onRemoveFlashing;
  final VoidCallback onAddFlashing;
  final List<String> flashingTypes;
  final Widget Function(Map<String, dynamic> data) buildFlashingSubfields;

  final List<Map<String, dynamic>> currentFacetVentsData;
  final List<TextEditingController> currentVentCountControllers;
  final List<TextEditingController> currentOtherVentSpecifyControllers;
  final void Function(int idx) onRemoveVent;
  final VoidCallback onAddVent;
  final List<String> ventTypes;

  final List<Map<String, dynamic>> currentFacetOtherElementsData;
  final List<TextEditingController> currentOtherElementCountControllers;
  final List<TextEditingController> currentOtherElementSpecifyControllers;
  final void Function(int idx) onRemoveOtherElement;
  final VoidCallback onAddOtherElement;

  final VoidCallback onTakeAdditionalFacetPhoto;

  final TextEditingController currentFacetCommentController;

  final bool isLastFacet;
  final void Function(bool value) onIsLastFacetChanged;

  final VoidCallback pickImagesFromGallery;
  final List<File> photoReportImages;
  final List<Map<String, String>> inspectionData;
  final void Function(File imageFile) onRemoveGalleryImage;

  final VoidCallback addNextFacet;
  final VoidCallback onDeleteCurrentFacet;
  final VoidCallback submitForm;
  final bool isSingleRoofSection;

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

  const ResidentialFacetInspectionHub({
    super.key,
    required this.setState,
    required this.roofCoverType,
    required this.facets,
    required this.currentFacetIndex,
    required this.onPreviousFacet,
    required this.onNextFacet,
    required this.currentFacetNameController,
    required this.currentFacetOrientationName,
    required this.facetOrientationOptions,
    required this.onFacetOrientationChanged,
    required this.currentPitchFacetController,
    required this.currentFacetOverviewPhoto,
    required this.currentHasRidgeVent,
    required this.onCurrentHasRidgeVentChanged,
    required this.ridgeVentTypes,
    required this.currentRidgeVentType,
    required this.onCurrentRidgeVentTypeChanged,
    required this.currentRidgeVentPhoto,
    required this.currentAtrPerformed,
    required this.onCurrentAtrPerformedChanged,
    required this.atrResults,
    required this.currentAtrResult,
    required this.onCurrentAtrResultChanged,
    required this.currentAtrPhoto,
    required this.currentHasValleyMetal,
    required this.onCurrentHasValleyMetalChanged,
    required this.valleyMetalTypes,
    required this.currentValleyMetalType,
    required this.onCurrentValleyMetalTypeChanged,
    required this.currentValleyMetalPhoto,
    required this.currentFacetFlashingsData,
    required this.currentFlashingOtherControllers,
    required this.onRemoveFlashing,
    required this.onAddFlashing,
    required this.flashingTypes,
    required this.buildFlashingSubfields,
    required this.currentFacetVentsData,
    required this.currentVentCountControllers,
    required this.currentOtherVentSpecifyControllers,
    required this.onRemoveVent,
    required this.onAddVent,
    required this.ventTypes,
    required this.currentFacetOtherElementsData,
    required this.currentOtherElementCountControllers,
    required this.currentOtherElementSpecifyControllers,
    required this.onRemoveOtherElement,
    required this.onAddOtherElement,
    required this.onTakeAdditionalFacetPhoto,
    required this.currentFacetCommentController,
    required this.isLastFacet,
    required this.onIsLastFacetChanged,
    required this.pickImagesFromGallery,
    required this.photoReportImages,
    required this.inspectionData,
    required this.onRemoveGalleryImage,
    required this.addNextFacet,
    required this.onDeleteCurrentFacet,
    required this.submitForm,
    this.isSingleRoofSection = false,
    required this.takePhoto,
    required this.takeExtraPhotoForLabel,
    required this.buildDropdown,
    required this.report,
  });

    String _selectedLabel({
    required String fallback,
    required int index,
    required String? type,
    TextEditingController? otherController,
  }) {
    if (type == 'Other') {
      final other = otherController?.text.trim() ?? '';
      if (other.isNotEmpty) return '$fallback ${index + 1} ($other)';
      return 'Other $fallback ${index + 1}';
    }

    if (type != null && type.trim().isNotEmpty) {
      return type.trim();
    }

    return '$fallback ${index + 1}';
  }
    
  @override
  Widget build(BuildContext context) {
    
         final bool isHeavyRoof = roofCoverType != null && (
      roofCoverType!.toLowerCase().trim().contains('tile') || 
      roofCoverType!.toLowerCase().trim().contains('slate') || 
      roofCoverType!.toLowerCase().trim().contains('shake')
    );

    if (roofCoverType == null) return const SizedBox.shrink();

          final previewPhotoReportImages = photoReportImages.length > 12
        ? photoReportImages.sublist(photoReportImages.length - 12)
        : photoReportImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isSingleRoofSection ? 'Roof Section Inspection' : 'Facet Inspection',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Divider(),
        if (!isSingleRoofSection) ...[
          if (facets.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: currentFacetIndex > 0 ? onPreviousFacet : null,
                  child: const Text('Previous Facet'),
                ),
                Text('Facet ${currentFacetIndex + 1} of ${facets.length}'),
                ElevatedButton(
                  onPressed:
                      currentFacetIndex < facets.length - 1 ? onNextFacet : null,
                  child: const Text('Next Facet'),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            'Current Facet: ${currentFacetNameController.text}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          buildDropdown(
            'Facet Orientation',
            facetOrientationOptions,
            currentFacetOrientationName,
            (val) => setState(() => onFacetOrientationChanged(val)),
            requiredField: true,
          ),
          TextFormField(
            controller: currentFacetNameController,
            decoration: const InputDecoration(labelText: 'Facet Name'),
            validator: (v) => v!.isEmpty ? 'Required' : null,
            onSaved: (val) => facets[currentFacetIndex]['facetName'] = val,
          ),
          TextFormField(
            controller: currentPitchFacetController,
            decoration: const InputDecoration(labelText: 'Pitch of Facet'),
            onSaved: (val) => facets[currentFacetIndex]['pitchFacetValue'] = val,
          ),
          if (currentFacetIndex >= 1)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onDeleteCurrentFacet,
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Delete current facet',
                    style: TextStyle(color: Colors.red)),
              ),
            ),
          ElevatedButton(
            onPressed: () => takePhoto(
              'Facet Overview Photo',
              isFacetPhoto: true,
              facetIndex: currentFacetIndex,
            ),
            child: const Text("Take Facet Overview Photo"),
          ),
          if (currentFacetOverviewPhoto != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Image.file(currentFacetOverviewPhoto!, height: 100, cacheWidth: 300),
            ),
        ],
        if (!isSingleRoofSection &&
            !isHeavyRoof &&
            roofCoverType?.toLowerCase().trim() != 'metal')
          CheckboxListTile(
            title: const Text('Is there Ridge Vent?'),
            value: currentHasRidgeVent,
            onChanged: (val) => setState(() {
              onCurrentHasRidgeVentChanged(val ?? false);
            }),
          ),
        if (!isSingleRoofSection &&
            !isHeavyRoof &&
            roofCoverType?.toLowerCase().trim() != 'metal' &&
            currentHasRidgeVent)
          Column(
            children: [
              buildDropdown(
                'Ridge Vent Type',
                ridgeVentTypes,
                currentRidgeVentType,
                (val) => setState(() => onCurrentRidgeVentTypeChanged(val)),
              ),
              ElevatedButton(
                onPressed: () => takePhoto(
                  'Ridge Vent Photo',
                  isFacetPhoto: true,
                  facetIndex: currentFacetIndex,
                ),
                child: const Text("Take Ridge Vent Photo"),
              ),
              TextButton(
                onPressed: () => takeExtraPhotoForLabel('Ridge Vent extra photo'),
                child: const Text('Add extra Ridge Vent photo'),
              ),
              if (currentRidgeVentPhoto != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Image.file(currentRidgeVentPhoto!, height: 100, cacheWidth: 300),
                ),
            ],
          ),
        if (!isSingleRoofSection && roofCoverType == 'Shingles')
          CheckboxListTile(
            title: const Text('ATR Performed?'),
            value: currentAtrPerformed,
            onChanged: (val) => setState(() {
              onCurrentAtrPerformedChanged(val ?? false);
            }),
          ),

        if (!isSingleRoofSection &&
            roofCoverType == 'Shingles' &&
            currentAtrPerformed)
          Column(
            children: [ 
              buildDropdown(
                'ATR Result',
                atrResults,
                currentAtrResult,
                (val) => setState(() => onCurrentAtrResultChanged(val)),
              ),
              ElevatedButton(
                onPressed: () => takePhoto(
                  'ATR Photo',
                  isFacetPhoto: true,
                  facetIndex: currentFacetIndex,
                ),
                child: const Text("Take ATR Photo"),
              ),
              TextButton(
                onPressed: () => takeExtraPhotoForLabel('ATR extra photo'),
                child: const Text('Add extra ATR photo'),
              ),
              if (currentAtrPhoto != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Image.file(currentAtrPhoto!, height: 100, cacheWidth: 300),
                ),
            ],
          ),

        if (!isSingleRoofSection)
          CheckboxListTile(
            title: const Text('Has Valley Metal?'),
            value: currentHasValleyMetal,
            onChanged: (val) => setState(() {
              onCurrentHasValleyMetalChanged(val ?? false);
            }),
          ),
        if (!isSingleRoofSection && currentHasValleyMetal)
          Column(
            children: [
              buildDropdown(
                'Valley Metal Type',
                valleyMetalTypes,
                currentValleyMetalType,
                (val) => setState(() => onCurrentValleyMetalTypeChanged(val)),
              ),
              ElevatedButton(
                onPressed: () => takePhoto(
                  'Valley Metal Photo',
                  isFacetPhoto: true,
                  facetIndex: currentFacetIndex,
                ),
                child: const Text("Take Valley Metal Photo"),
              ),
              TextButton(
                onPressed:
                    () => takeExtraPhotoForLabel('Valley Metal extra photo'),
                child: const Text('Add extra Valley Metal photo'),
              ),
              if (currentValleyMetalPhoto != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Image.file(currentValleyMetalPhoto!, height: 100, cacheWidth: 300),
                ),
            ],
          ),

        const SizedBox(height: 20),
        Text(
          isSingleRoofSection ? 'Flashings' : 'Flashings on Facet',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Divider(),

        ...currentFacetFlashingsData.asMap().entries.map((entry) {
          final idx = entry.key;
          final data = entry.value;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Flashing ${idx + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => onRemoveFlashing(idx)),
                      ),
                    ],
                  ),
                  buildDropdown(
                    'Flashing Type',
                    flashingTypes,
                    data['type'],
                    (val) {
                      setState(() {
                        data['type'] = val;
                        data['material'] = null;
                        data['size'] = null;
                        data['finish'] = null;
                        data['grade'] = null;
                        data['count'] = '';
                        data['changeFlueCap'] = false;
                        data['changeChaseCover'] = false;
                        data['chaseCoverMaterial'] = null;
                        data['otherSpecify'] = '';
                        if (data['otherController'] is TextEditingController) {
                          (data['otherController'] as TextEditingController).clear();
                        }
                      });
                    },
                  ),
                  if (data['type'] == 'Other')
                    TextFormField(
                      controller: data['otherController'],
                      decoration:
                          const InputDecoration(labelText: 'Specify Other Flashing'),
                      onSaved: (val) => data['otherSpecify'] = val,
                    ),
                  buildFlashingSubfields(data),
                  CheckboxListTile(
                    title: const Text('Should be changed?'),
                    value: data['shouldBeChanged'],
                    onChanged: (val) =>
                        setState(() => data['shouldBeChanged'] = val ?? false),
                         ),
                                           if (data['type'] == 'Chimney flashing') ...[
                    CheckboxListTile(
                      title: const Text('Change flue cap?'),
                      value: data['changeFlueCap'] ?? false,
                      onChanged: (val) => setState(
                        () => data['changeFlueCap'] = val ?? false,
                      ),
                    ),
                    CheckboxListTile(
                      title: const Text('Change chase cover?'),
                      value: data['changeChaseCover'] ?? false,
                      onChanged: (val) => setState(() {
                        data['changeChaseCover'] = val ?? false;
                        if (data['changeChaseCover'] != true) {
                          data['chaseCoverMaterial'] = null;
                        }
                      }),
                    ),
                    if (data['changeChaseCover'] == true)
                      buildDropdown(
                        'Chase cover material',
                        const ['Metal', 'Copper'],
                        data['chaseCoverMaterial'],
                        (val) => setState(() => data['chaseCoverMaterial'] = val),
                      ),
                  ],
                  ElevatedButton(
                    onPressed: () => takePhoto(
                      '${_selectedLabel(
                        fallback: 'flashing',
                        index: idx,
                        type: data['type'] as String?,
                        otherController: data['otherController']
                            as TextEditingController?,
                      )} Photo',
                      flashingIndex: idx,
                    ),
                    child: const Text("Take Flashing Photo"),
                  ),
                  TextButton(
                    onPressed: () => takeExtraPhotoForLabel(
                      '${_selectedLabel(
                        fallback: 'flashing',
                        index: idx,
                        type: data['type'] as String?,
                        otherController: data['otherController']
                            as TextEditingController?,
                      )} extra photo',
                    ),
                    child: const Text('Add extra Flashing photo'),
                  ),
                  if (data['photo'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Image.file(data['photo']!, height: 100, cacheWidth: 300),
                    ),
                ],
              ),
            ),
          );
        }),

        ElevatedButton(
          onPressed: () => setState(onAddFlashing),
          child: const Text('Add Flashing'),
        ),

        const SizedBox(height: 20),
        Text(
          isSingleRoofSection ? 'Vents' : 'Vents on Facet',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Divider(),

        ...currentFacetVentsData.asMap().entries.map((entry) {
          final ventIndex = entry.key;
          final ventData = entry.value;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Vent ${ventIndex + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => onRemoveVent(ventIndex)),
                      ),
                    ],
                  ),
                  buildDropdown(
                    'Vent Type',
                    ventTypes,
                    ventData['type'],
                    (val) => setState(() => ventData['type'] = val),
                  ),
                  CheckboxListTile(
                    title: const Text('Should be Changed?'),
                    value: ventData['shouldBeChanged'],
                    onChanged: (val) =>
                        setState(() => ventData['shouldBeChanged'] = val!),
                  ),
                  if (ventData['type'] != 'Other')
                    TextFormField(
                      controller: ventData['countController'],
                      decoration: InputDecoration(
                        labelText: 'Count of ${ventData['type']}',
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (val) => ventData['count'] = val,
                    ),
                  if (ventData['type'] == 'Pipe jack')
                    Column(
                      children: [
                        CheckboxListTile(
                          title: const Text('Include Split Boot?'),
                          value: ventData['includeSplitBoot'],
                          onChanged: (val) => setState(
                            () => ventData['includeSplitBoot'] = val!,
                          ),
                        ),
                        CheckboxListTile(
                          title: const Text('Include Lead?'),
                          value: ventData['includeLead'],
                          onChanged: (val) => setState(
                            () => ventData['includeLead'] = val!,
                          ),
                        ),
                      ],
                    ),
                  if (ventData['type'] == 'Other')
                    TextFormField(
                      controller: ventData['otherSpecifyController'],
                      decoration:
                          const InputDecoration(labelText: 'Specify Other Vent'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      onSaved: (val) => ventData['otherSpecify'] = val,
                    ),
                  ElevatedButton(
                    onPressed: () => takePhoto(
                      '${_selectedLabel(
                        fallback: 'vent',
                        index: ventIndex,
                        type: ventData['type'] as String?,
                        otherController: ventData['otherSpecifyController']
                            as TextEditingController?,
                      )} Photo',
                      ventIndex: ventIndex,
                    ),
                    child: const Text("Take Vent Photo"),
                  ),
                  TextButton(
                    onPressed: () => takeExtraPhotoForLabel(
                      '${_selectedLabel(
                        fallback: 'vent',
                        index: ventIndex,
                        type: ventData['type'] as String?,
                        otherController: ventData['otherSpecifyController']
                            as TextEditingController?,
                      )} extra photo',
                    ),
                    child: const Text('Add extra Vent photo'),
                  ),
                  if (ventData['photo'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                     child: Image.file(ventData['photo']!, height: 100, cacheWidth: 300),
                    ),
                ],
              ),
            ),
          );
        }),

        ElevatedButton(
          onPressed: () => setState(onAddVent),
          child: const Text('Add Vent'),
        ),

        const SizedBox(height: 20),
        Text(
          isSingleRoofSection ? 'Other elements on the Roof' : 'Other elements on the Facet',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Divider(),

        ...currentFacetOtherElementsData.asMap().entries.map((entry) {
          final idx = entry.key;
          final data = entry.value;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Element ${idx + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed:
                            () => setState(() => onRemoveOtherElement(idx)),
                      ),
                    ],
                  ),
                  buildDropdown(
                    'Element Type',
                    [
                      'Snow guard/stop',
                      'Snow bar - powder coated',
                      'Snow panel - aluminum',
                      'Snow panel rake cap - aluminum',
                      'Skylight',
                      'Evaporative cooler',
                      'Air condenser w/pad',
                      'Solar electric panel',
                      'Water heater panel',
                      'Satellite dishes',
                      'AC Units',
                      'Meter mast for overhead power – conduit',
                      'Other',
                    ],
                    data['type'],
                    (val) => setState(() => data['type'] = val),
                  ),
                  TextFormField(
                    controller: data['countController'],
                    decoration: const InputDecoration(
                      labelText: 'Count',
                    ),
                    keyboardType: TextInputType.number,
                    onSaved: (val) => data['count'] = val,
                  ),
                  if (data['type'] == 'Other')
                    TextFormField(
                      controller: data['otherSpecifyController'],
                      decoration: const InputDecoration(
                        labelText: 'Specify Other element',
                      ),
                      onSaved: (val) => data['otherSpecify'] = val,
                    ),
                  CheckboxListTile(
                    title: const Text('Should be changed?'),
                    value: data['shouldBeChanged'],
                    onChanged: (val) {
                      setState(() {
                        data['shouldBeChanged'] = val ?? false;
                        if (data['shouldBeChanged'] == true) {
                          data['detachAndResetOnly'] = false;
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Detach & Reset only'),
                    value: data['detachAndResetOnly'],
                    onChanged: (val) {
                      setState(() {
                        data['detachAndResetOnly'] = val ?? false;
                        if (data['detachAndResetOnly'] == true) {
                          data['shouldBeChanged'] = false;
                        }
                      });
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => takePhoto(
                      'Other element photo ${idx + 1}',
                      otherElementIndex: idx,
                    ),
                    child: const Text("Take element photo"),
                  ),
                  TextButton(
                    onPressed: () => takeExtraPhotoForLabel(
                      'Other element ${idx + 1} (${data['type'] ?? 'Unknown'}) extra photo',
                    ),
                    child: const Text('Add extra element photo'),
                  ),
                  if (data['photo'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                     child: Image.file(data['photo'] as File, height: 100, cacheWidth: 300),
                    ),
                ],
              ),
            ),
          );
        }),

        ElevatedButton(
          onPressed: () => setState(onAddOtherElement),
          child: const Text('Add Other element'),
        ),

        const SizedBox(height: 20),
        const Divider(),
        ElevatedButton.icon(
          onPressed: onTakeAdditionalFacetPhoto,
          icon: const Icon(Icons.add_a_photo),
          label: Text(
            isSingleRoofSection
                ? 'Take additional roof photo'
                : 'Take additional photo of this facet',
          ),
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 20),
        Text(
          isSingleRoofSection
              ? 'Additional comments'
              : 'Additional comment on this facet',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Divider(),
        TextFormField(
          controller: currentFacetCommentController,
          decoration: const InputDecoration(
            labelText: 'Comment',
            alignLabelWithHint: true,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 20),

        if (!isSingleRoofSection)
          CheckboxListTile(
            title: const Text('This is the Last Facet'),
            value: isLastFacet,
            onChanged: (val) =>
                setState(() => onIsLastFacetChanged(val ?? false)),
          ),
        if (isSingleRoofSection || isLastFacet) ...[
          const SizedBox(height: 20),
          const Text(
            'Photo Report - Additional Images',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          ElevatedButton.icon(
            onPressed: pickImagesFromGallery,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text("Add Images from your gallery?"),
          ),
          const SizedBox(height: 10),
          if (photoReportImages.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photoReportImages.length > previewPhotoReportImages.length
                      ? 'Images added to the report: ${photoReportImages.length} total. Showing latest ${previewPhotoReportImages.length} thumbnails.'
                      : 'Images added to the report:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: previewPhotoReportImages.map((imageFile) {
                    return Stack(
                      children: [
                        Image.file(
                          imageFile,
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                          cacheWidth: 240,
                          cacheHeight: 240,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => onRemoveGalleryImage(imageFile)),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],
            ),
        ],

// 🟢 1. Botón "Add Next Facet" (Solo sale si NO es la última faceta)
if (!isSingleRoofSection && !isLastFacet)
  Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ElevatedButton(
        onPressed: addNextFacet,
        child: const Text('Add Next Facet'),
      ),
    ],
  ),

// 🔵 2. Botones de Cierre (Solo salen si ES sección única o la última faceta)
// Al estar en un bloque independiente sin un Row padre, el Column se comportará perfectamente.
if (isSingleRoofSection || isLastFacet)
  Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Primer botón: Inspect Elevations (Si está activo)
      if (report.inspectElevations) ...[
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ElevationsInspectionScreen(
                  report: report,
                  isCommercial: false,
                ),
              ),
            );
          },
          child: const Text(
            'Inspect Elevations',
            style: TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 12), // Espaciado vertical entre ambos botones
      ],

      // Segundo botón: Submit Inspection
      ElevatedButton(
        onPressed: submitForm,
        child: const Text(
          'Submit Inspection',
          style: TextStyle(fontSize: 18),
        ),
      ),
    ],
  ),

const SizedBox(height: 40),
      ],
    );
  }
}
