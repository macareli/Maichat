import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maichat/models/message.dart';
import 'package:maichat/models/preset.dart';
import 'package:maichat/models/prompt_block.dart';
import 'package:maichat/models/provider.dart';
import 'package:maichat/services/chat_client.dart';
import 'package:maichat/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Plain tests deliberately capture real HTTP; widget bindings replace it.
void main() {
  late AppState state;
  late HttpServer server;
  late List<({String path, Map<String, dynamic> body})> requests;
  bool failTitle = false;
  Completer<void>? titleGate;
  Completer<void>? titleArrived;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    failTitle = false;
    titleGate = null;
    titleArrived = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      requests.add((path: request.uri.path, body: body));
      final title = jsonEncode(body).contains('concise title');
      if (title) {
        titleArrived?.complete();
        await titleGate?.future;
        if (failTitle) {
          request.response.statusCode = 500;
          await request.response.close();
          return;
        }
      }
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'A Good Generated Title'},
              'finish_reason': 'stop',
            },
          ],
        })}\n\n',
      );
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });
    state = AppState();
    await state.init();
    await state.addProvider(
      Provider(
        id: 'main',
        name: 'main',
        kind: ProviderKind.openai,
        baseUrl: 'http://127.0.0.1:${server.port}/main/v1',
        model: 'main-model',
        apiKey: 'key',
      ),
    );
    await state.selectProvider('main');
    state.active.systemPrompt = 'RP_SYSTEM';
    state.active.messages.addAll([
      ChatMessage(role: 'user', content: 'RP_FIRST_TURN'),
      ChatMessage(role: 'assistant', content: 'RP_REPLY'),
    ]);
  });

  tearDown(() async {
    if (titleGate != null && !titleGate!.isCompleted) titleGate!.complete();
    state.dispose();
    await server.close(force: true);
  });

  test(
    'a generated title is its own no-preset request and renames the chat',
    () async {
      final preset = Preset(
        id: 'heavy',
        prompts: [
          PromptBlock(identifier: 'main', content: 'HEAVY_PRESET_TEXT'),
        ],
        promptOrder: [PromptOrderEntry(identifier: 'main')],
      );
      await state.addPreset(preset);
      await state.setDefaultPreset(preset.id);
      final id = state.active.id;
      final title = await state.generateTitle(id);
      expect(title, 'A Good Generated Title');
      final chat = state.conversations.firstWhere((c) => c.id == id);
      expect(chat.title, 'A Good Generated Title');
      expect(requests.single.path, '/main/v1/chat/completions');
      // The prompt is the transcript itself, not the assembled payload: no
      // preset text, and exactly one leading system message.
      final messages = (requests.single.body['messages'] as List)
          .cast<Map<String, dynamic>>();
      expect(messages.first['role'], 'system');
      expect(messages.where((m) => m['role'] == 'system'), hasLength(1));
      expect(jsonEncode(messages), isNot(contains('HEAVY_PRESET_TEXT')));
      expect(jsonEncode(messages), isNot(contains('RP_SYSTEM')));
      expect(jsonEncode(messages), contains('RP_FIRST_TURN'));
      // Small ask: the title request stays token-capped.
      expect(requests.single.body['max_tokens'], 64);
      // The rename persisted: a fresh load reads the new name.
      final loaded = AppState();
      await loaded.init();
      expect(
        loaded.conversations.firstWhere((c) => c.id == id).title,
        'A Good Generated Title',
      );
      loaded.dispose();
    },
  );

  test(
    'only the newest turns are sent and a failed turn is left out',
    () async {
      state.active.messages.clear();
      for (var i = 0; i < 20; i++) {
        state.active.messages.add(
          ChatMessage(
            role: i.isEven ? 'user' : 'assistant',
            content: i == 0 ? 'OLDEST_TURN' : 'TURN_$i',
            error: i == 19,
          ),
        );
      }
      await state.generateTitle(state.active.id);
      final content = jsonEncode(requests.single.body['messages']);
      expect(content, isNot(contains('OLDEST_TURN')));
      expect(content, isNot(contains('TURN_19')));
      expect(content, contains('TURN_18'));
      expect(content, contains('TURN_1'));
    },
  );

  test('an empty chat has nothing to name', () async {
    state.newConversation();
    state.active.messages.clear();
    final empty = state.active;
    expect(empty.isEmpty, isTrue);
    expect(await state.generateTitle(empty.id), isNull);
    expect(requests, isEmpty);
  });

  test('a failed request keeps the old title and throws', () async {
    failTitle = true;
    await expectLater(
      state.generateTitle(state.active.id),
      throwsA(isA<ChatApiException>()),
    );
    expect(state.active.title, isNot('A Good Generated Title'));
    // A retry after the failure is a fresh run, not a stuck one.
    failTitle = false;
    expect(
      await state.generateTitle(state.active.id),
      'A Good Generated Title',
    );
  });

  test('a second tap while one runs does not start a second request', () async {
    titleGate = Completer<void>();
    titleArrived = Completer<void>();
    final pending = state.generateTitle(state.active.id);
    await titleArrived!.future;
    final second = await state.generateTitle(state.active.id);
    expect(second, isNull);
    titleGate!.complete();
    expect(await pending, 'A Good Generated Title');
    expect(requests, hasLength(1));
  });

  test('a title that lands late cannot overwrite a manual rename', () async {
    titleGate = Completer<void>();
    titleArrived = Completer<void>();
    final pending = state.generateTitle(state.active.id);
    await titleArrived!.future;
    await state.renameConversation(state.active.id, 'My own title');
    titleGate!.complete();
    expect(await pending, isNull);
    expect(state.active.title, 'My own title');
  });

  test('deleting the chat cancels its pending title', () async {
    titleGate = Completer<void>();
    titleArrived = Completer<void>();
    final pending = state.generateTitle(state.active.id);
    await titleArrived!.future;
    await state.deleteConversation(state.active.id);
    titleGate!.complete();
    expect(await pending, isNull);
  });

  test('the request is metered even without reported usage', () async {
    await state.generateTitle(state.active.id);
    final total = state.usage.totals('main', model: 'main-model');
    expect(total.requests, 1);
    expect(total.totalTokens, greaterThan(0));
  });
}
