import 'dart:convert';

import 'package:flutter/services.dart';

class SnapPokemon {
  final int id;
  final String name;
  final double displayHeight;
  final bool isFlying;
  final double spawnWeight;

  const SnapPokemon({
    required this.id, 
    required this.name, 
    required this.displayHeight,
    this.isFlying = false, 
    this.spawnWeight = 1.0,
  });

  //Ruta relativa a assets/images
  String get spriteAsset => 'pokemon/${id.toString().padLeft(3,'0')}.png';

  factory SnapPokemon.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final  name = json['name'];
    final displayHeight = json['displayHeight'];
    final isFlying = json['isFlying'] ?? false;
    final spawnWeight = json['spawnWeight'] ?? 1.0;

    if (id is! int || id <= 0){
      throw const FormatException('Cada pokemon debe tener un id positivo');
    }
    if (name is! String || name.isEmpty){
      throw FormatException('El pokemon $id debe tener un nombre');
    }
    if (displayHeight is! num || !displayHeight.isFinite || displayHeight <= 0){
      throw FormatException('Altura de pantalla invalida para $name.');
    }
    if (isFlying is! bool){
      throw FormatException('El indicador isFlying de $name debe ser booleano');
    }
    if (spawnWeight is! num || !spawnWeight.isFinite || spawnWeight <= 0){
      throw FormatException('El spawnWeight de $name debe ser positivo');
    }

    return SnapPokemon(
      id: id, 
      name: name, 
      displayHeight: displayHeight.toDouble(),
      isFlying: isFlying,
      spawnWeight: spawnWeight.toDouble(),
    );
  }

  static Future<List<SnapPokemon>> loadCatalog() async{
    final jsonText =  await rootBundle.loadString(
      'assets/data/snap_pokemon.json',
    );
    
    final decoded = jsonDecode(jsonText);
    if (decoded is! List) {
      throw const FormatException('El catalogo debe de ser una lista JSON');
    }

    final pokemon = decoded.map((entry) {
      if(entry is! Map<String, dynamic>) {
        throw const FormatException('Cada elemento del catalogo debe de ser un objeto JSON');
      }
      return SnapPokemon.fromJson(entry);
    }).toList();

    if (pokemon.isEmpty) {
      throw const FormatException('El catalogo de Pokemon esta vacio');
    }
    if (pokemon.map((def) => def.id).toSet().length != pokemon.length){
      throw const  FormatException('El contiene IDs duplicados');
    }

    return pokemon;
  }
}
