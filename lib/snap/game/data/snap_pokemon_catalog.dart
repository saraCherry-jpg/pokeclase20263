import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pokeclase20263/models/pokemon_detail_response.dart';

import 'package:pokeclase20263/snap/game/data/snap_pokemon.dart';

class SnapPokemonCatalog {
  static const int firstPokemonId = 1;
  static const int pokemmonCount = 151;
  static const int _batchSize = 8;

  static Future<List<SnapPokemon>> fetchFromApi({
    http.Client? client,
    int  startId = firstPokemonId,
    int count = pokemmonCount,
  }) async {
    if(startId <= 0 || count <= 0 || startId + count - 1 > 1025){
      throw ArgumentError('El rango de pokemon debe estar entre 1 y 1025');
    }

    final apiClient = client ?? http.Client();
    try{
      final pokemon = <SnapPokemon>[];
      final endId = startId + count;

      for(var batchStart = startId; batchStart < endId; batchStart += _batchSize){
        final batchEnd = (batchStart + _batchSize).clamp(startId, endId);
        final batch = await Future.wait([
          for (var id = batchStart; id < batchEnd; id++) _fetchPokemon(apiClient, id),
        ]);
        pokemon.addAll(batch);
      }

      return pokemon;
    } finally {
      if (client == null) apiClient.close();
    }
  }

  static Future<SnapPokemon> _fetchPokemon(http.Client client, int id) async {
    final uri = Uri.http('pokeapi.co', '/api/v2/pokemon/$id');
    final response = await client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpException('Pokepi respondio  ${response.statusCode} al solucionar ID $id');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Respuesta invalida de PokeAPI para ID $id');
    }

    final pokemon = PokemonDetailResponse.fromJson(decoded);
    if (pokemon.id != id || pokemon.name.isEmpty || pokemon.height <= 0){
      throw FormatException('Datos incomplletos de PokeAPI para ID $id');
    }

    final displayHeight = (120 + pokemon.height * 12).clamp(140, 260);
    return SnapPokemon(
      id: pokemon.id, 
      name:'${pokemon.name[0].toUpperCase()}${pokemon.name.substring(1)}', 
      displayHeight: displayHeight.toDouble(),
      isFlying: pokemon.types.any((type) => type.toString() == 'flying'),
    );
  }
}