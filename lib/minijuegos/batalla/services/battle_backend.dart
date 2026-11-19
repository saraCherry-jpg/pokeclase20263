import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import '../models/battle_item.dart';
import '../models/battle_pokemon.dart';
import '../models/battle_result.dart';
import 'auth_service.dart';
import 'local_bag.dart';

// Lo que batallas necesita del backend del equipo (ASP.NET en Somee).
// Hay dos versiones:
//   - ApiBattleBackend: llama a los endpoints reales (ver EndpointsBatallas del equipo).
//     Se usa cuando hay una dirección en config/backend_config.dart.
//   - MockBattleBackend: datos falsos con la misma forma, para probar sin internet.
abstract class BattleBackend {
  // GET /api/PokemonUser/usuario/{userId}  (cada PokemonUser con su PokemonEstado)
  Future<List<BattlePokemon>> getMyPokemon(String userId);

  // PUT /api/PokemonEstado/{idPokemonUser}  body: { vidaActual, estado }
  Future<void> updateEstado(BattlePokemon pokemon);

  // POST /api/Batallas  body: { pokemonUserR, idPokemonRival, resultado }
  // (la fecha y el usuario los pone el backend; también se guardan las huidas)
  Future<void> saveBattle(BattleResult result);

  // GET /api/Batallas/usuario/{userId}?pagina=1&tamano=100  -> { total, pagina, tamano, items }
  // De la más reciente a la más antigua.
  Future<List<BattleResult>> getMyBattles(String userId);

  // GET /api/Batallas/usuario/{userId}/resumen  (victorias, derrotas, huidas, winRate)
  Future<BattleSummary> getBattleSummary(String userId);

  // GET /api/ItemUser/usuario/{userId}  (cada ItemUser con su Item incluido)
  Future<List<BagItem>> getMyItems(String userId);

  // PUT /api/ItemUser/{id}  body: { cantidad }  (la cantidad que queda después de usarlo)
  Future<void> updateItemQuantity(BagItem bagItem);

  // GET /api/Item  (catálogo con Probabilidad, para el premio al ganar)
  // Si Somee no tiene objetos, se arma con las medicinas de la PokeAPI.
  Future<List<ItemInfo>> getItemCatalog();

  // POST /api/ItemUser  body: { idItem, cantidad }  (el usuario sale del token; suma si ya lo tiene)
  // Los premios de la PokeAPI se guardan en el teléfono (LocalBag).
  Future<void> addItem(String userId, ItemInfo item, int cantidad);
}

class ApiBattleBackend implements BattleBackend {
  final String baseUrl;       // Viene de config/backend_config.dart (https://backpokemon.runasp.net)
  String? token;              // JWT de POST /api/auth/login (se pone al iniciar sesión)
  final http.Client _client;  // Se puede cambiar en las pruebas
  final LocalBag _localBag;   // Premios guardados en el teléfono
  bool _catalogFromPokeApi = false;

