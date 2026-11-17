import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokeclase20263/screens/healing_machine_screen.dart';
import 'package:pokeclase20263/services/center_api.dart';

void main() {
  testWidgets('Curar envía PATCH únicamente para los Pokémon colocados', (
    tester,
  ) async {
    final patches = <String>[];
    final api = CenterApi(
      client: MockClient((request) async {
        expect(request.url.origin, 'https://backpokemon.runasp.net');
        expect(request.headers['Authorization'], 'Bearer test-token');
        if (request.method == 'GET') {
          expect(request.url.path, '/api/me/pokemon');
          return http.Response(
            '[{"id":12,"idPokemon":25,"vidaActual":10,"vidaTotal":35,"estado":"Sano"},{"id":38,"idPokemon":19,"vidaActual":30,"vidaTotal":30,"estado":"Quemado"},{"id":51,"vidaActual":40,"vidaTotal":40,"estado":"Sano"},{"id":52},{"id":53,"vidaActual":0,"vidaTotal":40,"estado":"Sano","crianza":{"vivo":false}}]',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(request.method, 'PATCH');
        expect(request.body, isEmpty);
        patches.add(request.url.path);
        return http.Response('', 204);
      }),
    )..token = 'test-token';

    await tester.pumpWidget(MaterialApp(home: HealingMachineScreen(api: api)));
    await tester.pumpAndSettle();
    IconButton button() =>
        tester.widget(find.byKey(const Key('healing-machine-button')));
    expect(button().onPressed, isNull);

    expect(find.byKey(const ValueKey('healing-pokemon-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('healing-pokemon-38')), findsOneWidget);
    for (final id in [51, 52, 53]) {
      expect(find.byKey(ValueKey('healing-pokemon-$id')), findsNothing);
    }
    expect(find.byKey(const ValueKey('healing-sprite-12')), findsOneWidget);
    final draggable = tester.widget<LongPressDraggable<int>>(
      find.byKey(const ValueKey('healing-pokemon-12')),
    );
    final feedback = draggable.feedback as SizedBox;
    expect((feedback.child as Semantics).child, isA<CustomPaint>());

    for (final (slot, id) in [(0, 12), (1, 38)]) {
      final target = tester.widget<DragTarget<int>>(
        find.byKey(ValueKey('healing-slot-$slot')),
      );
      target.onAcceptWithDetails!(
        DragTargetDetails(data: id, offset: Offset.zero),
      );
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('healing-machine-button')));
    await tester.pumpAndSettle();
    expect(patches, ['/api/me/pokemon/12/heal', '/api/me/pokemon/38/heal']);
    expect(find.text('Pokémon curados: 2 de 2'), findsOneWidget);
    expect(button().onPressed, isNull);
  });
}
