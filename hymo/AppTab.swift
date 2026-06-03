import Foundation

enum AppTab: CaseIterable, Hashable {
    case memos
    case servers
    case chat

    var title: String {
        switch self {
        case .memos: return "Hymo"
        case .servers: return "Server"
        case .chat: return "Chat"
        }
    }
}
