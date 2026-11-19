import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/status_condition.dart';
import '../theme/battle_theme.dart';
import '../utils/type_colors.dart';

// Piezas visuales que comparten Mis Pokémon y la pantalla de batalla.
// Cada una se dibuja en estilo GBA o Moderno según `gba`.

// Barra superior: alto 52 + borde inferior de 4 en primary
class BattleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool gba;
  final List<Widget> actions;

  const BattleAppBar({super.key, required this.title, required this.gba, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Material(
      color: BattleColors.ink,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: EdgeInsets.only(left: canPop ? 4 : 16, right: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: BattleColors.primary, width: 4)),
          ),
          child: Row(
            children: [
              if (canPop)
                IconButton(
                  tooltip: 'Atrás',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const CustomPaint(size: Size(18, 18), painter: _ChevronPainter()),
                ),
              Expanded(child: Text(title, style: BattleText(gba).appTitle(), overflow: TextOverflow.ellipsis)),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 10;
    final path = Path()
      ..moveTo(7 * s, 1 * s)
      ..lineTo(3 * s, 5 * s)
      ..lineTo(7 * s, 9 * s);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Botón principal. GBA: borde grueso con sombra dura que se hunde al presionar.
// Moderno: inclinado (skewX), con degradado opcional y se encoge al presionar.
class BattleButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool gba;
  final Color fill;
  final Color textColor;
  final double height;
  final TextStyle? style;
  final Gradient? gradient; // Solo Moderno
  final bool skew;          // Solo Moderno
  final BorderSide? border; // Solo Moderno (Huir)
  final double radius;
  final List<BoxShadow>? glow; // Solo Moderno

  const BattleButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.gba,
    required this.fill,
    required this.textColor,
    this.height = 60,
    this.style,
    this.gradient,
    this.skew = true,
    this.border,
    this.radius = 12,
    this.glow,
  });

  // Botón ancho de acción principal (¡A la batalla!, Volver a mis Pokémon, Reintentar)
  factory BattleButton.primary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    required bool gba,
    double height = 58,
    bool skew = false,
  }) =>
      BattleButton(
        key: key,
        label: label,
        onPressed: onPressed,
        gba: gba,
        fill: BattleColors.primary,
        textColor: Colors.white,
        height: height,
        style: BattleText(gba).wideButton(),
        gradient: gba ? null : modernGradient,
        skew: skew,
        radius: 14,
        glow: gba ? null : modernGlow,
      );

  static const modernGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [BattleColors.modLight, BattleColors.primary],
    stops: [0, .7],
  );
  static const modernGlow = [BoxShadow(color: Color(0x735345AB), blurRadius: 16, offset: Offset(0, 6))];

  @override
  State<BattleButton> createState() => _BattleButtonState();
}

class _BattleButtonState extends State<BattleButton> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.onPressed != null && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final enabled = w.onPressed != null;
    final text = Text(
      w.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: w.style ?? BattleText(w.gba).command(w.textColor),
    );

    Widget body;
    if (w.gba) {
      final isLight = w.fill.computeLuminance() > .4;
      body = Transform.translate(
        offset: Offset(0, _pressed ? 3 : 0),
        child: Container(
          height: w.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: w.fill,
            border: Border.all(color: BattleColors.shadow, width: 3),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: BattleColors.shadow, offset: Offset(0, _pressed ? 1 : 4))],
          ),
          child: Stack(
            children: [
              // Brillo superior de 3 px
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 3,
                child: ColoredBox(color: Colors.white.withValues(alpha: isLight ? .35 : .25)),
              ),
              Center(
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: text),
              ),
            ],
          ),
        ),
      );
    } else {
      const skew = -0.14; // ≈ 8°
      body = AnimatedScale(
        scale: _pressed ? .97 : 1,
        duration: const Duration(milliseconds: 90),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewX(w.skew ? skew : 0),
          child: Container(
            height: w.height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: w.gradient == null ? w.fill : null,
              gradient: w.gradient,
              borderRadius: BorderRadius.circular(w.radius),
              border: w.border == null ? null : Border.fromBorderSide(w.border!),
              boxShadow: w.glow,
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(w.skew ? -skew : 0),
              child: text,
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: w.onPressed,
        child: Opacity(opacity: enabled ? 1 : .4, child: body),
      ),
    );
  }
}

