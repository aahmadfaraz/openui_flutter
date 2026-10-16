import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/example.dart';

void main() {
  testWidgets('the README example renders and submits its choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(body: AnswerView(answer)),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Weekend in Lisbon'), findsOneWidget);
    await tester.tap(find.text('Views'));
    await tester.pump();
    await tester.tap(find.text('Plan my weekend'));
    await tester.pump();
    expect(
      find.text(
        'Plan my Lisbon weekend\n\nMy choices: pace: relaxed; interests: views.',
      ),
      findsOneWidget,
    );
  });
}
