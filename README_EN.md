<p align="center">
  <img src="assets/branding/haru_icon.svg" width="128" alt="HaRu icon">
</p>

<h1 align="center">HaRu</h1>

<p align="center">An independent Android client for Rule34Video and Hanime</p>

<p align="center"><a href="README.md">简体中文</a> · <strong>English</strong> · <a href="README_JA.md">日本語</a> · <a href="README_KO.md">한국어</a></p>

HaRu uses the existing pages, endpoints, and media sources of both websites to provide equal but independent browsing, account, library, and playback experiences in one app.

> [!IMPORTANT]
> This project is not affiliated with Rule34Video or Hanime. It is intended only for users who are of legal age and may lawfully access this content where they live.

## Core experience

- R34V and Hanime are equal top-level sources with separate home feeds, search, filters, and account state;
- The library is organized by Local, R34V, and Hanime, covering history, favorites or likes, playlists, subscriptions, watch later, local collections, and downloads;
- Hanime supports sign-in and Cloudflare verification, category browsing, advanced filters, ratings, watch later, creator subscriptions, playlists, and comment interactions;
- Video pages support multiple qualities, downloads, playback memory, speed control, background and loop playback, plus a collapsible player while paused;
- Feeds use caching, adjacent-content prefetching, failure recovery, one- or two-column layouts, and persistent scroll and filter state;
- Local collections work without an account, and the multilingual content translation library can be edited, imported, and exported;
- The interface supports Simplified Chinese, English, Japanese, and Korean. Bottom navigation and library scopes can be reordered;
- Local diagnostic logs are redacted, size-limited, retained for seven days, and leave the device only when explicitly exported.

## Installation

Download the latest `arm64-v8a` APK from [GitHub Releases](https://github.com/Hanestl/HaRu/releases/latest). Use `SHA256SUMS.txt` from the same release to verify the file.

HaRu supports ARM64 phones and tablets running Android 7.0 (API 24) or later. Android may ask you to allow your browser or file manager to install unknown apps.

## Data and privacy

Credentials are stored in Android secure storage. Local collections, download records, playback progress, settings, search history, and translations remain on the device. The app includes no advertising, analytics, or third-party crash-reporting SDKs.

Website account data remains under the control of each website. See [PRIVACY.md](PRIVACY.md) for details.

## Local build

Verified toolchain: Flutter 3.44.8, Dart 3.12.2, JDK 25, and Android SDK 36.

```powershell
flutter pub get
dart run build_runner build
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --split-per-abi --target-platform android-arm64 --no-pub
```

Release signing and publishing are documented in [docs/release.md](docs/release.md).

## Known boundaries

- Features depend on the websites' current HTML, endpoints, and sign-in flows; parser updates may be required after site changes;
- The app does not bypass permissions, paywalls, regional restrictions, or Cloudflare verification;
- Video URLs may expire, so playback and downloads refresh their sources when necessary.

## License

The project is released under the [MIT License](LICENSE). Third-party notices are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Links

- [LINUX DO](https://linux.do/)
