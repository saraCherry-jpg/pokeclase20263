import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui' hide TextStyle;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show HSVColor, TextStyle;
import 'package:http/http.dart' as http;

import 'package:pokeclase20263/snap/game/config/game_config.dart';
import 'package:pokeclase20263/snap/game/data/snap_pokemon.dart';
import 'package:pokeclase20263/snap/game/scene/spawn_slot.dart';

enum ActorPhase { entering, staying, leaving}

class PokemonActor extends PositionComponent with HasGameReference<FlameGame>{
  final SnapPokemon pkmn;
  final SpawnSlot slot;
  final Random _random;

  PokemonActor({
    required this.pkmn,
    required this.slot,
    Random? random
  }): _random = random ?? Random(),
    super(anchor: Anchor.center, priority: GameConfig.priorityPokemon);

  ActorPhase phase = ActorPhase.entering;
  bool photographed = false;

  Sprite? _sprite;
  double _stayDuration = 5;
  double _phaseTime = 0;
  double _idleTime = 0;
  Vector2 _leaveFrom = Vector2.zero();

  static final Map<int, Future<ui.Image>> _imageCache = {};
  static final Set<int> _reportedImageFailures = {};
  static final http.Client _httpClient =  http.Client();

  //Imagen oficial (fondo transparente del repo de sprite de PokeAPI)
  String get _imageUrl => 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${pkmn.id}.png';

  late final Paint _placeholderPaint = Paint()
    ..color = HSVColor.fromAHSV(0.9, ((pkmn.id * 47) % 360).toDouble(), 0.55, 0.95).toColor();

  late final TextPaint _label = TextPaint(
    style: const TextStyle(
      color: Color(0xFF000000),
      fontSize: 22,
      fontWeight: FontWeight.bold,
    )
  );

  //Rectangulo del Pokemon en coordenadas del mundo
  Rect get hitRect => Rect.fromCenter(
    center: Offset(position.x, position.y),
    width: size.x,
    height: size.y
  );

  //Descarga la imagen desde internet (o la toma del cache si ya se bajo)
  Future<ui.Image> _loadNetworkImage() async {
    final imageFuture = _imageCache.putIfAbsent(pkmn.id, _downloadNetworkImage);
    try {
      return await imageFuture;
    } catch (_) {
      if (identical(_imageCache[pkmn.id], imageFuture)) {
        _imageCache.remove(pkmn.id);
      }
      rethrow;
    }
  }

  Future<ui.Image> _downloadNetworkImage() async {
    final response = await _httpClient.get(Uri.parse(_imageUrl)).timeout(const Duration(seconds: 20));

    if(response.statusCode != 200){
      throw Exception('Error ${response.statusCode} al bajar ${pkmn.name}');
    }

    final Uint8List bytes =  response.bodyBytes;

    //El coded lee los bytes y prepara el decodificador
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    try{
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }

  }

  @override
  FutureOr<void> onLoad() async {
    final height = pkmn.displayHeight;
    size = Vector2(height, height);
    position = slot.entry.clone();
    _stayDuration = GameConfig.stayMin + _random.nextDouble() * (GameConfig.stayMax - GameConfig.stayMin);
    unawaited(_loadSprite(height));




    
  }

  Future<void> _loadSprite(double height) async {
    try{
      final image = await _loadNetworkImage();
      if(isRemoved) return;
      _sprite = Sprite(image);
      size = Vector2(height * image.width / image.height, height);
    } catch (error, stackTrace) {
      if(_reportedImageFailures.add(pkmn.id)){
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'Pokemon snap',
            context: ErrorDescription('Al descarga la imagen de ${pkmn.name}; se muestra el placeholder')
          )
        );
      }
    }
  }

  //Lamado al tomar foto
  void reactToFlash(){
    photographed = true;
    if(phase != ActorPhase.leaving) _setPhase(ActorPhase.leaving);
  }

  void _setPhase(ActorPhase next){
    phase = next;
    _phaseTime = 0;
    if (next == ActorPhase.leaving) _leaveFrom = position.clone();
  }

  void _moveBetween(Vector2 pointA, Vector2 pointB, double time){
    position.setValues(pointA.x + (pointB.x - pointA.x) * time, pointA.y + (pointB.y - pointA.y) * time);
  }

  @override
  void update(double dt){
    super.update(dt);
    _phaseTime += dt;
    _idleTime += dt;

    switch(phase){
      case ActorPhase.entering:
        final time = min(1.0, _phaseTime / GameConfig.enterDuration);
        _moveBetween(slot.entry, slot.stop, Curves.easeOutCubic.transform(time));
        if (time >= 1) _setPhase(ActorPhase.staying);
      case ActorPhase.staying:
        final amp = pkmn.isFlying ? 10.0 : 4.0;
        position.setValues(slot.stop.x, slot.stop.y + sin(_idleTime * 3) * amp) ;
        if(_phaseTime >= _stayDuration) _setPhase(ActorPhase.leaving);
      case ActorPhase.leaving:
        final time = min(1.0, _phaseTime / GameConfig.leaveDuration);
        _moveBetween(_leaveFrom, slot.entry, Curves.easeInCubic.transform(time));
        if (time >= 1)  removeFromParent();
    }
  }

  @override
  void render(Canvas canvas){
    final sprite = _sprite;
    if(sprite != null){
      sprite.render(canvas, size: size);
      return;
    }
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2), 
      min(size.x, size.y) / 2, 
      _placeholderPaint
    );
    _label.render(canvas, pkmn.name, Vector2(size.x / 2, size.y / 2), anchor: Anchor.center);
  }

  @override
  void onRemove() {
    slot.occupied = false;
    super.onRemove();
  }
}