import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:claimscope_clean/inspection_report_model.dart';
import 'package:claimscope_clean/utils/photo_labels.dart'; // Paso 4.5b

import 'models/elevations_data.dart';
import 'widgets/section_status_dot.dart';

/// Paso 4 — Sección 3 (Siding) + Add Trim cards, dentro del archivo del hub
/// por elevación. Centralizada como sub-widgets/métodos privados (Premisa Base).
///
/// Solo se implementan los campos que aparecen literalmente en el diseño
/// (`Pantalla Elevations.docx`). Si un campo, opción o condicional no aparece
/// en el diseño, NO se implementa.
class BuildingElevationsSection extends StatefulWidget {
  final BuildingElevation elevation;
  final InspectionReport report;
  final VoidCallback onChange;

  const BuildingElevationsSection({
    super.key,
    required this.elevation,
    required this.report,
    required this.onChange,
  });

  @override
  State<BuildingElevationsSection> createState() =>
      _BuildingElevationsSectionState();
}

class _BuildingElevationsSectionState extends State<BuildingElevationsSection> {
  // ─── Controllers de Siding (TextFields) ───────────────────────────────
  late final TextEditingController _steelSidingGauge;
  late final TextEditingController _sidingHeight;
  late final TextEditingController _panelInsulation;
  late final TextEditingController _howManySf;
  late final TextEditingController _stuccoSmallRepairSf;
  late final TextEditingController _stuccoCrackRepairLf;
  late final TextEditingController _stuccoFogCoatSf;
  late final TextEditingController _stuccoRedashSf;
  late final TextEditingController _stuccoWholeReplacementCoats;
  late final TextEditingController _sidingNotes;
  late final TextEditingController _underlaymentNotes;
  late final TextEditingController _substrateHowManySf;
  late final TextEditingController _substrateNotes;
  late final TextEditingController _eifsPartialRepairSf;
  late final TextEditingController _eifsNotes;

  // ─── Controllers por Trim (gestionados por id de instancia) ───────────
  final Map<TrimEntry, _TrimControllers> _trimCtl = {};

  // ─── Controllers por Window (gestionados por id de instancia) ─────────
  final Map<WindowEntry, _WindowControllers> _windowCtl = {};

  // ─── Controllers por Door (gestionados por id de instancia) ───────────
  final Map<DoorEntry, _DoorControllers> _doorCtl = {};

  // ─── Controllers por Accessory (gestionados por id de instancia) ──────
  final Map<AccessoryEntry, _AccessoryControllers> _accessoryCtl = {};

  final _picker = ImagePicker();
  bool _sidingPhotoReminderDismissed = false;
  bool _sidingPhotoReminderShowing = false;
  
  SidingDamagesData get _s => widget.elevation.siding;
  UnderlaymentInsulationData get _u => widget.elevation.underlayment;
  SubstrateData get _sub => widget.elevation.substrate;
  EifsData get _eifs => widget.elevation.eifs;
  List<TrimEntry> get _trims => widget.elevation.trims;
  List<WindowEntry> get _windows => widget.elevation.windows;
  List<DoorEntry> get _doors => widget.elevation.doors;
  List<AccessoryEntry> get _accessories => widget.elevation.accessories;

  @override
  void initState() {
    super.initState();
    _steelSidingGauge = TextEditingController(text: _s.steelSidingGauge);
    _sidingHeight = TextEditingController(text: _s.sidingHeight);
    _panelInsulation = TextEditingController(text: _s.panelInsulation);
    _howManySf = TextEditingController(text: _s.howManySf);
    _stuccoSmallRepairSf = TextEditingController(text: _s.stuccoSmallRepairSf);
    _stuccoCrackRepairLf = TextEditingController(text: _s.stuccoCrackRepairLf);
    _stuccoFogCoatSf = TextEditingController(text: _s.stuccoFogCoatSf);
    _stuccoRedashSf = TextEditingController(text: _s.stuccoRedashSf);
    _stuccoWholeReplacementCoats =
        TextEditingController(text: _s.stuccoWholeReplacementCoats);
    _sidingNotes = TextEditingController(text: _s.additionalNotes);
    _underlaymentNotes =
        TextEditingController(text: _u.additionalNotes);
    _substrateHowManySf = TextEditingController(text: _sub.howManySf);
    _substrateNotes = TextEditingController(text: _sub.additionalNotes);
    _eifsPartialRepairSf = TextEditingController(text: _eifs.partialRepairSf);
    _eifsNotes = TextEditingController(text: _eifs.additionalNotes);
    _syncTrimControllers();
    _syncWindowControllers();
    _syncDoorControllers();
    _syncAccessoryControllers();
  }

  void _clearSiding() {
  _s.sidingMain = '';

  _s.vinylType = '';
  _s.aluminumType = '';
  _s.woodType = '';
  _s.woodMaterial = '';
  _s.woodMaterialOther = '';
  _s.woodHardboardSize = '';

  _s.fiberCementType = '';
  _s.fiberCementSize = '';

  _s.steelType = '';
  _s.steelSidingGauge = '';
  _s.steelInsulatedSize = '';
  _s.steelInsulatedSizeOther = '';

  _s.panelType = '';
  _s.panelCorrugatedGauge = '';
  _s.panelCorrugatedGalvanized = false;
  _s.panelRibbedGauge = '';
  _s.panelHasInsulation = false;
  _s.panelInsulation = '';

  _s.sidingHeight = '';
  _s.changeWholeElevation = false;
  _s.howManySf = '';

  _s.stuccoScope = '';
  _s.stuccoSmallRepairSf = '';
  _s.stuccoCrackRepairLf = '';
  _s.stuccoFogCoatEntireElev = false;
  _s.stuccoFogCoatSf = '';
  _s.stuccoRedashEntireElev = false;
  _s.stuccoRedashSf = '';
  _s.stuccoRedashTexture = '';
  _s.stuccoWholeReplacementCoats = '';
  _s.stuccoMoistureBarrier = false;
  _s.stuccoExpansionJoints = false;
  _s.stuccoFinalTextureFinish = '';
  _s.stuccoFinish = '';

  _s.additionalNotes = '';

  _steelSidingGauge.clear();
  _sidingHeight.clear();
  _panelInsulation.clear();
  _howManySf.clear();
  _stuccoSmallRepairSf.clear();
  _stuccoCrackRepairLf.clear();
  _stuccoFogCoatSf.clear();
  _stuccoRedashSf.clear();
  _stuccoWholeReplacementCoats.clear();
  _sidingNotes.clear();

  _mark();
}

