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
            Section("일반") {
                Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
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

            Section("업데이트") {
                Toggle("자동으로 업데이트 확인", isOn: Binding(
                    get: { updaterViewModel.updaterController.updater.automaticallyChecksForUpdates },
                    set: { updaterViewModel.updaterController.updater.automaticallyChecksForUpdates = $0 }
                ))
                Button("업데이트 확인…") {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            }

            Section {
                Link(destination: URL(string: "https://hyson.kr/contact")!) {
                    HStack {
                        Text("문의사항")
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
