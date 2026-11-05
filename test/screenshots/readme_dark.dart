// flutter test test/screenshots/readme_dark.dart --update-goldens
// Explicit documentation captures: excluded from the normal *_test.dart suite.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maichat/main.dart';
import 'package:maichat/models/agent_message.dart';
import 'package:maichat/models/appearance.dart';
import 'package:maichat/models/btw_conversation.dart';
import 'package:maichat/models/chat_interface.dart';
import 'package:maichat/models/home_layout.dart';
import 'package:maichat/models/home_note.dart';
import 'package:maichat/models/lorebook.dart';
import 'package:maichat/models/scenario.dart';
import 'package:maichat/models/studio.dart';
import 'package:maichat/screens/chat_screen.dart';
import 'package:maichat/screens/discover/discover_screen.dart';
import 'package:maichat/screens/gallery/gallery_screen.dart';
import 'package:maichat/screens/home_screen.dart';
import 'package:maichat/screens/library/library_screen.dart';
import 'package:maichat/screens/studio/studio_screen.dart';
import 'package:maichat/services/studio/studio_store.dart';
import 'package:maichat/state/app_state.dart';
import 'package:provider/provider.dart';

import 'demo_catalogue.dart';
import 'demo_world.dart';
import 'shot.dart';

Widget _host(AppState state, Widget screen) {
  final fonts = shotTheme(brightness: Brightness.dark);
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme:
          MaiChatApp.themeFor(
            null,
            Brightness.dark,
            const Color(kDefaultSeedColor),
            expressive: true,
          ).copyWith(
            textTheme: fonts.textTheme,
            primaryTextTheme: fonts.primaryTextTheme,
          ),
      home: screen,
    ),
  );
}

