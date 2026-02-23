import SwiftUI

// MARK: - PreferenceKey for measuring list height

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

    private let headerHeight: CGFloat = 50
    private let minWindowHeight: CGFloat = 120
    private let windowWidth: CGFloat = 320
    private let memoListBottomPadding: CGFloat = 12
    private let memoListInterItemSpacing: CGFloat = 8
    private let memoListVerticalPadding: CGFloat = 16

    private var maxWindowHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 600) * 0.85
    }

    private var memoListHeight: CGFloat {
        let memoCount = CGFloat(memoHeights.count)
        let spacingHeight = max(0, memoCount - 1) * memoListInterItemSpacing
        let extraHeight = memoListVerticalPadding + memoListBottomPadding + spacingHeight
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
            HStack {
                Text("Hymo")
                    .font(.headline)
                Spacer()
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
                    VStack(spacing: 8) {
                        ForEach(store.sortedMemos) { memo in
                            MemoCardView(
                                memo: memo,
                                store: store,
                                isFocused: $focusedMemoID,
                                draggingMemoID: $draggingMemoID
                            )
                        }
                        Spacer().frame(height: memoListBottomPadding)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .animation(.easeInOut(duration: 0.2), value: store.sortedMemos.map(\.id))
                    .animation(.easeInOut(duration: 0.2), value: store.sortedMemos.map(\.isCollapsed))
                }
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
