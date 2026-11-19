import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/battle_engine.dart';
import '../models/battle_item.dart';
import '../models/battle_move.dart';
import '../models/battle_pokemon.dart';
import '../models/battle_result.dart';
import '../models/status_condition.dart';
import '../services/battle_backend.dart';
import 'poke_api_provider.dart';

// En qué parte de la batalla estamos. La pantalla dibuja un menú distinto en cada una.
enum BattlePhase {
  loading,
  choosingAction,      // Menú principal: Luchar / Mochila / Pokémon / Huir
  choosingMove,        // Lista de movimientos
  choosingPokemon,     // Cambiar de Pokémon (gasta el turno)
  choosingItem,        // Mochila
  choosingItemTarget,  // A quién se le da el objeto
  choosingReplacement, // El tuyo se debilitó: elige otro (no gasta turno)
  busy,                // Se están mostrando los mensajes del turno
  finished,
  error,
}

enum BattleOutcome { won, lost, fled }

// Estado de UNA batalla. Se crea al abrir la pantalla de batalla y se descarta al salir.
class BattleProvider extends ChangeNotifier {
  static const int maxPokedexId = 1025; // Pokémon disponibles en la PokeAPI
  static const int maxTeamSize = 6;
  static const int _moveCandidates = 12; // Movimientos que se revisan para elegir 4
  static const int _rivalAttempts = 5;   // Intentos para encontrar un rival parejo
  static const double _rivalTolerance = 0.3; // +-30% de la suma de estadísticas

  final BattleBackend backend;
  final PokeApiProvider pokeApi;
  final BattleEngine engine;
  final Duration messageDelay; // Cuánto dura cada mensaje si no se toca (0 en los tests)
  final Random _random;

  BattleProvider({
    required this.backend,
    required this.pokeApi,
    BattleEngine? engine,
    this.messageDelay = const Duration(milliseconds: 1600),
    Random? random,
  })  : engine = engine ?? BattleEngine(random: random),
        _random = random ?? Random();

  BattlePhase phase = BattlePhase.loading;
  List<BattlePokemon> team = [];
  int activeIndex = 0;
  BattlePokemon? enemy;
  String? userId; // Nulo = sin mochila ni premio (por ejemplo, en pruebas)
  List<BagItem> bag = [];
  BagItem? selectedItem;
  ItemInfo? lastItemUsed; // Para dibujar el ícono del objeto en la animación
  ItemInfo? reward;
  BattleOutcome? outcome;
  String message = 'Buscando un rival...';
  String? errorMessage;
  bool saveFailed = false;
  int _failedFleeAttempts = 0;

  // Lo que se muestra en pantalla (va un paso atrás de la lógica para animar los mensajes)
  int playerHpShown = 0;
  int enemyHpShown = 0;
  StatusCondition playerStatusShown = StatusCondition.sano;
  StatusCondition enemyStatusShown = StatusCondition.sano;
  // Último evento mostrado: la parte visual lo usa para saber qué animar
  BattleEvent? lastEvent;

  bool _disposed = false;
  Completer<void>? _messageWait; // Se completa al tocar el cuadro de texto
  List<BattlePokemon> _startTeam = []; // Para Reintentar si falla la carga

  BattlePokemon? get player => team.isEmpty ? null : team[activeIndex];
  bool get allFainted => team.every((p) => p.isFainted);
  bool? get playerWon => switch (outcome) {
        BattleOutcome.won => true,
        BattleOutcome.lost => false,
        _ => null,
      };
  List<BagItem> get usableItems =>
      bag.where((b) => b.cantidad > 0 && b.item.usableInBattle).toList();

  // Un objeto se puede elegir si le sirve a alguien del equipo
  bool canUseItem(BagItem bagItem) =>
      bagItem.cantidad > 0 && team.any((p) => engine.canApplyItem(bagItem.item, p));

  // Si el objeto elegido le sirve al Pokémon del equipo en `index`
  bool canUseItemOn(int index) {
    final bagItem = selectedItem;
    return bagItem != null && index >= 0 && index < team.length && engine.canApplyItem(bagItem.item, team[index]);
  }

