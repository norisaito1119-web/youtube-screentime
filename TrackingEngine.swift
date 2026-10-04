//フレームワーク(色々入っているキット)
import Foundation
import Combine
import AppKit //macOS専用キット
import UserNotifications //macOSのシステム通知を送る機能

//M4-1→M1-1→M1-2→M2-1

//[C2-1] IsTrackingEnabled(計測機能)がONの時の入口
class TrackingEngine:ObservableObject{
    static let shared = TrackingEngine() //、TrackingEngineクラスのインスタンス
    private var timer:Timer? //Foundation親クラス継承 ?:タイマー動いていない時用
    //↑Timer(クラス型):一定時間後に処理を実行したり、一定間隔で繰り返し処理を実行したりするため
    private let checkInterval:TimeInterval = 10.0
    //↑型エイリアス（typealias）:型のあだ名 実際はdouble型
    private var cancellables = Set<AnyCancellable>()
    //Combineで作った監視の「繋ぎ目」データを保存しないと、すぐにメモリから消えるから入れておく箱。
    
    private init() {
//        requestNotificationPermission() //[M4-1]  //通知許可確認(print) 
    }
    
    //[M1-1] 監視タイマー起動→[M1-2]
    //★一時停止中でもタイマー自体は常に動かす(日付チェック&日次投稿のため)。
    //  計測するかどうかはtick()の中でisTrackingEnabledを見て判断する
    //  (以前はONの時だけ起動していたので、停止状態で起動すると「再開」してもタイマーが動かなかった)
    func start() {
        startTimer()
    }
    //[M1-2]タイマーがnil？もう動いてるなら抜ける→timer起動[M2-1]
    private func startTimer(){
        //guard文:条件を満たしていない場合は、関数を抜け出す（return）
        guard timer == nil else {return}
        //scheduledTimer:タイムを作るメソッド。with~5.0s(l12) repeats:繰り返し
        //[weak]~以降が5sごとに何を実行するかの部分
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats:true){
            [weak self] _ in self?.tick() //★[weak self]???　弱参照(循環参照)closure ↔︎ TrackingEngineを防ぐ
            //self?.tickのselfはshared.tick ?→計測機能がOFFのとき=nilになる
        }
    }
    //[M1-3]タイマー起動中なら停止させ空にする
    private func stopTimer() {
        timer?.invalidate() //timerある? Tなら停止させる(invaildate)
        timer = nil
    }
    
    //[M2-1]日付が変わってないか&超過&警告送信チェック
    //
    private func tick() {
        //print("tick")
        let state = AppState.shared
        //AppState[M1-2] 日付チェック&リセット。日付が変わった時だけ前日の記録が返ってくる
        //if let:nilじゃなかったら中身をyesterdayに入れて{}を実行
        if let yesterday = state.checkDateChange() {
            PostToDiscord(message: dailyReportMessage(yesterday)) //[M5-4]
        }
        //★一時停止中(isTrackingEnabled=false)なら、ここで抜けて時間を加算しない
        //(日付チェックは↑で済ませたので、停止中でも日次投稿は届く)
        guard state.isTrackingEnabled else { return }
        if state.isLimitExceeded{          //AppState(l86) 超過制限か？
            if !state.isNotificationSent{  //AppState(l18) 警告文送ってるか？
                triggerLimitReachedAction() //[M5-1]警告ポップアップ
            }
            return
        }
        
        //最前面にあるアプリを取得
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return }
        
        let appName = frontmostApp.localizedName ?? ""
        //safariのAppleScript(Macアプリを自動操作するスクリプト言語)を取得
        var scriptText:String? = nil
        
    //print("isSafariEnabled:", state.isSafariEnabled)
        
        if appName == "Safari" && state.isSafariEnabled{ //AppState l70
            scriptText = """
                tell application "Safari"
                    if (count of windows) is not 0 then
                        return URL of front document
                    else
                        return ""
                    end if
                end tell
            """
        }   //ifの中身:ウィンドウの数が0でないなら、一番前のタブのURLを返す
            //""" 複数行文字列を作る記号。tell:AppleScript の構文
        
        
        print("前面:", frontmostApp.localizedName ?? "nil")
