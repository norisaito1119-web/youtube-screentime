import Foundation //★NSObject(色んな親クラス)★
import AppKit //★NSStatusItem(アイコンを置くクラス)★
import Combine
import SwiftUI


//上側メニュバーに表示&クリックメニュー管理クラス
class MenubarController:NSObject{
    static let shared = MenubarController()
    
    private var statusItem: NSStatusItem! //!:暗黙的アンラップオプショナル(あとで必ず値入るから、普通に使わせて！)
    private var cancellables = Set<AnyCancellable>() //TrackingEngine(l14と同様)
    
    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     親クラス：NSObject 子クラス：MenubarControllerである
     override:親のメソッドを子クラスで上書きすること,だからl20は【子】を初期化
     superは親クラス自身を表すキーワード
     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
    private override init(){
        super.init()
        
        // システムステータスバーに可変長の項目を追加　　　　↓アイコンの幅              ↓自動調整
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        //メニューの初期構築
        updateMenu()//[M1-1]
        
        
        // AppStateの各種プロパティを監視し、値の変更をメニューバーに動的反映
        Publishers.CombineLatest3( //AppState(l33~57)
            AppState.shared.$todaySpentTime, //$:通知役→.sinkに教えている
            AppState.shared.$dailyLimit,
            AppState.shared.$extendedMinutes
        )
        //.sink:変わった値を受け取る。.store:それを保存
        .receive(on: RunLoop.main)//メインスレッド??
        .sink { [weak self] spentTime, dailyLimit, extendedMinutes in
            self?.updateStatusItem(spentTime: spentTime, totalLimit: dailyLimit + extendedMinutes)
        }
        .store(in: &cancellables)
        
        // トラッキング状態の変更を監視してメニュー表示を切り替え??s
        AppState.shared.$isTrackingEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }//オーバードライブ閉じ
        
        // 外部起動用プレースホルダ
        func setup() {
            // インスタンス作成を強制するための空メソッド
        }
        
        //[M2-1]ステータスバー表示文字色と色の更新
        //SpentTime :今日のつべ時間。totalLimit= dailyLimit:設定した制限時間。 + extendedMinutes:延長した時間
        private func updateStatusItem(spentTime: TimeInterval, totalLimit: Int){
            guard let button = statusItem.button else {return}
            
            let spentMinutes = Int(spentTime/60)
            let isExceeded = spentMinutes  >= totalLimit //型推論 (大きいか否かだから)
            
            if isExceeded{ //TURE:制限時間オーバー時は、赤文字かつ警告マークを表示
                let title = "⚠️ \(spentMinutes)分"
                //"制限超過"(赤色・太字・13pt)
                let attributed  = NSAttributedString(string: title, attributes: [
                    .foregroundColor: NSColor.systemRed,
                    .font: NSFont.systemFont(ofSize: 13, weight: .bold)
                ])
                button.attributedTitle = attributed
            }else{ // FALSE:（デフォルトカラー自動追従）
                let title = "📺 \(spentMinutes)分"
                let attributed = NSAttributedString(string: title, attributes: [
                    .font: NSFont.systemFont(ofSize: 13)
                ])
                button.attributedTitle = attributed
            }
           
            updateMenu() // [M?-?]メニューの中身も再生成して最新時間を反映
        }//M2-1の閉じ
        
