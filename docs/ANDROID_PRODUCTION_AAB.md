# Android 本番AAB生成手順

## 目的

GitHub Actions の `Production Android AAB` workflow で、本番署名鍵・本番AdMob設定・Google Play課金商品ID・購入検証URLを使用したAABを生成します。

`publish_to_internal` を有効にすると、生成・検証した同じAABをfastlaneでGoogle Playの内部テストトラックへアップロードします。Play Consoleの初期設定、サービスアカウント、テスター追加は [Google Play 内部テスト配布手順](GOOGLE_PLAY_INTERNAL_TESTING.md) を参照してください。

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

内部テストへアップロードする場合は、次も必要です。

- `PLAY_SERVICE_ACCOUNT_JSON`: Google Play Developer APIへアクセスするサービスアカウントJSONの内容全体

値はログ、Issue、PR本文、リポジトリ内ファイルへ記載しません。

## versionCode の事前確認

Google Playで使用済みになるのは、Play ConsoleへアップロードしたAPK/AABのversionCodeです。Git tagを作成しただけではversionCodeは使用済みになりません。

Play Consoleへ一度もAPK/AABをアップロードしていない初回リリースでは、`v0.1.2` の `0.1.2+1`（versionCode 1）を使用できます。

アップロード前にPlay Consoleの「最新のリリースとバンドル」またはApp Bundle Explorerで、対象applicationIdに登録済みの最大versionCodeを確認します。

- 登録済みversionCodeがない: `v0.1.2`（versionCode 1）を使用する
- 登録済みversionCodeがある: 新しいversionCodeを最大値より大きくする
- 既存のannotated release tagは移動・上書きしない
- 修正が必要な場合はversionNameも更新し、新しいannotated tagを作成する

例として、versionCode 2が既に登録済みなら `0.1.2+2` は使用できません。`0.1.3+3` など、最大versionCodeを超える新しいリリースを作成します。

手動アップロードとworkflowアップロードの両方で同じversionCodeを送らないでください。

## 実行

1. Actionsで `Production Android AAB` を開く
2. workflowを実行するブランチとして **`main`** を選ぶ
3. `release_ref` にビルド対象のannotated tagを入力する（現在のリリースは `v0.1.2`）
4. AABをArtifactへ保存するだけなら `publish_to_internal` を無効にする
5. Google Play内部テストへ送るなら `publish_to_internal` を有効にする
6. `play_release_status` を選ぶ
   - `completed`: 内部テスターへ配信可能なリリースとして確定する
   - `draft`: draftアプリの初回APIアップロードなど、Consoleで最終確認する場合に使用する
7. `Run workflow` を実行する
8. `Build production-signed AAB` が成功したことを確認する
9. Artifact `aimitsumori-production-aab-<release commit SHA>` を取得する
10. 内部配信を有効にした場合は `Upload to Google Play internal testing` が成功したことを確認する

workflow自体は`main`上の最新リリースツールを使いますが、アプリソースは`release_ref`で指定したannotated tagを別ディレクトリへcheckoutしてビルドします。これにより、リリースパイプラインを改善した後でも、既存タグのソースを変更せず再現可能なAABを生成できます。

workflowは次を拒否します。

- `main`以外からのworkflow実行
- 存在しないtag
- lightweight tag
- checkoutしたcommitとtagのcommitが異なる状態
- tag名と`pubspec.yaml`のversionNameが異なる状態（例: `v0.1.1`と`0.1.2+3`）
- 必須Secretが未設定の状態
- Play内部配信時にサービスアカウントJSONが未設定または無効な状態

Artifactには次の3ファイルが含まれます。

- `app-release.aab`
- `app-release.aab.sha256`
- `release-manifest.json`

workflowはAABに対して `apksigner` または `jarsigner` による署名検証を実行し、SHA-256を生成します。さらに、release tag、release commit SHA、versionName、versionCode、applicationId、AABのサイズとSHA-256、署名証明書のSHA-256フィンガープリントを `release-manifest.json` に記録します。Secret値、keystore、パスワードはmanifestへ含めません。

署名鍵ファイルと `android/key.properties` は成功・失敗にかかわらずrunnerから削除します。サービスアカウントJSONはファイルへ書き出さず、GitHub Secretからfastlaneへ直接渡します。

## 提出前確認

- Play Consoleで登録済みの最大versionCodeを確認し、今回のversionCodeがそれを上回ることを確認する
- `release-manifest.json` のrefが指定したrelease tagと一致する
- manifestのcommit SHAがrelease tagのcommitと一致する
- manifestのversionName / versionCodeがGoogle Playへ登録する値と一致する
- manifestのapplicationIdが `com.kaenozu.aimitsumori_app` である
- manifestの署名証明書SHA-256がPlay App Signingのupload key証明書と一致する
- `app-release.aab.sha256` とmanifest内のAAB SHA-256が一致する
- `CHANGELOG.md` に同じversionの見出しがある
- Google Play Consoleの内部テストでリリースがActiveになっている
- Android実機受入テストを実施する
- AdMob、広告削除購入、購入復元、購入検証API障害時の挙動を確認する

## 失敗時

`Missing required repository secrets` の場合は、表示されたSecret名だけを確認し、値自体は共有しません。

署名エラーの場合は、keystore、alias、各パスワードの組合せと、Play App Signingで登録したupload keyとの一致を確認します。

Play API認証エラーの場合は、Google Play Android Developer APIが有効か、サービスアカウントがPlay Consoleへ招待済みか、対象アプリに「アプリ情報の表示」と「テストトラックへのアプリのリリース」権限があるかを確認します。

新規作成直後のdraftアプリで`completed`が拒否された場合は、`play_release_status: draft`でアップロードし、Play Consoleの内部テスト画面からリリースを確認・公開します。

release sourceの検証に失敗した場合は、`release_ref`がannotated tagであること、tagのcommit、`pubspec.yaml`のversionNameを確認します。

`Generate release manifest` が失敗した場合は、`pubspec.yaml` のversion形式、`android/app/build.gradle.kts` のapplicationId、release commit SHA、署名証明書フィンガープリントを確認します。
