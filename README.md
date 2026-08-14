# #zingChart

#zingChart là ứng dụng bảng xếp hạng và trình phát nhạc Local-First viết bằng
Flutter. Một codebase phục vụ Android, Android TV, iOS, Web/PWA, Windows,
macOS, Linux, Amazon Fire OS/Fire TV, LG webOS TV, Samsung Tizen TV và
HarmonyOS phone/tablet.

Client không gọi trực tiếp upstream Zing. Tất cả dữ liệu chart và audio đi qua
proxy Node/TypeScript do người triển khai tự host.

## 1. Tính năng hiện tại

- Zing Chart realtime: thứ hạng, ảnh bìa, tên bài và nghệ sĩ.
- Tìm kiếm theo tên bài hát hoặc nghệ sĩ.
- Play, pause, stop, seek, previous/next, shuffle và repeat.
- Queue kéo thả, vuốt sang phải để thêm bài và sleep timer.
- Background playback cùng system media controls trên nền tảng được hỗ trợ.
- Thư viện Local-First: yêu thích, playlist cá nhân, lịch sử nghe, tìm kiếm gần
  đây, analytics 7/30 ngày/theo năm, Daily Mix và Mood Mix Chill/Gym/Tập trung.
- Mini Wrapped 6 slide quanh năm; xuất PNG trên phone/web/desktop và QR tóm tắt
  local trên TV.
- Export/import backup JSON v2 theo hai chế độ Merge hoặc Overwrite; vẫn đọc
  được backup v1.
- Theme Sáng/Tối/Theo hệ thống, giữ nhận diện charcoal, coral và lime.
- UI adaptive cho mobile, tablet, desktop và giao diện 10-foot cho TV.

Chưa hỗ trợ tải/caching file nhạc để nghe offline. PWA chỉ cache app shell và
dữ liệu không phải audio.

### Local Intelligence v1.1

- Thời gian nghe được cộng từ tiến trình phát thực tế; bước nhảy do seek không
  được tính. Một lượt hợp lệ khi đạt `min(30 giây, 50% thời lượng)`.
- Chỉ Next, Previous hoặc chọn bài khác trước ngưỡng mới là early skip. Pause,
  Stop và seek là tín hiệu trung tính; completion được ghi khi player phát hết.
- Dữ liệu giữ tối đa 500 lịch sử gần nhất, chi tiết theo bài trong 62 ngày và
  tổng hợp tháng trong 24 tháng. Tất cả nằm trên thiết bị và không gửi lên proxy.
- Daily Mix lấy ứng viên từ chart, favorites, playlist và lịch sử, tối đa 25
  bài và không quá hai bài cùng nghệ sĩ. Cold start ưu tiên bài đã thích rồi tới
  thứ hạng chart.
- Mood không được suy đoán từ tên bài. Người dùng tự gắn nhiều nhãn Chill, Gym
  hoặc Tập trung từ menu bài hát và màn hình Now Playing.
- Backup v2 chứa analytics và mood. Merge dùng installation/date/song cùng bộ
  đếm lớn nhất để import lặp lại không cộng trùng; Overwrite vẫn giữ installation
  ID đang hoạt động. Giới hạn file là 5 MB.
- “Xóa lịch sử và thống kê” không xóa favorites, playlist hoặc mood tags.

Wrapped dùng Canvas nội bộ để dựng gradient, typography và họa tiết, không tải
ảnh bìa khi xuất nên không phụ thuộc CORS. Android/iOS mở share sheet, Web tải
hoặc chia sẻ PNG, desktop chọn nơi lưu; TV hiển thị QR chứa summary đã phiên bản
hóa và không cần server. HarmonyOS tự rơi về summary/QR có thể sao chép nếu
adapter share/save không khả dụng.

## 2. Kiến trúc và thư mục

```text
Flutter clients
    │
    ├── GET /v1/chart
    ├── GET /v1/songs/{code}/source
    └── GET /v1/streams/{signedToken}
              │
              ▼
        Node/Fastify proxy
              │
              ▼
          Zing upstream
```

