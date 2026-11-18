import Foundation
import Observation
import PearlKit
import QuickLookThumbnailing
import UIKit

enum LibrarySort: String, CaseIterable, Identifiable {
    case name, date, size, duration
    var id: Self { self }
}

struct LibraryItem: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let size: Int64?
    let modified: Date?
    var id: URL { url }
}

@MainActor
@Observable
final class LibraryModel {
    var folder: URL
    var items: [LibraryItem] = []
    var query = ""
    var sort: LibrarySort = .name
    var ascending = true
    var layout = "grid"
    var selection: Set<URL> = []
    var errorMessage: String?

    private let fileManager = FileManager.default
    private let stateStore: JSONFileStore<LibraryState>

    init(folder: URL? = nil, stateStore: JSONFileStore<LibraryState>) {
        self.folder = folder ?? Self.documentsDirectory
        self.stateStore = stateStore
        reload()
    }

    nonisolated static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var visibleItems: [LibraryItem] {
        let filtered =
            query.isEmpty ? items : items.filter { $0.url.lastPathComponent.localizedCaseInsensitiveContains(query) }
        return filtered.sorted { left, right in
            let ordered: Bool
            if left.isDirectory != right.isDirectory {
                ordered = left.isDirectory
            } else {
                switch sort {
                case .name, .duration:
                    ordered =
                        left.url.lastPathComponent.localizedStandardCompare(right.url.lastPathComponent)
                        == .orderedAscending
                case .date:
                    ordered = (left.modified ?? .distantPast) < (right.modified ?? .distantPast)
                case .size:
                    ordered = (left.size ?? 0) < (right.size ?? 0)
                }
            }
            return ascending ? ordered : !ordered
        }
    }

    func reload() {
        do {
            let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            items = try fileManager.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]
            ).map { url in
                let values = try? url.resourceValues(forKeys: keys)
                return LibraryItem(
                    url: url,
                    isDirectory: values?.isDirectory == true,
                    size: values?.fileSize.map(Int64.init),
                    modified: values?.contentModificationDate
                )
            }
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }

    func enter(_ item: LibraryItem) {
        folder = item.url
        selection.removeAll()
        reload()
    }

    func deleteSelection() {
        do {
            for url in selection { try fileManager.removeItem(at: url) }
            selection.removeAll()
            reload()
        } catch { errorMessage = error.localizedDescription }
    }

    func rename(_ item: LibraryItem, to name: String) {
        do {
            try fileManager.moveItem(at: item.url, to: item.url.deletingLastPathComponent().appending(path: name))
            reload()
        } catch { errorMessage = error.localizedDescription }
    }

    func moveSelection(to destination: URL) {
        do {
            for url in selection {
                try fileManager.moveItem(at: url, to: destination.appending(path: url.lastPathComponent))
            }
            selection.removeAll()
            reload()
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleFavorite(_ url: URL) {
        try? stateStore.update { state in
            let key = LibraryState.key(for: url)
            if state.favorites.contains(key) { state.favorites.remove(key) } else { state.favorites.insert(key) }
        }
    }

    func progress(for url: URL) -> Double? { stateStore.load().resume[LibraryState.key(for: url)]?.progress }
    func isFavorite(_ url: URL) -> Bool { stateStore.load().favorites.contains(LibraryState.key(for: url)) }
}

actor ThumbnailProvider {
    private let generator = QLThumbnailGenerator.shared

    func image(for url: URL, size: CGSize, scale: CGFloat) async -> UIImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)
        return try? await generator.generateBestRepresentation(for: request).uiImage
    }
}