  Future<void> _confirmClear({
  required String title,
  required VoidCallback onClear,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Clear $title?'),
      content: const Text(
        'This will remove all saved data in this section.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );

  if (ok == true) {
    setState(onClear);
  }
}

  @override
  void didUpdateWidget(covariant BuildingElevationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia la elevación (Front → Right, etc.) hay que repoblar
    // los controllers de Trim para los TrimEntry de la nueva elevación.
    if (oldWidget.elevation != widget.elevation) {
      _sidingPhotoReminderDismissed = false;
      _sidingPhotoReminderShowing = false;
      _underlaymentNotes.text = _u.additionalNotes;
      _substrateHowManySf.text = _sub.howManySf;
      _substrateNotes.text = _sub.additionalNotes;
      _eifsPartialRepairSf.text = _eifs.partialRepairSf;
      _eifsNotes.text = _eifs.additionalNotes;
      _syncTrimControllers();
      _syncWindowControllers();
      _syncDoorControllers();
      _syncAccessoryControllers();
    }
  }

  /// Garantiza que exista un `_TrimControllers` por cada `TrimEntry` actual
  /// y descarta los que ya no están presentes. Idempotente.
  void _syncTrimControllers() {
    for (final t in _trims) {
      _trimCtl.putIfAbsent(t, () => _TrimControllers.from(t));
    }
    final stale = _trimCtl.keys.where((k) => !_trims.contains(k)).toList();
    for (final k in stale) {
      _trimCtl.remove(k)?.dispose();
    }
  }

  /// Garantiza que exista un `_WindowControllers` por cada `WindowEntry` actual
  /// y descarta los que ya no están presentes. Idempotente.
  void _syncWindowControllers() {
    for (final w in _windows) {
      _windowCtl.putIfAbsent(w, () => _WindowControllers.from(w));
    }
    final stale = _windowCtl.keys.where((k) => !_windows.contains(k)).toList();
    for (final k in stale) {
      _windowCtl.remove(k)?.dispose();
    }
  }


  /// Garantiza que exista un `_DoorControllers` por cada `DoorEntry` actual
  /// y descarta los que ya no están presentes. Idempotente.
  void _syncDoorControllers() {
    for (final d in _doors) {
      _doorCtl.putIfAbsent(d, () => _DoorControllers.from(d));
    }
    _doorCtl.removeWhere((door, controllers) {
      final stale = !_doors.contains(door);
      if (stale) controllers.dispose();
      return stale;
    });
  }

  /// Garantiza que exista un `_AccessoryControllers` por cada
  /// `AccessoryEntry` actual y descarta los que ya no están presentes.
  void _syncAccessoryControllers() {
    for (final a in _accessories) {
      _accessoryCtl.putIfAbsent(a, () => _AccessoryControllers.from(a));
    }
    _accessoryCtl.removeWhere((accessory, controllers) {
      final stale = !_accessories.contains(accessory);
      if (stale) controllers.dispose();
      return stale;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _steelSidingGauge,
      _sidingHeight,
      _panelInsulation,
      _howManySf,
      _stuccoSmallRepairSf,
      _stuccoCrackRepairLf,
      _stuccoFogCoatSf,
      _stuccoRedashSf,
      _stuccoWholeReplacementCoats,
      _sidingNotes,
      _underlaymentNotes,
      _substrateHowManySf,
      _substrateNotes,
      _eifsPartialRepairSf,
      _eifsNotes,
    ]) {
      c.dispose();
    }
    for (final tc in _trimCtl.values) {
      tc.dispose();
    }
    for (final wc in _windowCtl.values) {
      wc.dispose();
    }
    for (final dc in _doorCtl.values) {
      dc.dispose();
    }
    for (final ac in _accessoryCtl.values) {
      ac.dispose();
    }
    super.dispose();
  }

  void _mark() => widget.onChange();

  // ─── Captura de fotos de Elevations (Paso 4.5a + 4.5b) ──────────────
  /// Devuelve el siguiente índice (1-based) para etiquetar la próxima foto
  /// de ESTA elevación y categoría, contando las ya almacenadas con el
  /// label estructurado `Elev=<side>|Cat=<category>|Label=Photo <N>`.
  int _nextElevationPhotoIndex(String category) {
    final prefix = 'Elev=${widget.elevation.side.display}|Cat=$category|';
    return widget.report.photoReportItems
            .where((p) => p.label.startsWith(prefix))
            .length +
        1;
  }

  /// Captura una foto desde la cámara y la registra en
  /// `report.photoReportItems` con label estructurado de Elevations:
  ///   `Elev=<side>|Cat=Siding|Label=Photo <N>`
  /// Sin thumbnail, sin estado local, sin persistencia adicional.
  Future<void> _addSidingPhoto() async {
   final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 75,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return;
    final n = _nextElevationPhotoIndex('Siding');
    // Paso 4.5b: label parseable para PDF Photos y ZIP etiquetado.
    widget.report.addPhoto(
      File(picked.path),
      buildElevationsPhotoLabel(
        elev: widget.elevation.side.display,
        category: 'Siding',
        label: 'Photo $n',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo Stored'),
        duration: Duration(seconds: 2),
      ),
    );
    _mark();
  }

  bool _hasSidingPhoto() {
    for (final item in widget.report.photoReportItems) {
      final parsed = tryParseElevationsPhotoLabel(item.label);
      if (parsed != null &&
          parsed.elev == widget.elevation.side.display &&
          parsed.category == 'Siding') {
        return true;
      }
    }
    return false;
  }

  void _maybeShowSidingPhotoReminder() {
    if (_sidingPhotoReminderDismissed || _sidingPhotoReminderShowing) return;
    if (!_s.hasAnyData || _hasSidingPhoto()) return;

    _sidingPhotoReminderDismissed = true;
    _sidingPhotoReminderShowing = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: const Text('Add siding damage photo'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      _sidingPhotoReminderShowing = false;
    });
  }

  Widget _withSidingPhotoReminder(Widget child) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _maybeShowSidingPhotoReminder(),
      child: child,
    );
  }

  // =====================================================================
  // BUILD
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Text(
          '${widget.elevation.side.display} elevation',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _buildSidingTile(),
        const SizedBox(height: 12),
        _withSidingPhotoReminder(_buildTrimSection()),
        const SizedBox(height: 8),
        _withSidingPhotoReminder(_buildUnderlaymentInsulationTile()),
        const SizedBox(height: 8),
        _withSidingPhotoReminder(_buildSubstrateTile()),
        const SizedBox(height: 8),
        _withSidingPhotoReminder(_buildEifsTile()),
        const SizedBox(height: 8),
        _withSidingPhotoReminder(_buildWindowSection()),
        const SizedBox(height: 8),
        _withSidingPhotoReminder(_buildDoorSection()),
        const SizedBox(height: 8),
        _withSidingPhotoReminder(_buildAccessorySection()),
      ],
    );
  }

    // =====================================================================
  // SECCIÓN 4 — UNDERLAYMENT & INSULATION
  // =====================================================================
  Widget _buildUnderlaymentInsulationTile() {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        controlAffinity: ListTileControlAffinity.trailing,
        leading: SectionStatusDot(status: _underlaymentStatus()),
        title: _sectionTitleWithClear(
          'Underlayment & Insulation',
          () => _confirmClear(
            title: 'Underlayment & Insulation',
            onClear: _clearUnderlayment,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: _buildUnderlaymentInsulationFields(),
      ),
    );
  }

  List<Widget> _buildUnderlaymentInsulationFields() {
    if (_s.sidingMain.isEmpty) {
      return const [
        Text('Select Siding Type first.'),
      ];
    }

    if (!_isUnderlaymentApplicableSiding(_s.sidingMain)) {
      return const [
        Text('Underlayment & Insulation does not apply to this Siding Type.'),
      ];
    }

    return [
      if (_s.sidingMain == 'Wall/roof panel') ...[
        _checkbox('Is there insulation?', _s.panelHasInsulation, (v) {
          setState(() {
            _s.panelHasInsulation = v;
            if (!v) {
              _s.panelInsulation = '';
              _panelInsulation.clear();
            }
            _mark();
          });
        }),
        if (_s.panelHasInsulation) ...[
          const SizedBox(height: 8),
          _textField(
            controller: _panelInsulation,
            label: 'Insulation',
            onChanged: (v) {
              _s.panelInsulation = v;
              _mark();
            },
          ),
        ],
      ],
      if (_showsFanfoldInsulation(_s.sidingMain)) ...[
        _checkbox('Add Fanfold Insulation', _u.addFanfoldInsulation, (v) {
          setState(() {
            _u.addFanfoldInsulation = v;
            if (!v) _u.fanfoldThickness = '';
            _mark();
          });
        }),
        if (_u.addFanfoldInsulation) ...[
          const SizedBox(height: 8),
          _dropdown(
            label: 'Thickness',
            value: _u.fanfoldThickness,
            options: const ['1/4"', '1/2"'],
            onChanged: (v) => setState(() {
              _u.fanfoldThickness = v ?? '';
              _mark();
            }),
          ),
        ],
      ],
      if (_isVeneerSiding(_s.sidingMain))
        _checkbox(
          'Add Foil Insulation / Radiant Barrier',
          _u.addFoilInsulationRadiantBarrier,
          (v) {
            setState(() {
              _u.addFoilInsulationRadiantBarrier = v;
              _mark();
            });
          },
        ),
      if (_showsHouseWrap(_s.sidingMain))
        _checkbox('Add House Wrap (WRB)', _u.addHouseWrapWrb, (v) {
          setState(() {
            _u.addHouseWrapWrb = v;
            _mark();
          });
        }),
      _checkbox(
        'Use Rainscreen/Furring Strips',
        _u.useRainscreenFurringStrips,
        (v) {
          setState(() {
            _u.useRainscreenFurringStrips = v;
            if (!v && !_isVeneerSiding(_s.sidingMain)) {
              _u.addFoilInsulationRadiantBarrier = false;
            }
            _mark();
          });
        },
      ),
      if (!_isVeneerSiding(_s.sidingMain) && _showsFoilInsulation(_s.sidingMain))
        _checkbox(
          'Add Foil Insulation / Radiant Barrier',
          _u.addFoilInsulationRadiantBarrier,
          (v) {
            setState(() {
              _u.addFoilInsulationRadiantBarrier = v;
              _mark();
            });
          },
        ),
      const SizedBox(height: 8),
      _notesField(_underlaymentNotes, (v) {
        _u.additionalNotes = v;
        _mark();
      }),
    ];
  }

  void _clearUnderlayment() {
    _u.addFanfoldInsulation = false;
    _u.fanfoldThickness = '';
    _u.addHouseWrapWrb = false;
    _u.addFoilInsulationRadiantBarrier = false;
    _u.useRainscreenFurringStrips = false;
    _u.additionalNotes = '';
    _s.panelHasInsulation = false;
    _s.panelInsulation = '';
    _panelInsulation.clear();
    _underlaymentNotes.clear();
    _mark();
  }

  SectionStatus _underlaymentStatus() {
    final panelInsulationHasData =
        _s.sidingMain == 'Wall/roof panel' &&
        (_s.panelHasInsulation || _s.panelInsulation.trim().isNotEmpty);

    if (!_u.hasAnyData && !panelInsulationHasData) return SectionStatus.empty;
    if (_s.sidingMain.isEmpty || !_isUnderlaymentApplicableSiding(_s.sidingMain)) {
      return SectionStatus.partial;
    }
    if (_u.addFanfoldInsulation && _u.fanfoldThickness.isEmpty) {
      return SectionStatus.partial;
    }
    if (_s.panelHasInsulation && _s.panelInsulation.trim().isEmpty) {
      return SectionStatus.partial;
    }
    return SectionStatus.complete;
  }

  bool _isUnderlaymentApplicableSiding(String siding) {
    return siding != 'Stucco';
  }

  bool _showsFanfoldInsulation(String siding) {
    return siding == 'Vinyl' || siding == 'Aluminum';
  }

  bool _showsHouseWrap(String siding) {
    return siding == 'Vinyl' ||
        siding == 'Aluminum' ||
        siding == 'Fiber-Cement' ||
        siding == 'Wood' ||
        siding == 'Steel' ||
        _isVeneerSiding(siding);
  }

  bool _showsFoilInsulation(String siding) {
    return _isVeneerSiding(siding) || _u.useRainscreenFurringStrips;
  }

  bool _isVeneerSiding(String siding) {
    return siding == 'Brick Veneer' ||
        siding == 'Stone Veneer' ||
        siding == 'Tone Veneer';
  }

  // =====================================================================
  // SECCIÓN 5 — SUBSTRATE
  // =====================================================================
  Widget _buildSubstrateTile() {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        controlAffinity: ListTileControlAffinity.trailing,
        leading: SectionStatusDot(status: _substrateStatus()),
        title: _sectionTitleWithClear(
          'Substrate',
          () => _confirmClear(
            title: 'Substrate',
            onClear: _clearSubstrate,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: _buildSubstrateFields(),
      ),
    );
  }

  List<Widget> _buildSubstrateFields() {
    return [
      _checkbox(
        'Substrate Repair / Replacement Needed?',
        _sub.substrateRepairReplacementNeeded,
        (v) {
          setState(() {
            _sub.substrateRepairReplacementNeeded = v;
            if (!v) {
              _sub.substrateMaterialType = '';
              _sub.substrateThickness = '';
              _sub.entireElevation = false;
              _sub.howManySf = '';
              _substrateHowManySf.clear();
            }
            _mark();
          });
        },
      ),
      if (_sub.substrateRepairReplacementNeeded) ...[
        const SizedBox(height: 8),
        _dropdown(
          label: 'Substrate Material Type',
          value: _sub.substrateMaterialType,
          options: const ['OSB Sheathing', 'Plywood Sheathing'],
          onChanged: (v) => setState(() {
            _sub.substrateMaterialType = v ?? '';
            _mark();
          }),
        ),
        const SizedBox(height: 8),
        _dropdown(
          label: 'Substrate Thickness',
          value: _sub.substrateThickness,
          options: const ['1/2"', '5/8"'],
          onChanged: (v) => setState(() {
            _sub.substrateThickness = v ?? '';
            _mark();
          }),
        ),
        const SizedBox(height: 12),
        const Text(
          'Replace Quantity:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        _checkbox('Entire elevation', _sub.entireElevation, (v) {
          setState(() {
            _sub.entireElevation = v;
            if (v) {
              _sub.howManySf = '';
              _substrateHowManySf.clear();
            }
            _mark();
          });
        }),
        if (!_sub.entireElevation)
          _qtyField(
            controller: _substrateHowManySf,
            hint: 'How many SF',
            unit: 'SF',
            hintText:
                'Enter the estimated Area in SF or number of 4x8 sheets to replace',
            onChanged: (v) {
              _sub.howManySf = v;
              _mark();
            },
          ),
      ],
      const SizedBox(height: 8),
      _notesField(_substrateNotes, (v) {
        _sub.additionalNotes = v;
        _mark();
      }),
    ];
  }

  void _clearSubstrate() {
    _sub.substrateRepairReplacementNeeded = false;
    _sub.substrateMaterialType = '';
    _sub.substrateThickness = '';
    _sub.entireElevation = false;
    _sub.howManySf = '';
    _sub.additionalNotes = '';
    _substrateHowManySf.clear();
    _substrateNotes.clear();
    _mark();
  }

  SectionStatus _substrateStatus() {
    if (!_sub.hasAnyData) return SectionStatus.empty;
    if (!_sub.substrateRepairReplacementNeeded) {
      return SectionStatus.complete;
    }
    final quantityOk = _sub.entireElevation || _sub.howManySf.trim().isNotEmpty;
    return _sub.substrateMaterialType.isNotEmpty &&
            _sub.substrateThickness.isNotEmpty &&
            quantityOk
        ? SectionStatus.complete
        : SectionStatus.partial;
  }

  // =====================================================================
  // EIFS — EXTERNAL INSULATION FINISHING SYSTEM
  // =====================================================================
  Widget _buildEifsTile() {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        controlAffinity: ListTileControlAffinity.trailing,
        leading: SectionStatusDot(status: _eifsStatus()),
        title: _sectionTitleWithClear(
          'EIFS / External Insulation Finishing System',
          () => _confirmClear(
            title: 'EIFS / External Insulation Finishing System',
            onClear: _clearEifs,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: _buildEifsFields(),
      ),
    );
  }

  List<Widget> _buildEifsFields() {
    return [
      _checkbox(
        'EIFS / External Insulation Finishing System',
        _eifs.present,
        (v) {
          setState(() {
            _eifs.present = v;
            if (!v) {
              _clearEifsData(keepPresent: false);
            }
            _mark();
          });
        },
      ),
      if (_eifs.present) ...[
        const SizedBox(height: 8),
        _checkbox('Whole elevation', _eifs.wholeReplacement, (v) {
          setState(() {
            _eifs.wholeReplacement = v;
            if (v) {
              _eifs.partialRepair = false;
              _eifs.partialRepairSf = '';
              _eifsPartialRepairSf.clear();
            }
            _mark();
          });
        }),
        _checkbox('Partial Repair', _eifs.partialRepair, (v) {
          setState(() {
            _eifs.partialRepair = v;
            if (v) {
              _eifs.wholeReplacement = false;
            } else {
              _eifs.partialRepairSf = '';
              _eifsPartialRepairSf.clear();
            }
            _mark();
          });
        }),
        if (_eifs.partialRepair) ...[
          const SizedBox(height: 4),
          _qtyField(
            controller: _eifsPartialRepairSf,
            hint: 'How many SF',
            unit: 'SF',
            onChanged: (v) {
              _eifs.partialRepairSf = v;
              _mark();
            },
          ),
        ],
        const SizedBox(height: 8),
        _dropdown(
          label: 'Substrate',
          value: _eifs.substrate,
          options: const ['OSB', 'Plywood', 'CMU'],
          onChanged: (v) => setState(() {
            _eifs.substrate = v ?? '';
            if (!_eifsSubstrateCanRequireReplacement(_eifs.substrate)) {
              _eifs.substrateRequiresReplacement = null;
            }
            _mark();
          }),
        ),
        if (_eifsSubstrateCanRequireReplacement(_eifs.substrate)) ...[
          const SizedBox(height: 8),
          _dropdown(
            label: 'Requires to be replaced?',
            value: _eifs.substrateRequiresReplacement == null
                ? ''
                : (_eifs.substrateRequiresReplacement! ? 'Yes' : 'No'),
            options: const ['Yes', 'No'],
            onChanged: (v) => setState(() {
              _eifs.substrateRequiresReplacement = v == 'Yes';
              _mark();
            }),
          ),
        ],
        const SizedBox(height: 8),
        _dropdown(
          label: 'Final Texture Finish',
          value: _eifs.finalTextureFinish,
          options: const ['Smooth/Flat', 'Sand float', 'Fine Sand', 'Medium/Coarse'],
          onChanged: (v) => setState(() {
            _eifs.finalTextureFinish = v ?? '';
            _mark();
          }),
        ),
        const SizedBox(height: 8),
        _dropdown(
          label: 'Finish',
          value: _eifs.finish,
          options: const ['Painted', 'natural gray'],
          onChanged: (v) => setState(() {
            _eifs.finish = v ?? '';
            _mark();
          }),
        ),
        const SizedBox(height: 8),
        _notesField(_eifsNotes, (v) {
          _eifs.additionalNotes = v;
          _mark();
        }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: () => _pickEifsPhoto(extra: false),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Take Photo'),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _pickEifsPhoto(extra: true),
            child: const Text('Add extra photo'),
          ),
        ),
        if (_eifs.photo != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Image.file(_eifs.photo!, height: 100, cacheWidth: 300),
          ),
      ],
    ];
  }

  Future<void> _pickEifsPhoto({required bool extra}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 75,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final n = _nextElevationPhotoIndex('EIFS');

    widget.report.addPhoto(
      file,
      buildElevationsPhotoLabel(
        elev: widget.elevation.side.display,
        category: 'EIFS',
        label: 'Photo $n',
      ),
    );

    setState(() {
      if (extra) {
        _eifs.extraPhoto = file;
      } else {
        _eifs.photo = file;
      }
      _mark();
    });

    if (extra && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo stored'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearEifs() {
    _clearEifsData(keepPresent: false);
    _mark();
  }

  void _clearEifsData({required bool keepPresent}) {
    _eifs.present = keepPresent ? _eifs.present : false;
    _eifs.wholeReplacement = false;
    _eifs.partialRepair = false;
    _eifs.partialRepairSf = '';
    _eifs.substrate = '';
    _eifs.substrateRequiresReplacement = null;
    _eifs.finalTextureFinish = '';
    _eifs.finish = '';
    _eifs.additionalNotes = '';
    _eifs.photo = null;
    _eifs.extraPhoto = null;
    _eifsPartialRepairSf.clear();
    _eifsNotes.clear();
  }

  SectionStatus _eifsStatus() {
    if (!_eifs.hasAnyData) return SectionStatus.empty;
    if (!_eifs.present) return SectionStatus.partial;

    final scopeOk = _eifs.wholeReplacement ||
        (_eifs.partialRepair && _eifs.partialRepairSf.trim().isNotEmpty);
    final substrateOk = _eifs.substrate.isNotEmpty &&
        (!_eifsSubstrateCanRequireReplacement(_eifs.substrate) ||
            _eifs.substrateRequiresReplacement != null);

    return scopeOk &&
             substrateOk &&
            _eifs.finalTextureFinish.isNotEmpty &&
            _eifs.finish.isNotEmpty
        ? SectionStatus.complete
        : SectionStatus.partial;
  }

  bool _eifsSubstrateCanRequireReplacement(String substrate) {
    return substrate == 'OSB' || substrate == 'Plywood';
  }

  // =====================================================================
  // SECCIÓN 3 — SIDING
  // =====================================================================
  Widget _buildSidingTile() {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
          controlAffinity: ListTileControlAffinity.trailing,
        leading: SectionStatusDot(status: _sidingStatus()),
        title: _sectionTitleWithClear(
        'Siding',
         () => _confirmClear(
         title: 'Siding',
         onClear: _clearSiding,
         ),
         ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: [
          _dropdown(
            label: 'Siding Type',
            value: _s.sidingMain,
            options: const [
              'Vinyl',
              'Aluminum',
              'Wood',
              'Fiber-Cement',
              'Steel',
              'Wall/roof panel',
              'Stucco',
              'Brick Veneer',
              'Tone Veneer',
            ],
            onChanged: (v) => setState(() {
              _s.sidingMain = v ?? '';
              if (_s.sidingMain != 'Wall/roof panel') {
                _s.panelHasInsulation = false;
                _s.panelInsulation = '';
                _panelInsulation.clear();
              }
              _mark();
            }),
          ),
          const SizedBox(height: 8),
          ..._buildSidingBranch(),
          if (_s.sidingMain == 'Steel') ...[
            const SizedBox(height: 8),
            _textField(
              controller: _steelSidingGauge,
              label: 'Steel Siding Gauge',
              onChanged: (v) {
                _s.steelSidingGauge = v;
                _mark();
              },
            ),
          ],
if (_showsSidingHeight()) ...[
  const SizedBox(height: 8),
  _textField(
    controller: _sidingHeight,
    label: 'Siding Height',
    hintText: 'Write the height of a single piece',
    onChanged: (v) {
      _s.sidingHeight = v;
      _mark();
    },
  ),
],
          if (_s.sidingMain.isNotEmpty && _s.sidingMain != 'Stucco') ...[
            const SizedBox(height: 12),
            const Text('Scope of Work',
                style: TextStyle(fontWeight: FontWeight.w500)),
            _checkbox(
              'Change whole elevation Siding',
              _s.changeWholeElevation,
              (v) {
                setState(() {
                  _s.changeWholeElevation = v;
                  if (v) {
                    _s.howManySf = '';
                    _howManySf.clear();
                  }
                  _mark();
                });
              },
            ),
            if (!_s.changeWholeElevation) ...[
              const SizedBox(height: 4),
              _qtyField(
                controller: _howManySf,
                hint: 'How many SF',
                unit: 'SF',
                onChanged: (v) {
                  _s.howManySf = v;
                  _mark();
                },
              ),
            ],
          ],
          if (_s.sidingMain == 'Stucco') ..._buildStuccoScope(),
          const SizedBox(height: 16),
          _notesField(_sidingNotes, (v) {
            _s.additionalNotes = v;
            _mark();
          }),
                    const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addSidingPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add Siding Photos'),
            ),
          ),
        ],
      ),
    );
  }

  bool _showsSidingHeight() {
    if (_s.sidingMain == 'Vinyl' || _s.sidingMain == 'Aluminum') return true;
    if (_s.sidingMain == 'Wood' && _s.woodType != 'Hardboard') return true;
    return false;
  }

  List<Widget> _buildSidingBranch() {
    switch (_s.sidingMain) {
      case 'Vinyl':
        return [
          _dropdown(
            label: 'Vinyl Type',
            value: _s.vinylType,
            options: const [
              'Seamless',
              'Average',
              'High grade',
              'Premium grade',
              'Specialty grade single color',
              'Specialty grade two tone',
              'Insulated',
            ],
            onChanged: (v) => setState(() {
              _s.vinylType = v ?? '';
              _mark();
            }),
          ),
        ];
      case 'Aluminum':
        return [
          _dropdown(
            label: 'Aluminum Type',
            value: _s.aluminumType,
            options: const [
              'Standard .019',
              'Premium .024',
              'Seamless 0.020',
            ],
            onChanged: (v) => setState(() {
              _s.aluminumType = v ?? '';
              _mark();
            }),
          ),
        ];
      case 'Wood':
        return [
          _dropdown(
            label: 'Wood Type',
            value: _s.woodType,
            options: const [
              'Clapboard/Lap',
              'Shiplap',
              'Board & Batten',
              'Tongue & Groove',
              'Shingles/Shakes',
              'Hardboard',
            ],
            onChanged: (v) => setState(() {
              _s.woodType = v ?? '';
              if (_s.woodType != 'Hardboard') {
                _s.woodHardboardSize = '';
              } else {
                _s.woodMaterial = '';
              }
              _mark();
            }),
          ),
          if (_s.woodType == 'Hardboard') ...[
            const SizedBox(height: 8),
            _dropdown(
              label: 'Size',
              value: _s.woodHardboardSize,
              options: const ['6"', '8"', '12"'],
              onChanged: (v) => setState(() {
                _s.woodHardboardSize = v ?? '';
                _mark();
              }),
            ),
          ],
          if (_s.woodType.isNotEmpty && _s.woodType != 'Hardboard') ...[
            const SizedBox(height: 8),
            _dropdown(
              label: 'Material',
              value: _s.woodMaterial,
              options: const ['Pine or equal', 'Redwood', 'Cedar', 'Other'],
              onChanged: (v) => setState(() {
                _s.woodMaterial = v ?? '';
                _mark();
              }),
            ),
            if (_s.woodMaterial == 'Other') ...[
              const SizedBox(height: 6),
              TextField(
                controller:
                    TextEditingController(text: _s.woodMaterialOther),
                decoration: const InputDecoration(
                  labelText: 'Material (Specify)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  _s.woodMaterialOther = v;
                  _mark();
                },
              ),
            ],
          ],
        ];
      case 'Fiber-Cement':
        return [
          _dropdown(
            label: 'Fiber Cement Type',
            value: _s.fiberCementType,
            options: const [
              'Clapboard/Lap',
              'Shingles or shakes type panel',
              'Vertical sheet',
            ],
            onChanged: (v) => setState(() {
              _s.fiberCementType = v ?? '';
              if (_s.fiberCementType != 'Clapboard/Lap') {
                _s.fiberCementSize = '';
              }
              _mark();
            }),
          ),
          if (_s.fiberCementType == 'Clapboard/Lap') ...[
            const SizedBox(height: 8),
            _dropdown(
              label: 'Size',
              value: _s.fiberCementSize,
              options: const ['6"', '8"', '12"'],
              onChanged: (v) => setState(() {
                _s.fiberCementSize = v ?? '';
                _mark();
              }),
            ),
          ],
        ];
      case 'Steel':
        return [
          _dropdown(
            label: 'Steel Type',
            value: _s.steelType,
            options: const [
              'Seamless',
              'Metal wall panel',
              'Commercial high grade',
              'Insulated Metal Panel',
            ],
            onChanged: (v) => setState(() {
              _s.steelType = v ?? '';
              if (_s.steelType != 'Insulated Metal Panel') {
                _s.steelInsulatedSize = '';
                _s.steelInsulatedSizeOther = '';
              }
              _mark();
            }),
          ),
          if (_s.steelType == 'Insulated Metal Panel') ...[
            const SizedBox(height: 8),
            _dropdown(
              label: 'Size',
              value: _s.steelInsulatedSize,
              options: const ['2"', '1"', '1/2"', 'Other'],
              onChanged: (v) => setState(() {
                _s.steelInsulatedSize = v ?? '';
                _mark();
              }),
            ),
            if (_s.steelInsulatedSize == 'Other') ...[
              const SizedBox(height: 6),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Size (Specify)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                controller: TextEditingController(text: _s.steelInsulatedSizeOther),
                onChanged: (v) {
                  _s.steelInsulatedSizeOther = v;
                  _mark();
                },
              ),
            ],
          ],
        ];
      case 'Wall/roof panel':
        return [
          _dropdown(
            label: 'Panel Type',
            value: _s.panelType,
            options: const ['Ribbed', 'Corrugated'],
            onChanged: (v) => setState(() {
              _s.panelType = v ?? '';
              if (_s.panelType != 'Corrugated') {
                _s.panelCorrugatedGauge = '';
                _s.panelCorrugatedGalvanized = false;
              }
              if (_s.panelType != 'Ribbed') {
                _s.panelRibbedGauge = '';
              }
              _mark();
            }),
          ),
          if (_s.panelType == 'Corrugated') ...[
            const SizedBox(height: 8),
            _dropdown(
              label: 'Gauge',
              value: _s.panelCorrugatedGauge,
              options: const ['24', '26', '29'],
              onChanged: (v) => setState(() {
                _s.panelCorrugatedGauge = v ?? '';
                _mark();
              }),
            ),
            _checkbox('Galvanized?', _s.panelCorrugatedGalvanized, (v) {
              setState(() {
                _s.panelCorrugatedGalvanized = v;
                _mark();
              });
            }),
          ],
          if (_s.panelType == 'Ribbed') ...[
            const SizedBox(height: 8),
            _dropdown(
              label: 'Gauge',
              value: _s.panelRibbedGauge,
              options: const [
                '24 gauge up to 1"',
                '26 gauge up to 1"',
                '29 gauge up to 1"',
                '24 gauge 1-1/8" to 1 1/2"',
                '26 gauge 1-1/8" to 1 1/2"',
              ],
              onChanged: (v) => setState(() {
                _s.panelRibbedGauge = v ?? '';
                _mark();
              }),
            ),
          ],
        ];
      case 'Stucco':
      case 'Brick Veneer':
      case 'Tone Veneer':
      default:
        return const [];
    }
  }

  List<Widget> _buildStuccoScope() {
    Widget radio(String value, String label, Widget? trailing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(label),
            value: value,
            // ignore: deprecated_member_use
            groupValue: _s.stuccoScope,
            // ignore: deprecated_member_use
            onChanged: (v) => setState(() {
              _s.stuccoScope = v ?? '';
              _mark();
            }),
          ),
          if (_s.stuccoScope == value && trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 8),
              child: trailing,
            ),
        ],
      );
    }

    return [
      const SizedBox(height: 12),
      const Text('Scope of Work',
          style: TextStyle(fontWeight: FontWeight.w500)),
      radio('Small repair', 'Small repair',
          _qtyField(
            controller: _stuccoSmallRepairSf,
            hint: 'How many SF',
            unit: 'SF',
            helper: 'Give an approximate SF of repairment',
            onChanged: (v) {
              _s.stuccoSmallRepairSf = v;
              _mark();
            },
          )),
      radio('Crack repair', 'Crack repair',
          _qtyField(
            controller: _stuccoCrackRepairLf,
            hint: 'How many LF',
            unit: 'LF',
            helper: 'Give an approximate LF of repairment',
            onChanged: (v) {
              _s.stuccoCrackRepairLf = v;
              _mark();
            },
          )),
      radio('Fog coat application', 'Fog coat application',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _checkbox('Entire elevation', _s.stuccoFogCoatEntireElev, (v) {
                setState(() {
                  _s.stuccoFogCoatEntireElev = v;
                  if (v) {
                    _s.stuccoFogCoatSf = '';
                    _stuccoFogCoatSf.clear();
                  }
                  _mark();
                });
              }),
              if (!_s.stuccoFogCoatEntireElev)
                _qtyField(
                  controller: _stuccoFogCoatSf,
                  hint: 'How many SF',
                  unit: 'SF',
                  onChanged: (v) {
                    _s.stuccoFogCoatSf = v;
                    _mark();
                  },
                ),
            ],
          )),
      radio('Redash', 'Redash',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _checkbox('Entire elevation', _s.stuccoRedashEntireElev, (v) {
                setState(() {
                  _s.stuccoRedashEntireElev = v;
                  if (v) {
                    _s.stuccoRedashSf = '';
                    _stuccoRedashSf.clear();
                  }
                  _mark();
                });
              }),
              if (!_s.stuccoRedashEntireElev) ...[
                _qtyField(
                  controller: _stuccoRedashSf,
                  hint: 'How many SF',
                  unit: 'SF',
                  onChanged: (v) {
                    _s.stuccoRedashSf = v;
                    _mark();
                  },
                ),
                const SizedBox(height: 8),
                _dropdown(
                  label: 'Texture',
                  value: _s.stuccoRedashTexture,
                  options: const ['Smooth/Flat', 'Fine Sand', 'Medium/Coarse'],
                  onChanged: (v) => setState(() {
                    _s.stuccoRedashTexture = v ?? '';
                    _mark();
                  }),
                ),
              ],
            ],
          )),
      radio('Whole replacement', 'Whole replacement',
          _textField(
            controller: _stuccoWholeReplacementCoats,
            label: 'How many coats',
            onChanged: (v) {
              _s.stuccoWholeReplacementCoats = v;
              _mark();
            },
          )),
      const SizedBox(height: 12),
      _checkbox('Moisture Barrier Required?', _s.stuccoMoistureBarrier, (v) {
        setState(() {
          _s.stuccoMoistureBarrier = v;
          _mark();
        });
      }),
      _checkbox('Expansion Joints?', _s.stuccoExpansionJoints, (v) {
        setState(() {
          _s.stuccoExpansionJoints = v;
          _mark();
        });
      }),
      const SizedBox(height: 8),
      _dropdown(
        label: 'Final Texture Finish',
        value: _s.stuccoFinalTextureFinish,
        options: const ['Smooth/Flat', 'Sand float', 'Fine Sand', 'Medium/Coarse'],
        onChanged: (v) => setState(() {
          _s.stuccoFinalTextureFinish = v ?? '';
          _mark();
        }),
      ),
      const SizedBox(height: 8),
      _dropdown(
        label: 'Finish',
        value: _s.stuccoFinish,
        options: const ['Painted', 'natural gray'],
        onChanged: (v) => setState(() {
          _s.stuccoFinish = v ?? '';
          _mark();
        }),
      ),
    ];
  }

  SectionStatus _sidingStatus() {
    if (!_s.hasAnyData) return SectionStatus.empty;
    if (_s.sidingMain.isEmpty) return SectionStatus.partial;
    bool branchOk = true;
    switch (_s.sidingMain) {
      case 'Vinyl':
        branchOk = _s.vinylType.isNotEmpty;
        break;
      case 'Aluminum':
        branchOk = _s.aluminumType.isNotEmpty;
        break;
      case 'Wood':
        branchOk = _s.woodType.isNotEmpty &&
            (_s.woodType == 'Hardboard'
                ? _s.woodHardboardSize.isNotEmpty
                : _s.woodMaterial.isNotEmpty);
        break;
      case 'Fiber-Cement':
        branchOk = _s.fiberCementType.isNotEmpty &&
            (_s.fiberCementType != 'Clapboard/Lap' ||
                _s.fiberCementSize.isNotEmpty);
        break;
      case 'Steel':
        branchOk = _s.steelType.isNotEmpty;
        break;
      case 'Wall/roof panel':
        branchOk = _s.panelType.isNotEmpty;
        break;
      case 'Stucco':
        branchOk = _s.stuccoScope.isNotEmpty;
        break;
    }
    if (_s.sidingMain != 'Stucco') {
      final scopeOk = _s.changeWholeElevation || _s.howManySf.isNotEmpty;
      return (branchOk && scopeOk)
          ? SectionStatus.complete
          : SectionStatus.partial;
    }
    return branchOk ? SectionStatus.complete : SectionStatus.partial;
  }

  // =====================================================================
  // ADD TRIM — patrón visual idéntico al "Add Flashing / Add Vents"
  // de `residential_facet_inspection_hub.dart` (ZIP 8).
  //   - Título de sección bold (fontSize 18, color black) + Divider
  //   - Cada item en Card(margin vertical 8) + Padding all 16
  //   - Header: Row(spaceBetween) con Text bold "Trim N" + IconButton
  //     (Icons.delete, color red)
  //   - ElevatedButton('Add Trim') al final
  //   - ElevatedButton("Take Trim Photo") + TextButton('Add extra Trim photo')
  //   - Image.file preview height: 100
  // =====================================================================
  Widget _buildTrimSection() {
    return Column(
            children: [
        const SizedBox(height: 8),
        const Text(
          'Trim',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Divider(),
        ..._trims.asMap().entries.map((entry) {
          final idx = entry.key;
          return _buildTrimCard(idx);
        }),
        ElevatedButton(
          onPressed: () => setState(_addTrimRaw),
          child: const Text('Add Trim'),
        ),
      ],
    );
  }

  void _addTrimRaw() {
    final t = TrimEntry();
    _trims.add(t);
    _trimCtl[t] = _TrimControllers.from(t);
    _mark();
  }

  void _removeTrim(int i) {
    setState(() {
      final t = _trims.removeAt(i);
      _trimCtl.remove(t)?.dispose();
      _mark();
    });
  }

  Widget _buildTrimCard(int i) {
    final t = _trims[i];
    // Lazy-init defensivo: si por cualquier motivo (cambio de elevación,
    // deserialización, hot reload) no existe controller para este TrimEntry,
    // se crea sobre la marcha. Evita el `_trimCtl[t]!` crash.
    final c = _trimCtl.putIfAbsent(t, () => _TrimControllers.from(t));

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
                  'Trim ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeTrim(i),
                ),
              ],
            ),
            _dropdown(
              label: 'Trim Type',
              value: t.trimType,
              options: const [
                'Outside corner post',
                'Inside corner post',
                'J-trim',
                'Siding trim',
                'Skirting',
                'Other',
              ],
              onChanged: (v) => setState(() {
                t.trimType = v ?? '';
                _mark();
              }),
            ),
            if (t.trimType == 'Other')
              TextFormField(
                controller: c.otherSpecify,
                decoration:
                    const InputDecoration(labelText: 'Specify Other Trim'),
                onChanged: (v) {
                  t.otherSpecify = v;
                  _mark();
                },
              ),
            const SizedBox(height: 8),
            _dropdown(
              label: 'Action',
              value: t.action,
              options: const ['Replace', 'D&R only'],
              onChanged: (v) => setState(() {
                t.action = v ?? '';
                _mark();
              }),
            ),
            if (t.action == 'Replace') ..._buildTrimReplaceFields(t, c),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _pickTrimPhoto(t, extra: false),
              child: const Text('Take Trim Photo'),
            ),
            TextButton(
              onPressed: () => _pickTrimPhoto(t, extra: true),
              child: const Text('Add extra Trim photo'),
            ),
            if (t.photo != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Image.file(t.photo!, height: 100, cacheWidth: 300),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTrimPhoto(TrimEntry t, {required bool extra}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 75,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final n = _nextElevationPhotoIndex('Trim');

    // Paso 4.5b: además del thumbnail local, registrar la foto
    // en el Photo PDF / ZIP con label estructurado de Elevations.
    widget.report.addPhoto(
      file,
      buildElevationsPhotoLabel(
        elev: widget.elevation.side.display,
        category: 'Trim',
        label: 'Photo $n',
      ),
    );

    setState(() {
      if (extra) {
        t.extraPhoto = file;
      } else {
        t.photo = file;
      }
      _mark();
    });

    
if (extra && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo stored'),
          duration: Duration(seconds: 2),
        ),
);
}
  }

  List<Widget> _buildTrimReplaceFields(TrimEntry t, _TrimControllers c) {
    switch (t.trimType) {
      case 'Outside corner post':
        return [
          const SizedBox(height: 8),
          _dropdown(
            label: 'Material',
            value: t.ocpMaterial,
            options: const ['Vinyl', 'Metal', 'Hardwood'],
            onChanged: (v) => setState(() {
              t.ocpMaterial = v ?? '';
              if (t.ocpMaterial != 'Metal') t.ocpMetalGauge = '';
              if (t.ocpMaterial != 'Vinyl' && t.ocpMaterial != 'Metal') {
                t.ocpInsulated = false;
              }
              _mark();
            }),
          ),
          if (t.ocpMaterial == 'Vinyl' || t.ocpMaterial == 'Metal')
            _checkbox('Insulated?', t.ocpInsulated, (v) {
              setState(() {
                t.ocpInsulated = v;
                _mark();
              });
            }),
          if (t.ocpMaterial == 'Metal') ...[
            const SizedBox(height: 8),
            _textField(
              controller: c.ocpMetalGauge,
              label: 'Gauge',
              helper: 'Specify gauge if known',
              onChanged: (v) {
                t.ocpMetalGauge = v;
                _mark();
              },
            ),
          ],
        ];
      case 'Inside corner post':
        return const [];
      case 'J-trim':
        return [
          const SizedBox(height: 8),
          _dropdown(
            label: 'Material',
            value: t.jTrimMaterial,
            options: const ['Vinyl', 'Metal'],
            onChanged: (v) => setState(() {
              t.jTrimMaterial = v ?? '';
              _mark();
            }),
          ),
        ];
      case 'Siding trim':
        return [
          const SizedBox(height: 8),
          _dropdown(
            label: 'Material',
            value: t.sidingTrimMaterial,
            options: const ['Hardboard', 'PVC', 'Wood'],
            onChanged: (v) => setState(() {
              t.sidingTrimMaterial = v ?? '';
              _mark();
            }),
          ),
          const SizedBox(height: 8),
          _textField(
            controller: c.sidingTrimSize,
            label: 'Size',
            helper: 'Specify trim dimensions',
            onChanged: (v) {
              t.sidingTrimSize = v;
              _mark();
            },
          ),
        ];
      case 'Skirting':
        return [
          const SizedBox(height: 8),
          _dropdown(
            label: 'Material',
            value: t.skirtingMaterial,
            options: const ['Vinyl/Plastic', 'Metal'],
            onChanged: (v) => setState(() {
              t.skirtingMaterial = v ?? '';
              _mark();
            }),
          ),
          const SizedBox(height: 8),
          _dropdown(
            label: 'Size',
            value: t.skirtingSize,
            options: const ['24" to 36"', '37" to 48"'],
            onChanged: (v) => setState(() {
              t.skirtingSize = v ?? '';
              _mark();
            }),
          ),
        ];
      default:
        return const [];
    }
  }

  // =====================================================================
  // ADD WINDOW — patrón visual idéntico al módulo Trim
  // =====================================================================
  Widget _buildWindowSection() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Windows',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Divider(),
        ..._windows.asMap().entries.map((entry) {
          final idx = entry.key;
          return _buildWindowCard(idx);
        }),
        ElevatedButton(
          onPressed: () => setState(_addWindowRaw),
          child: const Text('Add Window'),
        ),
      ],
    );
  }

  void _addWindowRaw() {
    final w = WindowEntry();
    _windows.add(w);
    _windowCtl[w] = _WindowControllers.from(w);
    _mark();
  }

  void _removeWindow(int i) {
    setState(() {
      final w = _windows.removeAt(i);
      _windowCtl.remove(w)?.dispose();
      _mark();
    });
  }

  Widget _buildWindowCard(int i) {
    final w = _windows[i];
    final c = _windowCtl.putIfAbsent(w, () => _WindowControllers.from(w));

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
                  'Window ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeWindow(i),
                ),
              ],
            ),
            _dropdown(
              label: 'Window Type',
              value: w.windowType,
              options: const [
                'Picture',
                'Single Hung',
                'Double Hung',
                'Horizontal Sliding',
                'Casement',
                'Jalousie',
                'Awning type',
                'Storefront',
              ],
              onChanged: (v) => setState(() {
                w.windowType = v ?? '';
                if (w.windowType.isEmpty) {
                  _clearWindowMaterialDependentFields(w, c);
                }
                _mark();
              }),
            ),
            if (w.windowType.isNotEmpty) ...[
              const SizedBox(height: 8),
              _dropdown(
                label: 'Material Type',
                value: w.materialType,
                options: const [
                  'Vinyl',
                  'Aluminum Anodized frame',
                  'Wood',
                  'Bronce Anodized frame',
                ],
                onChanged: (v) => setState(() {
                  w.materialType = v ?? '';
                  if (w.materialType.isEmpty) {
                    _clearWindowMaterialDependentFields(w, c);
                  }
                  _mark();
                }),
              ),
            ],
            if (w.materialType.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Glass & Efficiency',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._buildWindowMultiSelect(
                selected: w.glassEfficiencySelections,
                options: const [
                  'Low-E Glass',
                  'Impact Resistant',
                  'Single pane',
                  'Double Pane',
                  'Triple Pane',
                ],
                onChanged: () => setState(_mark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Components & Accessories',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._buildWindowMultiSelect(
                selected: w.componentsSelections,
                options: const [
                  'Screen',
                  'Grid',
                  'Exterior Casing / Trim',
                  'Interior Casing / Trim',
                  'Other',
                ],
                onChanged: () => setState(() {
                  if (!w.componentsSelections.contains('Other')) {
                    w.componentOtherSpecify = '';
                    c.componentOtherSpecify.clear();
                  }
                  _mark();
                }),
              ),
              if (w.componentsSelections.contains('Other')) ...[
                const SizedBox(height: 8),
                _textField(
                  controller: c.componentOtherSpecify,
                  label: 'Specify',
                  onChanged: (v) {
                    w.componentOtherSpecify = v;
                    _mark();
                  },
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Window Dimensions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _textField(
                controller: c.widthInches,
                label: 'Width (Inches)',
                onChanged: (v) {
                  w.widthInches = v;
                  _mark();
                },
              ),
              const SizedBox(height: 8),
              _textField(
                controller: c.heightInches,
                label: 'Height (Inches)',
                onChanged: (v) {
                  w.heightInches = v;
                  _mark();
                },
              ),
              const SizedBox(height: 8),
              _textField(
                controller: c.quantity,
                label: 'Quantity',
                hintText: 'Qty of windows with these exact specs',
                onChanged: (v) {
                  w.quantity = v;
                  _mark();
                },
              ),
              const SizedBox(height: 8),
              _dropdown(
                label: 'Scope of work',
                value: w.scopeOfWork,
                options: const [
                  'Replace',
                  'Reglaze',
                  'Replace bead only',
                  'Replace Casing/Trim only',
                  'Remove & Reset',
                ],
                onChanged: (v) => setState(() {
                  w.scopeOfWork = v ?? '';
                  _mark();
                }),
              ),
              _checkbox(
                'It has Shutters installed?',
                w.hasShuttersInstalled,
                (v) {
                  setState(() {
                    w.hasShuttersInstalled = v;
                    if (!v) {
                      w.shuttersScopeOfWork = '';
                      w.shuttersMaterial = '';
                      w.shuttersSize = '';
                    }
                    _mark();
                  });
                },
              ),
              if (w.hasShuttersInstalled) ...[
                const SizedBox(height: 8),
                _dropdown(
                  label: 'Shutters Scope of work',
                  value: w.shuttersScopeOfWork,
                  options: const ['Replace', 'Detach & reset'],
                  onChanged: (v) => setState(() {
                    w.shuttersScopeOfWork = v ?? '';
                    if (w.shuttersScopeOfWork != 'Replace') {
                      w.shuttersMaterial = '';
                      w.shuttersSize = '';
                    }
                    _mark();
                  }),
                ),
                if (w.shuttersScopeOfWork == 'Replace') ...[
                  const SizedBox(height: 8),
                  _dropdown(
                    label: 'Shutters Material',
                    value: w.shuttersMaterial,
                    options: const ['Aluminum', 'Simulated-wood', 'Other'],
                    onChanged: (v) => setState(() {
                      w.shuttersMaterial = v ?? '';
                      _mark();
                    }),
                  ),
                  if (w.shuttersMaterial == 'Other') ...[
              const SizedBox(height: 8),
             _textField(
              controller: c.shuttersMaterialSpecify,
              label: 'Specify Shutters Material',
               onChanged: (v) {
                w.shuttersMaterialSpecify = v;
               _mark();
               },
              ),
            ],
                  const SizedBox(height: 8),
                  _dropdown(
                    label: 'Shutters Size',
                    value: w.shuttersSize,
                    options: const ['Average', 'Small', 'Large'],
                    onChanged: (v) => setState(() {
                      w.shuttersSize = v ?? '';
                      _mark();
                    }),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              _notesField(c.additionalNotes, (v) {
                w.additionalNotes = v;
                _mark();
              }),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _pickWindowPhoto(w, extra: false),
                child: const Text('Take Window Photo'),
              ),
              TextButton(
                onPressed: () => _pickWindowPhoto(w, extra: true),
                child: const Text('Add extra Window photo'),
              ),
              if (w.photo != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Image.file(w.photo!, height: 100, cacheWidth: 300),
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWindowMultiSelect({
    required List<String> selected,
    required List<String> options,
    required VoidCallback onChanged,
  }) {
    return options
        .map(
          (option) => _checkbox(option, selected.contains(option), (v) {
            if (v) {
              if (!selected.contains(option)) selected.add(option);
            } else {
              selected.remove(option);
            }
            onChanged();
          }),
        )
        .toList();
  }

  void _clearWindowMaterialDependentFields(
    WindowEntry w,
    _WindowControllers c,
  ) {
    w.materialType = '';
    w.glassEfficiencySelections.clear();
    w.componentsSelections.clear();
    w.componentOtherSpecify = '';
    w.widthInches = '';
    w.heightInches = '';
    w.quantity = '';
    w.scopeOfWork = '';
    w.hasShuttersInstalled = false;
    w.shuttersScopeOfWork = '';
    w.shuttersMaterial = '';
    w.shuttersSize = '';
    w.additionalNotes = '';
    c.componentOtherSpecify.clear();
    c.widthInches.clear();
    c.heightInches.clear();
    c.quantity.clear();
    c.additionalNotes.clear();
  }

  Future<void> _pickWindowPhoto(WindowEntry w, {required bool extra}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 75,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final n = _nextElevationPhotoIndex('Window');

    widget.report.addPhoto(
      file,
      buildElevationsPhotoLabel(
        elev: widget.elevation.side.display,
        category: 'Window',
        label: 'Photo $n',
      ),
    );

    setState(() {
      if (extra) {
        w.extraPhoto = file;
      } else {
        w.photo = file;
      }
      _mark();
    });

    if (extra && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo stored'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }



  // =====================================================================
  // ADD DOOR — patrón visual idéntico a Windows/Trim
  // =====================================================================
  Widget _buildDoorSection() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Doors',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Divider(),
        for (var i = 0; i < _doors.length; i++) _buildDoorCard(i),
        ElevatedButton(
          onPressed: () => setState(_addDoorRaw),
          child: const Text('Add Door'),
        ),
      ],
    );
  }

  void _addDoorRaw() {
    final d = DoorEntry();
    _doors.add(d);
    _doorCtl[d] = _DoorControllers.from(d);
    _mark();
  }

  void _removeDoor(int i) {
    final d = _doors.removeAt(i);
    _doorCtl.remove(d)?.dispose();
    setState(_mark);
  }


  Widget _buildDoorCard(int i) {
    final d = _doors[i];
    final c = _doorCtl.putIfAbsent(d, () => _DoorControllers.from(d));

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
                  'Door ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeDoor(i),
                ),
              ],
            ),
            _dropdown(
              label: 'Door / Type',
              value: d.doorType,
              options: const [
                'Sliding Patio Door',
                'Exterior Door / Entry Door',
                'Garage Door',
                'Storefront door',
                'Roll-up Door',
              ],
              onChanged: (v) => setState(() {
                d.doorType = v ?? '';
                _clearDoorTypeDependentFields(d, c);
                _mark();
              }),
            ),
            if (d.doorType == 'Sliding Patio Door') ..._buildSlidingPatioDoorFields(d, c),
            if (d.doorType == 'Exterior Door / Entry Door') ..._buildEntryDoorFields(d, c),
            if (d.doorType == 'Garage Door') ..._buildGarageDoorFields(d, c),
            if (d.doorType == 'Storefront door') ..._buildStorefrontDoorFields(d, c),
            if (d.doorType == 'Roll-up Door') ..._buildRollupDoorFields(d, c),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSlidingPatioDoorFields(
    DoorEntry d,
    _DoorControllers c,
  ) {
    return [
      const SizedBox(height: 8),
      _dropdown(
        label: 'Material',
        value: d.patioMaterial,
        options: const ['Vinyl', 'Aluminum', 'Wood', 'Fiberglass'],
        onChanged: (v) => setState(() {
          d.patioMaterial = v ?? '';
          if (d.patioMaterial != 'Aluminum') {
            d.patioAluminumFinish = '';
          }
          _mark();
        }),
      ),
      if (d.patioMaterial == 'Aluminum') ...[
        const SizedBox(height: 8),
        _dropdown(
          label: 'Aluminum Finish',
          value: d.patioAluminumFinish,
          options: const ['Anodized', 'White', 'Bronze'],
          onChanged: (v) => setState(() {
            d.patioAluminumFinish = v ?? '';
            _mark();
          }),
        ),
      ],
      const SizedBox(height: 8),
      _dropdown(
        label: 'Stile',
        value: d.patioStyle,
        options: const ['Average', 'High grade'],
        onChanged: (v) => setState(() {
          d.patioStyle = v ?? '';
          _mark();
        }),
      ),
      const SizedBox(height: 8),
      _dropdown(
        label: 'Size',
        value: d.patioSize,
        options: const [
          '5-0/6-8',
          '5-0/8-0',
          '6-0/6-8',
          '6-0/8-0',
          '8-0/6-8',
          '8-0/8-0',
          '10-0/6-8',
          '10-0/8-0',
          '12-0/6-8',
          '12-0/8-0',
        ],
        onChanged: (v) => setState(() {
          d.patioSize = v ?? '';
          _mark();
        }),
      ),
      const SizedBox(height: 8),
      _dropdown(
        label: 'Scope of work',
        value: d.patioScopeOfWork,
        options: const [
          'Replace',
          'D&R / Detach & Reset',
          'Replacement Glass Only',
        ],
        onChanged: (v) => setState(() {
          d.patioScopeOfWork = v ?? '';
          _mark();
        }),
      ),
      ..._buildDoorNotesAndPhotos(
        d: d,
        c: c,
        takePhotoLabel: 'Take Sliding Patio Door Photo',
        extraPhotoLabel: 'Add extra Sliding Patio Door photo',
      ),
    ];
  }

  List<Widget> _buildEntryDoorFields(
    DoorEntry d,
    _DoorControllers c,
  ) {
    final isStormDoor = d.entryDoorType == 'Storm Door';
    final isSingleExteriorDoor = d.entryDoorType == 'Single Exterior Door';

    return [
      const SizedBox(height: 8),
      _dropdown(
        label: 'Entry/Exterior Door',
        value: d.entryDoorType,
        options: const [
          'Single Exterior Door',
          'Double Exterior Door',
          'Storm Door',
        ],
        onChanged: (v) => setState(() {
          d.entryDoorType = v ?? '';
          if (d.entryDoorType == 'Storm Door') {
            d.isFrenchDoor = false;
            d.hasLite = false;
            d.liteType = '';
            d.liteScopeOfWork = '';
          }
          if (d.entryDoorType != 'Single Exterior Door') {
            d.hasScreen = false;
            d.screenScopeOfWork = '';
          }
          _mark();
        }),
      ),
      const SizedBox(height: 8),
      _dropdown(
        label: 'Material',
        value: d.entryMaterial,
        options: const ['Metal', 'Wood'],
        onChanged: (v) => setState(() {
          d.entryMaterial = v ?? '';
          _mark();
        }),
      ),
      const SizedBox(height: 8),
      _dropdown(
        label: 'Style',
        value: d.entryStyle,
        options: const ['High grade', 'Premium grade', 'Deluxe grade'],
        onChanged: (v) => setState(() {
          d.entryStyle = v ?? '';
          _mark();
        }),
      ),
      if (!isStormDoor)
        _checkbox('Is a French Door?', d.isFrenchDoor, (v) {
          setState(() {
            d.isFrenchDoor = v;
            _mark();
          });
        }),
      const SizedBox(height: 8),
      _dropdown(
        label: 'Scope of work',
        value: d.entryScopeOfWork,
        options: const [
          'Replace All',
          'Replace Slab only',
          'Frame & trim only',
          'Detach & Reset',
        ],
        onChanged: (v) => setState(() {
          d.entryScopeOfWork = v ?? '';
          _mark();
        }),
      ),
      if (!isStormDoor) ...[
        _checkbox('Has lite?', d.hasLite, (v) {
          setState(() {
            d.hasLite = v;
            if (!v) {
              d.liteType = '';
              d.liteScopeOfWork = '';
            }
            _mark();
          });
        }),
        if (d.hasLite) ...[
          const SizedBox(height: 8),
          _dropdown(
            label: 'Lite Type',
            value: d.liteType,
            options: const ['Side lite', 'Full lite', 'Half lite'],
            onChanged: (v) => setState(() {
              d.liteType = v ?? '';
              _mark();
            }),
          ),
          const SizedBox(height: 8),
          _dropdown(
            label: 'Lite Scope of work',
            value: d.liteScopeOfWork,
            options: const ['Replace', 'Detach & reset', 'No action required'],
            onChanged: (v) => setState(() {
              d.liteScopeOfWork = v ?? '';
              _mark();
            }),
          ),
        ],
      ],
      if (isSingleExteriorDoor) ...[
        _checkbox('Has Screen?', d.hasScreen, (v) {
          setState(() {
            d.hasScreen = v;
            if (!v) d.screenScopeOfWork = '';
            _mark();
          });
        }),
        if (d.hasScreen) ...[
          const SizedBox(height: 8),
          _dropdown(
            label: 'Screen Scope of work',
            value: d.screenScopeOfWork,
            options: const ['Replace', 'Detach & reset', 'No action required'],
            onChanged: (v) => setState(() {
              d.screenScopeOfWork = v ?? '';
              _mark();
            }),
          ),
        ],
      ],
      ..._buildDoorNotesAndPhotos(
        d: d,
        c: c,
        takePhotoLabel: 'Take Exterior Door Photo',
        extraPhotoLabel: 'Add extra Exterior Door photo',
      ),
    ];
  }

  List<Widget> _buildGarageDoorFields(
    DoorEntry d,
    _DoorControllers c,
  ) {
    return [
      const SizedBox(height: 8),
      _dropdown(
        label: 'Style',
        value: d.garageStyle,
        options: const [
          'Standard grade',
          'High grade',
          'Premium grade',
          'Deluxe grade',
        ],
        onChanged: (v) => setState(() {
          d.garageStyle = v ?? '';
          _mark();
        }),
      ),
      _checkbox('With Windows', d.garageWithWindows, (v) {
        setState(() {
          d.garageWithWindows = v;
          if (!v) {
            d.garageWindowsCount = '';
            c.garageWindowsCount.clear();
          }
          _mark();
        });
      }),
      if (d.garageWithWindows) ...[
        const SizedBox(height: 8),
        _textField(
          controller: c.garageWindowsCount,
          label: 'How many?',
          onChanged: (v) {
            d.garageWindowsCount = v;
            _mark();
          },
        ),
      ],
      const SizedBox(height: 8),
      _dropdown(
        label: 'Garage Door Size',
        value: d.garageDoorSize,
        options: const [
          '8x7',
          '8x8',
          '8x9',
          '8x10',
          '8x11',
          '8x12',
          '9x7',
          '9x8',
          '9x10',
          '9x11',
          '9x12',
          '10x7',
          '10x8',
          '10x9',
          '10x11',
          '10x12',
          '12x7',
          '12x8',
          '16x7',
          '16x8',
          '18x7',
          '18x8',
        ],
        onChanged: (v) => setState(() {
          d.garageDoorSize = v ?? '';
          _mark();
        }),
      ),
      const SizedBox(height: 8),
      _dropdown(
        label: 'Scope of work',
        value: d.garageScopeOfWork,
        options: const [
          'Replace',
          'Replace windows only',
          'Panel Only / Section Replacement',
          'Detach & Reset',
        ],
        onChanged: (v) => setState(() {
          d.garageScopeOfWork = v ?? '';
          if (d.garageScopeOfWork != 'Panel Only / Section Replacement') {
            d.garagePanelSectionCount = '';
            c.garagePanelSectionCount.clear();
          }
          _mark();
        }),
      ),
      if (d.garageScopeOfWork == 'Panel Only / Section Replacement') ...[
        const SizedBox(height: 8),
        _textField(
          controller: c.garagePanelSectionCount,
          label: 'How many?',
          onChanged: (v) {
            d.garagePanelSectionCount = v;
            _mark();
          },
        ),
      ],
      ..._buildDoorNotesAndPhotos(
        d: d,
        c: c,
        takePhotoLabel: 'Take Garage Door Photo',
        extraPhotoLabel: 'Add extra Garage Door photo',
      ),
    ];
  }

  List<Widget> _buildStorefrontDoorFields(
    DoorEntry d,
    _DoorControllers c,
  ) {
    return [
      _checkbox('Sliding door?', d.storefrontSlidingDoor, (v) {
        setState(() {
          d.storefrontSlidingDoor = v;
          _mark();
        });
      }),
      _checkbox('Oversize?', d.storefrontOversize, (v) {
        setState(() {
          d.storefrontOversize = v;
          if (!v) {
            d.storefrontOversizeInputSize = '';
            c.storefrontOversizeInputSize.clear();
          }
          _mark();
        });
      }),
      if (d.storefrontOversize) ...[
        const SizedBox(height: 8),
        _textField(
          controller: c.storefrontOversizeInputSize,
          label: 'Input size',
          onChanged: (v) {
            d.storefrontOversizeInputSize = v;
            _mark();
          },
        ),
      ],
      const SizedBox(height: 8),
      _dropdown(
        label: 'Type',
        value: d.storefrontType,
        options: const [
          'Aluminum anodized frame',
          'Bronze anodized frame',
          'Hardwood veneer frame',
          'Single pane',
          'Double pane',
        ],
        onChanged: (v) => setState(() {
          d.storefrontType = v ?? '';
          _mark();
        }),
      ),
      _checkbox('Curved?', d.storefrontCurved, (v) {
        setState(() {
          d.storefrontCurved = v;
          _mark();
        });
      }),
      const SizedBox(height: 8),
      _dropdown(
        label: 'Scope of work',
        value: d.storefrontScopeOfWork,
        options: const [
          'Replace',
          'D&R / Detach & Reset',
          'Replacement Glass Only',
        ],
        onChanged: (v) => setState(() {
          d.storefrontScopeOfWork = v ?? '';
          _mark();
        }),
      ),
      ..._buildDoorNotesAndPhotos(
        d: d,
        c: c,
        takePhotoLabel: 'Take Storefront Door Photo',
        extraPhotoLabel: 'Add extra Storefront Door photo',
      ),
    ];
  }

  List<Widget> _buildRollupDoorFields(
    DoorEntry d,
    _DoorControllers c,
  ) {
    return [
      const SizedBox(height: 8),
      _dropdown(
        label: 'Material Door Gauge',
        value: d.rollupGauge,
        options: const ['22 gauge', '26 gauge', 'Other'],
        onChanged: (v) => setState(() {
          d.rollupGauge = v ?? '';
          if (d.rollupGauge != 'Other') {
            d.rollupGaugeOtherSpecify = '';
            c.rollupGaugeOtherSpecify.clear();
          }
          _mark();
        }),
      ),
      if (d.rollupGauge == 'Other') ...[
        const SizedBox(height: 8),
        _textField(
          controller: c.rollupGaugeOtherSpecify,
          label: 'Specify',
          onChanged: (v) {
            d.rollupGaugeOtherSpecify = v;
            _mark();
          },
        ),
      ],
      const SizedBox(height: 8),
      _dropdown(
        label: 'Roll-up Door Size',
        value: d.rollupSize,
        options: const [
          '4x8',
          '8x8',
          '8x10',
          '10x8',
          '10x10',
          '10x12',
          '10x14',
          '10x16',
          '10x18',
          '12x10',
          '12x12',
          '12x14',
          '12x16',
          '12x18',
          '14x12',
          '14x14',
          '14x16',
          '14x18',
          'Other',
        ],
        onChanged: (v) => setState(() {
          d.rollupSize = v ?? '';
          if (d.rollupSize != 'Other') {
            d.rollupSizeOtherSpecify = '';
            c.rollupSizeOtherSpecify.clear();
          }
          _mark();
        }),
      ),
      if (d.rollupSize == 'Other') ...[
        const SizedBox(height: 8),
        _textField(
          controller: c.rollupSizeOtherSpecify,
          label: 'Specify',
          onChanged: (v) {
            d.rollupSizeOtherSpecify = v;
            _mark();
          },
        ),
      ],
      const SizedBox(height: 8),
      _dropdown(
        label: 'Scope of Work',
        value: d.rollupScopeOfWork,
        options: const ['Replace', 'D&R'],
        onChanged: (v) => setState(() {
          d.rollupScopeOfWork = v ?? '';
          _mark();
        }),
      ),
      ..._buildDoorNotesAndPhotos(
        d: d,
        c: c,
        takePhotoLabel: 'Take Roll-up Door Photo',
        extraPhotoLabel: 'Add extra Roll-up Door photo',
      ),
    ];
  }

  List<Widget> _buildDoorNotesAndPhotos({
    required DoorEntry d,
    required _DoorControllers c,
    required String takePhotoLabel,
    required String extraPhotoLabel,
  }) {
    return [
      const SizedBox(height: 8),
      _textField(
        controller: c.entryQuantity,
        label: 'Count',
        hintText: 'Qty of doors with these exact specs',
        onChanged: (v) {
          d.entryQuantity = v;
          _mark();
        },
      ),
      const SizedBox(height: 8),
      _notesField(c.additionalNotes, (v) {
        d.additionalNotes = v;
        _mark();
      }),
      const SizedBox(height: 8),
      ElevatedButton(
        onPressed: () => _pickDoorPhoto(d, extra: false),
        child: Text(takePhotoLabel),
      ),
      TextButton(
        onPressed: () => _pickDoorPhoto(d, extra: true),
        child: Text(extraPhotoLabel),
      ),
      if (d.photo != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Image.file(d.photo!, height: 100, cacheWidth: 300),
        ),
    ];
  }

  void _clearDoorTypeDependentFields(
    DoorEntry d,
    _DoorControllers c,
  ) {
    d.entryDoorType = '';
    d.entryMaterial = '';
    d.entryStyle = '';
    d.isFrenchDoor = false;
    d.entryScopeOfWork = '';
    d.hasLite = false;
    d.liteType = '';
    d.liteScopeOfWork = '';
    d.hasScreen = false;
    d.screenScopeOfWork = '';
    d.entryQuantity = '';
    d.patioMaterial = '';
    d.patioAluminumFinish = '';
    d.patioStyle = '';
    d.patioSize = '';
    d.patioScopeOfWork = '';
    d.garageStyle = '';
    d.garageWithWindows = false;
    d.garageWindowsCount = '';
    d.garageDoorSize = '';
    d.garageScopeOfWork = '';
    d.garagePanelSectionCount = '';
    d.rollupGauge = '';
    d.rollupGaugeOtherSpecify = '';
    d.rollupSize = '';
    d.rollupSizeOtherSpecify = '';
    d.rollupScopeOfWork = '';
    d.storefrontSlidingDoor = false;
    d.storefrontOversize = false;
    d.storefrontOversizeInputSize = '';
    d.storefrontType = '';
    d.storefrontCurved = false;
    d.storefrontScopeOfWork = '';
    d.additionalNotes = '';
    c.clear();
  }

  Future<void> _pickDoorPhoto(DoorEntry d, {required bool extra}) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 75,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final n = _nextElevationPhotoIndex('Door');

    widget.report.addPhoto(
      file,
      buildElevationsPhotoLabel(
        elev: widget.elevation.side.display,
        category: 'Door',
        label: 'Photo $n',
      ),
    );

    setState(() {
      if (extra) {
        d.extraPhoto = file;
      } else {
        d.photo = file;
      }
      _mark();
    });

    if (extra && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo stored'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }


  // =====================================================================
  // ADD ACCESSORY — patrón visual idéntico a Trim / Windows / Doors
  // =====================================================================
  Widget _buildAccessorySection() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Accessories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Divider(),
        for (var i = 0; i < _accessories.length; i++) _buildAccessoryCard(i),
        ElevatedButton(
          onPressed: () => setState(_addAccessoryRaw),
          child: const Text('Add Accessory'),
        ),
      ],
    );
  }

  void _addAccessoryRaw() {
    final a = AccessoryEntry();
    _accessories.add(a);
    _accessoryCtl[a] = _AccessoryControllers.from(a);
    _mark();
  }

  void _removeAccessory(int i) {
    setState(() {
      final a = _accessories.removeAt(i);
      _accessoryCtl.remove(a)?.dispose();
      _mark();
    });
  }

  Widget _buildAccessoryCard(int i) {
    final a = _accessories[i];
    final c = _accessoryCtl.putIfAbsent(a, () => _AccessoryControllers.from(a));

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
                  'Accessory ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeAccessory(i),
                ),
              ],
            ),
            _dropdown(
              label: 'Select Accessories',
              value: a.accessoryType,
              options: const [
                'Exterior Lights',
                'Mailbox',
                'HVAC',
                'Exterior Outlet',
                'J-Vent',
                'Meter Base',
                'Electric Box',
                'Exterior Faucet',
                'House Numbers/Letters',
                'Awning',
                'Shutter Set',
                'Satellite Dish',
                'Security camera',
                'Other',
              ],
              onChanged: (v) => setState(() {
                a.accessoryType = v ?? '';
                if (a.accessoryType != 'Other') {
                  a.accessoryOtherSpecify = '';
                  c.accessoryOtherSpecify.clear();
                }
                _mark();
              }),
            ),
            if (a.accessoryType == 'Other') ...[
              const SizedBox(height: 8),
              _textField(
                controller: c.accessoryOtherSpecify,
                label: 'Specify',
                onChanged: (v) {
                  a.accessoryOtherSpecify = v;
                  _mark();
                },
              ),
            ],
            const SizedBox(height: 8),
            _dropdown(
              label: 'Scope of work',
              value: a.scopeOfWork,
              options: const ['Replace', 'Detach & Reset'],
              onChanged: (v) => setState(() {
                a.scopeOfWork = v ?? '';
                _mark();
              }),
            ),
            const SizedBox(height: 8),
            _textField(
              controller: c.count,
              label: 'Count',
              onChanged: (v) {
                a.count = v;
                _mark();
              },
            ),
            const SizedBox(height: 8),
            _notesField(c.additionalNotes, (v) {
              a.additionalNotes = v;
              _mark();
            }),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _pickAccessoryPhoto(a, extra: false),
              child: const Text('Take Accessory Photo'),
            ),
            TextButton(
              onPressed: () => _pickAccessoryPhoto(a, extra: true),
              child: const Text('Add extra Accessory photo'),
            ),
            if (a.photo != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Image.file(a.photo!, height: 100, cacheWidth: 300),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAccessoryPhoto(
    AccessoryEntry a, {
    required bool extra,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      imageQuality: 75,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final n = _nextElevationPhotoIndex('Accessory');

    widget.report.addPhoto(
      file,
      buildElevationsPhotoLabel(
        elev: widget.elevation.side.display,
        category: 'Accessory',
        label: 'Photo $n',
      ),
    );

    setState(() {
      if (extra) {
        a.extraPhoto = file;
      } else {
        a.photo = file;
      }
      _mark();
    });

    if (extra && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo stored'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // =====================================================================
  // HELPERS UI
  // =====================================================================
  Widget _checkbox(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      title: Text(label),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: (value == null || value.isEmpty || !options.contains(value))
          ? null
          : value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _qtyField({
    required TextEditingController controller,
    required String hint,
    required String unit,
    String? helper,
    required ValueChanged<String> onChanged,
      String? hintText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: hint,
         hintText: hintText,
        suffixText: unit,
        helperText: helper,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? helper,
    String? hintText,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
          hintStyle: const TextStyle(
    color: Colors.grey,
    fontSize: 12,
      ),
        helperText: helper,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  Widget _notesField(
      TextEditingController c, ValueChanged<String> onChanged) {
    return TextField(
      controller: c,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Additional Notes',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }
}

       Widget _sectionTitleWithClear(String title, VoidCallback onClearPressed) {
       return Row(
       children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.refresh, size: 20),
        tooltip: 'Clear section',
        onPressed: onClearPressed,
      ),
    ],
  );
}

// ─── Controllers por TrimEntry ────────────────────────────────────────
class _TrimControllers {
  final TextEditingController otherSpecify;
  final TextEditingController ocpMetalGauge;
  final TextEditingController sidingTrimSize;

  _TrimControllers.from(TrimEntry t)
      : otherSpecify = TextEditingController(text: t.otherSpecify),
        ocpMetalGauge = TextEditingController(text: t.ocpMetalGauge),
        sidingTrimSize = TextEditingController(text: t.sidingTrimSize);

  void dispose() {
    otherSpecify.dispose();
    ocpMetalGauge.dispose();
    sidingTrimSize.dispose();
  }
}

// ─── Controllers por WindowEntry ────────────────────────────────────── 
class _WindowControllers { 
  final TextEditingController componentOtherSpecify;
  final TextEditingController widthInches; 
  final TextEditingController heightInches; 
  final TextEditingController quantity; 
  final TextEditingController shuttersMaterialSpecify; // <-- AQUÍ ESTÁ EL NUEVO
  final TextEditingController additionalNotes;

  _WindowControllers.from(WindowEntry w) 
      : componentOtherSpecify = TextEditingController(text: w.componentOtherSpecify), 
        widthInches = TextEditingController(text: w.widthInches),
        heightInches = TextEditingController(text: w.heightInches), 
        quantity = TextEditingController(text: w.quantity), 
        shuttersMaterialSpecify = TextEditingController(text: w.shuttersMaterialSpecify), // <-- INICIALIZADO
        additionalNotes = TextEditingController(text: w.additionalNotes);

  void dispose() { 
    componentOtherSpecify.dispose(); 
    widthInches.dispose(); 
    heightInches.dispose(); 
    quantity.dispose(); 
    shuttersMaterialSpecify.dispose(); // <-- LIMPIADO PARA EVITAR FUGAS DE MEMORIA
    additionalNotes.dispose(); 
  } 
}
// ─── Controllers por DoorEntry ────────────────────────────────────────
class _DoorControllers {
  final TextEditingController entryQuantity;
  final TextEditingController garageWindowsCount;
  final TextEditingController garagePanelSectionCount;
  final TextEditingController rollupGaugeOtherSpecify;
  final TextEditingController rollupSizeOtherSpecify;
  final TextEditingController storefrontOversizeInputSize;
  final TextEditingController additionalNotes;

  _DoorControllers.from(DoorEntry d)
      : entryQuantity = TextEditingController(text: d.entryQuantity),
        garageWindowsCount = TextEditingController(text: d.garageWindowsCount),
        garagePanelSectionCount = TextEditingController(text: d.garagePanelSectionCount),
        rollupGaugeOtherSpecify = TextEditingController(text: d.rollupGaugeOtherSpecify),
        rollupSizeOtherSpecify = TextEditingController(text: d.rollupSizeOtherSpecify),
        storefrontOversizeInputSize = TextEditingController(text: d.storefrontOversizeInputSize),
        additionalNotes = TextEditingController(text: d.additionalNotes);

  void clear() {
    entryQuantity.clear();
    garageWindowsCount.clear();
    garagePanelSectionCount.clear();
    rollupGaugeOtherSpecify.clear();
    rollupSizeOtherSpecify.clear();
    storefrontOversizeInputSize.clear();
    additionalNotes.clear();
  }

  void dispose() {
    entryQuantity.dispose();
    garageWindowsCount.dispose();
    garagePanelSectionCount.dispose();
    rollupGaugeOtherSpecify.dispose();
    rollupSizeOtherSpecify.dispose();
    storefrontOversizeInputSize.dispose();
    additionalNotes.dispose();
  }
}

// ─── Controllers por AccessoryEntry ───────────────────────────────────
class _AccessoryControllers {
  final TextEditingController accessoryOtherSpecify;
  final TextEditingController count;
  final TextEditingController additionalNotes;

  _AccessoryControllers.from(AccessoryEntry a)
      : accessoryOtherSpecify =
            TextEditingController(text: a.accessoryOtherSpecify),
        count = TextEditingController(text: a.count),
        additionalNotes = TextEditingController(text: a.additionalNotes);

  void dispose() {
    accessoryOtherSpecify.dispose();
    count.dispose();
    additionalNotes.dispose();
  }
}
