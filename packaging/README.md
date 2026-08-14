# #zingChart packaging

The release workflow always produces testable artifacts and conditionally signs them when protected repository secrets are available. Set `API_BASE_URL` to the deployed HTTPS proxy URL before producing a public release. If it is absent, CI injects `https://api.example.invalid`; this intentionally produces an app that displays its configuration error instead of contacting Zing directly.

Optional production signing secrets:

- Android: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`.
- Windows: `WINDOWS_CERTIFICATE_BASE64`, `WINDOWS_CERTIFICATE_PASSWORD`.
- macOS: `MACOS_CERTIFICATE_BASE64`, `MACOS_CERTIFICATE_PASSWORD`, `MACOS_SIGNING_IDENTITY`; notarization additionally uses `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID`.
- iOS: `IOS_CERTIFICATE_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`, `IOS_SIGNING_IDENTITY` produce a signed direct-distribution IPA; otherwise CI keeps the unsigned app archive.

Set `LINUXDEPLOY_SHA256` to the reviewed SHA-256 digest of the `linuxdeploy-x86_64.AppImage` binary used by the Linux job. The download URL points to linuxdeploy's rolling `continuous` release, so the job refuses to execute it unless its bytes match the explicitly approved digest. When updating linuxdeploy, download it in a trusted environment, review its release provenance, calculate `sha256sum linuxdeploy-x86_64.AppImage`, and rotate the secret.

## Artifacts

- Android: APK and AAB signed by the protected release keystore when configured, otherwise development-signed artifacts.
- Web/PWA: gzipped contents of `build/web` for any static host with SPA fallback.
- Windows: portable ZIP and Inno Setup EXE, Authenticode-signed when its certificate secrets are configured.
- macOS: zipped `.app` and DMG, Developer ID signed/notarized when Apple secrets are configured; otherwise ad-hoc/unsigned test artifacts.
- iOS: unsigned `.app` ZIP plus a signed IPA when Apple distribution assets are configured.
- Linux x64: portable tarball, AppImage, and Debian package.
- Proxy: gzipped Docker image tarball, loadable with `docker load`.

Run the workflow from **Actions → Multiplatform Release → Run workflow**, or push a tag such as `v1.0.0`. The optional manual version becomes installer metadata; tag builds use the tag name with a leading `v` removed where required.

## Local packaging

Build the Flutter release bundle first with the same `--dart-define=API_BASE_URL=https://…` used in CI. Then run the matching script:

```text
PowerShell: .\packaging\windows\package_windows.ps1 -Version 1.0.0
macOS:      ./packaging/macos/package_macos.sh
Linux:      LINUXDEPLOY=/path/to/linuxdeploy ./packaging/linux/package_linux.sh 1.0.0
```

The scripts write only to `build/packaging` and `dist`. Store submission and automatic updates are outside this release scaffold.
