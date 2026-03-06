import SwiftUI

@main
struct hymoApp: App {
    @State private var updaterViewModel = UpdaterViewModel()

    var body: some Scene {
        MenuBarExtra("Hymo", image: "MenuBarIcon") {
            ContentView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(updaterViewModel: updaterViewModel)
        }
    }
}
