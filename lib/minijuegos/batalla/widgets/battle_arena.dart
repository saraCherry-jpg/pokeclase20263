import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/battle_engine.dart';
import '../models/battle_pokemon.dart';
import '../models/status_condition.dart';
import '../theme/battle_theme.dart';
import '../utils/type_colors.dart';
import 'battle_ui.dart';

// Arena de la batalla: fondo, plataformas, sprites, cajas de info y animaciones.
// Escucha `BattleProvider.lastEvent` (cada mensaje del turno) y anima según su tipo:
// ataque, daño, crítico, fallo, estado, debilitado, entra, sale, objeto, huida...
// Las duraciones y movimientos vienen de la tabla "Animaciones por evento" del diseño.
class BattleArena extends StatefulWidget {
  final bool gba;
  final BattlePokemon? me;  // Nulo mientras carga o si hubo error
  final BattlePokemon? foe;
  final int meHp;
  final int foeHp;
  final StatusCondition meStatus;
  final StatusCondition foeStatus;
  final BattleEvent? event;
  final String? itemUrl; // Ícono del último objeto usado

  const BattleArena({
    super.key,
    required this.gba,
    required this.me,
    required this.foe,
    required this.meHp,
    required this.foeHp,
    required this.meStatus,
    required this.foeStatus,
    required this.event,
    this.itemUrl,
  });

  @override
  State<BattleArena> createState() => _BattleArenaState();
}

enum _Side { me, foe }

enum _Fx {
  none,
  ataque,
  dano,
  critico,
  superEficaz,
  pocoEficaz,
  fallo,
  estado,
  estadoCurado,
  sube,
  baja,
  curacion,
  debilitado,
  entra,
  sale,
  objeto,
  huida,
}

// Animaciones de un lado (mi Pokémon o el rival)
class _SideFx {
  final AnimationController sprite;
  final AnimationController box;
  final AnimationController chip;
  final AnimationController item;
  _Fx fx = _Fx.none;
  _Fx boxFx = _Fx.none;
  int delayMs = 0; // Espera antes de empezar (la entrada del rival y la mía van desfasadas)
  int durationMs = 1;
  int boxDelayMs = 0;
  int boxDurationMs = 1;

  _SideFx(TickerProvider vsync)
      : sprite = AnimationController(vsync: vsync, value: 1),
        box = AnimationController(vsync: vsync, value: 1),
        chip = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 340), value: 1),
        item = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 1000), value: 1);

  // Avance del efecto (0 a 1) descontando la espera inicial
  double spriteT() => _local(sprite.value, delayMs, durationMs);
  double boxT() => _local(box.value, boxDelayMs, boxDurationMs);

  static double _local(double v, int delay, int duration) {
    final total = delay + duration;
    return ((v * total - delay) / duration).clamp(0.0, 1.0);
  }

  void dispose() {
    sprite.dispose();
    box.dispose();
    chip.dispose();
    item.dispose();
  }
}

class _BattleArenaState extends State<BattleArena> with TickerProviderStateMixin {
  late final Map<_Side, _SideFx> _fx = {for (final s in _Side.values) s: _SideFx(this)};
  late final AnimationController _flash = AnimationController(vsync: this, value: 1);
  late final AnimationController _scene = AnimationController(vsync: this, value: 1);
  Color _flashColor = Colors.white;
  double _flashOpacity = 0;
  double _sceneAmp = 0;

  @override
  void initState() {
    super.initState();
    if (_ready(widget)) _intro();
  }

  bool _ready(BattleArena w) => w.me != null && w.foe != null;

  @override
  void didUpdateWidget(BattleArena old) {
    super.didUpdateWidget(old);
    if (_ready(widget) && !_ready(old)) {
      _intro(); // El primer mensaje ("¡Apareció...!") ya queda cubierto por la entrada
    } else if (widget.event != null && !identical(widget.event, old.event)) {
      _onEvent(widget.event!);
    }
  }

  @override
  void dispose() {
    for (final f in _fx.values) {
      f.dispose();
    }
    _flash.dispose();
    _scene.dispose();
    super.dispose();
  }

  // Al empezar: entra el rival y, un poco después, el mío
  void _intro() {
    _play(_Side.foe, _Fx.entra, delayMs: 80);
    _play(_Side.me, _Fx.entra, delayMs: 420);
  }

