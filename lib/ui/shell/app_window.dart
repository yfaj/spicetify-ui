import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

const Size windowSize = Size(640, 560);

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
    // Leaves the window itself unfilled, so the gap between the two cards
    // shows the desktop rather than a slab of app colour. Only the cards are
    // opaque. On Windows this drives SetWindowCompositionAttribute with a
    // fully transparent accent.
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.show();
    await windowManager.focus();
  });
}