| Thành phần | Vị trí | Vai trò |
| --- | --- | --- |
| Flutter app | `lib/` | UI, playback, Local-First library |
| Proxy | `proxy/` | Chuẩn hóa chart, ký URL và relay audio |
| Native runners | `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` | Runner từng hệ điều hành |
| Packaging | `packaging/` | Fire OS, TV, HarmonyOS và installer desktop |
| CI/Release | `.github/workflows/` | Test và build artifact đa nền tảng |

## 3. Yêu cầu chung

### Bắt buộc

- Git.
- FVM và Flutter `3.44.7`.
- Dart đi kèm Flutter; project yêu cầu Dart `>=3.12.0 <4.0.0`.
- Node.js `22+` cho proxy. Docker có thể thay thế Node khi chỉ chạy proxy.
- Một proxy URL; release build bắt buộc dùng HTTPS.

### Toolchain theo nền tảng

| Nền tảng | Toolchain bổ sung |
| --- | --- |
| Android/Android TV/Fire OS | Android SDK, Android Studio hoặc command-line tools, JDK 17 |
| iOS/macOS | macOS, full Xcode, CocoaPods; iOS deployment target 13+ |
| Windows | Windows, Visual Studio 2022 với Desktop development with C++, Windows 10/11 SDK |
| Linux | Clang, CMake, Ninja, GTK 3, LZMA và GStreamer development packages |
| webOS TV | Node.js và `@webos-tools/cli@3.2.5` |
| Tizen TV | Tizen Studio, TV Extension, Web CLI và Samsung certificate profile |
| HarmonyOS | CPF-Flutter OHOS, DevEco Studio CLI và HarmonyOS SDK 5.1.0 API 18 |

## 4. Cài đặt project lần đầu

### Bước 1: Clone và chọn đúng Flutter

```sh
git clone https://github.com/LamPPKK/Zing-Chart.git
cd Zing-Chart
fvm install 3.44.7
fvm use 3.44.7
fvm flutter doctor -v
```

### Bước 2: Cài dependency Flutter

```sh
fvm flutter pub get
```

Chỉ chạy code generation khi thay đổi DTO/Retrofit hoặc file có annotation:

```sh
fvm dart run build_runner build --delete-conflicting-outputs
```

### Bước 3: Chạy proxy local

```sh
cd proxy
cp .env.example .env
set -a
. ./.env
set +a
npm ci
npm run dev
```

Node không tự đọc file `.env`; ba lệnh `set -a`, `. ./.env`, `set +a` nạp và
export cấu hình vào process hiện tại. Khi đổi file `.env`, hãy khởi động lại
proxy.

Kiểm tra proxy trong terminal khác:

```sh
curl http://localhost:8080/health
curl http://localhost:8080/v1/chart
```

Kết quả health hợp lệ:

```json
{"status":"ok"}
```

### Bước 4: Chạy Flutter app

```sh
cd ..
fvm flutter devices
fvm flutter run -d <desktop-device-id> \
  --dart-define=API_BASE_URL=http://localhost:8080
```

Chọn thiết bị cụ thể bằng `-d`:

```sh
fvm flutter run -d chrome --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:8080

fvm flutter run -d <device-id> \
  --dart-define=API_BASE_URL=https://your-dev-proxy.example.com
```

`localhost:8080` phù hợp cho desktop và Chrome chạy trên cùng máy; web dev dùng
port `3000` để khớp CORS mặc định. Android/iOS emulator hoặc thiết bị thật nên
dùng proxy HTTPS truy cập được từ thiết bị.

## 5. Cấu hình proxy

Các biến chính nằm trong `proxy/.env.example`:

