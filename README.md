# 相見積もり比較

複数社の見積書を、単純な総合点や順位ではなく、**価格・工事範囲・別途費用・オプション・要望との差・不明点**として整理するFlutterアプリです。

PDFまたは写真から見積書を取り込み、端末内OCRで抽出した内容を確認・修正したうえで、18カテゴリの比較、業者への確認質問、見積改訂履歴を作成します。案件・見積・比較結果・要望・改訂履歴は端末内SQLiteへ保存します。

> 現在のFlutter実装は `main` ブランチです。リポジトリの既定ブランチが変更されるまでは、clone時に `-b main` を指定してください。

## 主な機能

- 案件の作成、検索、スワイプ削除
- 18カテゴリの「必須・あればよい・不要・未設定」チェックリスト
- PDF・写真からの見積書取り込み
- 日本語OCR結果、金額、数量、単位、仕様の確認・修正
- OCR信頼度、合計不一致、数量×単価不一致のレビュー
- 複数社のカテゴリ別比較
- 要望との差異と確認質問の生成
- 同一業者の見積改訂履歴、親子関係、版間差分
- 任意の改訂版を選択した読み取り専用比較
- PDF・PNG・CSV・テキスト共有
- AdMobバナー・リワード広告
- 広告削除の非消費型購入・復元
- ダークモード
- 端末内データの一括削除

データの保存・OCR・共有・広告の概要は[PRIVACY.md](PRIVACY.md)を参照してください。ストア公開時は、正式なプライバシーポリシーURLを別途用意してください。
公開前の確認項目は[RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)にまとめています。

## スクリーンショット

| ホーム | 見積取込 | 比較結果 |
| --- | --- | --- |
| ![ホーム](docs/screenshots/home.png) | ![見積取込](docs/screenshots/quote-input.png) | ![比較結果](docs/screenshots/comparison.png) |

## セットアップ

### 1. Flutter版を取得

```bash
git clone -b main https://github.com/kaenozu/aimitsumori_app_spec_v0_1.git
cd aimitsumori_app_spec_v0_1
```

### 2. 依存関係を取得

```bash
flutter pub get
```

### 3. デバッグ起動

```bash
make run
```

または:

```bash
flutter run
```

デバッグビルドではGoogle公式のテスト広告IDを使用します。

## 開発用コマンド

| コマンド | 内容 |
| --- | --- |
| `make run` | アプリを起動 |
| `make test` | ユニット・Widgetテストを実行 |
| `make test-integration` | `DEVICE`で指定したデバイス（既定: `windows`）で統合テストを実行 |
| `make analyze` | 静的解析を実行 |
| `make icons` | ランチャーアイコンを生成 |
| `make splash` | ネイティブスプラッシュを生成 |
| `make build-apk` | 開発用Debug APKを作成 |
| `make build-release-apk` | 本番設定を使ってRelease APKを作成 |
| `make audit-release-apk` | Release APKのパッケージ、AdMobテストID、署名を監査 |
| `make release-prep` | アイコン・スプラッシュ生成、解析、テスト、APK作成を順番に実行 |

## Android Release設定

### 1. アップロードキーを作成

例:

```bash
keytool -genkeypair -v \
  -keystore "$HOME/upload-keystore.jks" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

### 2. `android/key.properties` を作成

```bash
cp android/key.properties.example android/key.properties
```

実値を設定します。

```properties
storePassword=CHANGE_ME
keyPassword=CHANGE_ME
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

`android/key.properties` とkeystoreはGit管理対象外です。

### 3. 本番用環境変数を設定

```bash
export ADMOB_ANDROID_APP_ID='ca-app-pub-...~...'
export ADMOB_ANDROID_BANNER_ID='ca-app-pub-.../...'
export ADMOB_ANDROID_REWARDED_ID='ca-app-pub-.../...'
export PURCHASE_VERIFICATION_URL='https://example.com/api/store/verify'
```

### 4. AABを作成

```bash
make build-aab
```

生成物:

```text
build/app/outputs/bundle/release/app-release.aab
```

Releaseビルドでは、署名、AdMobアプリID、広告ユニットID、購入検証URLのいずれかが未設定なら失敗します。テスト広告IDやデバッグ署名へ暗黙フォールバックしません。

## iOS Release設定

### 1. AdMobアプリID設定を作成

```bash
cp ios/Flutter/ReleaseSecrets.xcconfig.example \
  ios/Flutter/ReleaseSecrets.xcconfig
```

```xcconfig
ADMOB_APP_ID=ca-app-pub-...~...
```

`ReleaseSecrets.xcconfig` はGit管理対象外です。

### 2. Releaseビルド時のDart define

```bash
flutter build ios --release \
  --dart-define=ADMOB_IOS_BANNER_ID='ca-app-pub-.../...' \
  --dart-define=ADMOB_IOS_REWARDED_ID='ca-app-pub-.../...' \
  --dart-define=PURCHASE_VERIFICATION_URL='https://example.com/api/store/verify'
```

署名・Provisioning ProfileはXcode側で設定してください。

## 購入検証API

ReleaseではSharedPreferencesの値だけで広告削除権利を付与しません。購入または復元イベントを受けた後、`PURCHASE_VERIFICATION_URL`へHTTPS POSTし、検証成功時だけ権利を付与します。

