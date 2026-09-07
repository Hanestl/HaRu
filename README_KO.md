<p align="center">
  <img src="assets/branding/haru_icon.svg" width="128" alt="HaRu 아이콘">
</p>

<h1 align="center">HaRu</h1>

<p align="center">Rule34Video와 Hanime을 위한 비공식 Android 클라이언트</p>

<p align="center"><a href="README.md">简体中文</a> · <a href="README_EN.md">English</a> · <a href="README_JA.md">日本語</a> · <strong>한국어</strong></p>

HaRu는 두 웹사이트의 기존 페이지, 엔드포인트와 미디어 소스를 사용해 동등하면서도 독립적인 탐색, 계정, 라이브러리, 재생 경험을 하나의 앱에서 제공합니다.

> [!IMPORTANT]
> 이 프로젝트는 Rule34Video 또는 Hanime 공식과 관련이 없습니다. 거주 지역의 법정 성인 연령에 도달했고 해당 콘텐츠에 합법적으로 접근할 수 있는 사용자만을 대상으로 합니다.

## 주요 기능

- R34V와 Hanime을 동등한 최상위 소스로 제공하며 각각 홈, 검색, 필터와 계정 상태를 유지합니다;
- 라이브러리를 로컬, R34V, Hanime 범위로 나누고 기록, 즐겨찾기 또는 좋아요, 재생목록, 구독, 나중에 보기, 로컬 분류와 다운로드를 정리합니다;
- Hanime 로그인과 Cloudflare 인증, 카테고리 탐색, 상세 필터, 평가, 나중에 보기, 작가 구독, 재생목록과 댓글 상호작용을 지원합니다;
- 여러 화질, 다운로드, 재생 위치 기억, 배속, 백그라운드 및 반복 재생과 일시정지 중 플레이어 접기를 지원합니다;
- 피드 캐시, 인접 콘텐츠 미리 불러오기, 오류 복구, 1열·2열 레이아웃과 스크롤·필터 상태 유지를 제공합니다;
- 계정 없이 사용하는 로컬 분류와 편집·가져오기·내보내기가 가능한 다국어 콘텐츠 번역 라이브러리를 제공합니다;
- 중국어 간체, 영어, 일본어, 한국어 UI를 지원하며 하단 탐색과 라이브러리 범위 순서를 바꿀 수 있습니다;
- 진단 로그는 기기에서 비식별화되고 용량이 제한되며 최근 7일만 보관됩니다.

## 설치

[GitHub Releases](https://github.com/Hanestl/HaRu/releases/latest)에서 최신 `arm64-v8a` APK를 다운로드하세요. 같은 Release의 `SHA256SUMS.txt`로 파일 무결성을 확인할 수 있습니다.

Android 7.0(API 24) 이상 ARM64 스마트폰과 태블릿을 지원합니다. APK를 직접 설치할 때 브라우저나 파일 관리자에 알 수 없는 앱 설치 권한이 필요할 수 있습니다.

## 데이터와 개인정보

로그인 정보는 Android 보안 저장소에 보관됩니다. 로컬 분류, 다운로드 기록, 재생 위치, 설정, 검색 기록과 번역은 기기에 저장됩니다. 광고, 분석 또는 외부 충돌 보고 SDK는 포함하지 않습니다.

웹사이트 계정 데이터는 각 웹사이트에서 관리합니다. 자세한 내용은 [PRIVACY.md](PRIVACY.md)를 참조하세요.

## 로컬 빌드

검증된 도구: Flutter 3.44.8, Dart 3.12.2, JDK 25, Android SDK 36.

```powershell
flutter pub get
dart run build_runner build
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --split-per-abi --target-platform android-arm64 --no-pub
```

서명과 배포 절차는 [docs/release.md](docs/release.md)에 있습니다.

## 알려진 제한

- 웹사이트의 현재 HTML, 엔드포인트와 로그인 흐름에 의존하므로 사이트 변경 후 파서 업데이트가 필요할 수 있습니다;
- 권한, 유료 제한, 지역 제한 또는 Cloudflare 인증을 우회하지 않습니다;
- 동영상 URL이 만료될 수 있어 필요한 경우 재생 및 다운로드 소스를 다시 가져옵니다.

## 라이선스

프로젝트는 [MIT License](LICENSE)로 배포됩니다. 서드파티 고지는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)를 참조하세요.

## 관련 링크

- [LINUX DO](https://linux.do/)
