import 'package:flame/game.dart';

class GameConfig {
  //Estado
  GameConfig._();

  //Resolucion, Flame escala a la pantalla real
  static const double width = 1280;
  static const double height = 720;
  static Vector2 get resolution => Vector2(width, height);

  //Orden de dibujo, Z
  static const int priorityBackground = 0;
  static const int priorityMidground = 5;
  static const int priorityPokemon = 10;
  static const int priorityForeground = 20; //Arbustos
  static const int priorityDebug = 90;

  //Sesion
  static const int photoPerSession = 12;

  //Spawner
  static const int maxPokemonOnScreen = 3;
  static const double firstSpawnDelay = 1.0;
  static const double spawnIntervalMin = 2.0;
  static const double spawnIntervalMax = 5.0;

  //Pokemon
  static const double enterDuration = 1.6;
  static const double leaveDuration = 1.2;
  static const double stayMin = 4.0;
  static const double stayMax = 8.0;

  //Visor
  static const double frameWidth = 420;
  static const double frameHeight = 280;
  static const double reticleSensitivity =  1.4;

  //Foto
  //Fraccion minima del pokemon que debe estar dentro del encuadre para contar
  static const double minVisibleFraction = 0.6;

  //Dibuja los puntos de aparicion en pantalla
  static const bool debugDraw = false;

}