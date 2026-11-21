import 'dart:ui';

import 'package:flame/components.dart';
import 'package:pokeclase20263/snap/game/config/game_config.dart';
import 'package:pokeclase20263/snap/game/scene/spawn_slot.dart';

class DebugSlotsLayer extends PositionComponent{
  final List<SpawnSlot> slots;

  final Paint _line = Paint()
    ..color = const Color(0xCCFF00FF)
    ..strokeWidth = 2;

  final Paint _dot = Paint()..color = const Color(0xFFFF00FF);


  DebugSlotsLayer(this.slots) : super(priority: GameConfig.priorityDebug);

  @override
  void render(Canvas canvas) {
    for (final slot in slots) {
      canvas.drawLine(Offset(slot.entry.x, slot.entry.y), Offset(slot.stop.x, slot.stop.y), _line);
      canvas.drawCircle(Offset(slot.stop.x, slot.stop.y), 10, _dot);
    }
  }

}