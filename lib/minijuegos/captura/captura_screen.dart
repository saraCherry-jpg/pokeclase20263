/*
MINIJUEGO: CAPTURA (juego 3D)

Punto de entrada del minijuego "Captura": un prado en 3D donde se busca a
los Pokémon en la hierba alta y se les lanzan Poké Balls.

Esta pantalla hace de "raíz de composición" del minijuego: es el ÚNICO sitio
donde se crean los servicios y controladores concretos del juego 3D. El
resto del código del minijuego los recibe ya construidos con
context.read/watch (inyección de dependencias). Así no hace falta tocar
main.dart ni el MultiProvider de la app.

Todo lo que se crea aquí vive mientras la pantalla está abierta: al salir de
Captura, la bolsa y los Pokémon capturados se reinician.
 */

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'controllers/field_controller.dart';
import 'controllers/game_controller.dart';
import 'controllers/safari_controller.dart';
import 'controllers/trainer_controller.dart';
import 'game3d/render/scene_renderer.dart';
import 'services/image_bytes_service.dart';
import 'services/poke_api_service.dart';
import 'services/pokemon_repository.dart';
import 'services/random_pokemon_picker.dart';
import 'services/sound/sound_service.dart';
import 'views/game/stub_encounter_handler.dart';
import 'views/game3d/game3d_screen.dart';

/// Pantalla del minijuego Captura. Se abre desde la tarjeta "Captura" de
/// MinijuegoScreen.
///
/// Todos los parámetros son opcionales y solo sirven para los tests: allí
/// se pasan versiones falsas (sin red y sin GPU). Si no se pasa nada, se
/// usa la implementación real.
class CapturaScreen extends StatefulWidget {
  const CapturaScreen({
    super.key,
    this.repository,
    this.encounterHandler,
    this.sceneRenderer,
    this.soundService,
  });

  final PokemonRepository? repository;
  final EncounterHandler? encounterHandler;
  final SceneRenderer? sceneRenderer;
  final SoundService? soundService;

  @override
  State<CapturaScreen> createState() => _CapturaScreenState();
}

class _CapturaScreenState extends State<CapturaScreen> {
  /// Sonido compartido por todas las partidas. En la web abre un
  /// AudioContext del navegador que no se cierra nunca; si se creara uno
  /// por partida, se irían acumulando al entrar y salir. `static final` se
  /// crea la primera vez que se usa (perezoso) y luego se reutiliza.
  static final SoundService _sonidoDeLaApp = SoundService.create();

  /// Marca el subárbol del juego: su BuildContext está debajo del
  /// Navigator de la app, así que sirve para abrir diálogos desde código
  /// que no es un widget (el StubEncounterHandler).
  final GlobalKey _juegoKey = GlobalKey();

  late final http.Client _client;
  late final PokemonRepository _repository;
  late final RandomPokemonPicker _picker;
  late final EncounterHandler _encounterHandler;
  late final SceneRenderer _sceneRenderer;
  late final SoundService _sound;

  @override
  void initState() {
    super.initState();
    // Cadena de capas: cliente HTTP -> servicio -> caché (patrón decorador).
    _client = http.Client();
    // Para cada pieza: 1) la que se pase por parámetro; 2) si no, la que
    // haya arriba en el árbol con Provider (así un test que entra desde el
    // menú de minijuegos puede poner las falsas; en la app no hay ninguna);
    // 3) si no, la real. `read<T?>` devuelve null si no hay provider.
    _repository =
        widget.repository ??
        context.read<PokemonRepository?>() ??
        CachedPokemonRepository(service: PokeApiService(client: _client));
    _picker = RandomPokemonPicker(repository: _repository);

    // ↓↓↓ CONTRATO DE ENCUENTRO: reemplazar StubEncounterHandler por la
    // implementación real de la captura (Pokébola). Ver encounter_handler.dart.
    _encounterHandler =
        widget.encounterHandler ??
        StubEncounterHandler(contextOf: () => _juegoKey.currentContext);

    // Motor 3D. En los tests se pasa uno falso (allí no hay GPU).
    _sceneRenderer =
        widget.sceneRenderer ??
        context.read<SceneRenderer?>() ??
        FlutterSceneRenderer(
          loadImage: ImageBytesService(client: _client).fetch,
        );

    // Sonido del 3D (en la web, sintetizado; en el resto, silencio).
    _sound = widget.soundService ?? _sonidoDeLaApp;
  }

  @override
  void dispose() {
    // Se cierra el cliente HTTP: corta las descargas que sigan pendientes.
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // MultiProvider deja los servicios y controladores al alcance de
    // cualquier widget del juego que haya debajo.
    return MultiProvider(
      providers: [
        Provider<PokemonRepository>.value(value: _repository),
        Provider<RandomPokemonPicker>.value(value: _picker),
        Provider<EncounterHandler>.value(value: _encounterHandler),
        Provider<SceneRenderer>.value(value: _sceneRenderer),
        Provider<SoundService>.value(value: _sound),
        // Bolsa de Poké Balls y capturados (se reinician al salir).
        ChangeNotifierProvider(create: (_) => TrainerController()),
        // Encuentros (igual que en el 2D original), por partida: al salir
        // se cierran sus streams.
        ChangeNotifierProvider(
          create: (context) => GameController(
            picker: context.read<RandomPokemonPicker>(),
            encounterHandler: context.read<EncounterHandler>(),
          ),
        ),
        // La captura en el campo (bolsa y avisos).
        ChangeNotifierProvider(
          create: (context) => FieldController(
            trainer: context.read<TrainerController>(),
            picker: context.read<RandomPokemonPicker>(),
            repository: context.read<PokemonRepository>(),
          ),
        ),
        // El Reto Safari (opcional).
        ChangeNotifierProvider(create: (_) => SafariController()),
      ],
      child: KeyedSubtree(key: _juegoKey, child: const Game3DScreen()),
    );
  }
}
