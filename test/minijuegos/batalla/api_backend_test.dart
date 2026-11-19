import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/battle_item.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/battle_result.dart';
import 'package:pokeclase20263/minijuegos/batalla/models/status_condition.dart';
import 'package:pokeclase20263/minijuegos/batalla/services/battle_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Prueba ApiBattleBackend con las respuestas de ejemplo de EndpointsBatallas del equipo
void main() {
  SharedPreferences.setMockInitialValues({});
  final requests = <http.Request>[];

  http.Response respond(http.Request r) {
    requests.add(r);
    final path = r.url.path;
    if (r.method == 'GET' && path == '/api/PokemonUser/usuario/usuario-id') {
      return http.Response(
          json.encode([
            {
              'id': 12,
              'idPokemon': 25,
              'idUsuario': 'usuario-id',
              'nombre': 'pikachu',
              'pokemonEstado': {
                'vidaTotal': 100,
                'vidaActual': 90,
                'estado': 1,
                'ataqueBase': 55,
                'defensaBase': 40,
                'velocidadBase': 90,
                'tipoPrimario': 'electric',
                'tipoSecundario': null,
                'urlFrontal': 'https://f',
                'urlTrasera': 'https://b',
              },
            }
          ]),
          200);
    }
    if (r.method == 'GET' && path == '/api/ItemUser/usuario/usuario-id') {
      return http.Response.bytes(
          utf8.encode(json.encode([
            {
              'id': 3,
              'idItem': 1,
              'idUser': 'usuario-id',
              'cantidad': 2,
              'item': {
                'id': 1,
                'nombre': 'Poción',
                'probabilidad': 0.5,
                'urlImagen': 'https://i',
                'descripcion': 'Recupera vida',
                'efecto': 'curar',
                'valor': 20,
              },
            }
          ])),
          200);
    }
    if (r.method == 'GET' && path == '/api/Batallas/usuario/usuario-id/resumen') {
      return http.Response(
          json.encode({'total': 57, 'victorias': 38, 'derrotas': 15, 'huidas': 4, 'winRate': 0.717}), 200);
    }
    if (r.method == 'GET' && path == '/api/Batallas/usuario/usuario-id') {
      // Formato paginado de CambiosEndpointsTracker (sección 2.3)
      return http.Response(
          json.encode({
            'total': 1,
            'pagina': 1,
            'tamano': 100,
            'items': [
              {
                'id': 41,
                'fecha': '2026-10-22T16:40:00Z',
                'resultado': 'Derrota',
                'idPokemonRival': 19,
                'pokemon': {'id': 12, 'idPokemon': 25, 'nombre': 'Pikachu', 'urlFrontal': 'f.png'},
              }
            ],
          }),
          200);
    }
    if (r.method == 'POST' && path == '/api/Batallas') return http.Response(r.body, 201);
    if (r.method == 'PUT') return http.Response('', 204);
    if (r.method == 'POST' && path == '/api/ItemUser') return http.Response('', 200);
    return http.Response('', 500);
  }

  final api = ApiBattleBackend(
    baseUrl: 'https://pokeclase.somee.com/',
    client: MockClient((r) async => respond(r)),
  );

  setUp(requests.clear);

  test('lee el equipo del usuario', () async {
    final team = await api.getMyPokemon('usuario-id');
    expect(requests.single.url.toString(), 'https://pokeclase.somee.com/api/PokemonUser/usuario/usuario-id');
    expect(team.single.idPokemonUser, 12);
    expect(team.single.currentHp, 90);
    expect(team.single.status, StatusCondition.sano);
  });

  test('guarda vida y estado como id de la tabla Estados', () async {
    final p = (await api.getMyPokemon('usuario-id')).single
      ..currentHp = 40
      ..status = StatusCondition.quemado;
    await api.updateEstado(p);
    final put = requests.last;
    expect(put.method, 'PUT');
    expect(put.url.path, '/api/PokemonEstado/12');
    expect(json.decode(put.body), {'vidaActual': 40, 'estado': 3});
  });

  test('lee la mochila y gasta un objeto', () async {
    final bag = (await api.getMyItems('usuario-id')).single;
    expect(bag.item.nombre, 'Poción');
    expect(bag.item.efecto, ItemEffect.curar);
    expect(bag.item.valor, 20);
    bag.cantidad = 1;
    await api.updateItemQuantity(bag);
    expect(requests.last.url.path, '/api/ItemUser/3');
    expect(json.decode(requests.last.body), {'cantidad': 1});
  });

  test('registra la batalla con resultado y lee el historial paginado', () async {
    await api.saveBattle(BattleResult(
      idPokemonUserRetador: 12,
      idPokemonRival: 25,
      resultado: BattleResultado.huida,
    ));
    // Ya no se manda fecha, pokemonUserGanador ni el usuario
    expect(json.decode(requests.last.body), {'pokemonUserR': 12, 'idPokemonRival': 25, 'resultado': 'Huida'});

    final history = await api.getMyBattles('usuario-id');
    expect(requests.last.url.queryParameters, {'pagina': '1', 'tamano': '100'});
    expect(history.single.resultado, BattleResultado.derrota);
    expect(history.single.idPokemonUserRetador, 12);
    expect(history.single.nombre, 'Pikachu');
    expect(history.single.fecha!.toUtc(), DateTime.utc(2026, 10, 22, 16, 40));

    final summary = await api.getBattleSummary('usuario-id');
    expect(summary.victorias, 38);
    expect(summary.huidas, 4);
    expect(summary.winRate, 0.717);
  });

  test('lee el historial aunque venga como lista sola (como Somee hoy)', () async {
    final old = ApiBattleBackend(
      baseUrl: 'https://pokeclase.somee.com',
      client: MockClient((r) async => http.Response(
          json.encode([
            {'id': 1, 'fecha': '2026-10-29T19:00:00Z', 'resultado': 'Victoria', 'idPokemonRival': 4}
          ]),
          200)),
    );
    final history = await old.getMyBattles('usuario-id');
    expect(history.single.resultado, BattleResultado.victoria);
  });

  test('añade el premio al inventario', () async {
    await api.addItem('usuario-id', ItemInfo(id: 1, nombre: 'Poción', efecto: ItemEffect.curar), 1);
    expect(requests.last.url.path, '/api/ItemUser');
    expect(json.decode(requests.last.body), {'idItem': 1, 'cantidad': 1});
  });

  test('manda el token del login en cada petición', () async {
    api.token = 'abc.def.ghi';
    await api.getItemCatalog().catchError((_) => <Never>[]);
    expect(requests.last.headers['Authorization'], 'Bearer abc.def.ghi');
    api.token = null;
  });

  test('un error del servidor se convierte en excepción', () async {
    final broken = ApiBattleBackend(baseUrl: 'https://x', client: MockClient((_) async => http.Response('', 500)));
    expect(broken.getItemCatalog(), throwsException);
  });
}
