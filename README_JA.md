<p align="center">
  <img src="assets/branding/haru_icon.svg" width="128" alt="HaRu アイコン">
</p>

<h1 align="center">HaRu</h1>

<p align="center">Rule34Video と Hanime の非公式 Android クライアント</p>

<p align="center"><a href="README.md">简体中文</a> · <a href="README_EN.md">English</a> · <strong>日本語</strong> · <a href="README_KO.md">한국어</a></p>

HaRu は両サイトの既存ページ、エンドポイント、メディアソースを利用し、対等かつ独立した閲覧、アカウント、ライブラリ、再生体験を一つのアプリにまとめます。

> [!IMPORTANT]
> 本プロジェクトは Rule34Video および Hanime の公式とは関係ありません。居住地域の法定年齢に達し、当該コンテンツへ合法的にアクセスできる方のみを対象とします。

## 主な機能

- R34V と Hanime を対等な最上位ソースとして扱い、それぞれにホーム、検索、フィルター、アカウント状態を用意；
- ライブラリを「ローカル / R34V / Hanime」で整理し、履歴、お気に入りまたは高評価、再生リスト、購読、あとで見る、ローカル分類、ダウンロードを統合；
- Hanime のログインと Cloudflare 認証、カテゴリ閲覧、高度な絞り込み、評価、あとで見る、作者購読、再生リスト、コメント操作に対応；
- 複数画質、ダウンロード、再生位置記憶、速度変更、バックグラウンド再生、ループ再生、停止中のプレーヤー折りたたみに対応；
- フィードのキャッシュ、隣接コンテンツの先読み、失敗時の復旧、1列・2列表示、スクロールとフィルター状態の保持；
- アカウント不要のローカル分類と、編集・インポート・エクスポート可能な多言語翻訳ライブラリ；
- 簡体字中国語、英語、日本語、韓国語のUIに対応し、下部ナビゲーションとライブラリ範囲を並べ替え可能；
- 診断ログは端末内で匿名化・容量制限され、7日間だけ保持されます。

## インストール

[GitHub Releases](https://github.com/Hanestl/HaRu/releases/latest) から最新の `arm64-v8a` APK をダウンロードしてください。同じ Release の `SHA256SUMS.txt` で整合性を確認できます。

Android 7.0（API 24）以降の ARM64 スマートフォンとタブレットに対応します。サイドロード時はブラウザーまたはファイルマネージャーに不明なアプリのインストール許可が必要な場合があります。

## データとプライバシー

認証情報は Android の安全なストレージへ保存されます。ローカル分類、ダウンロード記録、再生位置、設定、検索履歴、翻訳は端末内に保存されます。広告、分析、外部クラッシュレポート SDK は組み込みません。

サイト側のアカウントデータは各サイトが管理します。詳細は [PRIVACY.md](PRIVACY.md) を参照してください。

## ローカルビルド

確認済み環境：Flutter 3.44.8、Dart 3.12.2、JDK 25、Android SDK 36。

```powershell
flutter pub get
dart run build_runner build
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --split-per-abi --target-platform android-arm64 --no-pub
```

署名と公開手順は [docs/release.md](docs/release.md) にあります。

## 既知の制約

- サイトの HTML、エンドポイント、ログイン手順に依存するため、サイト変更後はパーサー更新が必要になる場合があります；
- 権限、ペイウォール、地域制限、Cloudflare 認証を回避しません；
- 動画 URL には期限があるため、必要に応じて再生・ダウンロード元を再取得します。

## ライセンス

本プロジェクトは [MIT License](LICENSE) で公開されています。サードパーティの通知は [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) を参照してください。

## 関連リンク

- [LINUX DO](https://linux.do/)