  void _onEvent(BattleEvent e) {
    if (e.kind == BattleEventKind.fled) {
      _play(_Side.me, _Fx.huida);
      return;
    }
    final target = e.targetIsPlayer;
    if (target == null) return;
    final side = target ? _Side.me : _Side.foe;
    final fx = switch (e.kind) {
      BattleEventKind.attack => _Fx.ataque,
      BattleEventKind.damage => _Fx.dano,
      BattleEventKind.critical => _Fx.critico,
      BattleEventKind.superEffective => _Fx.superEficaz,
      BattleEventKind.notEffective => _Fx.pocoEficaz,
      BattleEventKind.miss => _Fx.fallo,
      BattleEventKind.statusInflicted => _Fx.estado,
      BattleEventKind.statusCured => _Fx.estadoCurado,
      BattleEventKind.statUp => _Fx.sube,
      BattleEventKind.statDown => _Fx.baja,
      BattleEventKind.heal => _Fx.curacion,
      BattleEventKind.faint => _Fx.debilitado,
      BattleEventKind.switchIn => _Fx.entra,
      BattleEventKind.switchOut => _Fx.sale,
      BattleEventKind.item => _Fx.objeto,
      BattleEventKind.fled || BattleEventKind.message => _Fx.none,
    };
    if (fx != _Fx.none) _play(side, fx);
  }

  void _play(_Side side, _Fx fx, {int delayMs = 0}) {
    final f = _fx[side]!;

    void sprite(int ms) {
      f.fx = fx;
      f.delayMs = delayMs;
      f.durationMs = ms;
      f.sprite.duration = Duration(milliseconds: delayMs + ms);
      f.sprite.forward(from: 0);
    }

    void box(_Fx boxFx, int ms, {int delay = 0}) {
      f.boxFx = boxFx;
      f.boxDelayMs = delayMs + delay;
      f.boxDurationMs = ms;
      f.box.duration = Duration(milliseconds: delayMs + delay + ms);
      f.box.forward(from: 0);
    }

    switch (fx) {
      case _Fx.ataque:
        sprite(340);
      case _Fx.dano:
        sprite(480);
        box(_Fx.dano, 240);
      case _Fx.critico:
        sprite(480);
        _flashScene(Colors.white, .9, 260);
        _shakeScene(5, 280);
      case _Fx.superEficaz:
        sprite(640);
        box(_Fx.superEficaz, 300);
        _flashScene(BattleColors.accent, .4, 320);
      case _Fx.pocoEficaz:
        sprite(200);
      case _Fx.fallo:
        sprite(460);
      case _Fx.estado:
        sprite(900);
        f.chip.forward(from: 0);
      case _Fx.estadoCurado:
        sprite(700);
      case _Fx.sube || _Fx.baja || _Fx.curacion:
        sprite(900);
      case _Fx.debilitado:
        sprite(520);
        box(_Fx.debilitado, 360, delay: 320);
      case _Fx.entra:
        sprite(540);
        box(_Fx.entra, 380, delay: 140);
      case _Fx.sale:
        sprite(440);
        box(_Fx.sale, 320);
      case _Fx.objeto:
        f.item.forward(from: 0);
      case _Fx.huida:
        sprite(460);
        box(_Fx.huida, 380);
      case _Fx.none:
        break;
    }
  }

  void _flashScene(Color color, double opacity, int ms) {
    _flashColor = color;
    _flashOpacity = opacity;
    _flash.duration = Duration(milliseconds: ms);
    _flash.forward(from: 0);
  }

