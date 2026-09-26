import SwiftUI

/// Pairing until the app holds a token, then three tabs.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.credentials == nil {
                PairingView()
            } else {
                TabView {
                    MessagesView()
                        .tabItem { Label(Copy.messagesTab, systemImage: "tray") }
                    TerminalView()
                        .tabItem { Label(Copy.terminalTab, systemImage: "text.bubble") }
                    SettingsView()
                        .tabItem { Label(Copy.settingsTab, systemImage: "gear") }
                }
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await model.becameActive() }
            }
        }
    }
}
