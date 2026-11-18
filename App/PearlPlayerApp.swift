import PearlKit
import SwiftUI

@main
struct PearlPlayerApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    model.handleIncoming(url: url)
                }
                .onAppear {
                    model.checkClipboardForStreamLink()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.checkClipboardForStreamLink()
            }
        }
    }
}
