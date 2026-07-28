# Android 本番AAB生成手順

## 目的

GitHub Actions の `Production Android AAB` workflow で、本番署名鍵・本番AdMob設定・Google Play課金商品ID・購入検証URLを使用したAABを生成します。

通常の `Flutter CI / Release APK compile` は一時署名鍵とCI用IDによるコンパイル検証です。Google Playへ提出する成果物には使用しません。

## 必須 Repository Secrets

リポジトリの `Settings > Secrets and variables > Actions` に、次のRepository Secretを登録します。

- `ANDROID_KEYSTORE_BASE64`: upload keystoreをBase64化した文字列
- `ANDROID_KEYSTORE_PASSWORD`: keystoreのパスワード
- `ANDROID_KEY_PASSWORD`: keyのパスワード
- `ANDROID_KEY_ALIAS`: upload key alias
- `ADMOB_APP_ID`: 本番Android AdMobアプリID
- `ADMOB_ANDROID_BANNER_ID`: 本番バナー広告ユニットID
- `ADMOB_ANDROID_REWARDED_ID`: 本番リワード広告ユニットID
- `REMOVE_ADS_PRODUCT_ID`: Google Playの広告削除商品ID
- `PURCHASE_VERIFICATION_URL`: HTTPSの購入検証API URL

値はログ、Issue、PR本文、リポジトリ内ファイルへ記載しません。

## 実行

1. `main` の `Actions` を開く
2. `Production Android AAB` を選択する
3. `Run workflow` を実行する
4. `Build production-signed AAB` が成功したことを確認する
5. Artifact `aimitsumori-production-aab-<commit SHA>` を取得する

Artifactには次の3ファイルが含まれます。

- `app-release.aab`
- `app-release.aab.sha256`
- `release-manifest.json`

workflowはAABに対して `jarsigner -verify -strict` を実行し、SHA-256を生成します。さらに、commit SHA、Git ref、versionName、versionCode、applicationId、AABのサイズとSHA-256、署名証明書のSHA-256フィンガープリントを `release-manifest.json` に記録します。Secret値、keystore、パスワードはmanifestへ含めません。

署名鍵ファイルと `android/key.properties` は成功・失敗にかかわらずrunnerから削除します。

## 提出前確認

- `release-manifest.json` のcommit SHAがリリース対象の`main`と一致する
- manifestのversionName / versionCodeがGoogle Playへ登録する値と一致する
- manifestのapplicationIdが `com.kaenozu.aimitsumori_app` である
- manifestの署名証明書SHA-256がPlay App Signingのupload key証明書と一致する
- `app-release.aab.sha256` とmanifest内のAAB SHA-256が一致する
- `CHANGELOG.md` に同じversionの見出しがある
- Google Play Consoleの内部テストへアップロードする
- Android実機受入テストを実施する
- AdMob、広告削除購入、購入復元、購入検証API障害時の挙動を確認する

## 失敗時

`Missing required repository secrets` の場合は、表示されたSecret名だけを確認し、値自体は共有しません。

署名エラーの場合は、keystore、alias、各パスワードの組合せと、Play App Signingで登録したupload keyとの一致を確認します。

`Generate release manifest` が失敗した場合は、`pubspec.yaml` のversion形式、`android/app/build.gradle.kts` のapplicationId、commit SHA、署名証明書フィンガープリントを確認します。
