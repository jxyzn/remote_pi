import 'package:app/domain/session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chat message search query matching', () {
    test('matches UserMsg text case-insensitively', () {
      const msg = UserMsg(id: 'u1', text: 'Please restart NGINX service');
      expect(msg.matchesSearchQuery('nginx'), isTrue);
      expect(msg.matchesSearchQuery('NGINX'), isTrue);
      expect(msg.matchesSearchQuery('restart'), isTrue);
      expect(msg.matchesSearchQuery('apache'), isFalse);
    });

    test('matches AssistantMsg text case-insensitively', () {
      const msg = AssistantMsg(
        id: 'a1',
        text: 'I have checked systemctl and restarted nginx successfully.',
      );
      expect(msg.matchesSearchQuery('systemctl'), isTrue);
      expect(msg.matchesSearchQuery('Restarted'), isTrue);
      expect(msg.matchesSearchQuery('docker'), isFalse);
    });

    test('matches ToolEvent tool name, args, result, or error', () {
      const toolEvent = ToolEvent(
        id: 't1',
        toolCallId: 'call_1',
        tool: 'bash',
        args: {'command': 'grep -rn "PORT" /etc/nginx/sites-available'},
        result: 'listen 8080;',
        error: null,
      );
      expect(toolEvent.matchesSearchQuery('bash'), isTrue);
      expect(toolEvent.matchesSearchQuery('PORT'), isTrue);
      expect(toolEvent.matchesSearchQuery('listen 8080'), isTrue);
      expect(toolEvent.matchesSearchQuery('redis'), isFalse);

      const failedTool = ToolEvent(
        id: 't2',
        toolCallId: 'call_2',
        tool: 'docker_ps',
        args: {},
        error: 'Connection refused on socket /var/run/docker.sock',
      );
      expect(failedTool.matchesSearchQuery('docker.sock'), isTrue);
      expect(failedTool.matchesSearchQuery('Connection refused'), isTrue);
    });

    test('matches CompactionMsg summary', () {
      const compaction = CompactionMsg(
        id: 'c1',
        summary: 'Compacted 20 prior turns discussing deployment setup.',
        tokensBefore: 45000,
      );
      expect(compaction.matchesSearchQuery('deployment'), isTrue);
      expect(compaction.matchesSearchQuery('Compacted'), isTrue);
      expect(compaction.matchesSearchQuery('unrelated'), isFalse);
    });

    test('empty or whitespace query matches nothing', () {
      const msg = UserMsg(id: 'u1', text: 'Hello world');
      expect(msg.matchesSearchQuery(''), isFalse);
      expect(msg.matchesSearchQuery('   '), isFalse);
    });
  });
}
