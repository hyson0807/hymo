import SwiftUI

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
    @State private var dragStartHeight: CGFloat = 0
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
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 10)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .overlay {
                        Capsule()
                            .fill(.primary.opacity(isCardResizeHovered ? 0.3 : 0.1))
                            .frame(width: 30, height: 3)
                    }
                    .onHover { hovering in
                        isCardResizeHovered = hovering
                        if hovering {
                            NSCursor.resizeUpDown.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragStartHeight == 0 {
                                    dragStartHeight = memo.cardHeight ?? measuredEditorHeight
                                }
                                let newHeight = max(40, dragStartHeight + value.translation.height)
                                store.updateCardHeight(for: memo.id, height: newHeight)
                            }
                            .onEnded { _ in
                                dragStartHeight = 0
                            }
                    )
                    .onTapGesture(count: 2) {
                        store.updateCardHeight(for: memo.id, height: nil)
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
