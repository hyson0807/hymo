import SwiftUI

// MARK: - ChatTabView (탭 루트)

struct ChatTabView: View {
    @Bindable var store: ChatStore
    @Bindable private var identity = ChatIdentity.shared

    var body: some View {
        Group {
            if !identity.hasNickname {
                NicknameSetupView(nickname: $identity.nickname)
            } else if store.room != nil {
                ChatRoomView(store: store)
            } else {
                ChatEntryView(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 닉네임 최초 설정

private struct NicknameSetupView: View {
    @Binding var nickname: String
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.crop.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Choose a name for chat")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            TextField("Nickname", text: $draft)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .glassTextEditor()
                .frame(width: 180)
                .onSubmit(commit)
            Button("Get Started", action: commit)
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            Spacer()
        }
        .padding()
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        nickname = trimmed
    }
}

// MARK: - 진입 화면 (생성 / 입장)

private struct ChatEntryView: View {
    @Bindable var store: ChatStore
    private enum Mode { case menu, create, join }
    @State private var mode: Mode = .menu

    var body: some View {
        VStack(spacing: 12) {
            switch mode {
            case .menu: menu
            case .create: CreateRoomForm(store: store, onCancel: { mode = .menu })
            case .join: JoinRoomForm(store: store, onCancel: { mode = .menu })
            }
        }
        .padding()
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    private var menu: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Chat Rooms")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)
            entryButton(icon: "plus", title: "Create a room") { mode = .create }
            entryButton(icon: "magnifyingglass", title: "Join with a code") { mode = .join }
            Spacer()
        }
    }

    private func entryButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(.subheadline, design: .rounded, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 방 생성 폼

private struct CreateRoomForm: View {
    @Bindable var store: ChatStore
    let onCancel: () -> Void
    @State private var name = ""
    @State private var password = ""

    var body: some View {
        FormScaffold(title: "New Room", onCancel: onCancel) {
            LabeledField("Room name") { TextField("e.g. Study Group", text: $name).textFieldStyle(.plain) }
            LabeledField("Password") { SecureField("Room password", text: $password).textFieldStyle(.plain) }
        } action: {
            Button {
                Task { await store.createRoom(name: name, password: password) }
            } label: {
                Text(store.isBusy ? "Creating…" : "Create").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isBusy || name.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
        }
        .errorBanner(store.errorMessage)
    }}

// MARK: - 방 입장 폼

private struct JoinRoomForm: View {
    @Bindable var store: ChatStore
    let onCancel: () -> Void
    @State private var code = ""
    @State private var password = ""

    var body: some View {
        FormScaffold(title: "Join with Code", onCancel: onCancel) {
            LabeledField("Room code") {
                TextField("e.g. 4BW8Z5", text: $code)
                    .textFieldStyle(.plain)
                    .textCase(.uppercase)
                    .autocorrectionDisabled()
            }
            LabeledField("Password") { SecureField("Room password", text: $password).textFieldStyle(.plain) }
        } action: {
            Button {
                Task { await store.joinRoom(code: code, password: password) }
            } label: {
                Text(store.isBusy ? "Joining…" : "Join").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isBusy || code.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
        }
        .errorBanner(store.errorMessage)
    }}

// MARK: - 폼 공통 골격

/// 라벨 + glassTextEditor 로 감싼 입력 필드. 생성/입장 폼 공용.
private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content.glassTextEditor()
        }
    }
}

private struct FormScaffold<Fields: View, Action: View>: View {
    let title: String
    let onCancel: () -> Void
    @ViewBuilder var fields: Fields
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(GlassButtonStyle())
                Text(title).font(.system(.headline, design: .rounded))
                Spacer()
            }
            fields
            action
            Spacer()
        }
    }
}

// MARK: - 채팅방 화면

private struct ChatRoomView: View {
    @Bindable var store: ChatStore
    @State private var draft = ""
    @State private var copied = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            messageList
            inputBar
        }
        // 채팅방 진입 시 입력창에 포커스를 줘 커서가 바로 깜빡이게 한다.
        .onAppear { inputFocused = true }
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(store.room?.name ?? "")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if !store.isConnected {
                        Text("Connecting…").font(.caption2).foregroundStyle(.tertiary)
                    } else {
                        Text(store.room?.code ?? "").font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Menu {
                Button("Copy code") { copyCode() }
                Divider()
                Button("Leave", role: .destructive) { store.leaveRoom() }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 13, weight: .semibold)).frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            if copied {
                Text("Code copied").font(.caption2).padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.ultraThinMaterial)).padding(.top, 2)
            }
        }
    }

    private var messageList: some View {
        let myDeviceId = ChatIdentity.shared.deviceId
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    // 맨 위 도달 시 과거 페이지 로드. 로드 후 직전 최상단 메시지로 스크롤을 고정해
                    // 위치가 튀지 않게 한다.
                    if store.hasMoreHistory {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .onAppear {
                                let anchor = store.messages.first?.id
                                Task {
                                    await store.loadOlder()
                                    if let anchor { proxy.scrollTo(anchor, anchor: .top) }
                                }
                            }
                    }
                    ForEach(store.messages) { message in
                        MessageBubble(message: message, isMine: message.senderId == myDeviceId)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            // 끝에 새 메시지가 붙을 때만 맨 아래로 스크롤(과거 prepend 시엔 last가 그대로라 안 움직임).
            .onChange(of: store.messages.last?.id) { _, _ in
                if let last = store.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .glassTextEditor()
                .focused($inputFocused)
                .onSubmit(sendDraft)
            Button(action: sendDraft) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 24))
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func sendDraft() {
        store.send(draft)   // 빈 값·미연결 검증은 store.send 가 담당
        draft = ""
    }

    private func copyCode() {
        guard let code = store.room?.code else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }
}

// MARK: - 메시지 버블

private struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 32) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if !isMine {
                    Text(message.senderName).font(.caption2).foregroundStyle(.secondary).padding(.leading, 4)
                }
                HStack(alignment: .bottom, spacing: 4) {
                    if isMine { Text(message.timeText).font(.caption2).foregroundStyle(.tertiary) }
                    Text(message.content)
                        .font(.system(.subheadline))
                        .foregroundStyle(isMine ? Color.white : Color.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(bubbleBackground)
                    if !isMine { Text(message.timeText).font(.caption2).foregroundStyle(.tertiary) }
                }
            }
            if !isMine { Spacer(minLength: 32) }
        }
    }

    @ViewBuilder private var bubbleBackground: some View {
        if isMine {
            RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius, style: .continuous).fill(Color.accentColor)
        } else {
            RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius, style: .continuous).fill(.ultraThinMaterial)
        }
    }
}

// MARK: - 에러 배너 헬퍼

private extension View {
    @ViewBuilder func errorBanner(_ message: String?) -> some View {
        if let message {
            VStack {
                self
                Text(message).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        } else {
            self
        }
    }
}
