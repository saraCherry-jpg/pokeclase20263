import 'package:flutter/widgets.dart';

class PokemonDetailResponse {
  final int id;
  final String name;
  final String imageUrl;
  final double height;
  final double weight;
  final int baseExperience;
  final List<String> types;
  final List<String> abilities;
  final Map<String, int> stats;
  final String cryUrl;


  //Constructor
  PokemonDetailResponse({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.height,
    required this.weight,
    required this.baseExperience,
    required this.types,
    required this.abilities,
    required this.stats,
    required this.cryUrl

  });

  factory PokemonDetailResponse.fromJson(Map<String, dynamic> json) {
    return PokemonDetailResponse(
      id: json['id'], 
      name: json['name'], 
      imageUrl: json['sprites']['front_default'] ?? '', 
      height: (json['height'] as int) / 10,  //la API da decimetros
      weight: (json['weight'] as int) / 10, //la API da hectogramos
      baseExperience: json['base_Experience'] ?? 0, 
      types: (json['types'] as List)
        .map((t) => t['type']['name'] as String)
        .toList(), 
      abilities: (json['abilities'] as List)
        .map((a) => a['ability']['name'] as String)
        .toList(), 
      stats: {
        for(var s in (json['stats'] as List))
          s['stat']['name'] as String: s['base_stat'] as int
      }, 
      cryUrl: json['cries']?['latest'] ?? '',
    );

  }


}