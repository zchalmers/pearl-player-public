import Foundation
import VLCKit

/// Sends libvlc log lines and app events only when explicitly configured.
/// Set PEARL_REMOTE_LOG_URL in the process environment to your own HTTPS
/// collector. Without a valid endpoint, logging is disabled and no data queues.
/// Log lines can include stream URLs and other sensitive playback details.
///
/// It is `nonisolated` on purpose. The project sets
/// `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`, and VLCKit calls logger methods
/// from libvlc worker threads, which is exactly the trap that crashed the app
/// when the playback delegate was main actor isolated.
nonisolated final class RemoteLog: NSObject, VLCLogging, @unchecked Sendable {
    static let shared = RemoteLog()

    private static let endpoint: URL? = {
        guard let value = ProcessInfo.processInfo.environment["PEARL_REMOTE_LOG_URL"],
            let url = URL(string: value), url.scheme?.lowercased() == "https",
            let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }()

    private let lock = NSLock()
    private var pending: [String] = []
    private var flushScheduled = false

    /// libvlc level, 0 error, 1 warning, 2 info, 3 debug.
    var level = VLCLogLevel(rawValue: 2) ?? VLCLogLevel(rawValue: 0)!

    func handleMessage(_ message: String, logLevel level: VLCLogLevel, context: VLCLogContext?) {
        let module = context?.module ?? "-"
        RemoteLog.enqueue("[vlc.\(module)] \(message)")
    }

    /// App side events, so the log shows what the app did before and after the
    /// stream reached libvlc.
    static func note(_ text: String) {
        enqueue("[app] \(text)")
    }

    private static func enqueue(_ line: String) {
        guard endpoint != nil else { return }
        let log = RemoteLog.shared
        log.lock.lock()
        log.pending.append(line)
        let count = log.pending.count
        let shouldSchedule = !log.flushScheduled
        if shouldSchedule { log.flushScheduled = true }
        log.lock.unlock()

        // Flush early when a burst arrives, otherwise on the next tick.
        if count >= 40 {
            log.flush()
        } else if shouldSchedule {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) {
                log.flush()
            }
        }
    }

    private func flush() {
        lock.lock()
        let lines = pending
        pending.removeAll(keepingCapacity: true)
        flushScheduled = false
        lock.unlock()

        guard let endpoint = Self.endpoint, !lines.isEmpty else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(lines.joined(separator: "\n").utf8)
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request).resume()
    }
}
