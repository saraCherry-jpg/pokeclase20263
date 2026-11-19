import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/battle_item.dart';
import 'package:pokeclase20263/minijuegos/batalla/services/battle_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Somee hoy: /api/Item vacío y POST /api/ItemUser da 405.
// El premio sale de la PokeAPI y se guarda en el teléfono.
void main() {
  // JWT con el Id "usuario-id" (nameidentifier), como el de Somee
  final payload = base64Url.encode(utf8.encode(json.encode(
      {'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier': 'usuario-id'})));
  final token = 'x.$payload.y';

  final requests = <http.Request>[];
  http.Response respond(http.Request r) {
    requests.add(r);
    if (r.url.host == 'pokeapi.co') {
      final slug = r.url.pathSegments.last;
      if (slug != 'potion') return http.Response('', 404);
      return http.Response.bytes(
          utf8.encode(json.encode({
            'id': 17,
            'name': 'potion',
            'names': [
              {'name': 'Potion', 'language': {'name': 'en'}},
              {'name': 'Poción', 'language': {'name': 'es'}},
            ],
            'flavor_text_entries': [
              {'text': 'Restaura 20 PS\na un Pokémon.', 'language': {'name': 'es'}},
            ],
            'sprites': {'default': 'https://sprites/potion.png'},
          })),
          200);
    }
    final path = r.url.path;
    if (path == '/api/Item') return http.Response('[]', 200);
    if (path == '/api/ItemUser/usuario/usuario-id') return http.Response('[]', 200);
    if (path == '/api/ItemUser') return http.Response('', 405);
    return http.Response('', 500);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
  });

  test('sin objetos en Somee, el premio sale de la PokeAPI y queda en la mochila', () async {
    final api = ApiBattleBackend(
      baseUrl: 'http://backpokemon.somee.com',
      token: token,
      client: MockClient((r) async => respond(r)),
    );

    final catalog = await api.getItemCatalog();
    final potion = catalog.single;
    expect(potion.id, 17);
    expect(potion.nombre, 'Poción');
    expect(potion.efecto, ItemEffect.curar);
    expect(potion.valor, 20);
    expect(potion.urlImagen, 'https://sprites/potion.png');
    expect(potion.descripcion, 'Restaura 20 PS a un Pokémon.');

    await api.addItem('usuario-id', potion, 1);
    await api.addItem('usuario-id', potion, 1);
    expect(requests.where((r) => r.url.path == '/api/ItemUser' && r.method == 'POST'), isEmpty);

    final bag = (await api.getMyItems('usuario-id')).single;
    expect(bag.local, isTrue);
    expect(bag.cantidad, 2);
    expect(bag.item.nombre, 'Poción');

    // Al usarla baja la cantidad en el teléfono, no en Somee
    bag.cantidad = 0;
    await api.updateItemQuantity(bag);
    expect(requests.where((r) => r.method == 'PUT'), isEmpty);
    expect(await api.getMyItems('usuario-id'), isEmpty);
  });

  test('si Somee tiene objetos pero no el POST, el premio también se guarda en el teléfono', () async {
    final api = ApiBattleBackend(
      baseUrl: 'http://backpokemon.somee.com',
      token: token,
      client: MockClient((r) async => respond(r)),
    );
    await api.addItem('usuario-id', ItemInfo(id: 1, nombre: 'Poción', efecto: ItemEffect.curar), 1);
    expect(requests.last.url.path, '/api/ItemUser');
    expect((await api.getMyItems('usuario-id')).single.local, isTrue);
  });
}
