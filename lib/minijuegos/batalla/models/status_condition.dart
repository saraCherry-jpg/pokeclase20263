// Estados posibles de un Pokémon. Coinciden 1 a 1 con la tabla `Estados` del pizarrón
// (Sano, Dormido, Quemado, Envenenado, Paralizado, Confundido, Congelado).
enum StatusCondition {
  sano('Sano'),
  dormido('Dormido'),
  quemado('Quemado'),
  envenenado('Envenenado'),
  paralizado('Paralizado'),
  confundido('Confundido'),
  congelado('Congelado');

  // Nombre tal como aparece en la tabla Estados (también se muestra en pantalla)
  final String dbName;
  const StatusCondition(this.dbName);

  // Id en la tabla Estados (GET /api/Estados): 1 Sano, 2 Dormido ... 7 Congelado.
  // Es lo que el backend manda y recibe en PokemonEstado.estado.
  int get dbId => index + 1;

  // Convierte lo que mande el backend en un estado.
  // El backend manda el id (1-7); también se acepta el texto ("Quemado") por si acaso.
  static StatusCondition fromDb(dynamic value) {
    if (value is int) {
      final index = value - 1;
      return (index >= 0 && index < values.length) ? values[index] : sano;
    }
    final text = value?.toString().toLowerCase().trim() ?? '';
    return values.firstWhere(
      (s) => s.dbName.toLowerCase() == text,
      orElse: () => sano,
    );
  }

  // La PokeAPI indica en `meta.ailment` qué estado puede causar un movimiento
  static StatusCondition? fromPokeApiAilment(String? ailment) {
    switch (ailment) {
      case 'sleep':
        return dormido;
      case 'burn':
        return quemado;
      case 'poison':
        return envenenado;
      case 'paralysis':
        return paralizado;
      case 'confusion':
        return confundido;
      case 'freeze':
        return congelado;
      default:
        return null;
    }
  }
}
