import { copyFile, cp, mkdir, readFile, writeFile } from 'node:fs/promises';
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
await installBrandAssets();
await updateModule();
await updateStrings();
await installServiceWidget();

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
  if (/"icon"\s*:/.test(source)) {
    source = source.replace(
      /"icon"\s*:\s*"[^"]*"/,
      '"icon": "$media:app_icon"',
    );
  } else {
    source = replaceRequired(
      source,
      /("versionName"\s*:\s*"[^"]*")\s*,?/,
      '$1,\n    "icon": "$media:app_icon"',
      'HarmonyOS app icon insertion point',
    );
  }
  await writeFile(file, source);
}

async function installBrandAssets() {
  const source = path.join(import.meta.dirname, 'app_icon.png');
  const mediaDirectory = path.join(
    projectDirectory,
    'ohos',
    'AppScope',
    'resources',
    'base',
    'media',
  );
  await mkdir(mediaDirectory, { recursive: true });
  await copyFile(source, path.join(mediaDirectory, 'app_icon.png'));
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
  if (!source.includes('"scheme": "zingchart"')) {
    source = replaceRequired(
      source,
      /"skills"\s*:\s*\[\s*\]/,
      `"skills": [
          {
            "entities": ["entity.system.browsable"],
            "actions": ["ohos.want.action.viewData"],
            "uris": [
              {
                "scheme": "zingchart",
                "host": "open"
              }
            ]
          }
        ]`,
      'HarmonyOS zingchart URL skill',
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
  if (!source.includes('EntryFormAbility')) {
    source = replaceRequired(
      source,
      /("requestPermissions"\s*:)/,
      `"extensionAbilities": [
      {
        "name": "EntryFormAbility",
        "srcEntry": "./ets/entryformability/EntryFormAbility.ets",
        "label": "$string:form_name",
        "description": "$string:form_desc",
        "type": "form",
        "metadata": [
          {
            "name": "ohos.extension.form",
            "resource": "$profile:form_config"
          }
        ]
      }
    ],
    $1`,
      'HarmonyOS requestPermissions section',
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
    form_name: '#zingChart đang phát',
    form_desc: 'Điều khiển nhạc từ màn hình chính',
    form_no_song: 'Chưa chọn bài hát',
    form_previous: 'Bài trước',
    form_play: 'Phát',
    form_pause: 'Tạm dừng',
    form_next: 'Bài tiếp theo',
  });
  await updateStringResource(path.join(resourceRoot, 'en_US/element/string.json'), {
    module_desc: '#zingChart music player',
    EntryAbility_desc: 'Music chart and player',
    EntryAbility_label: '#zingChart',
    background_running_reason:
      'Allow #zingChart to continue playing music in the background.',
    form_name: '#zingChart Now Playing',
    form_desc: 'Control music from the home screen',
    form_no_song: 'Choose a song in the app',
    form_previous: 'Previous',
    form_play: 'Play',
    form_pause: 'Pause',
    form_next: 'Next',
  });
  await updateStringResource(path.join(resourceRoot, 'zh_CN/element/string.json'), {
    module_desc: '#zingChart 音乐播放器',
    EntryAbility_desc: '音乐排行榜和播放器',
    EntryAbility_label: '#zingChart',
    background_running_reason: '允许 #zingChart 在后台继续播放音乐。',
    form_name: '#zingChart 正在播放',
    form_desc: '从主屏幕控制音乐',
    form_no_song: '请在应用中选择歌曲',
    form_previous: '上一首',
    form_play: '播放',
    form_pause: '暂停',
    form_next: '下一首',
  });
}

async function installServiceWidget() {
  const source = path.join(import.meta.dirname, 'service_widget');
  const entryRoot = path.join(projectDirectory, 'ohos', 'entry', 'src', 'main');
  await cp(path.join(source, 'ets'), path.join(entryRoot, 'ets'), {
    recursive: true,
    force: true,
  });
  await cp(path.join(source, 'resources'), path.join(entryRoot, 'resources'), {
    recursive: true,
    force: true,
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
