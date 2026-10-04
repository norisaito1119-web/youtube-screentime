import Foundation //Timer（タイマー）や String（文字列処理）などの基本機能
import Combine //★ObservableObject★「このデータが流れたら、自動的にここを更新する」というパイプラインを引く
//appleが提供している「データの変化やイベントを、水道のホースのように繋いで自動処理する」



//??
extension Notification.Name {
    static let automationPermissionDenied = Notification.Name("yt_automation_permission_denied")
}

//[C1-1] ObservableObject:データの変更がビューに反映されるプロトコル　l33~57の箇所。→どこからでも同じデータにアクセス統一。シングルトン(アプリで1つ)
class AppState: ObservableObject{
    
    //static:クラスのobj生成（インスタンス生成）に関係なく作られる変数)
    static let shared = AppState() //let(定数)
    private let defaults = UserDefaults.standard //UserDefaults:macに保存(≒キーバリューDB) standard⇨共有の箱(≒dict)
    
    //UserDefaults用 キー箱=キー名 (タイポ（打ち間違い）を防ぐ)
    //毎回 "yt_daily_limit_minutes" と手書きするとタイポする可能性があるので、定数 keyDailyLimitに入れる
    private let keyDailyLimit = "yt_daily_limit_minutes" //1日の基本制限時間（分）
    private let keyTodaySpentTime = "yt_today_spent_seconds" //今日のYouTube視聴時間（秒）
    private let keyIsTrackingEnabled = "yt_is_tracking_enabled" //計測機能のON/OFF（有効/無効）
    private let keyLastActiveDate = "yt_last_active_date" //最後にアプリが動いた日付
    private let keyIsNotificationSent = "yt_is_notification_sent" //超過警告を送ったかフラグ
    private let keySafariEnabled = "yt_safari_enabled" //Safariを監視するか（ON/OFF）
    //private let keyChromeEnabled = "yt_chrome_enabled" G chrome
    private let keyExtendedMinutes = "yt_extended_minutes"//今日の「延長時間クリック」の合計（分）
    private let keyDailyHistory = "yt_daily_history" //日ごとの視聴時間の履歴 ["2026-10-03": 25, ...]（分）

    // 変更されたら画面に自動反映(@Published=公表(ラッパー関数))し、同時にUserDefaultsに保存（didSet）
    //値を変数宣言
    //didset:dailyLimitの中身が書き換わった直後に { } の中の処理を自動的に実行する
    @Published var dailyLimit:Int {
        didSet { defaults.set(dailyLimit, forKey:keyDailyLimit) }
    }
    //TimeInterval : double型と同じ
    @Published var todaySpentTime: TimeInterval {
           didSet { defaults.set(todaySpentTime, forKey: keyTodaySpentTime) }
    }
    @Published var isTrackingEnabled: Bool {
           didSet { defaults.set(isTrackingEnabled, forKey: keyIsTrackingEnabled) }
    }
    @Published var lastActiveDate: String {
        didSet { defaults.set(lastActiveDate, forKey: keyLastActiveDate) }
    }
    @Published var isNotificationSent: Bool {
        didSet { defaults.set(isNotificationSent, forKey: keyIsNotificationSent) }
    }
    @Published var isSafariEnabled: Bool {
           didSet { defaults.set(isSafariEnabled, forKey: keySafariEnabled) }
    }
    /*@Published var isChromeEnabled: Bool {
           didSet { defaults.set(isChromeEnabled, forKey: keyChromeEnabled) }
    }*/
    @Published var extendedMinutes: Int {
           didSet { defaults.set(extendedMinutes, forKey: keyExtendedMinutes) }
    }
    
    //初期化(privateにすることで外部からのインスタンス生成を制限)
    private init(){
        //formatDateは別メソッド(r88 M?-?)
        let todayStr = AppState.formatDate(Date())//yyyy-mm-dd
        
        //defaults.set(値, forKey:) →データを上書き保存する(ユーザーが設定を変えたとき)
        //defaults.register(defaults:) →まだ保存データがないときだけ初期値を決める
           defaults.register(defaults: [
               keyDailyLimit: 30, // 制限時間はデフォルトで30分
               keyTodaySpentTime: 0.0,
               keyIsTrackingEnabled: true,
               keySafariEnabled: true,
               keyLastActiveDate: todayStr,
               keyIsNotificationSent: false,
               keyExtendedMinutes: 0
           ])
        
        //保存されている値(defaults)を呼び出す
        self.dailyLimit = defaults.integer(forKey: keyDailyLimit)
        self.todaySpentTime = defaults.double(forKey: keyTodaySpentTime)
        self.isTrackingEnabled = defaults.bool(forKey: keyIsTrackingEnabled)
        self.isSafariEnabled = defaults.bool(forKey: keySafariEnabled)
        self.lastActiveDate = defaults.string(forKey: keyLastActiveDate) ?? todayStr
        //??:nil合体演算子 左側をチェックして、もし空っぽ（nil）なら、代わりにtodayStrを代入
        self.isNotificationSent = defaults.bool(forKey: keyIsNotificationSent)
        self.extendedMinutes = defaults.integer(forKey: keyExtendedMinutes)

        //★init内ではdidSetが動かないので、最後に動いた日を明示的に保存する
        //(registerの初期値は保存されないため、これがないとアプリが寝てる間に日付が変わった時、
        // 起動時に「今日」扱いになって前日分がリセットも投稿もされない)
        defaults.set(self.lastActiveDate, forKey: keyLastActiveDate)
    }//初期化の閉じ
    
