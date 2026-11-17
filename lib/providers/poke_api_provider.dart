import 'dart:convert';
import 'package:pokeclase20263/services/center_api.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pokeclase20263/models/auth_response.dart';

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



   //_______________________ Metodo para ver el Tamagotchi (CONSULTAS) ___________________

  Future<http.Response> getTamagotchi(String token) async {
    final url = CenterApi.instance.uri('/api/tamagotchi'); //es el endpoint
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    return response;
  }


  Future<http.Response> getTamagotchiById(int id, String token) async {
    final url = CenterApi.instance.uri('/api/tamagotchi/$id');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    return response;
  }


  Future<http.Response> adoptarTamagotchi(int idPokemonUser, String token) async {
    final url = CenterApi.instance.uri('/api/tamagotchi');
    final response = await http.post(
      url,
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'idPokemonUser': idPokemonUser}) 
    );
    return response;
  }


  Future<http.Response> realizarActividadTamagotchi(int id, String tipo, String token) async {
    final url = CenterApi.instance.uri('/api/tamagotchi/$id/actividad');
    final response = await http.post(
      url,
      headers: {'Authorization': 'Bearer $token','Content-Type': 'application/json'},
      body: jsonEncode({'tipo': tipo})
    );
    return response;
  }



  Future<http.Response> liberarTamagotchi(int id, String token) async {
    final url = CenterApi.instance.uri('/api/tamagotchi/$id');
    final response = await http.delete(url, headers: {'Authorization': 'Bearer $token'});
    return response;

  }


  
}
  //getTamagotchis(String token) {}




//_______________________ Metodo para ver el credencial de usuario ___________________
class AuthProvider extends ChangeNotifier {
  String? token;
  bool cargando = false;
  String? error;



  //_____________ Metodo para permitir el acceso ___________
  Future<bool> login(String userName, String password) async {
    cargando = true;
    error = null;
    notifyListeners(); //notifica

    try{
      final url = CenterApi.instance.uri('/api/Auth/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userName': userName, 'password': password}),
      );

      //Valida si el usuario existe
      if (response.statusCode == 200){
        final loginResponse = LoginResponse.fromJson(jsonDecode(response.body));
        token = loginResponse.token;
        CenterApi.instance.token = token;
        CenterApi.instance.userName = userName;
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
      final url = CenterApi.instance.uri('/api/Auth/register');
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


 
