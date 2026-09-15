import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// The window is fixed at this size when the log is closed.
const Size windowSize = Size(640, 560);

/// The app's accent, and a heavily blacked-out version of it for the card
/// shadows, so they read as part of the theme rather than as generic black.
const Color accentColour = Color(0xFFF97316);
const Color cardShadow = Color(0xCC2A1408);

/// Width the log card occupies, including its margin.
const double logPanelWidth = 228;

/// The window with the log open, so the main card keeps its width.
const Size windowSizeWithLog = Size(640 + logPanelWidth, 560);

/// Grows the window to the left when the log opens, and shrinks it back when
/// the log closes. Both directions, so the size always returns to [windowSize].
Future<void> setLogPanelVisible(bool visible) async {
  final size = visible ? windowSizeWithLog : windowSize;
  final bounds = await windowManager.getBounds();
  final added = size.width - bounds.width;

  await windowManager.setMinimumSize(size);
  await windowManager.setMaximumSize(size);
  await windowManager.setBounds(
    Rect.fromLTWH(bounds.left - added, bounds.top, size.width, size.height),
  );
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
