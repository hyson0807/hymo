import Foundation
import Observation

/// 로그인 없는 익명 신원 — 디바이스 UUID + 전역 닉네임. UserDefaults에 영속.
@Observable
final class ChatIdentity {
    static let shared = ChatIdentity()

    private static let deviceIdKey = "chatDeviceId"
    private static let nicknameKey = "chatNickname"

    /// 최초 1회 생성 후 고정.
    let deviceId: String

    /// 모든 방에서 쓰는 표시 이름. Settings에서 수정.
    var nickname: String {
        didSet { UserDefaults.standard.set(nickname, forKey: Self.nicknameKey) }
    }

    var hasNickname: Bool { !nickname.trimmingCharacters(in: .whitespaces).isEmpty }

    private init() {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: Self.deviceIdKey) {
            deviceId = existing
        } else {
            let new = UUID().uuidString
            defaults.set(new, forKey: Self.deviceIdKey)
            deviceId = new
        }
        nickname = defaults.string(forKey: Self.nicknameKey) ?? ""
    }
}
