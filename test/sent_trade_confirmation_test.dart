import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokeclase20263/screens/backend_center_screen.dart';
import 'package:pokeclase20263/services/center_api.dart';

void main() {
  testWidgets('Creador retoma intercambio aceptado y confirma una sola vez', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var status = 'accepted';
    final writes = <http.Request>[];
    Map<String, dynamic> trade() => {
      'id': 1,
      'role': 'sent',
      'status': status,
      'creator': {'id': 'me', 'userName': 'intercambio'},
      'recipient': {'id': 'other', 'userName': 'intercambio2'},
      'offeredPokemon': {'id': 2, 'nombre': 'Pikachu'},
      'recipientPokemon': {'id': 4, 'nombre': 'Rattata'},
    };
    final api = CenterApi(
      client: MockClient((r) async {
        if (r.method != 'GET') {
          writes.add(r);
          expect(r.url.path, '/api/trades/1/confirm');
          expect(r.method, 'POST');
          expect(r.body, isEmpty);
          status = 'confirmed';
        }
        final Object data = r.url.path == '/api/me/trades'
            ? [
                trade(),
                {...trade(), 'id': 99, 'role': 'received'},
              ]
            : trade();
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    )..token = 'creator-token';
    await tester.pumpWidget(
      MaterialApp(
        home: BackendCenterScreen(trades: true, sentOnly: true, api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('#99'), findsNothing);
    await tester.tap(find.text('Revisar y confirmar en máquina'));
    await tester.pumpAndSettle();
    expect(find.text('Pikachu ↔ Rattata'), findsNothing);
    expect(find.byTooltip('Entregas: Pikachu'), findsOneWidget);
    expect(find.byTooltip('Recibes: Rattata'), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('player-slot'))).dx,
      lessThan(tester.getCenter(find.byKey(const Key('partner-slot'))).dx),
    );
    expect(writes, isEmpty);
    await tester.tap(find.text('Confirmar intercambio'));
    await tester.pumpAndSettle();
    expect(find.text('Intercambio confirmado.'), findsOneWidget);
    expect(writes, hasLength(1));
    expect(find.text('Confirmar intercambio'), findsNothing);
    await tester.tap(find.text('Volver a enviados'));
    await tester.pumpAndSettle();
    expect(find.textContaining('confirmed'), findsOneWidget);
    expect(writes, hasLength(1));
  });
}