//        print("Bundle:", frontmostApp.bundleIdentifier ?? "nil")
//        print("PID:", frontmostApp.processIdentifier)
        
        //AppleScriptを実行してURLを取得
        guard let script = scriptText else {return} //scTextに何かあったら続行、ないなら終了
        let urlString = executeAppleScript(script)//[M3-1]
        //youtubeURLなら時間を加算
        if isYouTubeURL(urlString){ //[M3-2]
            DispatchQueue.main.async {
                state.todaySpentTime += self.checkInterval
                
                if state.isLimitExceeded && !state.isNotificationSent {
                    self.triggerLimitReachedAction() //[M5-1]
                }
            }
        }
    }//tickの閉じ
    
    //[M3-1]URLの文字列にして返す
    private func executeAppleScript(_ scriptText: String)->String{ //_:呼び出し元に型を書かなくて良い
        
        guard let script = NSAppleScript(source: scriptText) else { return "" }
  //      print("==========")
  //      print(scriptText)
        
            var errorInfo: NSDictionary?
            let result = script.executeAndReturnError(&errorInfo)
        print("errorInfo =", errorInfo ?? "エラーなし")

            if let error = errorInfo {
                // オートメーション権限がない場合のエラーコード: -1743
                if let errNum = error["NSAppleScriptErrorNumber"] as? Int, errNum == -1743 {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .automationPermissionDenied,
                            object: nil
                        )
                    }
                }
                return ""
            }
            return result.stringValue ?? ""
        }//M3-1の閉じ
     
    /*
    private func executeAppleScript(_ scriptText: String) -> String {

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", scriptText]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let output = String(
                data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""

            let error = String(
                data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""

            if !error.isEmpty {
                print("osascript error:", error)
            }

            return output.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch {
            print("Process error:", error)
            return ""
        }
    }
     */
    
    //[M3-2]取得したURLに youtube.com や youtu.be が含まれているか判定する
    private func isYouTubeURL(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased() //low~小文字変換↔︎uppercased
        return lowercased.contains("youtube.com") || lowercased.contains("youtu.be") // ||:or
    }
    
    //↓ Discord通知に切り替えのため削除 ↓ 26/8/1
