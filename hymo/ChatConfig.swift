import Foundation

/// 채팅 서버 엔드포인트 설정.
enum ChatConfig {
    /// REST 베이스 URL (AWS Lightsail 배포).
    static let baseURL = URL(string: "https://api.hymo.hyson.kr")!

    /// Socket.io v4 websocket transport URL.
    static let socketURL = URL(
        string: "wss://api.hymo.hyson.kr/socket.io/?EIO=4&transport=websocket"
    )!
}
