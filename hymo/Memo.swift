import Foundation

struct Memo: Identifiable, Codable, Equatable {
    let id: UUID
    var content: String
    var isPinned: Bool
    var sortOrder: Int
    var isCollapsed: Bool
    var cardHeight: CGFloat?
    let createdAt: Date

    init(id: UUID = UUID(), content: String = "", isPinned: Bool = false, sortOrder: Int = 0, isCollapsed: Bool = false, cardHeight: CGFloat? = nil, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.isPinned = isPinned
        self.sortOrder = sortOrder
        self.isCollapsed = isCollapsed
        self.cardHeight = cardHeight
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
        cardHeight = try container.decodeIfPresent(CGFloat.self, forKey: .cardHeight)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
