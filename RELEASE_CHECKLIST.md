# リリースチェックリスト

## Sprint 5 マージ基準

- [ ] `flutter analyze --no-fatal-infos` がエラーなしで完了する
- [ ] `flutter test` が全件成功する
- [ ] `flutter test -d <android-device> test/integration/sprint5_e2e_test.dart -r expanded` が成功する
- [ ] `flutter build apk --release` 相当のCIジョブが成功し、`app-release.apk`が生成される
- [ ] GitHub Actionsの`Analyze and test`、`Android emulator E2E`、`Release APK compile`がすべて成功する
- [ ] 既存テスト、SQLiteスキーマ、公開済み画面仕様を壊す変更がない

`Release APK compile`は、コンパイル可能性だけを検証するために一時署名鍵とCI用IDを使用します。生成物はGoogle Playへ提出せず、公開時は本番署名鍵・本番AdMob ID・本番課金商品IDで改めてビルドしてください。

## 自動検証

- [ ] `flutter analyze --no-pub --no-fatal-infos`
- [ ] `flutter test --no-pub`
- [ ] `flutter test --no-pub -d <device> integration_test/app_test.dart -r expanded`
- [ ] `flutter test --no-pub -d <android-device> test/integration/sprint5_e2e_test.dart -r expanded`
- [ ] `tool/build_android_release.ps1 -Artifact appbundle` が成功する
- [ ] `tool/audit_android_release.ps1` が成功する（端末受入用APK）
- [ ] AABが本番用署名鍵で署名されている
- [ ] AABへ検証用AdMob ID・GoogleテストID・検証用課金商品IDが混入していない

本番AABは [Android 本番AAB生成手順](docs/ANDROID_PRODUCTION_AAB.md) に従い、GitHub Actionsの `Production Android AAB` workflowから生成します。

- [ ] workflowを`main`から実行した
- [ ] `release_ref`に対象のannotated release tagを指定した
- [ ] workflowがrelease tagのcommitをcheckoutした
- [ ] release tag名と`pubspec.yaml`のversionNameが一致した
- [ ] 必須Repository Secretsを登録した
- [ ] `Build production-signed AAB` が成功した
- [ ] `jarsigner -verify -strict` が成功した
- [ ] `app-release.aab.sha256` をリリース記録へ保存した
- [ ] `release-manifest.json` をリリース記録へ保存した
- [ ] manifestのrefがrelease tagと一致している
- [ ] manifestのcommit SHAがrelease tagのcommitと一致している
- [ ] manifestのversionName / versionCode / applicationIdがGoogle Play提出内容と一致している
- [ ] manifestの署名証明書SHA-256がPlay App Signingのupload key証明書と一致している
- [ ] manifest内のAAB SHA-256が`app-release.aab.sha256`と一致している

## Android実機確認

詳細な手順、期待結果、証跡、障害系ケースは [Android実機受入テスト](docs/ANDROID_REAL_DEVICE_ACCEPTANCE.md) を使用してください。

- [ ] 実行端末、Androidバージョン、アプリ版、commit SHA、配布経路を記録した
- [ ] P0ケース（データ損失・課金・クラッシュ）を全件実施した
- [ ] P1ケース（主要UX・端末連携）を全件実施した
- [ ] P2の未実施・失敗をIssue化し、リリース可否を記録した
- [ ] 初回起動とオンボーディング
- [ ] 案件作成、要望チェック、案件削除
- [ ] 不正な金額・数量が保存されず、入力エラーが表示される
- [ ] 2社以上の見積を保存し、比較結果・金額・数量・単位を確認できる
- [ ] アプリ再起動後も案件と見積が残っている
- [ ] PDF読込と写真読込
- [ ] 日本語OCR結果の確認・修正・保存
- [ ] OCRの重大な未確認項目を保存前に警告できる
- [ ] 複数社比較、比較結果の更新、共有
- [ ] 順位や総合点を付けず、条件差と不明点を比較する方針が維持されている
- [ ] 広告表示、広告削除購入、購入復元
- [ ] 「全データを削除」で案件・見積・比較結果・OCR確認状態が消える

## ストア情報

- [ ] Google Playの商品IDが本番商品と一致している
- [ ] AdMobの本番アプリID・広告ユニットIDを設定している
- [ ] 公開用プライバシーポリシーURLを登録している
- [ ] ストア掲載画像、説明文、対象年齢、データセーフティ申告を確認している
- [ ] バージョン名・バージョンコードを更新している

## iOSを公開する場合

- [ ] `ADMOB_APP_ID`をXcodeのReleaseビルド設定へ渡している
- [ ] `ADMOB_IOS_BANNER_ID`と`ADMOB_IOS_REWARDED_ID`を本番値で渡している
- [ ] 実機でカメラ、写真、PDF、OCR、共有、購入復元を確認している
- [ ] App Store Connectのプライバシー情報を登録している

## 現在のリポジトリで未完了の項目

本チェックリストのうち、本番署名鍵、本番AdMob・課金ID、公開URL、実機OCR・購入確認は、運営者のストア設定と実機が必要です。検証用鍵やダミーIDで作成したAPK・AABは公開物として使用しません。
