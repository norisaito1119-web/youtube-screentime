import SwiftUI
import UserNotifications

//struct データと機能もまとめたもの(viewではこっち)
//変数コピー可(a=bを別々の箱にできる:classはaとbで1つのインスタンスをみる)

struct SettingsView:View { //MenubarController l178で起動
    @ObservedObject var appState = AppState.shared
    //@State:Viewの中で値が変わったものを保存する
    @State private var showAutomationHelp = false
    @State private var hasAutomationError = false
    
    // 制限時間の選択肢（分）
    let limitOptions = [1, 30, 60, 90, 120, 180, 240, 300]
    
    //VS:縦,HS:横,ZS:Viewを奥から手前に重ねて表示する
    //spacing:View同士の隙間,spacer:空いているスペースで隙間を作り並べる
    //[font] headline:h3 .rounded:丸みフォント .caption:小さめ
    //[color] .primary:標準文字色 .secondary:補助的な色（少し薄い色） .opacity(0.15):薄さ
    //[padding] .horizontal:左右 .vertical:上下
    //.cornerRadius(4):角の丸み
    
    //[Circle] .stroke:外側の線(輪郭) LinearGradient():線の色
    //StrokeStyle lineCap:線の端を丸み
    //rotationEffect:回転効果
    // animation .spring()
    //[background] VisualEffectView:ぼかし blendingMode: .withinWindow:同じウィンドウ
    //[Button] .buttonStyle:枠線 .controlSize:大きさ
    
//    alignment　左端揃え
    
    var body: some View {
        VStack(spacing:0){ //子グループを縦並べ&隙間を0にする
            
            //[V1-1]上部：進捗状況カード (円形ゲージ)
            VStack{
                HStack{
                    //1,ヘッダーテキスト
                    Text("YouTube 使用状況")
                        .font(.system(.headline,design:.rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    if !appState.isTrackingEnabled{ //F→(計測停止)
                        Text("計測一時停止中")
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
                .padding(.bottom, 12)
                
                
                HStack(spacing:24){
                    //2,ドーナツ型進捗インジケータ
                    ZStack{
                        //外側の円
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                            .frame(width: 120, height: 120)
                        //進捗の円
                        Circle()
                        //0からto(今日の進捗率)まで min:1.0まで　CG~:画面の座標や大きさを表す小数型
                            .trim(from: 0.0, to: CGFloat(min(appState.progress, 1.0)))
                            .stroke(LinearGradient(
                                colors: appState.isLimitExceeded ? [Color.red, Color.pink] : [Color.red, Color.orange],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(Angle(degrees: -90))
                        //valueの中身が変わったらアニメーションしてね
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appState.todaySpentTime)
                        //円の中にあるテキスト
                        VStack(spacing: 2) {
                            Text("\(Int(appState.todaySpentTime / 60))分")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("制限: \(appState.totalAllowedMinutes)分")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            if appState.extendedMinutes > 0 {
                                Text("(延長+\(appState.extendedMinutes)分)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                                    .bold()
                            }
                        }//ドーナツ型進捗のZS閉じ
                    }//ドーナツ型進捗のHS閉じ
                    // 3，ステータスと簡易アクション
                    VStack(alignment: .leading, spacing: 8) {
                        Text("現在の状態")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if appState.isLimitExceeded {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("制限超過中")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .bold()
                            }
                        } else if appState.isTrackingEnabled {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("監視中...")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.secondary)
                                    .frame(width: 8, height: 8)
                                Text("停止中")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        //4,残り時間表示
                        let diff = appState.totalAllowedMinutes - Int(appState.todaySpentTime/60)
                        if diff > 0{
                            Text("制限まであと \(diff) 分")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }else{
                            Text(" \(abs(diff)) 分超過") //absolute（絶対値）
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        //Button({処理}) {見た目}
                        Button(action:{appState.resetToday()})//AppState l105
                        {
                            Text("計測リセット")
                                .font(.caption)
                        }
                        //テキストに反映するとえらーになるため、}外でボタンデザインをかく
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }//l96 VS閉じ
                    Spacer()
                }//l55HS閉じ
                .padding(16)
                .background(VisualEffectView(material: .contentBackground, blendingMode: .withinWindow))
                .cornerRadius(12)
            }//[V1-1]の閉じ
            .padding(15)
            
            //[V1-2]下部：スクロール可能な設定セクション
            ScrollView{
                VStack(spacing:15){
                    
                    // 1,制限時間設定カード
                    VStack(alignment: .leading, spacing: 8) {
                        Text("制限時間設定")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        HStack{
                            Text("1日のYouTube視聴上限")
                                .font(.subheadline)
                            Spacer()
                            //Picker:複数の候補から1つを選ぶView ([ラベル],[現在の値]{})
                            //forEach(,id:¥.self[配列の要素そのものをIDとして使う].tag[実際に入れられる値(.dailyLimit)])
                            Picker("", selection: $appState.dailyLimit) {
                                ForEach(limitOptions, id: \.self) {
                                    minutes in
                                    Text("\(minutes) 分").tag(minutes)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 110)
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // 2,監視対象ブラウザカード
                    VStack(alignment: .leading, spacing: 5) {
                        Text("監視対象ブラウザ")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        Toggle("Safari", isOn: $appState.isSafariEnabled)
                            .padding(.vertical, 3)
                        Divider()
                            .toggleStyle(.checkbox)
                            .padding(.horizontal, 10)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                }//l164VSの閉じ
            }//ScrollViewの閉じ
        }//大元VSの閉じ　l31
    }//body(view)の閉じ
}

/*
┌──────────────────────────────┐
│ YouTube 使用状況   計測一時停止中│
│　　　　　　　　　　　　　　　　　　 │
│   ◜██████◝                   │
│  █        █    （ステータスと 　│
│ █   35分   █     簡易アクション │
│ █ 制限:60分 █                 │
│  █ (+10分) █                 │
│   ◟██████◞                   │
│                              │
│  制限時間設定 (小さくグレー)      │
┌──────────────────────────────┐
│ 1日のYouTube視聴上限     ▼60分  │
└──────────────────────────────┘
 
 ──────────────────────────────────
 
 
*/
