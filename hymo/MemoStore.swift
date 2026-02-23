import Foundation

@Observable
final class MemoStore {

    private static let storageKey = "memos_v1"
    private static let legacyKey = "quickMemo"

    var memos: [Memo] = [] {
        didSet { save() }
    }

    var sortedMemos: [Memo] {
        let pinned = memos.filter(\.isPinned).sorted { $0.sortOrder < $1.sortOrder }
        let unpinned = memos.filter { !$0.isPinned }.sorted { $0.sortOrder < $1.sortOrder }
        return pinned + unpinned
    }

    init() {
        load()
        migrateFromLegacy()
    }

    // MARK: - CRUD

    func addMemo() -> Memo {
        let memo = Memo(sortOrder: 0)
        // Batch update to avoid multiple didSet → save() calls
        var updated = memos
        for i in updated.indices where !updated[i].isPinned {
            updated[i].sortOrder += 1
        }
        updated.append(memo)
        memos = updated
        return memo
    }

    func deleteMemo(_ memo: Memo) {
        memos.removeAll { $0.id == memo.id }
    }

    func updateContent(for id: UUID, content: String) {
        guard let index = memos.firstIndex(where: { $0.id == id }) else { return }
        memos[index].content = content
    }

    // MARK: - Collapse

    func toggleCollapse(_ memo: Memo) {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        memos[index].isCollapsed.toggle()
    }

    func updateCardHeight(for id: UUID, height: CGFloat?) {
        guard let index = memos.firstIndex(where: { $0.id == id }) else { return }
        memos[index].cardHeight = height
    }

    // MARK: - Pin

    func togglePin(_ memo: Memo) {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        memos[index].isPinned.toggle()

        // Assign a sortOrder at the end of the target group
        let targetGroup = memos.filter { $0.isPinned == memos[index].isPinned && $0.id != memo.id }
        let maxOrder = targetGroup.map(\.sortOrder).max() ?? -1
        memos[index].sortOrder = maxOrder + 1
    }

    // MARK: - Reorder

    func reorderMemo(_ fromID: UUID, to targetID: UUID) {
        guard fromID != targetID,
              let fromMemo = memos.first(where: { $0.id == fromID }),
              let toMemo = memos.first(where: { $0.id == targetID }),
              fromMemo.isPinned == toMemo.isPinned else { return }

        var group = memos
            .filter { $0.isPinned == fromMemo.isPinned }
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let fromIdx = group.firstIndex(where: { $0.id == fromID }),
              let toIdx = group.firstIndex(where: { $0.id == targetID }) else { return }

        let item = group.remove(at: fromIdx)
        group.insert(item, at: toIdx)

        var updated = memos
        for (i, groupMemo) in group.enumerated() {
            if let idx = updated.firstIndex(where: { $0.id == groupMemo.id }) {
                updated[idx].sortOrder = i
            }
        }
        memos = updated
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(memos) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Memo].self, from: data) else { return }
        memos = decoded
    }

    private func migrateFromLegacy() {
        let legacy = UserDefaults.standard.string(forKey: Self.legacyKey) ?? ""
        guard !legacy.isEmpty, memos.isEmpty else { return }

        let memo = Memo(content: legacy)
        memos.append(memo)
        UserDefaults.standard.removeObject(forKey: Self.legacyKey)
    }
}
