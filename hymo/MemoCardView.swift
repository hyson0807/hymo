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
                    .scrollDisabled(false)
                    .frame(minHeight: 40, maxHeight: 180)
                    .glassTextEditor()
                    .focused(isFocused, equals: memo.id)
                    .onChange(of: localText) { _, newValue in
                        store.updateContent(for: memo.id, content: newValue)
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