    //合計許容時間(制限時間+延長時間)
    var totalAllowedMinutes:Int {
        return dailyLimit + extendedMinutes
    }
    
    //制限時間判定
    var isLimitExceeded:Bool{
        let spendMInutes = Int(todaySpentTime / 60) //型変換(double→Int)←秒数(150s)を分(2.5m)変換にした後、小数点切り捨て
        return spendMInutes >= totalAllowedMinutes //制限超えてたらTになる
    }
    
    //今日の進捗率(0.0~1.0)　つべ使用時間/許容時間
    var progress: Double{
        let totalSeconds = Double(totalAllowedMinutes * 60 )
        guard totalSeconds > 0 else { return 0 }
        return todaySpentTime / totalSeconds
    }
    
    //[M1-1]日付リセットメソッド
    func resetToday() {
            todaySpentTime = 0.0
            isNotificationSent = false
            extendedMinutes = 0
        }
    
    //[M1-2]日付チェック、日付違うならリセット
    //戻り値:日付が変わった時だけ「前日の記録」を返す(Discordの日次投稿用)。同じ日ならnil
    //(date:,minutes:,limit:)?:名前付きタプル + ?(nilもOK) ≒ Pythonで (a,b,c) か None を返すのと同じ
    func checkDateChange() -> (date: String, minutes: Int, limit: Int)? {
        let todayStr = AppState.formatDate( Date())
        if lastActiveDate != todayStr{
            //★resetToday()で0に戻る前に、前日の値を退避しておく(順番が大事)
            let yesterday = (
                date: lastActiveDate,
                minutes: Int(todaySpentTime / 60), //秒→分
                limit: totalAllowedMinutes         //制限+延長
            )
            saveHistory(date: yesterday.date, minutes: yesterday.minutes) //[M1-3] リセット前に履歴へ保存
            resetToday()//[M1-1]
            lastActiveDate = todayStr
            return yesterday
        }
        return nil //日付が同じ→投稿しない
    }

    //[M1-3]履歴に1日分を保存
    //UserDefaultsは辞書もそのまま保存できる。[String: Int] = Pythonの {"2026-10-03": 25} と同じ
    private func saveHistory(date: String, minutes: Int) {
        var history = dailyHistory
        history[date] = minutes
        defaults.set(history, forKey: keyDailyHistory)
    }

    //保存されている履歴(なければ空の辞書)
    //as? [String: Int]:取り出した値を辞書型として扱えるか試す。ダメならnil → ?? で空の辞書
    var dailyHistory: [String: Int] {
        return defaults.dictionary(forKey: keyDailyHistory) as? [String: Int] ?? [:]
    }

    //[M1-4]直近N日(今日を除く)の平均視聴時間(分)と、記録があった日数
    //アプリが動いていなかった日は記録がないので、平均には入れない
    func recentAverage(days: Int) -> (average: Int, count: Int)? {
        let history = dailyHistory
        var total = 0
        var count = 0
        for i in 1...days { //1日前〜N日前
            //Calendar.date(byAdding:):日付の足し算。value: -i で i日前
            guard let day = Calendar.current.date(byAdding: .day, value: -i, to: Date()) else { continue }
            if let minutes = history[AppState.formatDate(day)] {
                total += minutes
                count += 1
            }
        }
        guard count > 0 else { return nil } //記録が1日もない→nil
        return (average: total / count, count: count)
    }
    
    //制限時間15分延長用
    func extendLimitBy15Minutes(){
        extendedMinutes += 15
        isNotificationSent = false //超過警告boolのリセット
    }
    
    //[M2-1]今日日付を指定の型にして文字列で返す
    private static func formatDate(_ date: Date) -> String {
          let formatter = DateFormatter()//apple標準装備クラスを呼び出す
          formatter.dateFormat = "yyyy-MM-dd"
          return formatter.string(from: date)
      }
}//クラスの閉じ
    // 26/7/8 130step





//1. アプリの「記憶」を保存する（UserDefaults）
//アプリが閉じられても、設定した制限時間や、今日それまでに何分YouTubeを見たかの記録が消えてしまっては困りますよね。 このコードの中では、macOSが提供するデータ保存機能（UserDefaults）を使って、以下の情報をMacの中に保存・記憶しています。
//
//制限時間（例：「30分」）
//今日YouTubeを見た時間（例：「12分30秒」）
//監視したいブラウザはどれか（例：「SafariとChromeは監視するが、Braveはしない」）
//日付（例：「2026-07-05」に計測したという記録）
//これがあるおかげで、アプリを再起動しても「今日のYouTube時間は15分から再開」したり、「設定画面の制限時間は30分のまま」維持したりできます。
//
//2. データの変更を画面（UI）に「通知」する（@Published）
//時間が「10分」から「11分」に増えたとき、メニューバーの表示や設定画面のゲージも連動して動いてほしいですよね。 SwiftUIという画面を作るシステムでは、変数に @Published（パブリッシュ＝公表する）というマークをつけておくと、「値が変わったよ！画面を書き換えて！」 と画面側に自動で通知が送られ、画面がリアルタイムに更新されます。
//
//3. 日付が変わったら「自動リセット」する
//「前日にYouTubeを1時間見たから、翌日起動したときに最初から制限時間オーバーになっている」という状態を防ぐ必要があります。 このコードの中の checkDateChange() は、日付をチェックして**「日付が変わっていたら、今日の視聴時間を0分にリセットする」**という大事な役割を持っています。
//
//
//
