import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokeclase20263/screens/dashboard_screen.dart';
import 'package:pokeclase20263/screens/minijuego_screen.dart';
import 'package:pokeclase20263/screens/pokemon_center_screen.dart';
import 'package:pokeclase20263/widgets/menu_button.dart';

void main() {
  testWidgets('Dashboard opens Poke Center and Inicio returns to dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.tap(find.text('Poke Center'));
    await tester.pumpAndSettle();
    expect(find.byType(PokemonCenterScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(MenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('INICIO'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(PokemonCenterScreen), findsNothing);
  });

  testWidgets('Minijuegos opens the actual Pokemon Center screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MinijuegoScreen()));
    await tester.scrollUntilVisible(find.text('Centro Pokemon'), 250);
    await tester.tap(find.text('Centro Pokemon'));
    await tester.pumpAndSettle();
    expect(find.byType(PokemonCenterScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
