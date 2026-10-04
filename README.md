# youtube-screentime

SafariでのYouTube視聴時間を計測するmacOSメニューバーアプリ（Swift / SwiftUI）。

- 10秒ごとにSafariの最前面タブのURLを確認し、YouTubeなら視聴時間を加算
- 1日の制限時間を超えるとDiscordに通知
- 日付が変わると前日の視聴時間をDiscordに投稿

## セットアップ

1. `Secrets.example.swift` をコピーして `Secrets.swift` にし、DiscordのwebhookのURLを書く
2. Xcodeで `youbutescreentime.xcodeproj` を開いてビルド
3. 初回起動時に「Safariを制御」の許可を出す
