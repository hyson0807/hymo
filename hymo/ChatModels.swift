import Foundation

/// 서버 message 레코드 (chat:new-message / 히스토리 응답과 동일 형태).
struct ChatMessage: Codable, Identifiable, Equatable {
    let id: String
    let roomId: String
    let senderId: String
    let senderName: String
    let content: String
    let createdAt: String

    /// ISO8601 문자열 → 표시용 시:분.
    var timeText: String {
        guard let date = ChatMessage.isoFormatter.date(from: createdAt) else { return "" }
        return ChatMessage.timeFormatter.string(from: date)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "a h:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()
}

/// 입장 성공 시 서버가 돌려주는 방 + 토큰. UserDefaults에 영속.
struct JoinedRoom: Codable, Equatable {
    let token: String
    let roomId: String
    let code: String
    let name: String
}

/// POST /rooms / GET /rooms/:code 응답.
struct RoomSummary: Codable, Equatable {
    let code: String
    let name: String
}
