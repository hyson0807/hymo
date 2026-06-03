import Foundation
import AppKit
import UserNotifications

/// 채팅 로컬 알림 (앱이 메뉴바에 살아있고 채팅을 보고 있지 않을 때).
enum ChatNotifier {
    /// 최초 1회 권한 요청. 이미 결정돼 있으면 시스템이 알아서 무시.
    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 앱 알림 토글을 켤 때 호출. OS 권한이 미정이면 프롬프트, 이미 거부됐으면
    /// (앱이 직접 켤 수 없으므로) 시스템 설정 알림 페이지로 안내한다.
    static func ensureSystemPermission() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
            case .denied:
                DispatchQueue.main.async { openSystemNotificationSettings() }
            default:
                break
            }
        }
    }

    /// 시스템 설정 > 알림 페이지 열기.
    static func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 새 메시지 알림 게시. 같은 방은 threadIdentifier로 묶인다.
    static func post(roomId: String, roomName: String, sender: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = roomName
        content.body = "\(sender): \(body)"
        content.sound = .default
        content.threadIdentifier = roomId
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
