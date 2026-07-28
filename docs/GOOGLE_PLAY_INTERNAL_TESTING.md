# Google Play 内部テスト配布手順

## 対象

- アプリ名: 愛みつもり
- applicationId: `com.kaenozu.aimitsumori_app`
- 現在のリリース: `0.1.2+1`（versionCode 1）
- 既存の本番AAB workflow: `.github/workflows/production_android_aab.yml`

この手順では、Google Play Consoleでアプリを作成し、Play App Signingを有効化し、本番署名済みAABを内部テストへ配布します。

## 最低限追加で必要なもの

既存の署名・AdMob・課金用Secretsが正しい前提では、追加作業は次の5点です。

1. Play Consoleでアプリ `愛みつもり` を作成する
2. Google Play Developer API用サービスアカウントを作成し、対象アプリへ権限を付与する
3. サービスアカウントJSONをGitHub Secret `PLAY_SERVICE_ACCOUNT_JSON` に登録する
4. `Production Android AAB` workflowを実行し、内部テストへアップロードする
5. 内部テスターを追加し、オプトインURLをテスト端末で開く

`google-services.json` はGoogle Playへのアップロードには不要です。このプロジェクトのAdMob Application IDはGradleのmanifest placeholderで設定されています。

## 1. Play Consoleでアプリを作成する

1. Play Consoleを開く: https://play.google.com/console/
2. `ホーム > アプリを作成` を選ぶ
3. 次を設定する
   - デフォルト言語: 日本語
   - アプリ名: 愛みつもり
   - 種別: アプリ
   - 無料／有料: 無料（後から無料アプリを有料へ変更できないため注意）
   - 連絡先メールアドレス
4. Developer Program Policies、米国輸出法の申告を確認する
5. Play App Signing利用規約へ同意する
6. `アプリを作成` を押す

最初のAABをアップロードすると、package name `com.kaenozu.aimitsumori_app` はそのPlay Consoleアプリへ固定されます。別アプリへ付け替えできません。

## 2. Play App Signingとupload key

### 推奨構成

- app signing key: Google Playが生成・保管する
- upload key: 開発者側で保管し、AABのアップロード署名に使用する

新規アプリでは、最初のAABアップロード時にGoogle Playがapp signing keyを生成する推奨設定を使用します。独自のapp signing keyを持ち込む必要はありません。

### 既存のCI keystoreはupload keyか

リポジトリのworkflowは `ANDROID_KEYSTORE_BASE64` を `upload-keystore.jks` として復元し、AABへ署名しています。そのため、設計上はこのkeystoreをupload keyとして使用する前提です。

ただしSecretの実体はリポジトリから確認できないため、次を照合して確定します。

1. `Production Android AAB` workflowを実行する
2. Artifact内の `release-manifest.json` を開く
3. `signerCertificateSha256` を確認する
4. Play Consoleの `設定 > アプリの完全性`（Play App Signing）でupload key証明書のSHA-256と一致することを確認する

ローカルkeystoreを保持している場合は、次でも確認できます。

```bash
keytool -list -v \
  -keystore /path/to/upload-keystore.jks \
  -alias <ANDROID_KEY_ALIAS>
```

最初のAABがまだ一度もPlay Consoleへ登録されていない場合、現在のversionCode 1を使用できます。既にversionCode 1以上が登録済みなら、`pubspec.yaml`のversionCodeを最大値より大きくし、新しいannotated tagを作成してください。既存の`v0.1.2` tagは移動・上書きしません。

## 3. サービスアカウントを作成する

### Google Cloud側

1. Google Cloud Consoleを開く: https://console.cloud.google.com/
2. 使用するGoogle Cloud Projectを選ぶか新規作成する
3. Google Play Android Developer APIを有効化する:
   https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com
4. サービスアカウント画面を開く:
   https://console.cloud.google.com/iam-admin/serviceaccounts
5. `サービス アカウントを作成` を押す
6. 例として名前を `github-actions-play-upload` にする
7. Google Cloud IAMロールは付与せず作成を完了する
8. 作成したサービスアカウントを開く
9. `キー > 鍵を追加 > 新しい鍵を作成 > JSON` を選ぶ
10. ダウンロードしたJSONを安全に保管する

サービスアカウントJSONは再ダウンロードできません。紛失時は新しい鍵を作成し、古い鍵を削除します。

### Play Console側

1. Play Consoleの `ユーザーと権限` を開く
2. `新しいユーザーを招待` を押す
3. サービスアカウントのメールアドレスを入力する
4. アプリアクセスで `愛みつもり` のみを選ぶ
5. 最小権限として次を付与する
   - アプリ情報の表示（読み取り専用）
   - テストトラックへのアプリのリリース
6. テスターリストもサービスアカウントで変更する場合だけ、次も付与する
   - テストトラックの管理とテスターリストの編集
