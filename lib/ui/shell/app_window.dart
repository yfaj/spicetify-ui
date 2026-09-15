import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

const Size windowSize = Size(640, 560);

/// Width the log panel occupies, including its own margin.
const double logPanelWidth = 258;

/// The window grows rather than squeezing the content when the log opens.
const Size windowSizeWithLog = Size(640 + logPanelWidth, 560);

/// Resizes the fixed window so the log panel sits beside the content instead
/// of taking width from it. Min and max are locked to the same value, so they
/// have to move with it.
Future<void> setLogPanelVisible(bool visible) async {
  final size = visible ? windowSizeWithLog : windowSize;
  await windowManager.setMinimumSize(size);
  await windowManager.setMaximumSize(size);
  await windowManager.setSize(size);
}

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
