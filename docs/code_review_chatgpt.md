# コードレビュー結果（ChatGPT 2026-07-19）

## 総評

純粋な比較ロジック、Repository層、依存注入用コンストラクタ、Widgetのdisposeなど、MVPとして良い土台があります。一方、現状は SQLite保存の破壊的UPSERT、OCR数値誤変換、改訂履歴の非原子的保存、購入検証不足があり、「比較結果を信用できるアプリ」としてリリースする前に修正すべき問題が残っています。

---

## 発見された問題（重要度順）

### [重大] 依頼されたプロダクト概要と実装ドメインが一致していない

- **ファイル**: `lib/data/category_master.dart`, `README.md`, 全ドメインモデル
- **説明**: 依頼文ではスーパー・ドラッグストア・通販の価格比較アプリとされていますが、実装は外構工事の相見積もりアプリです。プロジェクト概要の修正が必要です。

### [重大] ConflictAlgorithm.replaceにより要望・改訂履歴が連鎖削除される

- **ファイル**: `lib/services/database_service.dart`
- **説明**: `saveProject()` は `ConflictAlgorithm.replace` を使用。SQLiteのREPLACEは既存行を削除して新規挿入する動作です。`project_requirements` と `quote_revisions` は `ON DELETE CASCADE` を持つため、案件名を更新しただけで要望や改訂履歴が消える可能性があります。
- **修正**: REPLACEを廃止し、UPDATE→INSERTのUPSERTへ変更。

### [高] 既定ブランチが旧Kotlin版のmasterになっている

- **説明**: Flutterコードは `main` にあるが、GitHubの既定ブランチは `master` (旧Kotlin/Compose版)。clone、PR、CIが誤った実装を対象にする。
- **修正**: `gh repo edit kaenozu/aimitsumori_app_spec_v0_1 --default-branch main`

### [高] DBスキーマが遅延作成され、正式なマイグレーション管理がない

- **ファイル**: `lib/services/database_service.dart`, `lib/repositories/project_requirement_repository.dart`, `lib/services/quote_revision_service.dart`
- **説明**: DBバージョンは現在も1で `onUpgrade` 未定義。各Repositoryが `CREATE TABLE IF NOT EXISTS` で遅延作成しており、将来のスキーマ変更が安全に適用できない。
- **修正**: 全DDLを `DatabaseService` に集約し、バージョン管理と `onUpgrade` を実装。

### [高] OCRと入力画面で数量・金額が別の数値に変換される

- **ファイル**: `lib/services/ocr_confidence_engine.dart`, `lib/screens/quote_input_screen.dart`
- **説明**: 数量のカンマを無条件に小数点へ置換（例: 1,200㎡ → 1.2㎡）。金額抽出は「カンマ区切り」または「4桁以上」に限定され、500円や800円を抽出不可。全角数字未対応。
- **修正**: `NumericParser` クラスを作成し、全角→半角変換、カンマ区切り判定を分離。

### [高] 見積本体と改訂履歴が別トランザクションで保存される

- **ファイル**: `lib/repositories/project_repository.dart`, `lib/services/quote_revision_service.dart`
- **説明**: 改訂番号は「SELECT→+1→INSERT」で非アトミックに採番。並行保存時に同じ改訂番号が生成される可能性がある。
- **修正**: 同一トランザクション内で現行見積保存と改訂履歴保存を行う。

### [高] 画面間の改訂状態をSingletonで保持している

- **ファイル**: `lib/services/quote_revision_service.dart`, `lib/services/ocr_service.dart`
- **説明**: `QuoteRevisionSession.instance` に改訂元・変更理由を保持。画面の途中終了や複数画面開封で状態漏れのリスク。
- **修正**: 状態は画面引数として明示的に渡す。

### [高] 過去改訂版の比較が現行比較結果を上書きする

- **ファイル**: `lib/screens/quote_revision_screen.dart`, `lib/screens/comparison_screen.dart`
- **説明**: 過去版比較で一時Projectを作成し通常のComparisonScreenを開くが、initState()で比較結果を自動保存するため、現行結果を上書きする可能性がある。
- **修正**: `readOnly` / `persistReport` パラメータを追加。

### [高] 広告削除権利を購入検証前に付与している

- **ファイル**: `lib/services/ad_service.dart`
- **説明**: 起動時にSharedPreferencesの真偽値を購入証明として採用。verificationDataを検証していない。
- **修正**: `PurchaseVerifier` インターフェースを導入し、検証結果に基づいて権利付与。

### [高] CSV Formula Injectionが可能

- **ファイル**: `lib/services/comparison_export_service.dart`
- **説明**: `=`, `+`, `-`, `@` で始まる値を無害化していない。
- **修正**: 先頭が特殊文字の場合 `'` を前置。

### [高] PDFレンダリングと比較画面キャプチャでOOMが発生し得る

- **ファイル**: `lib/services/ocr_service.dart`, `lib/screens/comparison_screen.dart`
- **説明**: PDFページを `scale: 2` で全量レンダリング。キャプチャの最小pixelRatioが0.5で、長い比較画面で上限8,192pxを超える可能性がある。
- **修正**: ページ解像度の上限チェック追加。キャプチャの最小値を0.5に固定せず、超過時はエラー。

### [高] 同一カテゴリ・同一名称の明細が改訂差分から消える

