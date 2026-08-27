import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';

const root = path.resolve(import.meta.dirname, '../..');
const releasePath = path.join(root, '.github/workflows/release.yml');
const ciPath = path.join(root, '.github/workflows/ci.yml');

const between = (source, start, end) => {
  const startIndex = source.indexOf(start);
  const endIndex = source.indexOf(end, startIndex + start.length);
  assert.notEqual(startIndex, -1, `Missing workflow marker: ${start}`);
  assert.notEqual(endIndex, -1, `Missing workflow marker: ${end}`);
  return source.slice(startIndex, endIndex);
};

test('release builds distinct universal and forced-TV Android artifacts', async () => {
  const release = await readFile(releasePath, 'utf8');
  const androidJob = between(release, '  android:', '  fireos:');
  const universalBuild = between(
    androidJob,
    '      - name: Build universal Android APK and AAB',
    '      - name: Build dedicated Android TV sideload APK',
  );
  const tvBuild = between(
    androidJob,
    '      - name: Build dedicated Android TV sideload APK',
    '      - name: Build Wear OS remote',
  );

  const universalCommands =
    universalBuild.match(/flutter build (?:apk|appbundle)[^\n]+/g) ?? [];
  assert.equal(universalCommands.length, 2);
  assert.match(universalCommands[0], /flutter build apk/);
  assert.match(universalCommands[1], /flutter build appbundle/);
  for (const command of universalCommands) {
    assert.match(command, /--build-name="\$ANDROID_VERSION"/);
    assert.match(command, /--build-number="\$ANDROID_BUILD_NUMBER"/);
    assert.doesNotMatch(command, /TV_MODE=true/);
  }

  const tvCommands = tvBuild.match(/flutter build apk[^\n]+/g) ?? [];
  assert.equal(tvCommands.length, 1);
  assert.match(tvCommands[0], /--build-name="\$ANDROID_VERSION"/);
  assert.match(tvCommands[0], /--build-number="\$ANDROID_BUILD_NUMBER"/);
  assert.match(tvCommands[0], /--dart-define=TV_MODE=true/);
  assert.equal(
    (androidJob.match(/flutter build (?:apk|appbundle)[^\n]+/g) ?? []).length,
    3,
  );

  assert.match(
    universalBuild,
    /cp build\/app\/outputs\/flutter-apk\/app-release\.apk dist\/android\/zingchart-android-universal\.apk/,
  );
  assert.match(
    universalBuild,
    /cp build\/app\/outputs\/bundle\/release\/app-release\.aab dist\/android\/zingchart-android-universal\.aab/,
  );
  assert.match(
    tvBuild,
    /cp build\/app\/outputs\/flutter-apk\/app-release\.apk dist\/android\/zingchart-android-tv\.apk/,
  );
  assert.doesNotMatch(androidJob, /zingchart-android-tv\.aab/);

  const uploadIndex = androidJob.indexOf('actions/upload-artifact@v4');
  assert.notEqual(uploadIndex, -1);
  const upload = androidJob.slice(uploadIndex);
  assert.doesNotMatch(upload, /build\/app\/outputs/);
  assert.deepEqual(
    [...upload.matchAll(/^ {12}(dist\/android\/\S+)$/gm)].map(
      (match) => match[1],
    ),
    [
      'dist/android/zingchart-android-universal.apk',
      'dist/android/zingchart-android-universal.aab',
      'dist/android/zingchart-android-tv.apk',
      'dist/android/zingchart-wearos-remote.apk',
    ],
  );
});

test(
  'release validates Android version metadata and signing as complete sets',
  async () => {
    const release = await readFile(releasePath, 'utf8');
    const androidJob = between(release, '  android:', '  fireos:');
    const metadataStep = between(
      androidJob,
      '      - name: Resolve Android release metadata',
      '      - name: Validate Android signing configuration',
    );
    const signingStep = between(
      androidJob,
      '      - name: Validate Android signing configuration',
      '      - name: Configure Android release signing',
    );

    assert.match(
      metadataStep,
      /RELEASE_VERSION: \$\{\{ inputs\.version \|\| github\.ref_name \}\}/,
    );
    assert.match(metadataStep, /VERSION="\$RELEASE_VERSION"/);
    const runIndex = metadataStep.indexOf('        run: |');
    assert.notEqual(runIndex, -1);
    const metadataScript = metadataStep.slice(runIndex);
    assert.doesNotMatch(metadataScript, /\$\{\{ inputs\.version/);
    assert.match(androidJob, /VERSION="\$\{VERSION#v\}"/);
    assert.match(
      androidJob,
      /An Android release requires an explicit x\.y\.z version/,
    );
    assert.match(androidJob, /GITHUB_RUN_NUMBER must be a positive integer/);
    assert.match(androidJob, /GITHUB_RUN_NUMBER <= 2100000000/);
    assert.match(androidJob, /ANDROID_VERSION=\$VERSION/);
    assert.match(androidJob, /ANDROID_BUILD_NUMBER=\$GITHUB_RUN_NUMBER/);
    assert.match(
      signingStep,
      /for name in ANDROID_KEYSTORE_BASE64 ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD ANDROID_STORE_PASSWORD/,
    );
    assert.match(signingStep, /configured != 0 && configured != 4/);
    assert.match(
      signingStep,
      /Configure all four Android signing secrets together[^\n]+\n {12}exit 78/,
    );
    assert.match(signingStep, /ANDROID_SIGNING_ENABLED=true/);
    assert.match(signingStep, /ANDROID_SIGNING_ENABLED=false/);
    assert.match(
      androidJob,
      /if: \$\{\{ env\.ANDROID_SIGNING_ENABLED == 'true' \}\}/,
    );
  },
);

test('CI and release quality gates execute Android and TV packaging tests', async () => {
  for (const [workflowPath, nextJob] of [
    [ciPath, '  web-smoke:'],
    [releasePath, '  proxy:'],
  ]) {
    const workflow = await readFile(workflowPath, 'utf8');
    const qualityJob = between(workflow, '  quality:', nextJob);
    assert.match(qualityJob, /packaging\/android\/\*\.test\.mjs/);
    assert.match(qualityJob, /packaging\/tv\/\*\.test\.mjs/);
    assert.match(qualityJob, /packaging\/tv\/build_tv_web\.sh/);
    assert.match(qualityJob, /packaging\/tv\/package_tizen\.sh/);
  }
});
