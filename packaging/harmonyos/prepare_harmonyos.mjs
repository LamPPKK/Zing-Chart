import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const [projectDirectory, version = '1.0.0', buildNumber = '1'] =
  process.argv.slice(2);
if (!projectDirectory) {
  throw new Error(
    'Usage: node prepare_harmonyos.mjs <project-dir> [x.y.z] [build-number]',
  );
}
if (!/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(version)) {
  throw new Error('HarmonyOS package version must use x.y.z numeric format.');
}
if (!/^[1-9]\d*$/.test(buildNumber) || Number(buildNumber) > 2147483647) {
  throw new Error(
    'HarmonyOS build number must be between 1 and 2147483647.',
  );
}

await updatePubspec();
await updateApplicationMetadata();
await updateModule();
await updateStrings();

async function updatePubspec() {
  const file = path.join(projectDirectory, 'pubspec.yaml');
  let source = await readFile(file, 'utf8');
  source = replaceRequired(
    source,
    /sdk:\s*["']>=3\.12\.0 <4\.0\.0["']/,
    'sdk: ">=3.11.0 <4.0.0"',
    'Dart SDK constraint',
  );
  source = replaceRequired(
    source,
    /^version:\s*[^\n]+$/m,
    `version: ${version}+${buildNumber}`,
    'Flutter package version',
  );
  await writeFile(file, source);
}

async function updateApplicationMetadata() {
  const file = path.join(projectDirectory, 'ohos', 'AppScope', 'app.json5');
  let source = await readFile(file, 'utf8');
  source = replaceRequired(
    source,
    /"vendor"\s*:\s*"[^"]*"/,
    '"vendor": "LamNDT"',
    'HarmonyOS vendor',
  );
  source = replaceRequired(
    source,
    /"versionCode"\s*:\s*\d+/,
    `"versionCode": ${buildNumber}`,
    'HarmonyOS versionCode',
  );
  source = replaceRequired(
    source,
    /"versionName"\s*:\s*"[^"]*"/,
    `"versionName": "${version}"`,
    'HarmonyOS versionName',
  );
  await writeFile(file, source);
}

async function updateModule() {
  const file = path.join(
    projectDirectory,
    'ohos',
    'entry',
    'src',
    'main',
    'module.json5',
  );
  let source = await readFile(file, 'utf8');
  source = replaceRequired(
    source,
    /"deviceTypes"\s*:\s*\[[\s\S]*?\]/,
    '"deviceTypes": [\n      "phone",\n      "tablet"\n    ]',
    'HarmonyOS device types',
  );
  if (!source.includes('"backgroundModes"')) {
    source = replaceRequired(
      source,
      /("exported"\s*:\s*true,)/,
      '$1\n        "backgroundModes": ["audioPlayback"],',
      'HarmonyOS EntryAbility',
    );
  }
  if (!source.includes('ohos.permission.KEEP_BACKGROUND_RUNNING')) {
    source = replaceRequired(
      source,
      /(\{\s*"name"\s*:\s*"ohos\.permission\.INTERNET"\s*\},?)/,
      `$1
      {
        "name": "ohos.permission.KEEP_BACKGROUND_RUNNING",
        "reason": "$string:background_running_reason",
        "usedScene": {
          "abilities": ["EntryAbility"],
          "when": "inuse"
        }
      }`,
      'HarmonyOS INTERNET permission',
    );
  }
  await writeFile(file, source);
}

async function updateStrings() {
  await updateStringResource(
    path.join(
      projectDirectory,
      'ohos',
      'AppScope',
      'resources',
      'base',
      'element',
      'string.json',
    ),
    { app_name: '#zingChart' },
  );
  const resourceRoot = path.join(
    projectDirectory,
    'ohos',
    'entry',
    'src',
    'main',
    'resources',
  );
  await updateStringResource(path.join(resourceRoot, 'base/element/string.json'), {
    module_desc: 'Trình phát nhạc #zingChart',
    EntryAbility_desc: 'Bảng xếp hạng và trình phát nhạc',
    EntryAbility_label: '#zingChart',
    background_running_reason:
      'Cho phép #zingChart tiếp tục phát nhạc trong nền.',
  });
  await updateStringResource(path.join(resourceRoot, 'en_US/element/string.json'), {
    module_desc: '#zingChart music player',
    EntryAbility_desc: 'Music chart and player',
    EntryAbility_label: '#zingChart',
    background_running_reason:
      'Allow #zingChart to continue playing music in the background.',
  });
  await updateStringResource(path.join(resourceRoot, 'zh_CN/element/string.json'), {
    module_desc: '#zingChart 音乐播放器',
    EntryAbility_desc: '音乐排行榜和播放器',
    EntryAbility_label: '#zingChart',
    background_running_reason: '允许 #zingChart 在后台继续播放音乐。',
  });
}

async function updateStringResource(file, values) {
  const document = JSON.parse(await readFile(file, 'utf8'));
  if (!Array.isArray(document.string)) {
    throw new Error(`Invalid HarmonyOS string resource: ${file}`);
  }
  for (const [name, value] of Object.entries(values)) {
    const existing = document.string.find((entry) => entry.name === name);
    if (existing) {
      existing.value = value;
    } else {
      document.string.push({ name, value });
    }
  }
  await writeFile(file, JSON.stringify(document, null, 2) + '\n');
}

function replaceRequired(source, pattern, replacement, label) {
  const updated = source.replace(pattern, replacement);
  if (updated === source) throw new Error(`${label} was not found.`);
  return updated;
}
