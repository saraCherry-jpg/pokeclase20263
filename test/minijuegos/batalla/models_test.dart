import 'package:flutter_test/flutter_test.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/battle_item.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/battle_move.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/battle_pokemon.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/battle_result.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/status_condition.dart';

void main() {
  test('BattlePokemon se lee con la forma de PokemonUser + PokemonEstado', () {
    final p = BattlePokemon.fromJson({
      'id': 3,
      'idPokemon': 25,
      'idUsuario': 'abc',
      'nombre': 'pikachu',
      'pokemonEstado': {
        'vidaTotal': 35,
        'vidaActual': 20,
        'estado': 5,
        'ataqueBase': 55,
        'defensaBase': 40,
        'velocidadBase': 90,
        'tipoPrimario': 'Electric',
        'tipoSecundario': null,
        'urlFrontal': 'f.png',
        'urlTrasera': 'b.png',
      },
    });
    expect(p.idPokemonUser, 3);
    expect(p.maxHp, 35);
    expect(p.currentHp, 20);
    expect(p.status, StatusCondition.paralizado);
    expect(p.types, ['electric']);
    expect(p.toEstadoJson(), {'vidaActual': 20, 'estado': 5});
    expect(StatusCondition.fromDb('Paralizado'), StatusCondition.paralizado);
    expect(StatusCondition.congelado.dbId, 7);
  });

  test('PokemonUser con pokemonEstado null usa valores por defecto y el sprite de idPokemon', () {
    // Así lo devuelve hoy el backend justo después de POST /api/PokemonUser
    final p = BattlePokemon.fromJson({
      'id': 1,
      'idPokemon': 25,
      'idUsuario': 'abc',
      'nombre': 'pikachu',
      'pokemonEstado': null,
    });
    expect(p.maxHp, 100);
    expect(p.currentHp, 100);
    expect(p.types, ['normal']);
    expect(p.frontSprite, endsWith('/pokemon/25.png'));
    expect(p.backSprite, endsWith('/pokemon/back/25.png'));
  });

  test('el rival de la PokeAPI tiene la vida topada a 100', () {
    final p = BattlePokemon.fromPokeApiJson({
      'id': 242,
      'name': 'blissey',
      'sprites': {'front_default': 'f.png', 'back_default': null},
      'types': [
        {'type': {'name': 'normal'}}
      ],
      'stats': [
        {'base_stat': 255, 'stat': {'name': 'hp'}},
        {'base_stat': 10, 'stat': {'name': 'attack'}},
      ],
    });
    expect(p.isComputer, isTrue);
    expect(p.maxHp, 100);
    expect(p.currentHp, 100);
    expect(p.backSprite, 'f.png');
  });

  test('Estado acepta texto o id del 1 al 7', () {
    expect(StatusCondition.fromDb('quemado'), StatusCondition.quemado);
    expect(StatusCondition.fromDb(7), StatusCondition.congelado);
    expect(StatusCondition.fromDb(null), StatusCondition.sano);
  });

  test('BattleMove toma el nombre en español y el estado que causa', () {
    final m = BattleMove.fromJson({
      'name': 'flamethrower',
      'names': [
        {'name': 'Lanzallamas', 'language': {'name': 'es'}}
      ],
      'power': 90,
      'accuracy': 100,
      'pp': 15,
      'type': {'name': 'fire'},
      'damage_class': {'name': 'special'},
      'meta': {'ailment': {'name': 'burn'}, 'ailment_chance': 10},
    });
    expect(m.displayName, 'Lanzallamas');
    expect(m.ailment, StatusCondition.quemado);
    expect(m.ailmentChance, 10);
  });

  test('BattleResult manda resultado como texto', () {
    final r = BattleResult(idPokemonUserRetador: 3, idPokemonRival: 150, resultado: BattleResultado.derrota);
    expect(r.toJson(), {'pokemonUserR': 3, 'idPokemonRival': 150, 'resultado': 'Derrota'});
    expect(BattleResultado.fromJson(3), BattleResultado.huida); // Por si llega como número
  });

  test('BattleMove lee prioridad, crítico, cambios de estadísticas y a quién afectan', () {
    final move = BattleMove.fromJson({
      'name': 'nasty-plot',
      'names': [],
      'power': null,
      'accuracy': null,
      'pp': 20,
      'priority': 0,
      'type': {'name': 'dark'},
      'damage_class': {'name': 'status'},
      'target': {'name': 'user'},
      'stat_changes': [
        {'change': 2, 'stat': {'name': 'special-attack'}},
      ],
      'meta': {'ailment': {'name': 'none'}, 'ailment_chance': 0, 'crit_rate': 0, 'stat_chance': 0},
    });
    expect(move.statChanges, {'attack': 2}); // El especial se junta con el físico
    expect(move.targetsSelf, isTrue);
    expect(move.currentPp, 20);

    final quick = BattleMove.fromJson({'name': 'quick-attack', 'priority': 1, 'pp': 30, 'power': 40});
    expect(quick.priority, 1);
    expect(quick.targetsSelf, isFalse);
  });

  test('ItemUser se lee con su Item; sin Efecto se deduce por el nombre', () {
    final bag = BagItem.fromJson({
      'id': 7,
      'idItem': 5,
      'idUser': 'abc',
      'cantidad': 2,
      'item': {'nombre': 'Antídoto', 'probabilidad': 0.15, 'urlImagen': 'a.png'},
    });
    expect(bag.idItemUser, 7);
    expect(bag.item.id, 5);
    expect(bag.item.efecto, ItemEffect.curarEstado);
    expect(bag.item.curedStatus, StatusCondition.envenenado);
    expect(bag.item.probabilidad, 0.15);

    final withColumns = ItemInfo.fromJson({'id': 1, 'nombre': 'Algo', 'efecto': 'Curar', 'valor': 35});
    expect(withColumns.efecto, ItemEffect.curar);
    expect(withColumns.valor, 35);
    expect(ItemInfo.fromJson({'id': 3, 'nombre': 'Antídoto', 'efecto': 'curar_estado', 'valor': 4}).efecto,
        ItemEffect.curarEstado);
    expect(ItemInfo.fromJson({'id': 2, 'nombre': 'Ultra Ball'}).usableInBattle, isFalse);
  });

  test('BattleResult lee el formato nuevo con resultado', () {
    final r = BattleResult.fromJson({
      'id': 41,
      'fecha': '2026-10-22T16:40:00Z',
      'resultado': 'Victoria',
      'idPokemonRival': 19,
      'pokemon': {'id': 12, 'idPokemon': 25, 'nombre': 'Pikachu'},
    });
    expect(r.playerWon, isTrue);
    expect(r.idPokemonRival, 19);
    expect(r.idPokemonUserRetador, 12);
    expect(r.nombre, 'Pikachu');
  });

  test('BattleSummary no cuenta las huidas en el porcentaje', () {
    BattleResult b(BattleResultado r) => BattleResult(idPokemonUserRetador: 1, idPokemonRival: 1, resultado: r);
    final s = BattleSummary.fromBattles([
      b(BattleResultado.victoria),
      b(BattleResultado.victoria),
      b(BattleResultado.derrota),
      b(BattleResultado.huida),
    ]);
    expect(s.huidas, 1);
    expect(s.winRate, closeTo(2 / 3, 0.001));
    expect(BattleSummary.fromBattles([b(BattleResultado.huida)]).winRate, isNull);
  });
}