Future<void> _home(AppState state) async {
  await state.saveHomeNote(
    HomeNote(
      id: 'readme-note',
      title: 'Next chapter',
      body: 'The ferry arrives at dawn. Ask Mira about the old chart.',
    ),
  );
  await state.setHomeLayout(
    HomeLayout(
      columns: 4,
      rows: 6,
      pages: const [
        HomePage(
          id: 'readme-home',
          tiles: [
            HomeTile(
              id: 'search',
              kind: HomeWidgetKind.search,
              x: 0,
              y: 0,
              w: 4,
            ),
            HomeTile(
              id: 'chat',
              kind: HomeWidgetKind.recentChat,
              x: 0,
              y: 1,
              w: 4,
              h: 2,
            ),
            HomeTile(
              id: 'note',
              kind: HomeWidgetKind.note,
              x: 0,
              y: 3,
              w: 2,
              h: 2,
              config: {'noteId': 'readme-note'},
            ),
            HomeTile(
              id: 'faces',
              kind: HomeWidgetKind.characters,
              x: 2,
              y: 3,
              w: 2,
            ),
            HomeTile(
              id: 'provider',
              kind: HomeWidgetKind.provider,
              x: 2,
              y: 4,
              w: 2,
            ),
            HomeTile(
              id: 'discover',
              kind: HomeWidgetKind.quickOpen,
              x: 0,
              y: 5,
              config: {'target': 'discover'},
            ),
            HomeTile(
              id: 'library',
              kind: HomeWidgetKind.quickOpen,
              x: 1,
              y: 5,
              config: {'target': 'library'},
            ),
            HomeTile(
              id: 'studio',
              kind: HomeWidgetKind.quickOpen,
              x: 2,
              y: 5,
              config: {'target': 'studio'},
            ),
            HomeTile(
              id: 'gallery',
              kind: HomeWidgetKind.quickOpen,
              x: 3,
              y: 5,
              config: {'target': 'gallery'},
            ),
          ],
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(loadShotFonts);
  for (final name in [
    '01-mobile',
    '02-tablet',
    '03-chat-tools',
    '04-agentic-studio',
    '05-discover',
    '06-home',
    '07-library',
    '08-gallery',
  ]) {
    testWidgets(name, (tester) async {
      usePhone(tester);
      addTearDown(() => debugDisableShadows = true);
      if (name == '02-tablet' || name == '03-chat-tools') {
        tester.view
          ..physicalSize = const Size(2560, 1600)
          ..devicePixelRatio = 2;
      }
      final state = (await tester.runAsync(demoWorld))!;
      await tester.runAsync(() async {
        await state.updateAppearance(
          const Appearance(mode: AppThemeMode.dark, expressive: true),
        );
        await state.updateChatInterface(const ChatInterface(showNames: true));
        seedChat(state);
        await state.addLorebook(
          Lorebook(
            id: 'harbour',
            name: 'Harbour after dark',
            entries: [
              LorebookEntry(
                uid: 0,
                keys: ['lighthouse'],
                content: 'The light has not shone for twenty years.',
              ),
            ],
          ),
        );
        await state.addScenario(
          Scenario(
            id: 'dawn',
            name: 'Before the first ferry',
            text: 'The lamp room, just before dawn.',
          ),
        );
        await _home(state);
        if (name == '08-gallery') await seedGallery(state);
        if (name == '03-chat-tools') {
          final thread = state.createBtwThread(
            state.active.id,
            question: 'What do we know about the light?',
          );
          thread.exchanges.add(
            BtwExchange(
              'What do we know about the light?',
              answer:
                  'Mira’s grandmother was the last keeper to light it. The mechanism still turns, but nobody has lit the lamp since.\n\nThe old chart may explain what changed along the coast.',
              done: true,
            ),
          );
          await state.saveBtwThread(thread);
        }
      });
      final Widget screen;
      Directory? studioDir;
      if (name == '02-tablet' || name == '06-home') {
        screen = const HomeScreen();
      } else if (name == '05-discover') {
        screen = const DiscoverScreen(sources: [DemoCatalogue()]);
      } else if (name == '07-library') {
        screen = const LibraryScreen();
      } else if (name == '08-gallery') {
        screen = const GalleryScreen(mode: GalleryMode.everything);
      } else if (name == '04-agentic-studio') {
        studioDir = Directory.systemTemp.createTempSync('readme-studio-');
        final session = StudioSession(
          id: 'readme-studio',
          title: 'A keeper on the coast',
          workspace: StudioWorkspace(character: state.characterById('mira')!),
        );
        session.workspace.character
          ..title = 'Keeper of the last light'
          ..titleShown = true;
        session.transcript.addAll([
          AgentMessage.user(
            'Create a lighthouse keeper with a mystery to uncover.',
          ),
          AgentMessage(
            role: AgentRole.assistant,
            text:
                'Mira Vale is ready. I built her character, the harbour lorebook, and an opening scene before the first ferry. You can edit the draft or try a conversation in the Playground.',
          ),
        ]);
        screen = StudioScreen(store: StudioStore(studioDir), session: session);
      } else {
        screen = const ChatScreen();
      }
      await tester.pumpWidget(_host(state, screen));
      await tester.pumpAndSettle();
      if (name == '03-chat-tools') {
        await tester.tap(find.byKey(const Key('btw-reopen')));
        await tester.pumpAndSettle();
      }
      if (name == '04-agentic-studio') {
        await tester.tap(find.byKey(const Key('studio-composer-ops')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('studio-toggle-areas')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('studio-area-draft')));
        await tester.pumpAndSettle();
      }
      if (name == '03-chat-tools') {
        // Place the top visible name below the overlaid menu for this photo.
        final mainScroll = find
            .descendant(
              of: find.byKey(const Key('chat-main-pane')),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(mainScroll).position;
        position.jumpTo(
          (position.pixels + 80).clamp(0, position.maxScrollExtent),
        );
        await tester.pumpAndSettle();
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await settleShots(tester);
      // Image decoding uses real time, while SmoothImage's first-frame fade
      // uses the test clock. Wait for both before writing the screenshot.
      final imageContext = tester.element(find.byType(MaterialApp));
      final providers = tester
          .widgetList<Image>(find.byType(Image))
          .map((image) => image.image)
          .toSet();
      await tester.runAsync(
        () => Future.wait([
          for (final provider in providers)
            precacheImage(provider, imageContext),
        ]),
      );
      await tester.pumpAndSettle();
      if (name == '08-gallery') {
        expect(
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .where((image) => image.image != null)
              .length,
          greaterThanOrEqualTo(4),
        );
      }
      expect(
        Theme.of(
          tester.element(find.byType(screen.runtimeType).first),
        ).brightness,
        Brightness.dark,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../docs/screenshots/readme/$name.png'),
      );
      debugDisableShadows = true;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(state.flushPendingSaves);
      state.dispose();
      if (studioDir != null) {
        await tester.runAsync(() => studioDir!.delete(recursive: true));
      }
    });
  }
}
