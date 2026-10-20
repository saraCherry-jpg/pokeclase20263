import 'package:flutter/material.dart';
import 'package:pokeclase20263/services/center_api.dart';
import 'package:pokeclase20263/widgets/menu_button.dart';

class BackendCenterScreen extends StatefulWidget {
  final bool trades;
  final CenterApi? api;
  const BackendCenterScreen({super.key, required this.trades, this.api});
  @override
  State<BackendCenterScreen> createState() => _BackendCenterScreenState();
}

class _BackendCenterScreenState extends State<BackendCenterScreen> {
  late final api = widget.api ?? CenterApi.instance;
  final search = TextEditingController();
  List<Map<String, dynamic>> pokemon = [], trades = [], users = [];
  int? selectedPokemon;
  String? selectedUser;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (api.token != null) _run(_refresh);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final collection = await api.pokemon(availableOnly: widget.trades);
    if (!mounted) return;
    setState(() {
      pokemon = collection;
      if (!pokemon.any((p) => p['id'] == selectedPokemon)) {
        selectedPokemon = null;
      }
    });
    if (widget.trades) {
      final history = await api.trades();
      if (mounted) setState(() => trades = history);
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
    int? choice;
    if (action == 'accept') {
      final available = await api.pokemon(availableOnly: true);
      if (!mounted) return;
      choice = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Elige tu Pokémon'),
          children: [
            if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No tienes Pokémon disponibles.'),
              ),
            for (final p in available)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, p['id']),
                child: Text(
                  '${p['nombre'] ?? 'Pokémon'} · ejemplar #${p['id']}',
                ),
              ),
          ],
        ),
      );
      if (choice == null) return;
    }
    await api.action(trade['id'] as int, action, pokemonId: choice);
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
    onTap: widget.trades && !busy
        ? () => setState(() => selectedPokemon = p['id'] as int)
        : null,
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
              if (accepted && sent)
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => _run(() => _tradeAction(t, 'confirm')),
                  child: const Text('Confirmar'),
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
      title: Text(widget.trades ? 'Intercambios' : 'Curar Pokémon'),
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
                  const Text(
                    'La máquina cura todos tus Pokémon con estado registrado. No revive mascotas muertas.',
                  ),
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _run(() async {
                            final count = await api.heal();
                            _message('Pokémon actualizados: $count');
                            await _refresh();
                          }),
                    icon: const Icon(Icons.healing),
                    label: const Text('Curar todos'),
                  ),
                ] else ...[
                  const Text('Elige un Pokémon disponible para ofrecer.'),
                ],
                if (pokemon.isEmpty && !busy)
                  const Text('No hay Pokémon para mostrar.'),
                for (final p in pokemon) _pokemon(p),
                if (widget.trades) ...[
                  TextField(
                    controller: search,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Buscar entrenador (mínimo 2 caracteres)',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _run(() async {
                            final query = search.text.trim();
                            if (query.length < 2 || query.length > 100) {
                              throw const ApiException(
                                400,
                                'Escribe entre 2 y 100 caracteres.',
                              );
                            }
                            final result = await api.users(query);
                            if (mounted) {
                              setState(() {
                                users = result;
                                selectedUser = null;
                              });
                            }
                            if (result.isEmpty) {
                              _message('No se encontraron entrenadores.');
                            }
                          }),
                    child: const Text('Buscar'),
                  ),
                  for (final u in users)
                    ListTile(
                      title: Text(u['userName'] as String),
                      trailing: Icon(
                        selectedUser == u['id']
                            ? Icons.check_circle
                            : Icons.person_outline,
                      ),
                      onTap: busy
                          ? null
                          : () => setState(
                              () => selectedUser = u['id'] as String,
                            ),
                    ),
                  FilledButton(
                    onPressed:
                        busy || selectedUser == null || selectedPokemon == null
                        ? null
                        : () => _run(() async {
                            await api.create(selectedUser!, selectedPokemon!);
                            if (mounted) setState(() => selectedPokemon = null);
                            _message('Invitación enviada.');
                            await _refresh();
                          }),
                    child: const Text('Enviar invitación'),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Enviadas y recibidas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Actualiza para consultar respuestas y cambios de estado.',
                  ),
                  if (trades.isEmpty && !busy)
                    const Text('No tienes intercambios.'),
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