  void _shakeScene(double amp, int ms) {
    _sceneAmp = amp;
    _scene.duration = Duration(milliseconds: ms);
    _scene.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final gba = widget.gba;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final foeZone = Rect.fromLTWH(w - 4 - w * .54, h * .05, w * .54, h * .45);
      final meZone = Rect.fromLTWH(-6, h - h * .52, w * .58, h * .52);

      return ClipRect(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _BackgroundPainter(gba))),
            // Escena (se sacude con los críticos)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scene,
                builder: (context, child) => Transform.translate(
                  offset: Offset(_shake(_scene.value, _sceneAmp), 0),
                  child: child,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fromRect(rect: foeZone, child: _zone(_Side.foe, foeZone.size)),
                    Positioned.fromRect(rect: meZone, child: _zone(_Side.me, meZone.size)),
                    if (widget.foe != null) _infoBox(_Side.foe, w),
                    if (widget.me != null) _infoBox(_Side.me, w),
                  ],
                ),
              ),
            ),
            // Destello de los críticos y súper eficaces
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flash,
                  builder: (context, _) {
                    final o = _flash.isAnimating ? _flashOpacity * (1 - Curves.easeOut.transform(_flash.value)) : 0.0;
                    return o <= 0 ? const SizedBox.shrink() : ColoredBox(color: _flashColor.withValues(alpha: o));
                  },
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // Zona de un Pokémon: plataforma + sprite + ícono del objeto
  Widget _zone(_Side side, Size zone) {
    final gba = widget.gba;
    final me = side == _Side.me;
    final pokemon = me ? widget.me : widget.foe;
    final spriteSize = zone.height * (me ? .98 : .86);
    final f = _fx[side]!;

    final Rect platform = gba
        ? (me
            ? Rect.fromLTRB(zone.width * .02, zone.height * .79, zone.width * .98, zone.height * 1.09)
            : Rect.fromLTRB(zone.width * .03, zone.height * .74, zone.width * .97, zone.height * .99))
        : (me
            ? Rect.fromLTRB(-zone.width * .04, zone.height * .78, zone.width * 1.04, zone.height * 1.12)
            : Rect.fromLTRB(0, zone.height * .73, zone.width, zone.height));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(rect: platform, child: CustomPaint(painter: _PlatformPainter(gba))),
        if (pokemon != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: me ? 0 : zone.height * .11,
            height: spriteSize,
            child: OverflowBox(
              minWidth: 0,
              minHeight: 0,
              maxWidth: spriteSize,
              maxHeight: spriteSize,
              child: AnimatedBuilder(
                animation: f.sprite,
                builder: (context, _) => _animatedSprite(
                  side,
                  me ? pokemon.backSprite : pokemon.frontSprite,
                  spriteSize,
                ),
              ),
            ),
          ),
        if (pokemon != null && widget.itemUrl != null)
          Positioned(
            left: 0,
            right: 0,
            top: zone.height * (me ? .06 : -.04),
            child: Center(
              child: AnimatedBuilder(
                animation: f.item,
                builder: (context, child) {
                  if (!f.item.isAnimating) return const SizedBox(width: 48, height: 48);
                  final t = f.item.value;
                  final (o, y, s) = _itemPop(t);
                  return Opacity(
                    opacity: o,
                    child: Transform.translate(
                      offset: Offset(0, y),
                      child: Transform.scale(scale: s, child: child),
                    ),
                  );
                },
                child: ItemImage(url: widget.itemUrl!, size: 48),
              ),
            ),
          ),
      ],
    );
  }

  Widget _animatedSprite(_Side side, String url, double size) {
    final f = _fx[side]!;
    final me = side == _Side.me;
    final t = f.spriteT();
    final status = me ? widget.meStatus : widget.foeStatus;

    var dx = 0.0, dy = 0.0, opacity = 1.0, scale = 1.0, white = 0.0, sink = 0.0;
    Color? glowColor;
    var glow = 0.0;
    Color? stripeColor;
    var stripeDir = -1.0, stripes = 0.0;

    switch (f.fx) {
      case _Fx.ataque:
        final k = Curves.easeInOut.transform(t);
        final p = k < .4 ? k / .4 : (1 - k) / .6;
        dx = (me ? 30 : -30) * p;
        dy = (me ? -24 : 24) * p;
      case _Fx.dano:
        opacity = _blink(t, 3);
        dx = _shake((t * 480 / 320).clamp(0, 1), 6);
      case _Fx.critico:
        opacity = _blink(t, 3);
        dx = _shake((t * 480 / 360).clamp(0, 1), 8);
      case _Fx.superEficaz:
        opacity = _blink(t, 4);
        dx = _shake((t * 640 / 440).clamp(0, 1), 10);
      case _Fx.pocoEficaz:
        opacity = _blink((t * 200 / 180).clamp(0, 1), 1);
        dx = _shake(t, 2);
      case _Fx.fallo:
        final k = Curves.easeOut.transform(t);
        final p = k < .3 ? k / .3 : k < .65 ? 1.0 : (1 - k) / .35;
        dx = (me ? -24 : 24) * p;
        opacity = 1 - .55 * p;
      case _Fx.estado:
        glowColor = statusColors(status).$1;
        if (status == StatusCondition.sano) glowColor = const Color(0xFFE7C232);
        glow = _pulses(t, 3);
      case _Fx.estadoCurado:
        glowColor = Colors.white;
        glow = _pulses((t * 700 / 600).clamp(0, 1), 1);
        stripeColor = Colors.white;
        stripes = _stripeIntensity(t);
      case _Fx.sube:
        stripeColor = BattleColors.statUp;
        stripes = _stripeIntensity(t);
      case _Fx.baja:
        stripeColor = BattleColors.statDown;
        stripeDir = 1;
        stripes = _stripeIntensity(t);
      case _Fx.curacion:
        stripeColor = BattleColors.healing;
        stripes = _stripeIntensity(t);
        white = .35 * sin(pi * t);
      case _Fx.debilitado:
        sink = Curves.easeIn.transform(t);
      case _Fx.entra:
        // Silueta blanca que crece (0 → 1.08 → 1) y toma color
        scale = t < .55 ? 1.08 * Curves.easeOut.transform(t / .55) : 1.08 - .08 * ((t - .55) / .45);
        white = t < .55 ? 1 : 1 - (t - .55) / .45;
      case _Fx.sale:
        final k = Curves.easeIn.transform(t);
        white = (t / .3).clamp(0, 1);
        scale = t < .3 ? 1 : 1 - (k - Curves.easeIn.transform(.3)) / (1 - Curves.easeIn.transform(.3));
      case _Fx.huida:
        final k = Curves.easeIn.transform(t);
        dx = -1.3 * size * k;
        opacity = 1 - k;
      case _Fx.objeto || _Fx.none:
        break;
    }

    Widget sprite = PokemonSprite(url: url, size: size);

    if (stripeColor != null && stripes > 0) {
      final c = stripeColor.withValues(alpha: stripes);
      final offset = t * 56 * stripeDir;
      sprite = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [c, c, Colors.transparent, Colors.transparent],
          stops: const [0, .43, .43, 1],
          tileMode: TileMode.repeated,
        ).createShader(Rect.fromLTWH(0, offset, r.width, 14)),
        child: sprite,
      );
    }
    if (white > 0) {
      sprite = ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: white.clamp(0, 1)), BlendMode.srcATop),
        child: sprite,
      );
    }
    if (glowColor != null && glow > 0) {
      sprite = Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: glow.clamp(0, 1),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(glowColor, BlendMode.srcIn),
                child: PokemonSprite(url: url, size: size),
              ),
            ),
          ),
          sprite,
        ],
      );
    }
    if (sink > 0) {
      // Se hunde en la plataforma y se recorta a ras del suelo
      sprite = ClipRect(child: Transform.translate(offset: Offset(0, sink * size), child: sprite));
    }

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.scale(
        scale: scale.clamp(0, 2),
        alignment: me ? Alignment.bottomCenter : const Alignment(0, .8),
        child: Opacity(opacity: opacity.clamp(0, 1), child: sprite),
      ),
    );
  }

  // Caja con nombre, estado y PS
  Widget _infoBox(_Side side, double arenaWidth) {
    final gba = widget.gba;
    final me = side == _Side.me;
    final f = _fx[side]!;
    final pokemon = (me ? widget.me : widget.foe)!;
    final hp = me ? widget.meHp : widget.foeHp;
    final status = me ? widget.meStatus : widget.foeStatus;
    final t = BattleText(gba);
    final width = gba ? (me ? 212.0 : 208.0) : (me ? 228.0 : 224.0);
    final nameColor = gba ? BattleColors.ink : Colors.white;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 22),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  capitalize(pokemon.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.boxName(nameColor).copyWith(height: 1),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: f.chip,
                builder: (context, child) {
                  final v = f.chip.value;
                  final s = v < .6 ? 1.25 * Curves.easeOut.transform(v / .6) : 1.25 - .25 * Curves.elasticOut.transform((v - .6) / .4);
                  return Transform.scale(scale: f.chip.isAnimating ? s : 1, child: child);
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: BattleStatusChip(key: ValueKey(status), status: status, gba: gba),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gba ? 8 : 9),
        Row(
          children: [
            PsLabel(gba: gba),
            SizedBox(width: gba ? 6 : 8),
            Expanded(child: BattleHpBar(current: hp, max: pokemon.maxHp, gba: gba)),
          ],
        ),
        if (me)
          Padding(
            padding: EdgeInsets.only(top: gba ? 4 : 6),
            child: Text('$hp / ${pokemon.maxHp}', textAlign: TextAlign.right, style: t.hpNumbers()),
          ),
      ],
    );

    final Widget box;
    if (gba) {
      const r4 = Radius.circular(4), r16 = Radius.circular(16);
      box = Container(
        width: width,
        decoration: BoxDecoration(
          color: BattleColors.surface,
          border: Border.all(color: BattleColors.ink, width: 3),
          borderRadius: me
              ? const BorderRadius.only(topLeft: r16, topRight: r4, bottomRight: r16, bottomLeft: r4)
              : const BorderRadius.only(topLeft: r4, topRight: r16, bottomRight: r4, bottomLeft: r16),
          boxShadow: const [BoxShadow(color: Color(0x591E2240), offset: Offset(4, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Franja interior inferior de 4 px
            const Positioned(left: 0, right: 0, bottom: 0, height: 4, child: ColoredBox(color: BattleColors.mist)),
            Padding(padding: EdgeInsets.fromLTRB(12, 8, 12, me ? 8 : 12), child: content),
          ],
        ),
      );
    } else {
      box = ClipPath(
        clipper: _DiagonalClipper(cutRight: !me),
        child: Container(
          width: width,
          padding: me ? const EdgeInsets.fromLTRB(30, 9, 16, 10) : const EdgeInsets.fromLTRB(16, 9, 30, 11),
          decoration: BoxDecoration(
            color: BattleColors.modBox,
            borderRadius: me
                ? const BorderRadius.horizontal(left: Radius.circular(14))
                : const BorderRadius.horizontal(right: Radius.circular(14)),
          ),
          child: content,
        ),
      );
    }

    final animated = AnimatedBuilder(
      animation: f.box,
      builder: (context, child) {
        final bt = f.boxT();
        var dx = 0.0, opacity = 1.0;
        final out = me ? 1.3 * width : -1.3 * width; // Fuera de la pantalla por su lado
        switch (f.boxFx) {
          case _Fx.dano:
            dx = _shake(bt, 3);
          case _Fx.superEficaz:
            dx = _shake(bt, 4);
          case _Fx.debilitado:
            dx = (me ? 40 : -40) * bt;
            opacity = 1 - bt;
          case _Fx.entra:
            // Antes de que empiece la entrada la caja sigue afuera
            dx = out * (1 - const Cubic(.2, .9, .3, 1).transform(bt));
          case _Fx.sale:
            dx = out * Curves.easeIn.transform(bt);
          case _Fx.huida:
            dx = 1.3 * width * Curves.easeIn.transform(bt);
          default:
            break;
        }
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Opacity(opacity: opacity.clamp(0, 1), child: child),
        );
      },
      child: box,
    );

    if (gba) {
      return me
          ? Positioned(right: 12, bottom: 16, child: animated)
          : Positioned(left: 12, top: 14, child: animated);
    }
    return me ? Positioned(right: 0, bottom: 38, child: animated) : Positioned(left: 0, top: 16, child: animated);
  }

  // ---------------------------------------------------------------- Curvas

  // Temblor: 0, -a, a, -0.6a, 0.6a, 0 en tramos iguales
  static double _shake(double u, double a) {
    if (u <= 0 || u >= 1) return 0;
    const keys = [0.0, -1.0, 1.0, -.6, .6, 0.0];
    final x = u * 5;
    final i = x.floor().clamp(0, 4);
    final f = x - i;
    return a * (keys[i] + (keys[i + 1] - keys[i]) * f);
  }

  // Parpadeo en pasos: visible, invisible, visible... (n veces)
  static double _blink(double t, int n) {
    if (t <= 0 || t >= 1) return 1;
    final step = (t * (2 * n + 1)).floor();
    return step.isOdd ? 0 : 1;
  }

  // n pulsos de brillo (0 → 1 → 0)
  static double _pulses(double t, int n) => t <= 0 || t >= 1 ? 0 : sin(pi * (t * n % 1)).abs();

  // Franjas: aparecen (20 %), se quedan y se van (último 20 %)
  static double _stripeIntensity(double t) {
    if (t <= 0 || t >= 1) return 0;
    if (t < .2) return .9 * t / .2;
    if (t > .8) return .9 * (1 - t) / .2;
    return .9;
  }

  // Ícono del objeto: aparece, rebota, sube y se desvanece
  static (double, double, double) _itemPop(double t) {
    double lerp(double a, double b, double f) => a + (b - a) * f;
    if (t < .25) return (t / .25, lerp(10, -8, t / .25), lerp(.6, 1.15, t / .25));
    if (t < .45) return (1, lerp(-8, 0, (t - .25) / .2), lerp(1.15, 1, (t - .25) / .2));
    if (t < .75) return (1, lerp(0, -4, (t - .45) / .3), 1);
    return (1 - (t - .75) / .25, lerp(-4, -20, (t - .75) / .25), 1);
  }
}

