import 'dart:math';

import '../models/battle_item.dart';
import '../models/battle_move.dart';
import '../models/battle_pokemon.dart';
import '../models/status_condition.dart';
import 'type_chart.dart';

// Todos los Pokémon pelean en el mismo nivel estándar (no hay niveles en la BD)
const int standardLevel = 50;

// La vida máxima en la BD es 100 (en los juegos, a nivel 50 ronda 130-200). Sin ajuste, casi
// todo se debilita de un golpe. Con 0.5 una batalla dura unos 3-5 ataques. Se puede ajustar.
const double damageScale = 0.5;

// Qué pasó en cada mensaje. Sirve para que la parte visual sepa qué animar
// (sacudir un sprite, parpadear la barra, etc.) sin leer el texto.
enum BattleEventKind {
  message,
  attack,
  damage,
  critical,
  superEffective,
  notEffective,
  miss,
  statusInflicted,
  statusCured,
  statUp,
  statDown,
  heal,
  faint,
  switchIn,
  switchOut,
  item,
  fled,
}

// Una "foto" de la batalla después de cada mensaje, para que la pantalla
// muestre los mensajes uno por uno con la vida correcta en cada momento.
class BattleEvent {
  final String message;
  final BattleEventKind kind;
  final bool? targetIsPlayer; // A quién le pasa (null = a nadie en particular)
  final int playerHp;
  final int enemyHp;
  final StatusCondition playerStatus;
  final StatusCondition enemyStatus;

  BattleEvent({
    required this.message,
    this.kind = BattleEventKind.message,
    this.targetIsPlayer,
    required this.playerHp,
    required this.enemyHp,
    required this.playerStatus,
    required this.enemyStatus,
  });
}

typedef _Say = void Function(String message, [BattleEventKind kind, BattlePokemon? target]);

// Lógica pura de combate. No sabe nada de pantallas ni de internet,
// así se puede probar con tests. `random` se puede fijar en los tests.
class BattleEngine {
  static const _statNames = {'attack': 'Ataque', 'defense': 'Defensa', 'speed': 'Velocidad'};

  final Random random;

  BattleEngine({Random? random}) : random = random ?? Random();

  // Crea un evento con la vida y el estado actuales de los dos Pokémon
  BattleEvent snapshot(
    String message,
    BattlePokemon player,
    BattlePokemon enemy, {
    BattleEventKind kind = BattleEventKind.message,
    BattlePokemon? target,
  }) =>
      BattleEvent(
        message: message,
        kind: kind,
        targetIsPlayer: target == null ? null : !target.isComputer,
        playerHp: player.currentHp,
        enemyHp: enemy.currentHp,
        playerStatus: player.status,
        enemyStatus: enemy.status,
      );

  // ---------------------------------------------------------------- Daño

  // Fórmula de daño simplificada estilo Pokémon, con nivel estándar.
  // Como la BD solo tiene Ataque y Defensa (no especiales), se usan para todo.
  // Un golpe crítico hace x1.5 e ignora las bajadas de Ataque y las subidas de Defensa.
  int calculateDamage(
    BattlePokemon attacker,
    BattlePokemon defender,
    BattleMove move, {
    bool critical = false,
  }) {
    if (!move.doesDamage) return 0;
    final effectiveness = typeEffectiveness(move.type, defender.types);
    if (effectiveness == 0) return 0;

    final attackStage = critical ? max(1.0, attacker.stageMultiplier('attack'))
        : attacker.stageMultiplier('attack');
    final defenseStage = critical ? min(1.0, defender.stageMultiplier('defense'))
        : defender.stageMultiplier('defense');

    var attack = attacker.attack * attackStage;
    if (attacker.status == StatusCondition.quemado && move.damageClass == 'physical') {
      attack /= 2; // Las quemaduras bajan el ataque físico a la mitad
    }
    final defense = max(1.0, defender.defense * defenseStage);

    final base = ((2 * standardLevel / 5 + 2) * move.power! * attack / defense) / 50 + 2;
    final stab = attacker.types.map(normalizeType).contains(normalizeType(move.type)) ? 1.5 : 1.0;
    final crit = critical ? 1.5 : 1.0;
    final variation = 0.85 + random.nextDouble() * 0.15; // Entre 85% y 100%

    return max(1, (base * damageScale * stab * effectiveness * crit * variation).floor());
  }

