import 'dart:convert';

import 'battle_move.dart';
import 'status_condition.dart';

// Pokémon listo para pelear.
// Se llama BattlePokemon (y no Pokemon) para no chocar con los modelos de la pokeclase.
//
// Mapeo con la base de datos del pizarrón:
//   PokemonUser.Id              -> idPokemonUser
//   PokemonUser.IdPokemon       -> idPokemon
//   PokemonEstado.VidaTotal     -> maxHp (escala 0-100)
//   PokemonEstado.VidaActual    -> currentHp
//   PokemonEstado.Estado        -> status
//   PokemonEstado.AtaqueBase    -> attack
//   PokemonEstado.DefensaBase   -> defense
//   PokemonEstado.VelocidadBase -> speed
//   PokemonEstado.TipoPrimario / TipoSecundario -> types
//   PokemonEstado.UrlFrontal / UrlTrasera       -> frontSprite / backSprite
class BattlePokemon {
  static const int maxHpScale = 100; // La vida en la BD va de 0 a 100

  final int? idPokemonUser; // Nulo cuando es el Pokémon de la computadora
  final int idPokemon;      // Número de la Pokédex (id de la PokeAPI)
  String name;              // La BD no guarda nombre: se completa con la PokeAPI
  final String frontSprite;
  final String backSprite;
  final int maxHp;
  int currentHp;            // Mutable: baja durante la pelea
  final int attack;
  final int defense;
  final int speed;
  final List<String> types;
  StatusCondition status;   // Mutable: puede cambiar durante la pelea
  List<BattleMove> moves;   // Se cargan aparte desde `/move/{nombre}`

  // Turnos restantes de sueño o confusión. Solo existe durante la batalla, no se guarda.
  int statusTurns = 0;

  // Niveles de estadística (-6 a +6) que cambian con movimientos como Gruñido o
  // Danza Espada. Solo existen durante la batalla y se reinician al salir del combate.
  final Map<String, int> stages = {'attack': 0, 'defense': 0, 'speed': 0};

  BattlePokemon({
    required this.idPokemonUser,
    required this.idPokemon,
    required this.name,
    required this.frontSprite,
    required this.backSprite,
    required this.maxHp,
    required this.currentHp,
    required this.attack,
    required this.defense,
    required this.speed,
    required this.types,
    this.status = StatusCondition.sano,
    List<BattleMove>? moves,
  }) : moves = moves ?? [];

  bool get isFainted => currentHp <= 0;
  bool get isComputer => idPokemonUser == null;

  // Multiplicador del nivel de una estadística: +1 = x1.5, +2 = x2, -1 = x0.67, -2 = x0.5...
  double stageMultiplier(String stat) {
    final s = stages[stat] ?? 0;
    return s >= 0 ? (2 + s) / 2 : 2 / (2 - s);
  }

  // Suma de estadísticas, para buscar un rival parejo
  int get statTotal => maxHp + attack + defense + speed;

  void resetStages() => stages.updateAll((_, _) => 0);

  // Lee un PokemonUser con su PokemonEstado tal como lo devuelve el backend
  // (GET /api/PokemonUser/usuario/{userId}):
  // { "id": 12, "idPokemon": 25, "idUsuario": "...", "nombre": "pikachu",
  //   "pokemonEstado": { "vidaTotal": 100, "vidaActual": 90, "estado": 1, ... } }
  factory BattlePokemon.fromRawJson(String str) => BattlePokemon.fromJson(json.decode(str));

  factory BattlePokemon.fromJson(Map<String, dynamic> json) {
    final estado = json['pokemonEstado'] as Map<String, dynamic>? ?? {};
    final maxHp = (estado['vidaTotal'] ?? maxHpScale) as int;
    final types = <String>[
      if (estado['tipoPrimario'] != null) estado['tipoPrimario'].toString().toLowerCase(),
      if (estado['tipoSecundario'] != null && estado['tipoSecundario'].toString().isNotEmpty)
        estado['tipoSecundario'].toString().toLowerCase(),
    ];

    // Si el backend aún no tiene PokemonEstado (llega null), armamos el sprite con idPokemon
    final int idPokemon = json['idPokemon'] ?? 0;
    const spriteBase = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon';
    final defaultFront = idPokemon > 0 ? '$spriteBase/$idPokemon.png' : '';
    final defaultBack = idPokemon > 0 ? '$spriteBase/back/$idPokemon.png' : defaultFront;

    return BattlePokemon(
      idPokemonUser: json['id'],
      idPokemon: idPokemon,
      name: json['nombre'] ?? '',
      frontSprite: estado['urlFrontal'] ?? defaultFront,
      backSprite: estado['urlTrasera'] ?? estado['urlFrontal'] ?? defaultBack,
      maxHp: maxHp,
      currentHp: ((estado['vidaActual'] ?? maxHp) as int).clamp(0, maxHp),
      attack: estado['ataqueBase'] ?? 50,
      defense: estado['defensaBase'] ?? 50,
      speed: estado['velocidadBase'] ?? 50,
      types: types.isEmpty ? ['normal'] : types,
      status: StatusCondition.fromDb(estado['estado']),
    );
  }

  // Crea el Pokémon de la computadora con la respuesta de `/pokemon/{id}` de la PokeAPI.
  // Regla (pendiente de confirmar con el equipo): stats base tal cual y la vida es el
  // HP base topado a 100, para que quede en la misma escala que VidaTotal.
  factory BattlePokemon.fromPokeApiJson(Map<String, dynamic> json) {
    int stat(String key) {
      final stats = json['stats'] as List? ?? [];
      final match = stats.where((s) => s['stat']['name'] == key);
      return match.isEmpty ? 50 : match.first['base_stat'] as int;
    }

    final sprites = json['sprites'] as Map<String, dynamic>? ?? {};
    final maxHp = stat('hp').clamp(1, maxHpScale);
    final types = (json['types'] as List? ?? [])
        .map((t) => t['type']['name'] as String)
        .toList();

    return BattlePokemon(
      idPokemonUser: null,
      idPokemon: json['id'] ?? 0,
      name: json['name'] ?? '',
      frontSprite: sprites['front_default'] ?? '',
      backSprite: sprites['back_default'] ?? sprites['front_default'] ?? '',
      maxHp: maxHp,
      currentHp: maxHp,
      attack: stat('attack'),
      defense: stat('defense'),
      speed: stat('speed'),
      types: types.isEmpty ? ['normal'] : types,
    );
  }

  // Lo que se manda al backend al terminar la batalla (PUT /api/PokemonEstado/{id}).
  // El estado va como id de la tabla Estados (1-7).
  Map<String, dynamic> toEstadoJson() => {
        'vidaActual': currentHp,
        'estado': status.dbId,
      };
}
