import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:pokeclase20263/snap/game/config/game_config.dart';

typedef PlaceholderPainer = void Function(Canvas canvas, Vector2 size);

class SceneryLayer extends PositionComponent with HasGameReference<FlameGame> {
  final String assetPath;
  final PlaceholderPainer placeholder;
  Sprite? _sprite;
  Picture? _placeholderPicture;

  SceneryLayer({
    required this.assetPath, 
    required this.placeholder,
    required int priority,
  }) : super(
    position: Vector2.zero(),
    size: GameConfig.resolution,
    priority: priority
  );

  @override
  FutureOr<void> onLoad() async{
    try{
      final image = await game.images.load(assetPath);
      _sprite = Sprite(image);
    } catch (_) {
      //si no hay imagen todavía
      final recorder = PictureRecorder();
      placeholder(Canvas(recorder), size);
      _placeholderPicture =  recorder.endRecording();
    }
  }

  @override
  void render(Canvas canvas){
    final sprite = _sprite;
    if (sprite != null) {
      sprite.render(canvas, size: size);
      return;
    }
    final picture = _placeholderPicture;
    if (picture != null) canvas.drawPicture(picture);
  }

  @override
  void onRemove() {
    _placeholderPicture?.dispose();
    super.onRemove();
  }
}