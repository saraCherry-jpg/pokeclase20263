import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/battle_item.dart';
import '../../models/battle_move.dart';
import '../../models/battle_pokemon.dart';
import '../../models/status_condition.dart';
import '../../providers/battle_provider.dart';
import '../../providers/poke_api_provider.dart';
import '../../services/battle_backend.dart';
import '../../theme/battle_theme.dart';
import '../../utils/type_colors.dart';
import '../../widgets/battle_arena.dart';
import '../../widgets/battle_ui.dart';

// Pantalla de batalla contra la computadora (diseño "Batalla Pokemon.dc.html").
// Recibe el equipo que eligió el jugador (1 a 6); el rival se genera al azar.
// Arriba va la arena (BattleArena, con las animaciones) y abajo el panel, que cambia
// según la fase: menú, movimientos, equipo, mochila, mensajes del turno o resultado.
class BattleScreen extends StatelessWidget {
  final List<BattlePokemon> team;
  final String? userId; // Para la mochila y el premio

  const BattleScreen({super.key, required this.team, this.userId});

  @override
  Widget build(BuildContext context) {
    // Cada batalla tiene su propio BattleProvider, que se descarta al salir de la pantalla
    return ChangeNotifierProvider(
      create: (context) => BattleProvider(
        backend: context.read<BattleBackend>(),
        pokeApi: context.read<PokeApiProvider>(),
      )..start(team, userId: userId),
      child: const _BattleView(),
    );
  }
}

class _BattleView extends StatelessWidget {
  const _BattleView();

  // En Moderno el panel se monta 22 px sobre la arena
  static const _overlap = 22.0;