| Biến | Ý nghĩa |
| --- | --- |
| `NODE_ENV` | `development` hoặc `production` |
| `HOST`, `PORT` | Địa chỉ listen của proxy |
| `CORS_ORIGINS` | Allowlist origin, phân cách bằng dấu phẩy |
| `PUBLIC_BASE_URL` | URL public của proxy; production bắt buộc HTTPS |
| `STREAM_TOKEN_SECRET` | Secret ký stream token, production tối thiểu 32 ký tự |
| `STREAM_TOKEN_TTL_SECONDS` | Thời gian sống stream token |
| `STREAM_HOSTS` | Allowlist CDN upstream |
| `UPSTREAM_TIMEOUT_MS` | Timeout upstream |
| `CHART_CACHE_TTL_MS` | TTL cache chart |
| `RATE_LIMIT_MAX`, `RATE_LIMIT_WINDOW_MS` | Giới hạn request |
| `TRUST_PROXY_HOPS` | Số reverse proxy tin cậy phía trước service |

### Chạy production bằng Node

```sh
cd proxy
npm ci
npm run typecheck
npm test
npm run build
cp .env.example .env.production
# Chỉ tạo file này lần đầu; sửa NODE_ENV=production, URL, CORS và secret.
set -a
. ./.env.production
set +a
npm start
```

### Chạy production bằng Docker

Tạo `proxy/.env.production` với `NODE_ENV=production`, HTTPS public URL, CORS
allowlist và secret riêng. Sau đó chạy từ project root:

```sh
docker build -t zingchart-proxy:local ./proxy
docker run --rm \
  --env-file proxy/.env.production \
  -p 8080:8080 \
  zingchart-proxy:local
```

Kiểm tra container:

```sh
curl https://your-proxy.example.com/health
```

Không dùng `https://api.example.invalid` cho bản phát hành. URL này chỉ khiến
app hiển thị màn hình lỗi cấu hình an toàn.

## 6. Kiểm thử trước khi build

Chạy từ project root:

```sh
fvm flutter pub get
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test --reporter expanded
```

Kiểm tra proxy:

```sh
cd proxy
npm ci
npm run typecheck
npm test
npm run build
cd ..
```

Kiểm tra packaging scripts:

```sh
node --test \
  packaging/fireos/*.test.mjs \
  packaging/harmonyos/*.test.mjs \
  packaging/tv/*.test.mjs
```

## 7. Build và cài đặt theo nền tảng

Các ví dụ dưới đây dùng:

```sh
API_BASE_URL=https://proxy.example.com
VERSION=1.0.0
```

Thay URL và version bằng giá trị thật trước khi build.

### 7.1 Android phone/tablet

Build APK và Android App Bundle:

```sh
fvm flutter build apk --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"

fvm flutter build appbundle --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
```

Artifact:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

Cài APK bằng ADB:

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

#### Android production signing

Đặt keystore tại `android/app/release.jks`, rồi tạo file
`android/key.properties`:

```properties
storeFile=release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```

Không commit keystore, password hoặc `key.properties`. Nếu file này không tồn
tại, Gradle sẽ ký release APK bằng debug key; artifact đó chỉ dùng để test.

### 7.2 Android TV

Android runner đã có Leanback launcher, TV banner và đánh dấu touchscreen là
không bắt buộc. AAB Android bình thường có thể phục vụ cả phone/tablet/TV.

Để tạo APK ép giao diện TV phục vụ sideload/test:

```sh
fvm flutter build apk --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=TV_MODE=true
```

Cài lên TV hoặc emulator:

```sh
adb connect <ANDROID_TV_IP>:5555
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### 7.3 iOS

Yêu cầu macOS, full Xcode, CocoaPods và deployment target iOS 13+.

Build app không ký để kiểm tra CI:

```sh
fvm flutter build ios --release --no-codesign \
  --dart-define=API_BASE_URL="$API_BASE_URL"