- **ファイル**: `lib/services/quote_revision_diff_engine.dart`
- **説明**: 明細を `categoryId|normalizedLabel` の単一Mapへ格納しているため、重複明細が最後の1件だけになる。
- **修正**: `Map<String, List<QuoteLineItem>>` でグルーピングし、順序付きで突合。

### [高] 複数明細の数量正規化が誤っている

- **ファイル**: `lib/normalizer.dart`
- **説明**: 数量を合計せず、重複除去した値が1種類ならその値を採用。同一カテゴリに10m×2件なら合計20mではなく10mになる。
- **修正**: 明細の数量を合計し、単位を正規化して集約。

---

### [中] 案件一覧がN+1クエリになっている

- **ファイル**: `lib/services/database_service.dart`
- **説明**: 案件取得後、案件ごとに見積→明細を個別クエリ。件数が増えるほどDB往復回数が増加。
- **修正**: 各テーブルを1回ずつ取得しDart側でグルーピング。

### [中] 単位比較に正規化・換算がない

- **ファイル**: `lib/services/requirements_engine.dart`
- **説明**: `㎡` と `m²` を別単位として扱い、1mと1000mmも数量差として比較。
- **修正**: 共通の `ValueNormalizer` で単位正規化。

### [中] OCR確認状態の識別子がパスと32bitハッシュに依存している

- **ファイル**: `lib/ocr_models.dart`, `lib/services/ocr_review_store.dart`
- **説明**: 保存キーはソースファイルパスの32bitハッシュ。ファイル差し替えやパス変更で状態を引き継げない。衝突可能性も。
- **修正**: ファイル内容のSHA-256を使用。確認状態はSQLiteへ保存。

### [中] 注入されたOcrServiceまで画面が破棄する

- **ファイル**: `lib/screens/quote_input_screen.dart`
- **説明**: 共有インスタンスが注入されても `dispose()` 時に閉じる。
- **修正**: `_ownsOcrService` フラグで所有管理。

### [中] ドメインモデルが実質的に可変

- **ファイル**: `lib/models.dart`, `lib/quote_revision_models.dart`
- **説明**: `List` を `final` で保持するが元リスト変更が反映される。
- **修正**: `List.unmodifiable()` で防御的コピー。

### [中] 入力値のドメイン制約が不足

- **ファイル**: `lib/screens/quote_input_screen.dart`, `lib/screens/requirements_checklist_screen.dart`
- **説明**: 負数、0、NaN、Infinityがモデルへ入り得る。
- **修正**: 金額（割引除く負数禁止）、数量（有限・正数）のバリデーション追加。

### [中] DIが部分的で画面が具体実装を生成している

- **ファイル**: 各Screen
- **説明**: `Normalizer`、`QuestionGenerator`、`ComparisonEngine` を直接生成。Singletonフォールバックも多く依存関係が曖昧。
- **修正**: `AppDependencies` コンテナを用意。

### [中] 日本語文言がハードコードされ、表記も一部揺れている

- **ファイル**: 画面全般
- **説明**: 同じoptional状態が「オプション」「任意」「あればよい」と表記揺れ。
- **修正**: `AppStrings` クラスで文言集約。

### [中] 統合テストがCIで実行されていない

- **ファイル**: `.github/workflows/flutter_ci.yml`
- **修正**: `integration_test/app_test.dart` をCIに追加。

---

### [低] バージョン番号が画面にハードコード

- **ファイル**: `lib/screens/settings_screen.dart`
- **修正**: `package_info_plus` で実行時に取得。

### [低] ダークモードのローカル状態が親Widgetのロールバックに追従しない

- **ファイル**: `lib/screens/settings_screen.dart`
- **修正**: `didUpdateWidget` で同期。

### [低] オンボーディングだけSharedPreferencesへ直接依存

- **ファイル**: `lib/screens/onboarding_screen.dart`
- **修正**: `AppPreferences` へ集約。

### [低] sqflite_common_ffiが本番dependenciesにある

- **ファイル**: `pubspec.yaml`
- **修正**: `dev_dependencies` へ移動。

---

## 改善提案

1. **保存処理の受入条件を明文化**: 案件更新で要望・履歴が消えない、見積と改訂履歴のアトミック保存、改訂番号の一意性など。
2. **金額・数量・単位処理を一箇所へ集約**: OCR、入力、比較で共通の `ValueNormalizer` を作成。
3. **DB整合性テストを最優先で追加**: 案件更新後の要望・履歴維持テスト、ロールバックテスト、重複明細テスト。
4. **ローカルデータの脅威モデルを決める**: SQLCipher等の暗号化検討、ファイルパス外部漏洩防止ルール。
5. **推奨検証コマンド**: `flutter analyze`, `flutter test --coverage`, `flutter build appbundle --release` 等。

---

## 良い点

- `ProjectRepository` でUIからSQLite実装を隠蔽、エラーハンドリングも用意
- テスト用注入ポイントが多くのクラスに存在
- OCR処理でファイル容量・PDFページ数に上限、リソースの明示的解放を実施
- Widget側で `mounted` 確認、`TextEditingController.dispose()`、リスナー解除が丁寧
- CSVはUTF-8 BOM、ファイル名は不正文字除去に対応し日本語環境を意識
- Android Release設定は堅実（署名・AdMob ID・テスト広告混入検査）
- CIは `flutter analyze` と `flutter test` の終了コードを強制、ログもArtifact保存
- 「最安を断定しない」「別途・不明点を明示する」方針がロジックと画面に反映
- テストは比較・OCR信頼度・要望比較・改訂差分・Widget・統合導線まで既に存在
