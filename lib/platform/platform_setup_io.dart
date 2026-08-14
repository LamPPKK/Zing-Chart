import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initializePlatformWindow() async {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1180, 760),
    minimumSize: Size(760, 560),
    center: true,
    title: '#zingChart',
    backgroundColor: Color(0xFF101113),
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