// Botón "Atrás": GBA transparente con borde mist; Moderno tarjeta oscura con borde tenue
class BattleBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool gba;
  final double height;
  final bool compact; // En la cabecera de las listas (ancho según el texto)

  const BattleBackButton({super.key, required this.onPressed, required this.gba, this.height = 48, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final t = BattleText(gba);
    return Material(
      color: gba ? Colors.transparent : BattleColors.modCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(gba ? 10 : 12),
        side: gba
            ? const BorderSide(color: BattleColors.mist, width: 3)
            : BorderSide(color: BattleColors.mist.withValues(alpha: .4), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        highlightColor: gba ? BattleColors.ghost : null,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: compact ? (gba ? 16 : 18) : 0),
          alignment: Alignment.center,
          child: Text('Atrás', style: compact ? t.smallBackButton() : t.backButton()),
        ),
      ),
    );
  }
}

// Barra de PS. Baja (o sube) en 700 ms.
class BattleHpBar extends StatelessWidget {
  final int current;
  final int max;
  final bool gba;
  final bool small; // En las tarjetas del equipo

  const BattleHpBar({super.key, required this.current, required this.max, required this.gba, this.small = false});

  @override
  Widget build(BuildContext context) {
    final target = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    final height = gba ? (small ? 8.0 : 10.0) : (small ? 6.0 : 7.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: const Duration(milliseconds: 700),
      curve: const Cubic(.3, .7, .4, 1),
      builder: (context, f, _) {
        final fill = Container(
          decoration: BoxDecoration(
            color: BattleColors.hp(f),
            borderRadius: gba ? null : BorderRadius.circular(4),
            border: gba ? const Border(bottom: BorderSide(color: Color(0x2E000000), width: 3)) : null,
          ),
        );
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: gba ? BattleColors.hpTrack : Colors.white.withValues(alpha: .16),
            border: gba ? Border.all(color: BattleColors.ink, width: 2) : null,
            borderRadius: BorderRadius.circular(gba ? (small ? 5 : 6) : 4),
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: f, heightFactor: 1, child: fill),
        );
      },
    );
  }
}

// Etiqueta "PS": en GBA es un recuadro accent; en Moderno solo texto accent
class PsLabel extends StatelessWidget {
  final bool gba;

  const PsLabel({super.key, required this.gba});

  @override
  Widget build(BuildContext context) {
    final text = Text('PS', style: BattleText(gba).psLabel().copyWith(height: 1));
    if (!gba) return text;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 2),
      decoration: BoxDecoration(color: BattleColors.accent, borderRadius: BorderRadius.circular(3)),
      child: text,
    );
  }
}

// Etiqueta del estado (Quemado, Dormido...). No dibuja nada si está Sano.
class BattleStatusChip extends StatelessWidget {
  final StatusCondition status;
  final bool gba;
  final bool small;

  const BattleStatusChip({super.key, required this.status, required this.gba, this.small = false});

  @override
  Widget build(BuildContext context) {
    if (status == StatusCondition.sano) return const SizedBox.shrink();
    final (bg, fg) = statusColors(status);
    final t = BattleText(gba);
    return Container(
      padding: gba
          ? EdgeInsets.symmetric(horizontal: small ? 4 : 5, vertical: small ? 2 : 3)
          : EdgeInsets.symmetric(horizontal: small ? 7 : 8, vertical: small ? 3 : 4),
      decoration: gba
          ? BoxDecoration(
              color: bg,
              border: Border.all(color: BattleColors.ink, width: 2),
              borderRadius: BorderRadius.circular(small ? 3 : 4),
            )
          : ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Text(
        status.dbName,
        style: (small ? t.smallStatusChip(fg) : t.statusChip(fg)).copyWith(height: 1),
      ),
    );
  }
}

