import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gamelib/main.dart';

void main() {
  testWidgets('App startet ohne Absturz', (WidgetTester tester) async {
    await tester.pumpWidget(const GameLibApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
