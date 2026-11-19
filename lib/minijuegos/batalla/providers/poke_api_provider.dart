import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Mismo estilo que el PokeApiProvider de la pokeclase: cada método devuelve la respuesta
// HTTP y quien la usa la convierte con su modelo. Al juntar los proyectos, estos métodos
// se pueden agregar al provider que ya existe allá (getPokemonDetail ya está igual).
class PokeApiProvider extends ChangeNotifier {
  final String _baseUrl = 'pokeapi.co';
  final String _apiPatch = '/api/v2';

  Future<http.Response> getPokemonDetail(int id) async {
    final url = Uri.https(_baseUrl, '$_apiPatch/pokemon/$id');
    return http.get(url);
  }

  // El detalle de un movimiento (poder, precisión, tipo...) viene en un endpoint aparte
  Future<http.Response> getMove(String name) async {
    final url = Uri.https(_baseUrl, '$_apiPatch/move/$name');
    return http.get(url);
  }
}
