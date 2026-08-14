import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

const script = path.resolve(import.meta.dirname, 'prepare_harmonyos.mjs');

test('prepares phone/tablet metadata and background audio permissions', async () => {
  const project = await fixtureProject();
  const result = spawnSync(process.execPath, [script, project, '2.3.4', '42'], {
    encoding: 'utf8',
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);

  const pubspec = await readFile(path.join(project, 'pubspec.yaml'), 'utf8');
  assert.match(pubspec, /sdk: ">=3\.11\.0 <4\.0\.0"/);
  assert.match(pubspec, /version: 2\.3\.4\+42/);

  const app = await readFile(path.join(project, 'ohos/AppScope/app.json5'), 'utf8');
  assert.match(app, /"vendor": "LamNDT"/);
  assert.match(app, /"versionCode": 42/);
  assert.match(app, /"versionName": "2\.3\.4"/);

  const module = await readFile(
    path.join(project, 'ohos/entry/src/main/module.json5'),
    'utf8',
  );
  assert.match(module, /"phone"/);
  assert.match(module, /"tablet"/);
  assert.match(module, /"backgroundModes": \["audioPlayback"\]/);
  assert.match(module, /ohos\.permission\.INTERNET/);
  assert.match(module, /ohos\.permission\.KEEP_BACKGROUND_RUNNING/);
  assert.match(module, /\$string:background_running_reason/);

  const strings = JSON.parse(
    await readFile(
      path.join(
        project,
        'ohos/entry/src/main/resources/base/element/string.json',
      ),
    ),
  );
  assert.equal(valueOf(strings, 'EntryAbility_label'), '#zingChart');
  assert.match(valueOf(strings, 'background_running_reason'), /phát nhạc/);
  const appStrings = JSON.parse(
    await readFile(
      path.join(project, 'ohos/AppScope/resources/base/element/string.json'),
    ),
  );
  assert.equal(valueOf(appStrings, 'app_name'), '#zingChart');
});

test('pins reviewed HarmonyOS plugin forks by immutable commit', async () => {
  const overrides = await readFile(
    path.join(import.meta.dirname, 'pubspec_overrides.yaml'),
    'utf8',
  );
  const lock = await readFile(
    path.join(import.meta.dirname, 'pubspec.lock'),
    'utf8',
  );
  assert.match(overrides, /flutter_audioplayers\.git/);
  assert.match(overrides, /fluttertpc_audio_service\.git/);
  assert.match(overrides, /flutter_packages\.git/);
  assert.match(overrides, /3a3e22642fac78dedb5fd4364b5ca29bcb144365/);
  assert.match(overrides, /a9a26269ea04d77355f0d0aaad089ce6ac526fe5/);
  assert.match(overrides, /baa08b15565efccb870a6484ff6a31e7b7e5af74/);
  assert.match(overrides, /bd97a32d519c94772a4693d92cca88b145c6f4f3/);
  assert.match(overrides, /fd410050c6842717ee1b851ca7640c294de9568c/);
  assert.match(overrides, /19bd50ff6d5eaa96f18c63796c51e1b4e78a7480/);
  assert.doesNotMatch(overrides, /ref:\s*(master|main|br_)/);
  assert.match(lock, /dart: ">=3\.11\.0 <4\.0\.0"/);
  assert.match(lock, /resolved-ref: 3a3e22642fac78dedb5fd4364b5ca29bcb144365/);
  assert.match(lock, /resolved-ref: a9a26269ea04d77355f0d0aaad089ce6ac526fe5/);
  assert.match(lock, /  file_selector:\n    dependency: "direct main"/);
  assert.match(lock, /  share_plus:\n    dependency: "direct main"/);
  assert.match(lock, /  cross_file:/);
  assert.match(lock, /  file_selector_android:/);
  assert.match(lock, /  file_selector_ios:/);
  assert.match(lock, /  file_selector_web:/);
  assert.match(lock, /  share_plus_platform_interface:/);
  assert.doesNotMatch(lock, /\/private\/tmp|source: path/);
});

test('HarmonyOS pipeline builds a release arm64 HAP from an isolated runner', async () => {
  const buildScript = await readFile(
    path.join(import.meta.dirname, 'build_harmonyos.sh'),
    'utf8',
  );
  assert.match(buildScript, /create[\s\S]*--platforms=ohos/);
  assert.match(buildScript, /build hap/);
  assert.match(buildScript, /--release/);
  assert.match(buildScript, /--target-platform=ohos-arm64/);
  assert.match(buildScript, /DISTRIBUTION_CHANNEL=huawei/);
  assert.match(buildScript, /DEVECO_SDK_HOME/);
  assert.match(buildScript, /export HOS_SDK_HOME/);
  assert.match(buildScript, /Flutter\[\[:space:\]\]3\\\.41\\\.10/);
  assert.match(buildScript, /Dart\[\[:space:\]\]3\\\.11\\\.5/);
  assert.match(buildScript, /-name sdk-pkg\.json/);
  assert.match(buildScript, /apiVersion/);
  assert.match(buildScript, /OpenHarmony SDK directory alone/);
  assert.match(buildScript, /pubspec\.lock/);
  assert.match(buildScript, /pub get --enforce-lockfile/);
  assert.match(buildScript, /PUB_ATTEMPT >= 3/);
});

test('mobile release jobs reject bad versions and require Amazon signing', async () => {
  const workflow = await readFile(
    path.resolve(import.meta.dirname, '../../.github/workflows/release.yml'),
    'utf8',
  );
  assert.match(workflow, /Require Amazon production signing/);
  assert.match(workflow, /Missing required signing secret/);
  assert.match(workflow, /ANDROID_KEYSTORE_BASE64/);
  assert.match(workflow, /A Fire OS release requires an explicit x\.y\.z version/);
  assert.match(workflow, /A HarmonyOS release requires an explicit x\.y\.z version/);
  const fireJob = workflow.slice(
    workflow.indexOf('  fireos:'),
    workflow.indexOf('  harmonyos:'),
  );
  assert.doesNotMatch(fireJob, /VERSION="1\.0\.0"/);
  assert.doesNotMatch(
    fireJob.slice(0, fireJob.indexOf('    steps:')),
    /ANDROID_(KEYSTORE|KEY_ALIAS|KEY_PASSWORD|STORE_PASSWORD)/,
  );
});

test('rejects invalid HarmonyOS release versions', async () => {
  const project = await fixtureProject();
  const result = spawnSync(process.execPath, [script, project, '01.2.3', '0'], {
    encoding: 'utf8',
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /x\.y\.z numeric format/);
});

async function fixtureProject() {
  const project = await mkdtemp(path.join(os.tmpdir(), 'zingchart-harmony-test-'));
  await write(project, 'pubspec.yaml', `name: zmp3chart
environment:
  sdk: ">=3.12.0 <4.0.0"
version: 1.0.0+1
`);
  await write(project, 'ohos/AppScope/app.json5', `{
  "app": {
    "bundleName": "software.baycho.zmp3chart",
    "vendor": "example",
    "versionCode": 1000000,
    "versionName": "1.0.0"
  }
}
`);
  await write(project, 'ohos/entry/src/main/module.json5', `{
  "module": {
    "name": "entry",
    "deviceTypes": [
      "phone"
    ],
    "abilities": [
      {
        "name": "EntryAbility",
        "exported": true,
        "skills": []
      }
    ],
    "requestPermissions": [
      {"name" :  "ohos.permission.INTERNET"},
    ]
  }
}
`);
  await writeStrings(
    project,
    'ohos/AppScope/resources/base/element/string.json',
    [{ name: 'app_name', value: 'zmp3chart' }],
  );
  const entryStrings = [
    { name: 'module_desc', value: 'module description' },
    { name: 'EntryAbility_desc', value: 'description' },
    { name: 'EntryAbility_label', value: 'zmp3chart' },
  ];
  for (const locale of ['base', 'en_US', 'zh_CN']) {
    await writeStrings(
      project,
      `ohos/entry/src/main/resources/${locale}/element/string.json`,
      entryStrings,
    );
  }
  return project;
}

async function writeStrings(project, relativePath, values) {
  await write(project, relativePath, JSON.stringify({ string: values }, null, 2));
}

async function write(project, relativePath, contents) {
  const file = path.join(project, relativePath);
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, contents);
}

function valueOf(document, name) {
  return document.string.find((entry) => entry.name === name)?.value;
}
