import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maichat/models/agent_message.dart';
import 'package:maichat/models/message_image.dart';
import 'package:maichat/models/provider.dart';
import 'package:maichat/models/studio.dart';
import 'package:maichat/screens/studio/shell/slash_commands.dart';
import 'package:maichat/services/studio/studio_commands.dart';
import 'package:maichat/services/studio/studio_controller.dart';
import 'package:maichat/services/studio/studio_memory.dart';
import 'package:maichat/services/studio/studio_skills.dart';
import 'package:maichat/services/studio/studio_store.dart';
import 'package:maichat/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Starters implements StarterSkillSource {
  _Starters(this.skills);
  final Map<String, Map<String, String>> skills;
  @override
  Future<Map<String, Map<String, String>>> load() async => skills;
}

/// `/` commands end to end: a real [AppState] and [StudioController], the
/// real command runner, and a loopback model — asserting what actually goes
/// out on the wire (and that app-only commands send nothing at all).
void main() {
  late HttpServer server;
  late Directory dir;
  late List<Map<String, dynamic>> requests;

  Map<String, dynamic> words(String text) => {
        'choices': [
          {
            'delta': {'content': text},
          },
        ],
      };

  Future<(AppState, StudioController)> boot({
    Map<String, Map<String, String>> skills = const {},
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    StudioSkillLibrary.resetShared();
    StudioCommandStore.resetShared();
    StudioMemory.resetShared();
    requests = [];
    dir = await Directory.systemTemp.createTemp('studio_slash');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      requests.add(body);
      request.response.headers.contentType = ContentType('text', 'event-stream');
      request.response.write('data: ${jsonEncode(words('Done.'))}\n\n');
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });
    final state = AppState();
    await state.init();
    await state.addProvider(Provider(
      id: 'p',
      name: 'local',
      kind: ProviderKind.openai,
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      model: 'builder',
      apiKey: 'k',
    ));
    await StudioSkillLibrary.forDirectory(dir, starters: _Starters(skills));
    await StudioCommandStore.forDirectory(dir);
    final controller = StudioController(
      state: state,
      store: StudioStore(dir),
      session: newStudioSession(),
    );
    addTearDown(controller.flush);
    return (state, controller);
  }

  tearDown(() async {
    await server.close(force: true);
    StudioSkillLibrary.resetShared();
    StudioCommandStore.resetShared();
    StudioMemory.resetShared();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// The runner as the screen builds it, with its UI actions recorded.
  ({StudioSlashCommands runner, List<String> did}) wire(
    StudioController controller, {
    void Function(String text)? onUndo,
  }) {
    final did = <String>[];
    final runner = StudioSlashCommands(
      controller: controller,
      onHelp: () => did.add('help'),
      onSkills: () => did.add('skills'),
      onContext: () => did.add('context'),
      onAgents: () => did.add('agents'),
      onNewSession: () async => did.add('new'),
      onToast: (m) => did.add('toast: $m'),
      onUnknown: (text, images, name) => did.add('unknown: $name'),
      onUndo: onUndo,
    );
    controller.onSlashCommand = runner.handle;
    return (runner: runner, did: did);
  }

  List<Map> messages(Map<String, dynamic> body) =>
      (body['messages'] as List).cast<Map>();

  const voice = {
    'voice': {
      'SKILL.md': '---\nname: voice\ndescription: Sharpens how a character '
          'talks. Use for dialogue work.\n---\n\nVOICE_RULES: one habit per line.',
      'references/samples.md': 'Sample lines.',
    },
  };

  test('a /skill turn carries the skill\'s instructions before the user\'s '
      'words', () async {
    final (_, controller) = await boot(skills: voice);
    wire(controller);
    await controller.send('/voice make her drier');

    expect(requests, hasLength(1));
    final body = requests.single;
    final last = messages(body).last;
    expect(last['role'], 'user');
    final text = last['content'] as String;
    expect(text, contains('<skill_content name="voice">'));
    expect(text, contains('VOICE_RULES: one habit per line.'));
    expect(text, contains('references/samples.md'));
    expect(text.indexOf('VOICE_RULES'), lessThan(text.indexOf('make her drier')));
    expect(text.trim(), endsWith('make her drier'));
    // The system prompt lists the skill, and the tools can load it.
    expect(messages(body).first['content'], contains('- voice: Sharpens'));
    final tools = [
      for (final t in body['tools'] as List) (t as Map)['function']['name'],
    ];
    expect(tools, containsAll(['use_skill', 'read_skill_file']));
    // The transcript keeps it as a skill turn; the title is the user's words.
    final turn = controller.session.transcript.first;
    expect(parseSkillInvocation(turn.text)!.skill, 'voice');
    expect(controller.session.title, 'make her drier');
  });

  test('with no skill on, nothing about skills goes out', () async {
    final (_, controller) = await boot();
    wire(controller);
    await controller.send('Hello there.');
    final body = requests.single;
    expect(messages(body).first['content'], isNot(contains('available_skills')));
    final tools = [
      for (final t in body['tools'] as List) (t as Map)['function']['name'],
    ];
    expect(tools, isNot(contains('use_skill')));
  });

  test('a command of your own sends its filled-in template', () async {
    final (_, controller) = await boot();
    await StudioCommandStore.active!.save(const StudioCommand(
      name: 'villain',
      description: 'Add a villain',
      kind: StudioCommandKind.custom,
      template: 'Add a villain to this story who \$ARGUMENTS.',
    ));
    wire(controller);
    await controller.send('/villain hates the sea');
    expect(messages(requests.single).last['content'],
        'Add a villain to this story who hates the sea.');
  });

  test('/playtest asks the agent to playtest with the given line', () async {
    final (_, controller) = await boot();
    wire(controller);
    await controller.send('/playtest Why do you stay?');
    final text = messages(requests.single).last['content'] as String;
    expect(text, contains('Playtest the draft now'));
    expect(text, contains('"Why do you stay?"'));
  });

  test('app-only commands never reach the model', () async {
    final (state, controller) = await boot();
    final w = wire(controller);
    for (final line in ['/help', '/skills', '/context', '/new', '/stop',
                        '/agents']) {
      await controller.send(line);
    }
    expect(requests, isEmpty);
    expect(controller.session.transcript, isEmpty);
    expect(w.did, [
      'help',
      'skills',
      'context',
      'new',
      'toast: Nothing is running.',
      'toast: No sub-agents in this session yet.',
    ]);

    // /remember writes the memory straight away.
    await controller.send('/remember Prefers third-person present.');
    final memory = await StudioMemory.forDirectory(dir);
    expect(memory.notes, ['Prefers third-person present.']);
    expect(w.did.last, 'toast: Remembered.');
    await state.updateStudioConfig(
      state.studioConfig.copyWith(memoryEnabled: false),
    );
    await controller.send('/remember Likes tea.');
    expect(w.did.last, contains('Memory is off'));
    expect(requests, isEmpty);
    await memory.flush();
  });

  test('an unknown command is handed back, and "send as text" sends it', () async {
    final (_, controller) = await boot();
    final w = wire(controller);
    await controller.send('/wizard do magic');
    expect(requests, isEmpty);
    expect(w.did, ['unknown: wizard']);
    await controller.send('/wizard do magic', asText: true);
    expect(messages(requests.single).last['content'], '/wizard do magic');
  });

  test('pictures sent with a skill command go with it', () async {
    final (_, controller) = await boot(skills: voice);
    wire(controller);
    await controller.send(
      '/voice this face',
      images: const [MessageImage(ref: 'https://example.com/face.png')],
    );
    final content = messages(requests.single).last['content'];
    expect(content, isA<List>());
    expect(jsonEncode(content), contains('https://example.com/face.png'));
  });

  test('/compact summarises the older conversation now', () async {
    final (_, controller) = await boot();
    final w = wire(controller);
    // Too short to be worth it: nothing is sent.
    controller.session.transcript
      ..add(AgentMessage.user('Hello.'))
      ..add(AgentMessage(role: AgentRole.assistant, text: 'Hi.'));
    await controller.send('/compact');
    expect(requests, isEmpty);
    expect(w.did.last, 'toast: Nothing to summarise yet.');

    // A conversation long enough that there is something to summarise.
    for (var i = 0; i < 12; i++) {
      controller.session.transcript
        ..add(AgentMessage.user('Question $i: ${'words ' * 40}'))
        ..add(AgentMessage(
            role: AgentRole.assistant, text: 'Answer $i. ${'more ' * 40}'));
    }
    await controller.send('/compact');
    expect(requests, hasLength(1));
    // The one request is the summariser, not a turn of the conversation.
    expect(messages(requests.single).first['content'],
        contains('summarising your own working session'));
    expect(controller.session.compactions, hasLength(1));
    expect(w.did.last, 'toast: Summarised the older conversation.');
  });

  test('/undo drops the last exchange, and the resend goes out clean',
      () async {
    final (_, controller) = await boot();
    final w = wire(controller);
    await controller.send('First question.');
    await controller.send('Second question.');
    expect(requests, hasLength(2));
    expect(controller.session.transcript, hasLength(4));

    await controller.send('/undo');
    // An app-only command: nothing is sent, one exchange is gone.
    expect(requests, hasLength(2));
    expect(
      controller.session.transcript.map((m) => m.text),
      ['First question.', 'Done.'],
    );
    expect(w.did.last, 'toast: Dropped the last turn.');

    // The rephrased resend replaces what was dropped on the wire too.
    await controller.send('Second question, better put.');
    expect(requests, hasLength(3));
    final sent = messages(requests.last).map((m) => m['content']).join(' ');
    expect(sent, contains('Second question, better put.'));
    expect(sent, isNot(contains('Second question.')));
  });

  test('/undo puts the dropped turn back in the composer, unsent', () async {
    final (_, controller) = await boot();
    final restored = <String>[];
    final w = wire(controller, onUndo: restored.add);
    await controller.send('First question.');
    await controller.send('Second question.');
    expect(requests, hasLength(2));

    await controller.send('/undo');
    // Nothing more went out: the text is back in the composer, not sent.
    expect(requests, hasLength(2));
    expect(restored, ['Second question.']);
    expect(w.did.last, 'toast: Dropped the last turn.');

    // Rephrase in place, then send: the dropped words go back out.
    await controller.send(restored.single, asText: true);
    expect(requests, hasLength(3));
    final sent = messages(requests.last).map((m) => m['content']).join(' ');
    expect(sent, contains('Second question.'));
    // The first exchange was never dropped; it is still on the wire.
    expect(sent, contains('First question.'));
  });

  test('/undo N rewinds to the cut turn and stages only that one', () async {
    final (_, controller) = await boot();
    final restored = <String>[];
    final w = wire(controller, onUndo: restored.add);
    await controller.send('First question.');
    await controller.send('Second question.');
    await controller.send('Third question.');

    await controller.send('/undo 2');
    expect(requests, hasLength(3));
    // Both exchanges are gone, but only the turn the conversation was
    // rewound to — the second, at the cut — comes back: the deeper turns are
    // gone with the rest, the undo being what the user asked for.
    expect(restored, ['Second question.']);
    expect(w.did.last, 'toast: Dropped the last 2 turns.');
    expect(
      controller.session.transcript.map((m) => m.text),
      ['First question.', 'Done.'],
    );
  });

  test('/undo rewinds the draft changes made during the dropped turns and '
      'tells the agent', () async {
    final (_, controller) = await boot();
    final w = wire(controller);
    // A change made during the exchange that is about to be dropped.
    await controller.send('Make her a keeper of the light.');
    controller.session.edit(
      'set_fields',
      'Set description',
      (ws) => ws.character.description = 'Keeps the light.',
    );
    expect(controller.session.workspace.character.description,
        'Keeps the light.');

    await controller.send('/undo');
    expect(requests, hasLength(1));
    // The draft is back, and the agent is told to read it again.
    expect(controller.session.workspace.character.description, '');
    expect(controller.session.ops.single.reverted, isTrue);
    expect(
      controller.session.transcript.last.text,
      contains('The user rewound the draft'),
    );
    expect(w.did.last, 'toast: Dropped the last turn. Rewound 1 draft '
        'change.');
    // The next send carries the note, so the agent rebuilds on the rewound
    // draft.
    await controller.send('Try again.');
    expect(requests, hasLength(2));
    final sent = messages(requests.last).map((m) => m['content']).join(' ');
    expect(sent, contains('Call get_draft before making further changes'));
  });

  test('/undo N drops N exchanges at once', () async {
    final (_, controller) = await boot();
    final w = wire(controller);
    await controller.send('First question.');
    await controller.send('Second question.');
    await controller.send('/undo 2');
    expect(requests, hasLength(2));
    expect(controller.session.transcript, isEmpty);
    expect(w.did.last, 'toast: Dropped the last 2 turns.');
  });

  test('/undo refuses what there is not, and says what there is', () async {
    final (_, controller) = await boot();
    final w = wire(controller);
    await controller.send('First question.');
    await controller.send('Second question.');
    final before = controller.session.transcript.length;

    await controller.send('/undo 3');
    expect(requests, hasLength(2));
    expect(controller.session.transcript, hasLength(before));
    expect(w.did.last, 'toast: Only 2 turns to undo.');

    await controller.send('/undo what');
    await controller.send('/undo 0');
    expect(w.did.last, 'toast: How many turns: /undo <turns>.');
    expect(w.did[w.did.length - 2], 'toast: How many turns: /undo <turns>.');
    expect(controller.session.transcript, hasLength(before));
  });

  test('/undo with nothing to undo says so', () async {
    final (_, controller) = await boot();
    final w = wire(controller);
    await controller.send('/undo');
    expect(requests, isEmpty);
    expect(controller.session.transcript, isEmpty);
    expect(w.did.last, 'toast: Nothing to undo yet.');
  });

  test('/undo refuses while a sub-agent is working', () async {
    final (_, controller) = await boot();
    final w = wire(controller);
    await controller.send('First question.');
    final before = controller.session.transcript.length;
    // A background sub-agent at work: busy without a run of the main agent.
    controller.session.subagents.add(StudioSubagent(
      id: 'sub',
      number: 1,
      description: 'Helper',
      prompt: 'p',
      callId: 'c',
      status: StudioAgentStatus.running,
    ));
    await controller.send('/undo');
    expect(requests, hasLength(1));
    expect(controller.session.transcript, hasLength(before));
    expect(w.did.last, 'toast: The Studio is working — try again once it has '
        'finished.');
  });

  test('/undo drops a compaction that covered the removed turns', () async {
    final (_, controller) = await boot();
    final w = wire(controller);
    controller.session.transcript
      ..add(AgentMessage.user('First question.'))
      ..add(AgentMessage(role: AgentRole.assistant, text: 'Done.'))
      ..add(AgentMessage.user('Second question.'))
      ..add(AgentMessage(role: AgentRole.assistant, text: 'Done.'));
    // Its summary covers part of what is about to be removed.
    controller.session.compactions
        .add(StudioCompaction(summary: 'stale', upTo: 3));
    await controller.send('/undo');
    expect(requests, isEmpty);
    expect(controller.session.compactions, isEmpty);
    expect(w.did.last, 'toast: Dropped the last turn.');
  });
}
