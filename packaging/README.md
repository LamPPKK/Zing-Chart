# #zingChart packaging

The release workflow always produces testable artifacts and conditionally signs them when protected repository secrets are available. Set `API_BASE_URL` to the deployed HTTPS proxy URL before producing a public release. If it is absent, CI injects `https://api.example.invalid`; this intentionally produces an app that displays its configuration error instead of contacting Zing directly.

Optional production signing configuration:

- Android: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`.
- Windows EXE/Inno installer signing: `WINDOWS_CERTIFICATE_BASE64` and
  `WINDOWS_CERTIFICATE_PASSWORD`.
- Microsoft Store MSIX identity: `WINDOWS_PUBLISHER`,
  `WINDOWS_IDENTITY_NAME` and `WINDOWS_PUBLISHER_DISPLAY_NAME`. These three
  metadata values must exactly match Microsoft Partner Center and do not
  require the EXE/installer certificate.
- Optional direct-distribution signing of the Store-identity MSIX:
  `WINDOWS_MSIX_CERTIFICATE_BASE64` and
  `WINDOWS_MSIX_CERTIFICATE_PASSWORD`. This separate certificate subject must
  match `WINDOWS_PUBLISHER`; Partner Center can accept the unsigned Store MSIX
  and signs it during publication.
- macOS: `MACOS_CERTIFICATE_BASE64`, `MACOS_CERTIFICATE_PASSWORD`, `MACOS_SIGNING_IDENTITY`; notarization additionally uses `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID`.
- iOS: `IOS_CERTIFICATE_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`, `IOS_SIGNING_IDENTITY` produce a signed direct-distribution IPA; otherwise CI keeps the unsigned app archive.

Set `LINUXDEPLOY_SHA256` to the reviewed SHA-256 digest of the `linuxdeploy-x86_64.AppImage` binary used by the Linux job. The download URL points to linuxdeploy's rolling `continuous` release, so the job refuses to execute it unless its bytes match the explicitly approved digest. When updating linuxdeploy, download it in a trusted environment, review its release provenance, calculate `sha256sum linuxdeploy-x86_64.AppImage`, and rotate the secret.

## Artifacts

- Android: APK and AAB signed by the protected release keystore when configured, otherwise development-signed artifacts.
- Android TV: the universal Android APK/AAB with Leanback launcher metadata,
  TV banner, runtime television detection and remote-focus UI.
- Web/PWA: gzipped contents of `build/web` for any static host with SPA fallback.
- LG webOS TV: installable IPK built with the official webOS CLI.
- Samsung Tizen TV: signable TV Web project ZIP. A device-installable WGT must
  be produced with the publisher's Samsung certificate profile in Tizen Studio.
- Windows: portable ZIP, Inno Setup EXE and MSIX packaged desktop app.
  MSIX provides Windows package identity, Start menu tiles and a Microsoft
  Store-compatible artifact; Flutter does not provide a UWP runner. Every
  release includes a development-signed MSIX, its test certificate, installer
  script and the matching x64 VCLibs framework dependency. When Partner Center
  identity is configured, CI additionally creates `zingchart-windows-store.msix`.
- macOS: zipped `.app` and DMG, Developer ID signed/notarized when Apple secrets are configured; otherwise ad-hoc/unsigned test artifacts.
- iOS: unsigned `.app` ZIP plus a signed IPA when Apple distribution assets are configured.
- Linux x64: portable tarball, AppImage, and Debian package.
- Proxy: gzipped Docker image tarball, loadable with `docker load`.

Run the workflow from **Actions → Multiplatform Release → Run workflow**, or push a tag such as `v1.0.0`. The optional manual version becomes installer metadata; tag builds use the tag name with a leading `v` removed where required.

## Local packaging

Build the Flutter release bundle first with the same `--dart-define=API_BASE_URL=https://…` used in CI. Then run the matching script:

```text
PowerShell: .\packaging\windows\package_windows.ps1 -Version 1.0.0
MSIX:      .\packaging\windows\package_msix.ps1 -Version 1.0.0
macOS:      ./packaging/macos/package_macos.sh
Linux:      LINUXDEPLOY=/path/to/linuxdeploy ./packaging/linux/package_linux.sh 1.0.0
webOS TV:   TV_FLUTTER_BIN="$(fvm which flutter)" ./packaging/tv/build_tv_web.sh webos https://proxy.example.com 1.0.0
Tizen TV:   TV_FLUTTER_BIN="$(fvm which flutter)" ./packaging/tv/build_tv_web.sh tizen https://proxy.example.com 1.0.0
Signed WGT: ./packaging/tv/package_tizen.sh YOUR_SAMSUNG_CERT_PROFILE
```

