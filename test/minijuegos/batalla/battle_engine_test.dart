import 'package:flutter_test/flutter_test.dart';
import 'package:pokeclase20263/minijuegos/batalla/logic/battle_engine.dart';
import 'package:pokeclase20263/minijuegos/batalla/logic/type_chart.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/battle_item.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/battle_move.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/status_condition.dart';

import 'helpers.dart';

void main() {
  group('efectividad de tipos', () {
    test('fuego contra planta es x2 y contra agua es x0.5', () {
      expect(typeEffectiveness('fire', ['grass']), 2);
      expect(typeEffectiveness('fire', ['water']), 0.5);
    });

    test('se multiplica con doble tipo y acepta nombres en español', () {
      expect(typeEffectiveness('electric', ['water', 'flying']), 4);
      expect(typeEffectiveness('Tierra', ['Volador']), 0);
    });
  });

  group('daño', () {
    test('con variación máxima y sin STAB da el valor de la fórmula', () {
      final engine = BattleEngine(random: FixedRandom(doubleValue: 1.0));
      final attacker = makePokemon(attack: 100, types: ['water']);
      final defender = makePokemon(defense: 100, types: ['normal']);
      // (((2*50/5+2) * 40 * 100/100) / 50 + 2) * 0.5 = 9.8
      expect(engine.calculateDamage(attacker, defender, makeMove()), 9);
    });

    test('STAB y súper eficaz suben el daño', () {
      final engine = BattleEngine(random: FixedRandom(doubleValue: 1.0));
      final attacker = makePokemon(attack: 100, types: ['fire']);
      final defender = makePokemon(defense: 100, types: ['grass']);
      final move = makeMove(type: 'fire');
      // 9.8 * 1.5 * 2 = 29.4
      expect(engine.calculateDamage(attacker, defender, move), 29);
    });

    test('la quemadura baja a la mitad el daño físico', () {
      final engine = BattleEngine(random: FixedRandom(doubleValue: 1.0));
      final attacker = makePokemon(attack: 100, types: ['water'])..status = StatusCondition.quemado;
      final defender = makePokemon(defense: 100, types: ['normal']);
      // (((22 * 40 * 50/100) / 50) + 2) * 0.5 = 5.4
      expect(engine.calculateDamage(attacker, defender, makeMove()), 5);
    });

    test('inmunidad no hace daño y un movimiento de estado tampoco', () {
      final engine = BattleEngine(random: FixedRandom());
      final ghost = makePokemon(types: ['ghost']);
      expect(engine.calculateDamage(makePokemon(), ghost, makeMove()), 0);
      expect(engine.calculateDamage(makePokemon(), ghost, makeMove(power: null)), 0);
    });
  });

  group('turnos', () {
    test('el más rápido ataca primero y la parálisis baja la velocidad', () {
      final engine = BattleEngine(random: FixedRandom());
      final fast = makePokemon(speed: 100);
      final slow = makePokemon(speed: 60);
      expect(engine.playerGoesFirst(fast, slow), isTrue);
      fast.status = StatusCondition.paralizado;
      expect(engine.playerGoesFirst(fast, slow), isFalse);
    });

    test('la vida nunca baja de 0 y se anuncia quién se debilitó', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 0, doubleValue: 1.0));
      final player = makePokemon(attack: 200, speed: 100, types: ['water']);
      final enemy = makePokemon(idPokemonUser: null, name: 'rattata', currentHp: 5, speed: 10, types: ['normal']);

      final events = engine.runTurn(player, enemy, makeMove(power: 90), makeMove());

      expect(enemy.currentHp, 0);
      expect(enemy.isFainted, isTrue);
      expect(player.currentHp, player.maxHp); // El rival no alcanzó a atacar
      expect(events.last.message, '¡Rattata rival se debilitó!');
    });

    test('un ataque puede fallar según la precisión', () {
      // nextInt devuelve 99, así que un ataque con precisión 50 falla
      final engine = BattleEngine(random: FixedRandom(intValue: 99));
      final player = makePokemon(speed: 100);
      final enemy = makePokemon(idPokemonUser: null, speed: 10);
      final events = engine.runTurn(player, enemy, makeMove(accuracy: 50), makeMove(accuracy: 50));
      expect(events.where((e) => e.message == '¡Pero falló!').length, 2);
      expect(enemy.currentHp, enemy.maxHp);
    });

    test('el veneno quita 1/8 de la vida al final del turno', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 99));
      final player = makePokemon(maxHp: 80)..status = StatusCondition.envenenado;
      final enemy = makePokemon(idPokemonUser: null, maxHp: 80);
      engine.runTurn(player, enemy, makeMove(accuracy: 1), makeMove(accuracy: 1));
      expect(player.currentHp, 70);
    });

    test('un Pokémon dormido no ataca y luego se despierta', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 0, doubleValue: 1.0));
      final player = makePokemon(speed: 100)
        ..status = StatusCondition.dormido
        ..statusTurns = 1;
      final enemy = makePokemon(idPokemonUser: null, speed: 10, maxHp: 100);

      engine.runTurn(player, enemy, makeMove(), makeMove(power: null));
      expect(enemy.currentHp, 100);
      expect(player.status, StatusCondition.dormido);

      engine.runTurn(player, enemy, makeMove(), makeMove(power: null));
      expect(player.status, StatusCondition.sano);
      expect(enemy.currentHp, lessThan(100));
    });
  });

  group('críticos y prioridad', () {
    test('un crítico hace x1.5', () {
      final engine = BattleEngine(random: FixedRandom(doubleValue: 1.0));
      final attacker = makePokemon(attack: 100, types: ['water']);
      final defender = makePokemon(defense: 100, types: ['normal']);
      // 9.8 * 1.5 = 14.7
      expect(engine.calculateDamage(attacker, defender, makeMove(), critical: true), 14);
    });

    test('la probabilidad normal de crítico es 1/24', () {
      expect(BattleEngine(random: FixedRandom(intValue: 0)).rollCritical(makeMove()), isTrue);
      expect(BattleEngine(random: FixedRandom(intValue: 99)).rollCritical(makeMove()), isFalse);
    });

    test('un movimiento con prioridad va primero aunque sea más lento', () {
      final engine = BattleEngine(random: FixedRandom());
      final slow = makePokemon(speed: 10);
      final fast = makePokemon(speed: 200);
      expect(
        engine.playerGoesFirst(slow, fast,
            playerMove: makeMove(name: 'quick-attack', priority: 1), enemyMove: makeMove()),
        isTrue,
      );
    });
  });

  group('PP y Forcejeo', () {
    test('usar un movimiento gasta 1 PP aunque falle', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 99));
      final move = makeMove(pp: 5, accuracy: 50);
      engine.runTurn(makePokemon(speed: 100), makePokemon(idPokemonUser: null, speed: 1), move,
          makeMove(power: null, accuracy: null));
      expect(move.currentPp, 4);
    });

    test('sin PP la computadora usa Forcejeo y se hace daño', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 99, doubleValue: 1.0));
      final enemy = makePokemon(idPokemonUser: null, maxHp: 80, speed: 200)
        ..moves = [makeMove(pp: 1)..currentPp = 0];
      final player = makePokemon(maxHp: 100, speed: 1);
      expect(engine.mustStruggle(enemy), isTrue);

      final move = engine.pickEnemyMove(enemy, player);
      expect(move.isStruggle, isTrue);
      final events = engine.runTurn(player, enemy, null, move);
      expect(enemy.currentHp, 60); // Pierde 1/4 de 80
      expect(events.map((e) => e.message), contains('¡Charizard rival también se hizo daño!'));
    });
  });

  group('estados', () {
    test('los de tipo Fuego no se queman', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 0, doubleValue: 1.0));
      final burn = makeMove(type: 'fire', power: 90, ailment: StatusCondition.quemado, ailmentChance: 100);
      final fire = makePokemon(idPokemonUser: null, maxHp: 100, speed: 1, types: ['fire']);
      final water = makePokemon(idPokemonUser: null, maxHp: 100, speed: 1, types: ['water']);
      engine.runTurn(makePokemon(speed: 100), fire, burn, makeMove(power: null, accuracy: null));
      engine.runTurn(makePokemon(speed: 100), water, burn, makeMove(power: null, accuracy: null));
      expect(fire.status, StatusCondition.sano);
      expect(water.status, StatusCondition.quemado);
    });

    test('un movimiento de estado contra un inmune avisa que no afecta', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 0));
      final thunderWave = makeMove(power: null, type: 'electric', ailment: StatusCondition.paralizado);
      final pikachu = makePokemon(idPokemonUser: null, name: 'pikachu', speed: 1, types: ['electric']);
      final events = engine.runTurn(makePokemon(speed: 100), pikachu, thunderWave,
          makeMove(power: null, accuracy: null));
      expect(pikachu.status, StatusCondition.sano);
      expect(events.map((e) => e.message), contains('No afecta a Pikachu rival...'));
    });

    test('si llega dormido desde la BD sigue dormido en su primer turno', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 0, doubleValue: 1.0));
      final player = makePokemon(speed: 100)..status = StatusCondition.dormido; // statusTurns = 0
      final enemy = makePokemon(idPokemonUser: null, speed: 1, maxHp: 100);
      engine.prepareForBattle(player);
      engine.runTurn(player, enemy, makeMove(), makeMove(power: null, accuracy: null));
      expect(enemy.currentHp, 100);
    });

    test('al salir de la batalla se pierde la confusión y los cambios de estadísticas', () {
      final engine = BattleEngine(random: FixedRandom());
      final p = makePokemon()
        ..status = StatusCondition.confundido
        ..stages['attack'] = 3;
      engine.leaveBattle(p);
      expect(p.status, StatusCondition.sano);
      expect(p.stages['attack'], 0);
    });
  });

  group('cambios de estadísticas', () {
    test('Danza Espada sube mucho el Ataque y duplica el daño', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 99, doubleValue: 1.0));
      final player = makePokemon(attack: 100, speed: 100, types: ['water']);
      final enemy = makePokemon(idPokemonUser: null, defense: 100, speed: 1, types: ['normal']);
      final swordsDance = makeMove(
          name: 'swords-dance', power: null, accuracy: null, statChanges: {'attack': 2}, targetsSelf: true);

      final events = engine.runTurn(player, enemy, swordsDance, makeMove(power: null, accuracy: null));
      expect(player.stages['attack'], 2);
      expect(events.map((e) => e.message), contains('¡El Ataque de Charizard subió mucho!'));
      // (((22 * 40 * 200/100) / 50) + 2) * 0.5 = 18.6
      expect(engine.calculateDamage(player, enemy, makeMove()), 18);
    });

    test('Gruñido baja el Ataque del rival y no pasa de -6', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 0));
      final enemy = makePokemon(idPokemonUser: null, name: 'rattata', speed: 1)..stages['attack'] = -6;
      final growl = makeMove(name: 'growl', power: null, statChanges: {'attack': -1});
      final events = engine.runTurn(makePokemon(speed: 100), enemy, growl, makeMove(power: null, accuracy: null));
      expect(enemy.stages['attack'], -6);
      expect(events.map((e) => e.message), contains('¡El Ataque de Rattata rival no puede bajar más!'));
    });

    test('la Velocidad subida cambia quién ataca primero', () {
      final engine = BattleEngine(random: FixedRandom());
      final slow = makePokemon(speed: 60)..stages['speed'] = 2;
      expect(engine.playerGoesFirst(slow, makePokemon(speed: 100)), isTrue);
    });
  });

  group('rival', () {
    test('prefiere el movimiento súper eficaz', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 0));
      final enemy = makePokemon(idPokemonUser: null, types: ['normal'])
        ..moves = [makeMove(name: 'tackle'), makeMove(name: 'ember', type: 'fire')];
      expect(engine.pickEnemyMove(enemy, makePokemon(types: ['grass'])).name, 'ember');
    });

    test('nunca usa un movimiento que no afecta', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 99));
      final enemy = makePokemon(idPokemonUser: null, types: ['water'])
        ..moves = [makeMove(name: 'tackle'), makeMove(name: 'ember', type: 'fire', power: 10)];
      expect(engine.pickEnemyMove(enemy, makePokemon(types: ['ghost'])).name, 'ember');
    });
  });

  group('huir', () {
    test('si eres más rápido siempre escapas', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 255));
      expect(engine.tryToFlee(makePokemon(speed: 100), makePokemon(speed: 50), 0), isTrue);
    });

    test('si eres más lento cada intento fallido ayuda', () {
      final engine = BattleEngine(random: FixedRandom(intValue: 200));
      final slow = makePokemon(speed: 50);
      final fast = makePokemon(speed: 100);
      expect(engine.tryToFlee(slow, fast, 0), isFalse); // 64 < 200
      expect(engine.tryToFlee(slow, fast, 5), isTrue);  // 64 + 150 = 214
    });
  });

  group('objetos', () {
    ItemInfo item(ItemEffect efecto, int valor) =>
        ItemInfo(id: 1, nombre: 'x', efecto: efecto, valor: valor);

    test('Poción cura sin pasarse del máximo y no se gasta con la vida llena', () {
      final engine = BattleEngine();
      final p = makePokemon(maxHp: 100, currentHp: 90);
      expect(engine.applyItem(item(ItemEffect.curar, 20), p), '¡Charizard recuperó 10 PS!');
      expect(p.currentHp, 100);
      expect(engine.applyItem(item(ItemEffect.curar, 20), p), isNull);
    });

    test('Revivir solo sirve con un Pokémon debilitado', () {
      final engine = BattleEngine();
      final p = makePokemon(maxHp: 80, currentHp: 0)..status = StatusCondition.quemado;
      expect(engine.applyItem(item(ItemEffect.revivir, 50), makePokemon()), isNull);
      expect(engine.applyItem(item(ItemEffect.revivir, 50), p), isNotNull);
      expect(p.currentHp, 40);
      expect(p.status, StatusCondition.sano);
    });

    test('Antídoto solo cura el veneno y Cura Total cura todo', () {
      final engine = BattleEngine();
      final paralyzed = makePokemon()..status = StatusCondition.paralizado;
      expect(engine.applyItem(item(ItemEffect.curarEstado, 4), paralyzed), isNull);
      expect(engine.applyItem(item(ItemEffect.curarEstado, 0), paralyzed), isNotNull);
      expect(paralyzed.status, StatusCondition.sano);
    });

    test('el premio se sortea según la probabilidad', () {
      final catalog = [
        ItemInfo(id: 1, nombre: 'Nada', efecto: ItemEffect.ninguno, probabilidad: 0),
        ItemInfo(id: 2, nombre: 'Poción', efecto: ItemEffect.curar, probabilidad: 30),
        ItemInfo(id: 3, nombre: 'Revivir', efecto: ItemEffect.revivir, probabilidad: 10),
        ItemInfo(id: 4, nombre: 'Poké Ball', efecto: ItemEffect.pokeball, probabilidad: 1000),
      ];
      expect(BattleEngine(random: FixedRandom(doubleValue: 0.0)).rollReward(catalog)!.id, 2);
      expect(BattleEngine(random: FixedRandom(doubleValue: 0.9)).rollReward(catalog)!.id, 3);
      expect(BattleEngine().rollReward([]), isNull);
      // La Poké Ball tiene muchísima probabilidad, pero nunca sale como premio
      expect(BattleEngine(random: FixedRandom(doubleValue: 0.999)).rollReward(catalog)!.id, 3);
    });
  });

  test('Absorber recupera la mitad del daño hecho', () {
    final engine = BattleEngine(random: FixedRandom(intValue: 99, doubleValue: 1.0));
    final player = makePokemon(attack: 100, maxHp: 100, currentHp: 50, speed: 100, types: ['water']);
    final enemy = makePokemon(idPokemonUser: null, defense: 100, maxHp: 100, speed: 1, types: ['normal']);
    engine.runTurn(player, enemy, makeMove(drain: 50), makeMove(power: null, accuracy: null));
    expect(enemy.currentHp, 91); // 9 de daño
    expect(player.currentHp, 54); // 9 * 50% = 4
  });

  test('Forcejeo no tiene tipo: le pega hasta a un Fantasma', () {
    expect(typeEffectiveness(BattleMove.struggle().type, ['ghost']), 1);
  });
}