```

Artifact app bundle:

```text
build/ios/iphoneos/Runner.app
```

Build IPA khi Xcode đã cấu hình Team, certificate và provisioning profile:

```sh
fvm flutter build ipa --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
```

IPA nằm trong `build/ios/ipa/`. Có thể mở `ios/Runner.xcworkspace` bằng Xcode,
chọn thiết bị thật, cấu hình Signing & Capabilities rồi dùng Product → Archive
để cài qua TestFlight hoặc phương thức phân phối phù hợp.

### 7.4 Web/PWA

```sh
fvm flutter build web --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
```

Artifact: `build/web/`.

Smoke test local:

```sh
python3 -m http.server 8081 --directory build/web
```

Mở `http://localhost:8081`. Khi triển khai production, static host phải:

- phục vụ HTTPS;
- fallback route về `index.html`;
- không cache lâu file audio hoặc signed stream URL;
- có origin nằm trong `CORS_ORIGINS` của proxy.

Đóng tab hoặc trình duyệt sẽ kết thúc playback Web; autoplay lần đầu cần thao
tác của người dùng.

### 7.5 Windows desktop

Chỉ build Windows trên máy Windows:

```powershell
$env:API_BASE_URL = "https://proxy.example.com"
fvm flutter config --enable-windows-desktop
fvm flutter pub get
fvm flutter build windows --release `
  --dart-define=API_BASE_URL="$env:API_BASE_URL"
```

Bundle chạy trực tiếp:

```text
build/windows/x64/runner/Release/
```

Chạy `zmp3chart.exe` trong thư mục này; không tách riêng EXE khỏi DLL/data.

#### Portable ZIP và Inno Setup EXE

Cài Inno Setup 6, sau đó:

```powershell
./packaging/windows/package_windows.ps1 -Version 1.0.0
```

Artifact:

- `dist/windows/zingchart-windows-portable.zip`
- `dist/windows/zingchart-windows-installer.exe`

#### MSIX

MSIX cần Windows 10/11 SDK và Microsoft.VCLibs.Desktop 14.0 SDK:

```powershell
./packaging/windows/package_msix.ps1 -Version 1.0.0
```

Mặc định script tạo `dist/windows/zingchart-windows-development.msix` chưa ký
và copy VCLibs dependency. CI release tạo thêm development certificate cùng
script cài đặt. Trên máy test dùng PowerShell chạy với quyền Administrator:

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\install-zingchart-development.ps1
```

Đối với Microsoft Store, `Publisher`, `IdentityName` và
`PublisherDisplayName` phải khớp chính xác Partner Center. Đây là Flutter Win32
được đóng gói MSIX, không phải UWP runner.

### 7.6 macOS

Yêu cầu full Xcode:

```sh
fvm flutter config --enable-macos-desktop
fvm flutter pub get
fvm flutter build macos --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
./packaging/macos/package_macos.sh
```

Artifact:

- `build/macos/Build/Products/Release/#zingChart.app`
- `dist/macos/zingchart-macos-app.zip`
- `dist/macos/zingchart-macos.dmg`

Mở DMG và kéo app vào Applications. Bản phát hành bên ngoài máy phát triển cần
Developer ID signing, hardened runtime, notarization và stapling.

### 7.7 Linux x64

Trên Ubuntu 22.04:

```sh
sudo apt-get update
sudo apt-get install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libfuse2 \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev

fvm flutter config --enable-linux-desktop
fvm flutter pub get
fvm flutter build linux --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"
```

Bundle chạy trực tiếp:

```text
build/linux/x64/release/bundle/
```

Tạo tar.gz và DEB:

```sh
./packaging/linux/package_linux.sh "$VERSION"
```

Tạo thêm AppImage bằng `linuxdeploy` đã được tải và xác minh checksum:

```sh
LINUXDEPLOY=/absolute/path/to/linuxdeploy \
  ./packaging/linux/package_linux.sh "$VERSION"
```

Artifact:

- `dist/linux/zingchart-linux-portable.tar.gz`
- `dist/linux/zingchart_<version>_amd64.deb`
- `dist/linux/zingchart-linux.AppImage` nếu có `LINUXDEPLOY`

Cài DEB:

