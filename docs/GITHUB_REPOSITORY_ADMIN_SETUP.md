# GitHubリポジトリ管理設定

## 目的

Flutter実装の正規ブランチを `main` に統一し、CIが成功していない変更、直接push、force push、ブランチ削除が `main` に入らないようにします。

`.github/rulesets/main-required-checks.json` はGitHub Repository Ruleset APIへ渡す宣言ファイルです。リポジトリ内へ配置しただけでは保護は有効にならないため、Repository Administration権限を持つ管理者が一度適用してください。

## 前提条件

- GitHub CLI `gh` がインストール済み
- `gh auth login` 済み
- `kaenozu/aimitsumori_app_spec_v0_1` に対する `Administration: Read and write` 権限を持つアカウントまたはトークン
- `main` ブランチが存在する

## ワンコマンド適用

リポジトリのルートで次を実行します。

```powershell
pwsh -NoProfile -File .\tool\setup-default-branch.ps1
```

スクリプトは冪等です。同じコマンドを再実行すると、既定ブランチと同名rulesetを現在の宣言内容へ更新します。

`tool/setup-default-branch.ps1` は管理者向けの安定した入口で、実処理を `tool/configure_github_repository.ps1` へ委譲します。

## 実行される設定

1. 対象リポジトリと `main` の存在確認
2. 既定ブランチを `main` へ変更
3. `main-required-checks` rulesetを作成または更新
4. rulesetを `active` で有効化
5. pull request経由の更新を要求
6. review conversationの解決を要求
7. force pushとブランチ削除を禁止
8. 次のstatus checkをstrict modeで必須化

- `Format, analyze, test, debug build`
- `Android emulator E2E`
- `Release APK compile`

個人開発で自己承認ができない状態を避けるため、承認レビュー数は0にしています。CIと未解決conversationは引き続き必須です。

## 宣言ファイルだけを検証する

GitHub設定を変更せず、JSON構造と必須チェック名だけを検証する場合:

```powershell
pwsh -NoProfile -File .\tool\setup-default-branch.ps1 -ValidateOnly
```

この検証は `Flutter CI` のquality jobでも、委譲先の設定スクリプトに対して実行します。

## 適用後の確認

```powershell
gh repo view kaenozu/aimitsumori_app_spec_v0_1 --json defaultBranchRef
gh api repos/kaenozu/aimitsumori_app_spec_v0_1/rulesets
```

GitHub Web UIでは次を確認します。

- Settings → General → Default branch が `main`
- Settings → Rules → Rulesets に `main-required-checks` が表示され、Enforcement statusがActive
- `main` 向けPRで3つのCIチェックが必須表示される
- 直接pushとforce pushが拒否される

## 移行後の整理

- Issue #26の完了条件を確認してcloseする
- `master` が不要なら削除する
- `archive/master-legacy-20260726` は移行確認が終わるまで保持する
- `.github/workflows/flutter_ci.yml` の `master` トリガーを残すか削除するか判断する

## トラブルシューティング

- `HTTP 403 Resource not accessible by integration`: 使用中のトークンまたはGitHub Appに `Administration: Read and write` を付与してください。
- `HTTP 422`: 同名rulesetの競合、プラン制限、status check名の不一致を確認してください。
- status checkが候補に出ない: 対象チェックを `main` またはPRで一度実行してから再適用してください。
