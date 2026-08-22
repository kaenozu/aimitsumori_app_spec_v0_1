# Changelog

このプロジェクトの主な変更を記録します。

## [0.1.4] - 2026-08-18

Androidリリース候補のバージョン情報を更新したメタデータリリースです。

### Changed

- `pubspec.yaml` のバージョンを `0.1.3+2` から `0.1.4+3` へ更新。

### Release status

- v0.1.3以降、現時点の`main`で確認できる変更は上記バージョン更新のみです。未確認の機能変更はこのエントリへ含めません。
- 本エントリ追加だけではタグ作成・Production AAB生成・Play Console公開を実行しません。既存のrelease blockerと品質ゲートを満たした後にリリース判断します。

## [0.1.3] - 2026-07-29

Play Console内部テスト自動アップロードに対応したリリースです。

### Added

- fastlane + `production_android_aab.yml` workflow による、署名済みAABのPlay Console内部テストへの自動アップロード。
- 日本語OCRレビュー画面でOCR信頼度の低い値をハイライト表示し、確認漏れを防止。
- `TextNormalizer.normalize()` で全角円記号 `￥`（U+FFE5）を `¥`（U+00A5）に正規化。

### Changed

- OCR信頼度エンジンに基づき、信頼度80%未満の金額・数量を `OcrConfidenceEngine` が自動マーク。レビュー画面で視覚的に確認可能。
- `OcrService` の `processBatch` 内で信頼度データを `OcrResult` に含めて返すよう改善。

### Quality and release engineering

- `production` GitHub Environment に `PLAY_SERVICE_ACCOUNT_JSON` を追加し、fastlane から Play Publisher API へ認証可能に。
- `GEMFILE_GEMFILE_LOCK` を Repository Secret に追加し、`Gemfile.lock` のないランナー上でも `bundle install` が成功するよう対応。
- アップロード検証として `google-play-cli` で確認用コマンドを CI ログへ出力。
- `flutter analyze` 0 errors、CI全job（format / analyze / test / E2E / release compile）通過済み。

## [0.1.2] - 2026-07-28

コード品質とリリース再現性を改善するパッチリリースです。

### Changed

- `debugPrint` を `AppLogger`（`dart:developer/log` ベース）に置き換え。本番リリースビルドでも開発者ログを出力可能に。
- `_formatYen` / `_formatQuantity` / `_formatDate` の重複実装を `lib/utils/formatting.dart` へ集約。`comparison_screen.dart`、`quote_revision_screen.dart`、`revision_comparison_screen.dart`、`comparison_export_service.dart` から private 関数を削除。
- `logging` パッケージを直接依存に追加。
- ソースコードと設定ファイルの改行コードをLFへ統一（`.gitattributes` で `*.dart`・`*.yaml` 等を `eol=lf` に指定）。
- 静的解析ルールを強化し、戻り値・未使用コード・非同期処理などの品質上の問題を検出しやすく改善。

### Fixed

- ID生成テストを追加し、短時間に連続生成した場合の衝突回帰を防止。
- 比較処理と画面実装のlint・フォーマット上の不整合を修正。

### Quality and release engineering

- GitHub Freeプラン（プライベートリポジトリ）で Ruleset API が利用できない場合にスキップするよう `configure_github_repository.ps1` を修正。代わりに CI と production environment を主ゲートとして使用。
- `production` GitHub Environment を設定し、デプロイブランチを `main` のみに制限。
- Androidリリース監査manifest生成スクリプトと回帰テストをreleaseブランチへ同期。
- `flutter analyze` 0 errors、Unit / Widget test 153件成功をリリース前品質ゲートとして確認。
- バージョンを `0.1.2+1` へ更新。

### Known release tasks

- 本番署名AABを生成し、Google Play Consoleの内部テストへアップロードする必要があります。
- Android実機で主要フロー、広告、購入・復元、購入検証失敗時の挙動を確認する必要があります。

## [0.1.1] - 2026-07-26

初回配布前の信頼性・リリース運用を補強するパッチリリースです。

### Fixed

- 異常終了やプロセス強制終了後に残った一時スキャン画像を、次回起動時に安全に削除
- 一時画像の削除失敗がアプリ起動やデータベース初期化へ波及しないよう分離
- GitHub標準runnerでRelease APK / AABを生成する際のGradleメモリ上限を適正化

### Quality and release engineering