// Recorta el lado interior de la caja en diagonal (16 px), estilo Moderno
class _DiagonalClipper extends CustomClipper<Path> {
  final bool cutRight;

  _DiagonalClipper({required this.cutRight});

  @override
  Path getClip(Size size) => cutRight
      ? (Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width - 16, size.height)
        ..lineTo(0, size.height)
        ..close())
      : (Path()
        ..moveTo(16, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close());

  @override
  bool shouldReclip(covariant _DiagonalClipper old) => old.cutRight != cutRight;
}

// Cielo y pasto
class _BackgroundPainter extends CustomPainter {
  final bool gba;

  _BackgroundPainter(this.gba);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (gba) {
      // Bandas duras
      const bands = [
        (0.0, .18, Color(0xFFC3C8E4)),
        (.18, .32, Color(0xFFCFD3EA)),
        (.32, .44, Color(0xFFDCDFF0)),
        (.44, .52, Color(0xFFE8EAF5)),
        (.52, .64, Color(0xFFB4DC96)),
        (.64, .78, Color(0xFFA3D385)),
        (.78, 1.0, Color(0xFF93C877)),
      ];
      for (final (from, to, color) in bands) {
        canvas.drawRect(Rect.fromLTRB(0, h * from, w, h * to + 1), Paint()..color = color);
      }
      // Líneas verticales suaves en el pasto
      final grass = Paint()..color = Colors.white.withValues(alpha: .07);
      for (var x = 0.0; x < w; x += 12) {
        canvas.drawRect(Rect.fromLTWH(x, h * .52, 4, h * .48), grass);
      }
    } else {
      final sky = Rect.fromLTWH(0, 0, w, h * .47);
      canvas.drawRect(
        sky,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9FB4EA), Color(0xFFD9E1FA)],
          ).createShader(sky),
      );
      final grass = Rect.fromLTRB(0, h * .47, w, h);
      canvas.drawRect(
        grass,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBFE3A6), Color(0xFF86C46E)],
          ).createShader(grass),
      );
      // Halo blanco en el horizonte
      final halo = Rect.fromLTRB(-w * .2, h * .38, w * 1.2, h * .60);
      canvas.save();
      canvas.translate(halo.center.dx, halo.center.dy);
      canvas.scale(1, halo.height / halo.width);
      final r = halo.width / 2;
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withValues(alpha: .75), Colors.white.withValues(alpha: 0)],
            stops: const [0, .65],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) => old.gba != gba;
}

// Plataforma ovalada bajo cada Pokémon
class _PlatformPainter extends CustomPainter {
  final bool gba;

  _PlatformPainter(this.gba);

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Offset.zero & size;
    if (gba) {
      final path = Path()..addOval(oval);
      canvas.save();
      canvas.clipPath(path);
      canvas.drawOval(oval, Paint()..color = const Color(0xFF9DCC80)); // Banda inferior
      canvas.drawOval(oval.translate(0, -8), Paint()..color = const Color(0xFFBCE19E));
      canvas.restore();
      canvas.drawOval(
        oval.deflate(2),
        Paint()
          ..color = const Color(0xFF6CA455)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    } else {
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(1, size.height / size.width);
      final r = size.width / 2;
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -.2),
            colors: const [Color(0xFFE3F5D6), Color(0xFFE3F5D6), Color(0xFFA8D990), Color(0xFFA8D990), Color(0x008CC873)],
            stops: const [0, .38, .39, .66, .70],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PlatformPainter old) => old.gba != gba;
}
