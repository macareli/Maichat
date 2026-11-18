import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maichat/models/character.dart';
import 'package:maichat/models/message.dart';
import 'package:maichat/models/provider.dart';
import 'package:maichat/screens/chat_settings_screen.dart';
import 'package:maichat/screens/chats_screen.dart';
import 'package:maichat/services/chat_client.dart';
import 'package:maichat/state/app_state.dart';
import 'package:provider/provider.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';

/// "Generate title" where the user reaches for it: the title field in Chat
/// settings (Edit Chat) and the Chats row's own menu. One tap asks the
/// provider for a short title and renames the chat; while the request is out
/// the affordance shows its progress instead of offering a second run.
void main() {
  late _Client client;

  setUp(() {
    client = _Client();
  });

  Future<(AppState, String)> boot(
    WidgetTester tester, {
    Widget Function(AppState state)? homeBuilder,
  }) async {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final state = AppState(client: client);
    await state.init();
    await state.addProvider(
      Provider(
        id: 'p',
        name: 'Local',
        kind: ProviderKind.openai,
        baseUrl: 'https://example.invalid/v1',
        apiKey: 'test',
        model: 'm',
      ),
    );
    final alice = Character(id: 'a', name: 'Alice');
    await state.addCharacter(alice);
    state.startChatWithCharacter(alice);
    state.active.messages.addAll([
      ChatMessage(role: 'assistant', content: 'The story begins.'),
      ChatMessage(role: 'user', content: 'We walk into the forest.'),
    ]);
    // Grab the id before building the home screen: a settings screen needs to
    // be pointed at the chat up front.
    final chatId = state.active.id;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: homeBuilder?.call(state) ?? const ChatsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(state.dispose);
    return (state, chatId);
  }

  testWidgets('Edit Chat: the title field generates and takes the name', (
    tester,
  ) async {
    final (state, _) = await boot(
      tester,
      homeBuilder: (state) => ChatSettingsScreen(
        conversationId: state.active.id,
      ),
    );
    client.nextTitle = 'The Forest Path';
    await tester.tap(find.byTooltip('Generate a title'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The name lands in the field as if typed; the store keeps it too — the
    // rename persists even without Save, which only carries the field to the
    // store when they differ.
    expect(find.text('The Forest Path'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(state.active.title, 'The Forest Path');
  });

  testWidgets('Chats row menu: one tap renames without opening the chat', (
    tester,
  ) async {
    final (state, _) = await boot(tester);
    client.nextTitle = 'A Row Menu Title';
    await tester.tap(find.byTooltip('More').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate title'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.active.title, 'A Row Menu Title');
    expect(find.text('A Row Menu Title'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Chats row menu: while the request runs the item shows progress and '
    'the field does not re-fire',
    (tester) async {
      final (state, chatId) = await boot(
        tester,
        homeBuilder: (state) => ChatSettingsScreen(conversationId: state.active.id),
      );
      client.hold = Completer<void>();
      final pending = state.generateTitle(state.active.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // The run is in flight: the field's affordance is a spinner — there is
      // no button to re-tap, and the guard in the handler refuses anyway.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      client.nextTitle = 'A Late Title';
      client.hold!.complete();
      await pending;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // The model's name reached the store through the run itself.
      expect(state.active.title, 'A Late Title');
      await tester.pumpAndSettle();
    },
  );

  testWidgets('an empty chat has nothing to name', (tester) async {
    final (state, _) = await boot(
      tester,
      homeBuilder: (state) => ChatSettingsScreen(
        conversationId: state.active.id,
      ),
    );
    state.active.messages.clear();
    await tester.tap(find.byTooltip('Generate a title'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(client.requests, 0);
    expect(find.text('Nothing to name yet.'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}

/// A ChatClient that answers only what this feature asks for. [requests]
/// counts the calls; a title reply is released all at once, or held behind
/// [hold] to keep one in flight.
class _Client extends ChatClient {
  int requests = 0;
  Completer<void>? hold;
  String nextTitle = 'Generated Title';

  @override
  Future<List<String>> listModels(Provider provider) async => ['m'];

  @override
  Stream<ChatDelta> streamChat({
    required Provider provider,
    required List<ChatMessage> history,
    GenParams params = const GenParams(),
  }) async* {
    requests++;
    final arrived = hold?.future ?? Future<void>.value();
    await arrived;
    final isTitle = history.isNotEmpty &&
        history.first.role == 'system' &&
        history.first.content.contains('concise title');
    yield ChatDelta(text: isTitle ? nextTitle : 'A reply.');
  }
}
