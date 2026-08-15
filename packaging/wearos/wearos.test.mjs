import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relative) => readFile(path.join(root, relative), 'utf8');

test('Android and Wear OS use one signed application identity', async () => {
  const handheld = await read('android/app/build.gradle.kts');
  const watch = await read('android/wear/build.gradle.kts');
  assert.match(handheld, /applicationId = "software\.baycho\.zmp3chart"/);
  assert.match(watch, /applicationId = "software\.baycho\.zmp3chart"/);
  assert.match(watch, /rootProject\.file\(\s*"app\/\$\{keystoreProperties/);
  assert.match(watch, /play-services-wearable:20\.0\.1/);
});

test('watch RPC and state paths match the handheld listener', async () => {
  const state = await read(
    'android/app/src/main/kotlin/software/baycho/zmp3chart/CompanionStateStore.kt',
  );
  const listener = await read(
    'android/app/src/main/kotlin/software/baycho/zmp3chart/ZingChartWearListenerService.kt',
  );
  const watch = await read(
    'android/wear/src/main/kotlin/software/baycho/zmp3chart/watch/MainActivity.kt',
  );
  for (const source of [state, watch]) {
    assert.match(source, /\/zingchart\/player/);
    assert.match(source, /\/zingchart\/command/);
  }
  assert.match(listener, /MediaControlIntents\.send/);
  assert.match(state, /Google Play services is optional/);
});

test('home widget is registered and controls the shared media session', async () => {
  const manifest = await read('android/app/src/main/AndroidManifest.xml');
  const provider = await read(
    'android/app/src/main/kotlin/software/baycho/zmp3chart/ZingChartWidgetProvider.kt',
  );
  const media = await read(
    'android/app/src/main/kotlin/software/baycho/zmp3chart/MediaControlIntents.kt',
  );
  assert.match(manifest, /\.ZingChartWidgetProvider/);
  assert.match(manifest, /@xml\/zingchart_widget_info/);
  assert.match(provider, /KEYCODE_MEDIA_PLAY_PAUSE/);
  assert.match(provider, /KEYCODE_MEDIA_PREVIOUS/);
  assert.match(provider, /KEYCODE_MEDIA_NEXT/);
  assert.match(media, /com\.ryanheise\.audioservice\.MediaButtonReceiver/);
});

test('CI and release workflows build the Wear OS artifact', async () => {
  const ci = await read('.github/workflows/ci.yml');
  const release = await read('.github/workflows/release.yml');
  assert.match(ci, /:wear:assembleRelease/);
  assert.match(release, /:wear:assembleRelease/);
  assert.match(release, /zingchart-wearos-remote\.apk/);
});
