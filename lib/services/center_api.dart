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
      defaultValue: 'http://backpokemon.somee.com',
    ),
  }) : _client = client ?? http.Client();
  static final instance = CenterApi();
  final http.Client _client;
  final String baseUrl;
  void Function()? onUnauthorized;
  String? token;
  String? userName;

  Future<dynamic> request(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool post = false,
    bool authenticated = true,
  }) async {
    if (authenticated && token == null) {
      throw const ApiException(401, 'Inicia sesión para continuar.');
    }
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      if (authenticated) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    http.Response response;
    try {
      response =
          await (post
                  ? _client.post(
                      uri,
                      headers: headers,
                      body: body == null ? null : jsonEncode(body),
                    )
                  : _client.get(uri, headers: headers))
              .timeout(const Duration(seconds: 25));
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
        401:
            'La sesión venció o las credenciales son incorrectas. Inicia sesión.',
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
      '/api/auth/login',
      post: true,
      authenticated: false,
      body: {'userName': name, 'password': password},
    );
    token = data['token'] as String;
    userName = name;
  }

  Future<List<Map<String, dynamic>>> pokemon({
    bool availableOnly = false,
  }) async =>
      (await request(
                '/me/pokemon',
                query: availableOnly ? {'available': 'true'} : null,
              )
              as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<List<Map<String, dynamic>>> trades() async =>
      (await request('/me/trades') as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<List<Map<String, dynamic>>> users(String search) async =>
      (await request('/users', query: {'search': search}) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<int> heal() async =>
      (await request('/me/pokemon/heal', post: true))['healed'] as int;
  Future<dynamic> create(String recipient, int pokemonId) => request(
    '/trades',
    post: true,
    body: {'recipientUserId': recipient, 'pokemonUserId': pokemonId},
  );
  Future<dynamic> detail(int id) => request('/trades/$id');
  Future<dynamic> action(int id, String action, {int? pokemonId}) => request(
    '/trades/$id/$action',
    post: true,
    body: pokemonId == null ? null : {'pokemonUserId': pokemonId},
  );
}
