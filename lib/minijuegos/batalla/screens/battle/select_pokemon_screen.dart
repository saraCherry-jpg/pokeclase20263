import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/battle_pokemon.dart';
import '../../providers/battle_provider.dart';
import '../../services/battle_backend.dart';
import '../../theme/battle_theme.dart';
import '../../utils/type_colors.dart';
import '../../widgets/battle_ui.dart';
import 'battle_screen.dart';
import 'history_screen.dart';

// Pantalla de entrada al módulo de batallas ("Mis Pokémon" en el diseño): el jugador
// arma su equipo (1 a 6 Pokémon) y entra a pelear. También lleva al historial y deja
// cambiar entre los dos estilos del diseño (GBA / Moderno). Curar es de otro módulo.
// La app general solo tiene que navegar aquí pasándole el id del usuario logueado.
class SelectPokemonScreen extends StatefulWidget {
  final String userId; // AspNetUsers.Id del usuario logueado

  const SelectPokemonScreen({super.key, required this.userId});

  @override
  State<SelectPokemonScreen> createState() => _SelectPokemonScreenState();
}

class _SelectPokemonScreenState extends State<SelectPokemonScreen> {
  late Future<List<BattlePokemon>> _future;
  // Ids (PokemonUser.Id) elegidos, en el orden en que se tocaron. El primero sale a pelear.
  final List<int> _selected = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<BattleBackend>().getMyPokemon(widget.userId);
  }

  void _toggle(BattlePokemon pokemon) {
    final id = pokemon.idPokemonUser!;
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < BattleProvider.maxTeamSize) {
        _selected.add(id);
      }
    });
  }

  Future<void> _openBattle(List<BattlePokemon> pokemons) async {
    final team = _selected
        .map((id) => pokemons.where((p) => p.idPokemonUser == id).firstOrNull)
        .whereType<BattlePokemon>()
        .toList();
    if (team.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BattleScreen(team: team, userId: widget.userId)),
    );
    // Al volver, recargamos para ver la vida actualizada después de la batalla
    setState(() {
      _selected.clear();
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gba = watchIsGba(context);
    final t = BattleText(gba);

    return Scaffold(
      backgroundColor: gba ? const Color(0xFFE8EAF5) : BattleColors.modPanel,
      appBar: BattleAppBar(
        title: 'Mis Pokémon',
        gba: gba,
        actions: [
          IconButton(
            tooltip: gba ? 'Cambiar a estilo Moderno' : 'Cambiar a estilo GBA',
            color: Colors.white,
            icon: Icon(gba ? Icons.auto_awesome : Icons.grid_4x4),
            onPressed: () => context.read<BattleStyleProvider>().toggle(),
          ),
          IconButton(
            tooltip: 'Historial',
            color: Colors.white,
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HistoryScreen(userId: widget.userId)),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<BattlePokemon>>(
        future: _future,
        builder: (context, snapshot) {
          final hintColor = gba ? BattleColors.subtle : BattleColors.mist;
          Widget centered(String text) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(text, textAlign: TextAlign.center, style: t.body(hintColor, size: 16)),
                ),
              );

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: BattleColors.primary));
          } else if (snapshot.hasError) {
            return centered('No se pudieron cargar tus Pokémon.\n${snapshot.error}');
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return centered('Todavía no tienes Pokémon capturados.');
          }

          final pokemons = snapshot.data!;
          final byId = {for (final p in pokemons) p.idPokemonUser: p};
          final full = _selected.length >= BattleProvider.maxTeamSize;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TeamHeader(
                gba: gba,
                team: _selected.map((id) => byId[id]).whereType<BattlePokemon>().toList(),
                onRemove: _toggle,
              ),
              Padding(
                padding: gba ? const EdgeInsets.fromLTRB(14, 12, 14, 4) : const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Text('Toca un Pokémon para añadirlo o quitarlo.', style: t.body(hintColor, size: gba ? 15 : 14)),
              ),
              Expanded(
                child: GridView.builder(
                  padding: gba ? const EdgeInsets.fromLTRB(12, 8, 12, 14) : const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 136,
                  ),
                  itemCount: pokemons.length,
                  itemBuilder: (context, index) {
                    final pokemon = pokemons[index];
                    final order = _selected.indexOf(pokemon.idPokemonUser ?? -1);
                    final selected = order >= 0;
                    return _RosterCard(
                      pokemon: pokemon,
                      gba: gba,
                      order: selected ? order + 1 : null,
                      dimmed: !selected && full,
                      onTap: pokemon.isFainted ? null : () => _toggle(pokemon),
                    );
                  },
                ),
              ),
              _StartBar(
                gba: gba,
                onStart: _selected.isEmpty ? null : () => _openBattle(pokemons),
              ),
            ],
          );
        },
      ),
    );
  }
}

// "Tu equipo" con los 6 lugares. Tocar uno lleno lo quita.
class _TeamHeader extends StatelessWidget {
  final bool gba;
  final List<BattlePokemon> team;
  final void Function(BattlePokemon) onRemove;

