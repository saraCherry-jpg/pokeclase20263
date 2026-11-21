import 'package:pokeclase20263/snap/game/components/pokemon_actor.dart';

class PhotoSubject {
  final PokemonActor actor;
  final double visibleFraction;
  final double centering;
  final double sizeFactor;
  final int score;

  const PhotoSubject({
    required this.actor,
    required this.visibleFraction,
    required this.centering,
    required this.sizeFactor,
    required this.score
  });
}

class PhotoResult {
  final List<PhotoSubject> subjects;
  final int bonus;

  const PhotoResult({
    required this.subjects,
    required this.bonus
  });

  bool get isEmpty => subjects.isEmpty;
  int get total => subjects.fold<int>(bonus, (sum, s) => sum + s.score);
}