  // Carga los movimientos del equipo y genera un rival aleatorio de la computadora
  Future<void> start(List<BattlePokemon> myTeam, {String? userId}) async {
    _startTeam = myTeam;
    this.userId = userId;
    try {
      final alive = myTeam.where((p) => !p.isFainted).take(maxTeamSize).toList();
      if (alive.isEmpty) throw Exception('Todos tus Pokémon están debilitados.');
      team = alive;
      activeIndex = 0;

      await Future.wait(team.map((p) async {
        final json = await _fetchPokemonJson(p.idPokemon);
        if (p.name.isEmpty) p.name = json['name'] ?? '';
        p.moves = await _loadMoves(json);
        engine.prepareForBattle(p);
      }));

      final enemyJson = await _findRival(team.first);
      final rival = BattlePokemon.fromPokeApiJson(enemyJson);
      rival.moves = await _loadMoves(enemyJson);
      enemy = rival;

      if (userId != null) {
        try {
          bag = await backend.getMyItems(userId);
        } catch (_) {
          bag = []; // Sin mochila no se cancela la batalla
        }
      }

      _syncShown();
      message = '¡Apareció ${engine.label(rival)}! ¡Adelante, ${engine.label(player!)}!';
      lastEvent = engine.snapshot(message, player!, rival, kind: BattleEventKind.switchIn, target: player);
      phase = BattlePhase.choosingAction;
    } catch (e) {
      errorMessage = 'No se pudo cargar la batalla. Revisa tu conexión e inténtalo de nuevo.';
      debugPrint('Error al preparar la batalla: $e');
      phase = BattlePhase.error;
    }
    _notify();
  }

  // Reintentar cuando la carga falló (sin internet, PokeAPI caída...)
  Future<void> retry() async {
    if (phase != BattlePhase.error) return;
    phase = BattlePhase.loading;
    errorMessage = null;
    message = 'Buscando un rival...';
    _notify();
    await start(_startTeam, userId: userId);
  }

  // Tocar el cuadro de texto pasa al siguiente mensaje sin esperar
  void advanceMessage() {
    final wait = _messageWait;
    if (wait != null && !wait.isCompleted) wait.complete();
  }

  // ---------------------------------------------------------------- Menús

  Future<void> openFight() async {
    if (phase != BattlePhase.choosingAction) return;
    // Sin PP en ningún movimiento: se usa Forcejeo directamente, como en los juegos
    if (engine.mustStruggle(player!)) {
      phase = BattlePhase.choosingMove;
      await useMove(BattleMove.struggle());
      return;
    }
    phase = BattlePhase.choosingMove;
    _notify();
  }

  void openTeam() => _openMenu(BattlePhase.choosingPokemon);
  void openBag() => _openMenu(BattlePhase.choosingItem);

  void _openMenu(BattlePhase menu) {
    if (phase != BattlePhase.choosingAction) return;
    phase = menu;
    _notify();
  }

  // Desde "¿En quién usar...?" se regresa a la mochila
  void backToBag() {
    if (phase != BattlePhase.choosingItemTarget) return;
    selectedItem = null;
    phase = BattlePhase.choosingItem;
    _notify();
  }

  void backToMenu() {
    const menus = [
      BattlePhase.choosingMove,
      BattlePhase.choosingPokemon,
      BattlePhase.choosingItem,
      BattlePhase.choosingItemTarget,
    ];
    if (!menus.contains(phase)) return;
    selectedItem = null;
    phase = BattlePhase.choosingAction;
    message = '¿Qué hará ${engine.label(player!)}?';
    _notify();
  }

  // ---------------------------------------------------------------- Acciones

  // Luchar: el jugador eligió un movimiento
  Future<void> useMove(BattleMove move) async {
    if (phase != BattlePhase.choosingMove || !move.hasPp) return;
    await _playTurn(move);
  }

  // Pokémon: cambiar al del índice `index`. Si el activo se debilitó no gasta turno.
  Future<void> switchTo(int index) async {
    final forced = phase == BattlePhase.choosingReplacement;
    if (!forced && phase != BattlePhase.choosingPokemon) return;
    if (index < 0 || index >= team.length || index == activeIndex || team[index].isFainted) return;

    final old = player!;
    final e = enemy!;
    engine.leaveBattle(old);
    activeIndex = index;
    final incoming = player!;

    final events = <BattleEvent>[
      if (!forced)
        engine.snapshot('¡Vuelve, ${engine.label(old)}!', incoming, e,
            kind: BattleEventKind.switchOut, target: old),
      engine.snapshot('¡Adelante, ${engine.label(incoming)}!', incoming, e,
          kind: BattleEventKind.switchIn, target: incoming),
    ];

    if (forced) {
      phase = BattlePhase.busy;
      await _show(events);
      if (_disposed) return;
      await _afterTurn();
    } else {
      await _playTurn(null, before: events);
    }
  }

