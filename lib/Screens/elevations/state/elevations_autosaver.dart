import 'dart:async';
import 'dart:convert';

import 'package:claimscope_clean/screens/elevations/models/elevations_data.dart';
import 'package:claimscope_clean/services/pdf_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Autosaver con debounce de 800ms que serializa [ElevationsData] a
/// SharedPreferences bajo la clave `draft_elevations_<reportId>`.
///
/// Uso típico:
/// ```dart
/// final saver = ElevationsAutoSaver(reportId: report.id, data: report.elevations);
/// await saver.restoreInto(report.elevations); // hidratar al abrir
/// // ... cada vez que cambie algo en la UI:
/// saver.scheduleSave();
/// // al cerrar la pantalla:
/// await saver.flushAndDispose();
/// ```
class ElevationsAutoSaver {
  ElevationsAutoSaver({
    required this.reportId,
    required this.data,
    this.debounce = const Duration(milliseconds: 800),
  });

  final String reportId;
  final ElevationsData data;
  final Duration debounce;

  Timer? _timer;
  bool _disposed = false;
  Future<void>? _inFlight;

  String get _key => 'draft_elevations_$reportId';

  /// Programa un guardado debounced. Llamar tras cada mutación relevante.
  void scheduleSave() {
    if (_disposed) return;
    // Palanca 1: no serializar mientras se genera un PDF pesado.
    if (PdfBusyFlag.busy) return;
    _timer?.cancel();
    _timer = Timer(debounce, _persist);
  }

  /// Fuerza un guardado inmediato (cancela el debounce pendiente).
  Future<void> flush() async {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    await _persist();
    if (_inFlight != null) {
      try {
        await _inFlight;
      } catch (_) {/* swallow */}
    }
  }

  /// Flush + libera recursos. Idempotente.
  Future<void> flushAndDispose() async {
    if (_disposed) return;
    await flush();
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
  void mount() {
    // Aquí adentro va tu lógica para iniciar el temporizador (Timer) 
    // o el mecanismo que detecta los cambios.
    debugPrint('AutoSaver montado e iniciado.');
  }
     void markDirty() {
    // Palanca 1: gate global — no marcar dirty mientras se genera un PDF pesado.
    if (PdfBusyFlag.busy) return;
    // Aquí adentro va la lógica que le dice al Timer: 
    // "Hubo un cambio, ejecuta el guardado en el próximo ciclo".
    debugPrint('Datos marcados como modificados (dirty). Guardando pronto...');
  }
  /// Hidrata [target] con el draft guardado (si existe). No-op si no hay draft
  /// o si el JSON está corrupto.
  Future<bool> restoreInto(ElevationsData target) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return false;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final restored = ElevationsData.fromJson(map);
      target.assignFrom(restored);
      return true;
    } catch (e, st) {
      debugPrint('[ElevationsAutoSaver] restoreInto failed: $e\n$st');
      return false;
    }
  }

  /// Borra el draft persistido (p. ej. tras submit exitoso del reporte).
  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('[ElevationsAutoSaver] clearDraft failed: $e');
    }
  }

  Future<void> _persist() async {
    if (_disposed) return;
    final future = _doPersist();
    _inFlight = future;
    try {
      await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<void> _doPersist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(data.toJson());
      await prefs.setString(_key, encoded);
    } catch (e, st) {
      debugPrint('[ElevationsAutoSaver] persist failed: $e\n$st');
    }
  }
}
