import ServiceManagement
import Sparkle
import SwiftUI

struct SettingsView: View {
    var updaterViewModel: UpdaterViewModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section("General") {
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
            }

            Section("Updates") {
                Toggle("Automatically Check for Updates", isOn: Binding(
                    get: { updaterViewModel.updaterController.updater.automaticallyChecksForUpdates },
                    set: { updaterViewModel.updaterController.updater.automaticallyChecksForUpdates = $0 }
                ))
                Button("Check for Updates…") {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            }

            Section {
                Link(destination: URL(string: "https://hyson.kr/contact")!) {
                    HStack {
                        Text("Contact")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                HStack {
                    Spacer()
                    Text("Hymo \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 320)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
