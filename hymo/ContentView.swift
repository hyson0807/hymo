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
    @State private var hasUserResized = UserDefaults.standard.bool(forKey: "hasUserResized")
    @State private var userWidth: CGFloat = {
        let v = UserDefaults.standard.double(forKey: "userWindowWidth")
        return v > 0 ? v : 320
    }()
    @State private var userHeight: CGFloat = {
        let v = UserDefaults.standard.double(forKey: "userWindowHeight")
        return v > 0 ? v : 200
    }()

    private let minWindowHeight: CGFloat = 120
    private let defaultWindowWidth: CGFloat = 320
    private let minWindowWidth: CGFloat = 260
    private let maxWindowWidth: CGFloat = 600
    private let memoListPadding: CGFloat = GlassTheme.cardSpacing

    private var maxWindowHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 600) * 0.85
    }

    private var effectiveWidth: CGFloat {
        hasUserResized ? userWidth : defaultWindowWidth
    }

    private var memoListHeight: CGFloat {
        let memoCount = CGFloat(memoHeights.count)
        let spacingHeight = max(0, memoCount - 1) * memoListPadding
        let verticalPadding = (memoListPadding + GlassTheme.shadowRadius) * 2
        return memoHeights.values.reduce(0, +) + spacingHeight + verticalPadding
    }

    private var autoHeight: CGFloat {
        min(max(memoListHeight + headerHeight, minWindowHeight), maxWindowHeight)
    }

    private var effectiveHeight: CGFloat {
        hasUserResized ? userHeight : autoHeight
    }

    private var scrollEnabled: Bool {
        if hasUserResized { return true }
        return memoListHeight + headerHeight > maxWindowHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 0) {
                HStack {
                    Text("Hymo")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                    Spacer()
                    SettingsLink {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(GlassButtonStyle())
                    .help("Settings")
                    Button {
                        let memo = store.addMemo()
                        focusedMemoID = memo.id
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(GlassButtonStyle())
                    .help("New memo")
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.primary.opacity(0), .primary.opacity(0.06), .primary.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 0.5)
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
                VStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("No memos yet")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("Tap + to create one")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
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
                            .opacity(draggingMemoID == memo.id ? 0.85 : 1.0)
                            .scaleEffect(draggingMemoID == memo.id ? 1.02 : 1.0)
                        }
                    }
                    .padding(.horizontal, memoListPadding)
                    .padding(.vertical, memoListPadding + GlassTheme.shadowRadius)
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
        .frame(width: effectiveWidth, height: effectiveHeight)
        .overlay(alignment: .bottomTrailing) {
            ResizeHandleView(
                userWidth: $userWidth,
                userHeight: $userHeight,
                hasUserResized: $hasUserResized,
                minWidth: minWindowWidth, maxWidth: maxWindowWidth,
                minHeight: minWindowHeight, maxHeight: maxWindowHeight,
                defaultWidth: defaultWindowWidth
            )
        }
        .background(WindowAccessor(window: $hostWindow))
        .onChange(of: effectiveHeight) { _, _ in
            resizeWindow(to: NSSize(width: effectiveWidth, height: effectiveHeight))
        }
        .onChange(of: effectiveWidth) { _, _ in
            resizeWindow(to: NSSize(width: effectiveWidth, height: effectiveHeight))
        }
        .onChange(of: hostWindow) { _, newWindow in
            guard newWindow != nil else { return }
            resizeWindow(to: NSSize(width: effectiveWidth, height: effectiveHeight))
        }
        .onChange(of: hasUserResized) { _, isManual in
            if !isManual {
                resizeWindow(to: NSSize(width: defaultWindowWidth, height: autoHeight))
            }
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
        guard window.frame != newFrame else { return }
        window.setFrame(newFrame, display: true, animate: false)
    }
}

#Preview {
    ContentView()
}
