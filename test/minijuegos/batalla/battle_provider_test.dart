import 'package:flutter_test/flutter_test.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/battle_result.dart';
import 'package:pokeclase20263/minijuegos/batalla/providers/battle_provider.dart';
import 'package:pokeclase20263/minijuegos/batalla/services/battle_backend.dart';

import 'helpers.dart';

BattleProvider makeBattle(MockBattleBackend backend) => BattleProvider(
      backend: backend,
      pokeApi: FakePokeApiProvider(),
      messageDelay: Duration.zero,
      random: FixedRandom(intValue: 0, doubleValue: 1.0),
    );

void main() {
  test('una batalla completa guarda la vida y el resultado', () async {
    final backend = MockBattleBackend();
    final battle = makeBattle(backend);
    final player = (await backend.getMyPokemon('usuario-demo')).first; // Charizard

    await battle.start([player]);
    expect(battle.phase, BattlePhase.choosingAction);
    expect(battle.enemy!.maxHp, 100); // HP base 250 topado a 100
    // El movimiento que falló al cargar se salta; se prefieren los que hacen daño
    expect(player.moves.first.displayName, 'Placaje');

    var turns = 0;
    while (battle.phase != BattlePhase.finished && turns < 50) {
      await battle.openFight();
      await battle.useMove(player.moves.first);
      turns++;
    }

    expect(battle.phase, BattlePhase.finished);
    expect(battle.outcome, BattleOutcome.won);
    expect(battle.playerWon, isTrue);
    expect(player.moves.first.currentPp, 35 - turns); // Cada ataque gastó 1 PP
    expect(backend.savedBattles.single['resultado'], 'Victoria');
    expect(backend.savedBattles.single['pokemonUserR'], player.idPokemonUser);
    final updated = (await backend.getMyPokemon('usuario-demo')).first;
    expect(updated.currentHp, player.currentHp);
  });

  test('si el primero se debilita hay que elegir otro, sin perder el turno', () async {
    final backend = MockBattleBackend();
    final battle = makeBattle(backend);
    final mine = await backend.getMyPokemon('usuario-demo');
    // Pega muy poco para que el rival alcance a atacar
    final charizard = makePokemon(idPokemonUser: 1, attack: 1, currentHp: 1, types: ['water']);
    final blastoise = mine[1];

    await battle.start([charizard, blastoise]);
    await battle.openFight();
    await battle.useMove(charizard.moves.first); // El rival lo debilita

    expect(charizard.isFainted, isTrue);
    expect(battle.phase, BattlePhase.choosingReplacement);

    await battle.switchTo(0); // No se puede elegir al debilitado
    expect(battle.phase, BattlePhase.choosingReplacement);

    final hpBefore = blastoise.currentHp;
    await battle.switchTo(1);
    expect(battle.player, same(blastoise));
    expect(battle.phase, BattlePhase.choosingAction);
    expect(blastoise.currentHp, hpBefore); // El rival no atacó al entrar
  });

  test('cambiar de Pokémon por gusto gasta el turno', () async {
    final backend = MockBattleBackend();
    final battle = makeBattle(backend);
    final mine = await backend.getMyPokemon('usuario-demo');
    await battle.start([mine[0], mine[1]]);

    battle.openTeam();
    expect(battle.phase, BattlePhase.choosingPokemon);
    await battle.switchTo(1);

    expect(battle.player, same(mine[1]));
    expect(mine[1].currentHp, lessThan(mine[1].maxHp)); // El rival le pegó al que entró
    expect(battle.phase, BattlePhase.choosingAction);
  });

  test('usar una Poción gasta el objeto y el turno; si no sirve, no se gasta', () async {
    final backend = MockBattleBackend();
    final battle = makeBattle(backend);
    final mine = await backend.getMyPokemon('usuario-demo');
    final charizard = mine[0];
    final pikachu = mine[2]; // 20/35
    await battle.start([charizard, pikachu], userId: 'usuario-demo');

    // La Poké Ball no aparece en la mochila de batalla
    expect(battle.usableItems.map((b) => b.item.nombre), ['Poción', 'Revivir', 'Antídoto']);
    final potion = battle.usableItems.first;

    battle.openBag();
    battle.selectItem(potion);
    await battle.useItemOn(0); // Charizard tiene la vida llena
    expect(battle.message, 'No tendría ningún efecto.');
    expect(battle.phase, BattlePhase.choosingItem);
    expect(potion.cantidad, 3);

    battle.selectItem(potion);
    await battle.useItemOn(1);
    expect(pikachu.currentHp, 35);
    expect(potion.cantidad, 2);
    expect(charizard.currentHp, lessThan(charizard.maxHp)); // El rival atacó
    expect(battle.phase, BattlePhase.choosingAction);

    final bag = await backend.getMyItems('usuario-demo');
    expect(bag.firstWhere((b) => b.item.nombre == 'Poción').cantidad, 2);
  });

  test('al ganar se sortea un premio y se guarda en la mochila', () async {
    final backend = MockBattleBackend();
    final battle = makeBattle(backend);
    final player = (await backend.getMyPokemon('usuario-demo')).first;
    await battle.start([player], userId: 'usuario-demo');

    while (battle.phase != BattlePhase.finished) {
      await battle.openFight();
      await battle.useMove(player.moves.first);
    }

    expect(battle.outcome, BattleOutcome.won);
    // Con doubleValue 1.0 sale el último objeto de batalla del catálogo (Cura Total).
    // La Poké Ball está después en el catálogo, pero no entra al sorteo.
    expect(battle.reward!.nombre, 'Cura Total');
    expect(battle.message, '¡Ganaste la batalla! Encontraste: Cura Total.');
    final bag = await backend.getMyItems('usuario-demo');
    expect(bag.firstWhere((b) => b.item.nombre == 'Cura Total').cantidad, 1);
  });

  test('huir guarda la batalla como Huida y también la vida', () async {
    final backend = MockBattleBackend();
    final battle = makeBattle(backend);
    final mine = await backend.getMyPokemon('usuario-demo');
    final pikachu = mine[2]..currentHp = 10;
    await battle.start([pikachu]);

    await battle.flee(); // Pikachu (90) es más rápido que el rival (1)

    expect(battle.phase, BattlePhase.finished);
    expect(battle.outcome, BattleOutcome.fled);
    expect(battle.playerWon, isNull);
    expect(backend.savedBattles.single['resultado'], 'Huida');
    final history = await backend.getMyBattles('usuario-demo');
    expect(history.single.resultado, BattleResultado.huida);
    expect(history.single.nombre, 'pikachu');
    final updated = (await backend.getMyPokemon('usuario-demo'))[2];
    expect(updated.currentHp, 10);
  });

  test('tocar el cuadro de texto pasa al siguiente mensaje sin esperar', () async {
    final backend = MockBattleBackend();
    final battle = BattleProvider(
      backend: backend,
      pokeApi: FakePokeApiProvider(),
      messageDelay: const Duration(hours: 1), // Sin tocar, el turno no terminaría
      random: FixedRandom(intValue: 0, doubleValue: 1.0),
    );
    final player = (await backend.getMyPokemon('usuario-demo')).first;
    await battle.start([player]);
    await battle.openFight();

    final turn = battle.useMove(player.moves.first);
    var shown = 0;
    while (battle.phase == BattlePhase.busy && shown < 50) {
      await Future<void>.delayed(Duration.zero);
      battle.advanceMessage();
      shown++;
    }
    await turn;
    expect(battle.phase, isNot(BattlePhase.busy));
    expect(shown, greaterThan(1));
  });

  test('la mochila solo deja elegir objetos y Pokémon a los que les sirven', () async {
    final backend = MockBattleBackend();
    final battle = makeBattle(backend);
    final player = (await backend.getMyPokemon('usuario-demo')).first; // Charizard sano
    await battle.start([player], userId: 'usuario-demo');

    final potion = battle.bag.firstWhere((b) => b.item.nombre == 'Poción');
    final revive = battle.bag.firstWhere((b) => b.item.nombre == 'Revivir');
    expect(battle.canUseItem(revive), isFalse); // Nadie está debilitado

    player.currentHp = player.maxHp ~/ 2;
    expect(battle.canUseItem(potion), isTrue);
    battle.openBag();
    battle.selectItem(potion);
    expect(battle.canUseItemOn(0), isTrue);

    battle.backToBag();
    expect(battle.phase, BattlePhase.choosingItem);
    expect(battle.selectedItem, isNull);
  });
}
