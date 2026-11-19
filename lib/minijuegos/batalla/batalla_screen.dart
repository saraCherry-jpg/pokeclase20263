/*
Minijuego de Batalla.

- batallaProviders(): los providers de batallas. Se agregan al MultiProvider de main.dart.
- BatallaScreen: la entrada desde el menú de Minijuegos.

Usa el backend del equipo en https://backpokemon.runasp.net (config/backend_config.dart).
Con el backend real primero se inicia sesión (token + Id del usuario).
*/

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'config/backend_config.dart';
import 'providers/poke_api_provider.dart';
import 'screens/battle/select_pokemon_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/battle_backend.dart';
import 'theme/battle_theme.dart';

// realBackend = false usa los datos falsos de MockBattleBackend (lo usan las pruebas)
List<SingleChildWidget> batallaProviders({bool realBackend = useRealBackend}) => [
      ChangeNotifierProvider(create: (_) => PokeApiProvider()),
      Provider<BattleBackend>(
        create: (_) => realBackend ? ApiBattleBackend(baseUrl: backendBaseUrl) : MockBattleBackend(),
      ),
      // Estilo visual de las batallas (GBA o Moderno). Se cambia desde Mis Pokémon.
      ChangeNotifierProvider(create: (_) => BattleStyleProvider()),
    ];

class BatallaScreen extends StatelessWidget {
  final bool realBackend;

  const BatallaScreen({super.key, this.realBackend = useRealBackend});

  @override
  Widget build(BuildContext context) => realBackend
      ? LoginScreen(auth: AuthService(baseUrl: backendBaseUrl))
      : const SelectPokemonScreen(userId: currentUserId);
}
