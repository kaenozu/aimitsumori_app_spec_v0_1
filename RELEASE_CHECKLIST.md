# リリースチェックリスト

## 自動検証

- [ ] `flutter analyze --no-pub`
- [ ] `flutter test --no-pub`
- [ ] `flutter test --no-pub -d <device> integration_test/app_test.dart -r expanded`
- [ ] `tool/build_android_release.ps1 -Artifact appbundle` が成功する
- [ ] `tool/audit_android_release.ps1` が成功する（端末受入用APK）
- [ ] AABが本番用署名鍵で署名されている
- [ ] AABへ検証用AdMob ID・GoogleテストID・検証用課金商品IDが混入していない

## Android実機確認

- [ ] 初回起動とオンボーディング
- [ ] 案件作成、要望チェック、案件削除
- [ ] PDF読込と写真読込
- [ ] 日本語OCR結果の確認・修正・保存
- [ ] OCRの重大な未確認項目を保存前に警告できる
- [ ] 複数社比較、比較結果の更新、共有
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

本チェックリストのうち、本番署名鍵、本番AdMob・課金ID、公開URL、実機OCR・購入確認は、運営者のストア設定と実機が必要です。検証用鍵やダミーIDで作成したAABは公開物として使用しません。