```sh
sudo apt install ./dist/linux/zingchart_1.0.0_amd64.deb
```

### 7.8 Amazon Fire OS phone/tablet

Fire OS dùng Android runtime. Script touch tạo APK riêng cho Amazon và không
phụ thuộc Google Play Services:

```sh
FIREOS_FLUTTER_BIN="$(fvm which flutter)" \
FIREOS_BUILD_NUMBER=1 \
./packaging/fireos/build_fireos.sh \
  "$API_BASE_URL" "$VERSION" touch
```

Artifact:

```text
dist/fireos/zingchart-fireos-1.0.0-development.apk
```

Nếu `android/key.properties` đã cấu hình, hậu tố `-development` được bỏ. CI
Amazon release bắt buộc production signing và dừng build khi thiếu secret.

Cài lên Fire tablet:

```sh
adb install -r dist/fireos/zingchart-fireos-1.0.0-development.apk
```

Fire Phone đời cũ không nằm trong phạm vi hỗ trợ; Flutter build hiện yêu cầu
Android API tối thiểu của project.

### 7.9 Amazon Fire TV

```sh
FIREOS_FLUTTER_BIN="$(fvm which flutter)" \
FIREOS_BUILD_NUMBER=1 \
./packaging/fireos/build_fireos.sh \
  "$API_BASE_URL" "$VERSION" tv
```

Artifact:

```text
dist/firetv/zingchart-firetv-1.0.0-development.apk
```

Cài qua mạng:

```sh
adb connect <FIRE_TV_IP>:5555
adb install -r dist/firetv/zingchart-firetv-1.0.0-development.apk
```

Với `FIREOS_BUILD_NUMBER=N`, touch dùng versionCode `N*2`, Fire TV dùng
`N*2+1`. Tăng N ở mỗi release và ánh xạ hai APK vào đúng nhóm thiết bị trong
Amazon Developer Console.

### 7.10 LG webOS TV

Hỗ trợ package Flutter Web cho webOS TV 24+.

Cài CLI chính thức:

```sh
npm install --global @webos-tools/cli@3.2.5
```

Build IPK:

```sh
TV_FLUTTER_BIN="$(fvm which flutter)" \
./packaging/tv/build_tv_web.sh \
  webos "$API_BASE_URL" "$VERSION"
```

Artifact nằm trong `dist/webos/*.ipk`.

Khai báo TV bằng `ares-setup-device`, sau đó cài và chạy:

```sh
ares-install --device <DEVICE_NAME> dist/webos/<PACKAGE_FILE>.ipk
ares-launch --device <DEVICE_NAME> software.baycho.app.zingchart
```

Proxy phục vụ package TV phải thêm literal `null` vào `CORS_ORIGINS`. Nên dùng
proxy riêng cho TV vì nhiều file/sandbox origin khác cũng có giá trị `null`.

### 7.11 Samsung Tizen TV

Hỗ trợ package Web cho Tizen TV 8.0+.

Tạo project ZIP có thể ký:

```sh
TV_FLUTTER_BIN="$(fvm which flutter)" \
./packaging/tv/build_tv_web.sh \
  tizen "$API_BASE_URL" "$VERSION"
```

Artifact:

```text
dist/tizen/zingchart-tizen-project-1.0.0.zip
```

Tạo WGT bằng profile chứng thư Samsung trong Tizen Studio:

```sh
./packaging/tv/package_tizen.sh <SAMSUNG_CERT_PROFILE>
```

WGT được ghi vào `dist/tizen/`. Bật Developer Mode trên TV, kết nối bằng Tizen
Device Manager hoặc SDB rồi cài:

```sh
sdb connect <TV_IP>
sdb install dist/tizen/<PACKAGE_FILE>.wgt
```

Giữ an toàn author certificate; mọi bản update phải dùng cùng certificate.
Proxy Tizen package cũng cần origin `null` trong CORS allowlist.

### 7.12 HarmonyOS phone/tablet

