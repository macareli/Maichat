import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maichat/models/btw_conversation.dart';
import 'package:maichat/models/conversation.dart';
import 'package:maichat/models/message.dart';
import 'package:maichat/screens/chat_screen.dart';
import 'package:maichat/services/btw.dart';
import 'package:maichat/services/chat_client.dart';
import 'package:maichat/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _State extends AppState {
  @override
  bool get isConfigured => true;

  @override
  Future<String> askAside(
    String question, {
    Conversation? conversation,
    BtwConversation? thread,
    List<ChatMessage> sideHistory = const [],
    ChatClient? client,
    BtwRun? run,
    void Function(String)? onProgress,
  }) async => 'Side answer';
}

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
    'DUlEQVR42mP8z8DAwAAABQABg1z0GwAAAABJRU5ErkJggg==';

void main() {
  for (final width in [412.0, 1280.0]) {
    for (final perChat in [false, true]) {
      testWidgets('return tab shares background at $width, per-chat $perChat', (
        tester,
      ) async {
        tester.view
          ..physicalSize = Size(width, 915)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final state = _State();
        await state.init();
        addTearDown(state.dispose);
        await state.updateChatInterface(
          state.chatInterface.copyWith(
            backgroundColor: 0xff315747,
            backgroundImage: perChat ? null : _png,
            backgroundOpacity: 0.65,
          ),
        );
        if (perChat) {
          state.active
            ..backgroundImage = _png
            ..backgroundOpacity = 0.37;
        }
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: state,
            child: const MaterialApp(home: ChatScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('composer-field')),
          '/btw Question',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('chat-ask-aside')));
        await tester.pumpAndSettle();

        final fragment = find.byKey(const Key('btw-return-background'));
        final backdrop = find.descendant(
          of: fragment,
          matching: find.byType(ColoredBox),
        );
        expect(
          tester.widget<ColoredBox>(backdrop).color,
          const Color(0xff315747),
        );
        final image = find.descendant(
          of: fragment,
          matching: find.byType(Image),
        );
        final painted = tester.widget<Image>(image);
        final mainImage = tester.widget<Image>(
          find
              .descendant(
                of: find.byKey(const Key('chat-main-pane')),
                matching: find.byType(Image),
              )
              .first,
        );
        expect(painted.image, same(mainImage.image));
        expect(painted.opacity!.value, perChat ? 0.37 : 0.65);
        final mainWidth = tester
            .getSize(find.byKey(const Key('chat-main-pane')))
            .width;
        expect(tester.getSize(image), Size(mainWidth + 48, 915));
        final transform = tester.widget<Transform>(
          find.descendant(of: fragment, matching: find.byType(Transform)),
        );
        expect(transform.transform.storage[12], closeTo(-mainWidth, 0.1));
        expect(transform.transform.storage[13], -56);
        expect(tester.getSize(fragment), const Size(48, 48));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
