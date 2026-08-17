# #zingChart

[Tiếng Việt](README.md) · [English](README.en.md) · [简体中文](README.zh-CN.md)

文档维护以上三种语言。Flutter 主界面目前以越南语为默认语言；原生桌面组件与
手表遥控器会根据系统语言选择越南语、英语或简体中文标签。

#zingChart 是使用 Flutter 开发的 Local-First 音乐排行榜与播放器。一个代码库
覆盖 Android、Android TV、iOS/iPadOS、Web/PWA、Windows、macOS、Linux、
Amazon Fire OS/Fire TV、LG webOS TV、Samsung Tizen TV 和 HarmonyOS。
客户端不会直接请求 Zing 上游；排行榜数据与音频统一经过自托管 Node 代理。

## 功能

- 实时 Zing Chart：排名、封面、歌曲名和歌手。
- 搜索、播放/暂停/停止、进度跳转、上一首/下一首、随机、循环、队列和睡眠定时。
- 系统支持范围内的后台播放、锁屏与系统媒体控制。
- 本地收藏、个人歌单、收听历史、最近搜索、Daily/Mood Mix、7/30 天及年度统计。
- 全年可查看的六页 Mini Wrapped，并可导出 PNG 或 TV 本地二维码摘要。
- JSON v2 备份，支持幂等合并与完全覆盖，也能读取 v1。
- 手机、平板、桌面和电视自适应 UI，保留 charcoal/coral/lime 视觉语言。

在获得合法音源和存储许可前，不提供离线音频下载。PWA 只缓存应用外壳和非音频数据。

## 按版本展示界面

以下图片由当前 UI 使用稳定、完全本地的演示数据渲染，再按功能里程碑分组。
它们不是旧版本二进制文件的历史截图，也不包含真实用户数据。

### v1.0 — 排行榜、播放器与跨平台音乐库

<table>
  <tr>
    <td width="33%" align="center"><img src="docs/screenshots/v1.0-home-mobile.png" alt="手机端实时 ZingChart 首页"><br><sub><b>首页</b> · 实时排行榜与 Daily Mix</sub></td>
    <td width="33%" align="center"><img src="docs/screenshots/v1.0-search-mobile.png" alt="手机端音乐搜索"><br><sub><b>搜索</b> · 歌曲、歌手与最近关键词</sub></td>
    <td width="33%" align="center"><img src="docs/screenshots/v1.0-now-playing-mobile.png" alt="手机端正在播放界面"><br><sub><b>正在播放</b> · 进度、队列、心情与睡眠定时</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/v1.0-library-mobile.png" alt="手机端 Local-First 音乐库"><br><sub><b>音乐库</b> · 收藏、歌单与本地备份</sub></td>
    <td colspan="2" align="center"><img src="docs/screenshots/v1.0-desktop-player.png" alt="包含正在播放和队列面板的桌面自适应界面"><br><sub><b>桌面自适应</b> · 排行榜、正在播放与队列同屏</sub></td>
  </tr>
</table>

### v1.1 — Local Intelligence

<table>
  <tr>
    <td width="33%" align="center"><img src="docs/screenshots/v1.1-for-you-mobile.png" alt="为你推荐中的 Daily Mix 和 Mood Mix"><br><sub><b>为你推荐</b> · 设备端 Daily Mix 与 Mood Mix</sub></td>
    <td width="33%" align="center"><img src="docs/screenshots/v1.1-analytics-mobile.png" alt="本地收听统计面板"><br><sub><b>统计</b> · 7 天、30 天与年度视图</sub></td>
    <td width="33%" align="center"><img src="docs/screenshots/v1.1-wrapped-mobile.png" alt="可导出图片的 Mini Wrapped"><br><sub><b>Mini Wrapped</b> · 六页总结与 PNG 导出</sub></td>
  </tr>
  <tr>
    <td colspan="3" align="center"><img src="docs/screenshots/v1.1-tv-for-you.png" alt="带遥控焦点与播放器面板的电视端为你推荐界面"><br><sub><b>电视 10-foot UI</b> · 遥控导航、本地 Mix 与播放器面板</sub></td>
  </tr>
</table>

用于重建图片库的稳定 fixture 位于
[`tool/docs_screenshot_app.dart`](tool/docs_screenshot_app.dart)。该入口不会
请求代理、真实音频或操作系统媒体服务。

## 桌面组件与智能手表

| 界面 | 最低版本/支持范围 | 控制 |
| --- | --- | --- |
| Android 桌面组件 | Android 手机/平板 | 上一首、播放/暂停、下一首 |
| Fire OS 平板 | 已包含在 Android APK；是否可添加取决于 Launcher | 上一首、播放/暂停、下一首 |
| iOS/iPadOS WidgetKit | iOS/iPadOS 17+ | App Intent 交互控制 |
| macOS WidgetKit | macOS 14+ | 上一首、播放/暂停、下一首 |
| HarmonyOS 服务卡片 | HarmonyOS 5.1/API 18 | 上一首、播放/暂停、下一首 |
| Wear OS 遥控器 | Wear OS 3+，与 Android 配对 | Data Layer 本地 RPC |
| watchOS 遥控器 | watchOS 10+，与 iPhone 配对 | WatchConnectivity 本地 RPC |
| Windows/Linux/Web/TV | v1 没有统一桌面组件 API | 使用现有 SMTC、MPRIS、Media Session 或 TV 遥控 |