HarmonyOS dùng CPF-Flutter OHOS riêng, không dùng Flutter upstream. Pipeline
được khóa với:

- CPF-Flutter `3.41.10-ohos-1.0.0`;
- Dart `3.11.5`;
- HarmonyOS SDK `5.1.0` API 18;
- dependency lock và plugin fork trong `packaging/harmonyos/`.

Cài toolchain và cấu hình:

```sh
git clone --branch 3.41.10-ohos-1.0.0 \
  https://gitcode.com/CPF-Flutter/flutter_flutter.git \
  ../flutter-ohos

export HARMONY_FLUTTER_BIN="$PWD/../flutter-ohos/bin/flutter"
export DEVECO_SDK_HOME=/path/to/HarmonyOS/sdk
export PATH="/path/to/DevEco-Studio/tools/ohpm/bin:/path/to/DevEco-Studio/tools/hvigor/bin:/path/to/DevEco-Studio/tools/node/bin:$PATH"
```

Build HAP:

```sh
HARMONY_BUILD_NUMBER=1 \
./packaging/harmonyos/build_harmonyos.sh \
  "$API_BASE_URL" "$VERSION"
```

Artifact:

```text
dist/harmonyos/zingchart-harmonyos-1.0.0.hap
```

Cài bằng DevEco Studio hoặc HDC sau khi thiết bị đã cho phép debug:

```sh
hdc install -r dist/harmonyos/zingchart-harmonyos-1.0.0.hap
```

`DEVECO_SDK_HOME` phải chứa DevEco HarmonyOS `sdk-pkg.json` có API 18. Chỉ có
thư mục OpenHarmony tên `18` không đủ để build HAP. Phát hành AppGallery cần
signing profile thật.

Các plugin file picker/share hiện chưa có OHOS implementation đã được review;
backup UI sẽ fallback sang copy/paste JSON trên HarmonyOS.

## 8. Backup và dữ liệu Local-First

App lưu favorites, playlist, queue, history, recent searches, theme và phiên
phát trên từng thiết bị; không có tài khoản hoặc cloud sync riêng.

Trong **Thư viện → Dữ liệu của bạn**:

- **Xuất backup JSON** tạo `zingchart-library-YYYY-MM-DD.json`.
- **Hợp nhất** giữ dữ liệu hiện tại, loại record/bài trùng ID và chỉ lấy
  playlist metadata mới hơn.
- **Ghi đè** thay toàn bộ thư viện và theme bằng nội dung file.
- Import bị giới hạn 5 MB và không chứa audio hoặc signed stream URL.

Android Auto Backup/Device Transfer bao gồm AndroidX DataStore hiện tại và
SharedPreferences legacy. iOS đưa dữ liệu app container vào device iCloud
Backup theo chính sách hệ điều hành; đây không phải đồng bộ realtime.

## 9. CI và phát hành

### CI

`.github/workflows/ci.yml` chạy khi push lên `main`, `develop`, pull request hoặc
workflow dispatch. Pipeline kiểm tra:

- format, analyze và Flutter tests;
- Web/Android TV/Fire OS/TV package smoke builds;
- Windows MSIX layout;
- proxy typecheck/test/build và Docker smoke build.

### Release workflow

Chạy **Actions → Multiplatform Release → Run workflow** với version `x.y.z`,
hoặc push tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

`API_BASE_URL` nên được cấu hình bằng repository secret. Các signing secrets
chính:

