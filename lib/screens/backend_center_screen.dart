import 'package:flutter/material.dart';
import 'package:pokeclase20263/screens/pokemon_trade_screen.dart';
import 'package:pokeclase20263/screens/pokemon_selection_screen.dart';
import 'package:pokeclase20263/services/center_api.dart';
import 'package:pokeclase20263/widgets/menu_button.dart';

class BackendCenterScreen extends StatefulWidget {
  final bool trades;
  final bool sentOnly;
  final CenterApi? api;
  const BackendCenterScreen({
    super.key,
    required this.trades,
    this.api,
    this.sentOnly = false,
  });
  @override
  State<BackendCenterScreen> createState() => _BackendCenterScreenState();
}

class _BackendCenterScreenState extends State<BackendCenterScreen> {
  late final api = widget.api ?? CenterApi.instance;
  List<Map<String, dynamic>> pokemon = [], trades = [];
  int? selectedPokemon;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (api.token != null) _run(_refresh);
  }

  Future<void> _refresh() async {
    if (widget.trades) {
      final history = await api.trades();
      if (mounted) {
        setState(
          () => trades = history
              .where(
                (t) => t['role'] == (widget.sentOnly ? 'sent' : 'received'),
              )
              .toList(),
        );
      }
    } else {
      final collection = await api.pokemon();
      if (mounted) setState(() => pokemon = collection);
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _tradeAction(Map<String, dynamic> trade, String action) async {
    final detail = await api.detail(trade['id'] as int);
    if (!mounted) return;
    if (detail['status'] != trade['status']) {
      await _refresh();
      throw const ApiException(
        409,
        'El intercambio cambió. Revisa su estado actualizado.',
      );
    }
    if (action == 'accept') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PokemonSelectionScreen(
            incomingTrade: Map<String, dynamic>.from(detail),
            api: api,
          ),
        ),
      );
      if (mounted) await _refresh();
      return;
    }
    await api.action(trade['id'] as int, action);
    _message(
      action == 'accept'
          ? 'Aceptado. El creador debe confirmar.'
          : action == 'confirm'
          ? 'Intercambio confirmado.'
          : 'Solicitud finalizada.',
    );
    await _refresh();
  }

  Widget _pokemon(Map<String, dynamic> p) => ListTile(
    leading: Image.network(
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${p['idPokemon']}.png',
      width: 48,
      errorBuilder: (_, error, stack) => const Icon(Icons.catching_pokemon),
    ),
    title: Text('${p['nombre'] ?? 'Pokémon'} · #${p['id']}'),
    subtitle: Text(
      'Vida: ${p['vidaActual'] ?? '—'}/${p['vidaTotal'] ?? '—'} · ${p['estado'] ?? 'Sin estado'}${p['reserved'] == true ? ' · Reservado' : ''}',
    ),
    selected: selectedPokemon == p['id'],
    trailing: widget.trades
        ? Icon(
            selectedPokemon == p['id']
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
          )
        : null,
    onTap: busy
        ? null
        : widget.trades
        ? () => setState(() => selectedPokemon = p['id'] as int)
        : () => _run(() async {
            await api.heal(p['id'] as int);
            _message('Pokémon curado');
            await _refresh();
          }),
  );

  Widget _trade(Map<String, dynamic> t) {
    final sent = t['role'] == 'sent';
    final pending = t['status'] == 'pending';
    final accepted = t['status'] == 'accepted';
    final partner = t[sent ? 'recipient' : 'creator'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${t['id']} · ${sent ? 'Enviada a' : 'Recibida de'} ${partner['userName']} · ${t['status']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${t['offeredPokemon']['nombre'] ?? 'Pokémon'} ↔ ${t['recipientPokemon']?['nombre'] ?? 'Por elegir'}',
          ),
          if (accepted)
            Text(
              sent
                  ? 'El destinatario aceptó. Falta tu confirmación.'
                  : 'Aceptaste. Esperando confirmación del creador.',
            ),
          Wrap(
            spacing: 8,
            children: [
              if (pending && !sent)
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => _run(() => _tradeAction(t, 'accept')),
                  child: const Text('Aceptar'),
                ),
              if (sent && (pending || accepted))
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => _run(() async {
                          final detail = await api.detail(t['id'] as int);
                          if (!mounted) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PokemonTradeScreen(
                                outgoingTrade: Map<String, dynamic>.from(
                                  detail,
                                ),
                                selectedPokemonIds: [
                                  detail['offeredPokemon']['id'] as int,
                                ],
                                api: api,
                              ),
                            ),
                          );
                          if (mounted) await _refresh();
                        }),
                  child: Text(
                    accepted
                        ? 'Revisar y confirmar en máquina'
                        : 'Ver en máquina',
                  ),
                ),
              if (pending || accepted)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => _run(() => _tradeAction(t, 'cancel')),
                  child: Text(pending && !sent ? 'Rechazar' : 'Cancelar'),
                ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.trades
            ? (widget.sentOnly
                  ? 'Intercambios enviados'
                  : 'Invitaciones recibidas')
            : 'Curar Pokémon',
      ),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: busy || api.token == null ? null : () => _run(_refresh),
          icon: const Icon(Icons.refresh),
        ),
        const MenuButton(),
      ],
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/poke_center/${widget.trades ? 'tradeF1.jpeg' : 'centerF2.jpeg'}',
          fit: BoxFit.cover,
        ),
        Container(
          color: const Color(0xEEB8BDD5),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Color(0xFF9A1818))),
                const SizedBox(height: 12),
              ],
              if (api.token == null)
                const Text(
                  'Sesión finalizada. Regresa a la entrada de la app.',
                ),
              if (api.token != null) ...[
                if (!widget.trades) ...[
                  const Text('Toca un Pokémon para curarlo.'),
                  if (pokemon.isEmpty && !busy)
                    const Text('No hay Pokémon para mostrar.'),
                  for (final p in pokemon) _pokemon(p),
                ] else ...[
                  Text(
                    widget.sentOnly
                        ? 'Intercambios enviados'
                        : 'Invitaciones recibidas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.sentOnly
                        ? 'Retoma un intercambio para consultar la respuesta y confirmar en la máquina.'
                        : 'Acepta una invitación para elegir tu Pokémon y llevarlo a la máquina.',
                  ),
                  if (trades.isEmpty && !busy)
                    Text(
                      widget.sentOnly
                          ? 'No tienes intercambios enviados.'
                          : 'No tienes invitaciones recibidas.',
                    ),
                  for (final t in trades) _trade(t),
                ],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
