import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const repositoryRoot = path.resolve(import.meta.dirname, '../..');
const generator = path.join(repositoryRoot, 'tool/generate_brand_assets.mjs');

test('keeps every generated #zingChart brand asset in sync', () => {
  const result = spawnSync(process.execPath, [generator, '--check'], {
    cwd: repositoryRoot,
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /Brand assets are current/);
});

test('uses an opaque original mark and a smaller maskable safe zone', async () => {
  const icon = await readFile(path.join(repositoryRoot, 'web/icons/Icon-512.png'));
  const maskable = await readFile(
    path.join(repositoryRoot, 'web/icons/Icon-maskable-512.png'),
  );
  assertPng(icon, 512, 512);
  assertPng(maskable, 512, 512);
  assert.equal(icon[25], 2, 'PWA icon must be opaque RGB without alpha');
  assert.notDeepEqual(icon, maskable);

  const svg = await readFile(
    path.join(repositoryRoot, 'assets/brand/zingchart-mark.svg'),
    'utf8',
  );
  assert.match(svg, /#FF6B4A/);
  assert.match(svg, /#B8F43D/);
  assert.match(svg, /coral hash crossed by a lime audio pulse/i);
  assert.doesNotMatch(svg, /Flutter|Spotify/i);
});

test('ships Apple RGB icons, Windows ICO sizes and Android adaptive layers', async () => {
  const apple = await readFile(
    path.join(
      repositoryRoot,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    ),
  );
  assertPng(apple, 1024, 1024);
  assert.equal(apple[25], 2, 'Apple marketing icon must not contain alpha');

  const mac = await readFile(
    path.join(
      repositoryRoot,
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
    ),
  );
  assertPng(mac, 1024, 1024);
  assert.equal(mac[25], 6, 'macOS Dock icon must preserve transparent corners');

  const ico = await readFile(
    path.join(repositoryRoot, 'windows/runner/resources/app_icon.ico'),
  );
  assert.equal(ico.readUInt16LE(0), 0);
  assert.equal(ico.readUInt16LE(2), 1);
  assert.equal(ico.readUInt16LE(4), 7);
  assert.deepEqual(
    Array.from({ length: 7 }, (_, index) => ico[6 + index * 16] || 256),
    [16, 24, 32, 48, 64, 128, 256],
  );

  const adaptive = await readFile(
    path.join(
      repositoryRoot,
      'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml',
    ),
    'utf8',
  );
  assert.match(adaptive, /@drawable\/ic_launcher_foreground/);
  assert.match(adaptive, /@drawable\/ic_launcher_monochrome/);

  const splash = await readFile(
    path.join(
      repositoryRoot,
      'android/app/src/main/res/values-v31/styles.xml',
    ),
    'utf8',
  );
  assert.match(splash, /windowSplashScreenAnimatedIcon/);
  assert.match(splash, /@drawable\/launch_mark/);
});

function assertPng(buffer, width, height) {
  assert.deepEqual([...buffer.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
  assert.equal(buffer.readUInt32BE(16), width);
  assert.equal(buffer.readUInt32BE(20), height);
}