- 本番署名鍵、本番AdMob設定、Google Play課金商品ID、購入検証URLをRepository Secretsから受け取る本番AAB workflowを追加
- 本番AABに対する署名検証、SHA-256生成、Artifact保存、署名素材の確実な削除を追加
- 通常CIでも一時署名鍵によるRelease APKとAABの両方をコンパイル検証
- リリース対象commitとタグを一致させるため、versionを `0.1.1+2` へ更新

### Known release tasks

- Android実機でのP0 / P1受入テスト結果はIssue #28で管理します。
- GitHubの既定ブランチ変更とmain保護ルールの適用はIssue #26で管理します。
- 本番AAB生成には署名・AdMob・課金・購入検証のRepository Secrets登録が必要です。

## [0.1.0] - 2026-07-26

初回MVPリリースです。複数社の見積書を端末内で取り込み、確認・比較・共有する一連のフローと、リリース前の品質ゲートを整備しました。

### Added

- 案件の作成、検索、削除と、18カテゴリの要望チェックリスト
- PDF、写真、複数ページのカメラ撮影からの見積書取り込み
- 日本語OCR、信頼度表示、原本画像との照合、金額・数量・単位・仕様の確認と修正
- 数量×単価、明細合計、見積合計の不整合検出
- SQLiteによる案件、要望、見積、比較結果、OCR確認状態、改訂履歴の永続化
- 複数社の価格、工事範囲、別途費用、オプション、不明点、要望との差異の比較
- 同一業者の見積改訂履歴、版間差分、比較対象版の切り替え
- 業者へ確認する質問の生成
- PDF、PNG、CSV、テキストの出力と共有
- AdMobバナー・リワード広告、非消費型の広告削除購入、購入復元
- 購入検証API連携と、タイムアウト・HTTP 429・5xxに対する再試行可能な扱い
- オンボーディング、設定画面、ダークモード、触覚フィードバック、全データ削除
- TalkBack向けSemantics、タッチターゲット、200%文字拡大を含むアクセシビリティ対応

### Changed

- カメラスキャナーを、品質ガイド、連続撮影、並べ替え、原本保持、バッチOCRを備えたフローへ拡張
- 比較画面を単純な総合点ではなく、判断材料と確認事項を中心に再構成
- 入力画面を共有バリデータとFormベースへ統一
- Repository境界、依存性注入、テスト用fixtureとmockを整理
- AndroidとiOSのOCR、AdMob、リリース設定を本番ビルドへ向けて整理

### Fixed

- OCR数値解析、全角・桁区切り・負数・数量単位の正規化
- ID衝突、OCRレビューキー、要望質問の保持に関する整合性問題
- SQLite更新の原子性、DB migration、改訂番号の一意性
- カメラ初期化競合、画面破棄後の非同期処理、画像デコードによるUI停止
- FilePicker、ReorderableListView、Flutter 3.44 / Dart 3.12 API変更への追従
- エクスポート時のレイアウト、ファイル名、未確認値の安全な出力
- 触覚フィードバック失敗時に画面操作を止めないフォールバック

### Quality and release engineering

- Dart format、Flutter analyze、Unit / Widget test、Debug APK buildをCI化
- Android API 35エミュレータE2Eと、一時署名鍵によるRelease APK compileをCI化
- SQLite v1からv4へのmigration回帰テストを追加
- 入力、比較、OCR、共有、広告、課金、データ削除、アクセシビリティのテストを追加
- Android実機受入テストのP0 / P1 / P2チェックリストと証跡テンプレートを追加
- Android / iOSのリリース手順、プライバシー方針、署名・AdMob・購入設定の監査手順を追加
- 既定ブランチ変更とmain保護ルールをワンコマンドで適用する `tool/setup-default-branch.ps1` を追加

### Known release tasks

- Android実機でのP0 / P1受入テスト結果はIssue #28で管理します。
- GitHubの既定ブランチ変更とmain保護ルールの適用はIssue #26で管理します。

[0.1.4]: https://github.com/kaenozu/aimitsumori_app_spec_v0_1/tree/v0.1.4
[0.1.3]: https://github.com/kaenozu/aimitsumori_app_spec_v0_1/tree/v0.1.3
[0.1.2]: https://github.com/kaenozu/aimitsumori_app_spec_v0_1/tree/v0.1.2
[0.1.1]: https://github.com/kaenozu/aimitsumori_app_spec_v0_1/tree/v0.1.1
[0.1.0]: https://github.com/kaenozu/aimitsumori_app_spec_v0_1/tree/v0.1.0