## TV packaging notes

Android TV uses the normal Android build and detects
`UI_MODE_TYPE_TELEVISION` at runtime, so one Play Store AAB serves phone,
tablet and TV without forcing the TV layout on mobile.

For webOS packaging, install the pinned official CLI with
`npm install --global @webos-tools/cli@3.2.5`. The build script embeds all
Flutter web engine resources in the IPK and rewrites the base path for a
packaged file application. Install a development build with `ares-install`.

Tizen requires Tizen Studio with the TV Extension, Web CLI, a valid Samsung
certificate profile and a TV/emulator that permits application installation.
The release workflow intentionally uploads a signable project instead of a
fake unsigned `.wgt`; run `package_tizen.sh` on the signing machine to create
the real WGT. Back up the author certificate because future updates must use
the same certificate.

Both packaged Web TV clients can send the CORS origin `null`. The proxy accepts
that origin only when the operator explicitly includes it in `CORS_ORIGINS`.
Use a dedicated TV proxy deployment when possible because browsers and other
sandboxed file documents may also use the same origin value.

The packaged Flutter Web targets are intentionally limited to LG webOS TV 24+
and Samsung Tizen 8.0+ (2024 models or newer). Their Chromium 108 engine is
above Flutter 3.44's explicitly unsupported Chrome 95-and-earlier range. Select
only those model groups in LG Seller Lounge and Samsung Seller Office. LG's
separate native `flutter-webOS` SDK currently starts at webOS 26 Re:New and uses
a different Ubuntu-only toolchain/plugin ecosystem; it is not interchangeable
with this app's standard Flutter 3.44 plugins.

The TV UI reserves arrow keys for focus traversal. Select/Enter activates the
focused control; Play/Pause, Stop, Previous, Next, Rewind and Fast Forward are
mapped to the same playback service. Back dismisses text input or returns to
Home before showing an HTML exit-confirmation dialog at the root screen. The
confirmed action uses Tizen's application exit API or closes the webOS app.
Actual store submission still requires testing on representative LG and
Samsung TV hardware.

For Microsoft Store submission, set all three identity values assigned in
Partner Center. The Store package does not depend on the certificate used for
the portable EXE/Inno installer. If you separately sign that MSIX for direct
distribution, its certificate subject must match the Store `Publisher`. Store
versions use four numeric components, must have a major version above zero and
must end in `.0`.

Release CI signs `zingchart-windows-development.msix` with a short-lived
certificate and uploads `zingchart-development.cer` plus its VCLibs dependency.
On a disposable Windows test machine, open an elevated PowerShell window and
run `PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File
.\install-zingchart-development.ps1`. This override applies only to that
process. The script trusts the test certificate, installs or upgrades VCLibs
only when required, and then installs the development MSIX. It removes the
certificate if installation fails and prints the cleanup command after a
successful test. Do not trust this certificate on production machines.

When Store identity metadata is configured, a manual workflow run must provide
an explicit version; a version tag supplies it automatically. This prevents
Partner Center from rejecting repeated fallback versions.

The local `package_msix.ps1` command creates an unsigned package layout. Sign
its output with `signtool` using a certificate whose subject matches
`Publisher` before direct installation.

The scripts write only to `build` and `dist`. Store submission and automatic
updates are outside this release scaffold.

## Amazon Fire OS

Fire OS is Android-based, so both dedicated artifacts are built from the normal
Android runner without Google Play Services. `build_fireos.sh` requires an
HTTPS proxy URL and accepts `touch` (the default) or `tv` as its third argument.
The touch target applies `DISTRIBUTION_CHANNEL=amazon`; the TV target applies
`DISTRIBUTION_CHANNEL=amazon-fire-tv` and `TV_MODE=true` so the 10-foot UI is
always enabled even if device detection is unavailable. Builds use deterministic
metadata and write either a signed APK or a clearly labelled `*-development.apk`
when signing is absent.