  @override
  Widget build(BuildContext context) {
    final battle = context.watch<BattleProvider>();
    final gba = watchIsGba(context);
    final ready = battle.phase != BattlePhase.loading && battle.phase != BattlePhase.error;

    final arena = BattleArena(
      gba: gba,
      me: ready ? battle.player : null,
      foe: ready ? battle.enemy : null,
      meHp: battle.playerHpShown,
      foeHp: battle.enemyHpShown,
      meStatus: battle.playerStatusShown,
      foeStatus: battle.enemyStatusShown,
      event: battle.lastEvent,
      itemUrl: battle.lastItemUsed?.urlImagen,
    );

    return Scaffold(
      backgroundColor: BattleColors.ink,
      appBar: BattleAppBar(title: 'Batalla', gba: gba),
      body: Column(
        children: [
          Expanded(
            child: gba
                ? arena
                : LayoutBuilder(
                    builder: (context, c) => OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: c.maxHeight + _overlap,
                      maxHeight: c.maxHeight + _overlap,
                      child: arena,
                    ),
                  ),
          ),
          _Panel(battle: battle, gba: gba),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final BattleProvider battle;
  final bool gba;

  const _Panel({required this.battle, required this.gba});

  @override
  Widget build(BuildContext context) {
    final bottom = 26 + MediaQuery.paddingOf(context).bottom;
    final padding = gba ? EdgeInsets.fromLTRB(12, 12, 12, bottom) : EdgeInsets.fromLTRB(14, 16, 14, bottom);
    final minHeight = 290 - padding.vertical + 26; // El alto mínimo no cuenta la barra del sistema

    Widget content = switch (battle.phase) {
      BattlePhase.choosingMove => _MoveGrid(battle: battle, gba: gba),
      BattlePhase.choosingPokemon => _TeamGrid(
          battle: battle,
          gba: gba,
          title: 'Elige un Pokémon',
          canPick: (i, p) => i != battle.activeIndex && !p.isFainted,
          onPick: battle.switchTo,
          onBack: battle.backToMenu,
        ),
      BattlePhase.choosingReplacement => _TeamGrid(
          battle: battle,
          gba: gba,
          title: '¡${capitalize(battle.player!.name)} se debilitó! Elige a tu siguiente Pokémon.',
          titleColor: BattleColors.accent,
          canPick: (i, p) => i != battle.activeIndex && !p.isFainted,
          onPick: battle.switchTo,
        ),
      BattlePhase.choosingItemTarget => _TeamGrid(
          battle: battle,
          gba: gba,
          title: '¿En quién usar ${battle.selectedItem?.item.nombre ?? 'el objeto'}?',
          canPick: (i, _) => battle.canUseItemOn(i),
          onPick: battle.useItemOn,
          onBack: battle.backToBag,
        ),
      BattlePhase.choosingItem => _BagList(battle: battle, gba: gba),
      // Las fases con cuadro de texto lo estiran para llenar el panel
      _ => IntrinsicHeight(child: _textPhase(context)),
    };

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight + padding.vertical),
      padding: padding,
      decoration: gba
          ? const BoxDecoration(
              color: BattleColors.ink,
              border: Border(top: BorderSide(color: BattleColors.primary, width: 4)),
            )
          : const BoxDecoration(
              color: BattleColors.modPanel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [BoxShadow(color: Color(0x590B0D22), blurRadius: 24, offset: Offset(0, -8))],
            ),
      child: ConstrainedBox(constraints: BoxConstraints(minHeight: minHeight), child: content),
    );
  }

  Widget _textPhase(BuildContext context) {
    Widget box(String text, {bool arrow = false, bool loading = false, VoidCallback? onTap}) => Expanded(
          child: BattleMessageBox(text: text, gba: gba, showArrow: arrow, loading: loading, onTap: onTap),
        );
    const gap = SizedBox(height: 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (battle.phase) {
        BattlePhase.loading => [box('Preparando la batalla', loading: true)],
        BattlePhase.error => [
            box(battle.errorMessage ?? 'No se pudo cargar la batalla.'),
            gap,
            BattleButton.primary(label: 'Reintentar', onPressed: battle.retry, gba: gba),
          ],
        // Mensajes del turno: sin menú; tocar el cuadro pasa al siguiente
        BattlePhase.busy => [box(battle.message, arrow: true, onTap: battle.advanceMessage)],
        BattlePhase.finished => [
            Expanded(child: _EndCard(battle: battle, gba: gba)),
            gap,
            BattleButton.primary(
              label: 'Volver a mis Pokémon',
              onPressed: () => Navigator.pop(context),
              gba: gba,
            ),
          ],
        _ => [box(battle.message), gap, _CommandMenu(battle: battle, gba: gba)],
      },
    );
  }
}

// Menú principal: Luchar / Mochila / Pokémon / Huir
class _CommandMenu extends StatelessWidget {
  final BattleProvider battle;
  final bool gba;

  const _CommandMenu({required this.battle, required this.gba});

