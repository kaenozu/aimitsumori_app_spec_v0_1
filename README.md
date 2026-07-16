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

## データとプライバシー

- OCRは端末内で実行します。
- 見積の原本ファイルパスはCSV・テキスト共有へ含めません。
- 購入検証用データ以外の見積内容を外部サーバーへ送信する実装はありません。
- 購入検証エンドポイントは、ストアの検証データを受け取り、購入の有効性だけを返す構成を想定しています。

## 必要環境

- Flutter SDK 3.44.0
- Dart SDKはFlutter同梱版
- Java 17
- Android Studio / Android SDK
- iOSビルド時はXcodeとCocoaPods
- GNU Make（任意）

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
| `make format` | `lib`・`test`・`integration_test`を整形 |
| `make analyze` | 静的解析を実行 |
| `make test` | ユニット・Widget・実SQLiteテストを実行 |
| `make test-integration` | 接続済み端末またはエミュレーターで統合テストを実行 |
| `make build-debug` | Debug APKを作成 |
| `make build-aab` | 本番設定を検証してRelease AABを作成 |
| `make release-prep` | 整形、解析、テスト、Release AAB作成を実行 |

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
make test-integration
```

主要な回帰テスト:

- SQLite更新時に要望・改訂履歴がCASCADE削除されない
- 見積と改訂履歴の保存が同一トランザクションでロールバックされる
- 改訂番号が順番に採番される
- `1,200`が`1.2`へ誤変換されない
- `500円`等の小額をOCR候補として抽出する
- m/mm、㎡/m²等を正規化する
- CSV数式注入を防止する
- 過去版比較が現在の比較結果を保存しない
- 同一名称の複数明細を改訂差分から欠落させない

## CI

GitHub Actionsは次を実行します。

- Flutter 3.44.0固定
- `dart format --set-exit-if-changed`
- `flutter analyze`
- `flutter test`
- Android Debug APK
- 一時署名鍵を用いたRelease AAB smoke build
- Androidエミュレーター統合テスト
- iOS `--no-codesign` Release build

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