  // Probabilidad de crítico según `crit_rate` de la PokeAPI: 1/24, 1/8, 1/2 o siempre
  bool rollCritical(BattleMove move) {
    const odds = [24, 8, 2, 1];
    return random.nextInt(odds[move.critRate.clamp(0, 3)]) == 0;
  }

  // ---------------------------------------------------------------- Orden de turno

  double effectiveSpeed(BattlePokemon p) {
    final speed = p.speed * p.stageMultiplier('speed');
    return p.status == StatusCondition.paralizado ? speed / 2 : speed;
  }

  // Primero va el movimiento con más prioridad (Ataque Rápido +1). Si empatan, el más
  // rápido. La parálisis baja la velocidad a la mitad. Empate de velocidad = al azar.
  bool playerGoesFirst(
    BattlePokemon player,
    BattlePokemon enemy, {
    BattleMove? playerMove,
    BattleMove? enemyMove,
  }) {
    final pp = playerMove?.priority ?? 0;
    final ep = enemyMove?.priority ?? 0;
    if (pp != ep) return pp > ep;

    final ps = effectiveSpeed(player);
    final es = effectiveSpeed(enemy);
    if (ps == es) return random.nextBool();
    return ps > es;
  }

  // ---------------------------------------------------------------- IA del rival

  // Si ya no le quedan PP a ningún movimiento, usa Forcejeo
  bool mustStruggle(BattlePokemon p) => p.moves.every((m) => !m.hasPp);

  // La computadora casi siempre (70%) elige el movimiento que más daño haría,
  // y a veces uno al azar para no ser predecible. Nunca usa uno que no le afecte.
  BattleMove pickEnemyMove(BattlePokemon enemy, BattlePokemon target) {
    final available = enemy.moves.where((m) => m.hasPp).toList();
    if (available.isEmpty) return BattleMove.struggle();

    final useful = available.where((m) => _moveScore(enemy, target, m) > 0).toList();
    final candidates = useful.isEmpty ? available : useful;

    if (random.nextInt(100) < 70) {
      candidates.sort((a, b) => _moveScore(enemy, target, b).compareTo(_moveScore(enemy, target, a)));
      return candidates.first;
    }
    return candidates[random.nextInt(candidates.length)];
  }

  // Qué tan buena idea es un movimiento (sin azar)
  double _moveScore(BattlePokemon user, BattlePokemon target, BattleMove move) {
    if (move.doesDamage) {
      final eff = typeEffectiveness(move.type, target.types);
      final stab = user.types.map(normalizeType).contains(normalizeType(move.type)) ? 1.5 : 1.0;
      return move.power! * eff * stab * (move.accuracy ?? 100) / 100;
    }
    final ailment = move.ailment;
    if (ailment != null && !move.targetsSelf) {
      final works = target.status == StatusCondition.sano && !isImmuneTo(target, ailment);
      return works ? 45 : 0;
    }
    if (move.statChanges.isNotEmpty) return 25;
    if (move.healing > 0) return user.currentHp < user.maxHp / 2 ? 60 : 0;
    return 0;
  }

  // ---------------------------------------------------------------- Turno

  // Juega un turno completo: los dos atacan en orden y luego se aplican los daños por
  // quemadura/veneno. Si `playerMove` es null, el jugador gastó su turno en otra cosa
  // (cambiar, usar un objeto o intentar huir) y solo ataca el rival.
  List<BattleEvent> runTurn(
    BattlePokemon player,
    BattlePokemon enemy,
    BattleMove? playerMove,
    BattleMove enemyMove,
  ) {
    final events = <BattleEvent>[];
    void say(String message, [BattleEventKind kind = BattleEventKind.message, BattlePokemon? target]) =>
        events.add(snapshot(message, player, enemy, kind: kind, target: target));

    final order = playerMove == null
        ? [(enemy, player, enemyMove)]
        : playerGoesFirst(player, enemy, playerMove: playerMove, enemyMove: enemyMove)
            ? [(player, enemy, playerMove), (enemy, player, enemyMove)]
            : [(enemy, player, enemyMove), (player, enemy, playerMove)];

    for (final (attacker, defender, move) in order) {
      if (attacker.isFainted || defender.isFainted) break;
      _executeMove(attacker, defender, move, say);
    }

    for (final p in [player, enemy]) {
      if (!player.isFainted && !enemy.isFainted) _applyEndOfTurnDamage(p, say);
    }

    for (final p in [enemy, player]) {
      if (p.isFainted) say('¡${label(p)} se debilitó!', BattleEventKind.faint, p);
    }
    return events;
  }

