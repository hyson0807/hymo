import ServiceManagement
import Sparkle
import SwiftUI
import UserNotifications

// MARK: - 설정 창을 다른 앱 위로 띄우는 구성기

/// accessory(메뉴바) 앱이라 설정 창이 다른 앱 뒤로 숨는 경우가 있어,
/// 창을 잡아 floating 레벨로 올리고 맨 앞으로 가져온다.
private struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = _ConfiguratorView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class _ConfiguratorView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.level = .floating
            window.collectionBehavior.insert(.canJoinAllSpaces)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

struct SettingsView: View {
    var updaterViewModel: UpdaterViewModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Bindable private var chatIdentity = ChatIdentity.shared
    /// OS 알림 권한 허용 여부. 거부 상태면 앱 토글이 ON으로 보이지 않게 한다.
    @State private var systemAuthorized = false
    /// 최초 권한 읽기 완료 여부 — 최초 읽기를 "권한 켜짐 전이"로 오인하지 않기 위함.
    @State private var didInitialAuthRead = false

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

            Section {
                TextField("닉네임", text: $chatIdentity.nickname, prompt: Text("채팅에서 보일 이름"))
                // 표시 상태 = 앱 설정 ON && OS 권한 허용. OS가 꺼져 있으면 ON으로 보이지 않는다.
                Toggle("새 메시지 알림", isOn: Binding(
                    get: { chatIdentity.notificationsEnabled && systemAuthorized },
                    set: { on in
                        chatIdentity.notificationsEnabled = on
                        // 켜려는데 OS 권한이 없으면 요청/시스템 설정 안내(앱이 직접 못 켬).
                        if on && !systemAuthorized { ChatNotifier.ensureSystemPermission() }
                    }
                ))
            } header: {
                Text("Chat")
            } footer: {
                Text("시스템 설정에서 이 앱의 알림이 꺼져 있으면 받을 수 없어요. 토글을 켜면 시스템 설정으로 안내합니다.")
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
        .background(SettingsWindowConfigurator())
        .onAppear { refreshAuthStatus() }
        // 시스템 설정에 다녀와 앱으로 돌아오면 권한 상태 다시 반영.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAuthStatus()
        }
    }

    /// 현재 OS 알림 권한 상태를 읽어 systemAuthorized 갱신.
    /// 시스템 설정에서 막 권한을 켠 경우(거부/미정 → 허용)엔 앱 토글도 자동 ON.
    private func refreshAuthStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let ok = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            DispatchQueue.main.async {
                if didInitialAuthRead, ok, !systemAuthorized {
                    chatIdentity.notificationsEnabled = true
                }
                systemAuthorized = ok
                didInitialAuthRead = true
            }
        }
    }
}
