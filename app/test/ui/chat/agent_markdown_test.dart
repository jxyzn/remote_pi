// Plan/32b — AgentMarkdown renders fenced code with a copy button.

import 'package:app/ui/chat/widgets/agent_markdown.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, String md) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AgentMarkdown(md))),
    );
  }

  testWidgets('fenced code block shows a copy button', (tester) async {
    await pump(tester, '```dart\nfinal x = 1;\n```');
    await tester.pump();
    expect(find.byKey(const Key('code-copy')), findsOneWidget);
    expect(find.textContaining('final x = 1;'), findsOneWidget);
  });

  testWidgets('tapping copy puts the code on the clipboard', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pump(tester, '```\nhello code\n```');
    await tester.pump();
    await tester.tap(find.byKey(const Key('code-copy')));
    await tester.pump();

    expect(calls, isNotEmpty, reason: 'Clipboard.setData was invoked');
    final text = (calls.first.arguments as Map)['text'] as String;
    expect(text, contains('hello code'));
  });

  testWidgets('plain prose renders without a code block', (tester) async {
    await pump(tester, 'just a normal sentence.');
    await tester.pump();
    expect(find.byKey(const Key('code-copy')), findsNothing);
  });

  testWidgets(
    'markdown table constrains to available width and wraps long cell text',
    (tester) async {
      const md = '''
| Feature | Detailed Description |
| --- | --- |
| Collapsible Sidebar | Allows the session picker on the left side of the foldable inner screen to collapse so the chat transcript uses the full display width. |
| Wrapping Tables | Long sentences and paragraphs inside markdown table cells automatically word-wrap to fit within the chat window without horizontal scrolling. |
''';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              child: AgentMarkdown(md),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Table), findsOneWidget);
      final tableSize = tester.getSize(find.byType(Table));
      expect(
        tableSize.width,
        lessThanOrEqualTo(340),
        reason: 'Table must fit inside the 340px container and wrap cells',
      );
    },
  );

  testWidgets(
    'markdown table with 5+ columns falls back to horizontal scroll on narrow width',
    (tester) async {
      const md = '''
| C1 | C2 | C3 | C4 | C5 |
| --- | --- | --- | --- | --- |
| A | B | C | D | E |
''';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: AgentMarkdown(md),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Table), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final tableSize = tester.getSize(find.byType(Table));
      expect(tableSize.width, greaterThan(240));
    },
  );

  testWidgets('headline text in dark mode renders with readable color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkTheme(),
        home: const Scaffold(
          body: AgentMarkdown('## Suggested additions for your config/tasks'),
        ),
      ),
    );
    await tester.pump();

    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    final headingWidget = textWidgets.firstWhere(
      (w) => w.textSpan?.toPlainText().contains('Suggested additions') ?? false,
    );
    final span = headingWidget.textSpan! as TextSpan;
    final childSpan = span.children!.firstWhere(
      (c) => c.toPlainText().contains('Suggested additions'),
    ) as TextSpan;

    expect(childSpan.style?.color, equals(AppColors.dark.text));
    expect(childSpan.style?.color, isNot(equals(const Color(0xFF1D1B20))));
    expect(childSpan.style?.fontWeight, equals(FontWeight.w700));
  });

  testWidgets('headline text in light mode renders with readable color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: AgentMarkdown('# Main Title\n## Section Header\n### Subsection'),
        ),
      ),
    );
    await tester.pump();

    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    for (final title in ['Main Title', 'Section Header', 'Subsection']) {
      final widget = textWidgets.firstWhere(
        (w) => w.textSpan?.toPlainText().contains(title) ?? false,
      );
      final span = widget.textSpan! as TextSpan;
      final childSpan = span.children!.firstWhere(
        (c) => c.toPlainText().contains(title),
      ) as TextSpan;

      expect(childSpan.style?.color, equals(AppColors.light.text));
      expect(childSpan.style?.fontWeight, equals(FontWeight.w700));
    }
  });
}
