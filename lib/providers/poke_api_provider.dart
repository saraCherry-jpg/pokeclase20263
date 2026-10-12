import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokeclase20263/models/auth_response.dart';
import 'package:pokeclase20263/models/pokemon_detail_response.dart';

class PokeApiProvider extends ChangeNotifier {
  final String _baseUrl = 'pokeapi.co';
  final String _apiPatch = '/api/v2';

  //_______________________ Metodo para las listas de las genetaciones pokemon ________________
  Future<http.Response> getGenerations() async {
    final url = Uri.https(_baseUrl, "$_apiPatch/generation");
    final response = await http.get(url);
    return response;
  }

  Future<http.Response> getGenerationDetail(int id) async {
    final url = Uri.https(_baseUrl, '$_apiPatch/generation/$id');
    final response = await http.get(url);
    return response;
  }

  
  //______________ Metodo para ver las descrpiciones de pokemon __________________
  Future<http.Response> getPokemonDetail(int id) async {
    final url = Uri.https(_baseUrl, '$_apiPatch/pokemon/$id');
    final response = await http.get(url);
    return response;

  }

}


//_______________________ Metodo para ver el credencial de usuario ___________________
class AuthProvider extends ChangeNotifier {
  String? token;
  bool cargando = false;
  String? error;

  final String _baseUrl = 'BackPokemon.somee.com'; //es el servidor donde esta subido el backend

  //_____________ Metodo para permitir el acceso ___________
  Future<bool> login(String userName, String password) async {
    cargando = true;
    error = null;
    notifyListeners(); //notifica

    try{
      final url = Uri.http(_baseUrl, '/api/Auth/login'); //aqui es.. no es https
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userName': userName, 'password': password}),
      );

      //Valida si el usuario existe
      if (response.statusCode == 200){
        final loginResponse = LoginResponse.fromJson(jsonDecode(response.body));
        token = loginResponse.token;
        cargando = false;
        notifyListeners();
        return true;

      }else{
        error = 'No se pudo iniciar sesión (${response.statusCode})';
        cargando = false;
        notifyListeners();
        return false;

      }
    }catch (e){
      error = 'Error de Conexión: $e';
      cargando = false;
      notifyListeners();
      return false;

    }

  }

  //______________ Metodo para el registro __________________
  Future<bool> register(String userName, String email, String password) async {
    cargando = true;
    error = null;
    notifyListeners();

    try{
      final url = Uri.http(_baseUrl, 'api/Auth/register');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userName': userName,
          'email': email,
          'password': password,
        }),
      );

      //Verificación del registro
      if(response.statusCode == 200){
        RegisterResponse.fromJson(jsonDecode(response.body));
        cargando = false;
        notifyListeners();
        return true;

      }else{
        error = 'No se pudo registrar (${response.statusCode}): ${response.body}';
        cargando = false;
        notifyListeners();
        return false;
      }

    }catch (e) {
      error = 'Error de conexión: $e';
      cargando = false;
      notifyListeners();
      return false;
    }
  }




}


  //_______________________ Metodo para ver el Tamagotchi ___________________