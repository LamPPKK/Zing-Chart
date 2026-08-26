import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile and desktop packages register the zingchart URL scheme', () {
    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(android, contains('android:scheme="zingchart"'));
    expect(android, contains('android:host="open"'));
    expect(android, contains('android:host="zingmp3.vn"'));
    expect(android, contains('android:pathPrefix="/bai-hat/"'));
    expect(android, contains('android:pathPrefix="/video-clip/"'));
    expect(android, contains('android:pathPrefix="/tim-kiem"'));
    expect(android, contains('android:pathPattern="/.*"'));
    expect(android, contains('flutter_deeplinking_enabled'));

    for (final path in ['ios/Runner/Info.plist', 'macos/Runner/Info.plist']) {
      final plist = File(path).readAsStringSync();
      expect(plist, contains('<key>CFBundleURLSchemes</key>'), reason: path);
      expect(plist, contains('<string>zingchart</string>'), reason: path);
      expect(plist, contains('<key>FlutterDeepLinkingEnabled</key>'));
    }

    final msix = File('packaging/windows/AppxManifest.xml').readAsStringSync();
    expect(msix, contains('Category="windows.protocol"'));
    expect(msix, contains('<uap:Protocol Name="zingchart">'));

    final inno = File('packaging/windows/zingchart.iss').readAsStringSync();
    expect(inno, contains('Software\\Classes\\zingchart'));
    expect(inno, contains(r'\"%1\"'));

    final desktop = File(
      'packaging/linux/zingchart.desktop',
    ).readAsStringSync();
    expect(desktop, contains('Exec=zingchart %u'));
    expect(desktop, contains('MimeType=x-scheme-handler/zingchart;'));

    final macDelegate = File(
      'macos/Runner/AppDelegate.swift',
    ).readAsStringSync();
    expect(
      macDelegate,
      contains('application(_ application: NSApplication, open urls: [URL])'),
    );
    expect(macDelegate, contains('software.baycho.zmp3chart/deep_link'));
    expect(macDelegate, contains('case "getInitialRoute"'));
    expect(macDelegate, contains('case "ready"'));
    expect(macDelegate, contains('urls.last(where:'));
    expect(macDelegate, isNot(contains('asyncAfter')));
    expect(macDelegate, isNot(contains('applicationDidFinishLaunching')));
    final macWindow = File(
      'macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();
    expect(
      macWindow,
      contains('configureDeepLinkChannel(flutterViewController)'),
    );
  });
}
