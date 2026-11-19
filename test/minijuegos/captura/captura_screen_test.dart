// PRUEBAS DE PANTALLA (widget tests) del minijuego Captura: que la opción
// "Captura" del menú de minijuegos abre el juego 3D, y que el HUD del 3D
// funciona (bolsa, fichas de captura, "Mis capturas", Reto Safari, lanzar,
// carteles, bayas, mapa, ayuda y sonido). Adaptadas de las pruebas del 3D
// del repo original: en vez de montar aquella app, se monta CapturaScreen
// con un repositorio falso y un motor 3D falso (en los tests no hay GPU).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokeclase20263/minijuegos/captura/captura_screen.dart';
import 'package:pokeclase20263/minijuegos/captura/game3d/render/scene_renderer.dart';
import 'package:pokeclase20263/minijuegos/captura/services/pokemon_repository.dart';
import 'package:pokeclase20263/minijuegos/captura/services/sound/sound_service.dart';
import 'package:pokeclase20263/minijuegos/captura/views/game3d/game3d_screen.dart';
import 'package:pokeclase20263/minijuegos/captura/views/game3d/widgets/field_hud.dart';
import 'package:pokeclase20263/screens/minijuego_screen.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math.dart';

import 'package:pokeclase20263/minijuegos/captura/game3d/sim/world3d_sim.dart';
import 'package:pokeclase20263/minijuegos/captura/game3d/sim/wild_pokemon.dart';
import 'package:pokeclase20263/minijuegos/captura/models/capture_result.dart';
import 'package:pokeclase20263/minijuegos/captura/models/poke_ball.dart';
import 'package:pokeclase20263/minijuegos/captura/views/pokedex/widgets/pokemon_card.dart';

import 'fakes/fake_pokemon_repository.dart';
import 'fakes/fake_scene_renderer.dart';

