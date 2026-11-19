import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

// Sesión del usuario después del login del backend (POST /api/auth/login)
class AuthSession {
  final String token;     // JWT que va en "Authorization: Bearer ..."
  final String userId;    // AspNetUsers.Id, sacado del token
  final String userName;
  final DateTime? expiration;

  AuthSession({required this.token, required this.userId, required this.userName, this.expiration});
}

// Login del backend del equipo. El login solo devuelve { token, expiration }, así que
// el Id del usuario se lee de adentro del token (los JWT de ASP.NET Identity lo traen).
class AuthService {
  final String baseUrl;
  final http.Client _client;

  AuthService({required String baseUrl, http.Client? client})
      : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  Future<AuthSession> login(String userName, String password) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/api/auth/login'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: json.encode({'userName': userName.trim(), 'password': password}),
        )
        .timeout(backendTimeout);
    if (response.statusCode == 401) throw Exception('Usuario o contraseña incorrectos');
    if (response.statusCode != 200) throw Exception('No se pudo iniciar sesión (${response.statusCode})');

    final body = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final token = body['token'] as String;
    final userId = userIdFromToken(token);
    if (userId == null) throw Exception('El token no trae el Id del usuario');

    return AuthSession(
      token: token,
      userId: userId,
      userName: userName.trim(),
      expiration: DateTime.tryParse(body['expiration']?.toString() ?? ''),
    );
  }

  // Nombres que suele usar ASP.NET para el Id del usuario dentro del JWT
  static const _idClaims = [
    'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier',
    'nameid',
    'sub',
    'uid',
    'userId',
    'id',
  ];

  // Lee la parte del medio del JWT (base64) y busca el Id del usuario
  static String? userIdFromToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if (payload is! Map) return null;
      for (final claim in _idClaims) {
        final value = payload[claim];
        if (value != null && value.toString().isNotEmpty) return value.toString();
      }
    } catch (_) {}
    return null;
  }
}