  // Mochila: elegir un objeto. Luego se elige a quién dárselo.
  void selectItem(BagItem bagItem) {
    if (phase != BattlePhase.choosingItem || bagItem.cantidad <= 0) return;
    selectedItem = bagItem;
    phase = BattlePhase.choosingItemTarget;
    message = '¿A quién le darás ${bagItem.item.nombre}?';
    _notify();
  }

  // Dar el objeto elegido al Pokémon del equipo en `index`. Gasta el turno.
  Future<void> useItemOn(int index) async {
    final bagItem = selectedItem;
    if (phase != BattlePhase.choosingItemTarget || bagItem == null) return;
    if (index < 0 || index >= team.length) return;

    final target = team[index];
    final result = engine.applyItem(bagItem.item, target);
    if (result == null) {
      // No se gasta el objeto ni el turno
      message = 'No tendría ningún efecto.';
      phase = BattlePhase.choosingItem;
      selectedItem = null;
      _notify();
      return;
    }

    bagItem.cantidad--;
    selectedItem = null;
    unawaited(backend.updateItemQuantity(bagItem).catchError((_) => saveFailed = true));

    final p = player!, e = enemy!;
    lastItemUsed = bagItem.item;
    // Solo se anima si el objeto es para el que está peleando (los de la banca no se ven)
    final shown = index == activeIndex ? target : null;
    final effect = bagItem.item.efecto == ItemEffect.curarEstado ? BattleEventKind.statusCured : BattleEventKind.heal;
    await _playTurn(null, before: [
      engine.snapshot('Usaste ${bagItem.item.nombre}.', p, e, kind: BattleEventKind.item, target: shown),
      engine.snapshot(result, p, e, kind: effect, target: shown),
    ]);
  }

  // Huir. Si falla, el rival ataca.
  Future<void> flee() async {
    if (phase != BattlePhase.choosingAction) return;
    final p = player!, e = enemy!;
    if (engine.tryToFlee(p, e, _failedFleeAttempts)) {
      phase = BattlePhase.busy;
      await _show([engine.snapshot('¡Escapaste sin problemas!', p, e, kind: BattleEventKind.fled, target: p)]);
      if (_disposed) return;
      await _finish(BattleOutcome.fled);
      _notify();
      return;
    }
    _failedFleeAttempts++;
    await _playTurn(null, before: [engine.snapshot('¡No puedes escapar!', p, e)]);
  }

  // ---------------------------------------------------------------- Turno

  Future<void> _playTurn(BattleMove? playerMove, {List<BattleEvent> before = const []}) async {
    final p = player!, e = enemy!;
    phase = BattlePhase.busy;
    _notify();

    final enemyMove = engine.pickEnemyMove(e, p);
    final events = [...before, ...engine.runTurn(p, e, playerMove, enemyMove)];
    await _show(events);
    if (_disposed) return;
    await _afterTurn();
  }

  Future<void> _afterTurn() async {
    _syncShown();
    if (enemy!.isFainted) {
      await _finish(BattleOutcome.won);
    } else if (allFainted) {
      await _finish(BattleOutcome.lost);
    } else if (player!.isFainted) {
      phase = BattlePhase.choosingReplacement;
      message = '¿Qué Pokémon vas a sacar?';
    } else {
      phase = BattlePhase.choosingAction;
      message = '¿Qué hará ${engine.label(player!)}?';
    }
    _notify();
  }

  Future<void> _show(List<BattleEvent> events) async {
    for (final event in events) {
      message = event.message;
      lastEvent = event;
      playerHpShown = event.playerHp;
      enemyHpShown = event.enemyHp;
      playerStatusShown = event.playerStatus;
      enemyStatusShown = event.enemyStatus;
      _notify();
      await _waitMessage();
      if (_disposed) return;
    }
  }

