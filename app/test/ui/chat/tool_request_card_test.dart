import 'package:app/domain/session_state.dart';
import 'package:app/ui/chat/widgets/tool_request_card.dart';
import 'package:app/ui/core/themes/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

const _bashTool = ToolEvent(
  id: 'tc1',
  toolCallId: 'tc1',
  tool: 'Bash',
  args: {'command': 'ls -la'},
);

const _editToolWithHunk = ToolEvent(
  id: 'tc2',
  toolCallId: 'tc4',
  tool: 'edit',
  args: {
    'path': 'app/test/ui/chat/tool_request_card_test.dart',
    'hunks': [
      {
        'lines': [
          {'kind': 'context', 'oldLine': 16, 'newLine': 16, 'text': 'args: {'},
          {'kind': 'remove', 'oldLine': 17, 'text': "  tool: 'Edit',"},
          {'kind': 'add', 'newLine': 17, 'text': "  tool: 'edit',"},
          {'kind': 'context', 'oldLine': 18, 'newLine': 18, 'text': '},'},
        ],
      },
    ],
  },
);

void main() {
  group('ToolRequestCard (informational)', () {
    testWidgets('shows tool name and command', (tester) async {
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: _bashTool)));
      expect(find.text('BASH'), findsOneWidget);
      expect(find.text('ls -la'), findsOneWidget);
    });

    testWidgets('edit renders rich hunks with context lines', (tester) async {
      await tester.pumpWidget(
        _wrap(const ToolRequestCard(tool: _editToolWithHunk)),
      );

      expect(
        find.textContaining('   16 args: {', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining("-  17   tool: 'Edit',", findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining("+  17   tool: 'edit',", findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('   18 },', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('pending state shows RUNNING and no Allow/Deny buttons', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: _bashTool)));
      expect(find.text('RUNNING'), findsOneWidget);
      expect(find.text('Allow'), findsNothing);
      expect(find.text('Deny'), findsNothing);
      expect(find.textContaining('s'), findsAny); // no '60s' countdown
      expect(find.textContaining('60s'), findsNothing);
    });

    testWidgets('completed state shows DONE', (tester) async {
      const done = ToolEvent(
        id: 'tc1',
        toolCallId: 'tc1',
        tool: 'Bash',
        args: {'command': 'ls'},
        status: ToolEventStatus.completed,
      );
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: done)));
      expect(find.text('DONE'), findsOneWidget);
      expect(find.textContaining('Done'), findsAny);
    });

    testWidgets('denied state shows DENIED label', (tester) async {
      const denied = ToolEvent(
        id: 'tc1',
        toolCallId: 'tc1',
        tool: 'Bash',
        args: {'command': 'ls'},
        status: ToolEventStatus.denied,
        error: 'user denied',
      );
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: denied)));
      expect(find.text('DENIED'), findsOneWidget);
    });

    testWidgets('allowed state shows RUNNING (still in flight)', (
      tester,
    ) async {
      const allowed = ToolEvent(
        id: 'tc1',
        toolCallId: 'tc1',
        tool: 'Bash',
        args: {'command': 'ls'},
        status: ToolEventStatus.allowed,
      );
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: allowed)));
      expect(find.text('RUNNING'), findsOneWidget);
      expect(find.text('Allow'), findsNothing);
    });

    // Plan/32 — the card is colored by status: running blue, done green,
    // failed red. We assert the outcome line's color (the same _statusColor
    // drives the border / icon / tool name).
    Color? outcomeColor(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style?.color;

    testWidgets('completed → green "✓ Done"', (tester) async {
      const done = ToolEvent(
        id: 'tc1',
        toolCallId: 'tc1',
        tool: 'Bash',
        args: {'command': 'ls'},
        status: ToolEventStatus.completed,
      );
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: done)));
      expect(outcomeColor(tester, '✓ Done'), AppColors.dark.success);
    });

    testWidgets('failed → red "✗ {error}" + FAILED label', (tester) async {
      const failed = ToolEvent(
        id: 'tc1',
        toolCallId: 'tc1',
        tool: 'Bash',
        args: {'command': 'exit 1'},
        status: ToolEventStatus.failed,
        error: 'command failed: exit 1',
      );
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: failed)));
      expect(find.text('FAILED'), findsOneWidget);
      expect(
        outcomeColor(tester, '✗ command failed: exit 1'),
        AppColors.dark.error,
      );
    });

    testWidgets('running → blue "⏳ Running…"', (tester) async {
      // pending defaults
      await tester.pumpWidget(_wrap(const ToolRequestCard(tool: _bashTool)));
      expect(outcomeColor(tester, '⏳ Running…'), AppColors.dark.accent);
    });

    group('Verbosity levels', () {
      testWidgets(
        'terse mode: tool is initially collapsed into a single line; tap expands',
        (tester) async {
          await tester.pumpWidget(
            _wrap(
              const ToolRequestCard(
                tool: _bashTool,
                verbosity: SessionVerbosity.terse,
              ),
            ),
          );
          // Single-line collapsed row shows tool name and status
          expect(find.text('BASH'), findsOneWidget);
          expect(find.text('RUNNING'), findsOneWidget);
          // Code block ($ prompt) and full outcome are not visible
          expect(find.text(r'$ '), findsNothing);
          expect(find.text('⏳ Running…'), findsNothing);

          // Tap collapsed widget to expand
          await tester.tap(find.byType(ToolRequestCard));
          await tester.pump();

          expect(find.text(r'$ '), findsOneWidget);
          expect(find.text('⏳ Running…'), findsOneWidget);
        },
      );

      testWidgets(
        'default mode: recent tool calls stay expanded; older completed calls are collapsed',
        (tester) async {
          const active = ToolEvent(
            id: 'tc1',
            toolCallId: 'tc1',
            tool: 'Bash',
            args: {'command': 'cargo check'},
            status: ToolEventStatus.pending,
          );
          await tester.pumpWidget(
            _wrap(
              const ToolRequestCard(
                tool: active,
                verbosity: SessionVerbosity.defaultLevel,
                isRecent: true,
              ),
            ),
          );
          // Active tool call is expanded
          expect(find.text(r'$ '), findsOneWidget);
          expect(find.text('⏳ Running…'), findsOneWidget);

          // Recent tool transitions to completed -> remains expanded!
          const done = ToolEvent(
            id: 'tc1',
            toolCallId: 'tc1',
            tool: 'Bash',
            args: {'command': 'cargo check'},
            status: ToolEventStatus.completed,
          );
          await tester.pumpWidget(
            _wrap(
              const ToolRequestCard(
                tool: done,
                verbosity: SessionVerbosity.defaultLevel,
                isRecent: true,
              ),
            ),
          );
          // Still expanded in full form
          expect(find.text(r'$ '), findsOneWidget);
          expect(find.text('✓ Done'), findsOneWidget);

          // When updated to isRecent: false (e.g. next turn starts), it collapses
          await tester.pumpWidget(
            _wrap(
              const ToolRequestCard(
                tool: done,
                verbosity: SessionVerbosity.defaultLevel,
                isRecent: false,
              ),
            ),
          );
          await tester.pump();
          expect(find.text(r'$ '), findsNothing);
          expect(find.text('DONE'), findsOneWidget);

          // Clicking the older collapsed tool expands it
          await tester.tap(find.byType(ToolRequestCard));
          await tester.pump();
          expect(find.text(r'$ '), findsOneWidget);
          expect(find.text('✓ Done'), findsOneWidget);

          // Keeping not-recent on rebuild preserves user-expanded state
          await tester.pumpWidget(
            _wrap(
              const ToolRequestCard(
                tool: done,
                verbosity: SessionVerbosity.defaultLevel,
                isRecent: false,
              ),
            ),
          );
          await tester.pump();
          expect(find.text(r'$ '), findsOneWidget);

          // Failed tool stays expanded even when not recent
          const failed = ToolEvent(
            id: 'tc2',
            toolCallId: 'tc2',
            tool: 'Bash',
            args: {'command': 'cargo check'},
            status: ToolEventStatus.failed,
            error: 'build error',
          );
          await tester.pumpWidget(
            _wrap(
              const ToolRequestCard(
                tool: failed,
                verbosity: SessionVerbosity.defaultLevel,
                isRecent: false,
              ),
            ),
          );
          expect(find.text(r'$ '), findsOneWidget);
          expect(find.text('FAILED'), findsOneWidget);
          expect(find.text('✗ build error'), findsOneWidget);
        },
      );

      testWidgets(
        'default mode: twiddling expansion keeps user state when moving between recent and not-recent',
        (tester) async {
          const done = ToolEvent(
            id: 'tc1',
            toolCallId: 'tc1',
            tool: 'Bash',
            args: {'command': 'cargo check'},
            status: ToolEventStatus.completed,
          );

          // 1. Tool is recent: expanded by default
          await tester.pumpWidget(
            _wrap(
              const ToolRequestCard(
                tool: done,
                verbosity: SessionVerbosity.defaultLevel,
                isRecent: true,
              ),
            ),
          );
          expect(find.text(r'$ '), findsOneWidget);

          // User twiddles it to collapse while still recent
          await tester.tap(find.byIcon(LucideIcons.chevronDown));
          await tester.pump();
          expect(find.text(r'$ '), findsNothing);

          // Moves to not-recent: should preserve collapsed state left by user
          await tester.pumpWidget(
            _wrap(
              const ToolRequestCard(
                tool: done,
                verbosity: SessionVerbosity.defaultLevel,
                isRecent: false,
              ),
            ),
          );
          await tester.pump();
          expect(find.text(r'$ '), findsNothing);

          // User explicitly expands it while not-recent
          await tester.tap(find.byType(ToolRequestCard));
          await tester.pump();
          expect(find.text(r'$ '), findsOneWidget);

          // Further rebuilds at not-recent preserve user-expanded state
          await tester.pumpWidget(
            _wrap(
              const ToolRequestCard(
                tool: done,
                verbosity: SessionVerbosity.defaultLevel,
                isRecent: false,
              ),
            ),
          );
          await tester.pump();
          expect(find.text(r'$ '), findsOneWidget);

          // Switching global verbosity resets user twiddle to the new mode's default (terse -> collapsed)
          await tester.pumpWidget(
            _wrap(
              const ToolRequestCard(
                tool: done,
                verbosity: SessionVerbosity.terse,
                isRecent: false,
              ),
            ),
          );
          await tester.pump();
          expect(find.text(r'$ '), findsNothing);
        },
      );

      testWidgets(
        'verbose mode: all tool calls are left expanded unless collapsed widget is clicked',
        (tester) async {
          const done = ToolEvent(
            id: 'tc1',
            toolCallId: 'tc1',
            tool: 'Bash',
            args: {'command': 'ls'},
            status: ToolEventStatus.completed,
          );
          await tester.pumpWidget(
            _wrap(
              const ToolRequestCard(
                tool: done,
                verbosity: SessionVerbosity.verbose,
              ),
            ),
          );
          // Left expanded
          expect(find.text(r'$ '), findsOneWidget);
          expect(find.text('✓ Done'), findsOneWidget);

          // Click header/collapse widget to collapse
          await tester.tap(find.byIcon(LucideIcons.chevronDown));
          await tester.pump();

          // Now collapsed
          expect(find.text(r'$ '), findsNothing);
          expect(find.text('DONE'), findsOneWidget);
        },
      );
    });
  });
}