  String label(BattlePokemon p) {
    final name = p.name.isEmpty ? '???' : p.name[0].toUpperCase() + p.name.substring(1);
    return p.isComputer ? '$name rival' : name;
  }

  void _executeMove(BattlePokemon attacker, BattlePokemon defender, BattleMove move, _Say say) {
    if (!_canMove(attacker, say)) return;

    // El PP se gasta aunque el ataque falle
    if (!move.isStruggle && move.currentPp > 0) move.currentPp--;

    say('${label(attacker)} usó ${move.displayName}.', BattleEventKind.attack, attacker);

    // Chequeo de precisión (null = nunca falla)
    if (move.accuracy != null && random.nextInt(100) >= move.accuracy!) {
      say('¡Pero falló!', BattleEventKind.miss, defender);
      return;
    }

    var didSomething = false;

    if (move.doesDamage) {
      final effectiveness = typeEffectiveness(move.type, defender.types);
      if (effectiveness == 0) {
        say('No afecta a ${label(defender)}...', BattleEventKind.miss, defender);
        return;
      }
      final critical = rollCritical(move);
      final damage = min(defender.currentHp, calculateDamage(attacker, defender, move, critical: critical));
      defender.currentHp -= damage;
      didSomething = true;

      if (critical) say('¡Un golpe crítico!', BattleEventKind.critical, defender);
      if (effectiveness > 1) {
        say('¡Es súper eficaz! Hizo $damage de daño.', BattleEventKind.superEffective, defender);
      } else if (effectiveness < 1) {
        say('No es muy eficaz... Hizo $damage de daño.', BattleEventKind.notEffective, defender);
      } else {
        say('Hizo $damage de daño.', BattleEventKind.damage, defender);
      }

      // Drenar (Absorber) o retroceso (Doble Filo). Forcejeo siempre quita 1/4 de la vida máxima.
      if (move.isStruggle) {
        _hurt(attacker, max(1, attacker.maxHp ~/ 4));
        say('¡${label(attacker)} también se hizo daño!', BattleEventKind.damage, attacker);
      } else if (move.drain > 0 && attacker.currentHp < attacker.maxHp) {
        _heal(attacker, max(1, damage * move.drain ~/ 100));
        say('¡${label(defender)} perdió energía!', BattleEventKind.heal, attacker);
      } else if (move.drain < 0) {
        _hurt(attacker, max(1, damage * -move.drain ~/ 100));
        say('${label(attacker)} también se hizo daño.', BattleEventKind.damage, attacker);
      }
    }

    // Estado del movimiento (Lanzallamas puede quemar, Somnífero duerme...)
    final ailment = move.ailment;
    if (ailment != null) {
      final target = move.targetsSelf ? attacker : defender;
      if (!target.isFainted && target.status == StatusCondition.sano) {
        if (isImmuneTo(target, ailment)) {
          if (!move.doesDamage) {
            say('No afecta a ${label(target)}...', BattleEventKind.miss, target);
            didSomething = true;
          }
        } else {
          // En movimientos de estado la API manda chance 0 = siempre
          final chance = move.ailmentChance == 0 && !move.doesDamage ? 100 : move.ailmentChance;
          if (random.nextInt(100) < chance) {
            _inflict(target, ailment, say);
            didSomething = true;
          }
        }
      }
    }

    // Subir o bajar estadísticas (Gruñido, Danza Espada, A Bocajarro...)
    if (move.statChanges.isNotEmpty) {
      final target = move.targetsSelf ? attacker : defender;
      final chance = move.statChance == 0 ? 100 : move.statChance;
      if (!target.isFainted && random.nextInt(100) < chance) {
        move.statChanges.forEach((stat, change) => _changeStage(target, stat, change, say));
        didSomething = true;
      }
    }

    // Curarse a sí mismo (Recuperación)
    if (move.healing > 0) {
      if (attacker.currentHp < attacker.maxHp) {
        _heal(attacker, max(1, attacker.maxHp * move.healing ~/ 100));
        say('${label(attacker)} recuperó salud.', BattleEventKind.heal, attacker);
      } else {
        say('¡La salud de ${label(attacker)} ya está al máximo!');
      }
      didSomething = true;
    }

    if (!didSomething) say('No tuvo ningún efecto.');
  }

