import Foundation

enum ChatAPIError: LocalizedError {
    case roomNotFound
    case wrongPassword
    case server(String)
    case network

    var errorDescription: String? {
        switch self {
        case .roomNotFound: return "존재하지 않는 채팅방 코드입니다"
        case .wrongPassword: return "비밀번호가 일치하지 않습니다"
        case .server(let msg): return msg
        case .network: return "서버에 연결할 수 없습니다"
        }
    }
}

/// 채팅 서버 REST 호출 (URLSession async/await).
enum ChatAPI {
    private static let json = JSONDecoder()

    /// POST /rooms — 방 생성.
    static func createRoom(name: String, password: String) async throws -> RoomSummary {
        let body = ["name": name, "password": password]
        return try await post("/rooms", body: body)
    }

    /// GET /rooms/:code — 방 존재 확인(검색).
    static func findRoom(code: String) async throws -> RoomSummary {
        try await get("/rooms/\(encode(code))")
    }

    /// POST /rooms/:code/join — 비밀번호 검증 후 입장 토큰 발급.
    static func join(
        code: String, password: String, deviceId: String, nickname: String
    ) async throws -> JoinedRoom {
        let body = ["password": password, "deviceId": deviceId, "nickname": nickname]
        return try await post("/rooms/\(encode(code))/join", body: body)
    }

    /// GET /rooms/:code/messages — 최근 메시지 히스토리.
    static func messages(code: String, token: String, limit: Int = 50) async throws -> [ChatMessage] {
        try await get("/rooms/\(encode(code))/messages?limit=\(limit)&token=\(encode(token))")
    }

    // MARK: - 공통

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
    }

    // path 가 쿼리스트링을 포함할 수 있어 appendingPathComponent 대신 문자열 결합.
    private static func url(_ path: String) -> URL {
        URL(string: ChatConfig.baseURL.absoluteString + path)!
    }

    private static func get<T: Decodable>(_ path: String) async throws -> T {
        var req = URLRequest(url: url(path))
        req.httpMethod = "GET"
        return try await send(req)
    }

    private static func post<T: Decodable>(_ path: String, body: [String: String]) async throws -> T {
        var req = URLRequest(url: url(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(req)
    }

    private static func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw ChatAPIError.network
        }
        guard let http = response as? HTTPURLResponse else { throw ChatAPIError.network }
        switch http.statusCode {
        case 200..<300:
            return try json.decode(T.self, from: data)
        case 404:
            throw ChatAPIError.roomNotFound
        case 401:
            throw ChatAPIError.wrongPassword
        default:
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["message"]
            throw ChatAPIError.server(msg ?? "요청 실패 (\(http.statusCode))")
        }
    }
}
