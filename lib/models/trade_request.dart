class TradeRequest {
  final int id;
  final int trainerId;
  final String trainerName;
  final int offeredPokemonId;
  final String pokemonName;
  final String spriteUrl;

  const TradeRequest({
    required this.id,
    required this.trainerId,
    required this.trainerName,
    required this.offeredPokemonId,
    required this.pokemonName,
    required this.spriteUrl,
  });
}

// Solicitudes de ejemplo hasta disponer del endpoint del usuario activo.
const demoTradeRequests = [
  TradeRequest(
    id: 1,
    trainerId: 101,
    trainerName: 'Ash Ketchum',
    offeredPokemonId: 501,
    pokemonName: 'Pikachu',
    spriteUrl:
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png',
  ),
  TradeRequest(
    id: 2,
    trainerId: 102,
    trainerName: 'Misty',
    offeredPokemonId: 502,
    pokemonName: 'Psyduck',
    spriteUrl:
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/54.png',
  ),
  TradeRequest(
    id: 3,
    trainerId: 103,
    trainerName: 'Brock',
    offeredPokemonId: 503,
    pokemonName: 'Onix',
    spriteUrl:
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/95.png',
  ),
];