  // Los de tipo Fuego no se queman, Eléctrico no se paraliza, Veneno y Acero no se
  // envenenan, Hielo no se congela.
  bool isImmuneTo(BattlePokemon p, StatusCondition status) {
    final types = p.types.map(normalizeType);
    return switch (status) {
      StatusCondition.quemado => types.contains('fire'),
      StatusCondition.paralizado => types.contains('electric'),
      StatusCondition.envenenado => types.contains('poison') || types.contains('steel'),
      StatusCondition.congelado => types.contains('ice'),
      _ => false,
    };
  }

  void _changeStage(BattlePokemon p, String stat, int change, _Say say) {
    final name = '${_statNames[stat]} de ${label(p)}';
    final current = p.stages[stat] ?? 0;
    final next = (current + change).clamp(-6, 6);
    if (next == current) {
      say(change > 0 ? '¡El $name no puede subir más!' : '¡El $name no puede bajar más!');
      return;
    }
    p.stages[stat] = next;
    final much = (next - current).abs() >= 2 ? ' mucho' : '';
    if (change > 0) {
      say('¡El $name subió$much!', BattleEventKind.statUp, p);
    } else {
      say('¡El $name bajó$much!', BattleEventKind.statDown, p);
    }
  }

  void _inflict(BattlePokemon target, StatusCondition status, _Say say) {
    target.status = status;
    const k = BattleEventKind.statusInflicted;
    switch (status) {
      case StatusCondition.dormido:
        target.statusTurns = 1 + random.nextInt(3); // 1 a 3 turnos
        say('¡${label(target)} se quedó dormido!', k, target);
      case StatusCondition.confundido:
        target.statusTurns = 2 + random.nextInt(4); // 2 a 5 turnos
        say('¡${label(target)} está confundido!', k, target);
      case StatusCondition.quemado:
        say('¡${label(target)} se quemó!', k, target);
      case StatusCondition.envenenado:
        say('¡${label(target)} fue envenenado!', k, target);
      case StatusCondition.paralizado:
        say('¡${label(target)} está paralizado! Quizás no se pueda mover.', k, target);
      case StatusCondition.congelado:
        say('¡${label(target)} se congeló!', k, target);
      case StatusCondition.sano:
        break;
    }
  }

