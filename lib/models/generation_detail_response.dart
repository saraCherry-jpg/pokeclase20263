import 'dart:convert';
import 'package:flutter/material.dart';

class GenerationDetailResponse {
  final id;
  final String name;
  final List<PokemonSpeciesItem> pokemonSpecies;


  //constructor
  GenerationDetailResponse({
    required this.id,
    required this.name,
    required this.pokemonSpecies
  });

  
  //________________ Metodos... ________________
  factory GenerationDetailResponse.fromRawJson(String str) => GenerationDetailResponse.fromJson(json.decode(str));

  factory GenerationDetailResponse.fromJson(Map<String, dynamic> json){
    var list = json['pokemon_species'] as List? ?? [];
    List<PokemonSpeciesItem> speciesList = list.map((i) => PokemonSpeciesItem.fromJson(i)).toList();

    return GenerationDetailResponse(
      id: json["id"] ?? 0,
      name: json['name'] ?? '',
      pokemonSpecies: speciesList

    );
  }

  Map<String, dynamic> toJson() =>{
    'id': id,
    'name': name,
    'pokemon_species': pokemonSpecies.map((x) => x.toJson()).toList()
  };
}


//_____________________ nueva clase___________________________
class PokemonSpeciesItem{
  final String name;
  final String url;

  //constructor
  PokemonSpeciesItem({
    required this.name,
    required this.url
  });

  

  //________ metodos __________________
  factory PokemonSpeciesItem.fromRawJson(String str) => PokemonSpeciesItem.fromJson(json.decode(str));

  factory PokemonSpeciesItem.fromJson(Map<String, dynamic> json){
    return  PokemonSpeciesItem(
      name: json['name'],
      url: json['url']
    );
  }

  Map<String, dynamic> toJson() => {
    "name": name,
    "url": url
  };

  //Extraer el ID del pokemon desde la url
  int get id{
    final uri =Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return int.parse(segments.last);

  }
}