import 'package:flame/input.dart';

enum EntryEdge { left, right, top, bottom }

class SpawnSlot {
  final EntryEdge edge;
  final Vector2 entry;
  final Vector2 stop;
  final bool airOnly;

  SpawnSlot({
    required this.edge,
    required this.entry,
    required this.stop,
    this.airOnly = false
  });

  bool occupied = false;
}

List<SpawnSlot> buildDefaultSlots() => [
  // Salen por la izquierda, detras de los arbustos
      SpawnSlot(edge: EntryEdge.left, entry: Vector2(-220, 520), stop: Vector2(260, 520)),
      SpawnSlot(edge: EntryEdge.left, entry: Vector2(-220, 560), stop: Vector2(480, 560)),
      // Salen por la derecha
      SpawnSlot(edge: EntryEdge.right, entry: Vector2(1500, 520), stop: Vector2(1020, 520)),
      SpawnSlot(edge: EntryEdge.right, entry: Vector2(1500, 560), stop: Vector2(800, 560)),
      // Suben desde abajo, detras de la hierba del frente
      SpawnSlot(edge: EntryEdge.bottom, entry: Vector2(640, 920), stop: Vector2(640, 540)),
      // Bajan desde arriba (voladores)
      SpawnSlot(edge: EntryEdge.top, entry: Vector2(400, -200), stop: Vector2(400, 170), airOnly: true),
      SpawnSlot(edge: EntryEdge.top, entry: Vector2(640, -200), stop: Vector2(640, 140), airOnly: true),
      SpawnSlot(edge: EntryEdge.top, entry: Vector2(880, -200), stop: Vector2(880, 200), airOnly: true),
];