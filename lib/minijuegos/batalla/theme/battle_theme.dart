import 'package:flutter/material.dart';

import '../logic/type_chart.dart';
import '../models/status_condition.dart';
import '../utils/type_colors.dart';

// Diseño del módulo de batallas.
// Hay dos estilos con el mismo flujo, textos y botones:
//   1a GBA     -> estilo Rubí/Esmeralda: bandas de color, bordes gruesos, fuente pixel
//   1b Moderno -> estilo Espada/Escudo: cajas oscuras, botones inclinados
enum BattleStyle { gba, moderno }

// Estilo elegido. Se registra arriba de la app (main.dart) y se cambia desde Mis Pokémon.
class BattleStyleProvider extends ChangeNotifier {
  BattleStyle style;

  BattleStyleProvider({this.style = BattleStyle.gba});

  bool get isGba => style == BattleStyle.gba;

  void toggle() {
    style = isGba ? BattleStyle.moderno : BattleStyle.gba;
    notifyListeners();
  }
}

class BattleColors {
  // Paleta del proyecto (la misma de la pokeclase)
  static const primary = Color(0xFF5345AB);
  static const accent = Color(0xFFE5D36D);
  static const mist = Color(0xFFB8BDD5);
  static const ink = Color(0xFF1E2240);
  // Derivados
  static const shadow = Color(0xFF0B0D22);
  static const surface = Color(0xFFF6F6FA);
  static const textBox = Color(0xFFFBFBFD);
  static const hpTrack = Color(0xFF3A3F66);
  static const ghost = Color(0xFF2B3060); // Botón Huir en GBA
  static const disabled = Color(0xFF4A4F78);
  static const inBattle = Color(0xFFFFF6C2); // Fondo de la tarjeta "en combate" en GBA
  static const subtle = Color(0xFF4B5078);
  static const muted = Color(0xFF6B7093);
  static const modPanel = Color(0xFF14172E);
  static const modCard = Color(0xFF252A52);
  static const modCardHi = Color(0xFF31376A);
  static const modBox = Color(0xE614172E); // 90 %
  static const modLight = Color(0xFF6E5FD6); // Inicio del degradado de Luchar
  // Barra de PS
  static const hpHigh = Color(0xFF4CC26B);
  static const hpMid = Color(0xFFF0A030);
  static const hpLow = Color(0xFFE04848);

  static Color hp(double fraction) => fraction > .5 ? hpHigh : fraction > .2 ? hpMid : hpLow;

  // Ícono de categoría del movimiento
  static const physical = Color(0xFFE8603C);
  static const physicalStar = Color(0xFFFFE07A);
  static const special = Color(0xFF5B7BE0);
  static const statusMove = Color(0xFF9A9AB4);

  // Franjas de las animaciones
  static const statUp = Color(0xFFF0604A);
  static const statDown = Color(0xFF5B7BE0);
  static const healing = Color(0xFF5FD37A);
}

// Fondo y texto de la etiqueta de cada estado
(Color, Color) statusColors(StatusCondition status) => switch (status) {
      StatusCondition.dormido => (const Color(0xFF8A8FA8), Colors.white),
      StatusCondition.quemado => (const Color(0xFFE2653A), Colors.white),
      StatusCondition.envenenado => (const Color(0xFF9B4DB0), Colors.white),
      StatusCondition.paralizado => (const Color(0xFFE7C232), BattleColors.ink),
      StatusCondition.confundido => (const Color(0xFFD9578F), Colors.white),
      StatusCondition.congelado => (const Color(0xFF7CCDE6), BattleColors.ink),
      StatusCondition.sano => (Colors.transparent, BattleColors.ink),
    };

// Texto blanco solo en los tipos oscuros; el resto lleva texto ink
const _darkTypes = {'fighting', 'poison', 'ghost', 'dragon', 'dark'};

Color textOnType(String type) => _darkTypes.contains(normalizeType(type)) ? Colors.white : BattleColors.ink;

String typeChipLabel(String type) => typeLabel(type).toUpperCase();

// Oscurece un color (para el degradado de los movimientos en Moderno)
Color shade(Color c, double k) => Color.fromARGB(
      (c.a * 255).round(),
      (c.r * 255 * k).round(),
      (c.g * 255 * k).round(),
      (c.b * 255 * k).round(),
    );

// Tipografía. Las fuentes van incluidas en assets/fonts (no se descargan al abrir la app).
//   GBA: Pixelify Sans (y VT323 para números) · Moderno: Chakra Petch
class BattleText {
  static const pixel = 'PixelifySans';
  static const digits = 'VT323';
  static const chakra = 'ChakraPetch';

  final bool gba;
  const BattleText(this.gba);

  TextStyle _s(double size, FontWeight weight, {bool italic = false, Color? color, double? height}) =>
      TextStyle(
        fontFamily: gba ? pixel : chakra,
        fontSize: size,
        fontWeight: weight,
        fontStyle: italic && !gba ? FontStyle.italic : FontStyle.normal,
        color: color,
        height: height,
      );

  TextStyle _digits(double size, {Color? color}) =>
      TextStyle(fontFamily: digits, fontSize: size, fontWeight: FontWeight.w400, color: color, height: 1);

