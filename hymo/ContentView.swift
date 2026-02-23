import SwiftUI

// MARK: - PreferenceKeys for measuring heights

struct HeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MemoHeightKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - NSViewRepresentable to capture the hosting window reference

private struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> WindowAccessorView {
        let view = WindowAccessorView()
        view.onWindowChange = { newWindow in
            DispatchQueue.main.async { self.window = newWindow }
        }
        return view
    }

    func updateNSView(_ nsView: WindowAccessorView, context: Context) {}

    class WindowAccessorView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }
}

// MARK: - ContentView

struct ContentView: View {

    @State private var store = MemoStore()
    @FocusState private var focusedMemoID: UUID?
    @State private var draggingMemoID: UUID?
    @State private var memoHeights: [UUID: CGFloat] = [:]
    @State private var hostWindow: NSWindow?
    @State private var dragOffset: CGFloat = 0
    @State private var dragBaseOffset: CGFloat = 0

    @State private var headerHeight: CGFloat = 0
    private let minWindowHeight: CGFloat = 120
    private let windowWidth: CGFloat = 320
    private let memoListPadding: CGFloat = 8

    private var maxWindowHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 600) * 0.85
    }

    private var memoListHeight: CGFloat {
        let memoCount = CGFloat(memoHeights.count)
        let spacingHeight = max(0, memoCount - 1) * memoListPadding
        let extraHeight = memoListPadding * 2 + spacingHeight
        return memoHeights.values.reduce(0, +) + extraHeight
    }

    private var totalHeight: CGFloat {
        min(max(memoListHeight + headerHeight, minWindowHeight), maxWindowHeight)
    }

    private var scrollEnabled: Bool {
        memoListHeight + headerHeight > maxWindowHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 0) {
                HStack {
                    Text("Hymo")
                        .font(.headline)
                    Spacer()
                    SettingsLink {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                    Button {
                        let memo = store.addMemo()
                        focusedMemoID = memo.id
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .help("New memo")
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                Divider()
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: HeaderHeightKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(HeaderHeightKey.self) { headerHeight = $0 }

            // Memo list
            if store.memos.isEmpty {
                Spacer()
                    .onAppear { memoHeights = [:] }
                Text("No memos yet.\nTap + to create one.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: memoListPadding) {
                        ForEach(store.sortedMemos) { memo in
                            MemoCardView(
                                memo: memo,
                                store: store,
                                isFocused: $focusedMemoID,
                                draggingMemoID: $draggingMemoID,
                                dragOffset: $dragOffset
                            )
                            .zIndex(draggingMemoID == memo.id ? 1 : 0)
                            .offset(y: draggingMemoID == memo.id ? dragOffset - dragBaseOffset : 0)
                            .opacity(draggingMemoID == memo.id ? 0.7 : 1.0)
                        }
                    }
                    .padding(memoListPadding)
                    .animation(draggingMemoID == nil ? .easeInOut(duration: 0.2) : nil, value: store.sortedMemos.map(\.id))
                    .animation(.easeInOut(duration: 0.2), value: store.sortedMemos.map(\.isCollapsed))
                }
                .coordinateSpace(.named("memoList"))
                .scrollDisabled(!scrollEnabled)
                .scrollBounceBehavior(.basedOnSize)
                .onPreferenceChange(MemoHeightKey.self) { heights in
                    memoHeights = heights
                }
            }
        }
        .frame(width: windowWidth, height: totalHeight)
        .background(WindowAccessor(window: $hostWindow))
        .onChange(of: totalHeight) { _, newHeight in
            resizeWindow(to: NSSize(width: windowWidth, height: newHeight))
        }
        .onChange(of: hostWindow) { _, newWindow in
            guard newWindow != nil else { return }
            resizeWindow(to: NSSize(width: windowWidth, height: totalHeight))
        }
        .onChange(of: dragOffset) { _, _ in
            handleDragReorder()
        }
        .onChange(of: draggingMemoID) { _, newValue in
            if newValue == nil {
                dragBaseOffset = 0
            }
        }
    }

    private func handleDragReorder() {
        guard let draggingID = draggingMemoID else { return }
        let sorted = store.sortedMemos
        guard let currentIndex = sorted.firstIndex(where: { $0.id == draggingID }) else { return }

        let effectiveOffset = dragOffset - dragBaseOffset
        let currentHeight = memoHeights[draggingID] ?? 0
        let spacing = memoListPadding

        if effectiveOffset > 0 {
            // Dragging down — check next card
            let nextIndex = sorted.index(after: currentIndex)
            guard nextIndex < sorted.endIndex else { return }
            let neighbor = sorted[nextIndex]
            // Don't cross pin boundary
            guard neighbor.isPinned == sorted[currentIndex].isPinned else { return }
            let neighborHeight = memoHeights[neighbor.id] ?? 0
            let threshold = (currentHeight + neighborHeight) / 2 + spacing
            if effectiveOffset > threshold {
                store.reorderMemo(draggingID, to: neighbor.id)
                dragBaseOffset += neighborHeight + spacing
            }
        } else if effectiveOffset < 0 {
            // Dragging up — check previous card
            guard currentIndex > sorted.startIndex else { return }
            let prevIndex = sorted.index(before: currentIndex)
            let neighbor = sorted[prevIndex]
            guard neighbor.isPinned == sorted[currentIndex].isPinned else { return }
            let neighborHeight = memoHeights[neighbor.id] ?? 0
            let threshold = (currentHeight + neighborHeight) / 2 + spacing
            if -effectiveOffset > threshold {
                store.reorderMemo(draggingID, to: neighbor.id)
                dragBaseOffset -= neighborHeight + spacing
            }
        }
    }

    private func resizeWindow(to size: NSSize) {
        guard let window = hostWindow else { return }
        let newFrame = NSRect(
            x: window.frame.origin.x,
            y: window.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        window.setFrame(newFrame, display: true, animate: false)
    }
}

#Preview {
    ContentView()
}
