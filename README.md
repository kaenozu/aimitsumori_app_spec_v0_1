# 相見積もり比較

複数社の見積書を、単純な総合点や順位ではなく、**価格・工事範囲・別途費用・オプション・不明点**の差として整理するFlutterアプリです。

PDFまたは写真から見積書を取り込み、端末内OCRで抽出した内容を確認・修正したうえで、カテゴリ別の比較表と業者への確認質問を作成します。案件・見積・比較結果は端末内のSQLiteに保存されます。

## 主な機能

- 案件の作成、検索、スワイプ削除
- PDF・写真からの見積書取り込み
- OCR結果の確認・修正
- 複数社のカテゴリ別比較
- 別途費用、オプション、不明点の可視化
- 比較結果の共有
- ダークモード
- 端末内データの一括削除

## スクリーンショット

> リリース前に以下の画像へ差し替えてください。

| ホーム | 見積取込 | 比較結果 |
| --- | --- | --- |
| `docs/screenshots/home.png` | `docs/screenshots/quote-input.png` | `docs/screenshots/comparison.png` |

## セットアップ

### 必要環境

- Flutter SDK（`pubspec.yaml`のSDK制約を満たすバージョン）
- Android Studio、または接続済みAndroid端末
- Android SDK
- Java 17
- GNU Make（Makefileを利用する場合）

### 1. リポジトリを取得

```bash
git clone https://github.com/kaenozu/aimitsumori_app_spec_v0_1.git
cd aimitsumori_app_spec_v0_1
```

### 2. 依存関係を取得

```bash
flutter pub get
```

### 3. アプリを起動

```bash
make run
```

Makeを使用しない場合は、次のコマンドでも起動できます。

```bash
flutter run
```

## 開発用コマンド

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

## テストと静的解析

```bash
make analyze
make test
```

Androidエミュレーターまたは実機で統合テストを実行する場合:

```bash
make test-integration
```

## リリースビルド

Android APKを作成します。

```bash
make build-apk
```

生成物は通常、`build/app/outputs/flutter-apk/app-release.apk`に出力されます。

アイコンやスプラッシュ素材を変更した場合は、ビルド前に次を実行してください。

```bash
make icons
make splash
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
- `lib/services/app_preferences.dart`: ダークモード設定の保存
- `lib/services/haptic_service.dart`: 主要操作の触覚フィードバック

### Screens

- `lib/screens/onboarding_screen.dart`: 初回案内とサンプルデータ登録
- `lib/screens/home_screen.dart`: 案件一覧、検索、スワイプ削除、設定画面への導線
- `lib/screens/quote_input_screen.dart`: PDF・写真の取込と抽出結果の確認
- `lib/screens/comparison_screen.dart`: カテゴリ別比較と確認質問の表示
- `lib/screens/settings_screen.dart`: テーマ、アプリ情報、全データ削除

比較ロジックは`lib/normalizer.dart`、`lib/comparison_engine.dart`、`lib/question_generator.dart`に分離されています。
