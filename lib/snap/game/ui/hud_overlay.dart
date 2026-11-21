import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pokeclase20263/snap/game/gallery/gallery_view.dart';
import 'package:pokeclase20263/snap/game/photo/photo_result.dart';
import 'package:pokeclase20263/snap/game/snap_game.dart';

class HudOverlay extends StatelessWidget {
  final SnapGame game;
  final VoidCallback onExit;


  const HudOverlay({super.key, required this.game, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton.filledTonal(
                onPressed: onExit,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ValueListenableBuilder<int>(
                valueListenable: game.totalScore,
                builder: (_, score, __) => _Chip('Puntos: $score'),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: ValueListenableBuilder<int>(
                valueListenable: game.photosLeft,
                builder: (_, left, __) => _Chip('Fotos: $left'),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                children: [
                  ValueListenableBuilder<Uint8List?>(
                    valueListenable: game.lastScreenshot,
                    builder: (_, bytes, __) {
                      if (bytes == null) return const SizedBox.shrink();
                      return  GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => GalleryView())
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              bytes,
                              width: 96,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    }
                  ),
                  ValueListenableBuilder<PhotoResult?>(
                    valueListenable: game.lastPhoto,
                    builder: (_, photo, __) => _LastPhotoInfo(photo),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: _ShutterButton(onPressed: game.takePhoto),
            ),
            if (kDebugMode) 
              Align(
                alignment: Alignment.centerRight,
                child: IconButton.filled(
                  tooltip: 'Debug: spawn',
                  onPressed: game.debugSpawn,
                  icon: const Icon(Icons.bug_report),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip(this.text);  

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _LastPhotoInfo extends StatelessWidget {
  final PhotoResult? photo;

  const _LastPhotoInfo(this.photo);

  @override
  Widget build(BuildContext context) {
    final p = photo;
    final String text;

    if (p == null) {
      text = 'Arrastra para apuntar y tocar el boton para tomar la foto';
    } else if (p.isEmpty) {
      text = 'Sin Pokemon en el encuadre (+0)';
    } else {
      final names = p.subjects.map((s) => s.actor.pkmn.name).join(', ');
      text = '$names +${p.total}';
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: _Chip(text),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ShutterButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.red, width: 8),
        ),
        child: const Icon(Icons.camera_alt, size: 36, color: Colors.black87,),
      ),
    );
  }
}