void main() {
  late FakePokemonRepository repository;

  setUp(() => repository = FakePokemonRepository(speciesCount: 40));

  /// Abre el minijuego con los falsos y deja que arranque el mundo 3D.
  Future<void> openCaptura(
    WidgetTester tester, {
    FakeSceneRenderer? renderer,
    SoundService? sound,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CapturaScreen(
          repository: repository,
          sceneRenderer: renderer ?? FakeSceneRenderer(),
          soundService: sound ?? SilentSoundService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('the "Captura" card of the minigames menu opens CapturaScreen', (
    tester,
  ) async {
    // Los falsos van arriba con Provider: MinijuegoScreen crea
    // `const CapturaScreen()` sin parámetros y CapturaScreen los recoge.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<PokemonRepository>.value(value: repository),
          Provider<SceneRenderer>.value(value: FakeSceneRenderer()),
        ],
        child: const MaterialApp(home: MinijuegoScreen()),
      ),
    );

    expect(
      find.text('Explora la hierba alta en 3D y atrápalos'),
      findsOneWidget,
    );
    await tester.tap(find.text('Captura'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CapturaScreen), findsOneWidget);
    expect(find.byType(Game3DScreen), findsOneWidget);
    expect(find.byKey(const Key('fake_scene')), findsOneWidget);
  });

  testWidgets('CapturaScreen shows the 3D world', (tester) async {
    await openCaptura(tester);

    expect(find.widgetWithText(AppBar, 'Captura'), findsOneWidget);
    expect(find.byType(Game3DScreen), findsOneWidget);
    expect(find.byKey(const Key('fake_scene')), findsOneWidget);
    expect(find.byKey(const Key('game3d_dpad')), findsOneWidget);
    expect(find.byKey(const Key('game3d_minimap')), findsOneWidget);
  });

  testWidgets('3D HUD: picking up balls fills the bag and shows a notice', (
    tester,
  ) async {
    final renderer = FakeSceneRenderer();
    await openCaptura(tester, renderer: renderer);

    expect(
      find.descendant(
        of: find.byKey(const Key('bag_poke')),
        matching: find.text('×5'),
      ),
      findsOneWidget,
    );
    renderer.lastSim!.onEvent!(const BallsPickedUp(PokeBallType.ultra, 1));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('bag_ultra')),
        matching: find.text('×1'),
      ),
      findsOneWidget,
    );
    expect(find.text('+1 Ultra Ball'), findsOneWidget);

    // El aviso se va solo.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text('+1 Ultra Ball'), findsNothing);
  });

  testWidgets('3D: a capture shows its card; "Mis capturas" lists it', (
    tester,
  ) async {
    final renderer = FakeSceneRenderer();
    await openCaptura(tester, renderer: renderer);

    final sim = renderer.lastSim!;
    final wild = WildPokemon(
      id: 'w',
      pokemon: fakePokemon(25),
      position: Vector3.zero(),
    );
    const result = CaptureResult(chance: 0.5, shakes: 3, caught: true);
    sim.onEvent!(PokemonCaught(wild, PokeBallType.great, result));
    await tester.pump();
    expect(find.byKey(const Key('capture_card')), findsOneWidget);
    expect(find.text('Poke 25'), findsOneWidget);
    expect(find.text('#025'), findsOneWidget);
    expect(find.text('¡Capturado!'), findsOneWidget);
    expect(find.byKey(const Key('capture_card_new')), findsOneWidget);

    // La misma especie otra vez (y crítica): ya no es nueva.
    const critical = CaptureResult(
      chance: 0.5,
      shakes: 1,
      caught: true,
      critical: true,
    );
    sim.onEvent!(PokemonCaught(wild, PokeBallType.poke, critical));
    await tester.pump();
    expect(find.byKey(const Key('capture_card')), findsNWidgets(2));
    expect(find.byKey(const Key('capture_card_new')), findsOneWidget);
    expect(find.text('¡Captura crítica!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.byKey(const Key('capture_card')), findsNothing);

    // Tocar "Capturados" abre el panel y congela el mundo.
    await tester.tap(find.byKey(const Key('bag_captured')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('captures_panel')), findsOneWidget);
    expect(find.text('Mis capturas (2)'), findsOneWidget);
    expect(find.byType(PokemonCard), findsNWidgets(2));
    expect(sim.isPaused, isTrue);

    await tester.tap(find.byKey(const Key('captures_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('captures_panel')), findsNothing);
    expect(sim.isPaused, isFalse);
  });

  testWidgets('3D: a shiny capture shows "Variocolor" on its card and in the '
      'panel', (tester) async {
    final renderer = FakeSceneRenderer();
    await openCaptura(tester, renderer: renderer);
    final sim = renderer.lastSim!;
    final wild = WildPokemon(
      id: 'w',
      pokemon: fakePokemon(25),
      position: Vector3.zero(),
      shiny: true,
    );
    sim.onEvent!(ShinySpotted(wild));
    await tester.pump();
    expect(find.textContaining('VARIOCOLOR'), findsOneWidget);

    const result = CaptureResult(chance: 0.5, shakes: 3, caught: true);
    sim.onEvent!(PokemonCaught(wild, PokeBallType.poke, result));
    await tester.pump();
    expect(find.byKey(const Key('capture_card_shiny')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    await tester.tap(find.byKey(const Key('bag_captured')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('captured_shiny')), findsOneWidget);
    await tester.tap(find.byKey(const Key('captures_close')));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('3D: "Mis capturas" with nothing caught explains how', (
    tester,
  ) async {
    await openCaptura(tester);

    await tester.tap(find.byKey(const Key('bag_captured')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mis capturas (0)'), findsOneWidget);
    expect(find.textContaining('Aún no has capturado'), findsOneWidget);
  });

  testWidgets('3D: Reto Safari: start, own balls and clock, abandon, summary', (
    tester,
  ) async {
    final renderer = FakeSceneRenderer();
    await openCaptura(tester, renderer: renderer);
    final sim = renderer.lastSim!;
    Finder inside(String key, String text) =>
        find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

    // Las reglas, con el mundo congelado; "¡Empezar!".
    await tester.tap(find.byKey(const Key('safari_start')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('safari_intro')), findsOneWidget);
    expect(sim.isPaused, isTrue);
    await tester.tap(find.byKey(const Key('safari_go')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(sim.isPaused, isFalse);
    expect(sim.safariActive, isTrue);
    expect(sim.fieldItems.items, isEmpty);
    expect(find.byKey(const Key('safari_hud')), findsOneWidget);
    expect(find.byKey(const Key('bag_poke')), findsNothing);
    expect(find.text('10:00'), findsOneWidget);
    expect(inside('safari_balls', '×25'), findsOneWidget);

    // Se lanza una bola DEL RETO (la bolsa no se toca).
    await tester.tap(find.byKey(const Key('game3d_throw')));
    await tester.pump();
    expect(sim.throwProgress, isNotNull);
    expect(inside('safari_balls', '×24'), findsOneWidget);
    // Pasan 30 s (la simulación no avanza sola en los tests).
    sim.update(30);
    await tester.pump();
    expect(find.text('9:30'), findsOneWidget);

    // Esa bola captura (rareza 255 = 100 puntos, por la espalda ×2).
    sim.onEvent!(
      PokemonCaught(
        WildPokemon(
          id: 's',
          pokemon: fakePokemon(8),
          position: Vector3.zero(),
          captureRate: 255,
        ),
        PokeBallType.poke,
        const CaptureResult(chance: 1, shakes: 3, caught: true),
        hit: (unaware: true, fromBehind: true, eating: false, asleep: false),
      ),
    );
    await tester.pump();
    expect(inside('safari_hud', 'Capturas: 1 · 200 pts'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));

    // Abandonar: resumen y vuelta al modo libre, con la bolsa intacta.
    await tester.tap(find.byKey(const Key('safari_abandon')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('safari_summary')), findsOneWidget);
    expect(find.text('Reto abandonado'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('safari_score'))).data,
      '200',
    );
    expect(find.text('100 ×2'), findsOneWidget);
    expect(sim.safariActive, isFalse);
    await tester.tap(find.byKey(const Key('safari_close')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('safari_hud')), findsNothing);
    expect(inside('bag_poke', '×5'), findsOneWidget);
    expect(find.byKey(const Key('safari_start')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('3D: the throw button spends a ball; an empty bag warns', (
    tester,
  ) async {
    final renderer = FakeSceneRenderer();
    await openCaptura(tester, renderer: renderer);

    final sim = renderer.lastSim!;
    await tester.tap(find.byKey(const Key('game3d_throw')));
    await tester.pump();
    expect(sim.throwProgress, isNotNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('bag_poke')),
        matching: find.text('×4'),
      ),
      findsOneWidget,
    );

    // Gastar el resto (la simulación no avanza sola: se hace a mano).
    for (var i = 0; i < 4; i++) {
      sim.update(World3DSim.throwDuration + 0.01);
      await tester.tap(find.byKey(const Key('game3d_throw')));
      await tester.pump();
    }
    sim.update(World3DSim.throwDuration + 0.01);
    await tester.tap(find.byKey(const Key('game3d_throw')));
    await tester.pump();
    expect(find.textContaining('No te quedan'), findsOneWidget);
    expect(sim.readyBall, isNull);

    // Botón de apuntar: se queda activo.
    await tester.tap(find.byKey(const Key('game3d_aim')));
    await tester.pump();
    expect(sim.aiming, isTrue);

    // Botón de agacharse (sigilo).
    await tester.tap(find.byKey(const Key('game3d_crouch')));
    await tester.pump();
    expect(sim.crouching, isTrue);

    // Botón de cámara: vuelve detrás del jugador.
    sim.camera.yaw = 1;
    await tester.tap(find.byKey(const Key('game3d_recenter')));
    await tester.pump();
    expect(sim.camera.recenterGoal, isNotNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('3D: a sign in front can be read (tap or L) and closes', (
    tester,
  ) async {
    final renderer = FakeSceneRenderer();
    await openCaptura(tester, renderer: renderer);
    expect(find.byKey(const Key('sign_prompt')), findsNothing);

    // Delante del cartel del pueblo (7,7), mirando hacia él (al sur).
    final sim = renderer.lastSim!;
    sim.player
      ..teleport(sim.cellCenter(7, 6))
      ..facing = 0;
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign_prompt')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign_prompt')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign_panel')), findsOneWidget);
    expect(find.text('Pueblo Paleta'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign_panel')), findsNothing);
    expect(find.byKey(const Key('sign_prompt')), findsOneWidget);

    // Abierto otra vez: alejarse lo cierra.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign_panel')), findsOneWidget);
    sim.player.teleport(sim.cellCenter(7, 3));
    sim.update(1 / 60);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign_panel')), findsNothing);
    expect(find.byKey(const Key('sign_prompt')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('3D: shake a bush (L), berries fill the bag and can be thrown', (
    tester,
  ) async {
    final renderer = FakeSceneRenderer();
    await openCaptura(tester, renderer: renderer);
    expect(find.byKey(const Key('bush_prompt')), findsNothing);
    Finder berriesInBag(String text) => find.descendant(
      of: find.byKey(const Key('bag_berry')),
      matching: find.text(text),
    );
    expect(berriesInBag('×0'), findsOneWidget);

    // Debajo del arbusto del pueblo (2,10), mirándolo (al norte).
    final sim = renderer.lastSim!;
    sim.player
      ..teleport(sim.cellCenter(2, 11))
      ..facing = 3.14159;
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('bush_prompt')), findsOneWidget);
    expect(find.text('Sacudir el arbusto'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    for (var i = 0; i < 90; i++) {
      sim.update(1 / 60);
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(berriesInBag('×3'), findsOneWidget);
    expect(find.text('+3 Bayas Frambu'), findsOneWidget);
    expect(find.text('sin bayas'), findsOneWidget);

    // Sacudirlo vacío avisa (tocando el aviso, como en una pantalla táctil).
    await tester.tap(find.byKey(const Key('bush_prompt')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('no tiene bayas'), findsOneWidget);

    // Con la baya en la mano (tecla 4), el botón de lanzar la lanza.
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('game3d_throw')),
        matching: find.byType(BerryIcon),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('game3d_throw')));
    await tester.pump();
    sim.update(World3DSim.releaseTime + 0.01);
    expect(sim.berries.loose.where((b) => b.thrown), hasLength(1));
    expect(berriesInBag('×2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('3D: M (or tapping the minimap) opens the map and freezes the '
      'world', (tester) async {
    final renderer = FakeSceneRenderer();
    await openCaptura(tester, renderer: renderer);
    final sim = renderer.lastSim!;

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('big_map')), findsOneWidget);
    expect(find.text('Arbustos con bayas'), findsOneWidget);
    expect(sim.isPaused, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('big_map')), findsNothing);
    expect(sim.isPaused, isFalse);

    await tester.tap(find.byKey(const Key('game3d_minimap')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('big_map')), findsOneWidget);
    await tester.tap(find.byKey(const Key('big_map_close')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('big_map')), findsNothing);
    expect(sim.isPaused, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('3D: the controls help folds itself away; H and tapping '
      'toggle it', (tester) async {
    await openCaptura(tester);
    final help = find.byKey(const Key('game3d_help'));
    final tab = find.byKey(const Key('game3d_help_tab'));
    expect(help, findsOneWidget);
    expect(tab, findsNothing);

    // Al rato se pliega sola.
    await tester.pump(const Duration(seconds: 21));
    await tester.pump(const Duration(milliseconds: 300));
    expect(help, findsNothing);
    expect(tab, findsOneWidget);

    await tester.tap(tab);
    await tester.pump(const Duration(milliseconds: 300));
    expect(help, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump(const Duration(milliseconds: 300));
    expect(help, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump(const Duration(milliseconds: 300));
    expect(help, findsOneWidget);
    await tester.tap(find.byKey(const Key('game3d_help_close')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tab, findsOneWidget);
  });

  testWidgets('3D: the speaker button (or N) mutes and unmutes', (
    tester,
  ) async {
    final sound = SilentSoundService();
    await openCaptura(tester, sound: sound);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);

    await tester.tap(find.byKey(const Key('game3d_sound')));
    await tester.pump();
    expect(sound.muted, isTrue);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pump();
    expect(sound.muted, isFalse);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
  });

  testWidgets('3D: once you toggle the help, it no longer folds by '
      'itself', (tester) async {
    await openCaptura(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump(const Duration(seconds: 25));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('game3d_help')), findsOneWidget);
  });

  testWidgets('3D: aiming at a species you have (or not) paints fine', (
    tester,
  ) async {
    final renderer = FakeSceneRenderer();
    await openCaptura(tester, renderer: renderer);

    final sim = renderer.lastSim!;
    // Uno ya capturado y otro nuevo, delante del jugador.
    const caught = CaptureResult(chance: 0.5, shakes: 3, caught: true);
    sim.onEvent!(
      PokemonCaught(
        WildPokemon(id: 'c', pokemon: fakePokemon(4), position: Vector3.zero()),
        PokeBallType.poke,
        caught,
      ),
    );
    final ahead = sim.player.position + sim.camera.forward * 6;
    for (final (id, species, side) in [('a', 4, -1.0), ('b', 7, 1.0)]) {
      sim.wild.add(
        WildPokemon(
          id: id,
          pokemon: fakePokemon(species),
          position: ahead + sim.camera.right * side,
        ),
      );
    }
    sim
      ..aiming = true
      ..update(0.5);
    expect(sim.lockedTarget, isNotNull);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
  });
}