  const _TeamHeader({required this.gba, required this.team, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final t = BattleText(gba);
    const max = BattleProvider.maxTeamSize;
    return Container(
      padding: gba ? const EdgeInsets.fromLTRB(12, 12, 12, 14) : const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: gba ? BattleColors.ink : null,
        gradient: gba
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [BattleColors.ink, BattleColors.modPanel],
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('Tu equipo', style: t.sectionTitle())),
              Text('${team.length} / $max', style: t.counter()),
            ],
          ),
          SizedBox(height: gba ? 10 : 12),
          Row(
            children: [
              for (var i = 0; i < max; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _Slot(
                      gba: gba,
                      number: i + 1,
                      pokemon: i < team.length ? team[i] : null,
                      onTap: i < team.length ? () => onRemove(team[i]) : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  final bool gba;
  final int number;
  final BattlePokemon? pokemon;
  final VoidCallback? onTap;

  const _Slot({required this.gba, required this.number, required this.pokemon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final filled = pokemon != null;
    final Widget inside = filled
        ? ClipRect(
            child: OverflowBox(
              minWidth: 0,
              minHeight: 0,
              maxWidth: 68,
              maxHeight: 68,
              child: PokemonSprite(url: pokemon!.frontSprite, size: 68),
            ),
          )
        : Center(child: Text('$number', style: BattleText(gba).slotNumber()));

    final decoration = gba
        ? BoxDecoration(
            color: filled ? BattleColors.surface : BattleColors.ghost,
            border: Border.all(color: BattleColors.shadow, width: 3),
            borderRadius: BorderRadius.circular(8),
          )
        : BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? BattleColors.modCard : Colors.transparent,
            border: Border.all(
              color: filled ? BattleColors.accent : BattleColors.mist.withValues(alpha: .35),
              width: 2,
            ),
          );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: decoration,
        child: inside,
      ),
    );
  }
}

class _RosterCard extends StatelessWidget {
  final BattlePokemon pokemon;
  final bool gba;
  final int? order; // Lugar en el equipo (1-6), nulo si no está elegido
  final bool dimmed; // El equipo ya está lleno
  final VoidCallback? onTap;

  const _RosterCard({
    required this.pokemon,
    required this.gba,
    required this.order,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = BattleText(gba);
    final selected = order != null;
    final fainted = pokemon.isFainted;
    final textColor = gba ? BattleColors.ink : Colors.white;

    Widget sprite = PokemonSprite(url: pokemon.frontSprite, size: 76);
    if (fainted) sprite = ColorFiltered(colorFilter: faintedFilter, child: sprite);

    final card = Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 9),
      decoration: gba
          ? BoxDecoration(
              color: selected ? BattleColors.inBattle : BattleColors.surface,
              border: Border.all(color: selected ? BattleColors.primary : BattleColors.shadow, width: 3),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: BattleColors.shadow, offset: Offset(0, 3))],
            )
          : BoxDecoration(
              color: BattleColors.modCard,
              border: Border.all(color: selected ? BattleColors.accent : Colors.transparent, width: 2),
              borderRadius: BorderRadius.circular(14),
            ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              SizedBox(height: 68, child: OverflowBox(maxHeight: 76, alignment: Alignment.topCenter, child: sprite)),
              const SizedBox(height: 4),
              Text(capitalize(pokemon.name),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: t.rosterName(textColor)),
              const SizedBox(height: 4),
              if (fainted)
                // Curar es de otro módulo: aquí solo se avisa
                _Tag(text: 'Debilitado', bg: const Color(0xFFC23A3A), fg: Colors.white, gba: gba)
              else
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  alignment: WrapAlignment.center,
                  children: [for (final type in pokemon.types) TypeChip(type: type, gba: gba)],
                ),
            ],
          ),
          if (selected)
            Positioned(
              top: 3,
              right: 1,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: gba
                    ? BoxDecoration(
                        color: BattleColors.primary,
                        border: Border.all(color: BattleColors.shadow, width: 2),
                        borderRadius: BorderRadius.circular(5),
                      )
                    : const BoxDecoration(color: BattleColors.accent, shape: BoxShape.circle),
                child: Text('$order', style: t.order(gba ? Colors.white : BattleColors.ink)),
              ),
            ),
        ],
      ),
    );

    return PressableCard(
      gba: gba,
      onTap: onTap,
      disabledOpacity: .5,
      child: Opacity(opacity: dimmed ? .45 : 1, child: card),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final bool gba;

  const _Tag({required this.text, required this.bg, required this.fg, required this.gba});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: gba ? 4 : 6, vertical: 3),
      decoration: gba
          ? BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3))
          : ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Text(text, style: BattleText(gba).typeChip(fg, size: 9).copyWith(height: 1)),
    );
  }
}

// Barra inferior: rival (siempre al azar) + ¡A la batalla!
class _StartBar extends StatelessWidget {
  final bool gba;
  final VoidCallback? onStart;

  const _StartBar({required this.gba, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final t = BattleText(gba);
    return Container(
      padding: EdgeInsets.fromLTRB(gba ? 12 : 14, gba ? 12 : 14, gba ? 12 : 14, 26 + MediaQuery.paddingOf(context).bottom),
      decoration: gba
          ? const BoxDecoration(
              color: BattleColors.ink,
              border: Border(top: BorderSide(color: BattleColors.primary, width: 4)),
            )
          : const BoxDecoration(
              color: BattleColors.ink,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [BoxShadow(color: Color(0x590B0D22), blurRadius: 24, offset: Offset(0, -8))],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BattleColors.ghost,
                  shape: gba ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: gba ? BorderRadius.circular(4) : null,
                ),
                child: Text('?', style: t.body(BattleColors.accent, size: 15).copyWith(fontWeight: FontWeight.w700, height: 1)),
              ),
              const SizedBox(width: 8),
              Text('Rival: al azar', style: t.body(BattleColors.mist, size: gba ? 15 : 14)),
            ],
          ),
          const SizedBox(height: 10),
          BattleButton.primary(
            label: '¡A la batalla!',
            onPressed: onStart,
            gba: gba,
            height: gba ? 58 : 60,
            skew: !gba,
          ),
        ],
      ),
    );
  }
}
