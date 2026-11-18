import PearlKit
import SwiftUI
import UIKit

/// The app's top level state: what is playing, how a link got here, and what to
/// say when a link cannot be played.
@MainActor
@Observable
final class AppModel {
    var player: PlayerViewModel?
    var notice: String?
    var pendingClipboardLink: URL?
    var recentRequests: [PlayRequest] = []

    let settings: SettingsModel
    let library: LibraryModel
    let downloads: DownloadManager
    let sources: NetworkSourceModel
    let folderLocks = FolderLockModel()

    @ObservationIgnored let libraryStore: JSONFileStore<LibraryState>

    private var engine: VLCKitEngine?

    init() {
        let documents = LibraryModel.documentsDirectory
        let store = JSONFileStore(url: documents.appending(path: ".pearl-library.json"), fallback: LibraryState())
        libraryStore = store
        settings = SettingsModel(baseDirectory: documents)
        library = LibraryModel(stateStore: store)
        downloads = DownloadManager()
        sources = NetworkSourceModel(baseDirectory: documents)
        recentRequests = store.load().recents.map { url in
            PlayRequest(url: url, origin: url.isFileURL ? .document : .url)
        }
    }

    // MARK: - Intake

    /// Everything that hands Pearl a URL lands here: URL schemes, documents, the
    /// clipboard and the in-app field.
    func handleIncoming(url: URL, origin: PlayRequest.Origin = .externalApp) {
        RemoteLog.note("incoming url \(url.absoluteString)")
        switch DeepLinkParser.parse(url) {
        case .playback(var request):
            if request.origin == .url {
                request.origin = origin
            }
            present(request)
        case .needsTorrentEngine:
            notice =
                "That is a torrent or magnet link. Pearl plays direct streams, so use a debrid source in Stremio and it will hand over an http link instead."
        case .unsupported(let reason, _):
            RemoteLog.note("incoming rejected: \(reason)")
            notice = reason
        }
    }

    func handleIncoming(string: String) {
        RemoteLog.note("incoming string \(string)")
        switch DeepLinkParser.parse(string) {
        case .playback(var request):
            request.origin = .manual
            present(request)
        case .needsTorrentEngine:
            notice = "Pearl has no torrent engine. Pick a direct stream in Stremio and it will hand over an http link."
        case .unsupported(let reason, _):
            notice = reason
        }
    }

    func present(_ request: PlayRequest) {
        let model = PlayerViewModel()
        let engine = engine ?? VLCKitEngine()
        self.engine = engine

        model.attach(engine: engine)
        model.onExit = { [weak self] request, time in
            self?.handleExit(request: request, position: time)
        }
        model.load(request)
        player = model

        recentRequests.removeAll { $0.url == request.url }
        recentRequests.insert(request, at: 0)
        if recentRequests.count > 30 {
            recentRequests.removeLast(recentRequests.count - 30)
        }
        try? libraryStore.update {
            $0.record(
                url: request.url,
                title: request.title,
                position: request.startAt ?? 0,
                historyLimit: settings.settings.storage.historyLimit
            )
        }
    }

    func dismissPlayer() {
        player?.pause()
        player = nil
    }

    /// Full teardown. The app keeps one engine for its whole life, so this is
    /// mainly for tests and for the moment playback is abandoned: VLCKit runs
    /// `playMedia:` on a worker queue, and freeing its media list underneath that
    /// block segfaults.
    func shutdown() {
        player = nil
        engine?.shutdown()
        engine = nil
    }

    /// Leaving the player is also the moment to tell Stremio where we stopped,
    /// which is the piece neither VLC nor Outplayer does on iOS.
    private func handleExit(request: PlayRequest?, position: TimeInterval) {
        defer { player = nil }
        guard let request else { return }
        try? libraryStore.update {
            $0.record(
                url: request.url,
                title: request.title,
                position: position,
                historyLimit: settings.settings.storage.historyLimit
            )
        }
        guard let callback = request.callbackURL, position > 15 else { return }
        guard
            let target = StremioBridge.progressURL(
                callback: callback,
                position: position,
                lastPlayedURL: request.url
            )
        else { return }
        UIApplication.shared.open(target)
    }

    // MARK: - Clipboard

    /// Stremio Web's "copy stream link" route ends here: if the clipboard holds
    /// something playable, offer it rather than making the user paste.
    func checkClipboardForStreamLink() {
        guard settings.settings.sources.clipboardDetection else { return }
        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty,
            text.count < 4096
        else { return }
        if case .playback(let request) = DeepLinkParser.parse(text) {
            pendingClipboardLink = request.url
        }
    }
}

/// The launcher. The library and network sources live here as they land.
struct RootView: View {
    @Bindable var model: AppModel
    @State private var urlField = ""
    @State private var showingPlayer = false

    var body: some View {
        NavigationStack {
            List {
                Section("Open a stream") {
                    TextField("https://... or a Stremio link", text: $urlField)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("Play") {
                        model.handleIncoming(string: urlField)
                        urlField = ""
                    }
                    .disabled(urlField.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section("Library") {
                    NavigationLink {
                        LibraryView(library: model.library, folderLocks: model.folderLocks) {
                            model.present(PlayRequest(url: $0, origin: .document))
                        }
                    } label: {
                        Label("On This Device", systemImage: "film.stack")
                    }
                    NavigationLink {
                        DownloadsView(downloads: model.downloads) {
                            model.present(PlayRequest(url: $0, origin: .document))
                        }
                    } label: {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }
                    NavigationLink {
                        CollectionsView(store: model.libraryStore) { model.present(PlayRequest(url: $0)) }
                    } label: {
                        Label("Favorites & Playlists", systemImage: "star")
                    }
                    NavigationLink {
                        NetworkSourcesView(model: model.sources) { model.present(PlayRequest(url: $0, origin: .url)) }
                    } label: {
                        Label("Network Sources", systemImage: "network")
                    }
                    NavigationLink {
                        WiFiTransferView()
                    } label: {
                        Label("Wi-Fi Transfer", systemImage: "wifi")
                    }
                }

                if let link = model.pendingClipboardLink {
                    Section {
                        Button {
                            model.handleIncoming(url: link)
                            model.pendingClipboardLink = nil
                        } label: {
                            Label("Play the link on your clipboard", systemImage: "doc.on.clipboard")
                        }
                    }
                }

                if !model.recentRequests.isEmpty {
                    Section("Recent") {
                        ForEach(Array(model.recentRequests.enumerated()), id: \.offset) { _, request in
                            Button {
                                model.present(request)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(request.title ?? Format.title(from: request.url))
                                        .lineLimit(1)
                                    Text(request.origin.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Pearl") {
                    NavigationLink {
                        SettingsView(model: model.settings)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }

                Section("Stremio handoff") {
                    NavigationLink("Set up Stremio") {
                        StremioSetupView()
                    }
                }
            }
            .navigationTitle("Pearl Player")
            .alert(
                "Cannot play that",
                isPresented: Binding(
                    get: { model.notice != nil },
                    set: { if !$0 { model.notice = nil } }
                )
            ) {
                Button("OK", role: .cancel) { model.notice = nil }
            } message: {
                Text(model.notice ?? "")
            }
            .fullScreenCover(
                isPresented: Binding(
                    get: { model.player != nil },
                    set: { if !$0 { model.dismissPlayer() } }
                )
            ) {
                if let player = model.player {
                    PlayerScreen(model: player)
                }
            }
        }
    }
}
