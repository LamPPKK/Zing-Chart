import assert from 'node:assert/strict';
import { chmod, mkdtemp, mkdir, readFile, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const script = path.resolve(import.meta.dirname, 'build_fireos.sh');

test('builds a touch-device Fire OS APK with release metadata', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'zingchart-fireos-test-'));
  const flutter = path.join(root, 'fake-flutter');
  await writeFile(
    flutter,
    `#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > flutter-arguments.txt
mkdir -p build/app/outputs/flutter-apk
printf 'fake-apk' > build/app/outputs/flutter-apk/app-release.apk
`,
  );
  await chmod(flutter, 0o755);

  const result = spawnSync(
    'bash',
    [script, 'https://proxy.example.com', '2.3.4'],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        FIREOS_PROJECT_ROOT: root,
        FIREOS_FLUTTER_BIN: flutter,
        FIREOS_BUILD_NUMBER: '42',
      },
    },
  );
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.equal(
    await readFile(
      path.join(root, 'dist/fireos/zingchart-fireos-2.3.4-development.apk'),
      'utf8',
    ),
    'fake-apk',
  );
  const argumentsText = await readFile(
    path.join(root, 'flutter-arguments.txt'),
    'utf8',
  );
  assert.match(argumentsText, /--build-name=2\.3\.4/);
  assert.match(argumentsText, /--build-number=84/);
  assert.match(argumentsText, /DISTRIBUTION_CHANNEL=amazon/);
  assert.doesNotMatch(argumentsText, /TV_MODE=true/);
  assert.match(argumentsText, /API_BASE_URL=https:\/\/proxy\.example\.com/);
});

test('builds a dedicated Fire TV APK with forced 10-foot UI', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'zingchart-firetv-test-'));
  const flutter = path.join(root, 'fake-flutter');
  await writeFile(
    flutter,
    `#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > flutter-arguments.txt
mkdir -p build/app/outputs/flutter-apk
printf 'fake-firetv-apk' > build/app/outputs/flutter-apk/app-release.apk
`,
  );
  await chmod(flutter, 0o755);

  const result = spawnSync(
    'bash',
    [script, 'https://proxy.example.com', '2.3.4', 'tv'],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        FIREOS_PROJECT_ROOT: root,
        FIREOS_FLUTTER_BIN: flutter,
        FIREOS_BUILD_NUMBER: '42',
      },
    },
  );
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.equal(
    await readFile(
      path.join(root, 'dist/firetv/zingchart-firetv-2.3.4-development.apk'),
      'utf8',
    ),
    'fake-firetv-apk',
  );
  const argumentsText = await readFile(
    path.join(root, 'flutter-arguments.txt'),
    'utf8',
  );
  assert.match(argumentsText, /--build-name=2\.3\.4/);
  assert.match(argumentsText, /--build-number=85/);
  assert.match(argumentsText, /DISTRIBUTION_CHANNEL=amazon-fire-tv/);
  assert.match(argumentsText, /TV_MODE=true/);
});

test('rejects unknown Fire OS targets before building', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'zingchart-fireos-test-'));
  const result = spawnSync(
    'bash',
    [script, 'https://proxy.example.com', '2.3.4', 'watch'],
    {
      encoding: 'utf8',
      env: { ...process.env, FIREOS_PROJECT_ROOT: root },
    },
  );
  assert.equal(result.status, 64);
  assert.match(result.stderr, /either 'touch' or 'tv'/);
});

test('rejects a sequence that cannot produce valid Android version codes', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'zingchart-fireos-test-'));
  const result = spawnSync(
    'bash',
    [script, 'https://proxy.example.com', '2.3.4', 'tv'],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        FIREOS_PROJECT_ROOT: root,
        FIREOS_BUILD_NUMBER: '1050000000',
      },
    },
  );
  assert.equal(result.status, 64);
  assert.match(result.stderr, /too large/);
});

test('wires Fire TV compatibility metadata and both CI artifacts', async () => {
  const projectRoot = path.resolve(import.meta.dirname, '../..');
  const manifest = await readFile(
    path.join(projectRoot, 'android/app/src/main/AndroidManifest.xml'),
    'utf8',
  );
  assert.match(manifest, /android\.software\.leanback/);
  assert.match(manifest, /android\.hardware\.touchscreen/);
  assert.match(manifest, /android\.hardware\.faketouch/);
  assert.match(manifest, /android:required="false"/);
  assert.match(manifest, /android\.intent\.category\.LEANBACK_LAUNCHER/);
  assert.match(manifest, /android:banner="@drawable\/tv_banner"/);

  const ci = await readFile(
    path.join(projectRoot, '.github/workflows/ci.yml'),
    'utf8',
  );
  assert.match(ci, /build_fireos\.sh "\$API_BASE_URL" 1\.0\.0 tv/);
  assert.match(ci, /dist\/firetv\/zingchart-firetv-1\.0\.0-development\.apk/);

  const release = await readFile(
    path.join(projectRoot, '.github/workflows/release.yml'),
    'utf8',
  );
  const fireJob = release.slice(
    release.indexOf('  fireos:'),
    release.indexOf('  harmonyos:'),
  );
  assert.match(fireJob, /build_fireos\.sh "\$API_BASE_URL" "\$VERSION" tv/);
  assert.match(fireJob, /dist\/firetv\/\*\.apk/);
  assert.match(fireJob, /FIREOS_REQUIRE_PRODUCTION_SIGNING: '1'/);
});

test('rejects insecure Fire OS release configuration before building', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'zingchart-fireos-test-'));
  await mkdir(root, { recursive: true });
  const result = spawnSync('bash', [script, 'http://proxy.example.com'], {
    encoding: 'utf8',
    env: { ...process.env, FIREOS_PROJECT_ROOT: root },
  });
  assert.equal(result.status, 64);
  assert.match(result.stderr, /HTTPS API_BASE_URL/);
});

test('fails closed when a production Amazon build has no signing config', async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'zingchart-fireos-test-'));
  const flutter = path.join(root, 'fake-flutter');
  await writeFile(flutter, '#!/usr/bin/env bash\nexit 0\n');
  await chmod(flutter, 0o755);
  const result = spawnSync(
    'bash',
    [script, 'https://proxy.example.com', '2.3.4'],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        FIREOS_PROJECT_ROOT: root,
        FIREOS_FLUTTER_BIN: flutter,
        FIREOS_REQUIRE_PRODUCTION_SIGNING: '1',
      },
    },
  );
  assert.equal(result.status, 78);
  assert.match(result.stderr, /android\/key\.properties/);
});