  // Espera `messageDelay` o a que el jugador toque el cuadro de texto
  Future<void> _waitMessage() async {
    if (messageDelay <= Duration.zero) return;
    final wait = _messageWait = Completer<void>();
    final timer = Timer(messageDelay, advanceMessage);
    await wait.future;
    timer.cancel();
    _messageWait = null;
  }

  // Guarda la vida y el estado de todo el equipo, el premio y el resultado (también las huidas).
  Future<void> _finish(BattleOutcome result) async {
    outcome = result;
    phase = BattlePhase.finished;
    for (final p in team) {
      engine.leaveBattle(p);
    }
    _syncShown();

    if (result == BattleOutcome.won && userId != null) {
      try {
        reward = engine.rollReward(await backend.getItemCatalog());
        if (reward != null) await backend.addItem(userId!, reward!, 1);
      } catch (_) {
        reward = null;
        saveFailed = true;
      }
    }

    message = switch (result) {
      BattleOutcome.won => reward == null
          ? '¡Ganaste la batalla!'
          : '¡Ganaste la batalla! Encontraste: ${reward!.nombre}.',
      BattleOutcome.lost => 'Perdiste la batalla...',
      BattleOutcome.fled => 'Escapaste de la batalla.',
    };

    try {
      for (final p in team) {
        await backend.updateEstado(p);
      }
      await backend.saveBattle(BattleResult(
        idPokemonUserRetador: team.first.idPokemonUser!,
        idPokemonRival: enemy!.idPokemon,
        resultado: switch (result) {
          BattleOutcome.won => BattleResultado.victoria,
          BattleOutcome.lost => BattleResultado.derrota,
          BattleOutcome.fled => BattleResultado.huida,
        },
      ));
    } catch (_) {
      saveFailed = true;
    }
  }

  // ---------------------------------------------------------------- Carga

  Future<Map<String, dynamic>> _fetchPokemonJson(int id) async {
    final response = await pokeApi.getPokemonDetail(id);
    if (response.statusCode != 200) {
      throw Exception('PokeAPI respondió ${response.statusCode} para el Pokémon $id');
    }
    return json.decode(response.body);
  }

  // Busca un rival cuya suma de estadísticas se parezca a la de tu primer Pokémon,
  // para que no te toque Arceus contra Bulbasaur. Si no sale en pocos intentos, usa el último.
  Future<Map<String, dynamic>> _findRival(BattlePokemon lead) async {
    late Map<String, dynamic> candidate;
    for (var i = 0; i < _rivalAttempts; i++) {
      candidate = await _fetchPokemonJson(1 + _random.nextInt(maxPokedexId));
      final total = BattlePokemon.fromPokeApiJson(candidate).statTotal;
      if ((total - lead.statTotal).abs() <= lead.statTotal * _rivalTolerance) break;
    }
    return candidate;
  }

  // Revisa los primeros movimientos que puede aprender y se queda con 4,
  // prefiriendo los que hacen daño. Si alguno falla, se salta sin tronar la carga.
  Future<List<BattleMove>> _loadMoves(Map<String, dynamic> pokemonJson) async {
    final names = (pokemonJson['moves'] as List? ?? [])
        .map((m) => m['move']['name'] as String)
        .take(_moveCandidates)
        .toList();

    final results = await Future.wait(names.map((name) async {
      try {
        final response = await pokeApi.getMove(name);
        return response.statusCode == 200 ? BattleMove.fromRawJson(response.body) : null;
      } catch (_) {
        return null;
      }
    }));
    final moves = results.whereType<BattleMove>().toList();

    // Hasta 3 de daño y el resto de estado (que cause un estado, cambie estadísticas o cure)
    final damaging = moves.where((m) => m.doesDamage).toList();
    final support = moves
        .where((m) => !m.doesDamage && (m.ailment != null || m.statChanges.isNotEmpty || m.healing > 0))
        .toList();
    final chosen = [...damaging.take(3), ...support, ...damaging.skip(3)].take(4).toList();
    return chosen.isEmpty ? [BattleMove.struggle()] : chosen;
  }

  void _syncShown() {
    playerHpShown = player?.currentHp ?? 0;
    enemyHpShown = enemy?.currentHp ?? 0;
    playerStatusShown = player?.status ?? StatusCondition.sano;
    enemyStatusShown = enemy?.status ?? StatusCondition.sano;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    advanceMessage();
    super.dispose();
  }
}
