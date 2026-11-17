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
  final Map<String, dynamic>? incomingTrade;
  final CenterApi? api;
  final Map<String, dynamic>? outgoingTrade;
  final Map<int, String> selectedPokemonNames;

  const PokemonTradeScreen({
    super.key,
    this.selectedPokemonIds = const [],
    this.incomingRequest,
    this.incomingTrade,
    this.api,
    this.outgoingTrade,
    this.selectedPokemonNames = const {},
  });

  @override
  State<PokemonTradeScreen> createState() => _PokemonTradeScreenState();
}

class _PokemonTradeScreenState extends State<PokemonTradeScreen> {
  TradeTrainer? _selectedTrainer;
  int? _createdTradeId;
  bool _confirmed = false;
  CenterApi get _api => widget.api ?? CenterApi.instance;
  bool get _accepting => widget.incomingTrade != null;
  bool _sending = false;
  bool _sent = false;
  bool _inMachine = false;
  String? _error;
  Map<String, dynamic>? _outgoingDetail;

  @override
  void initState() {
    super.initState();
    final trade = widget.outgoingTrade;
    if (trade != null) {
      _createdTradeId = trade['id'] as int;
      _outgoingDetail = trade;
      _sent = true;
      _inMachine = true;
      _confirmed = trade['status'] == 'confirmed';
      _selectedTrainer = TradeTrainer(
        id: trade['recipient']['id'] as String,
        name: trade['recipient']['userName'] as String,
      );
    }
  }

