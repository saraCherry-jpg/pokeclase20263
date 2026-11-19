// Resultado de una batalla. Es lo que se guarda en la tabla `Batallas`.
//
// Formato de CambiosEndpointsTracker (sección 2):
//   POST /api/Batallas  body: { pokemonUserR, idPokemonRival, resultado }
//   GET  /api/Batallas/usuario/{userId}  -> { total, pagina, tamano, items: [...] }
// El rival es un Pokémon salvaje, así que se guarda su número de Pokédex (IdPokemonRival).
// La fecha y el usuario los pone el backend.

// Batallas.Resultado. El backend lo manda como texto ("Victoria") y lo guarda como 1, 2, 3.
enum BattleResultado {
  victoria('Victoria'),
  derrota('Derrota'),
  huida('Huida');

  final String json;
  const BattleResultado(this.json);

  static BattleResultado fromJson(dynamic value) => switch (value) {
        'Victoria' || 1 => BattleResultado.victoria,
        'Huida' || 3 => BattleResultado.huida,
        _ => BattleResultado.derrota,
      };
}

class BattleResult {
  final int? id;                  // Batallas.Id (nulo antes de guardarla)
  final int idPokemonUserRetador; // Batallas.PokemonUserR (el primero del equipo)
  final int idPokemonRival;       // Batallas.IdPokemonRival
  final BattleResultado resultado; // Batallas.Resultado
  final DateTime? fecha;          // Batallas.Fecha (la asigna el backend; nula antes de guardarla)
  final String? nombre;           // pokemon.nombre del historial (sigue aunque ya lo hayas intercambiado)
  final String? urlFrontal;       // pokemon.urlFrontal del historial

  BattleResult({
    this.id,
    required this.idPokemonUserRetador,
    required this.idPokemonRival,
    required this.resultado,
    this.fecha,
    this.nombre,
    this.urlFrontal,
  });

  bool get playerWon => resultado == BattleResultado.victoria;

  // Un elemento de `items` del historial:
  // { "id": 41, "fecha": "...", "resultado": "Victoria", "idPokemonRival": 19,
  //   "pokemon": { "id": 12, "idPokemon": 25, "nombre": "Pikachu", "urlFrontal": "..." } }
  factory BattleResult.fromJson(Map<String, dynamic> json) {
    final pokemon = json['pokemon'] as Map<String, dynamic>? ?? {};
    return BattleResult(
      id: json['id'],
      idPokemonUserRetador: json['pokemonUserR'] ?? pokemon['id'] ?? 0,
      idPokemonRival: json['idPokemonRival'] ?? 0,
      resultado: BattleResultado.fromJson(json['resultado']),
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '')?.toLocal(),
      nombre: pokemon['nombre'],
      urlFrontal: pokemon['urlFrontal'],
    );
  }

  Map<String, dynamic> toJson() => {
        'pokemonUserR': idPokemonUserRetador,
        'idPokemonRival': idPokemonRival,
        'resultado': resultado.json,
      };
}

// GET /api/Batallas/usuario/{userId}/resumen
class BattleSummary {
  final int victorias;
  final int derrotas;
  final int huidas;
  final double? winRate; // victorias / (victorias + derrotas); null si no hay

  const BattleSummary({
    required this.victorias,
    required this.derrotas,
    required this.huidas,
    required this.winRate,
  });

  factory BattleSummary.fromJson(Map<String, dynamic> json) => BattleSummary(
        victorias: json['victorias'] ?? 0,
        derrotas: json['derrotas'] ?? 0,
        huidas: json['huidas'] ?? 0,
        winRate: (json['winRate'] as num?)?.toDouble(),
      );

  // Igual que el backend: las huidas no cuentan para el porcentaje
  factory BattleSummary.fromBattles(List<BattleResult> battles) {
    int count(BattleResultado r) => battles.where((b) => b.resultado == r).length;
    final v = count(BattleResultado.victoria);
    final d = count(BattleResultado.derrota);
    return BattleSummary(
      victorias: v,
      derrotas: d,
      huidas: count(BattleResultado.huida),
      winRate: v + d == 0 ? null : v / (v + d),
    );
  }
}
