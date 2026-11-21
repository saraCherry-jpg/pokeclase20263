import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokeclase20263/snap/game/snap_game.dart';
import 'package:pokeclase20263/snap/game/ui/hud_overlay.dart';
import 'package:pokeclase20263/snap/game/ui/results_overlay.dart';
import 'package:screenshot/screenshot.dart';

class SnapScreen extends StatefulWidget {
  const SnapScreen({super.key});

  @override
  State<SnapScreen> createState() => _SnapScreenState();
}

class _SnapScreenState extends State<SnapScreen> {
  late SnapGame _game;

  @override
  void initState() {
    super.initState();
    _game = SnapGame();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _exit() => Navigator.of(context).pop();
  void _restart() => setState(() => _game = SnapGame());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Screenshot(
              controller: _game.screenshotController,
              child: GameWidget<SnapGame>(
                game: _game,
                key: ObjectKey(_game),
              ),
            ),
          ),
          //HUD
          Positioned.fill(
            child: ValueListenableBuilder(
              valueListenable: _game.hudVisible,
              builder: (_, visible, ___) => visible ? HudOverlay(
                game: _game,
                onExit: _exit,
              ) : const SizedBox.shrink()
            ),
          ),
          //Resultados
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: _game.resultsVisible,
              builder: (_, visible, ___) =>  visible ? ResultsOverlay(
                game: _game,
                onRestart: _restart,
                onExit: _exit,
              ) : const SizedBox.shrink()
            )
          )
        ],
      ),
    );
  }
}