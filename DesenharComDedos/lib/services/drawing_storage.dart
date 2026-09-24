import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/stroke.dart';

/// Persiste o desenho num arquivo no diretório do app (via canal nativo),
/// para que sobreviva ao fechamento do aplicativo.
///
/// Usa MethodChannel em vez de um plugin para evitar dependências com
/// build hooks nativos (que falham quando o caminho do usuário tem espaços).
class DrawingStorage {
  static const _channel =
      MethodChannel('com.desenhardedos.desenhar_com_dedos/storage');

  Future<void> _writeChain = Future<void>.value();

  /// Salva os traços. Escritas são encadeadas para evitar corrupção.
  Future<void> save(List<Stroke> strokes) {
    final data = jsonEncode(strokes.map((s) => s.toJson()).toList());
    _writeChain = _writeChain.then((_) async {
      try {
        await _channel.invokeMethod('save', {'data': data});
      } catch (_) {}
    });
    return _writeChain;
  }

  Future<List<Stroke>> load() async {
    try {
      final raw = await _channel.invokeMethod<String>('load');
      if (raw == null || raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Stroke.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
