import 'package:flutter/material.dart';
import 'package:pokeclase20263/models/trade_request.dart';
import 'package:pokeclase20263/screens/backend_center_screen.dart';
import 'package:pokeclase20263/services/center_api.dart';
import 'package:pokeclase20263/screens/pokemon_trade_screen.dart';
import 'package:pokeclase20263/widgets/menu_button.dart';
import 'package:pokeclase20263/widgets/responsive_panel.dart';

class PokemonSelectionScreen extends StatefulWidget {
  final List<TradeRequest> incomingRequests;
  final Map<String, dynamic>? incomingTrade;
  final CenterApi? api;

  const PokemonSelectionScreen({
    super.key,
    this.incomingRequests = const [],
    this.incomingTrade,
    this.api,
  });

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
      final data = await (widget.api ?? CenterApi.instance).pokemon(
        availableOnly: true,
      );
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
        builder: (_) => BackendCenterScreen(trades: true, api: widget.api),
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
                    onPressed: widget.incomingTrade == null
                        ? _openRequests
                        : null,
                    icon: Badge(
                      label: Text('${widget.incomingRequests.length}'),
                      isLabelVisible: widget.incomingRequests.isNotEmpty,
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        color: Color(0xFF30275C),
                      ),
                    ),
                  ),
                  if (widget.incomingTrade == null)
                    IconButton(
                      key: const Key('sent-trades-button'),
                      tooltip: 'Intercambios enviados',
                      icon: const Icon(
                        Icons.outbox_outlined,
                        color: Color(0xFF30275C),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BackendCenterScreen(
                              trades: true,
                              sentOnly: true,
                              api: widget.api,
                            ),
                          ),
                        );
                        if (mounted) await _load();
                      },
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.incomingTrade == null
                          ? 'Elige un Pokémon'
                          : 'Elige tu Pokémon para aceptar',
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
                        padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
                        child: Scrollbar(
                          controller: scrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          thickness: 10,
                          radius: const Radius.circular(12),
                          child: GridView.builder(
                            key: const Key('captured-pokemon-grid'),
                            controller: scrollController,
                            padding: const EdgeInsets.only(right: 16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent: 160,
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
                                                Positioned.fill(
                                                  child: Image.network(
                                                    (_pokemon[id]?['urlFrontal']
                                                                    as String?)
                                                                ?.isNotEmpty ==
                                                            true
                                                        ? _pokemon[id]!['urlFrontal']
                                                              as String
                                                        : 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${_pokemon[id]?['idPokemon']}.png',
                                                    fit: BoxFit.contain,
                                                    filterQuality:
                                                        FilterQuality.none,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          error,
                                                          stackTrace,
                                                        ) => const Icon(
                                                          Icons
                                                              .catching_pokemon,
                                                          color: Colors.white,
                                                        ),
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
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            height: 24,
                                            width: double.infinity,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '${_pokemon[id]?['nombre'] ?? '#$id'}',
                                                maxLines: 1,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: selected
                                                      ? const Color(0xFF30275C)
                                                      : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
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
                                selectedPokemonNames: {
                                  for (final id in selectedPokemon)
                                    id: '${_pokemon[id]?['nombre'] ?? '#$id'}',
                                },
                                incomingTrade: widget.incomingTrade,
                                api: widget.api,
                                selectedPokemonIds: List.unmodifiable(
                                  selectedPokemon,
                                ),
                              ),
                            ),
                          );
                          if (!context.mounted) return;
                          if (widget.incomingTrade != null) {
                            Navigator.pop(context);
                          } else {
                            await _load();
                          }
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