        //[M1-1]右クリック,左クリックメニュー生成&更新
        //
        private func updateMenu(){
            let menu = NSMenu() //macOSのメニューバー箱
            
            let spentMinutes = Int(AppState.shared.todaySpentTime / 60)
            let totalLimit = AppState.shared.totalAllowedMinutes //AppState l88
            let percent = Int(AppState.shared.progress * 100) //AppState l99 進捗率
            
            // 1. 今日の使用時間ヘッダー（選択不可）
            let progressItem = NSMenuItem( //macOSのメニューバー1つ1つ設定
                 title: "今日の進捗: \(spentMinutes)分 / \(totalLimit)分 (\(percent)%)",
                action: nil, //クリック時なにもしない
                keyEquivalent: "" //ショトカキーなし
            )
        
            progressItem.isEnabled = false
            menu.addItem(progressItem)
            
            menu.addItem(NSMenuItem.separator())
             
            // 2. 設定画面の起動
            let settingsItem = NSMenuItem(
                title: "設定を開く...",
                action: #selector(openSettings), //[M3-1] #selector:メニュークリック後 openSettings() を呼んで
                keyEquivalent: ","
                )
            settingsItem.target = self //クリックされた時のインスタンス
            menu.addItem(settingsItem) //l99を呼び出す
            
            // 3. トラッキング有効/無効の切り替え
            //三項演算子（条件演算子）→ (条件) ? [Tのとき] : [Fのとき]
            let trackingTitle = AppState.shared.isTrackingEnabled ? "計測を一時停止" : "計測を再開"
            let toggleTrackingItem = NSMenuItem(
                title: trackingTitle,
                action: #selector(toggleTracking), //[M3-2]
                keyEquivalent: "t"
            )
            toggleTrackingItem.target = self
            menu.addItem(toggleTrackingItem)
            
            menu.addItem(NSMenuItem.separator())//セパレート線(区切り横線)
            
            // 4. 今日のデータリセット
            let resetItem = NSMenuItem(
                title: "今日の計測値をリセット",
                action: #selector(resetTime),//[M3-3]
                keyEquivalent: "r"
            )
            resetItem.target = self
            menu.addItem(resetItem)
            
            // 5. アプリ終了
            let quitItem = NSMenuItem(
                title: "アプリを終了",
                action: #selector(quitApp), //[M3-4]
                keyEquivalent: "q"
            )
            quitItem.target = self
            menu.addItem(quitItem)
            
            statusItem.menu = menu //l86変数 : アプリ終了をメニュー箱に入れる
        }//M1-1の閉じ
        
        //[M3-1]設定ウィンドウ(開閉)クラスを呼び出す
        @objc private func openSettings() {
            SettingsWindowController.shared.show()
        }
        //[M3-2]l112が起動された時→bool型を反転(toggle)させる
        @objc private func toggleTracking() {
            AppState.shared.isTrackingEnabled.toggle() //
        }
        //[M3-3]//AppState l106(日付リセット)
        @objc private func resetTime() {
            AppState.shared.resetToday() //AppState l106
        }
        //[M3-4]アプリを終了させる
        @objc private func quitApp() {
            NSApp.terminate(nil)
        }
    //26/7/15 157step
    
    //以下、コピペのみなのでカウントしない
    // 設定ウィンドウを管理するシングルトンクラス
    class SettingsWindowController: NSObject {
        static let shared = SettingsWindowController()
        private var window: NSWindow?
        
        private override init() {
            super.init()
        }
        
        func show() {
            // すでに表示中の場合は前面に持ってくる
            if let window = window {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            
            // 新しいウィンドウを生成
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 330, height: 380),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            newWindow.contentViewController = hostingController
            newWindow.title = "YouTube Screen Time 設定"
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .visible
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            
            // ↓ 追加：自動リサイズを止めて、ウィンドウサイズを明示的に固定する ↓
            hostingController.sizingOptions = []  // SwiftUIの内容に合わせた自動リサイズを無効化
            newWindow.setContentSize(NSSize(width: 330, height: 380))
            newWindow.minSize = NSSize(width: 330, height: 380)
            
            self.window = newWindow
            newWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            // ウィンドウ閉鎖時の監視設定（参照クリアのため）
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowWillClose),
                name: NSWindow.willCloseNotification,
                object: newWindow
            )
        }
        
        
        @objc private func windowWillClose(notification: Notification) {
            if let closedWindow = notification.object as? NSWindow, closedWindow == window {
                window = nil
            }
        }
    }//設定ウィンドウ(開閉)クラスの閉じ
}//クラスの閉じ
