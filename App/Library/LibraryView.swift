import PearlKit
import SwiftUI

struct LibraryView: View {
    @Bindable var library: LibraryModel
    @Bindable var folderLocks: FolderLockModel
    let play: (URL) -> Void
    @State private var editing = false
    @State private var renameItem: LibraryItem?
    @State private var renameText = ""

    var body: some View {
        Group {
            if library.visibleItems.isEmpty {
                ContentUnavailableView(
                    "No videos here", systemImage: "film.stack",
                    description: Text("Add files with Files, downloads, or Wi-Fi transfer."))
            } else if library.layout == "grid" {
                ScrollView { grid }
            } else {
                List(library.visibleItems, selection: $library.selection) { row(for: $0) }
            }
        }
        .navigationTitle(library.folder.lastPathComponent)
        .searchable(text: $library.query, prompt: "Search this folder")
        .toolbar { toolbar }
        .environment(\.editMode, .constant(editing ? .active : .inactive))
        .alert("Rename", isPresented: Binding(get: { renameItem != nil }, set: { if !$0 { renameItem = nil } })) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let item = renameItem { library.rename(item, to: renameText) }
                renameItem = nil
            }
            Button("Cancel", role: .cancel) { renameItem = nil }
        }
        .alert(
            "Library error",
            isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(library.errorMessage ?? "")
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
            ForEach(library.visibleItems) { item in row(for: item) }
        }.padding()
    }

    private func row(for item: LibraryItem) -> some View {
        Button {
            activate(item)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                LibraryThumbnail(url: item.url, isDirectory: item.isDirectory)
                    .frame(maxWidth: .infinity).aspectRatio(16 / 9, contentMode: .fit)
                Text(item.url.lastPathComponent).lineLimit(2).multilineTextAlignment(.leading)
                if let progress = library.progress(for: item.url) { ProgressView(value: progress).tint(.accentColor) }
                if let size = item.size, !item.isDirectory {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)).font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.url.lastPathComponent)
        .contextMenu {
            Button(library.isFavorite(item.url) ? "Remove Favorite" : "Favorite", systemImage: "star") {
                library.toggleFavorite(item.url)
            }
            ShareLink(item: item.url)
            Button("Rename", systemImage: "pencil") {
                renameItem = item
                renameText = item.url.lastPathComponent
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu("Sort", systemImage: "arrow.up.arrow.down") {
                Picker("Sort", selection: $library.sort) {
                    ForEach(LibrarySort.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                Toggle("Ascending", isOn: $library.ascending)
            }
            Button(
                library.layout == "grid" ? "List" : "Grid",
                systemImage: library.layout == "grid" ? "list.bullet" : "square.grid.2x2"
            ) {
                library.layout = library.layout == "grid" ? "list" : "grid"
            }
            Button(editing ? "Done" : "Select") {
                editing.toggle()
                if !editing { library.selection.removeAll() }
            }
            Button(
                folderLocks.lockedFolders.contains(library.folder.standardizedFileURL.path)
                    ? "Unlock Folder" : "Lock Folder",
                systemImage: folderLocks.lockedFolders.contains(library.folder.standardizedFileURL.path)
                    ? "lock.open" : "lock"
            ) {
                let locked = folderLocks.lockedFolders.contains(library.folder.standardizedFileURL.path)
                folderLocks.setLocked(!locked, folder: library.folder)
            }
        }
        if editing {
            ToolbarItemGroup(placement: .bottomBar) {
                ShareLink(items: Array(library.selection)) { Label("Share", systemImage: "square.and.arrow.up") }
                Spacer()
                Button("Delete", systemImage: "trash", role: .destructive) { library.deleteSelection() }.disabled(
                    library.selection.isEmpty)
            }
        }
    }

    private func activate(_ item: LibraryItem) {
        if editing {
            if library.selection.contains(item.url) {
                library.selection.remove(item.url)
            } else {
                library.selection.insert(item.url)
            }
        } else if item.isDirectory {
            Task {
                if await folderLocks.unlock(folder: item.url) {
                    library.enter(item)
                }
            }
        } else {
            play(item.url)
        }
    }
}

private struct LibraryThumbnail: View {
    let url: URL
    let isDirectory: Bool
    @State private var image: UIImage?
    private let provider = ThumbnailProvider()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(.quaternary)
            if let image {
                Image(uiImage: image).resizable().scaledToFill().clipShape(.rect(cornerRadius: 10))
            } else {
                Image(systemName: isDirectory ? "folder.fill" : "film").font(.largeTitle).foregroundStyle(.secondary)
            }
        }
        .clipped()
        .task {
            if !isDirectory { image = await provider.image(for: url, size: CGSize(width: 300, height: 170), scale: 2) }
        }
    }
}
