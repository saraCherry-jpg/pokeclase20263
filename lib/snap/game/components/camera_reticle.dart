import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
import 'package:pokeclase20263/snap/game/config/game_config.dart';

class CameraReticle extends PositionComponent with DragCallbacks, HasVisibility{
  CameraReticle() : super(position: Vector2.zero(), size: GameConfig.resolution, priority: 10);

  final Vector2 center = GameConfig.resolution / 2;
  final Vector2 frameSize = Vector2(GameConfig.frameWidth, GameConfig.frameHeight);

  final Paint _dim = Paint()..color = const Color(0x66000000);

  final Paint _line = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  
  final Paint _thin = Paint()
    ..color = const Color(0x55FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  Rect get frameRect => Rect.fromCenter(
    center: Offset(center.x, center.y), 
    width: frameSize.x, 
    height: frameSize.y
  );

  @override
  void onDragUpdate(DragUpdateEvent event) {
    center.add(event.localDelta * GameConfig.reticleSensitivity);
    center.clamp(frameSize / 2, GameConfig.resolution - frameSize / 2);
  }

  @override
  void render(Canvas canvas){
    final frame = frameRect;

    //Oscurece todo lo que queda fuera del encuadre
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.x, size.y))
      ..addRect(frame);
    canvas.drawPath(outside, _dim);

    //regla de tercios
    final width = frame.width / 3;
    final height = frame.height / 3;
    for (var i = 1; i<=2; i++){
      canvas.drawLine(Offset(frame.left + width * i, frame.top), Offset(frame.left + width * i, frame.bottom), _thin);
      canvas.drawLine(Offset(frame.left, frame.top + height * i), Offset(frame.right, frame.top + height * i), _thin);
    }

    //Esquinas
    const  len = 32.0;
    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * len, y), _line);
      canvas.drawLine(Offset(x,y), Offset(x, y + dy * len), _line);
    }

    corner(frame.left, frame.top, 1, 1);
    corner(frame.right, frame.top, -1, 1);
    corner(frame.left, frame.bottom, 1, -1);
    corner(frame.right, frame.bottom, -1, -1);

    //Cruz central
    final center = frame.center;
    canvas.drawLine(Offset(center.dx - 12, center.dy), Offset(center.dx + 12, center.dy), _line);
    canvas.drawLine(Offset(center.dx, center.dy - 12), Offset(center.dx, center.dy + 12), _line);
  }

}