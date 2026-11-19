import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokeclase20263/minijuegos/batalla/services/auth_service.dart';

String fakeJwt(Map<String, dynamic> claims) {
  String part(Object o) => base64Url.encode(utf8.encode(json.encode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(claims)}.firma';
}

void main() {
  test('el Id del usuario se lee del token de ASP.NET', () {
    final token = fakeJwt({
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier': 'usuario-mario',
      'unique_name': 'mario',
    });
    expect(AuthService.userIdFromToken(token), 'usuario-mario');
    expect(AuthService.userIdFromToken(fakeJwt({'sub': 'abc'})), 'abc');
    expect(AuthService.userIdFromToken('no-es-un-jwt'), isNull);
  });

  test('login manda usuario y contraseña y arma la sesión', () async {
    late http.Request sent;
    final auth = AuthService(
      baseUrl: 'https://pokeclase.somee.com',
      client: MockClient((r) async {
        sent = r;
        return http.Response(
            json.encode({'token': fakeJwt({'nameid': 'usuario-mario'}), 'expiration': '2026-10-01T18:00:00Z'}), 200);
      }),
    );
    final session = await auth.login(' mario ', 'Clave!1');
    expect(sent.url.toString(), 'https://pokeclase.somee.com/api/auth/login');
    expect(json.decode(sent.body), {'userName': 'mario', 'password': 'Clave!1'});
    expect(session.userId, 'usuario-mario');
    expect(session.userName, 'mario');
  });

  test('login incorrecto da un mensaje claro', () async {
    final auth = AuthService(baseUrl: 'https://x', client: MockClient((_) async => http.Response('', 401)));
    expect(
      () => auth.login('mario', 'mal'),
      throwsA(predicate((e) => e.toString().contains('Usuario o contraseña incorrectos'))),
    );
  });
}
