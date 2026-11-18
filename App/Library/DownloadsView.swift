import SwiftUI

struct DownloadsView: View {
    @Bindable var downloads: DownloadManager
    let play: (URL) -> Void
    @State private var newURL = ""

    var body: some View {
        List {
            Section("Download a URL") {
                TextField("https://…", text: $newURL).keyboardType(.URL).textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Add to Queue") {
                    if let url = URL(string: newURL), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                        downloads.enqueue(url)
                        newURL = ""
                    }
                }
            }
            Section("Downloads") {
                ForEach(downloads.items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.sourceURL.lastPathComponent).lineLimit(1)
                        if let progress = item.progress { ProgressView(value: progress) }
                        HStack {
                            Text(item.status.rawValue.capitalized).foregroundStyle(.secondary)
                            Spacer()
                            if item.status == .downloading { Button("Pause") { downloads.pause(id: item.id) } }
                            if item.status == .paused { Button("Resume") { downloads.start(id: item.id) } }
                            if let url = item.destinationURL { Button("Play") { play(url) } }
                            Button("Delete", role: .destructive) { downloads.delete(id: item.id) }
                        }.buttonStyle(.borderless)
                    }
                }
            }
        }.navigationTitle("Downloads")
    }
}
