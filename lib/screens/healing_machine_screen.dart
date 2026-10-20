import 'package:pokeclase20263/services/center_api.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pokeclase20263/widgets/menu_button.dart';
import 'package:pokeclase20263/widgets/pokeball_painter.dart';
import 'package:pokeclase20263/widgets/responsive_panel.dart';

class HealingMachineScreen extends StatefulWidget {
  final CenterApi? api;
  const HealingMachineScreen({super.key, this.api});

  @override
  State<HealingMachineScreen> createState() => _HealingMachineScreenState();
}

class _HealingMachineScreenState extends State<HealingMachineScreen> {
  List<int> available = [];
  Map<int, Map<String, dynamic>> _pokemon = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await (widget.api ?? CenterApi.instance).pokemon();
      if (!mounted) return;
      setState(() {
        _pokemon = {for (final p in data) p['id'] as int: p};
        available = _pokemon.keys.toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  final ScrollController _scrollController = ScrollController();
  final List<int?> _slots = List.filled(6, null);
  int _progress = 0;
  bool _healing = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _place(int slot, int id) {
    if (_healing || _slots[slot] != null || _slots.contains(id)) {
      return;
    }
    setState(() {
      _slots[slot] = id;
      _progress = 0;
    });
  }

  Future<void> _heal() async {
    if (_healing || _loading) return;
    setState(() {
      _healing = true;
      _progress = 0;
      _error = null;
    });
    try {
      final count = await (widget.api ?? CenterApi.instance).heal();
      if (!mounted) return;
      setState(() {
        _progress = 100;
        _slots.fillRange(0, 6, null);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pokémon actualizados: $count')));
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _healing = false);
    }
  }

  Widget _ball(int id) => Semantics(
    label: '${_pokemon[id]?['nombre'] ?? 'Pokémon'} $id',
    child: CustomPaint(painter: PokeballPainter()),
  );

  Widget _machine() => LayoutBuilder(
    builder: (context, constraints) {
      // Match the centered BoxFit.cover background exactly.
      final scale = math.max(
        constraints.maxWidth / 900,
        constraints.maxHeight / 1600,
      );
      final dx = (constraints.maxWidth - 900 * scale) / 2;
      final dy = (constraints.maxHeight - 1600 * scale) / 2;
      Widget at(double x, double y, double w, double h, Widget child) =>
          Positioned(
            left: dx + x * scale,
            top: dy + y * scale,
            width: w * scale,
            height: h * scale,
            child: child,
          );
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          at(
            285,
            150,
            145,
            68,
            Semantics(
              label: 'Barra de curación',
              child: Center(
                child: LinearProgressIndicator(
                  key: const Key('healing-progress-bar'),
                  value: _progress / 100,
                  minHeight: 42 * scale,
                  backgroundColor: const Color(0xFF353653),
                  color: const Color(0xFF00C900),
                ),
              ),
            ),
          ),
          at(
            475,
            150,
            138,
            68,
            Semantics(
              liveRegion: true,
              child: FittedBox(
                child: Text(
                  '$_progress%',
                  key: const Key('healing-progress-text'),
                  style: const TextStyle(
                    color: Color(0xFF00C900),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          for (var slot = 0; slot < 6; slot++)
            at(
              260 + (slot % 3) * 133,
              299 + (slot ~/ 3) * 125,
              112,
              112,
              DragTarget<int>(
                key: ValueKey('healing-slot-$slot'),
                onWillAcceptWithDetails: (details) =>
                    !_healing &&
                    _slots[slot] == null &&
                    !_slots.contains(details.data),
                onAcceptWithDetails: (details) => _place(slot, details.data),
                builder: (context, candidates, rejected) => Semantics(
                  label:
                      'Espacio ${slot + 1}${_slots[slot] == null ? ', vacío' : ', Pokémon ${_slots[slot]}'}',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: candidates.isNotEmpty
                          ? Colors.green.withValues(alpha: 0.4)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: candidates.isNotEmpty
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: _slots[slot] == null
                        ? null
                        : Tooltip(
                            message: 'Toca para devolver al panel',
                            child: InkWell(
                              onTap: _healing
                                  ? null
                                  : () => setState(() {
                                      _slots[slot] = null;
                                      _progress = 0;
                                    }),
                              child: _ball(_slots[slot]!),
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/poke_center/centerF2.jpeg',
            fit: BoxFit.cover,
          ),
          _machine(),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: const MenuButton(),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: screenHeight * 0.04,
            child: ResponsivePanel(
              widthFactor: 1,
              height: screenHeight * 0.38,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading || _healing) const LinearProgressIndicator(),
                  const Text(
                    'La máquina cura todos tus Pokémon elegibles.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  if (_error != null)
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  if (!_loading && _error == null && available.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'No tienes Pokémon para curar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  if (_error != null || (!_loading && available.isEmpty))
                    TextButton(
                      onPressed: _healing || _loading
                          ? null
                          : () {
                              setState(() => _loading = true);
                              _load();
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Actualizar'),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      thickness: 10,
                      radius: const Radius.circular(12),
                      child: GridView.builder(
                        key: const Key('healing-pokemon-grid'),
                        controller: _scrollController,
                        padding: const EdgeInsets.only(right: 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: screenWidth < 360 ? 3 : 4,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: available
                            .where((id) => !_slots.contains(id))
                            .length,
                        itemBuilder: (context, index) {
                          final id = available
                              .where((item) => !_slots.contains(item))
                              .skip(index)
                              .first;
                          final tile = Column(
                            children: [
                              Expanded(
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: _ball(id),
                                ),
                              ),
                              Text(
                                '${_pokemon[id]?['nombre'] ?? '#$id'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                          return LongPressDraggable<int>(
                            key: ValueKey('healing-pokemon-$id'),
                            data: id,
                            maxSimultaneousDrags: _healing ? 0 : 1,
                            feedback: SizedBox(
                              width: 64,
                              height: 64,
                              child: _ball(id),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.25,
                              child: tile,
                            ),
                            child: tile,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: screenWidth * 0.4,
            top: screenHeight * 0.10,
            width: screenWidth * 0.20,
            height: screenHeight * 0.60,
            child: Center(
              child: IconButton(
                key: const Key('healing-machine-button'),
                tooltip: _healing ? 'Curando…' : 'Curar todos los Pokémon',
                padding: EdgeInsets.zero,
                onPressed:
                    !_healing &&
                        !_loading &&
                        _error == null &&
                        available.isNotEmpty
                    ? _heal
                    : null,
                icon: Image.asset(
                  'assets/images/poke_center/x.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