  ApiBattleBackend({required String baseUrl, this.token, http.Client? client, LocalBag? localBag})
      : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client(),
        _localBag = localBag ?? LocalBag();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _url(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _get(String path, String error) async {
    final response = await _client.get(_url(path), headers: _headers).timeout(backendTimeout);
    if (response.statusCode == 401) throw Exception('Tu sesión venció, vuelve a iniciar sesión');
    if (response.statusCode != 200) throw Exception('$error (${response.statusCode})');
    if (response.body.trim().isEmpty) return [];
    return json.decode(utf8.decode(response.bodyBytes));
  }

  Future<http.Response> _send(String method, String path, Object body) {
    final url = _url(path);
    final encoded = json.encode(body);
    final request = method == 'PUT'
        ? _client.put(url, headers: _headers, body: encoded)
        : _client.post(url, headers: _headers, body: encoded);
    return request.timeout(backendTimeout);
  }

  void _check(http.Response response, String error) {
    if (response.statusCode == 401) throw Exception('Tu sesión venció, vuelve a iniciar sesión');
    if (response.statusCode >= 300) throw Exception('$error (${response.statusCode})');
  }

  @override
  Future<List<BattlePokemon>> getMyPokemon(String userId) async {
    final list = await _get('/api/PokemonUser/usuario/$userId', 'No se pudieron cargar tus Pokémon') as List;
    return list.map((e) => BattlePokemon.fromJson(e)).toList();
  }

  @override
  Future<void> updateEstado(BattlePokemon pokemon) async {
    final response = await _send('PUT', '/api/PokemonEstado/${pokemon.idPokemonUser}', pokemon.toEstadoJson());
    _check(response, 'No se pudo guardar la vida del Pokémon');
  }

  @override
  Future<void> saveBattle(BattleResult result) async {
    final response = await _send('POST', '/api/Batallas', result.toJson());
    _check(response, 'No se pudo guardar la batalla');
  }

  @override
  Future<List<BattleResult>> getMyBattles(String userId) async {
    final page = await _get('/api/Batallas/usuario/$userId?pagina=1&tamano=100', 'No se pudo cargar el historial');
    // Somee todavía devuelve la lista sola, sin { total, items }
    final list = page is List ? page : page['items'] as List? ?? [];
    return list.map((e) => BattleResult.fromJson(e)).toList();
  }

  @override
  Future<BattleSummary> getBattleSummary(String userId) async {
    final json = await _get('/api/Batallas/usuario/$userId/resumen', 'No se pudo cargar el resumen');
    return BattleSummary.fromJson(json);
  }

  @override
  Future<List<BagItem>> getMyItems(String userId) async {
    final list = await _get('/api/ItemUser/usuario/$userId', 'No se pudo cargar la mochila') as List;
    return [
      ...list.map((e) => BagItem.fromJson(e)),
      ...await _localBag.load(userId),
    ];
  }

  @override
  Future<void> updateItemQuantity(BagItem bagItem) async {
    if (bagItem.local) {
      final userId = _userIdFromToken();
      if (userId != null) await _localBag.setQuantity(userId, bagItem.item.id, bagItem.cantidad);
      return;
    }
    final response = await _send('PUT', '/api/ItemUser/${bagItem.idItemUser}', {'cantidad': bagItem.cantidad});
    _check(response, 'No se pudo gastar el objeto');
  }

  @override
  Future<List<ItemInfo>> getItemCatalog() async {
    final list = await _get('/api/Item', 'No se pudo cargar el catálogo de objetos') as List;
    final items = list.map((e) => ItemInfo.fromJson(e)).where((i) => i.usableInBattle).toList();
    _catalogFromPokeApi = items.isEmpty;
    return items.isEmpty ? await _pokeApiCatalog() : items;
  }

  @override
  Future<void> addItem(String userId, ItemInfo item, int cantidad) async {
    if (!_catalogFromPokeApi) {
      final response =
          await _send('POST', '/api/ItemUser', {'idItem': item.id, 'cantidad': cantidad});
      // 404/405: Somee todavía no tiene el POST, se guarda en el teléfono
      if (response.statusCode != 404 && response.statusCode != 405) {
        _check(response, 'No se pudo guardar el premio');
        return;
      }
    }
    await _localBag.add(userId, item, cantidad);
  }

  // Medicinas de la PokeAPI que pueden tocar de premio, con su probabilidad (peso)
  static const _pokeApiRewards = {
    'potion': 40.0,
    'super-potion': 20.0,
    'antidote': 12.0,
    'awakening': 10.0,
    'paralyze-heal': 10.0,
    'burn-heal': 8.0,
    'hyper-potion': 8.0,
    'ice-heal': 6.0,
    'revive': 5.0,
    'full-heal': 5.0,
  };
  static List<ItemInfo>? _pokeApiCache;

  // GET https://pokeapi.co/api/v2/item/{nombre}: nombre y descripción en español y la imagen.
  // El efecto se deduce del nombre (ItemInfo._fromName), con los valores de la escala 0-100.
  Future<List<ItemInfo>> _pokeApiCatalog() async {
    if (_pokeApiCache != null) return _pokeApiCache!;
    final items = await Future.wait(_pokeApiRewards.entries.map((e) async {
      try {
        final response = await _client
            .get(Uri.https('pokeapi.co', '/api/v2/item/${e.key}'))
            .timeout(backendTimeout);
        if (response.statusCode != 200) return null;
        final data = json.decode(utf8.decode(response.bodyBytes));
        String? spanish(List list, String field) =>
            list.lastWhere((x) => x['language']['name'] == 'es', orElse: () => null)?[field];
        return ItemInfo.fromJson({
          'id': data['id'],
          'nombre': spanish(data['names'], 'name') ?? e.key,
          'urlImagen': data['sprites']?['default'] ?? '',
          'descripcion': (spanish(data['flavor_text_entries'], 'text') ?? '').replaceAll(RegExp(r'\s+'), ' '),
          'probabilidad': e.value,
        });
      } catch (_) {
        return null;
      }
    }));
    final catalog = items.whereType<ItemInfo>().where((i) => i.usableInBattle).toList();
    if (catalog.isEmpty) throw Exception('No se pudo cargar el catálogo de la PokeAPI');
    return _pokeApiCache = catalog;
  }

  String? _userIdFromToken() => token == null ? null : AuthService.userIdFromToken(token!);
}

// Backend falso en memoria. Los JSON tienen la misma forma que los del backend real.
// Se usa cuando config/backend_config.dart no tiene dirección (y en las pruebas).
class MockBattleBackend implements BattleBackend {
  static const _userId = 'usuario-demo';

