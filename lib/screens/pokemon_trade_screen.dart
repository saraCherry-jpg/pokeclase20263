import 'package:flutter/material.dart';
import 'package:pokeclase20263/services/center_api.dart';
import 'package:pokeclase20263/models/trade_request.dart';
import 'package:pokeclase20263/widgets/menu_button.dart';
import 'package:pokeclase20263/widgets/trainer_search_dialog.dart';
import 'package:pokeclase20263/widgets/pokeball_painter.dart';
import 'package:pokeclase20263/widgets/responsive_panel.dart';

class PokemonTradeScreen extends StatefulWidget {
  final List<int> selectedPokemonIds;

  final TradeRequest? incomingRequest;

  const PokemonTradeScreen({
    super.key,
    this.selectedPokemonIds = const [],
    this.incomingRequest,
  });

  @override
  State<PokemonTradeScreen> createState() => _PokemonTradeScreenState();
}

class _PokemonTradeScreenState extends State<PokemonTradeScreen> {
  TradeTrainer? _selectedTrainer;
  bool _sending = false;
  bool _sent = false;
  String? _error;
  Future<void> _send() async {
    if (_sending ||
        _sent ||
        _selectedTrainer == null ||
        widget.selectedPokemonIds.length != 1) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await CenterApi.instance.create(
        _selectedTrainer!.id,
        widget.selectedPokemonIds.single,
      );
      if (!mounted) return;
      setState(() => _sent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitación enviada. El destinatario debe aceptarla.'),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _searchTrainer() async {
    final trainer = await showDialog<TradeTrainer>(
      context: context,
      builder: (_) =>
          TrainerSearchDialog(selectedTrainerId: _selectedTrainer?.id),
    );
    if (!mounted || trainer == null) return;
    setState(() => _selectedTrainer = trainer);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: const Color(0xFF130F20),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/poke_center/tradeF1.jpeg',
            key: const Key('trade-background'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: const MenuButton(),
            ),
          ),
          Positioned(
            left: screenWidth * 0.03,
            top: screenHeight * 0.15,
            width: screenWidth * 0.99,
            height: screenHeight * 0.65,
            child: Stack(
              children: [
                Image.asset(
                  'assets/images/poke_center/trade.png',
                  fit: BoxFit.contain,
                ),
                Positioned(
                  left: screenWidth * 0.18,
                  top: screenHeight * 0.07,
                  width: screenWidth * 0.22,
                  height: screenHeight * 0.24,
                  child: Container(
                    key: const Key('partner-slot'),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.transparent),
                    ),
                  ),
                ),
                Positioned(
                  left: screenWidth * 0.61,
                  top: screenHeight * 0.07,
                  width: screenWidth * 0.22,
                  height: screenHeight * 0.24,
                  child: Container(
                    key: const Key('player-slot'),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.transparent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: screenWidth * 0.06,
            right: screenWidth * 0.06,
            bottom: screenHeight * 0.208 + 10,
            child: FilledButton.icon(
              key: const Key('search-trainers-button'),
              onPressed: widget.incomingRequest == null && !_sending && !_sent
                  ? _searchTrainer
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5D36D),
                disabledBackgroundColor: const Color(0xFFE5D36D),
                disabledForegroundColor: const Color(0xFF30275C),
                foregroundColor: const Color(0xFF30275C),
                minimumSize: const Size(0, 48),
              ),
              icon: const Icon(Icons.person_search),
              label: Text(
                widget.incomingRequest != null
                    ? '${widget.incomingRequest!.trainerName} ofrece a ${widget.incomingRequest!.pokemonName}'
                    : _selectedTrainer == null
                    ? 'Buscar entrenador'
                    : 'Entrenador: ${_selectedTrainer!.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: screenHeight * 0.07,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.white)),
                FilledButton(
                  onPressed:
                      _sending ||
                          _sent ||
                          _selectedTrainer == null ||
                          widget.selectedPokemonIds.length != 1
                      ? null
                      : _send,
                  child: Text(
                    _sending
                        ? 'Enviando…'
                        : _sent
                        ? 'Invitación enviada'
                        : 'Enviar invitación',
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: screenWidth * 0.022,
            top: screenHeight * 0.792,
            width: screenWidth * 0.96,
            height: screenHeight * 0.119,
            child: ResponsivePanel(
              height: screenHeight * 0.119,
              padding: EdgeInsets.zero,
              borderWidth: screenWidth * 0.015,
              borderRadius: BorderRadius.circular(screenWidth * 0.053),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.036),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/poke_center/characters/npc1.png',
                      width: screenWidth * 0.179,
                      height: screenHeight * 0.076,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              CenterApi.instance.userName ?? 'Entrenador',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.008),
                            // Poké Balls correspondientes a los ejemplares seleccionados.
                            Semantics(
                              label:
                                  '${widget.selectedPokemonIds.length} Poké Balls seleccionadas',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  widget.selectedPokemonIds.length,
                                  (index) => Container(
                                    key: ValueKey(
                                      'trade-pokemon-${widget.selectedPokemonIds[index]}',
                                    ),
                                    width: screenWidth * 0.085,
                                    height: screenWidth * 0.095,
                                    margin: EdgeInsets.only(
                                      right:
                                          index <
                                              widget.selectedPokemonIds.length -
                                                  1
                                          ? screenWidth * 0.018
                                          : 0,
                                    ),
                                    child: Semantics(
                                      label:
                                          'Ejemplar Pokémon ${widget.selectedPokemonIds[index]}',
                                      child: const CustomPaint(
                                        painter: PokeballPainter(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
