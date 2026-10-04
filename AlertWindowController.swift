import AppKit
import SwiftUI

//コピペのみ(26/7/16)

//アラート時のアクション分類
enum AlertAction{
    case extend //拡張?
    case pause
    case close
}

// 画面中央にフローティング表示される警告ウィンドウのコントローラ
class AlertWindowController: NSWindowController {
   static let shared = AlertWindowController()
  
   private init() {
       // 境界線のないフルサイズコンテンツウィンドウを生成
       let window = NSWindow(
           contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
           styleMask: [.titled, .fullSizeContentView],
           backing: .buffered,
           defer: false
       )
       
       super.init(window: window)
       // アクションハンドラをバインドして SwiftUI ビューを作成
       let alertView = AlertView { [weak self] action in
           self?.handleAction(action)
       }
       
       let hostingController = NSHostingController(rootView: alertView)
       
      
       
       window.contentViewController = hostingController
       window.titleVisibility = .hidden
       window.titlebarAppearsTransparent = true
       window.isMovableByWindowBackground = true
       window.level = .statusBar // 常に他のアプリの前面に表示
       window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
   }
   
   required init?(coder: NSCoder) {
       fatalError("init(coder:) has not been implemented")
   }
   
   // ウィンドウを中央に表示し最前面にアクティベート
   func show() {
       DispatchQueue.main.async {
           guard let window = self.window else { return }
           window.center()
           NSApp.activate(ignoringOtherApps: true)
           window.makeKeyAndOrderFront(nil)
       }
   }
   
   // ウィンドウを閉じる
   func hide() {
       DispatchQueue.main.async {
           self.window?.orderOut(nil)
       }
   }
   
   private func handleAction(_ action: AlertAction) {
       switch action {
       case .extend:
           AppState.shared.extendLimitBy15Minutes()
           hide()
       case .pause:
           AppState.shared.isTrackingEnabled = false
           hide()
       case .close:
           hide()
       }
   }
}

// 警告ウィンドウ内のSwiftUIビュー
struct AlertView: View {
   var actionHandler: (AlertAction) -> Void
   @ObservedObject var appState = AppState.shared
   
   var body: some View {
       VStack(spacing: 20) {
           // ヘッダー情報
           HStack(spacing: 16) {
               ZStack {
                   Circle()
                       .fill(Color.red.opacity(0.15))
                       .frame(width: 48, height: 48)
                   Image(systemName: "timer")
                       .font(.title)
                       .foregroundColor(.red)
               }
               
               VStack(alignment: .leading, spacing: 4) {
                   Text("制限時間に達しました")
                       .font(.headline)
                       .foregroundColor(.primary)
                   Text("YouTubeの視聴時間が本日の制限時間に達しました。目の休息をとりましょう！")
                       .font(.subheadline)
                       .foregroundColor(.secondary)
                       .fixedSize(horizontal: false, vertical: true)
               }
           }
           .frame(maxWidth: .infinity, alignment: .leading)
           
           Divider()
           
           // 時間測定状況
           HStack(spacing: 40) {
               VStack(alignment: .leading, spacing: 4) {
                   Text("今日の合計視聴時間")
                       .font(.caption)
                       .foregroundColor(.secondary)
                   Text("\(Int(appState.todaySpentTime / 60)) 分")
                       .font(.title2)
                       .bold()
                       .foregroundColor(.primary)
               }
               Spacer()
               VStack(alignment: .trailing, spacing: 4) {
                   Text("現在の設定制限")
                       .font(.caption)
                       .foregroundColor(.secondary)
                   Text("\(appState.totalAllowedMinutes) 分")
                       .font(.title2)
                       .bold()
                       .foregroundColor(.secondary)
               }
           }
           .padding(.horizontal, 8)
           
           Spacer()
           
           // 操作ボタン
           HStack(spacing: 12) {
               Button(action: { actionHandler(.pause) }) {
                   Text("計測を一時停止")
                       .frame(maxWidth: .infinity)
                       .padding(.vertical, 8)
               }
               .buttonStyle(.bordered)
               .controlSize(.large)
               
               Button(action: { actionHandler(.extend) }) {
                   Text("15分延長する")
                       .bold()
                       .foregroundColor(.white)
                       .frame(maxWidth: .infinity)
                       .padding(.vertical, 8)
                       .background(
                           LinearGradient(
                               colors: [.red, .orange],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing
                           )
                       )
                       .cornerRadius(6)
               }
               .buttonStyle(.plain)
               .controlSize(.large)
           }
       }
       .padding(24)
       .frame(width: 420, height: 260)
       .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
   }
}

// macOS用の視覚効果（すりガラス）ビューのRepresentable
struct VisualEffectView: NSViewRepresentable {
   var material: NSVisualEffectView.Material
   var blendingMode: NSVisualEffectView.BlendingMode
   
   func makeNSView(context: Context) -> NSVisualEffectView {
       let view = NSVisualEffectView()
       view.material = material
       view.blendingMode = blendingMode
       view.state = .active
       return view
   }
   
   func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
       nsView.material = material
       nsView.blendingMode = blendingMode
   }
}
