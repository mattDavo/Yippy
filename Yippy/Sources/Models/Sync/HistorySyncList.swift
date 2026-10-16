//
//  HistorySyncList.swift
//  Yippy
//
//  Lets sync read and change a `History` (Adapter from `History` to `SyncList`).
//

import Foundation

final class HistorySyncList: SyncList {
    
    let history: History
    
    init(_ history: History) {
        self.history = history
    }
    
    var syncItems: [SyncListItem] {
        return history.items.map({
            SyncListItem(id: $0.fsId, copiedAt: $0.metadata.copiedAt, title: $0.metadata.title, sourceBundleId: $0.metadata.sourceBundleId)
        })
    }
    
    var syncMaxItems: Int {
        return history.maxItemCount
    }
    
    func syncContent(of id: UUID) -> SyncContent? {
        guard let item = item(withId: id) else {
            return nil
        }
        return SyncPasteboardMapper.syncContent(types: item.types, read: item.data(forType:))
    }
    
    func insertSynced(_ content: SyncContent, copiedAt: Date, title: String?, at index: Int) -> UUID? {
        let data = SyncPasteboardMapper.pasteboardData(for: content)
        guard !data.isEmpty else {
            return nil
        }
        let item = HistoryItem(unsavedData: data, cache: history.cache, metadata: HistoryItemMetadata(copiedAt: copiedAt, title: title))
        history.insertItem(item, at: min(max(index, 0), history.items.count))
        return item.fsId
    }
    
    func deleteSynced(_ id: UUID) {
        if let i = index(ofId: id) {
            history.deleteItem(at: i)
        }
    }
    
    func moveSynced(_ id: UUID, to index: Int) {
        if let i = self.index(ofId: id) {
            history.moveItem(at: i, to: min(max(index, 0), history.items.count - 1))
        }
    }
    
    func setSyncedCopiedAt(_ date: Date, of id: UUID) {
        history.updateMetadata(ofItemWithId: id) { $0.copiedAt = date }
    }
    
    func setSyncedTitle(_ title: String?, of id: UUID) {
        history.updateMetadata(ofItemWithId: id) { $0.title = title }
    }
    
    private func index(ofId id: UUID) -> Int? {
        return history.items.firstIndex(where: { $0.fsId == id })
    }
    
    private func item(withId id: UUID) -> HistoryItem? {
        return history.items.first(where: { $0.fsId == id })
    }
}