  static String _front(int id) =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';
  static String _back(int id) =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/back/$id.png';
  static String _itemSprite(String name) =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/$name.png';

  static Map<String, dynamic> _row(int id, int idPokemon, String nombre, int vidaTotal,
          int vidaActual, int estado, int ataque, int defensa, int velocidad,
          String tipo1, String? tipo2) =>
      {
        'id': id,
        'idPokemon': idPokemon,
        'idUsuario': _userId,
        'nombre': nombre,
        'pokemonEstado': {
          'idPokemonUser': id,
          'vidaTotal': vidaTotal,
          'vidaActual': vidaActual,
          'estado': estado,
          'idPokeball': 1,
          'ataqueBase': ataque,
          'defensaBase': defensa,
          'velocidadBase': velocidad,
          'tipoPrimario': tipo1,
          'tipoSecundario': tipo2,
          'urlFrontal': _front(idPokemon),
          'urlTrasera': _back(idPokemon),
        },
      };

  // Stats base reales de la PokeAPI, con la vida topada a 100
  final List<Map<String, dynamic>> _rows = [
    // estado: id de la tabla Estados (1 Sano, 5 Paralizado...)
    _row(1, 6, 'charizard', 78, 78, 1, 84, 78, 100, 'fire', 'flying'),
    _row(2, 9, 'blastoise', 79, 79, 1, 83, 100, 78, 'water', null),
    _row(3, 25, 'pikachu', 35, 20, 5, 55, 40, 90, 'electric', null),
    _row(4, 1, 'bulbasaur', 45, 0, 1, 49, 49, 45, 'grass', 'poison'),
  ];

  // Tabla Item (con Efecto y Valor)
  static Map<String, dynamic> _item(int id, String nombre, String sprite, double probabilidad,
          String efecto, int valor, String descripcion) =>
      {
        'id': id,
        'nombre': nombre,
        'probabilidad': probabilidad,
        'urlImagen': _itemSprite(sprite),
        'descripcion': descripcion,
        'efecto': efecto,
        'valor': valor,
      };

