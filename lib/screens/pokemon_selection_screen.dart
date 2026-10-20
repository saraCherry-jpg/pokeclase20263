import 'package:flutter/material.dart';
import 'package:pokeclase20263/models/trade_request.dart';
import 'package:pokeclase20263/screens/backend_center_screen.dart';
import 'package:pokeclase20263/services/center_api.dart';
import 'package:pokeclase20263/screens/pokemon_trade_screen.dart';
import 'package:pokeclase20263/widgets/menu_button.dart';
import 'package:pokeclase20263/widgets/pokeball_painter.dart';
import 'package:pokeclase20263/widgets/responsive_panel.dart';

class PokemonSelectionScreen extends StatefulWidget {
  final List<TradeRequest> incomingRequests;

  const PokemonSelectionScreen({super.key, this.incomingRequests = const []});

  @override
  State<PokemonSelectionScreen> createState() => _PokemonSelectionScreenState();
}

class _PokemonSelectionScreenState extends State<PokemonSelectionScreen> {
  List<int> capturedPokemon = [];
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
      final data = await CenterApi.instance.pokemon(availableOnly: true);
      if (!mounted) return;
      setState(() {
        _pokemon = {for (final p in data) p['id'] as int: p};
        capturedPokemon = _pokemon.keys.toList();
        selectedPokemon.removeWhere((id) => !capturedPokemon.contains(id));
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

  final Set<int> selectedPokemon = {};
  final ScrollController scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _openRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BackendCenterScreen(trades: true),
      ),
    );
    if (mounted) await _load();
  }

  void togglePokemon(int id) {
    setState(() {
      if (selectedPokemon.contains(id)) {
        selectedPokemon.remove(id);
      } else if (selectedPokemon.isEmpty) {
        selectedPokemon.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: const Color(0xFFB9B9D5),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.035),
          child: Column(
            children: [
              Row(
                children: [
                  const MenuButton(),
                  IconButton(
                    key: const Key('trade-requests-button'),
                    tooltip: 'Solicitudes de intercambio',
                    onPressed: _openRequests,
                    icon: Badge(
                      label: Text('${widget.incomingRequests.length}'),
                      isLabelVisible: widget.incomingRequests.isNotEmpty,
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        color: Color(0xFF30275C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Elige un Pokémon',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Text(
                'Pokémon disponibles · Toca para seleccionar o quitar',
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) Text(_error!),
              if (!_loading && capturedPokemon.isEmpty)
                const Text('No tienes Pokémon disponibles.'),
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() => _loading = true);
                        _load();
                      },
                child: const Text('Actualizar'),
              ),
              SizedBox(height: screenHeight * 0.015),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ResponsivePanel(
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(screenWidth * 0.05),
                        padding: const EdgeInsets.fromLTRB(20, 24, 12, 16),
                        child: Scrollbar(
                          controller: scrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          thickness: 10,
                          radius: const Radius.circular(12),
                          child: GridView.builder(
                            key: const Key('captured-pokemon-grid'),
                            controller: scrollController,
                            padding: const EdgeInsets.only(left: 20, right: 24),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: screenWidth < 360 ? 3 : 4,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.85,
                                ),
                            itemCount: capturedPokemon.length,
                            itemBuilder: (context, index) {
                              final id = capturedPokemon[index];
                              final selected = selectedPokemon.contains(id);
                              final enabled =
                                  selected || selectedPokemon.isEmpty;
                              return Semantics(
                                label:
                                    '${_pokemon[id]?['nombre'] ?? 'Pokémon'} $id',
                                selected: selected,
                                child: InkWell(
                                  key: ValueKey('pokemon-$id'),
                                  onTap: enabled
                                      ? () => togglePokemon(id)
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFFE5D36D)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Opacity(
                                      opacity: enabled ? 1 : 0.45,
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                const AspectRatio(
                                                  aspectRatio: 1,
                                                  child: CustomPaint(
                                                    painter: PokeballPainter(),
                                                  ),
                                                ),
                                                if (selected)
                                                  const Align(
                                                    alignment:
                                                        Alignment.topRight,
                                                    child: Icon(
                                                      Icons.check_circle,
                                                      color: Color(0xFF246634),
                                                      size: 20,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '${_pokemon[id]?['nombre'] ?? '#$id'}',
                                            style: TextStyle(
                                              color: selected
                                                  ? const Color(0xFF30275C)
                                                  : Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${selectedPokemon.length} / 1 seleccionados',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('continue-to-trade'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5345AB),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: !_loading && selectedPokemon.isNotEmpty
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PokemonTradeScreen(
                                selectedPokemonIds: List.unmodifiable(
                                  selectedPokemon,
                                ),
                              ),
                            ),
                          );
                          if (mounted) await _load();
                        }
                      : null,
                  child: const Text('Llevar a la máquina de intercambio'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
