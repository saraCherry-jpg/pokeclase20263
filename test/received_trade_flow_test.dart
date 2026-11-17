import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokeclase20263/screens/backend_center_screen.dart';
import 'package:pokeclase20263/screens/pokemon_selection_screen.dart';
import 'package:pokeclase20263/screens/pokemon_trade_screen.dart';
import 'package:pokeclase20263/services/center_api.dart';

void main() {
  testWidgets(
    'La cartita acepta desde el selector y máquina sin crear invitaciones',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final writes = <http.Request>[];
      final trade = {
        'id': 7,
        'role': 'received',
        'status': 'pending',
        'creator': {'id': 'other', 'userName': 'Otro'},
        'recipient': {'id': 'me', 'userName': 'Yo'},
        'offeredPokemon': {'id': 2, 'nombre': 'Pikachu'},
        'recipientPokemon': null,
      };
      final api = CenterApi(
        client: MockClient((r) async {
          Object data;
          if (r.method != 'GET') {
            writes.add(r);
            data = {...trade, 'status': 'accepted'};
          } else if (r.url.path == '/api/me/trades') {
            data = [
              trade,
              {...trade, 'id': 8, 'role': 'sent'},
            ];
          } else if (r.url.path == '/api/me/pokemon') {
            data = [
              {'id': 4, 'idPokemon': 19, 'nombre': 'Rattata'},
            ];
          } else {
            data = trade;
          }
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      )..token = 'test';
      await tester.pumpWidget(
        MaterialApp(home: BackendCenterScreen(trades: true, api: api)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Enviar invitación'), findsNothing);
      expect(find.textContaining('#8'), findsNothing);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(find.byType(PokemonSelectionScreen), findsOneWidget);
      expect(writes, isEmpty);
      await tester.tap(find.byKey(const ValueKey('pokemon-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('continue-to-trade')));
      await tester.pumpAndSettle();
      expect(find.byType(PokemonTradeScreen), findsOneWidget);
      FilledButton button() =>
          tester.widget(find.byKey(const Key('send-trade-button')));
      expect(button().onPressed, isNull);
      final target = tester.widget<DragTarget<int>>(
        find.byKey(const Key('player-slot')),
      );
      target.onAcceptWithDetails!(
        DragTargetDetails(data: 4, offset: Offset.zero),
      );
      await tester.pumpAndSettle();
      expect(button().onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('send-trade-button')));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(writes.single.url.path, '/api/trades/7/accept');
      expect(jsonDecode(writes.single.body), {'pokemonUserId': 4});
      expect(find.text('Invitación aceptada'), findsOneWidget);
      await tester.tap(find.text('Volver a invitaciones'));
      await tester.pumpAndSettle();
      expect(find.byType(BackendCenterScreen), findsOneWidget);
      expect(find.byType(PokemonSelectionScreen), findsNothing);
    },
  );
}
