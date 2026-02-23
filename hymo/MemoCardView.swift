import SwiftUI

// MARK: - CardResizeNSView (NSViewRepresentable for card resize)

private class _CardResizeDragView: NSView {
    weak var coordinator: CardResizeNSView.Coordinator?

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        guard let coordinator else { return }

        if event.clickCount == 2 {
            coordinator.store.updateCardHeight(for: coordinator.memoID, height: nil)
            return
        }

        coordinator.initialMouseY = NSEvent.mouseLocation.y
        coordinator.initialCardHeight = coordinator.currentHeight
    }

    override func mouseDragged(with event: NSEvent) {
        guard let coordinator,
              coordinator.initialMouseY != 0 else { return }

        let currentMouseY = NSEvent.mouseLocation.y
        // Screen coordinates: Y increases upward, dragging down = negative deltaY
        let deltaY = currentMouseY - coordinator.initialMouseY
        let newHeight = max(40, coordinator.initialCardHeight - deltaY)
        coordinator.store.updateCardHeight(for: coordinator.memoID, height: newHeight)
    }

    override func mouseUp(with event: NSEvent) {
        guard let coordinator else { return }
        coordinator.initialMouseY = 0
        coordinator.initialCardHeight = 0
    }
}

struct CardResizeNSView: NSViewRepresentable {
    let memoID: UUID
    let store: MemoStore
    let currentHeight: CGFloat
    let cardHeight: CGFloat?

    func makeCoordinator() -> Coordinator {
        Coordinator(memoID: memoID, store: store, currentHeight: currentHeight)
    }

    func makeNSView(context: Context) -> NSView {
        let view = _CardResizeDragView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.memoID = memoID
        context.coordinator.currentHeight = cardHeight ?? currentHeight
    }

    class Coordinator {
        var memoID: UUID
        let store: MemoStore
        var currentHeight: CGFloat
        var initialMouseY: CGFloat = 0
        var initialCardHeight: CGFloat = 0

        init(memoID: UUID, store: MemoStore, currentHeight: CGFloat) {
            self.memoID = memoID
            self.store = store
            self.currentHeight = currentHeight
        }
    }
}

// MARK: - MemoCardView

struct MemoCardView: View {

    let memo: Memo
    let store: MemoStore
    var isFocused: FocusState<UUID?>.Binding
    @Binding var draggingMemoID: UUID?
    @Binding var dragOffset: CGFloat

    @State private var localText: String
    @State private var isHandleHovered = false
    @State private var showCopied = false
    @State private var isCardResizeHovered = false
    @State private var measuredEditorHeight: CGFloat = 80

    init(memo: Memo, store: MemoStore, isFocused: FocusState<UUID?>.Binding, draggingMemoID: Binding<UUID?>, dragOffset: Binding<CGFloat>) {
        self.memo = memo
        self.store = store
        self.isFocused = isFocused
        self._draggingMemoID = draggingMemoID
        self._dragOffset = dragOffset
        self._localText = State(initialValue: memo.content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.toggleCollapse(memo)
                    }
                } label: {
                    Image(systemName: memo.isCollapsed ? "chevron.right" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(GlassButtonStyle())
                .help(memo.isCollapsed ? "Expand" : "Collapse")

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(localText, forType: .string)
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showCopied = false
                    }
                } label: {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(showCopied ? .green : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(GlassButtonStyle())
                .help("Copy")

                Button {
                    store.togglePin(memo)
                } label: {
                    Image(systemName: memo.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(memo.isPinned ? .orange : .secondary)
                }
                .buttonStyle(GlassButtonStyle())
                .help(memo.isPinned ? "Unpin" : "Pin")

                Button {
                    store.deleteMemo(memo)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(GlassButtonStyle())
                .help("Delete")

                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(isHandleHovered ? .primary : .tertiary)
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isHandleHovered ? Color.primary.opacity(0.08) : Color.clear)
                    )
                    .onHover { hovering in
                        isHandleHovered = hovering
                    }
                    .gesture(
                        DragGesture(coordinateSpace: .named("memoList"))
                            .onChanged { value in
                                if draggingMemoID == nil {
                                    draggingMemoID = memo.id
                                }
                                dragOffset = value.translation.height
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.15)) {
                                    draggingMemoID = nil
                                }
                                dragOffset = 0
                            }
                    )
            }
            .font(.caption)

            if memo.isCollapsed {
                Text(localText.isEmpty ? " " : localText)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(localText.isEmpty ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
            } else {
                TextEditor(text: $localText)
                    .font(.body)
                    .scrollDisabled(memo.cardHeight == nil)
                    .frame(minHeight: 40)
                    .frame(height: memo.cardHeight)
                    .glassTextEditor()
                    .focused(isFocused, equals: memo.id)
                    .onChange(of: localText) { _, newValue in
                        store.updateContent(for: memo.id, content: newValue)
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { measuredEditorHeight = geo.size.height }
                                .onChange(of: geo.size.height) { _, h in measuredEditorHeight = h }
                        }
                    )

                // Card resize handle
                ZStack {
                    Capsule()
                        .fill(.primary.opacity(isCardResizeHovered ? 0.3 : 0.1))
                        .frame(width: 30, height: 3)

                    CardResizeNSView(
                        memoID: memo.id,
                        store: store,
                        currentHeight: measuredEditorHeight,
                        cardHeight: memo.cardHeight
                    )
                    .frame(height: 10)
                    .frame(maxWidth: .infinity)
                }
                .onHover { hovering in
                    isCardResizeHovered = hovering
                }
            }
        }
        .glassCard()
        .contentShape(Rectangle())
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: MemoHeightKey.self,
                    value: [memo.id: geo.size.height]
                )
            }
        )
    }
}
