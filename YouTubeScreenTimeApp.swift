import SwiftUI

struct YouTubeScreenTimeApp: App {

    init() {
        TrackingEngine.shared.start()
        MenubarController.shared.setup()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
