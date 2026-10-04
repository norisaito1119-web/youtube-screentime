import AppKit
import SwiftUI

//⭐️起動後のスタート⭐️

// Shared applicationの初期化
let app = NSApplication.shared //AppKitの1つ

// アプリの起動モードを「アクセサリ（エージェント）」に設定
// これにより、Dockやアプリケーションスイッチャー（Cmd+Tab）に表示されなくなります
NSApp.setActivationPolicy(.accessory)

// SwiftUI アプリケーションを起動
YouTubeScreenTimeApp.main()
