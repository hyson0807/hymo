import ServiceManagement
import Sparkle
import SwiftUI

struct SettingsView: View {
    var updaterViewModel: UpdaterViewModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Text("Automatically open Hymo when you log in.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Text("Updates")
                Spacer()
                Button("Check for Updates…") {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            }

            Toggle("Automatically check for updates", isOn: Binding(
                get: { updaterViewModel.updaterController.updater.automaticallyChecksForUpdates },
                set: { updaterViewModel.updaterController.updater.automaticallyChecksForUpdates = $0 }
            ))
        }
        .formStyle(.grouped)
        .frame(width: 300)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
