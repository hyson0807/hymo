import Foundation

enum AppTab: CaseIterable, Hashable {
    case memos
    case servers

    var title: String {
        switch self {
        case .memos: return "Hymo"
        case .servers: return "Server"
        }
    }
}