```sh
FIREOS_FLUTTER_BIN="$(fvm which flutter)" \
  FIREOS_BUILD_NUMBER=1 \
  ./packaging/fireos/build_fireos.sh https://proxy.example.com 1.0.0

FIREOS_FLUTTER_BIN="$(fvm which flutter)" \
  FIREOS_BUILD_NUMBER=1 \
  ./packaging/fireos/build_fireos.sh https://proxy.example.com 1.0.0 tv
```

Outputs:

- `dist/fireos/zingchart-fireos-<version>.apk` for Fire touch devices.
- `dist/firetv/zingchart-firetv-<version>.apk` for Fire TV.

Amazon requires a unique `versionCode` for every binary in one listing. The
script treats `FIREOS_BUILD_NUMBER` as a release sequence and derives `N*2` for
touch and `N*2+1` for TV. Increase the sequence for every Amazon release; both
APKs keep the same package name and user-facing version.

A local build uses the Android signing configuration already present in the
project and is development-only when `android/key.properties` is absent. The
release workflow requires all four Android production-signing secrets and
fails closed before an Amazon artifact is built if any secret is missing.

The shared manifest declares Leanback launcher support and marks touchscreen and
faketouch as optional. The Fire TV binary additionally forces the app's remote-
first layout, D-pad focus navigation and media-key handling. Amazon permits
separate Fire tablet and Fire TV binaries, but the publisher must map each APK
to its intended devices manually in Developer Console. Validate the production-
signed packages with Amazon Appstore Live App Testing and physical Fire TV/
tablet generations before submission. Amazon currently documents Fire tablets
and Fire TV, not a current Fire OS phone product; legacy Fire Phone devices are
below this Flutter release's minimum Android API (`minSdkVersion=24`).

For sideload testing, enable ADB on the Fire TV and install the development APK:

```sh
adb connect FIRE_TV_IP_ADDRESS:5555
adb install -r dist/firetv/zingchart-firetv-1.0.0-development.apk
```

## HarmonyOS phone and tablet

HarmonyOS uses the CPF-Flutter OpenHarmony adaptation rather than the upstream
Flutter SDK. The supported build set is intentionally isolated from the root
lockfile and uses `packaging/harmonyos/pubspec.lock` with
`pub get --enforce-lockfile`:

- CPF-Flutter `3.41.10-ohos-1.0.0` / Dart 3.11.5.
- HarmonyOS SDK 5.1.0 (API 18) and DevEco command-line tools.
- Immutable plugin commits corresponding to audioplayers 6.5.1-ohos-1.0.0,
  audio_service 0.18.18-ohos-1.0.0 and shared_preferences
  2.5.4-ohos-1.0.0.

`build_harmonyos.sh` creates a disposable project in `build/harmonyos`, copies
the shared Dart source, applies `pubspec_overrides.yaml`, enables phone/tablet,
Internet, `audioPlayback` and `KEEP_BACKGROUND_RUNNING`, then runs
`flutter build hap --release --target-platform=ohos-arm64`.

```sh
export HARMONY_FLUTTER_BIN=/opt/flutter-ohos/bin/flutter
export DEVECO_SDK_HOME=/opt/HarmonyOS/sdk
export PATH="/opt/DevEco-Studio/tools/ohpm/bin:/opt/DevEco-Studio/tools/hvigor/bin:/opt/DevEco-Studio/tools/node/bin:$PATH"
HARMONY_BUILD_NUMBER=1 \
  ./packaging/harmonyos/build_harmonyos.sh https://proxy.example.com 1.0.0
```

The script exports this path as `HOS_SDK_HOME`, which is the variable consumed
by CPF-Flutter, after validating a DevEco `sdk-pkg.json` whose `apiVersion` is
18. An OpenHarmony SDK folder named `18` is not a substitute for the HarmonyOS
SDK layout required by the HAP builder.

The release workflow runs this job only on a self-hosted runner when
`HARMONYOS_RUNNER_ENABLED=true`. Configure `HARMONY_FLUTTER_BIN`,
`DEVECO_SDK_HOME` and optionally `DEVECO_TOOL_HOME` as repository variables.
AppGallery distribution still requires a real HarmonyOS signing profile and
device validation; an unsigned local HAP is only a development artifact.

The Harmony lock also freezes the hosted `file_selector`/`share_plus` graph
used by the Local-First backup UI. Those upstream packages do not currently
provide reviewed OHOS native implementations in this runner, so the app catches
an unavailable platform channel and offers copy/paste JSON instead. This keeps
the HAP data-portable without claiming a native Harmony document picker.
