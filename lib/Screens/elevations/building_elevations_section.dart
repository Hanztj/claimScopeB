import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final VoidCallback onChange;

  const BuildingElevationsSection({
    super.key,
    required this.elevation,
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
  late final TextEditingController _howManySf;
  late final TextEditingController _stuccoSmallRepairSf;
  late final TextEditingController _stuccoCrackRepairLf;
  late final TextEditingController _stuccoFogCoatSf;
  late final TextEditingController _stuccoRedashSf;
  late final TextEditingController _stuccoWholeReplacementCoats;
  late final TextEditingController _sidingNotes;

  // ─── Controllers por Trim (gestionados por id de instancia) ───────────
  final Map<TrimEntry, _TrimControllers> _trimCtl = {};

  final _picker = ImagePicker();
  
  SidingDamagesData get _s => widget.elevation.siding;
  List<TrimEntry> get _trims => widget.elevation.trims;

  @override
  void initState() {
    super.initState();
    _steelSidingGauge = TextEditingController(text: _s.steelSidingGauge);
    _sidingHeight = TextEditingController(text: _s.sidingHeight);
    _howManySf = TextEditingController(text: _s.howManySf);
    _stuccoSmallRepairSf = TextEditingController(text: _s.stuccoSmallRepairSf);
    _stuccoCrackRepairLf = TextEditingController(text: _s.stuccoCrackRepairLf);
    _stuccoFogCoatSf = TextEditingController(text: _s.stuccoFogCoatSf);
    _stuccoRedashSf = TextEditingController(text: _s.stuccoRedashSf);
    _stuccoWholeReplacementCoats =
        TextEditingController(text: _s.stuccoWholeReplacementCoats);
    _sidingNotes = TextEditingController(text: _s.additionalNotes);
    _syncTrimControllers();
  }

  @override
  void didUpdateWidget(covariant BuildingElevationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia la elevación (Front → Right, etc.) hay que repoblar
    // los controllers de Trim para los TrimEntry de la nueva elevación.
    if (oldWidget.elevation != widget.elevation) {
      _syncTrimControllers();
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

  @override
  void dispose() {
    for (final c in [
      _steelSidingGauge,
      _sidingHeight,
      _howManySf,
      _stuccoSmallRepairSf,
      _stuccoCrackRepairLf,
      _stuccoFogCoatSf,
      _stuccoRedashSf,
      _stuccoWholeReplacementCoats,
      _sidingNotes,
    ]) {
      c.dispose();
    }
    for (final tc in _trimCtl.values) {
      tc.dispose();
    }
    super.dispose();
  }

  void _mark() => widget.onChange();

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
        _buildTrimSection(),
        const SizedBox(height: 8),
        // Placeholders compilables para próximas secciones (pasos 5+)
        for (final s in const [
          'Underlayment & Insulation',
          'Substrate',
          'EIFS',
          'Windows',
          'Doors',
          'Accessories',
        ])
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.construction_outlined),
              title: Text(s),
              subtitle: const Text('Coming in next steps'),
              dense: true,
            ),
          ),
      ],
    );
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
        title: const Text('Siding',
            style: TextStyle(fontWeight: FontWeight.w600)),
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
                child: Image.file(t.photo!, height: 100),
              ),
            if (t.extraPhoto != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Image.file(t.extraPhoto!, height: 100),
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
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (picked == null) return;
    setState(() {
      if (extra) {
        t.extraPhoto = File(picked.path);
      } else {
        t.photo = File(picked.path);
      }
      _mark();
    });
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
