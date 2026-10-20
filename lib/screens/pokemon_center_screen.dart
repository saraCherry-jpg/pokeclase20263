import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pokeclase20263/screens/chansey_screen.dart';
import 'package:pokeclase20263/screens/healing_machine_screen.dart';
import 'package:pokeclase20263/screens/pokemon_selection_screen.dart';
import 'package:pokeclase20263/widgets/menu_button.dart';
import 'package:pokeclase20263/widgets/responsive_panel.dart';

const _panelColor = Color(0xFF5345AB);

class PokemonCenterScreen extends StatefulWidget {
  const PokemonCenterScreen({super.key});

  @override
  State<PokemonCenterScreen> createState() => _PokemonCenterScreenState();
}

class _PokemonCenterScreenState extends State<PokemonCenterScreen> {
  static const _welcomeMessage = 'HOLA, BIENVENIDO AL CENTRO POKEMON';
  static const _destinationMessage = '¿A DONDE QUIERES IR?';

  Timer? _typingTimer;
  int _dialogueIndex = 0;
  int _visibleCharacters = 0;
  int _chanseyPresses = 0;
  bool _isChanseyPressed = false;

  String get _currentMessage =>
      _dialogueIndex == 0 ? _welcomeMessage : _destinationMessage;

  bool get _isTyping => _visibleCharacters < _currentMessage.length;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(const Duration(milliseconds: 55), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_visibleCharacters >= _currentMessage.length) {
        timer.cancel();
        return;
      }

      setState(() {
        _visibleCharacters++;
      });
    });
  }

  void _showNextDialogue() {
    if (_dialogueIndex != 0) {
      return;
    }

    setState(() {
      _dialogueIndex = 1;
      _visibleCharacters = 0;
    });
    _startTyping();
  }

  void _handleChanseyTap() {
    final opensChanseyScreen = _chanseyPresses == 7;

    setState(() {
      _chanseyPresses = opensChanseyScreen ? 0 : _chanseyPresses + 1;
    });

    if (opensChanseyScreen) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChanseyScreen()),
      );
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  Widget _destinationButton(String label, Widget screen) => ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: _panelColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    onPressed: () =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'NESFont', fontSize: 16),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      // appBar: AppBar(
      // title: Center(
      //    child: const Text('Centro Pokemon'),
      //    ),
      //  ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/poke_center/centerF1.jpeg',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: const MenuButton(),
            ),
          ),
          Positioned(
            left: screenWidth * -0.10,
            bottom: screenHeight * 0.374,
            width: screenWidth * 0.50,
            height: screenHeight * 0.50,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/poke_center/characters/nurse1.png',
                  fit: BoxFit.contain,
                ),
                if (_isTyping)
                  Image.asset(
                    'assets/images/poke_center/characters/nurse2.png',
                    fit: BoxFit.contain,
                  ),
              ],
            ),
          ),
          Positioned(
            left: screenWidth * 0.45,
            bottom: screenHeight * 0.302,
            width: screenWidth * 0.74,
            height: screenHeight * 0.50,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/poke_center/characters/chansey.png',
                  fit: BoxFit.contain,
                ),
                if (_isChanseyPressed)
                  Image.asset(
                    'assets/images/poke_center/characters/chansey2.png',
                    fit: BoxFit.contain,
                  ),
              ],
            ),
          ),
          Positioned(
            left: screenWidth * 0.45,
            bottom: screenHeight * 0.302,
            width: screenWidth * 0.74,
            height: screenHeight * 0.50,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleChanseyTap,
              onTapDown: (_) => setState(() => _isChanseyPressed = true),
              onTapUp: (_) => setState(() => _isChanseyPressed = false),
              onTapCancel: () => setState(() => _isChanseyPressed = false),
              child: Opacity(
                opacity: 0,
                child: Image.asset(
                  'assets/images/poke_center/characters/chansey.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: screenHeight * 0.10,
            child: ResponsivePanel(
              widthFactor: 1,
              height: (screenHeight * 0.30).clamp(180.0, 280.0),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        _currentMessage.substring(0, _visibleCharacters),
                        key: const Key('center-dialogue'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'NESFont',
                          fontSize: (screenWidth * 0.035).clamp(12.0, 20.0),
                        ),
                      ),
                    ),
                  ),
                  if (_dialogueIndex == 1) ...[
                    const SizedBox(height: 8),
                    Expanded(
                      child: _destinationButton(
                        'IR A LA MAQUINA DE CURACION',
                        const HealingMachineScreen(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _destinationButton(
                        'IR A LA MAQUINA DE INTERCAMBIO',
                        const PokemonSelectionScreen(),
                      ),
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: _showNextDialogue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _panelColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(40),
                      ),
                      child: const Text('>>'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
