import Foundation

public enum JSONFileStoreError: Error, Equatable {
    case missingParentDirectory
}

/// A small atomic JSON document store. Callers own the schema and can mutate a
/// complete value without exposing half-written state to another launch.
public final class JSONFileStore<Value: Codable & Sendable>: @unchecked Sendable {
    public let url: URL
    private let fallback: Value
    private let lock = NSLock()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(url: URL, fallback: Value) {
        self.url = url
        self.fallback = fallback
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() -> Value {
        lock.withLock {
            guard let data = try? Data(contentsOf: url) else { return fallback }
            return (try? decoder.decode(Value.self, from: data)) ?? fallback
        }
    }

    public func save(_ value: Value) throws {
        try lock.withLock {
            let parent = url.deletingLastPathComponent()
            guard !parent.path.isEmpty else { throw JSONFileStoreError.missingParentDirectory }
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        }
    }

    @discardableResult
    public func update(_ body: (inout Value) throws -> Void) throws -> Value {
        try lock.withLock {
            var value: Value
            if let data = try? Data(contentsOf: url), let decoded = try? decoder.decode(Value.self, from: data) {
                value = decoded
            } else {
                value = fallback
            }
            try body(&value)
            let parent = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try encoder.encode(value).write(to: url, options: .atomic)
            return value
        }
    }
}
