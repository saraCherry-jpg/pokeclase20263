import 'package:flutter/material.dart';
import 'package:pokeclase20263/models/trade_request.dart';
import 'package:pokeclase20263/widgets/pokeball_painter.dart';

class TradeRequestsDialog extends StatelessWidget {
  final List<TradeRequest> requests;

  const TradeRequestsDialog({super.key, required this.requests});

  @override
  Widget build(BuildContext context) {
    return _TradeDialog(
      title: 'Solicitudes de intercambio',
      child: requests.isEmpty
          ? const Center(
              child: Text(
                'No tienes solicitudes de intercambio.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              itemCount: requests.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final request = requests[index];
                return ListTile(
                  key: ValueKey('trade-request-${request.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Image.network(
                    request.spriteUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, error, stackTrace) => const SizedBox(
                      width: 56,
                      height: 56,
                      child: CustomPaint(painter: PokeballPainter()),
                    ),
                  ),
                  title: Text(
                    request.trainerName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Ofrece a ${request.pokemonName}',
                    style: const TextStyle(color: Color(0xFF30275C)),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, request),
                );
              },
            ),
    );
  }
}

class TradeResponseDialog extends StatefulWidget {
  final TradeRequest request;
  final List<int> pokemonIds;

  const TradeResponseDialog({
    super.key,
    required this.request,
    required this.pokemonIds,
  });

  @override
  State<TradeResponseDialog> createState() => _TradeResponseDialogState();
}

class _TradeResponseDialogState extends State<TradeResponseDialog> {
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    return _TradeDialog(
      title:
          'Elige un Pokémon para intercambiarlo por ${widget.request.pokemonName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Solicitud de ${widget.request.trainerName}',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: widget.pokemonIds.isEmpty
                ? const Center(child: Text('No tienes Pokémon disponibles.'))
                : GridView.builder(
                    itemCount: widget.pokemonIds.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 110,
                          mainAxisExtent: 100,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemBuilder: (context, index) {
                      final id = widget.pokemonIds[index];
                      final selected = _selectedId == id;
                      return Semantics(
                        selected: selected,
                        label: 'Pokémon provisional $id',
                        child: InkWell(
                          key: ValueKey('response-pokemon-$id'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(
                            () => _selectedId = selected ? null : id,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFE5D36D)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const SizedBox.expand(
                                        child: CustomPaint(
                                          painter: PokeballPainter(),
                                        ),
                                      ),
                                      if (selected)
                                        const Align(
                                          alignment: Alignment.topRight,
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
                                  '#$id',
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_selectedId == null ? 0 : 1} / 1 seleccionado',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('continue-request-trade'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5345AB),
              foregroundColor: Colors.white,
            ),
            onPressed: _selectedId == null
                ? null
                : () => Navigator.pop(context, _selectedId),
            child: const Text('Llevar a la máquina'),
          ),
        ],
      ),
    );
  }
}

class _TradeDialog extends StatelessWidget {
  final String title;
  final Widget child;

  const _TradeDialog({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF4F1E9),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF5345AB), width: 3),
      ),
      child: SizedBox(
        width: 440,
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar solicitudes',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
