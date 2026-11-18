import PearlKit
import SwiftUI

struct CollectionsView: View {
    let store: JSONFileStore<LibraryState>
    let play: (URL) -> Void
    @State private var state = LibraryState()
    @State private var newPlaylist = ""

    var body: some View {
        List {
            Section("Favorites") {
                ForEach(Array(state.favorites).sorted(), id: \.self) { key in
                    if let url = resolvedURL(key) { Button(Format.title(from: url)) { play(url) } }
                }
            }
            Section("Playlists") {
                ForEach(state.playlists) { playlist in
                    NavigationLink {
                        PlaylistView(playlist: playlist, store: store, play: play)
                    } label: {
                        Text(playlist.name)
                    }
                }
                .onMove { offsets, destination in
                    update { $0.movePlaylists(fromOffsets: offsets, toOffset: destination) }
                }
                .onDelete { offsets in update { $0.deletePlaylists(atOffsets: offsets) } }
                HStack {
                    TextField("New playlist", text: $newPlaylist)
                    Button("Create") {
                        update { _ = $0.createPlaylist(named: newPlaylist) }
                        newPlaylist = ""
                    }.disabled(newPlaylist.isEmpty)
                }
            }
            Section("Bookmarks") {
                ForEach(state.bookmarks) { bookmark in
                    Button("\(bookmark.title) · \(Format.duration(bookmark.time))") { play(bookmark.mediaURL) }
                }
            }
        }.navigationTitle("Favorites & Playlists").toolbar { EditButton() }.onAppear { state = store.load() }
    }

    private func resolvedURL(_ key: String) -> URL? {
        key.hasPrefix("/") ? URL(fileURLWithPath: key) : URL(string: key)
    }
    private func update(_ body: (inout LibraryState) -> Void) {
        if let value = try? store.update(body) { state = value }
    }
}

private struct PlaylistView: View {
    let playlist: Playlist
    let store: JSONFileStore<LibraryState>
    let play: (URL) -> Void
    @State private var name: String

    init(playlist: Playlist, store: JSONFileStore<LibraryState>, play: @escaping (URL) -> Void) {
        self.playlist = playlist
        self.store = store
        self.play = play
        _name = State(initialValue: playlist.name)
    }

    var body: some View {
        List(playlist.items, id: \.self) { url in Button(Format.title(from: url)) { play(url) } }
            .navigationTitle(name)
            .toolbar { Button("Rename") { try? store.update { $0.renamePlaylist(id: playlist.id, to: name) } } }
            .safeAreaInset(edge: .bottom) {
                TextField("Playlist name", text: $name).textFieldStyle(.roundedBorder).padding()
            }
    }
}
