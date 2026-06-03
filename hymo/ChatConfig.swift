import Foundation

/// 채팅 서버 엔드포인트 설정.
enum ChatConfig {
    /// REST 베이스 URL (Railway 배포).
    static let baseURL = URL(string: "https://hymo-server-production.up.railway.app")!

    /// Socket.io v4 websocket transport URL.
    static let socketURL = URL(
        string: "wss://hymo-server-production.up.railway.app/socket.io/?EIO=4&transport=websocket"
    )!
}
