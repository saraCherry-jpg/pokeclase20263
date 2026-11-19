import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:pokeclase20263/minijuegos/batalla/models/battle_move.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/battle_pokemon.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/status_condition.dart';
import 'package:pokeclase20263/minijuegos/batalla/providers/poke_api_provider.dart';

// Random predecible: nextInt devuelve siempre `intValue` (topado) y nextDouble `doubleValue`
class FixedRandom implements Random {
  final int intValue;
  final double doubleValue;
  final bool boolValue;

  FixedRandom({this.intValue = 0, this.doubleValue = 1.0, this.boolValue = true});

  @override
  int nextInt(int max) => intValue.clamp(0, max - 1);
  @override
  double nextDouble() => doubleValue;
  @override
  bool nextBool() => boolValue;
}

BattlePokemon makePokemon({
  int? idPokemonUser = 1,
  int idPokemon = 6,
  String name = 'charizard',
  int maxHp = 78,
  int? currentHp,
  int attack = 84,
  int defense = 78,
  int speed = 100,
  List<String> types = const ['fire', 'flying'],
}) =>
    BattlePokemon(
      idPokemonUser: idPokemonUser,
      idPokemon: idPokemon,
      name: name,
      frontSprite: '',
      backSprite: '',
      maxHp: maxHp,
      currentHp: currentHp ?? maxHp,
      attack: attack,
      defense: defense,
      speed: speed,
      types: types,
    );

BattleMove makeMove({
  String name = 'tackle',
  int? power = 40,
  int? accuracy = 100,
  int pp = 35,
  String type = 'normal',
  String damageClass = 'physical',
  StatusCondition? ailment,
  int ailmentChance = 0,
  int priority = 0,
  Map<String, int> statChanges = const {},
  bool targetsSelf = false,
  int drain = 0,
}) =>
    BattleMove(
      name: name,
      displayName: name,
      power: power,
      accuracy: accuracy,
      pp: pp,
      type: type,
      damageClass: damageClass,
      ailment: ailment,
      ailmentChance: ailmentChance,
      priority: priority,
      statChanges: statChanges,
      targetsSelf: targetsSelf,
      drain: drain,
    );

// Random que devuelve una lista de valores en orden (y luego repite el último)
class SequenceRandom implements Random {
  final List<int> ints;
  final double doubleValue;
  int _i = 0;

  SequenceRandom(this.ints, {this.doubleValue = 1.0});

  @override
  int nextInt(int max) => ints[_i < ints.length ? _i++ : ints.length - 1].clamp(0, max - 1);
  @override
  double nextDouble() => doubleValue;
  @override
  bool nextBool() => true;
}

// PokeAPI falsa: responde con JSON armado a mano, sin internet
class FakePokeApiProvider extends PokeApiProvider {
  @override
  Future<http.Response> getPokemonDetail(int id) async => http.Response(
        json.encode({
          'id': id,
          'name': 'rival$id',
          'sprites': {'front_default': 'f.png', 'back_default': 'b.png'},
          'types': [
            {'type': {'name': 'normal'}}
          ],
          'stats': [
            {'base_stat': 250, 'stat': {'name': 'hp'}},
            {'base_stat': 10, 'stat': {'name': 'attack'}},
            {'base_stat': 10, 'stat': {'name': 'defense'}},
            {'base_stat': 1, 'stat': {'name': 'speed'}},
          ],
          'moves': [
            {'move': {'name': 'growl'}},
            {'move': {'name': 'tackle'}},
            {'move': {'name': 'broken'}},
          ],
        }),
        200,
      );

  @override
  Future<http.Response> getMove(String name) async {
    if (name == 'broken') return http.Response('not found', 404);
    return http.Response(
      json.encode({
        'name': name,
        'names': [
          {'name': name == 'tackle' ? 'Placaje' : 'Gruñido', 'language': {'name': 'es'}}
        ],
        'power': name == 'tackle' ? 40 : null,
        'accuracy': 100,
        'pp': 35,
        'type': {'name': 'normal'},
        'damage_class': {'name': name == 'tackle' ? 'physical' : 'status'},
        'meta': {'ailment': {'name': 'none'}, 'ailment_chance': 0},
      }),
      200,
    );
  }
}
