import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pokeclase20263/services/center_api.dart';

class TradeTrainer {
  final String id;
  final String name;

  const TradeTrainer({required this.id, required this.name});
}

class TrainerSearchDialog extends StatefulWidget {
  final String? selectedTrainerId;
  final CenterApi? api;

  const TrainerSearchDialog({super.key, this.selectedTrainerId, this.api});

  @override
  State<TrainerSearchDialog> createState() => _TrainerSearchDialogState();
}

class _TrainerSearchDialogState extends State<TrainerSearchDialog> {
  final _searchController = TextEditingController();
  String _query = '';
  List<TradeTrainer> _trainers = [];
  String? _error;
  bool _loading = false;
  Timer? _debounce;
  int _revision = 0;

  void _search(String value) {
    _debounce?.cancel();
    final revision = ++_revision;
    setState(() {
      _query = value;
      _trainers = [];
      _error = null;
      _loading = false;
    });
    final query = value.trim();
    if (query.length < 2 || query.length > 100) return;
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final users = await (widget.api ?? CenterApi.instance).users(query);
        if (!mounted || revision != _revision) return;
        setState(() {
          _trainers = users
              .map(
                (u) => TradeTrainer(
                  id: u['id'] as String,
                  name: u['userName'] as String,
                ),
              )
              .toList();
          _loading = false;
        });
      } catch (e) {
        if (mounted && revision == _revision) {
          setState(() {
            _error = e.toString();
            _loading = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trainers = _trainers;

    return Dialog(
      key: const Key('trainer-search-dialog'),
      backgroundColor: const Color(0xFF5345AB),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE5D36D), width: 3),
      ),
      child: SizedBox(
        width: 440,
        height: 500,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Buscar entrenador',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar buscador',
                    color: Colors.white,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Text(
                'Elige con quién intercambiar.',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('trainer-search-field'),
                controller: _searchController,
                onChanged: _search,
                style: const TextStyle(color: Color(0xFF30275C)),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre',
                  filled: true,
                  fillColor: const Color(0xFFF4F1E9),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _search('');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    : trainers.isEmpty
                    ? Center(
                        child: Text(
                          _query.trim().length < 2
                              ? 'Escribe al menos 2 caracteres.'
                              : 'No se encontraron entrenadores.\nPrueba con otro nombre.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: trainers.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1, color: Colors.white24),
                        itemBuilder: (context, index) {
                          final trainer = trainers[index];
                          final selected =
                              trainer.id == widget.selectedTrainerId;
                          return ListTile(
                            key: ValueKey('trainer-${trainer.id}'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE5D36D),
                              foregroundColor: const Color(0xFF30275C),
                              child: Text(trainer.name[0]),
                            ),
                            title: Text(
                              trainer.name,
                              style: const TextStyle(color: Colors.black),
                            ),
                            subtitle: selected
                                ? const Text(
                                    'Seleccionado',
                                    style: TextStyle(color: Color(0xFFE5D36D)),
                                  )
                                : null,
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.chevron_right,
                              color: const Color(0xFFE5D36D),
                            ),
                            onTap: () => Navigator.pop(context, trainer),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
