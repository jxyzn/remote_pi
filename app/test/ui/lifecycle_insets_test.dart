import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unfocuses primary focus when app enters inactive or paused state', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextField(
            key: const Key('test-field'),
            focusNode: focusNode,
          ),
        ),
      ),
    ));

    // Tap text field to gain focus
    await tester.tap(find.byKey(const Key('test-field')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    // Simulate moving to app switcher / background
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
  });
}