  @override
  Widget build(BuildContext context) {
    final enabled = battle.phase == BattlePhase.choosingAction;
    final canSwitch = [
      for (var i = 0; i < battle.team.length; i++)
        if (i != battle.activeIndex && !battle.team[i].isFainted) i,
    ].isNotEmpty;
    final hasItems = battle.usableItems.any(battle.canUseItem);
    final t = BattleText(gba);

    VoidCallback? on(VoidCallback action, [bool allowed = true]) => enabled && allowed ? action : null;

    if (gba) {
      Widget button(String label, Color fill, Color text, VoidCallback? onPressed) => Expanded(
            child: BattleButton(label: label, onPressed: onPressed, gba: true, fill: fill, textColor: text),
          );
      return Column(
        children: [
          Row(children: [
            button('Luchar', BattleColors.primary, Colors.white, on(battle.openFight)),
            const SizedBox(width: 10),
            button('Mochila', BattleColors.accent, BattleColors.ink, on(battle.openBag, hasItems)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            button('Pokémon', BattleColors.mist, BattleColors.ink, on(battle.openTeam, canSwitch)),
            const SizedBox(width: 10),
            button('Huir', BattleColors.ghost, Colors.white, on(battle.flee)),
          ]),
        ],
      );
    }

    Widget small(String label, Color fill, Color text, VoidCallback? onPressed, {BorderSide? border}) => Expanded(
          child: BattleButton(
            label: label,
            onPressed: onPressed,
            gba: false,
            fill: fill,
            textColor: text,
            height: 54,
            border: border,
          ),
        );
    return Column(
      children: [
        BattleButton(
          label: 'Luchar',
          onPressed: on(battle.openFight),
          gba: false,
          fill: BattleColors.primary,
          textColor: Colors.white,
          height: 64,
          radius: 14,
          gradient: BattleButton.modernGradient,
          glow: BattleButton.modernGlow,
          style: t.command(Colors.white, big: true),
        ),
        const SizedBox(height: 10),
        Row(children: [
          small('Mochila', BattleColors.accent, BattleColors.ink, on(battle.openBag, hasItems)),
          const SizedBox(width: 8),
          small('Pokémon', BattleColors.mist, BattleColors.ink, on(battle.openTeam, canSwitch)),
          const SizedBox(width: 8),
          small('Huir', BattleColors.modCard, Colors.white, on(battle.flee),
              border: BorderSide(color: BattleColors.mist.withValues(alpha: .4), width: 1.5)),
        ]),
      ],
    );
  }
}

// Movimientos en 2×2 + Atrás
class _MoveGrid extends StatelessWidget {
  final BattleProvider battle;
  final bool gba;

  const _MoveGrid({required this.battle, required this.gba});

  @override
  Widget build(BuildContext context) {
    final moves = battle.player!.moves;
    final buttons = [
      for (final move in moves)
        _MoveButton(
          move: move,
          gba: gba,
          onPressed: move.hasPp ? () => battle.useMove(move) : null,
        ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < buttons.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: buttons[i]),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < buttons.length ? buttons[i + 1] : const SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
        const SizedBox(height: 10),
        BattleBackButton(onPressed: battle.backToMenu, gba: gba),
      ],
    );
  }
}

class _MoveButton extends StatelessWidget {
  final BattleMove move;
  final bool gba;
  final VoidCallback? onPressed;

  const _MoveButton({required this.move, required this.gba, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final off = onPressed == null;
    final color = colorForType(move.type);
    final fg = off ? const Color(0xFFA3A8C8) : textOnType(move.type);
    final t = BattleText(gba);
    final power = move.doesDamage ? '${move.power}' : '—';

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(move.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.moveName(fg)),
        const SizedBox(height: 6),
        Row(children: [
          TypeChip(type: move.type, gba: gba, onMove: true),
          const SizedBox(width: 6),
          MoveCategoryIcon(damageClass: move.damageClass, gba: gba),
        ]),
        const SizedBox(height: 6),
        Text(
          'Poder $power · PP ${move.currentPp}/${move.pp}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.moveInfo(fg).copyWith(height: 1),
        ),
      ],
    );

    final decoration = gba
        ? BoxDecoration(
            color: off ? BattleColors.disabled : color,
            border: Border.all(color: BattleColors.shadow, width: 3),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: BattleColors.shadow, offset: Offset(0, 4))],
          )
        : BoxDecoration(
            color: off ? BattleColors.hpTrack : null,
            gradient: off
                ? null
                : LinearGradient(
                    begin: const Alignment(-.42, -.9),
                    end: const Alignment(.42, .9),
                    colors: [color, color, shade(color, .82), shade(color, .82)],
                    stops: const [0, .58, .58, 1],
                  ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))],
          );

    return PressableCard(
      gba: gba,
      onTap: onPressed,
      child: Container(
        constraints: BoxConstraints(minHeight: gba ? 86 : 88),
        padding: gba ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: decoration,
        child: content,
      ),
    );
  }
}

// Equipo en 2 columnas: para cambiar, para reemplazar al debilitado o para dar un objeto
class _TeamGrid extends StatelessWidget {
  final BattleProvider battle;
  final bool gba;
  final String title;
  final Color titleColor;
  final bool Function(int index, BattlePokemon pokemon) canPick;
  final void Function(int index) onPick;
  final VoidCallback? onBack; // Nulo cuando es obligatorio elegir (el tuyo se debilitó)

