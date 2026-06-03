import Foundation
import Observation

/// 채팅 화면 상태 + REST/소켓 오케스트레이션.
/// 단일 방 모델: 입장한 방 하나만 유지(UserDefaults 영속), 나가면 비움.
@Observable
final class ChatStore {
    private static let roomKey = "chatCurrentRoom"

    /// 현재 입장 중인 방. nil 이면 진입 화면(생성/입장) 표시.
    var room: JoinedRoom? {
        didSet { persistRoom() }
    }
    var messages: [ChatMessage] = []
    var isConnected = false
    var errorMessage: String?
    /// 생성/입장 진행 중 표시.
    var isBusy = false
    /// 위로 더 불러올 과거 메시지가 있는지(마지막 페이지가 가득 찼는지로 추정).
    var hasMoreHistory = false

    private var socket: SocketIOClient?
    private var isLoadingOlder = false
    private let pageSize = 50
    private let identity = ChatIdentity.shared

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.roomKey),
           let saved = try? JSONDecoder().decode(JoinedRoom.self, from: data) {
            room = saved
        }
    }

    // MARK: - 방 생성/입장/나가기

    /// 방 생성 후 곧바로 입장.
    @MainActor
    func createRoom(name: String, password: String) async {
        await run {
            let summary = try await ChatAPI.createRoom(name: name, password: password)
            let joined = try await ChatAPI.join(
                code: summary.code,
                password: password,
                deviceId: self.identity.deviceId,
                nickname: self.identity.nickname
            )
            self.enter(joined)
        }
    }

    @MainActor
    func joinRoom(code: String, password: String) async {
        await run {
            let joined = try await ChatAPI.join(
                code: code.uppercased(),
                password: password,
                deviceId: self.identity.deviceId,
                nickname: self.identity.nickname
            )
            self.enter(joined)
        }
    }

    @MainActor
    func leaveRoom() {
        disconnect()
        messages = []
        hasMoreHistory = false
        room = nil
        errorMessage = nil
    }

    // MARK: - 연결 수명주기

    /// 채팅 탭 진입 시 호출 — 방이 있으면 히스토리 로드 후 소켓 연결.
    @MainActor
    func connectIfNeeded() {
        guard let room, socket == nil else { return }
        setupRoom(room)
    }

    @MainActor
    func disconnect() {
        socket?.disconnect()
        socket = nil
        isConnected = false
    }

    // MARK: - 메시지 전송

    @MainActor
    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, socket?.connected == true else { return }
        socket?.emit(event: "chat:send-message", payload: ["content": trimmed])
    }

    // MARK: - 내부

    @MainActor
    private func enter(_ joined: JoinedRoom) {
        room = joined
        setupRoom(joined)
    }

    /// 히스토리 로드 + 소켓 연결 (입장/탭 진입 공용).
    @MainActor
    private func setupRoom(_ joined: JoinedRoom) {
        messages = []
        hasMoreHistory = false
        Task { await loadHistory(for: joined) }
        startSocket(for: joined)
    }

    @MainActor
    private func loadHistory(for room: JoinedRoom) async {
        if let history = try? await ChatAPI.messages(code: room.code, token: room.token, limit: pageSize) {
            merge(history)
            hasMoreHistory = history.count == pageSize
        }
    }

    /// 위로 스크롤 시 가장 오래된 메시지보다 과거의 한 페이지를 불러와 앞에 붙인다.
    @MainActor
    func loadOlder() async {
        guard let room, hasMoreHistory, !isLoadingOlder,
              let cursor = messages.first?.id else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        if let older = try? await ChatAPI.messages(
            code: room.code, token: room.token, limit: pageSize, cursor: cursor
        ) {
            merge(older)
            hasMoreHistory = older.count == pageSize
        }
    }

    @MainActor
    private func startSocket(for room: JoinedRoom) {
        let client = SocketIOClient(token: room.token)
        client.onConnected = { [weak self] in self?.isConnected = true }
        client.onDisconnected = { [weak self] in self?.isConnected = false }
        client.onEvent = { [weak self] name, data in
            guard name == "chat:new-message",
                  let message = try? JSONDecoder().decode(ChatMessage.self, from: data) else { return }
            self?.append(message)
        }
        socket = client
        client.connect()
    }

    @MainActor
    private func append(_ message: ChatMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
    }

    @MainActor
    private func merge(_ history: [ChatMessage]) {
        let existing = Set(messages.map(\.id))
        messages.append(contentsOf: history.filter { !existing.contains($0.id) })
        messages.sort { $0.createdAt < $1.createdAt }
    }

    @MainActor
    private func run(_ work: @escaping () async throws -> Void) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await work()
        } catch let e as ChatAPIError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = "오류가 발생했습니다"
        }
    }

    private func persistRoom() {
        if let room, let data = try? JSONEncoder().encode(room) {
            UserDefaults.standard.set(data, forKey: Self.roomKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.roomKey)
        }
    }
}
