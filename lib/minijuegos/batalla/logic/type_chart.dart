// Tabla de efectividad de tipos (atacante -> defensor -> multiplicador).
// Solo se anotan los casos distintos de x1.
const Map<String, Map<String, double>> _chart = {
  'normal': {'rock': 0.5, 'ghost': 0, 'steel': 0.5},
  'fire': {'fire': 0.5, 'water': 0.5, 'grass': 2, 'ice': 2, 'bug': 2, 'rock': 0.5, 'dragon': 0.5, 'steel': 2},
  'water': {'fire': 2, 'water': 0.5, 'grass': 0.5, 'ground': 2, 'rock': 2, 'dragon': 0.5},
  'electric': {'water': 2, 'electric': 0.5, 'grass': 0.5, 'ground': 0, 'flying': 2, 'dragon': 0.5},
  'grass': {'fire': 0.5, 'water': 2, 'grass': 0.5, 'poison': 0.5, 'ground': 2, 'flying': 0.5, 'bug': 0.5, 'rock': 2, 'dragon': 0.5, 'steel': 0.5},
  'ice': {'fire': 0.5, 'water': 0.5, 'grass': 2, 'ice': 0.5, 'ground': 2, 'flying': 2, 'dragon': 2, 'steel': 0.5},
  'fighting': {'normal': 2, 'ice': 2, 'poison': 0.5, 'flying': 0.5, 'psychic': 0.5, 'bug': 0.5, 'rock': 2, 'ghost': 0, 'dark': 2, 'steel': 2, 'fairy': 0.5},
  'poison': {'grass': 2, 'poison': 0.5, 'ground': 0.5, 'rock': 0.5, 'ghost': 0.5, 'steel': 0, 'fairy': 2},
  'ground': {'fire': 2, 'electric': 2, 'grass': 0.5, 'poison': 2, 'flying': 0, 'bug': 0.5, 'rock': 2, 'steel': 2},
  'flying': {'electric': 0.5, 'grass': 2, 'fighting': 2, 'bug': 2, 'rock': 0.5, 'steel': 0.5},
  'psychic': {'fighting': 2, 'poison': 2, 'psychic': 0.5, 'dark': 0, 'steel': 0.5},
  'bug': {'fire': 0.5, 'grass': 2, 'fighting': 0.5, 'poison': 0.5, 'flying': 0.5, 'psychic': 2, 'ghost': 0.5, 'dark': 2, 'steel': 0.5, 'fairy': 0.5},
  'rock': {'fire': 2, 'ice': 2, 'fighting': 0.5, 'ground': 0.5, 'flying': 2, 'bug': 2, 'steel': 0.5},
  'ghost': {'normal': 0, 'psychic': 2, 'ghost': 2, 'dark': 0.5},
  'dragon': {'dragon': 2, 'steel': 0.5, 'fairy': 0},
  'dark': {'fighting': 0.5, 'psychic': 2, 'ghost': 2, 'dark': 0.5, 'fairy': 0.5},
  'steel': {'fire': 0.5, 'water': 0.5, 'electric': 0.5, 'ice': 2, 'rock': 2, 'steel': 0.5, 'fairy': 2},
  'fairy': {'fire': 0.5, 'fighting': 2, 'poison': 0.5, 'dragon': 2, 'dark': 2, 'steel': 0.5},
};

// Por si el backend guarda los tipos en español
const Map<String, String> _spanishToEnglish = {
  'normal': 'normal', 'fuego': 'fire', 'agua': 'water', 'eléctrico': 'electric',
  'electrico': 'electric', 'planta': 'grass', 'hielo': 'ice', 'lucha': 'fighting',
  'veneno': 'poison', 'tierra': 'ground', 'volador': 'flying', 'psíquico': 'psychic',
  'psiquico': 'psychic', 'bicho': 'bug', 'roca': 'rock', 'fantasma': 'ghost',
  'dragón': 'dragon', 'dragon': 'dragon', 'siniestro': 'dark', 'acero': 'steel', 'hada': 'fairy',
};

String normalizeType(String type) {
  final t = type.toLowerCase().trim();
  return _spanishToEnglish[t] ?? t;
}

// Multiplicador total de un ataque de `moveType` contra un Pokémon con `defenderTypes`
double typeEffectiveness(String moveType, List<String> defenderTypes) {
  final row = _chart[normalizeType(moveType)] ?? const {};
  var multiplier = 1.0;
  for (final t in defenderTypes) {
    multiplier *= row[normalizeType(t)] ?? 1.0;
  }
  return multiplier;
}