7. 本番公開を自動化しない段階では、`本番環境へのリリース、デバイスの除外、Play App Signingの使用` は付与しない
8. 招待を確定する

Google Play Developer APIの設定では、Play ConsoleアカウントとGoogle Cloud Projectを従来のように「リンク」する操作は不要です。

## 4. GitHub Secretを追加する

1. GitHubリポジトリを開く
2. `Settings > Secrets and variables > Actions`
3. `New repository secret` を押す
4. Name: `PLAY_SERVICE_ACCOUNT_JSON`
5. Secret: ダウンロードしたJSONファイルの内容全体
6. 保存する

JSONファイル自体をリポジトリへ追加しないでください。PR、Issue、Actionsログにも貼り付けません。

## 5. fastlane構成

追加済みファイル:

```text
Gemfile
fastlane/
  Appfile
  Fastfile
```

認証確認:

```bash
PLAY_SERVICE_ACCOUNT_JSON="$(cat /secure/path/service-account.json)" \
  bundle exec fastlane android validate_play_credentials
```

既存AABを内部テストへアップロード:

```bash
PLAY_SERVICE_ACCOUNT_JSON="$(cat /secure/path/service-account.json)" \
PLAY_AAB_PATH="build/app/outputs/bundle/release/app-release.aab" \
PLAY_RELEASE_STATUS="completed" \
  bundle exec fastlane android internal
```

fastlaneはストア掲載文、画像、スクリーンショット、変更履歴を変更せず、指定AABだけを`internal`トラックへアップロードします。

## 6. GitHub Actionsから内部テストへ配信する

PRをmainへマージ後、次を実行します。

1. GitHubの `Actions` を開く
2. `Production Android AAB` を選ぶ
3. `Run workflow` を押す
4. 実行ブランチ: `main`
5. `release_ref`: `v0.1.2`
6. `publish_to_internal`: 有効
7. `play_release_status`:
   - 通常: `completed`
   - 新規作成直後のdraftアプリでAPIがcompletedを拒否する場合: `draft`
8. workflowを実行する

workflowは次を順番に実行します。

1. annotated tagとバージョンを検証
2. 本番SecretsでAABをビルド
3. AAB署名、SHA-256、署名証明書を検証
4. AABとmanifestをArtifactへ保存
5. Play API認証を検証
6. AABを内部テストトラックへアップロード

`completed`が成功すれば、そのリリースは内部テスターへ配信可能な状態になります。

初回だけ`draft`を使った場合は、Play Consoleの `テストとリリース > テスト > 内部テスト` でdraftリリースを開き、`リリースを確認`、`内部テストとして公開`を実行します。

同じversionCodeのAABは再アップロードできません。手動アップロードとworkflowアップロードの両方で同じ`v0.1.2`を送らないでください。

## 7. 手動アップロードを使う場合

初回だけ手動で進める場合は次の手順です。

1. Play Consoleの `テストとリリース > テスト > 内部テスト` を開く
2. `新しいリリースを作成` を押す
3. Play App Signingの案内が出たら推奨設定を選ぶ
4. `app-release.aab` をアップロードする
5. versionCodeが1で、未使用であることを確認する
6. リリース名・リリースノートを入力する
7. `次へ` または `リリースを確認` を押す
8. エラーを解消し、`内部テストとして公開`を押す

手動でversionCode 1をアップロードした後、同じ`v0.1.2`をfastlaneから再アップロードしないでください。次回はversionCodeを2以上へ更新し、新しいリリースtagを作成します。

## 8. テスターを追加する

1. Play Consoleの `テストとリリース > テスト > 内部テスト` を開く
2. `テスター` タブを選ぶ
3. `メールリストを作成` を押す
4. GoogleアカウントまたはGoogle Workspaceアカウントのメールアドレスを登録する
5. 作成したリストを内部テストへ割り当てる
6. フィードバック用メールアドレスまたはURLを設定する
7. オプトインURLをコピーする
8. テスト端末で、登録済みGoogleアカウントにログインする
9. オプトインURLを開き、テスター参加を承認する
10. 表示されたGoogle Playリンクからインストールする

内部テストは1アプリにつき最大100人です。初回公開後はリンクが利用可能になるまで数時間かかる場合があります。通常の更新は数分程度で反映されます。

アプリ内課金を無料でテストする場合は、内部テスターとは別にPlay Consoleのライセンステストユーザーへ対象アカウントを追加してください。

## 9. 完了条件

- Play Consoleにpackage name `com.kaenozu.aimitsumori_app` のアプリが存在する
- Play App Signingが有効である
- upload key証明書とCI署名証明書のSHA-256が一致する
- 内部テストトラックにversionCode 1以上のリリースがActiveになっている
- テスターがオプトイン済みである
- テスト端末のGoogle Playからインストールできる
- 起動、OCR、広告表示、購入・復元を実機で確認している
