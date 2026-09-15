import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

const Size windowSize = Size(640, 720);

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
    await windowManager.show();
    await windowManager.focus();
  });
}
