import SwiftUI

// MARK: - 서버 행 높이 측정용 PreferenceKey

struct ServerRowHeightKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - 서버 행

struct ServerRowView: View {
    let server: ServerProcess
    let monitor: ServerMonitor

    var body: some View {
        HStack(spacing: 10) {
            // 좌측 상태 엣지바 (정지 시 주황)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(server.isPaused ? Color.orange : Color.green.opacity(0.7))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(":\(server.port)")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    if server.isPaused {
                        Text("PAUSED")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                    }
                }
                Text("\(server.command) · PID \(server.pid)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let full = server.fullCommand, !full.isEmpty {
                    Text(full)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 우측 액션
            Button {
                monitor.togglePause(server)
            } label: {
                Image(systemName: server.isPaused ? "play.fill" : "pause.fill")
                    .foregroundStyle(server.isPaused ? .green : .secondary)
            }
            .buttonStyle(GlassButtonStyle())
            .help(server.isPaused ? "Resume" : "Pause")

            Button {
                monitor.terminate(server)
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.red)
            }
            .buttonStyle(GlassButtonStyle())
            .help("Kill")
        }
        .glassCard()
        .opacity(server.isPaused ? 0.65 : 1.0)
        .contentShape(Rectangle())
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ServerRowHeightKey.self,
                    value: [server.id: geo.size.height]
                )
            }
        )
    }
}
