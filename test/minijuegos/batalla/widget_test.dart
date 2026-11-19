import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:pokeclase20263/minijuegos/batalla/batalla_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('la pantalla inicial lista los Pokémon del usuario', (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: batallaProviders(realBackend: false),
      child: const MaterialApp(home: BatallaScreen(realBackend: false)),
    ));
    expect(find.text('Mis Pokémon'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400)); // Espera al backend falso
    expect(find.text('Charizard'), findsOneWidget);
    expect(find.text('Debilitado'), findsOneWidget); // Bulbasaur no se puede elegir
    expect(find.text('0 / 6'), findsOneWidget);

    // Elegir a Charizard y Pikachu arma el equipo en ese orden
    await tester.tap(find.text('Charizard'));
    await tester.tap(find.text('Pikachu'));
    await tester.pump();
    expect(find.text('2 / 6'), findsOneWidget);
    expect(find.text('¡A la batalla!'), findsOneWidget);
    // Insignias de orden en las tarjetas (los lugares 1 y 2 ya muestran el sprite)
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Cambiar al estilo Moderno no pierde la selección
    await tester.tap(find.byTooltip('Cambiar a estilo Moderno'));
    await tester.pump();
    expect(find.byTooltip('Cambiar a estilo GBA'), findsOneWidget);
    expect(find.text('2 / 6'), findsOneWidget);
  });
}
