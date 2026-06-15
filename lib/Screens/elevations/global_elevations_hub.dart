import 'package:flutter/material.dart';

import 'models/elevations_data.dart';
import 'widgets/section_status_dot.dart';

/// Secciones globales del edificio (no dependen de la elevación activa):
///   1. Emergency Services
///   2. Gutters / Fascia / Soffit
///
/// Toda la UI vive en este archivo (sub-widgets privados). Patrón `Other → TextField`
/// inline. Cada tile termina con un único TextField "Additional Notes" no colapsable.
class GlobalElevationsHub extends StatefulWidget {
  final ElevationsData data;
  final VoidCallback onChange;

  const GlobalElevationsHub({
    super.key,
    required this.data,
    required this.onChange,
  });

  @override
  State<GlobalElevationsHub> createState() => _GlobalElevationsHubState();
}

class _GlobalElevationsHubState extends State<GlobalElevationsHub> {
  // ─── Emergency Services ──────────────────────────────────────────────
  late final TextEditingController _twpSf;
  late final TextEditingController _twdpSf;
  late final TextEditingController _pwSf;
  late final TextEditingController _esNotes;

  // ─── Gutters ─────────────────────────────────────────────────────────
  late final TextEditingController _gutMaterialOther;
  late final TextEditingController _gutShapeOther;
  late final TextEditingController _gutScopeOther;
  late final TextEditingController _gutLf;
  late final TextEditingController _gutScreenType;
  late final TextEditingController _gutScupperQty;

  // ─── Fascia ──────────────────────────────────────────────────────────
  late final TextEditingController _facMaterialOther;
  late final TextEditingController _facSizeOther;
  late final TextEditingController _facScopeOther;
  late final TextEditingController _facLf;

  // ─── Soffit ──────────────────────────────────────────────────────────
  late final TextEditingController _sofMaterialOther;
  late final TextEditingController _sofSizeOther;
  late final TextEditingController _sofScopeOther;
  late final TextEditingController _sofLf;
  late final TextEditingController _sofVentsQty;

  // ─── Notas única para sec.2 ──────────────────────────────────────────
  late final TextEditingController _gsfNotes;

  EmergencyServicesData get _es => widget.data.emergencyServices;
  GuttersSoffitFasciaData get _gsf => widget.data.guttersSoffitFascia;

  @override
  void initState() {
    super.initState();
    _twpSf = TextEditingController(text: _es.twpSf);
    _twdpSf = TextEditingController(text: _es.twdpSf);
    _pwSf = TextEditingController(text: _es.pwSf);
    _esNotes = TextEditingController(text: _es.additionalNotes);

    _gutMaterialOther = TextEditingController(text: _gsf.gutMaterialOther);
    _gutShapeOther = TextEditingController(text: _gsf.gutShapeOther);
    _gutScopeOther = TextEditingController(text: _gsf.gutScopeOther);
    _gutLf = TextEditingController(text: _gsf.gutLf);
  // Cambia la línea de tu initState para que lea esa nueva variable:
    _gutScreenType = TextEditingController(text: _gsf.gutScreenStyle);
    _gutScupperQty = TextEditingController(text: _gsf.gutScupperQty);

    _facMaterialOther = TextEditingController(text: _gsf.facMaterialOther);
    _facSizeOther = TextEditingController(text: _gsf.facSizeOther);
    _facScopeOther = TextEditingController(text: _gsf.facScopeOther);
    _facLf = TextEditingController(text: _gsf.facLf);

    _sofMaterialOther = TextEditingController(text: _gsf.sofMaterialOther);
    _sofSizeOther = TextEditingController(text: _gsf.sofSizeOther);
    _sofScopeOther = TextEditingController(text: _gsf.sofScopeOther);
    _sofLf = TextEditingController(text: _gsf.sofLf);
    _sofVentsQty = TextEditingController(text: _gsf.sofVentsQty);

    _gsfNotes = TextEditingController(text: _gsf.additionalNotes);
  }

  @override
  void dispose() {
    for (final c in [
      _twpSf, _twdpSf, _pwSf, _esNotes,
      _gutMaterialOther, _gutShapeOther, _gutScopeOther, _gutLf,
      _gutScreenType, _gutScupperQty,
      _facMaterialOther, _facSizeOther, _facScopeOther, _facLf,
      _sofMaterialOther, _sofSizeOther, _sofScopeOther, _sofLf, _sofVentsQty,
      _gsfNotes,
    ]) { c.dispose(); }
    super.dispose();
  }

