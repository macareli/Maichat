import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maichat/models/chat_interface.dart';
import 'package:maichat/widgets/btw_thread.dart';

void main() {
  for (final width in [320.0, 412.0, 800.0]) {
    for (final composer in ComposerStyle.values) {
      for (final scale in [1.0, 1.7]) {
        testWidgets('full-width transcript at $width, $composer, $scale', (
          tester,
        ) async {
          tester.view
            ..physicalSize = Size(width, 915)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final controller = BtwThreadController(
            ask: (_, _, _, _) async =>
                List.filled(12, 'A long side answer.').join(' '),
          );
          addTearDown(controller.dispose);
          await controller.submit('Question');
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: BtwThread(
                      controller: controller,
                      ui: ChatInterface(composerStyle: composer),
                      onClose: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final answer = tester.getRect(find.byKey(const Key('btw-answer-0')));
          expect(answer.left, closeTo(20, 0.1));
          expect(answer.right, closeTo(width - 20, 0.1));
          final close = find.byKey(const Key('btw-close'));
          expect(tester.getSize(close), const Size(48, 48));
          expect(
            tester
                .widget<Icon>(
                  find.descendant(of: close, matching: find.byType(Icon)),
                )
                .icon,
            Icons.arrow_forward,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('small gradient title and faint note leave with the transcript', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = BtwThreadController(
      ask: (_, _, _, _) async => 'A short answer.',
    );
    addTearDown(controller.dispose);
    await controller.submit('First question');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BtwThread(
            controller: controller,
            ui: const ChatInterface(),
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gradient = find.byKey(const Key('btw-title-gradient'));
    expect(tester.getTopLeft(gradient).dy, closeTo(0, 0.1));
    final title = tester.widget<Text>(
      find.byKey(const Key('btw-thread-title')),
    );
    expect(title.style!.fontSize, lessThan(20));
    final decoration =
        tester.widget<Container>(gradient).decoration! as BoxDecoration;
    expect((decoration.gradient! as LinearGradient).colors.first, Colors.black);
    final note = find.byKey(const Key('btw-transcript-note'));
    expect(tester.widget<Text>(note).style!.color!.a, lessThanOrEqualTo(0.5));

    for (var i = 0; i < 15; i++) {
      await controller.submit('Follow-up $i');
    }
    await tester.pumpAndSettle();
    final transcript = find.byKey(const Key('btw-transcript'));
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(of: transcript, matching: find.byType(Scrollable))
              .first,
        )
        .position;
    final viewport = tester.getRect(transcript);
    expect(
      gradient.evaluate().isNotEmpty &&
          tester.getRect(gradient).overlaps(viewport),
      isFalse,
    );
    expect(tester.getRect(note).overlaps(viewport), isTrue);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(gradient).dy, closeTo(viewport.top, 0.1));
    expect(
      note.evaluate().isNotEmpty && tester.getRect(note).overlaps(viewport),
      isFalse,
    );
    position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      gradient.evaluate().isNotEmpty &&
          tester.getRect(gradient).overlaps(viewport),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