// Etiqueta del tipo (PLANTA, AGUA...)
class TypeChip extends StatelessWidget {
  final String type;
  final bool gba;
  final bool onMove; // En los botones de movimiento: fondo oscuro translúcido

  const TypeChip({super.key, required this.type, required this.gba, this.onMove = false});

  @override
  Widget build(BuildContext context) {
    final bg = onMove ? BattleColors.shadow.withValues(alpha: .72) : colorForType(type);
    final fg = onMove ? Colors.white : textOnType(type);
    return Container(
      padding: onMove
          ? (gba ? const EdgeInsets.symmetric(horizontal: 5, vertical: 3) : const EdgeInsets.symmetric(horizontal: 7, vertical: 4))
          : EdgeInsets.symmetric(horizontal: gba ? 4 : 6, vertical: 3),
      decoration: gba
          ? BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3))
          : ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Text(
        typeChipLabel(type),
        style: BattleText(gba).typeChip(fg, size: onMove ? 10 : 9).copyWith(height: 1),
      ),
    );
  }
}

// Ícono de categoría de 24×16: físico (estrella), especial (círculos) o estado (círculo con línea)
class MoveCategoryIcon extends StatelessWidget {
  final String damageClass; // physical, special, status
  final bool gba;

  const MoveCategoryIcon({super.key, required this.damageClass, required this.gba});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(24, 16), painter: _CategoryPainter(damageClass, gba));
}

class _CategoryPainter extends CustomPainter {
  final String damageClass;
  final bool gba;

  _CategoryPainter(this.damageClass, this.gba);

  @override
  void paint(Canvas canvas, Size size) {
    final color = switch (damageClass) {
      'special' => BattleColors.special,
      'status' => BattleColors.statusMove,
      _ => BattleColors.physical,
    };
    final rect = gba
        ? RRect.fromRectAndRadius(const Rect.fromLTWH(.75, .75, 22.5, 14.5), const Radius.circular(3))
        : RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 24, 16), const Radius.circular(8));
    canvas.drawRRect(rect, Paint()..color = color);
    if (gba) {
      canvas.drawRRect(
        rect,
        Paint()
          ..color = BattleColors.shadow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    switch (damageClass) {
      case 'special':
        canvas.drawCircle(const Offset(12, 8), 4.6, white);
        canvas.drawCircle(const Offset(12, 8), 1.8, Paint()..color = Colors.white);
      case 'status':
        canvas.drawCircle(const Offset(12, 8), 4.4, white);
        canvas.drawLine(const Offset(7.6, 8), const Offset(16.4, 8), white);
      default:
        // Estrella de 8 puntas
        final star = Path();
        for (var i = 0; i < 16; i++) {
          final r = i.isEven ? 5.6 : 2.6;
          final a = -pi / 2 + i * pi / 8;
          final p = Offset(12 + r * cos(a), 8 + r * sin(a));
          i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
        }
        star.close();
        canvas.drawPath(star, Paint()..color = BattleColors.physicalStar);
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryPainter old) => old.damageClass != damageClass || old.gba != gba;
}

// Cuadro de texto de la batalla. GBA: doble marco (mist + primary). Moderno: tarjeta oscura.
// Con `showArrow` aparece la flechita ▼ que rebota (hay más mensajes: toca para avanzar).
class BattleMessageBox extends StatelessWidget {
  final String text;
  final bool gba;
  final bool showArrow;
  final bool loading; // Puntos suspensivos que parpadean
  final VoidCallback? onTap;

  const BattleMessageBox({
    super.key,
    required this.text,
    required this.gba,
    this.showArrow = false,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = BattleText(gba).textBox();
    final content = DefaultTextStyle.merge(
      style: style,
      child: loading
          ? Row(children: [Flexible(child: Text(text)), const _BlinkingDots()])
          : Text(text),
    );

    final Widget frame = gba
        ? Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: BattleColors.mist, borderRadius: BorderRadius.circular(12)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 84),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              decoration: BoxDecoration(
                color: BattleColors.textBox,
                border: Border.all(color: BattleColors.primary, width: 3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: content,
            ),
          )
        : Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            decoration: BoxDecoration(
              color: BattleColors.modCard,
              border: Border.all(color: BattleColors.mist.withValues(alpha: .28), width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: content,
          );

    final box = Stack(
      fit: StackFit.passthrough,
      children: [
        frame,
        if (showArrow)
          Positioned(
            right: gba ? 21 : 17.5,
            bottom: gba ? 17 : 13.5,
            child: _BouncingArrow(color: gba ? BattleColors.primary : BattleColors.accent),
          ),
      ],
    );

    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: box);
  }
}

class _BouncingArrow extends StatefulWidget {
  final Color color;

  const _BouncingArrow({required this.color});

  @override
  State<_BouncingArrow> createState() => _BouncingArrowState();
}

class _BouncingArrowState extends State<_BouncingArrow> with SingleTickerProviderStateMixin {
  // Rebote de 5 px en 2 pasos cada 520 ms
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(offset: Offset(0, _c.value < .5 ? 0 : 5), child: child),
      child: CustomPaint(size: const Size(16, 10), painter: _TrianglePainter(widget.color)),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}

class _BlinkingDots extends StatefulWidget {
  const _BlinkingDots();

  @override
  State<_BlinkingDots> createState() => _BlinkingDotsState();
}

class _BlinkingDotsState extends State<_BlinkingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: .15).animate(_c),
      child: Text('…', style: DefaultTextStyle.of(context).style),
    );
  }
}

