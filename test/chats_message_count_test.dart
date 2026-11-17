import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maichat/models/conversation.dart';
import 'package:maichat/models/message.dart';
import 'package:maichat/screens/chats_screen.dart';
import 'package:maichat/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The message-count pill on the Chats list rows. It rides on the row avatar's
/// corner, and describes the freshest branch of the row's fork tree — the same
/// chat the preview and timestamp are drawn from.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Conversation chat(
    String id,
    String title, {
    int turns = 1,
    String? parentId,
    int? forkIndex,
    int minutesAgo = 0,
  }) =>
      Conversation(
        id: id,
        title: title,
        messages: [
          for (var i = 0; i < turns; i++)
            ChatMessage(
              role: i.isEven ? 'user' : 'assistant',
              content: 'turn $i of $title',
            ),
        ],
        updatedAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
        parentId: parentId,
        forkIndex: forkIndex,
      );

  Future<AppState> ready(List<Conversation> chats) async {
    final state = AppState();
    await state.init();
    await state.importConversations(chats);
    return state;
  }

  Widget host(AppState state) => ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: ChatsScreen()),
      );

  testWidgets('a row shows the chat message count on its avatar',
      (tester) async {
    final state = await ready([
      chat('a', 'Solo chat', turns: 7),
    ]);
    await tester.pumpWidget(host(state));
    await tester.pumpAndSettle();

    expect(find.text('Solo chat'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('a fork-tree row counts the freshest branch, not the family',
      (tester) async {
    final state = await ready([
      chat('root', 'Tavern', turns: 6, minutesAgo: 120),
      chat('b1', 'She refuses', turns: 4, parentId: 'root', forkIndex: 1,
          minutesAgo: 5),
    ]);
    await tester.pumpWidget(host(state));
    await tester.pumpAndSettle();

    // The row previews the branch it was last left in, so the pill counts that
    // same branch — its own 4 turns, not 6 + 4 (the branch re-contains the
    // turns it inherited from the root).
    expect(find.textContaining('turn 3 of She refuses'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('10'), findsNothing);
  });

  testWidgets('a long chat compacts its count', (tester) async {
    final state = await ready([
      chat('big', 'Marathon', turns: 1200),
    ]);
    await tester.pumpWidget(host(state));
    await tester.pumpAndSettle();

    expect(find.text('Marathon'), findsOneWidget);
    expect(find.text('1.2k'), findsOneWidget);
    expect(find.text('1250'), findsNothing);
  });
}