  void _mark() => widget.onChange();

  // =====================================================================
  // BUILD
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ListView( 
        shrinkWrap: true, 
        physics: const ClampingScrollPhysics(), 
        children: [
          _buildEmergencyServicesTile(),
          const SizedBox(height: 8),
          _buildGuttersTile(),
          const SizedBox(height: 8),
          _buildFasciaTile(),
          const SizedBox(height: 8),
          _buildSoffitTile(),
        ],
      ),
    );
  }

  // =====================================================================
  // SECCIÓN 1 — EMERGENCY SERVICES
  // =====================================================================
  Widget _buildEmergencyServicesTile() {
    final status = _esStatus();
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: SectionStatusDot(status: status),
        title: const Text('Emergency Services',
            style: TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: [
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: const Text('Emergency Services performed'),
            value: _es.enabled,
            onChanged: (v) => setState(() { _es.enabled = v ?? false; _mark(); }),
          ),
          if (_es.enabled) ...[
            const Divider(height: 16),
            // 1.A Temporary Wall Protection
            _checkbox('Temporary Wall Protection', _es.twpEnabled,
                (v) { _es.twpEnabled = v; _mark(); }),
            if (_es.twpEnabled) Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _dropdown(
                  label: 'Type',
                  value: _es.twpType,
                  options: const ['Board', 'Tarp'],
                  onChanged: (v) => setState(() { _es.twpType = v ?? ''; _mark(); }),
                ),
                const SizedBox(height: 8),
                _qtyField(controller: _twpSf, hint: 'How many SF', unit: 'SF',
                    onChanged: (v) { _es.twpSf = v; _mark(); }),
              ]),
            ),
            // 1.B Temporary Window/Door Protection
            _checkbox('Temporary Window/Door Protection', _es.twdpEnabled,
                (v) { _es.twdpEnabled = v; _mark(); }),
            if (_es.twdpEnabled) Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 8),
              child: _qtyField(controller: _twdpSf, hint: 'How many SF', unit: 'SF',
                  onChanged: (v) { _es.twdpSf = v; _mark(); }),
            ),
            // 1.C Power Washing
            _checkbox('Power Washing required', _es.pwEnabled,
                (v) { _es.pwEnabled = v; _mark(); }),
            if (_es.pwEnabled) Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _dropdown(
                  label: 'Area',
                  value: _es.pwArea,
                  options: const ['Entire Elev', 'Partial'],
                  onChanged: (v) => setState(() { _es.pwArea = v ?? ''; _mark(); }),
                ),
                if (_es.pwArea == 'Partial') ...[
                  const SizedBox(height: 8),
                  _qtyField(
                    controller: _pwSf,
                    hint: 'How many SF',
                    unit: 'SF',
                    onChanged: (v) {
                      _es.pwSf = v;
                      _mark();
                    },
                  ),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 12),
          _notesField(_esNotes, (v) { _es.additionalNotes = v; _mark(); }),
        ],
      ),
    );
  }

  SectionStatus _esStatus() {
    if (!_es.hasAnyData) return SectionStatus.empty;
    if (!_es.enabled) return SectionStatus.partial;
    bool blockComplete(bool en, List<String> reqs) =>
        !en || reqs.every((r) => r.isNotEmpty);
    final twpOk = blockComplete(_es.twpEnabled, [_es.twpType, _es.twpSf]);
    final twdpOk = blockComplete(_es.twdpEnabled, [_es.twdpSf]);
    final pwOk = blockComplete(_es.pwEnabled, [_es.pwArea, _es.pwSf]);
    return (twpOk && twdpOk && pwOk) ? SectionStatus.complete : SectionStatus.partial;
  }

  // =====================================================================
  // SECCIÓN 2.A — GUTTERS & DOWNSPOUTS
  // =====================================================================
  Widget _buildGuttersTile() {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: SectionStatusDot(status: _gutStatus()),
        title: const Text('Gutters & Downspouts',
            style: TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: [
          const SizedBox(height: 8),
          _dropdownWithOther(
            label: 'Material Type',
            value: _gsf.gutMaterial,
            options: const ['Plastic/Vinyl', 'Aluminum', 'Galvanized', 'Copper', 'Other'], 
            otherController: _gutMaterialOther,
            onChanged: (v) => setState(() { _gsf.gutMaterial = v ?? ''; _mark(); }),
            onOtherChanged: (v) { _gsf.gutMaterialOther = v; _mark(); },
          ),
          const SizedBox(height: 8),
          _dropdownWithOther(
            label: 'Shape Type',
            value: _gsf.gutShape,
            options: const ['Standard','Box','Half round','Soldered'],
            otherController: _gutShapeOther,
            onChanged: (v) => setState(() { _gsf.gutShape = v ?? ''; _mark(); }),
            onOtherChanged: (v) { _gsf.gutShapeOther = v; _mark(); },
          ),
          const SizedBox(height: 8),
          _dropdown(
            label: 'Size',
            value: _gsf.gutSize,
            options: const ['Up to 5"','6"','7" to 8"'],
            onChanged: (v) => setState(() { _gsf.gutSize = v ?? ''; _mark(); }),
          ),
         const SizedBox(height: 4),
          const Text('Accessories', style: TextStyle(fontWeight: FontWeight.w500)),
          
          // 1. Checkbox de Gutter Screen (Corregido con setState)
          _checkbox('Has gutter screen?', _gsf.gutScreen, (v) { 
            setState(() {
              _gsf.gutScreen = v; 
              _mark(); 
            });
          }),
          if (_gsf.gutScreen) 
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, 
                children: [
                  _dropdown(
                    label: 'Style',
                    value: _gutScreenType.text.isEmpty ? null : _gutScreenType.text,
                    options: const ['Standard', 'High grade', 'Premium grade'],
                    onChanged: (v) => setState(() { 
                      _gutScreenType.text = v ?? ''; 
                      _gsf.gutScreenStyle = v ?? '';
                      _mark(); 
                    }),
                  ),
                ],
              ),
            ),

          // 2. Checkbox de Scupper (Simplificado y funcionando)
          _checkbox('Has Scupper?', _gsf.gutScupper, (v) { 
            setState(() {
              _gsf.gutScupper = v; 
              if (!v) {
                _gutScupperQty.clear(); 
                _gsf.gutScupperQty = ''; 
              }
              _mark(); 
            });
          }),
          if (_gsf.gutScupper) 
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 8),
              child: _qtyField(
                controller: _gutScupperQty, 
                hint: 'How many Scuppers', 
                unit: 'Qty',
                onChanged: (v) { 
                  _gsf.gutScupperQty = v; 
                  _mark(); 
                },
              ),
            ),