// Sprite de Pokémon (pixel art: sin suavizado)
class PokemonSprite extends StatelessWidget {
  final String url;
  final double size;

  const PokemonSprite({super.key, required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.catching_pokemon, size: size / 2, color: BattleColors.muted),
      ),
    );
  }
}

// Ícono de un objeto (Poción, Antídoto...)
class ItemImage extends StatelessWidget {
  final String url;
  final double size;

  const ItemImage({super.key, required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) => Icon(Icons.medication, size: size * .7, color: BattleColors.subtle),
    );
  }
}

// Filtro gris para los Pokémon debilitados (grayscale + brillo .8)
const ColorFilter faintedFilter = ColorFilter.matrix([
  .17, .57, .06, 0, 0, //
  .17, .57, .06, 0, 0, //
  .17, .57, .06, 0, 0, //
  0, 0, 0, 1, 0,
]);

// Tarjeta tocable (movimientos, equipo, mochila). GBA se hunde 3 px al presionar;
// Moderno se encoge un poco. Sin `onTap` queda apagada con `disabledOpacity`.
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool gba;
  final double disabledOpacity;

  const PressableCard({super.key, required this.child, required this.onTap, required this.gba, this.disabledOpacity = 1});

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.onTap != null && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final child = widget.gba
        ? Transform.translate(offset: Offset(0, _pressed ? 2 : 0), child: widget.child)
        : AnimatedScale(scale: _pressed ? .97 : 1, duration: const Duration(milliseconds: 90), child: widget.child);
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: Opacity(opacity: enabled ? 1 : widget.disabledOpacity, child: child),
      ),
    );
  }
}

// Lee el estilo elegido. Si la app no registró BattleStyleProvider, usa GBA.
bool watchIsGba(BuildContext context) {
  try {
    return context.watch<BattleStyleProvider>().isGba;
  } on ProviderNotFoundException {
    return true;
  }
}
