import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pokeclase20263/minijuegos/batalla/providers/poke_api_provider.dart';
import 'package:pokeclase20263/minijuegos/batalla/screens/battle/battle_screen.dart';
import 'package:pokeclase20263/minijuegos/batalla/services/battle_backend.dart';

import 'helpers.dart';

void main() {
  testWidgets('el menú de batalla lleva a los movimientos y a la mochila', (tester) async {
    // Tamaño de un teléfono chico (360x780)
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final backend = MockBattleBackend();
    final team = await tester.runAsync(() => backend.getMyPokemon('usuario-demo'));

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<PokeApiProvider>(create: (_) => FakePokeApiProvider()),
        Provider<BattleBackend>.value(value: backend),
      ],
      child: MaterialApp(home: BattleScreen(team: [team![0], team[2]], userId: 'usuario-demo')),
    ));
    await tester.pump();
    await tester.pump();

    for (final label in ['Luchar', 'Mochila', 'Pokémon', 'Huir']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Luchar'));
    await tester.pump();
    expect(find.text('Placaje'), findsOneWidget);
    expect(find.text('Poder 40 · PP 35/35'), findsOneWidget);

    await tester.tap(find.text('Atrás'));
    await tester.pump();
    await tester.tap(find.text('Mochila'));
    await tester.pump();
    expect(find.text('Poción'), findsOneWidget);
    expect(find.text('x3'), findsOneWidget);
    expect(find.text('Poké Ball'), findsNothing);

    await tester.tap(find.text('Atrás'));
    await tester.pump();
    await tester.tap(find.text('Pokémon'));
    await tester.pump();
    expect(find.text('Pikachu'), findsOneWidget);
    expect(find.text('(en combate)'), findsOneWidget);
  });
}
