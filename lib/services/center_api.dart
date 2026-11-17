import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int status;
  final String message;
  const ApiException(this.status, this.message);
  @override
  String toString() => message;
}

/// Session stays in memory; neither passwords nor JWTs are saved in the repo.
class CenterApi {
  CenterApi({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'https://backpokemon.runasp.net',
    ),
  }) : _client = client ?? http.Client();
  static final instance = CenterApi();
  final http.Client _client;
  final String baseUrl;
  void Function()? onUnauthorized;
  String? token;
  String? userName;

  Uri uri(String path) =>
      Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path');

  Future<dynamic> request(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String method = 'GET',
    bool authenticated = true,
  }) async {
    if (authenticated && token == null) {
      throw const ApiException(401, 'Inicia sesión para continuar.');
    }
    final uri = this.uri(path).replace(queryParameters: query);
    final headers = <String, String>{
      if (authenticated) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    http.Response response;
    try {
      response = await (() async {
        final request = http.Request(method, uri)..headers.addAll(headers);
        if (body != null) request.body = jsonEncode(body);
        return http.Response.fromStream(await _client.send(request));
      })().timeout(const Duration(seconds: 25));
    } catch (_) {
      throw const ApiException(
        0,
        'No se pudo verificar la respuesta. Actualiza los intercambios antes de repetir una operación.',
      );
    }
    final text = utf8.decode(response.bodyBytes);
    dynamic data = text.isEmpty ? null : text;
    if (text.isNotEmpty &&
        (response.headers['content-type'] ?? '').contains('json')) {
      try {
        data = jsonDecode(text);
      } catch (_) {
        throw const ApiException(
          0,
          'El servidor devolvió una respuesta inválida. Actualiza antes de repetir.',
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 && authenticated) {
        token = null;
        onUnauthorized?.call();
      }
      final messages = {
        401: 'La sesión venció o las credenciales son incorrectas. Inicia sesión.',
        403: 'Tu rol no permite esta acción.',
        404: 'No se encontró el recurso.',
        409: 'Cambió el intercambio o la disponibilidad. Actualiza la lista.',
      };
      throw ApiException(
        response.statusCode,
        messages[response.statusCode] ??
            (data is Map
                ? '${data['errors'] ?? data['title'] ?? data}'
                : text.isEmpty
                ? 'HTTP ${response.statusCode}'
                : text),
      );
    }
    return data;
  }

  Future<void> login(String name, String password) async {
    final data = await request(
      '/api/Auth/login',
      method: 'POST',
      authenticated: false,
      body: {'userName': name, 'password': password},
    );
    token = data['token'] as String;
    userName = name;
  }

  Future<List<Map<String, dynamic>>> pokemon({
    bool availableOnly = false,
  }) async => (await request(
    '/api/me/pokemon',
    query: availableOnly ? {'available': 'true'} : null,
  ) as List).map((e) => Map<String, dynamic>.from(e)).toList();
  Future<List<Map<String, dynamic>>> trades() async =>
      (await request('/api/me/trades') as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<List<Map<String, dynamic>>> users(String search) async =>
      (await request('/api/Users', query: {'search': search}) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<void> heal(int pokemonUserId) async {
    await request('/api/me/pokemon/$pokemonUserId/heal', method: 'PATCH');
  }

  Future<dynamic> create(String recipient, int pokemonId) => request(
    '/api/trades',
    method: 'POST',
    body: {'recipientUserId': recipient, 'pokemonUserId': pokemonId},
  );
  Future<dynamic> detail(int id) => request('/api/trades/$id');
  Future<dynamic> action(int id, String action, {int? pokemonId}) => request(
    '/api/trades/$id/$action',
    method: 'POST',
    body: pokemonId == null ? null : {'pokemonUserId': pokemonId},
  );
}