  Future<void> _send() async {
    if (_sending ||
        !_inMachine ||
        _sent ||
        (!_accepting && _selectedTrainer == null) ||
        widget.selectedPokemonIds.length != 1) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (_accepting) {
        final id = widget.incomingTrade!['id'] as int;
        final detail = await _api.detail(id);
        if (detail['status'] != 'pending' || detail['role'] != 'received') {
          throw const ApiException(
            409,
            'La invitación cambió. Actualiza la cartita.',
          );
        }
        await _api.action(
          id,
          'accept',
          pokemonId: widget.selectedPokemonIds.single,
        );
      } else {
        final created = await _api.create(
          _selectedTrainer!.id,
          widget.selectedPokemonIds.single,
        );
        _createdTradeId = created['id'] as int;
        _outgoingDetail = Map<String, dynamic>.from(created);
      }
      if (!mounted) return;
      setState(() => _sent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _accepting
                ? 'Invitación aceptada. El creador debe confirmar.'
                : 'Invitación enviada. El destinatario debe aceptarla.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmSentTrade() async {
    if (_sending || _createdTradeId == null || _confirmed) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final detail = await _api.detail(_createdTradeId!);
      if (!mounted) return;
      if (detail['role'] != 'sent') {
        throw const ApiException(403, 'Solo el creador puede confirmar.');
      }
      setState(() => _outgoingDetail = Map<String, dynamic>.from(detail));
      if (detail['status'] == 'confirmed') {
        setState(() => _confirmed = true);
      } else if (detail['status'] == 'accepted') {
        final result = await _api.action(_createdTradeId!, 'confirm');
        if (result['status'] != 'confirmed') {
          throw const ApiException(
            409,
            'No se pudo confirmar. Actualiza el intercambio.',
          );
        }
        if (mounted) setState(() => _confirmed = true);
      } else {
        setState(
          () => _error = detail['status'] == 'pending'
              ? 'El destinatario todavía no acepta. Vuelve a consultar.'
              : 'Estado del intercambio: ${detail['status']}',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _searchTrainer() async {
    final trainer = await showDialog<TradeTrainer>(
      context: context,
      builder: (_) => TrainerSearchDialog(
        selectedTrainerId: _selectedTrainer?.id,
        api: widget.api,
      ),
    );
    if (!mounted || trainer == null) return;
    setState(() => _selectedTrainer = trainer);
  }

  String get _offeredName {
    if (_accepting) {
      return widget.selectedPokemonNames[widget.selectedPokemonIds.single] ??
          'Pokémon #${widget.selectedPokemonIds.single}';
    }
    return _outgoingDetail?['offeredPokemon']?['nombre'] as String? ??
        (widget.selectedPokemonIds.isEmpty
            ? 'Tu Pokémon'
            : widget.selectedPokemonNames[widget.selectedPokemonIds.single] ??
                  'Pokémon #${widget.selectedPokemonIds.single}');
  }

  String? get _receivedName => _accepting
      ? widget.incomingTrade!['offeredPokemon']['nombre'] as String? ??
            'Pokémon ofrecido'
      : _outgoingDetail?['recipientPokemon']?['nombre'] as String?;

  Widget _machineBall(
    String name,
    String direction, {
    bool removable = false,
  }) => Tooltip(
    message:
        '$direction: $name${removable ? '\nToca para devolver al panel' : ''}',
    child: InkWell(
      onTap: removable ? () => setState(() => _inMachine = false) : null,
      child: const CustomPaint(painter: PokeballPainter()),
    ),
  );

  Widget _tradeMachine() => Align(
    alignment: Alignment.topLeft,
    child: AspectRatio(
      aspectRatio: 1225 / 1284,
      child: LayoutBuilder(
        builder: (context, constraints) {
          Widget slot(double x, String key, Widget child) => Positioned(
            left: constraints.maxWidth * x / 1225,
            top: constraints.maxHeight * 520 / 1284,
            width: constraints.maxWidth * 150 / 1225,
            height: constraints.maxHeight * 125 / 1284,
            child: KeyedSubtree(key: ValueKey(key), child: child),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/poke_center/trade.png',
                fit: BoxFit.contain,
              ),
              slot(
                100,
                'offered-position',
                DragTarget<int>(
                  key: const Key('player-slot'),
                  onWillAcceptWithDetails: (details) =>
                      !_sending &&
                      !_sent &&
                      !_inMachine &&
                      widget.selectedPokemonIds.length == 1 &&
                      widget.selectedPokemonIds.single == details.data,
                  onAcceptWithDetails: (_) => setState(() => _inMachine = true),
                  builder: (context, candidates, rejected) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: candidates.isNotEmpty
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _inMachine
                        ? _machineBall(
                            _offeredName,
                            'Entregas',
                            removable: !_sending && !_sent,
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              ),
              slot(
                960,
                'partner-slot',
                _receivedName == null
                    ? const SizedBox.expand()
                    : _machineBall(_receivedName!, 'Recibes'),
              ),
            ],
          );
        },
      ),
    ),
  );

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
            child: _tradeMachine(),
          ),
          Positioned(
            left: screenWidth * 0.06,
            right: screenWidth * 0.06,
            bottom: screenHeight * 0.208 + 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.white)),
                if (!_sent || _accepting)
                  FilledButton(
                    key: const Key('send-trade-button'),
                    onPressed:
                        _sending ||
                            _sent ||
                            !_inMachine ||
                            (!_accepting && _selectedTrainer == null) ||
                            widget.selectedPokemonIds.length != 1
                        ? null
                        : _send,
                    child: Text(
                      _sending
                          ? 'Enviando…'
                          : _sent
                          ? (_accepting
                                ? 'Invitación aceptada'
                                : 'Invitación enviada')
                          : (_accepting
                                ? 'Aceptar intercambio'
                                : 'Intercambiar'),
                    ),
                  ),
                if (_sent && !_accepting && !_confirmed)
                  FilledButton(
                    onPressed: _sending ? null : _confirmSentTrade,
                    child: const Text('Confirmar intercambio'),
                  ),
                if (_confirmed)
                  const Text(
                    'Intercambio confirmado.',
                    style: TextStyle(color: Colors.white),
                  ),
                if (widget.outgoingTrade != null)
                  TextButton(
                    onPressed: _sending ? null : () => Navigator.pop(context),
                    child: const Text('Volver a enviados'),
                  ),
                if (_sent && _accepting)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver a invitaciones'),
                  ),
                if (!_inMachine && !_sent)
                  const Text(
                    'Arrastra tu Poké Ball a la máquina para intercambiar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('search-trainers-button'),
                  onPressed:
                      !_accepting &&
                          widget.incomingRequest == null &&
                          !_sending &&
                          !_sent
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
                    _accepting
                        ? "Entrenador: ${widget.incomingTrade!['creator']['userName']} · ofrece ${widget.incomingTrade!['offeredPokemon']['nombre'] ?? 'Pokémon'}"
                        : widget.incomingRequest != null
                        ? '${widget.incomingRequest!.trainerName} ofrece a ${widget.incomingRequest!.pokemonName}'
                        : _selectedTrainer == null
                        ? 'Buscar entrenador'
                        : 'Entrenador: ${_selectedTrainer!.name}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                              _api.userName ?? 'Entrenador',
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
                                  _inMachine
                                      ? 0
                                      : widget.selectedPokemonIds.length,
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
                                    child: Draggable<int>(
                                      key: ValueKey(
                                        'trade-ball-${widget.selectedPokemonIds[index]}',
                                      ),
                                      data: widget.selectedPokemonIds[index],
                                      maxSimultaneousDrags: _sending || _sent
                                          ? 0
                                          : 1,
                                      feedback: const SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: CustomPaint(
                                          painter: PokeballPainter(),
                                        ),
                                      ),
                                      childWhenDragging:
                                          const SizedBox.shrink(),
                                      child: Semantics(
                                        label:
                                            'Arrastrar Pokémon ${widget.selectedPokemonIds[index]} a la máquina',
                                        child: const CustomPaint(
                                          painter: PokeballPainter(),
                                        ),
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
