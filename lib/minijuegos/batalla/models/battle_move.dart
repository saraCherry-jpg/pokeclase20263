import 'dart:convert';

import 'status_condition.dart';

// Un movimiento (ataque) de batalla.
// Se llena desde el endpoint `/move/{nombre}` de la PokeAPI, porque la base de datos
// del equipo todavía no tiene una tabla de movimientos.
class BattleMove {
  final String name;          // Nombre interno de la API (ej. "flamethrower")
  final String displayName;   // Nombre en español si la API lo trae (ej. "Lanzallamas")
  final int? power;           // Poder. Es nulo en movimientos que no hacen daño
  final int? accuracy;        // Precisión (0-100). Nulo = nunca falla
  final int pp;               // Veces que se puede usar
  final String type;          // Tipo del movimiento (fire, water, ...)
  final String damageClass;   // physical, special o status
  final StatusCondition? ailment; // Estado que puede causar (quemar, dormir, ...)
  final int ailmentChance;    // Probabilidad (0-100) de causar ese estado
  final int priority;         // Mayor prioridad ataca primero (Ataque Rápido = +1)
  final int critRate;         // 0 = normal (1/24), 1 = alta (1/8), 2 = 1/2, 3 = siempre
  final Map<String, int> statChanges; // Cambios de estadísticas, ej. {'attack': -1} (Gruñido)
  final int statChance;       // Probabilidad de esos cambios. 0 = siempre
  final bool targetsSelf;     // Los cambios (y el estado) son para quien lo usa (Danza Espada)
  final int drain;            // % del daño que recupera (+) o que pierde por retroceso (-)
  final int healing;          // % de su vida máxima que se cura (Recuperación)

  // PP que quedan. Se reinician en cada batalla (no se guardan en la BD).
  int currentPp;

  BattleMove({
    required this.name,
    required this.displayName,
    required this.power,
    required this.accuracy,
    required this.pp,
    required this.type,
    required this.damageClass,
    this.ailment,
    this.ailmentChance = 0,
    this.priority = 0,
    this.critRate = 0,
    this.statChanges = const {},
    this.statChance = 0,
    this.targetsSelf = false,
    this.drain = 0,
    this.healing = 0,
    int? currentPp,
  }) : currentPp = currentPp ?? pp;

  bool get doesDamage => (power ?? 0) > 0;
  bool get isStruggle => name == 'struggle';
  bool get hasPp => isStruggle || currentPp > 0;

  factory BattleMove.fromRawJson(String str) => BattleMove.fromJson(json.decode(str));

  factory BattleMove.fromJson(Map<String, dynamic> json) {
    // Buscamos el nombre en español dentro de la lista `names`
    final names = json['names'] as List? ?? [];
    final spanish = names.cast<Map<String, dynamic>>().where(
          (n) => n['language']?['name'] == 'es',
        );
    final meta = json['meta'] as Map<String, dynamic>?;
    final target = json['target']?['name'] as String? ?? '';

    return BattleMove(
      name: json['name'] ?? '',
      displayName: spanish.isNotEmpty ? spanish.first['name'] : (json['name'] ?? ''),
      power: json['power'],
      accuracy: json['accuracy'],
      pp: json['pp'] ?? 0,
      type: json['type']?['name'] ?? 'normal',
      damageClass: json['damage_class']?['name'] ?? 'physical',
      ailment: StatusCondition.fromPokeApiAilment(meta?['ailment']?['name']),
      ailmentChance: meta?['ailment_chance'] ?? 0,
      priority: json['priority'] ?? 0,
      critRate: meta?['crit_rate'] ?? 0,
      statChanges: _readStatChanges(json['stat_changes']),
      statChance: meta?['stat_chance'] ?? 0,
      targetsSelf: target == 'user' || target == 'user-or-ally' || target == 'user-and-allies',
      drain: meta?['drain'] ?? 0,
      healing: meta?['healing'] ?? 0,
    );
  }

  // La BD solo tiene Ataque, Defensa y Velocidad, así que los especiales se juntan
  // con los físicos (igual que en el daño). Precisión y evasión se ignoran.
  static Map<String, int> _readStatChanges(dynamic list) {
    const mapping = {
      'attack': 'attack',
      'special-attack': 'attack',
      'defense': 'defense',
      'special-defense': 'defense',
      'speed': 'speed',
    };
    final result = <String, int>{};
    for (final change in (list as List? ?? [])) {
      final stat = mapping[change['stat']?['name']];
      final amount = change['change'] as int? ?? 0;
      if (stat == null || amount == 0) continue;
      // Si un movimiento sube Ataque y Ataque Especial, cuenta una sola vez
      final current = result[stat];
      if (current == null || amount.abs() > current.abs()) result[stat] = amount;
    }
    return result;
  }

  // Movimiento de respaldo cuando ya no quedan PP (equivale a "Forcejeo").
  // Quien lo usa pierde 1/4 de su vida máxima.
  factory BattleMove.struggle() => BattleMove(
        name: 'struggle',
        displayName: 'Forcejeo',
        power: 50,
        accuracy: null,
        pp: 1,
        type: 'typeless', // No tiene tipo: le pega normal a todos (incluso a Fantasma)
        damageClass: 'physical',
      );
}
