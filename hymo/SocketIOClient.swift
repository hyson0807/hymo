import Foundation

/// URLSessionWebSocketTask 위에 구현한 최소 Socket.io v4(EIO4) 클라이언트.
///
/// 프레임 규약 (websocket transport, 프레임 1개 = Engine.IO 패킷 1개):
///   "0{...}"  Engine.IO OPEN  → 우리는 "40{auth}" 로 응답(접속)
///   "2"       Engine.IO PING  → "3"(PONG) 로 응답
///   "4" + p   Engine.IO MESSAGE, p 는 Socket.IO 패킷
///       "0..."  CONNECT ack   → 접속 완료
///       "1..."  DISCONNECT
///       "2" + json  EVENT     → ["이벤트명", payload]
///   emit: "42" + ["이벤트명", payload] JSON
final class SocketIOClient {
    private let url: URL
    private let token: String
    private let session: URLSession

    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onEvent: ((String, Data) -> Void)?

    private var task: URLSessionWebSocketTask?
    private(set) var connected = false
    private var shouldReconnect = false
    private var isClosed = true
    private var reconnectAttempts = 0

    init(token: String, url: URL = ChatConfig.socketURL) {
        self.token = token
        self.url = url
        self.session = URLSession(configuration: .default)
    }

    // MARK: - 공개 API

    func connect() {
        shouldReconnect = true
        open()
    }

    func disconnect() {
        shouldReconnect = false
        connected = false
        send("41")                       // Socket.IO DISCONNECT
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isClosed = true
    }

    func emit(event: String, payload: [String: Any]) {
        guard connected,
              let data = try? JSONSerialization.data(withJSONObject: [event, payload]),
              let json = String(data: data, encoding: .utf8) else { return }
        send("42" + json)
    }

    // MARK: - 연결

    private func open() {
        isClosed = false
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        receive()
    }

    private func send(_ text: String) {
        task?.send(.string(text)) { [weak self] error in
            if error != nil { self?.handleClose() }
        }
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self.handleFrame(text)
                } else if case .data(let d) = message,
                          let text = String(data: d, encoding: .utf8) {
                    self.handleFrame(text)
                }
                self.receive()
            case .failure:
                self.handleClose()
            }
        }
    }

    // MARK: - 프레임 파싱

    private func handleFrame(_ text: String) {
        guard let first = text.first else { return }
        switch first {
        case "0": sendConnect()                       // Engine.IO OPEN
        case "2": send("3")                           // PING → PONG
        case "4": handleSocketIO(String(text.dropFirst()))
        case "1": handleClose()                       // Engine.IO CLOSE
        default: break
        }
    }

    private func sendConnect() {
        if let data = try? JSONSerialization.data(withJSONObject: ["token": token]),
           let json = String(data: data, encoding: .utf8) {
            send("40" + json)
        } else {
            send("40")
        }
    }

    private func handleSocketIO(_ packet: String) {
        guard let type = packet.first else { return }
        let rest = String(packet.dropFirst())
        switch type {
        case "0":                                     // CONNECT ack
            connected = true
            reconnectAttempts = 0
            DispatchQueue.main.async { self.onConnected?() }
        case "1":                                     // DISCONNECT
            handleClose()
        case "2":                                     // EVENT
            parseEvent(rest)
        default:
            break
        }
    }

    private func parseEvent(_ rest: String) {
        // rest 가 ack id로 시작할 수 있으니 첫 '[' 부터 잘라 JSON 배열로 파싱.
        guard let bracket = rest.firstIndex(of: "["),
              let data = String(rest[bracket...]).data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let name = arr.first as? String else { return }
        let payload = arr.count > 1 ? arr[1] : [String: Any]()
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        DispatchQueue.main.async { self.onEvent?(name, payloadData) }
    }

    private func handleClose() {
        guard !isClosed else { return }
        isClosed = true
        let wasConnected = connected
        connected = false
        task = nil
        if wasConnected { DispatchQueue.main.async { self.onDisconnected?() } }
        guard shouldReconnect else { return }
        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts) * 1.5, 10)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.shouldReconnect else { return }
            self.open()
        }
    }
}