| Nền tảng | Secrets/variables |
| --- | --- |
| Android/Fire OS | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD` |
| Windows EXE | `WINDOWS_CERTIFICATE_BASE64`, `WINDOWS_CERTIFICATE_PASSWORD` |
| Windows Store MSIX | `WINDOWS_PUBLISHER`, `WINDOWS_IDENTITY_NAME`, `WINDOWS_PUBLISHER_DISPLAY_NAME` |
| Windows direct MSIX | `WINDOWS_MSIX_CERTIFICATE_BASE64`, `WINDOWS_MSIX_CERTIFICATE_PASSWORD` |
| macOS | `MACOS_CERTIFICATE_BASE64`, `MACOS_CERTIFICATE_PASSWORD`, `MACOS_SIGNING_IDENTITY`, Apple notarization secrets |
| iOS | `IOS_CERTIFICATE_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`, `IOS_SIGNING_IDENTITY` |
| Linux AppImage | `LINUXDEPLOY_SHA256` |
| HarmonyOS | self-hosted runner variables `HARMONY_FLUTTER_BIN`, `DEVECO_SDK_HOME`, tùy chọn `DEVECO_TOOL_HOME` |

Chi tiết signing và artifact xem thêm tại
[`packaging/README.md`](packaging/README.md). Proxy contract và security xem tại
[`proxy/README.md`](proxy/README.md).

## 10. Artifact đầu ra

| Nền tảng | Artifact |
| --- | --- |
| Android | APK, AAB |
| Android TV | APK/AAB universal hoặc APK ép `TV_MODE=true` |
| iOS | unsigned app ZIP trong CI, IPA khi có signing |
| Web/PWA | `build/web/` hoặc tar.gz trong CI |
| Windows | portable ZIP, Inno EXE, MSIX |
| macOS | `.app` ZIP, DMG |
| Linux | tar.gz, DEB, tùy chọn AppImage |
| Fire OS | touch APK |
| Fire TV | TV APK |
| webOS TV | IPK |
| Tizen TV | signable project ZIP, WGT sau khi ký |
| HarmonyOS | HAP |
| Proxy | Docker image tar.gz trong release CI |

## 11. Lỗi thường gặp

### App hiển thị lỗi cấu hình API

- Release build thiếu `API_BASE_URL` hoặc URL không phải HTTPS.
- Build đang dùng placeholder `https://api.example.invalid`.
- CORS proxy chưa cho phép origin của Web/TV client.

### Web chạy nhưng không phát audio

- Kiểm tra `/v1/songs/{code}/source` trả URL cùng proxy origin.
- Kiểm tra `/v1/streams/{token}` hỗ trợ byte range.
- Lần phát đầu tiên phải bắt đầu từ thao tác người dùng do autoplay policy.

### Android/Fire artifact bị ký bằng debug certificate

Tạo `android/app/release.jks` và `android/key.properties` trước khi build.
Không upload debug-signed artifact lên Store.

### iOS/macOS build báo thiếu Xcode

Command Line Tools không đủ. Cài full Xcode, chọn đúng developer directory và
chạy lại `fvm flutter doctor -v`.

### Windows MSIX không cài được

- Package chưa ký hoặc certificate subject không khớp `Publisher`.
- Thiếu Microsoft.VCLibs.Desktop x64 dependency.
- Development installer phải chạy trong PowerShell Administrator.

### Linux không có AppImage

`package_linux.sh` vẫn tạo tar.gz và DEB. AppImage chỉ được tạo khi biến
`LINUXDEPLOY` trỏ tới executable đã được xác minh checksum.

### webOS/Tizen bị CORS

Thêm literal `null` vào `CORS_ORIGINS` của proxy TV và giữ rate limit. Không mở
`*` cho production.

### HarmonyOS báo `No Hmos SDK found`

`DEVECO_SDK_HOME` đang trỏ tới OpenHarmony SDK không tương thích hoặc thiếu
DevEco HarmonyOS API 18 metadata. Cài đúng HarmonyOS SDK từ DevEco Studio.

## 12. Giới hạn phát hành

- Store submission và auto-update chưa được tự động hóa.
- Artifact không có signing secret chỉ dành cho development/test.
- Background playback, lock screen metadata, media keys và TV remote cần kiểm
  tra thêm trên thiết bị thật trước mỗi release.
- Nguồn Zing là upstream bên ngoài và có thể thay đổi; mọi thay đổi adapter phải
  được cô lập trong proxy.
- Chỉ sử dụng, relay hoặc tải nội dung khi có quyền phù hợp.