所有组件和手表只接收节流后的版本化播放状态及控制指令，不接收历史、收藏、
流地址或分析数据，也不会把手表数据发送到代理。

## 架构

```text
Flutter UI + PlaybackService
        │
        ├── SystemMediaBridge → 锁屏 / SMTC / MPRIS / Media Session
        ├── CompanionBridge   → 桌面组件 / Wear OS / watchOS
        └── MusicRepository   → 自托管 Node/Fastify 代理
                                      │
                                      └── 签名音频中继 → Zing 上游
```

主要目录：`lib/` 为 Flutter 应用，`proxy/` 为代理，`android/wear/` 为
Wear OS，`ios/ZingChartWatch/` 和 `ios/ZingChartWidget/` 为 Apple 配套目标，
`macos/ZingChartWidget/` 为 macOS 组件，`packaging/` 为各平台打包脚本。

## 环境要求

- Git、FVM、Flutter `3.44.7` 与随附 Dart `3.12.2`。
- Node.js `22+` 或 Docker；一个设备可访问的代理 URL，正式版必须 HTTPS。
- Android：Android SDK 36、JDK 17+。
- Apple：macOS、完整 Xcode、CocoaPods、Ruby gem `xcodeproj 1.27.0`。
- Windows：Visual Studio 2022 与 Desktop development with C++。
- Linux：Clang、CMake、Ninja、GTK 3、LZMA 和 GStreamer 开发包。
- HarmonyOS：CPF-Flutter `3.41.10-ohos-1.0.0`、Dart `3.11.5`、
  DevEco 工具及 HarmonyOS SDK 5.1/API 18。

## 首次安装与本地运行

```sh
git clone https://github.com/LamPPKK/Zing-Chart.git
cd Zing-Chart
fvm install 3.44.7
fvm use 3.44.7
fvm flutter pub get
```

启动开发代理：

```sh
cd proxy
cp .env.example .env
set -a
. ./.env
set +a
npm ci
npm run dev
```

在另一个终端验证并运行客户端：

```sh
curl http://localhost:8080/health
curl http://localhost:8080/v1/chart
cd ..
fvm flutter devices
fvm flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://localhost:8080
```

真机、电视和正式版应使用设备可访问的 HTTPS 代理。
`https://api.example.invalid` 只是安全诊断占位符，不会回退为直连 Zing。

## 测试

```sh
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test --reporter expanded

cd proxy
npm ci
npm run typecheck
npm test
npm run build
cd ..

node --test \
  packaging/apple/*.test.mjs \
  packaging/fireos/*.test.mjs \
  packaging/harmonyos/*.test.mjs \
  packaging/tv/*.test.mjs \
  packaging/wearos/*.test.mjs
```

## 各平台构建

以下命令中的 URL 和版本需替换为真实值：

```sh
API_BASE_URL=https://proxy.example.com
VERSION=1.1.0
```

### Android、Android TV 与桌面组件

```sh
fvm flutter build apk --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
fvm flutter build appbundle --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
```

输出位于 `build/app/outputs/flutter-apk/app-release.apk` 和
`build/app/outputs/bundle/release/app-release.aab`。APK 已包含桌面组件和可选
Leanback 入口。电视侧载测试可增加 `--dart-define=TV_MODE=true`。

正式签名需把 keystore 放在 `android/app/release.jks`，并创建不纳入 Git 的
`android/key.properties`：

```properties
storeFile=release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```

### Wear OS 遥控器

先构建 Android 应用以生成共享版本信息，再运行：

```sh
./android/gradlew -p android :wear:assembleRelease
```

输出：`build/wear/outputs/apk/release/wear-release.apk`。手机与手表 APK 使用
同一个 application ID `software.baycho.zmp3chart`，并且必须由同一证书签名。
分别安装到已配对的设备，先打开手机应用，再启动手表上的 **#zingChart Remote**。

### iOS/iPadOS WidgetKit 与 watchOS

```sh
gem install xcodeproj -v 1.27.0 --no-document
ruby packaging/apple/prepare_ios_companions.rb
fvm flutter build ios --release --no-codesign \
  --dart-define=API_BASE_URL="$API_BASE_URL"
```

`Runner.app` 会嵌入 `ZingChartWidget.appex` 和 `ZingChartWatch.app`。签名发布需注册：

- App Group：`group.software.baycho.zmp3chart.shared`；
- bundle ID：`software.baycho.zmp3chart.widget`；
- bundle ID：`software.baycho.zmp3chart.watchkitapp`；
- Runner、Widget、Watch 三个独立 provisioning profile，归属同一 Team。