送信例:

```json
{
  "productId": "remove_ads",
  "purchaseId": "...",
  "transactionDate": "...",
  "source": "google_play_or_app_store",
  "serverVerificationData": "...",
  "localVerificationData": "..."
}
```

成功応答例:

```json
{
  "valid": true,
  "productId": "remove_ads"
}
```

サーバー側では、Google Play Developer APIまたはApp Store Server API等を使用して購入の真正性、商品ID、失効・返金状態を確認してください。

## テスト

```bash
make format
make analyze
make test
```

Androidエミュレーターまたは実機:

```bash
make test-integration DEVICE=emulator-5554
```

Windowsで実行する場合は`make test-integration`（`DEVICE=windows`）を使用します。接続先が複数ある場合は、必ず`DEVICE`を明示してください。

## リリースビルド

Android向けの開発用APKを作成します。

## CI

GitHub Actionsは次を実行します。

Google Play提出用にはAABを使用します。

### 本番リリースの必須設定

本番ビルドは、debug署名やAdMobのテストIDでは作成できません。

1. `android/key.properties.example`を`android/key.properties`へコピーし、リリース用keystoreの情報を設定します。
2. 本番AdMobアプリIDと広告ユニットIDを環境変数から渡します。
3. Google Playの広告削除商品IDを`REMOVE_ADS_PRODUCT_ID`で渡します。

iOSで広告を有効にする場合は、`ios/Runner/Info.plist`の`ADMOB_APP_ID`ビルド設定に本番AdMobアプリIDを渡し、`ADMOB_IOS_BANNER_ID`と`ADMOB_IOS_REWARDED_ID`を`--dart-define`で渡します。未設定のまま本番広告を初期化しないでください。

AndroidのReleaseビルドでは、AdMob IDは`ca-app-pub-...`形式、課金商品IDはGoogle Playで作成した商品ID形式であることも検証されます。

```powershell
$env:ADMOB_APP_ID='ca-app-pub-XXXXXXXX~YYYYYYYY'
$env:ADMOB_ANDROID_BANNER_ID='ca-app-pub-XXXXXXXX/BBBBBBBB'
$env:ADMOB_ANDROID_REWARDED_ID='ca-app-pub-XXXXXXXX/RRRRRRRR'
$env:REMOVE_ADS_PRODUCT_ID='remove_ads_pro'
.\tool\build_android_release.ps1 -Artifact appbundle
```

スクリプトが環境変数を検証し、GradleとDartの両方へ同じ値を渡します。署名情報、本番広告ID、または課金商品IDが未設定・不正の場合は、ビルドを意図的に停止します。
生成物は通常、`build/app/outputs/bundle/release/app-release.aab`に出力されます。

APKのAdMob Application IDと本番設定値まで照合する場合は、次のように指定します。

```powershell
.\tool\audit_android_release.ps1 -ExpectedAdMobAppId $env:ADMOB_APP_ID
```

アイコンやスプラッシュ素材を変更した場合は、ビルド前に次を実行してください。

CI内の広告ID、署名鍵、購入検証URLはビルド経路を検査する一時値であり、本番用ではありません。

## アーキテクチャ

### Models

- `lib/models.dart`: 案件、見積、明細、比較結果、確認質問
- `lib/requirements_models.dart`: 案件要望と差異
- `lib/quote_revision_models.dart`: 改訂履歴と差分
- `lib/ocr_models.dart`: OCR行、矩形、レビュー状態

### Repositories

- `lib/repositories/project_repository.dart`: 案件・見積・比較結果
- `lib/repositories/project_requirement_repository.dart`: 要望チェックリスト
- `lib/repositories/quote_revision_repository.dart`: 改訂履歴

### Services

- `lib/services/database_service.dart`: SQLite v3、マイグレーション、トランザクション
- `lib/services/ocr_service.dart`: PDF・画像のOCR
- `lib/services/ocr_confidence_engine.dart`: OCR信頼度と数値抽出
- `lib/services/requirements_engine.dart`: 要望との差異判定
- `lib/services/quote_revision_service.dart`: 改訂履歴保存
- `lib/services/quote_revision_diff_engine.dart`: 版間差分
- `lib/services/comparison_export_service.dart`: PDF・CSV・共有データ
- `lib/services/ad_service.dart`: 広告と広告削除購入
- `lib/services/purchase_verification_service.dart`: サーバー購入検証
- `lib/services/value_normalizer.dart`: 数値・単位・CSVセル正規化

### Screens

- `lib/screens/onboarding_screen.dart`: 初回案内とサンプル登録
- `lib/screens/home_screen.dart`: 案件一覧、検索、削除
- `lib/screens/requirements_checklist_screen.dart`: 要望入力
- `lib/screens/quote_input_screen.dart`: OCR取込と修正
- `lib/screens/comparison_screen.dart`: 現在の見積比較
- `lib/screens/requirements_comparison_screen.dart`: 要望との差異
- `lib/screens/quote_revision_screen.dart`: 改訂履歴
- `lib/screens/revision_comparison_screen.dart`: 過去版の読み取り専用比較
- `lib/screens/settings_screen.dart`: テーマと全データ削除

比較ロジックは`lib/normalizer.dart`、`lib/comparison_engine.dart`、`lib/question_generator.dart`に分離されています。