const SizedBox(height: 8),
          _dropdownWithOther(
            label: 'Scope of Work',
            value: _gsf.gutScope,
            options: const ['Replace', 'Dettach & Reset'],
            otherController: _gutScopeOther,
            onChanged: (v) => setState(() { 
              _gsf.gutScope = v ?? ''; 
              if (_gsf.gutScope.isEmpty) {
                _gutLf.clear();
                _gsf.gutLf = '';
              }
              _mark(); 
            }),
            onOtherChanged: (v) { _gsf.gutScopeOther = v; _mark(); },
          ),
          
          // El campo LF ahora es condicional
          if (_gsf.gutScope.isNotEmpty) ...[
  const SizedBox(height: 12),
  _qtyField(
    controller: _gutLf,
    hint: 'How many LF?',
    unit: 'LF',
    hintText: 'Approx. gutters/downspouts LF',
    onChanged: (v) {
      _gsf.gutLf = v;
      _mark();
    },
  ),
],
          
          const SizedBox(height: 8),
          _checkbox('Requires to be painted?', _gsf.gutPaint, (v) { 
            setState(() {
              _gsf.gutPaint = v; 
              _mark(); 
            });
          }),
        ],
      ),
    );
  }

SectionStatus _gutStatus() {
  final any = _gsf.guttersHasData;
  if (!any) return SectionStatus.empty;
  
  // Dejamos únicamente los 5 campos base obligatorios para el Gutter
  final req = [_gsf.gutMaterial, _gsf.gutShape, _gsf.gutSize, _gsf.gutScope, _gsf.gutLf];
  
  return req.every((r) => r.isNotEmpty) ? SectionStatus.complete : SectionStatus.partial;
}

  // =====================================================================
  // SECCIÓN 2.B — FASCIA
  // =====================================================================
  Widget _buildFasciaTile() {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: SectionStatusDot(status: _facStatus()),
        title: const Text('Fascia',
            style: TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: [
          const SizedBox(height: 8),
          _dropdownWithOther(
            label: 'Material Type',
            value: _gsf.facMaterial,
            options: const ['Metal', 'Wood', 'Vinyl', 'Fiber Cement',],
            otherController: _facMaterialOther,
            onChanged: (v) => setState(() { _gsf.facMaterial = v ?? ''; _mark(); }),
            onOtherChanged: (v) { _gsf.facMaterialOther = v; _mark(); },
          ),

            if (_gsf.facMaterial.isNotEmpty && _gsf.facMaterial != 'Wood') ...[
            const SizedBox(height: 8),
            _dropdownWithOther(
              label: 'Size',
              value: _gsf.facSize,
              options: const ['4"', '6"', '8"', '10"'],
              otherController: _facSizeOther,
              onChanged: (v) => setState(() { _gsf.facSize = v ?? ''; _mark(); }),
              onOtherChanged: (v) { _gsf.facSizeOther = v; _mark(); },
            ), 
          ],

          if (_gsf.facMaterial == 'Wood') ...[
            const SizedBox(height: 8),
            _dropdown(
              label: 'Wood Subtype',
              value: _gsf.facWoodSubtype,
              options: const ['Pine', 'Cedar', 'Softwood', 'Re-saw'],
              onChanged: (v) => setState(() { _gsf.facWoodSubtype = v ?? ''; _mark(); }),
            ),
                    
          const SizedBox(height: 8),
          _dropdownWithOther(
            label: 'Size',
            value: _gsf.facSize,
            options: const ['1x4', '1x6', '1x8', '2x6', '2x8',],
            otherController: _facSizeOther,
            onChanged: (v) => setState(() { _gsf.facSize = v ?? ''; _mark(); }),
            onOtherChanged: (v) { _gsf.facSizeOther = v; _mark(); },
          ),
          ],
          const SizedBox(height: 8),
          _dropdownWithOther(
            label: 'Scope of Work',
            value: _gsf.facScope,
            options: const ['Replace', 'Dettach & Reset'],
            otherController: _facScopeOther,
            onChanged: (v) => setState(() { _gsf.facScope = v ?? ''; _mark(); }),
            onOtherChanged: (v) { _gsf.facScopeOther = v; _mark(); },
          ),
          const SizedBox(height: 8),
          _dropdown(
            label: 'Quantity',
            value: _gsf.facQuantity,
            options: const ['Entire perimeter', 'Partial'],
            onChanged: (v) => setState(() {
              _gsf.facQuantity = v ?? '';
              if (_gsf.facQuantity == 'Entire perimeter') {
                _gsf.facLf = '';
                _facLf.clear();
              }
              _mark();
            }),
          ),
          if (_gsf.facQuantity == 'Partial') ...[
            const SizedBox(height: 8),
            _qtyField(controller: _facLf, hint: 'How many LF', unit: 'LF',
                onChanged: (v) { _gsf.facLf = v; _mark(); }),
          ],
          _checkbox('Requires to be painted?', _gsf.facPaint,
              (v) { _gsf.facPaint = v; _mark(); }),
        ],
      ),
    );
  }

  SectionStatus _facStatus() {
    if (!_gsf.fasciaHasData) return SectionStatus.empty;
    final req = <String>[
      _gsf.facMaterial, _gsf.facSize, _gsf.facScope, _gsf.facQuantity,
      if (_gsf.facMaterial == 'Wood') _gsf.facWoodSubtype,
      if (_gsf.facQuantity == 'Partial') _gsf.facLf,
    ];
    return req.every((r) => r.isNotEmpty) ? SectionStatus.complete : SectionStatus.partial;
  }

  // =====================================================================
  // SECCIÓN 2.C — SOFFIT
  // =====================================================================
