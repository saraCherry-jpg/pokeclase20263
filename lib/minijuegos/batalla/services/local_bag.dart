import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/battle_item.dart';

// Premios guardados en el teléfono. Se usa porque Somee todavía no tiene objetos en la
// tabla Item ni deja hacer POST /api/ItemUser. Se guarda el Item completo (sacado de la
// PokeAPI) y la cantidad, por usuario.
class LocalBag {
  static String _key(String userId) => 'mochila_local_$userId';

  // Si no se puede leer, la mochila sigue con lo de Somee
  Future<List<BagItem>> load(String userId) async {
    try {
      final rows = await _rows(userId);
      return rows.map((e) => BagItem.fromJson(e, local: true)).where((b) => b.cantidad > 0).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(String userId, ItemInfo item, int cantidad) async {
    final rows = await _rows(userId);
    final row = rows.where((r) => r['idItem'] == item.id).firstOrNull;
    if (row != null) {
      row['cantidad'] = (row['cantidad'] as int) + cantidad;
    } else {
      rows.add({'id': item.id, 'idItem': item.id, 'cantidad': cantidad, 'item': item.toJson()});
    }
    await _save(userId, rows);
  }

  Future<void> setQuantity(String userId, int idItem, int cantidad) async {
    final rows = await _rows(userId);
    for (final r in rows) {
      if (r['idItem'] == idItem) r['cantidad'] = cantidad;
    }
    await _save(userId, rows.where((r) => (r['cantidad'] as int) > 0).toList());
  }

  Future<List<Map<String, dynamic>>> _rows(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_key(userId));
    if (text == null) return [];
    return (json.decode(text) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _save(String userId, List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), json.encode(rows));
  }
}
