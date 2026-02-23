import SwiftUI

// MARK: - ResizeGripShape

/// Draws 3 diagonal lines (↘) in the bottom-right corner, mimicking a classic resize grip.
struct ResizeGripShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 3.5
        let lineCount = 3

        for i in 0..<lineCount {
            let offset = CGFloat(i) * spacing
            path.move(to: CGPoint(x: rect.maxX - offset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - offset))
        }
        return path
    }
}

// MARK: - _ResizeDragView (NSView subclass for mouse events)

private class _ResizeDragView: NSView {
    weak var coordinator: ResizeHandleNSView.Coordinator?

    override func resetCursorRects() {
        discardCursorRects()
        // Use a diagonal resize cursor created from SF Symbol
        if let image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right",
                               accessibilityDescription: "Resize") {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            let configured = image.withSymbolConfiguration(config) ?? image
            let cursor = NSCursor(image: configured,
                                  hotSpot: NSPoint(x: configured.size.width / 2,
                                                   y: configured.size.height / 2))
            addCursorRect(bounds, cursor: cursor)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let coordinator else { return }

        if event.clickCount == 2 {
            // Double-click: reset to auto size
            coordinator.userWidth = coordinator.defaultWidth
            coordinator.userHeight = 200
            coordinator.hasUserResized = false
            UserDefaults.standard.set(false, forKey: "hasUserResized")
            UserDefaults.standard.removeObject(forKey: "userWindowWidth")
            UserDefaults.standard.removeObject(forKey: "userWindowHeight")
            return
        }

        coordinator.initialMouseLocation = NSEvent.mouseLocation
        coordinator.initialWindowFrame = window?.frame ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let coordinator,
              let window,
              coordinator.initialMouseLocation != .zero else { return }

        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - coordinator.initialMouseLocation.x
        // Screen coordinates: Y increases upward, so dragging down = negative deltaY
        let deltaY = coordinator.initialMouseLocation.y - currentMouse.y

        let newWidth = min(max(coordinator.initialWindowFrame.width + deltaX,
                               coordinator.minWidth), coordinator.maxWidth)
        let newHeight = min(max(coordinator.initialWindowFrame.height + deltaY,
                                coordinator.minHeight), coordinator.maxHeight)

        let newFrame = NSRect(
            x: coordinator.initialWindowFrame.origin.x,
            y: coordinator.initialWindowFrame.maxY - newHeight,
            width: newWidth,
            height: newHeight
        )

        window.setFrame(newFrame, display: true, animate: false)

        coordinator.userWidth = newWidth
        coordinator.userHeight = newHeight
        coordinator.hasUserResized = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let coordinator, coordinator.hasUserResized else { return }

        UserDefaults.standard.set(coordinator.userWidth, forKey: "userWindowWidth")
        UserDefaults.standard.set(coordinator.userHeight, forKey: "userWindowHeight")
        UserDefaults.standard.set(true, forKey: "hasUserResized")

        coordinator.initialMouseLocation = .zero
        coordinator.initialWindowFrame = .zero
    }
}

// MARK: - ResizeHandleNSView (NSViewRepresentable)

struct ResizeHandleNSView: NSViewRepresentable {
    @Binding var userWidth: CGFloat
    @Binding var userHeight: CGFloat
    @Binding var hasUserResized: Bool

    let minWidth: CGFloat
    let maxWidth: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let defaultWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(userWidth: $userWidth,
                    userHeight: $userHeight,
                    hasUserResized: $hasUserResized,
                    minWidth: minWidth, maxWidth: maxWidth,
                    minHeight: minHeight, maxHeight: maxHeight,
                    defaultWidth: defaultWidth)
    }

    func makeNSView(context: Context) -> NSView {
        let view = _ResizeDragView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.minWidth = minWidth
        context.coordinator.maxWidth = maxWidth
        context.coordinator.minHeight = minHeight
        context.coordinator.maxHeight = maxHeight
    }

    class Coordinator {
        var initialMouseLocation: NSPoint = .zero
        var initialWindowFrame: NSRect = .zero

        var minWidth: CGFloat
        var maxWidth: CGFloat
        var minHeight: CGFloat
        var maxHeight: CGFloat
        let defaultWidth: CGFloat

        var userWidth: CGFloat {
            get { _userWidth.wrappedValue }
            set { _userWidth.wrappedValue = newValue }
        }
        var userHeight: CGFloat {
            get { _userHeight.wrappedValue }
            set { _userHeight.wrappedValue = newValue }
        }
        var hasUserResized: Bool {
            get { _hasUserResized.wrappedValue }
            set { _hasUserResized.wrappedValue = newValue }
        }

        private var _userWidth: Binding<CGFloat>
        private var _userHeight: Binding<CGFloat>
        private var _hasUserResized: Binding<Bool>

        init(userWidth: Binding<CGFloat>,
             userHeight: Binding<CGFloat>,
             hasUserResized: Binding<Bool>,
             minWidth: CGFloat, maxWidth: CGFloat,
             minHeight: CGFloat, maxHeight: CGFloat,
             defaultWidth: CGFloat) {
            self._userWidth = userWidth
            self._userHeight = userHeight
            self._hasUserResized = hasUserResized
            self.minWidth = minWidth
            self.maxWidth = maxWidth
            self.minHeight = minHeight
            self.maxHeight = maxHeight
            self.defaultWidth = defaultWidth
        }
    }
}

// MARK: - ResizeHandleView (SwiftUI wrapper)

struct ResizeHandleView: View {
    @Binding var userWidth: CGFloat
    @Binding var userHeight: CGFloat
    @Binding var hasUserResized: Bool

    let minWidth: CGFloat
    let maxWidth: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    var defaultWidth: CGFloat = 320

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Visual grip indicator
            ResizeGripShape()
                .stroke(.primary.opacity(isHovering ? 0.4 : 0.15), lineWidth: 1)
                .frame(width: 10, height: 10)
                .padding(4)

            // Hit target (larger than visual grip)
            ResizeHandleNSView(
                userWidth: $userWidth,
                userHeight: $userHeight,
                hasUserResized: $hasUserResized,
                minWidth: minWidth,
                maxWidth: maxWidth,
                minHeight: minHeight,
                maxHeight: maxHeight,
                defaultWidth: defaultWidth
            )
            .frame(width: 20, height: 20)
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