Widget _buildSoffitTile() {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: SectionStatusDot(status: _sofStatus()),
        title: const Text('Soffit',
            style: TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        children: [
          const SizedBox(height: 8),
          _dropdownWithOther(
            label: 'Material Type',
            value: _gsf.sofMaterial,
            options: const ['Metal', 'Vinyl', 'Wood', 'Fiber Cement', 'Other'],
            otherController: _sofMaterialOther,
            onChanged: (v) => setState(() { _gsf.sofMaterial = v ?? ''; _mark(); }),
            onOtherChanged: (v) { _gsf.sofMaterialOther = v; _mark(); },
          ),
          const SizedBox(height: 8),
          _dropdownWithOther(
            label: 'Size',
            value: _gsf.sofSize,
            options: const ['12"', '16"', '24"', 'Other'],
            otherController: _sofSizeOther,
            onChanged: (v) => setState(() { _gsf.sofSize = v ?? ''; _mark(); }),
            onOtherChanged: (v) { _gsf.sofSizeOther = v; _mark(); },
          ),
          const SizedBox(height: 8),
          _dropdownWithOther(
            label: 'Scope of Work',
            value: _gsf.sofScope,
            options: const ['Replace', 'Dettach & Reset'],
            otherController: _sofScopeOther,
            onChanged: (v) => setState(() { _gsf.sofScope = v ?? ''; _mark(); }),
            onOtherChanged: (v) { _gsf.sofScopeOther = v; _mark(); },
          ),
           const SizedBox(height: 8),
          _dropdown(
            label: 'Quantity',
            value: _gsf.facQuantity,
            options: const ['Entire perimeter', 'Partial'],
            onChanged: (v) => setState(() {
              _gsf.facQuantity = v ?? '';
              if (_gsf.facQuantity == 'Entire perimeter') {
                _gsf.facLf = '';
                _facLf.clear();
              }
              _mark();
            }),
          ),
          if (_gsf.facQuantity == 'Partial') ...[
            const SizedBox(height: 8),
            _qtyField(controller: _facLf, hint: 'How many LF', unit: 'LF',
                onChanged: (v) { _gsf.facLf = v; _mark(); }),
          ],
          
          // ─── Modificación para Vents ───────────────────────────────────────
          _checkbox('Has Vents?', _gsf.sofVents, (v) { 
            setState(() { 
              _gsf.sofVents = v; 
              if (!v) {
                _sofVentsQty.clear(); // Limpia la UI si desmarcan
                _gsf.sofVentsQty = ''; // Limpia el modelo
              }
              _mark(); 
            }); 
          }),
          
          if (_gsf.sofVents) 
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 8),
              child: _qtyField(
                controller: _sofVentsQty, 
                hint: 'How many vents', 
                unit: 'Qty',
                onChanged: (v) { 
                  _gsf.sofVentsQty = v; 
                  _mark(); 
                },
              ),
            ),
          // ───────────────────────────────────────────────────────────────────

          const SizedBox(height: 8),
          _checkbox('Requires to be painted?', _gsf.sofPaint,
              (v) { setState(() { _gsf.sofPaint = v; _mark(); }); }),
          const SizedBox(height: 12),
          // Notas únicas de TODA la sección Gutters/Fascia/Soffit
          _notesField(_gsfNotes, (v) { _gsf.additionalNotes = v; _mark(); }),
        ],
      ),
    );
  }
  SectionStatus _sofStatus() {
    if (!_gsf.soffitHasData) return SectionStatus.empty;
    final req = [_gsf.sofMaterial, _gsf.sofSize, _gsf.sofScope, _gsf.sofLf];
    return req.every((r) => r.isNotEmpty) ? SectionStatus.complete : SectionStatus.partial;
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
      onChanged: (v) => setState(() => onChanged(v ?? false)),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value, // Corregido: String? para admitir nulos de campos condicionales
  required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: (value == null || value.isEmpty || !options.contains(value)) ? null : value, // Evita crash por desalineación de opciones iniciales
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

  Widget _dropdownWithOther({
    required String label,
    required String value,
    required List<String> options,
    required TextEditingController otherController,
    required ValueChanged<String?> onChanged,
    required ValueChanged<String> onOtherChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _dropdown(label: label, value: value, options: options, onChanged: onChanged),
      if (value == 'Other') ...[
        const SizedBox(height: 6),
        TextField(
          controller: otherController,
          decoration: InputDecoration(
            labelText: '$label (Other)',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onOtherChanged,
        ),
      ],
    ]);
  }

Widget _qtyField({
  required TextEditingController controller,
  required String hint,
  required String unit,
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
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    onChanged: onChanged,
  );
}

  Widget _notesField(TextEditingController c, ValueChanged<String> onChanged) {
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