交互组件要求 iOS/iPadOS 17+，手表遥控器要求 watchOS 10+。手表只控制
iPhone 播放，不下载音频。

### Web/PWA

```sh
fvm flutter build web --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
python3 -m http.server 8081 --directory build/web
```

以 HTTPS 部署 `build/web/`，并把未知路由回退到 `index.html`。浏览器自动播放和
后台限制仍然有效；关闭标签页会停止播放。

### Windows

仅在 Windows 构建：

```powershell
flutter config --enable-windows-desktop
flutter build windows --release `
  --dart-define=API_BASE_URL="https://proxy.example.com"
.\packaging\windows\package_windows.ps1 -Version 1.1.0
.\packaging\windows\package_msix.ps1 -Version 1.1.0
```

这是打包后的 Flutter Win32 应用，不是 UWP runner。系统控制使用 SMTC；v1 不包含
Windows Widget provider。

### macOS 与 WidgetKit

```sh
fvm flutter config --enable-macos-desktop
gem install xcodeproj -v 1.27.0 --no-document
ruby packaging/apple/prepare_macos_widget.rb
fvm flutter build macos --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
./packaging/macos/package_macos.sh
```

组件要求 macOS 14+ 和共享 App Group。公开分发还需 Developer ID 签名、
hardened runtime、公证和 stapling。

### Linux x64

```sh
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev \
  liblzma-dev libfuse2 libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev
fvm flutter build linux --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
./packaging/linux/package_linux.sh "$VERSION"
```

脚本生成 portable tar.gz 与 DEB；提供已验证的 `LINUXDEPLOY` 时再生成 AppImage。

### Amazon Fire OS 与 Fire TV

```sh
FIREOS_FLUTTER_BIN="$(fvm which flutter)" FIREOS_BUILD_NUMBER=1 \
  ./packaging/fireos/build_fireos.sh "$API_BASE_URL" "$VERSION" touch
FIREOS_FLUTTER_BIN="$(fvm which flutter)" FIREOS_BUILD_NUMBER=1 \
  ./packaging/fireos/build_fireos.sh "$API_BASE_URL" "$VERSION" tv
```

Touch/TV 的 versionCode 分别为 `2N` 和 `2N+1`。Fire TV 不提供桌面组件；
Fire 平板能否放置组件取决于 Amazon Launcher。

### LG webOS 与 Samsung Tizen TV

```sh
TV_FLUTTER_BIN="$(fvm which flutter)" \
  ./packaging/tv/build_tv_web.sh webos "$API_BASE_URL" "$VERSION"
TV_FLUTTER_BIN="$(fvm which flutter)" \
  ./packaging/tv/build_tv_web.sh tizen "$API_BASE_URL" "$VERSION"
./packaging/tv/package_tizen.sh YOUR_SAMSUNG_CERT_PROFILE
```

webOS 需要 `@webos-tools/cli@3.2.5`；Tizen 需要 Tizen Studio、TV Extension
及 Samsung 证书。文件型 TV 客户端使用 `null` origin，应只在专用代理 CORS
allowlist 中显式允许。

### HarmonyOS 手机/平板与服务卡片

```sh
export HARMONY_FLUTTER_BIN=/opt/flutter-ohos/bin/flutter
export DEVECO_SDK_HOME=/opt/HarmonyOS/sdk
export PATH="/opt/DevEco-Studio/tools/ohpm/bin:/opt/DevEco-Studio/tools/hvigor/bin:/opt/DevEco-Studio/tools/node/bin:$PATH"
HARMONY_BUILD_NUMBER=1 \
  ./packaging/harmonyos/build_harmonyos.sh "$API_BASE_URL" "$VERSION"
```

隔离 runner 会注入 `2×4` 服务卡片、本地 Preferences 状态和 companion
MethodChannel，并生成 `dist/harmonyos/zingchart-harmonyos-<version>.hap`。
只有 OpenHarmony SDK 不足以构建，必须安装 DevEco HarmonyOS API 18 元数据。

## 本地数据、代理与发布说明

- 收藏、歌单、队列、收听分析、Mood 和播放会话保留在设备本地。系统可能按
  Android Auto Backup/iOS 设备备份策略进行备份。
- JSON v2 备份上限 5 MB，不含音频或签名流 URL，并兼容 v1。
- 代理提供 `/health`、`/v1/chart`、`/v1/songs/{code}/source` 和签名
  `/v1/streams/{token}` 中继，带 CORS allowlist、限流、超时与安全错误响应。
- iOS 签名发布需三个 profile secret：`IOS_PROVISIONING_PROFILE_BASE64`、
  `IOS_WIDGET_PROVISIONING_PROFILE_BASE64`、
  `IOS_WATCH_PROVISIONING_PROFILE_BASE64`。
- 商店提交、自动更新和真机配对测试尚未完全自动化。发布前必须在真实目标设备
  验证媒体按键、桌面组件、手表配对、后台播放和签名。

安装器详情见 [packaging/README.md](packaging/README.md)，代理协议与安全说明见
[proxy/README.md](proxy/README.md)。