  const _TeamGrid({
    required this.battle,
    required this.gba,
    required this.title,
    this.titleColor = Colors.white,
    required this.canPick,
    required this.onPick,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (var i = 0; i < battle.team.length; i++)
        _TeamCard(
          pokemon: battle.team[i],
          gba: gba,
          inBattle: i == battle.activeIndex && !battle.team[i].isFainted,
          onTap: canPick(i, battle.team[i]) ? () => onPick(i) : null,
        ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[i]),
            const SizedBox(width: 8),
            Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ListHeader(title: title, titleColor: titleColor, gba: gba, onBack: onBack),
        const SizedBox(height: 10),
        ...rows,
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  final String title;
  final Color titleColor;
  final bool gba;
  final VoidCallback? onBack;

  const _ListHeader({required this.title, this.titleColor = Colors.white, required this.gba, this.onBack});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(child: Text(title, style: BattleText(gba).listTitle(titleColor))),
          if (onBack != null) ...[
            const SizedBox(width: 10),
            BattleBackButton(onPressed: onBack!, gba: gba, height: 44, compact: true),
          ],
        ],
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final BattlePokemon pokemon;
  final bool gba;
  final bool inBattle;
  final VoidCallback? onTap;

  const _TeamCard({required this.pokemon, required this.gba, required this.inBattle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fainted = pokemon.isFainted;
    final t = BattleText(gba);
    final textColor = gba ? BattleColors.ink : Colors.white;

    // Sprite de 76 recortado a 48 (los sprites traen mucho borde vacío)
    Widget sprite = SizedBox(
      width: 48,
      height: 48,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: 76,
          maxHeight: 76,
          child: PokemonSprite(url: pokemon.frontSprite, size: 76),
        ),
      ),
    );
    if (fainted) sprite = ColorFiltered(colorFilter: faintedFilter, child: sprite);

    final card = Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: gba ? const EdgeInsets.fromLTRB(4, 6, 10, 9) : const EdgeInsets.fromLTRB(4, 6, 12, 10),
      decoration: gba
          ? BoxDecoration(
              color: inBattle ? BattleColors.inBattle : BattleColors.surface,
              border: Border.all(color: inBattle ? BattleColors.accent : BattleColors.shadow, width: 3),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: BattleColors.shadow, offset: Offset(0, 3))],
            )
          : BoxDecoration(
              color: BattleColors.modCard,
              border: Border.all(color: inBattle ? BattleColors.accent : Colors.transparent, width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              sprite,
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(capitalize(pokemon.name),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: t.cardName(textColor)),
                    if (inBattle) ...[
                      const SizedBox(height: 3),
                      Text('(en combate)', style: t.inBattle().copyWith(height: 1)),
                    ],
                    if (!fainted && pokemon.status != StatusCondition.sano) ...[
                      const SizedBox(height: 3),
                      BattleStatusChip(status: pokemon.status, gba: gba, small: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: gba ? 5 : 6),
          Padding(
            padding: EdgeInsets.only(left: gba ? 4 : 6),
            child: Row(
              children: [
                Expanded(child: BattleHpBar(current: pokemon.currentHp, max: pokemon.maxHp, gba: gba, small: true)),
                SizedBox(width: gba ? 6 : 8),
                Text('${pokemon.currentHp} / ${pokemon.maxHp}', style: t.cardHp()),
              ],
            ),
          ),
        ],
      ),
    );

    return PressableCard(
      gba: gba,
      onTap: onTap,
      // La tarjeta "en combate" no se apaga aunque no se pueda elegir
      disabledOpacity: inBattle ? 1 : .42,
      child: card,
    );
  }
}

// Mochila: solo los objetos que sirven en batalla (pociones, curas de estado, revivir)
class _BagList extends StatelessWidget {
  final BattleProvider battle;
  final bool gba;

