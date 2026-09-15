import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// The window is made transparent natively, in windows/runner/flutter_window.cpp.
// Doing it through window_manager passes a flags value that asks the compositor
// to draw a one-pixel border around the window, which cannot be styled away.
const Size windowSize = Size(640, 560);

/// The app's accent, and a heavily blacked-out version of it for the card
/// shadows, so they read as part of the theme rather than as generic black.
const Color accentColour = Color(0xFFF97316);
const Color cardShadow = Color(0xCC2A1408);

/// Width the log card occupies, including its margin.
const double logPanelWidth = 228;

/// The window grows so the main card keeps its width when the log opens.
const Size windowSizeWithLog = Size(640 + logPanelWidth, 560);

/// Resizes the fixed window so the log card sits beside the main card instead
/// of taking width from it. Min and max are locked to the same value, so they
/// move with it.
///
/// The window grows to the left, so the main card stays exactly where it was
/// on screen instead of being pushed sideways.
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
    // The native drop shadow draws a rounded slab around the whole window,
    // which reads as a container holding both cards. The cards carry their
    // own shadows instead.
    await windowManager.setHasShadow(false);
    await windowManager.show();
    await windowManager.focus();
  });
}