//    //[M4-1]初回起動時にmacOSのシステム通知の通知許可してるか
//    private func requestNotificationPermission() {
//        UNUserNotificationCenter.current().requestAuthorization( //requestAuthorization:通知許可を聞き,自動でクロージャ(granted)を作る。(bool + error)
//            options: [.alert, .sound]
//        ) { granted, error in
//            if let error = error {
//                print("通知許可リクエストエラー: \(error.localizedDescription)")
//            }
//        }
//    }

    
    //[M5-1]制限時間を超えたときにシステム通知を送信&警告ポップアップ
    private func triggerLimitReachedAction(){
        PostToDiscord(message: LandomMesse()) //[M5-3 = M5-2]
        
        AppState.shared.isNotificationSent = true
    }
    
    //[M5-2]ディスコードメッセ配列から1つ選ぶ
    private func LandomMesse()->String{
        let messeList = [
        " ⚠️トラブル発生！！\nYouTubeの制限を超えてしまった。\n貴重な時間が奪われています。\n各レッスンポイント −5pt。",
        " ⚠️トラブル発生！！\nYouTubeの制限を超えてしまった。\n貴重な時間が奪われています。\nアピールポイント -0.1倍",
        " ⚠️トラブル発生！！\nYouTubeの制限を超えてしまった。\n貴重な時間が奪われています。\n次のレッスンポイント 獲得無効化"
        ]
        //randomElement(配列から1つ選ぶ)
        return messeList.randomElement() ?? messeList[0] //??:nilの時→[0]の値を代入
    }

    //[M5-4]日次レポートの文章を作る 例:📺 9/30 のYouTube視聴時間：45分（制限 45分）
    private func dailyReportMessage(_ day: (date: String, minutes: Int, limit: Int)) -> String {
        //"2026-09-30" → ["2026","09","30"] → "9/30" (Int()で頭の0を消す)
        let parts = day.date.split(separator: "-")
        var dateLabel = day.date
        if parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) {
            dateLabel = "\(m)/\(d)"
        }
        //制限を超えたかで一言変える
        let judge = day.minutes > day.limit ? "⚠️ \(day.minutes - day.limit)分オーバー" : "✅ 制限内"
        return "📺 \(dateLabel) のYouTube視聴時間：\(day.minutes)分（制限 \(day.limit)分）\(judge)"
    }

    //[M5-3] Discord Webhookにメッセージを送信
    private func PostToDiscord(message:String){
        //URLは秘密情報なのでSecrets.swift(GitHubに上げない)から読む
        guard let webhook = URL(string: Secrets.discordWebhookURL) else {return}
        
        var request = URLRequest(url: webhook)
        request.httpMethod = "POST"
        //荷札（ヘッダー）」に「送るデータの形式はJSONです」
        request.setValue("application/json", forHTTPHeaderField: "Content-type") //"Content-type" → ヘッダーの項目名
        //データの中身（本体）作成。
        let payload :[String: Any] = ["content":message]//[辞書型]キー:content 値:message　Any型=valiant的な
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }
            request.httpBody = jsonData
       
        //URLSession.shared:アプリ全体で共通して使える、通信用の基本インスタンス。
        /*{ _, response, error in ... }通信が終わったあとに呼ばれる**クロージャ（完了ハンドラ）3つの引数が渡されてきます。
         1:_(本来はdata）→サーバーから返ってきたデータ本体（今回は使わないので_で捨てる）
         2:response →HTTPステータスコードなど、通信結果の情報
         3:通信自体が失敗した場合のエラー（タイムアウトなど）
        URLSession~ は通信タスクを作るだけで、まだ通信は始まらない。渡した{ _, response, error in ... }は「通信が終わった後に呼んでね」と predefined処理（クロージャ:無名関数）で、responseとerrorはその時にOSから渡される引数。最後の.resume()で実際に通信がスタート。*/
        URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    print("Discord通知の送信に失敗: \(error.localizedDescription)")
                } else {
                    print("Discord通知を送信しました")
                }
            }.resume()
    }
    
    //↓ Discord通知に切り替えのため削除 ↓ 26/8/1 macに通知メソッド
//    private func triggerLimitReachedAction(){
//        let content = UNMutableNotificationContent() //UserNotificationsキットにあるクラス(引数なしinit)
//        content.title = "YouTube制限時間です"
//        content.body = "今日のYouTube試聴時間が¥(AppState.shared.totalAllowedMinutes)分を超えました。" //¥:文字列の中に変数や式の値を埋め込む（文字列補間）
//        content.sound = UNNotificationSound.default
        
        //何秒後に通知を出すかを決めるクラス(引数あり)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 0.1,
            repeats: false
        )
    
    //↓ Discord通知に切り替えのため削除 ↓ 26/8/1 macに通知メソッド
//        //この内容の通知を、このタイミングで出してくださいクラス
//        let request = UNNotificationRequest(
//            identifier: "YouTubeLimitExceeded",//ラベル名
//            content: content, //通知の中身
//            trigger: trigger
//        )
//        //通知追加、エラー時
//        UNUserNotificationCenter.current().add(request) { error in
//              if let error = error {
//                  print("通知の送信に失敗: \(error.localizedDescription)")
//              }
//          }
    //26/7/10 154step
    
}//クラスの閉じ