  const _BagList({required this.battle, required this.gba});

  @override
  Widget build(BuildContext context) {
    final items = battle.usableItems;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ListHeader(title: 'Mochila', gba: gba, onBack: battle.backToMenu),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .45),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _BagRow(
                    bagItem: items[i],
                    gba: gba,
                    onTap: battle.canUseItem(items[i]) ? () => battle.selectItem(items[i]) : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BagRow extends StatelessWidget {
  final BagItem bagItem;
  final bool gba;
  final VoidCallback? onTap;

  const _BagRow({required this.bagItem, required this.gba, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = BattleText(gba);
    final item = bagItem.item;
    return PressableCard(
      gba: gba,
      onTap: onTap,
      disabledOpacity: .45,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: gba ? const EdgeInsets.fromLTRB(6, 5, 14, 5) : const EdgeInsets.fromLTRB(6, 6, 16, 6),
        decoration: gba
            ? BoxDecoration(
                color: BattleColors.surface,
                border: Border.all(color: BattleColors.shadow, width: 3),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: BattleColors.shadow, offset: Offset(0, 3))],
              )
            : BoxDecoration(color: BattleColors.modCard, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: gba
                  ? BoxDecoration(color: BattleColors.mist, borderRadius: BorderRadius.circular(6))
                  : const BoxDecoration(color: BattleColors.modCardHi, shape: BoxShape.circle),
              child: ItemImage(url: item.urlImagen, size: gba ? 40 : 38),
            ),
            SizedBox(width: gba ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.nombre, style: t.itemName()),
                  if (item.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.itemDesc()),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('x${bagItem.cantidad}', style: t.itemQty()),
          ],
        ),
      ),
    );
  }
}

// Resultado: ¡Victoria! / Derrota / ¡Huiste!, con el premio si lo hubo
class _EndCard extends StatelessWidget {
  final BattleProvider battle;
  final bool gba;

  const _EndCard({required this.battle, required this.gba});

  @override
  Widget build(BuildContext context) {
    final t = BattleText(gba);
    final foe = capitalize(battle.enemy?.name ?? '');
    final reward = battle.reward;
    final (title, sub, color) = switch (battle.outcome) {
      BattleOutcome.won => (
          '¡Victoria!',
          reward == null ? '$foe se debilitó.' : '$foe se debilitó. Recibiste un premio:',
          gba ? BattleColors.primary : BattleColors.accent,
        ),
      BattleOutcome.lost => (
          'Derrota',
          'Todos tus Pokémon se debilitaron.',
          gba ? const Color(0xFFC23A3A) : const Color(0xFFFF7A7A),
        ),
      _ => ('¡Huiste!', 'Escapaste sin problemas.', gba ? BattleColors.ink : Colors.white),
    };

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.endTitle(color).copyWith(height: 1)),
        const SizedBox(height: 10),
        Text(sub, style: t.endSub()),
        if (reward != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: EdgeInsets.fromLTRB(4, 3, gba ? 14 : 16, 3),
            decoration: ShapeDecoration(
              color: BattleColors.accent,
              shape: StadiumBorder(
                side: gba ? const BorderSide(color: BattleColors.ink, width: 3) : BorderSide.none,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ItemImage(url: reward.urlImagen, size: 34),
                const SizedBox(width: 6),
                Text('+1 ${reward.nombre}', style: t.reward()),
              ],
            ),
          ),
        ],
        if (battle.saveFailed) ...[
          const SizedBox(height: 10),
          Text(
            'No se pudo guardar el resultado en el servidor.',
            style: t.body(gba ? const Color(0xFFC23A3A) : const Color(0xFFFF7A7A), size: 14),
          ),
        ],
      ],
    );

    if (!gba) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: BattleColors.modCard, borderRadius: BorderRadius.circular(16)),
        child: content,
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: BattleColors.mist, borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BattleColors.textBox,
          border: Border.all(color: BattleColors.primary, width: 3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: content,
      ),
    );
  }
}