  TextStyle appTitle() => gba
      ? _s(20, FontWeight.w700, color: Colors.white)
      : _s(21, FontWeight.w700, italic: true, color: Colors.white);
  TextStyle endTitle(Color color) =>
      gba ? _s(32, FontWeight.w700, color: color) : _s(34, FontWeight.w700, italic: true, color: color);
  TextStyle endSub() => gba
      ? _s(19, FontWeight.w500, color: BattleColors.ink, height: 1.3)
      : _s(17, FontWeight.w500, color: const Color(0xFFE4E6F2), height: 1.35);
  TextStyle command(Color color, {bool big = false}) => gba
      ? _s(22, FontWeight.w700, color: color)
      : _s(big ? 25 : 18, FontWeight.w700, italic: true, color: color);
  TextStyle wideButton() => gba
      ? _s(21, FontWeight.w700, color: Colors.white)
      : _s(20, FontWeight.w700, italic: true, color: Colors.white);
  TextStyle backButton() => gba
      ? _s(19, FontWeight.w700, color: Colors.white)
      : _s(18, FontWeight.w700, italic: true, color: Colors.white);
  TextStyle smallBackButton() => gba
      ? _s(17, FontWeight.w700, color: Colors.white)
      : _s(16, FontWeight.w700, italic: true, color: Colors.white);
  TextStyle textBox() => gba
      ? _s(21, FontWeight.w500, color: BattleColors.ink, height: 1.35)
      : _s(19, FontWeight.w600, color: Colors.white, height: 1.35);
  TextStyle moveName(Color color) =>
      gba ? _s(18, FontWeight.w700, color: color, height: 1.1) : _s(18, FontWeight.w700, italic: true, color: color, height: 1.1);
  TextStyle moveInfo(Color color) => gba ? _digits(19, color: color) : _s(14, FontWeight.w600, color: color);
  TextStyle boxName(Color color) =>
      gba ? _s(18, FontWeight.w700, color: color) : _s(18, FontWeight.w700, italic: true, color: color);
  TextStyle hpNumbers() =>
      gba ? _digits(22, color: BattleColors.ink) : _s(15, FontWeight.w600, color: BattleColors.mist);
  TextStyle psLabel() => gba
      ? _s(11, FontWeight.w700, color: BattleColors.ink)
      : _s(11, FontWeight.w700, color: BattleColors.accent);
  TextStyle statusChip(Color color) => gba ? _s(12, FontWeight.w600, color: color) : _s(11, FontWeight.w700, color: color);
  TextStyle smallStatusChip(Color color) =>
      gba ? _s(11, FontWeight.w600, color: color) : _s(10, FontWeight.w700, color: color);
  TextStyle typeChip(Color color, {double size = 10}) => _s(size, FontWeight.w700, color: color)
      .copyWith(letterSpacing: gba ? .6 : .8);
  TextStyle listTitle(Color color) =>
      gba ? _s(18, FontWeight.w700, color: color, height: 1.25) : _s(18, FontWeight.w700, italic: true, color: color, height: 1.25);
  TextStyle cardName(Color color) =>
      gba ? _s(16, FontWeight.w700, color: color, height: 1.1) : _s(16, FontWeight.w700, italic: true, color: color, height: 1.1);
  TextStyle inBattle() => gba
      ? _s(12, FontWeight.w600, color: BattleColors.primary)
      : _s(12, FontWeight.w600, color: BattleColors.accent);
  TextStyle cardHp() => gba ? _digits(17, color: BattleColors.ink) : _s(13, FontWeight.w600, color: BattleColors.mist);
  TextStyle itemName() => gba
      ? _s(17, FontWeight.w700, color: BattleColors.ink, height: 1.1)
      : _s(16, FontWeight.w700, color: Colors.white, height: 1.1);
  TextStyle itemDesc() => gba
      ? _s(13, FontWeight.w400, color: BattleColors.subtle, height: 1.2)
      : _s(13, FontWeight.w500, color: BattleColors.mist, height: 1.25);
  TextStyle itemQty() => gba ? _digits(26, color: BattleColors.ink) : _s(19, FontWeight.w700, color: BattleColors.accent);
  TextStyle reward() => gba
      ? _s(18, FontWeight.w700, color: BattleColors.ink)
      : _s(17, FontWeight.w700, color: BattleColors.ink);
  TextStyle body(Color color, {double size = 15}) => _s(size, FontWeight.w500, color: color, height: 1.3);
  TextStyle counter() => gba
      ? _digits(24, color: BattleColors.accent)
      : _s(16, FontWeight.w700, color: BattleColors.accent);
  TextStyle sectionTitle() => gba
      ? _s(18, FontWeight.w700, color: Colors.white)
      : _s(19, FontWeight.w700, italic: true, color: Colors.white);
  TextStyle rosterName(Color color) =>
      gba ? _s(15, FontWeight.w700, color: color, height: 1.1) : _s(15, FontWeight.w700, italic: true, color: color, height: 1.1);
  TextStyle slotNumber() => gba ? _digits(22, color: BattleColors.muted) : _s(13, FontWeight.w700, color: BattleColors.muted);
  TextStyle order(Color color) => gba ? _digits(18, color: color) : _s(12, FontWeight.w700, color: color);
}
