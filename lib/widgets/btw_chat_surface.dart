import 'package:flutter/material.dart';

/// Shares the main chat's background canvas with the side pane's return tab.
/// Only the small fragment depends on this geometry; the transcript is retained.
class BtwChatSurface extends InheritedWidget {
  const BtwChatSurface({
    super.key,
    required this.viewport,
    required this.background,
    required super.child,
  });

  static const tabWidth = 48.0;
  final Size viewport;
  final Widget background;

  static Widget fragment(BuildContext context, {required double top}) {
    final surface = context
        .dependOnInheritedWidgetOfExactType<BtwChatSurface>();
    if (surface == null) {
      return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
    }
    return ClipRect(
      key: const Key('btw-return-background'),
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: surface.viewport.width,
        maxWidth: surface.viewport.width,
        minHeight: surface.viewport.height,
        maxHeight: surface.viewport.height,
        child: Transform.translate(
          offset: Offset(-(surface.viewport.width - tabWidth), -top),
          child: surface.background,
        ),
      ),
    );
  }

  @override
  bool updateShouldNotify(BtwChatSurface oldWidget) =>
      viewport != oldWidget.viewport || background != oldWidget.background;
}