  final List<Map<String, dynamic>> _items = [
    _item(1, 'Poción', 'potion', 40, 'Curar', 20, 'Recupera 20 PS.'),
    _item(2, 'Superpoción', 'super-potion', 20, 'Curar', 50, 'Recupera 50 PS.'),
    _item(3, 'Hiperpoción', 'hyper-potion', 8, 'Curar', 100, 'Recupera todos los PS.'),
    _item(4, 'Revivir', 'revive', 5, 'Revivir', 50, 'Revive a un Pokémon con la mitad de sus PS.'),
    _item(5, 'Antídoto', 'antidote', 12, 'CurarEstado', 4, 'Cura el envenenamiento.'),
    _item(6, 'Despertar', 'awakening', 10, 'CurarEstado', 2, 'Despierta a un Pokémon dormido.'),
    _item(7, 'Cura Total', 'full-heal', 5, 'CurarEstado', 0, 'Cura cualquier problema de estado.'),
    _item(8, 'Poké Ball', 'poke-ball', 20, 'Pokeball', 0, 'Sirve para atrapar Pokémon.'),
  ];

  // Tabla ItemUser (idItem -> cantidad) del usuario de prueba
  final Map<int, int> _bag = {1: 3, 4: 1, 5: 2, 8: 5};
  int _nextBattleId = 1;

  final List<Map<String, dynamic>> savedBattles = [];

  @override
  Future<List<BattlePokemon>> getMyPokemon(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300)); // Simula la red
    return _rows
        .where((r) => r['idUsuario'] == userId)
        .map((r) => BattlePokemon.fromJson(json.decode(json.encode(r))))
        .toList();
  }

  @override
  Future<void> updateEstado(BattlePokemon pokemon) async {
    final row = _rows.firstWhere((r) => r['id'] == pokemon.idPokemonUser);
    (row['pokemonEstado'] as Map<String, dynamic>).addAll(pokemon.toEstadoJson());
  }

  @override
  Future<void> saveBattle(BattleResult result) async {
    savedBattles.add({
      'id': _nextBattleId++,
      'idUsuario': _userId, // Como el backend: el usuario sale del token
      'fecha': DateTime.now().toUtc().toIso8601String(),
      ...result.toJson(),
    });
  }

  @override
  Future<List<BattleResult>> getMyBattles(String userId) async {
    final items = savedBattles.where((b) => b['idUsuario'] == userId).toList().reversed.map((b) {
      final row = _rows.firstWhere((r) => r['id'] == b['pokemonUserR']);
      return {
        'id': b['id'],
        'fecha': b['fecha'],
        'resultado': b['resultado'],
        'idPokemonRival': b['idPokemonRival'],
        'pokemon': {
          'id': row['id'],
          'idPokemon': row['idPokemon'],
          'nombre': row['nombre'],
          'urlFrontal': (row['pokemonEstado'] as Map)['urlFrontal'],
        },
      };
    });
    return items.map(BattleResult.fromJson).toList();
  }

  @override
  Future<BattleSummary> getBattleSummary(String userId) async =>
      BattleSummary.fromBattles(await getMyBattles(userId));

  @override
  Future<List<BagItem>> getMyItems(String userId) async {
    if (userId != _userId) return [];
    return _bag.entries
        .where((e) => e.value > 0)
        .map((e) => BagItem.fromJson({
              'id': e.key, // En el mock el id de ItemUser es el mismo que el del Item
              'idItem': e.key,
              'idUser': userId,
              'cantidad': e.value,
              'item': _items.firstWhere((i) => i['id'] == e.key),
            }))
        .toList();
  }

  @override
  Future<void> updateItemQuantity(BagItem bagItem) async {
    _bag[bagItem.idItemUser] = bagItem.cantidad;
  }

  @override
  Future<List<ItemInfo>> getItemCatalog() async => _items.map(ItemInfo.fromJson).toList();

  @override
  Future<void> addItem(String userId, ItemInfo item, int cantidad) async {
    _bag[item.id] = (_bag[item.id] ?? 0) + cantidad;
  }
}
