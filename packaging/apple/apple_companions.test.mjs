import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relative) => readFile(path.join(root, relative), 'utf8');

test('Apple companion bridge shares versioned playback state locally', async () => {
  const dart = await read('lib/services/companion_surface_bridge.dart');
  const delegate = await read('ios/Runner/AppDelegate.swift');
  assert.match(dart, /schemaVersion': 1/);
  assert.match(delegate, /software\.baycho\.zmp3chart\/companion/);
  assert.match(delegate, /updateApplicationContext/);
  assert.match(delegate, /reloadTimelines/);
  assert.match(delegate, /widgetSignature/);
  assert.doesNotMatch(delegate, /URLSession|uploadTask|dataTask/);
});

test('WidgetKit uses AudioPlaybackIntent and the shared app group', async () => {
  const command = await read('ios/SharedCompanion/CompanionCommand.swift');
  const widget = await read('ios/ZingChartWidget/ZingChartWidget.swift');
  const entitlement = await read(
    'ios/ZingChartWidget/ZingChartWidget.entitlements',
  );
  assert.match(command, /AudioPlaybackIntent/);
  assert.match(widget, /Button\(intent: ZingChartPlaybackIntent/);
  assert.match(widget, /ProgressView\(timerInterval:/);
  assert.match(widget, /supportedFamilies\(\[\.systemMedium\]\)/);
  assert.match(entitlement, /group\.software\.baycho\.zmp3chart\.shared/);
});

test('watchOS remote sends only local WatchConnectivity commands', async () => {
  const model = await read('ios/ZingChartWatch/WatchSessionModel.swift');
  const view = await read('ios/ZingChartWatch/WatchPlayerView.swift');
  assert.match(model, /WCSession\.default\.sendMessage/);
  assert.match(model, /didReceiveApplicationContext/);
  for (const action of ['previous', 'togglePlayPause', 'next']) {
    assert.match(view, new RegExp(`session\\.send\\("${action}"\\)`));
  }
  assert.doesNotMatch(model, /URLSession|https?:\/\//);
  const icons = await read(
    'ios/ZingChartWatch/Assets.xcassets/AppIcon.appiconset/Contents.json',
  );
  assert.match(icons, /"platform"\s*:\s*"watchos"/);
  assert.match(icons, /AppIcon-1024\.png/);
});

test('deterministic project preparation embeds both Apple targets', async () => {
  const script = await read('packaging/apple/prepare_ios_companions.rb');
  assert.match(script, /new_target\(:app_extension/);
  assert.match(script, /new_target\(:watch2_app/);
  assert.match(script, /Embed App Extensions/);
  assert.match(script, /Embed Watch Content/);
  assert.match(script, /CODE_SIGN_ENTITLEMENTS/);
  assert.match(script, /ASSETCATALOG_COMPILER_APPICON_NAME/);
  const macScript = await read('packaging/apple/prepare_macos_widget.rb');
  assert.match(macScript, /new_target\(:app_extension/);
  assert.match(macScript, /:osx/);
  assert.match(macScript, /Embed App Extensions/);
});

test('macOS widget shares state without a network transport', async () => {
  const window = await read('macos/Runner/MainFlutterWindow.swift');
  const widget = await read('macos/ZingChartWidget/ZingChartWidget.swift');
  assert.match(window, /software\.baycho\.zmp3chart\/companion/);
  assert.match(window, /reloadTimelines/);
  assert.match(window, /widgetSignature/);
  assert.match(widget, /ZingChartMacPlaybackIntent/);
  assert.match(widget, /ProgressView\(timerInterval:/);
  assert.doesNotMatch(window + widget, /URLSession|https?:\/\//);
});
