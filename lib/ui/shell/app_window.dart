import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

const Size windowSize = Size(640, 560);

bool get usesCustomShell => Platform.isWindows || Platform.isMacOS;

Future<void> configureWindow() async {
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: windowSize,
    center: true,
    title: 'Spicetify UI',
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setResizable(false);
    await windowManager.setMaximizable(false);
    await windowManager.setMinimumSize(windowSize);
    await windowManager.setMaximumSize(windowSize);
    if (usesCustomShell) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    // Leaves the window itself unfilled, so the gap between the two cards
    // shows the desktop rather than a slab of app colour. Only the cards are
    // opaque. On Windows this drives SetWindowCompositionAttribute with a
    // fully transparent accent.
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.show();
    await windowManager.focus();
  });
}
