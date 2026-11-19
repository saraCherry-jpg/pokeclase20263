import 'package:flutter/material.dart';

import '../logic/type_chart.dart';

// Mismos colores por tipo que usa PokemonDetailScreen en la pokeclase.
// Al juntar los proyectos, lo ideal es que ambos usen este archivo.
const Map<String, Color> typeColors = {
  'normal': Color(0xFFA8A878),
  'fire': Color(0xFFF08030),
  'water': Color(0xFF6890F0),
  'electric': Color(0xFFF8D030),
  'grass': Color(0xFF78C850),
  'ice': Color(0xFF98D8D8),
  'fighting': Color(0xFFC03028),
  'poison': Color(0xFFA040A0),
  'ground': Color(0xFFE0C068),
  'flying': Color(0xFFA890F0),
  'psychic': Color(0xFFF85888),
  'bug': Color(0xFFA8B820),
  'rock': Color(0xFFB8A038),
  'ghost': Color(0xFF705898),
  'dragon': Color(0xFF7038F8),
  'dark': Color(0xFF705848),
  'steel': Color(0xFFB8B8D0),
  'fairy': Color(0xFFEE99AC),
};

const Map<String, String> typeNamesEs = {
  'normal': 'Normal', 'fire': 'Fuego', 'water': 'Agua', 'electric': 'Eléctrico',
  'grass': 'Planta', 'ice': 'Hielo', 'fighting': 'Lucha', 'poison': 'Veneno',
  'ground': 'Tierra', 'flying': 'Volador', 'psychic': 'Psíquico', 'bug': 'Bicho',
  'rock': 'Roca', 'ghost': 'Fantasma', 'dragon': 'Dragón', 'dark': 'Siniestro',
  'steel': 'Acero', 'fairy': 'Hada',
};

String typeLabel(String type) => typeNamesEs[normalizeType(type)] ?? capitalize(type);

Color colorForType(String type) => typeColors[normalizeType(type)] ?? const Color(0xFF9AA0AB);

String capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
