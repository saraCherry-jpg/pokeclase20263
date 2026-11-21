import 'dart:async';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pokeclase20263/snap/game/components/camera_reticle.dart';
import 'package:pokeclase20263/snap/game/components/photo_flash.dart';
import 'package:pokeclase20263/snap/game/components/pokemon_actor.dart';
import 'package:pokeclase20263/snap/game/components/pokemon_spawner.dart';
import 'package:pokeclase20263/snap/game/config/game_config.dart';
import 'package:pokeclase20263/snap/game/data/snap_pokemon.dart';
import 'package:pokeclase20263/snap/game/data/snap_pokemon_catalog.dart';
import 'package:pokeclase20263/snap/game/debug/debug_slots_layer.dart';
import 'package:pokeclase20263/snap/game/gallery/gallery_repository.dart';
import 'package:pokeclase20263/snap/game/photo/photo_cropper.dart';
import 'package:pokeclase20263/snap/game/photo/photo_evaluator.dart';
import 'package:pokeclase20263/snap/game/photo/photo_result.dart';
import 'package:pokeclase20263/snap/game/scene/placeholder_scenery.dart';
import 'package:pokeclase20263/snap/game/scene/scenery_layer.dart';
import 'package:pokeclase20263/snap/game/scene/spawn_slot.dart';
import 'package:screenshot/screenshot.dart';

class SnapGame extends FlameGame {
  SnapGame() : super(
    camera: CameraComponent.withFixedResolution(
      width: GameConfig.width,
      height: GameConfig.height
    ),
  );

  final ValueNotifier<bool> hudVisible = ValueNotifier(true);
  final ValueNotifier<bool> resultsVisible = ValueNotifier(false);

  final ValueNotifier<int> photosLeft = ValueNotifier(GameConfig.photoPerSession);
  final ValueNotifier<int> totalScore = ValueNotifier(0);
  final ValueNotifier<PhotoResult?> lastPhoto = ValueNotifier(null);

  //Todas las fotos de la sesión
  final List<PhotoResult> album = [];

  final List<SpawnSlot> slots = buildDefaultSlots();

  CameraReticle? _reticle;
  PokemonSpawner? _spawner;

  //Para el screenshot
  final ScreenshotController screenshotController = ScreenshotController();
  //Key pública para la screenshot
  final GlobalKey screenshotKey = GlobalKey();
  //Ultima captura en base 64
  final ValueNotifier<Uint8List?> lastScreenshot = ValueNotifier(null);
  //La galeria de imagenes
  final ValueNotifier<List<Uint8List>> galleryImages = ValueNotifier([]);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;

    world.addAll([
      SceneryLayer(
        assetPath: 'scenery/background.png',
        placeholder: paintPlaceholderBackground,
        priority: GameConfig.priorityBackground
      ),
      SceneryLayer(
        assetPath: 'scenery/midground.png',
        placeholder: paintPlaceholderMidground,
        priority: GameConfig.priorityMidground
      ),
      SceneryLayer(
        assetPath: 'scenery/foreground.png',
        placeholder: paintPlaceholderForeground,
        priority: GameConfig.priorityForeground
      )
    ]);

    if (GameConfig.debugDraw) world.add(DebugSlotsLayer(slots));
    
    final pokemonPool = await SnapPokemon.loadCatalog();
    final spawner = PokemonSpawner(
      world: world,
      pool: pokemonPool,
      slots: slots
    );

    _spawner = spawner;
    add(spawner);
    unawaited(_refreshPokemonPool(spawner, pokemonPool));

    final reticle = CameraReticle();
    _reticle = reticle;
    camera.viewport.add(reticle);
  }

  Future<void> _refreshPokemonPool(PokemonSpawner spawner, List<SnapPokemon> localPool) async {
    try {
      final localById = {for (final pokemon in localPool) pokemon.id: pokemon};
      final remotePool = await SnapPokemonCatalog.fetchFromApi();
      if (!identical(_spawner, spawner)) return;

      spawner.updatePool([
        for (final pokemon in remotePool)
          if (localById[pokemon.id] case final local?)
            SnapPokemon(
              id: pokemon.id,
              name: pokemon.name,
              displayHeight: local.displayHeight,
              isFlying: pokemon.isFlying,
              spawnWeight: local.spawnWeight
            )
          else 
            pokemon,
      ]);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Pokemon Snap',
          context: ErrorDescription(
            'Al actualizar el catalogo desde pokeAPI, se conserva e local'
          )
        )
      );
    }
  }

  //Toma una foto con el encuadre actual, devuelve null si no se pudo
  PhotoResult? takePhoto() {
    final reticle = _reticle;
    if (reticle == null || photosLeft.value <= 0 || paused) return null;

    photosLeft.value -= 1;

    //Congelar camara
    final frameAtShot = reticle.frameRect;

    final result = PhotoEvaluator.evaluate(
      frame: frameAtShot,
      actors: world.children.whereType<PokemonActor>(),
    );

    album.add(result);
    totalScore.value += result.total;
    lastPhoto.value = result;

    //Ocultar visor para que el proximo frame se pinte sin el
    reticle.isVisible = false;

    //Capturamos el siguiente frame (sin flash)
    //Si era la ultima foto, se muestra el overlay
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _captureImage(frameAtShot);
      } finally {
        reticle.isVisible = true;
      }

      camera.viewport.add(PhotoFlash());
      for (final subject in result.subjects) {
        subject.actor.reactToFlash();
      }
      if (photosLeft.value == 0) finishSession();
    });

    return result;
  }

  Future<void> _captureImage(Rect frameRect) async {
    const pixelRatio =  2.0;
    try{
      final bytes = await screenshotController.capture(
        pixelRatio: pixelRatio,
      );

      if (bytes == null || bytes.isEmpty){
        debugPrint('CaptureImage: bytes vacios');
        return;
      }

      final cropped = await PhotoCropper.cropToFrame(
        fullBytes: bytes,
        frameRect: frameRect,
        gameSize: GameConfig.resolution,
        pixelRatio: pixelRatio
      );

      if (cropped == null || cropped.isEmpty) {
        debugPrint('captureImage: recorte vacio');
        return;
      }

      await GalleryRepository.instance.add(cropped);
      lastScreenshot.value = cropped;
      debugPrint('Screenshot OK (${cropped.length} bytes)');
    } catch (error) {
      debugPrint('Error inesperado capturando screenshot: $error');
    }
  }

  void finishSession(){
    resultsVisible.value = true;
    pauseEngine();
  }

  void debugSpawn() => _spawner?.SpawnNow();

}