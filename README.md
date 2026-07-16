# 相見積もり比較

複数社の見積書を、単純な総合点や順位ではなく、**価格・工事範囲・別途費用・オプション・不明点**の差として整理するFlutterアプリです。

PDFまたは写真から見積書を取り込み、端末内OCRで抽出した内容を確認・修正したうえで、カテゴリ別の比較表と業者への確認質問を作成します。データは端末内のSQLiteに保存されます。

## スクリーンショット

> リリース前に以下の画像へ差し替えてください。

| ホーム | 見積取込 | 比較結果 |
| --- | --- | --- |
| `docs/screenshots/home.png` | `docs/screenshots/quote-input.png` | `docs/screenshots/comparison.png` |

## セットアップ

### 必要環境

- Flutter SDK（`pubspec.yaml`のSDK制約を満たすバージョン）
- Android Studio または接続済みAndroid端末
- Android SDK / Java 17

### 依存関係の取得

```bash
flutter pub get
```

### アプリの起動

```bash
flutter run
```

## リリースビルド

Android APKを作成します。

```bash
flutter build apk --release
```

生成物は通常、`build/app/outputs/flutter-apk/app-release.apk`に出力されます。

アイコンやスプラッシュ素材を変更した場合は、ビルド前に次を実行してください。

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## アーキテクチャ概要

### Models

- `lib/models.dart`
- 案件、業者見積、明細、比較結果、確認質問などのドメインモデルを定義します。

### Repositories

- `lib/repositories/project_repository.dart`
- UIとSQLite実装の間に入り、案件・見積・比較結果の保存操作をまとめます。

### Services

- `lib/services/database_service.dart`: SQLiteへの永続化
- `lib/services/ocr_service.dart`: PDF・画像からのOCR処理
- `lib/services/ad_service.dart`: 広告表示と広告削除課金
- `lib/services/comparison_export_service.dart`: 比較結果の共有テキスト生成
- `lib/services/app_preferences.dart`: テーマ、通知設定、最終比較日時の保存
- `lib/services/haptic_service.dart`: 操作時の触覚フィードバック

### Screens

- `lib/screens/onboarding_screen.dart`: 初回案内とサンプルデータ登録
- `lib/screens/home_screen.dart`: 案件一覧、検索、削除、設定画面への導線
- `lib/screens/quote_input_screen.dart`: PDF・写真の取込と抽出結果の確認
- `lib/screens/comparison_screen.dart`: カテゴリ別比較と確認質問の表示
- `lib/screens/settings_screen.dart`: テーマ、通知、アプリ情報、全データ削除

比較ロジックは`lib/normalizer.dart`、`lib/comparison_engine.dart`、`lib/question_generator.dart`に分離されています。

## Makefileコマンド

| コマンド | 内容 |
| --- | --- |
| `make run` | アプリを起動 |
| `make test` | ユニット・Widgetテストを実行 |
| `make test-integration` | 統合テストを実行 |
| `make analyze` | 静的解析を実行 |
| `make icons` | ランチャーアイコンを生成 |
| `make splash` | ネイティブスプラッシュを生成 |
| `make build-apk` | Release APKを作成 |
| `make release-prep` | アイコン・スプラッシュ生成、解析、テスト、APK作成を順番に実行 |

## テスト

```bash
flutter analyze
flutter test
```

Androidエミュレーターまたは実機で統合テストを実行する場合:

```bash
flutter test integration_test
```
