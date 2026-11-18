import Foundation
import Observation

struct DownloadItem: Codable, Identifiable {
    enum Status: String, Codable { case queued, downloading, paused, finished, failed }
    var id: UUID
    var sourceURL: URL
    var destinationURL: URL?
    var resumeData: Data?
    var receivedBytes: Int64
    var expectedBytes: Int64?
    var status: Status
    var error: String?

    var progress: Double? {
        guard let expectedBytes, expectedBytes > 0 else { return nil }
        return Double(receivedBytes) / Double(expectedBytes)
    }
}

@MainActor
@Observable
final class DownloadManager: NSObject, URLSessionDownloadDelegate {
    private(set) var items: [DownloadItem] = []
    private var tasks: [UUID: URLSessionDownloadTask] = [:]
    @ObservationIgnored private var session: URLSession!
    private let metadataURL = LibraryModel.documentsDirectory.appending(path: ".pearl-downloads.json")

    override init() {
        super.init()
        session = URLSession(
            configuration: .background(
                withIdentifier: "\(Bundle.main.bundleIdentifier ?? "org.example.pearlplayer").downloads"
            ),
            delegate: self,
            delegateQueue: nil
        )
        if let data = try? Data(contentsOf: metadataURL),
            let decoded = try? JSONDecoder().decode([DownloadItem].self, from: data)
        {
            items = decoded
        }
    }

    func enqueue(_ url: URL) {
        let item = DownloadItem(id: UUID(), sourceURL: url, receivedBytes: 0, status: .queued)
        items.append(item)
        start(id: item.id)
    }

    func start(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let task =
            items[index].resumeData.map(session.downloadTask(withResumeData:))
            ?? session.downloadTask(with: items[index].sourceURL)
        task.taskDescription = id.uuidString
        tasks[id] = task
        items[index].status = .downloading
        items[index].resumeData = nil
        task.resume()
        save()
    }

    func pause(id: UUID) {
        tasks[id]?.cancel { [weak self] data in
            Task { @MainActor in
                guard let self, let index = self.items.firstIndex(where: { $0.id == id }) else { return }
                self.items[index].resumeData = data
                self.items[index].status = .paused
                self.tasks[id] = nil
                self.save()
            }
        }
    }

    func delete(id: UUID) {
        tasks[id]?.cancel()
        if let destination = items.first(where: { $0.id == id })?.destinationURL {
            try? FileManager.default.removeItem(at: destination)
        }
        tasks[id] = nil
        items.removeAll { $0.id == id }
        save()
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let id = downloadTask.taskDescription.flatMap(UUID.init) else { return }
        Task { @MainActor in
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            items[index].receivedBytes = totalBytesWritten
            items[index].expectedBytes = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
        }
    }

    nonisolated func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL
    ) {
        guard let id = downloadTask.taskDescription.flatMap(UUID.init) else { return }
        let suggestedName =
            downloadTask.response?.suggestedFilename ?? downloadTask.originalRequest?.url?.lastPathComponent
            ?? id.uuidString
        let destination = LibraryModel.documentsDirectory.appending(path: suggestedName)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            Task { @MainActor in finish(id: id, destination: destination, error: nil) }
        } catch {
            Task { @MainActor in finish(id: id, destination: nil, error: error.localizedDescription) }
        }
    }

    private func finish(id: UUID, destination: URL?, error: String?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].destinationURL = destination
        items[index].status = error == nil ? .finished : .failed
        items[index].error = error
        tasks[id] = nil
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: metadataURL, options: .atomic) }
    }
}
