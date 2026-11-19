import 'status_condition.dart';

// Qué hace un objeto, según la columna `Efecto` de la tabla `Item` (ej. "curar").
// Si viene vacía o con un texto desconocido, se deduce por el nombre (ver _fromName).
enum ItemEffect {
  curar,       // Valor = cuánta vida recupera (escala 0-100)
  curarEstado, // Valor = id del estado que quita (1-7, como la tabla Estados). 0 = todos
  revivir,     // Valor = % de la vida máxima con la que revive
  pokeball,    // No se usa en batallas (lo maneja el módulo de captura)
  ninguno;

  // Acepta "curar", "Curar", "curarEstado", "curar_estado", "Curar Estado"...
  static ItemEffect fromDb(dynamic value) {
    final text = value?.toString().toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '') ?? '';
    return values.firstWhere((e) => e.name.toLowerCase() == text, orElse: () => ninguno);
  }
}

// Un objeto del catálogo (GET /api/Item).
// Tabla `Item(Id, Nombre, Probabilidad, UrlImagen, Descripcion, Efecto, Valor)`.
class ItemInfo {
  final int id;
  final String nombre;
  final String urlImagen;
  final String descripcion;
  final double probabilidad; // Peso para el premio al ganar (la escala no importa)
  final ItemEffect efecto;
  final int valor;

  ItemInfo({
    required this.id,
    required this.nombre,
    this.urlImagen = '',
    this.descripcion = '',
    this.probabilidad = 0,
    required this.efecto,
    this.valor = 0,
  });

  // Los que tienen sentido usar a media batalla
  bool get usableInBattle =>
      efecto == ItemEffect.curar || efecto == ItemEffect.curarEstado || efecto == ItemEffect.revivir;

  // Estado que quita (null = todos). Solo aplica a ItemEffect.curarEstado
  StatusCondition? get curedStatus => valor == 0 ? null : StatusCondition.fromDb(valor);

  factory ItemInfo.fromJson(Map<String, dynamic> json) {
    final nombre = json['nombre']?.toString() ?? '';
    final parsed = ItemEffect.fromDb(json['efecto']);
    final fromDb = parsed == ItemEffect.ninguno ? null : parsed;
    final guess = _fromName(nombre);

    return ItemInfo(
      id: json['id'] ?? 0,
      nombre: nombre,
      urlImagen: json['urlImagen'] ?? '',
      descripcion: json['descripcion'] ?? '',
      probabilidad: (json['probabilidad'] as num?)?.toDouble() ?? 0,
      efecto: fromDb ?? guess.$1,
      valor: (json['valor'] as num?)?.toInt() ?? (fromDb == null ? guess.$2 : 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'urlImagen': urlImagen,
        'descripcion': descripcion,
        'probabilidad': probabilidad,
        'efecto': efecto.name,
        'valor': valor,
      };

  // Respaldo cuando `Efecto` viene vacío o no se reconoce: se identifica el objeto por su nombre
  static (ItemEffect, int) _fromName(String nombre) {
    final n = nombre
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll(RegExp(r'[\s\-_]'), '');
    const known = <String, (ItemEffect, int)>{
      'pocion': (ItemEffect.curar, 20),
      'superpocion': (ItemEffect.curar, 50),
      'hiperpocion': (ItemEffect.curar, 100),
      'pocionmaxima': (ItemEffect.curar, 100),
      'revivir': (ItemEffect.revivir, 50),
      'revivirmax': (ItemEffect.revivir, 100),
      'despertar': (ItemEffect.curarEstado, 2),
      'antiquemar': (ItemEffect.curarEstado, 3),
      'antidoto': (ItemEffect.curarEstado, 4),
      'antiparalizador': (ItemEffect.curarEstado, 5),
      'antihielo': (ItemEffect.curarEstado, 7),
      'curatotal': (ItemEffect.curarEstado, 0),
    };
    if (known.containsKey(n)) return known[n]!;
    if (n.contains('ball')) return (ItemEffect.pokeball, 0);
    return (ItemEffect.ninguno, 0);
  }
}

// Un objeto en la mochila del usuario. Tabla `ItemUser(Id, IdItem, IdUser, Cantidad)`
// con los datos del `Item` incluidos:
// { "id": 1, "idItem": 1, "idUser": "...", "cantidad": 3, "item": { "nombre": "Poción", ... } }
class BagItem {
  final int idItemUser;
  final ItemInfo item;
  int cantidad; // Baja al usarlo
  final bool local; // Premio guardado en el teléfono (ver services/local_bag.dart), no en Somee

  BagItem({required this.idItemUser, required this.item, required this.cantidad, this.local = false});

  factory BagItem.fromJson(Map<String, dynamic> json, {bool local = false}) {
    final itemJson = Map<String, dynamic>.from(json['item'] as Map? ?? {});
    itemJson['id'] ??= json['idItem'];
    return BagItem(
      idItemUser: json['id'] ?? 0,
      item: ItemInfo.fromJson(itemJson),
      cantidad: json['cantidad'] ?? 0,
      local: local,
    );
  }
}
