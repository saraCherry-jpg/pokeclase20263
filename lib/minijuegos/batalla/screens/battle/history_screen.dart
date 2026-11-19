import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/battle_result.dart';
import '../../services/battle_backend.dart';
import '../../utils/type_colors.dart';
import '../../widgets/battle_ui.dart';

// Historial de batallas del usuario (tabla Batallas) con el resumen de victorias, derrotas y huidas.
class HistoryScreen extends StatefulWidget {
  final String userId;

  const HistoryScreen({super.key, required this.userId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Historial (cada batalla ya trae el nombre de tu Pokémon) + resumen del backend
  late final Future<(List<BattleResult>, BattleSummary)> _future;

  @override
  void initState() {
    super.initState();
    final backend = context.read<BattleBackend>();
    _future = () async {
      final battles = await backend.getMyBattles(widget.userId);
      BattleSummary summary;
      try {
        summary = await backend.getBattleSummary(widget.userId);
      } catch (_) {
        summary = BattleSummary.fromBattles(battles); // Si /resumen todavía no está
      }
      return (battles, summary);
    }();
  }

  static String _rivalSprite(int idPokemon) =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$idPokemon.png';

  static String _date(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BattleAppBar(title: 'Historial de batallas', gba: watchIsGba(context)),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final (battles, summary) = snapshot.data!;
          if (battles.isEmpty) {
            return const Center(child: Text('Todavía no tienes batallas.'));
          }

          final percent = summary.winRate == null ? '-' : '${(summary.winRate! * 100).round()}%';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(label: 'Victorias', value: '${summary.victorias}'),
                    _Stat(label: 'Derrotas', value: '${summary.derrotas}'),
                    _Stat(label: 'Huidas', value: '${summary.huidas}'),
                    _Stat(label: '% de victorias', value: percent),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: battles.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final b = battles[index];
                    final mine = capitalize(b.nombre ?? '???');
                    final (label, color) = switch (b.resultado) {
                      BattleResultado.victoria => ('Ganó', Colors.green[700]),
                      BattleResultado.derrota => ('Perdió', Colors.red[700]),
                      BattleResultado.huida => ('Huyó', Colors.grey[700]),
                    };
                    return ListTile(
                      leading: Image.network(
                        _rivalSprite(b.idPokemonRival),
                        width: 48,
                        height: 48,
                        errorBuilder: (_, _, _) => const Icon(Icons.catching_pokemon),
                      ),
                      title: Text('$mine vs. Pokémon #${b.idPokemonRival}'),
                      subtitle: Text(_date(b.fecha)),
                      trailing: Text(
                        label,
                        style: TextStyle(fontWeight: FontWeight.bold, color: color),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
