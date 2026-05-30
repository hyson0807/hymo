import SwiftUI
import AppKit

@main
struct hymoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var updaterViewModel = UpdaterViewModel()

    var body: some Scene {
        // 메뉴바 팝업은 AppDelegate가 직접 만든 NSPanel로 제어한다.
        // 여기서는 Settings 화면(SettingsLink 대상)만 선언한다.
        Settings {
            SettingsView(updaterViewModel: updaterViewModel)
        }
    }
}

// MARK: - 메뉴바 아이콘 + 이동 가능한 떠 있는 패널 관리

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private var statusItem: NSStatusItem?
    private var panel: HymoPanel?

    private static let originXKey = "panelOriginX"
    private static let originYKey = "panelOriginY"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock 아이콘 없는 메뉴바 앱
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPanel()
        showPanel() // 시작 시 한 번 띄워준다
    }

    // MARK: 메뉴바 아이콘

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "note.text", accessibilityDescription: "Hymo")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(togglePanel)
            button.target = self
        }
        statusItem = item
    }

    // MARK: 패널 생성

    private func setupPanel() {
        let hosting = NSHostingView(rootView: PanelRootView())
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]

        let panel = HymoPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true   // 배경 아무 데나 잡고 드래그로 이동
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting
        panel.delegate = self
        self.panel = panel
    }

    // MARK: 토글 / 표시 / 숨김

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let panel else { return }
        positionPanel(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hidePanel() {
        guard let panel else { return }
        saveOrigin(panel.frame.origin)
        panel.orderOut(nil)
    }

    // MARK: 위치 (마지막 위치 기억, 없으면 메뉴바 아이콘 아래)

    private func positionPanel(_ panel: HymoPanel) {
        let defaults = UserDefaults.standard
        let size = panel.frame.size

        if defaults.object(forKey: Self.originXKey) != nil,
           defaults.object(forKey: Self.originYKey) != nil {
            let origin = NSPoint(
                x: defaults.double(forKey: Self.originXKey),
                y: defaults.double(forKey: Self.originYKey)
            )
            panel.setFrameOrigin(clampedOrigin(origin, size: size))
            return
        }

        // 첫 표시: 메뉴바 아이콘 바로 아래에 정렬
        if let button = statusItem?.button, let buttonWindow = button.window {
            let buttonFrame = buttonWindow.convertToScreen(
                button.convert(button.bounds, to: nil)
            )
            let x = buttonFrame.midX - size.width / 2
            let y = buttonFrame.minY - 6 - size.height
            panel.setFrameOrigin(clampedOrigin(NSPoint(x: x, y: y), size: size))
        } else {
            panel.center()
        }
    }

    private func clampedOrigin(_ origin: NSPoint, size: NSSize) -> NSPoint {
        guard let visible = NSScreen.main?.visibleFrame else { return origin }
        let x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        let y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        return NSPoint(x: x, y: y)
    }

    private func saveOrigin(_ origin: NSPoint) {
        UserDefaults.standard.set(Double(origin.x), forKey: Self.originXKey)
        UserDefaults.standard.set(Double(origin.y), forKey: Self.originYKey)
    }

    // MARK: NSWindowDelegate — 드래그로 옮긴 위치 저장

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }
        saveOrigin(panel.frame.origin)
    }
}

// MARK: - borderless 패널이 키 윈도우가 될 수 있도록 (메모 편집을 위해 필수)

final class HymoPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - 패널 배경 (둥근 모서리 + 머티리얼)

private struct PanelRootView: View {
    var body: some View {
        ContentView()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
    }
}
