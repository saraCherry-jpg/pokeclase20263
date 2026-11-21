import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pokeclase20263/snap/game/components/pokemon_actor.dart';
import 'package:pokeclase20263/snap/game/config/game_config.dart';
import 'package:pokeclase20263/snap/game/photo/photo_result.dart';

class PhotoEvaluator {
  PhotoEvaluator._();

  static PhotoResult evaluate({required Rect frame, required Iterable<PokemonActor> actors}) {
    final subjects = <PhotoSubject>[];

    for(final actor in actors){
      final rect = actor.hitRect;
      if (!frame.overlaps(rect)) continue;

      final inter = frame.intersect(rect);
      final area = rect.width * rect.height;
      if (area <= 0) continue;

      final visible = (inter.width * inter.height) / area;
      if (visible < GameConfig.minVisibleFraction) continue;

      final halfDiag = frame.size.longestSide / 2;
      final dist = (rect.center - frame.center).distance;
      final centering = (1 - dist / halfDiag).clamp(0.0, 1.0).toDouble();

      final ratio = rect.height / frame.height;
      final sizeFactor = min(1.0, ratio / 0.7);

      final score = (100 * (0.45 * centering + 0.35 * sizeFactor + 0.20 * visible)).round();

      subjects.add(PhotoSubject(
        actor: actor,
        visibleFraction: visible,
        centering: centering,
        sizeFactor: sizeFactor,
        score: score,
      ));
    }

    final bonus = subjects.length >= 2 ? 25 * (subjects.length - 1) : 0;
    return PhotoResult(subjects: subjects, bonus: bonus);
  }
}