  // Revisa si el estado deja atacar este turno
  bool _canMove(BattlePokemon p, _Say say) {
    switch (p.status) {
      case StatusCondition.dormido:
        if (p.statusTurns <= 0) {
          p.status = StatusCondition.sano;
          say('¡${label(p)} se despertó!', BattleEventKind.statusCured, p);
          return true;
        }
        p.statusTurns--;
        say('${label(p)} está dormido.', BattleEventKind.message, p);
        return false;
      case StatusCondition.congelado:
        if (random.nextInt(100) < 20) {
          p.status = StatusCondition.sano;
          say('¡${label(p)} se descongeló!', BattleEventKind.statusCured, p);
          return true;
        }
        say('${label(p)} está congelado y no se puede mover.', BattleEventKind.message, p);
        return false;
      case StatusCondition.paralizado:
        if (random.nextInt(100) < 25) {
          say('${label(p)} está paralizado y no se puede mover.', BattleEventKind.message, p);
          return false;
        }
        return true;
      case StatusCondition.confundido:
        if (p.statusTurns <= 0) {
          p.status = StatusCondition.sano;
          say('${label(p)} ya no está confundido.', BattleEventKind.statusCured, p);
          return true;
        }
        p.statusTurns--;
        if (random.nextInt(100) < 33) {
          _hurt(p, max(1, p.maxHp ~/ 8));
          say('¡${label(p)} está tan confundido que se hirió a sí mismo!', BattleEventKind.damage, p);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _applyEndOfTurnDamage(BattlePokemon p, _Say say) {
    if (p.isFainted) return;
    if (p.status == StatusCondition.quemado) {
      _hurt(p, max(1, p.maxHp ~/ 16));
      say('${label(p)} se resiente de la quemadura.', BattleEventKind.damage, p);
    } else if (p.status == StatusCondition.envenenado) {
      _hurt(p, max(1, p.maxHp ~/ 8));
      say('${label(p)} sufre por el veneno.', BattleEventKind.damage, p);
    }
  }

  void _hurt(BattlePokemon p, int amount) => p.currentHp = (p.currentHp - amount).clamp(0, p.maxHp);
  void _heal(BattlePokemon p, int amount) => p.currentHp = (p.currentHp + amount).clamp(0, p.maxHp);

  // ---------------------------------------------------------------- Entrar y salir

  // Al entrar a la batalla: si viene dormido o confundido desde la BD, el contador de
  // turnos no se guardó, así que se sortea (si no, se "curaría" en su primer turno).
  void prepareForBattle(BattlePokemon p) {
    p.resetStages();
    if (p.statusTurns > 0) return;
    if (p.status == StatusCondition.dormido) p.statusTurns = 1 + random.nextInt(3);
    if (p.status == StatusCondition.confundido) p.statusTurns = 2 + random.nextInt(4);
  }

  // Al salir del combate (cambio o fin de batalla) se pierden los cambios de
  // estadísticas y la confusión, como en los juegos.
  void leaveBattle(BattlePokemon p) {
    p.resetStages();
    if (p.status == StatusCondition.confundido) {
      p.status = StatusCondition.sano;
      p.statusTurns = 0;
    }
  }

  // ---------------------------------------------------------------- Huir

  // Fórmula de los juegos (Gen 3-4): si eres igual o más rápido, huyes siempre. Si no,
  // la probabilidad depende de la diferencia de velocidad y sube con cada intento fallido.
  bool tryToFlee(BattlePokemon player, BattlePokemon enemy, int failedAttempts) {
    final ps = effectiveSpeed(player);
    final es = effectiveSpeed(enemy);
    if (ps >= es) return true;
    final chance = (ps * 128 / max(1, es)).floor() + 30 * failedAttempts;
    return random.nextInt(256) < chance;
  }

  // ---------------------------------------------------------------- Objetos

  // Si el objeto tendría algún efecto en ese Pokémon (sin aplicarlo).
  // La pantalla lo usa para apagar los objetos y Pokémon que no sirven.
  bool canApplyItem(ItemInfo item, BattlePokemon target) => switch (item.efecto) {
        ItemEffect.curar => !target.isFainted && target.currentHp < target.maxHp,
        ItemEffect.revivir => target.isFainted,
        ItemEffect.curarEstado => !target.isFainted &&
            target.status != StatusCondition.sano &&
            (item.curedStatus == null || target.status == item.curedStatus),
        ItemEffect.pokeball || ItemEffect.ninguno => false,
      };

  // Aplica un objeto de la mochila. Devuelve el mensaje de lo que pasó, o null si
  // no tendría efecto (en ese caso no se gasta ni se pierde el turno).
  String? applyItem(ItemInfo item, BattlePokemon target) {
    if (!canApplyItem(item, target)) return null;
    final name = target.name.isEmpty ? '???' : target.name[0].toUpperCase() + target.name.substring(1);
    switch (item.efecto) {
      case ItemEffect.curar:
        if (target.isFainted || target.currentHp >= target.maxHp) return null;
        final before = target.currentHp;
        _heal(target, max(1, item.valor));
        return '¡$name recuperó ${target.currentHp - before} PS!';
      case ItemEffect.revivir:
        if (!target.isFainted) return null;
        target.currentHp = max(1, target.maxHp * item.valor ~/ 100);
        target.status = StatusCondition.sano;
        target.statusTurns = 0;
        return '¡$name se recuperó y puede volver a pelear!';
      case ItemEffect.curarEstado:
        final cured = item.curedStatus;
        if (target.isFainted || target.status == StatusCondition.sano) return null;
        if (cured != null && target.status != cured) return null;
        target.status = StatusCondition.sano;
        target.statusTurns = 0;
        return '¡$name se curó!';
      case ItemEffect.pokeball:
      case ItemEffect.ninguno:
        return null;
    }
  }

  // ---------------------------------------------------------------- Premio

  // Sorteo del premio al ganar: cada objeto tiene tantas "papeletas" como su Probabilidad.
  // Solo salen objetos que sirven en batalla (pociones, curas de estado, Revivir);
  // las Pokéballs y los de probabilidad 0 no entran al sorteo.
  ItemInfo? rollReward(List<ItemInfo> catalog) {
    final items = catalog.where((i) => i.usableInBattle && i.probabilidad > 0).toList();
    final total = items.fold<double>(0, (sum, i) => sum + i.probabilidad);
    if (total <= 0) return null;
    var r = random.nextDouble() * total;
    for (final i in items) {
      r -= i.probabilidad;
      if (r < 0) return i;
    }
    return items.last;
  }
}
