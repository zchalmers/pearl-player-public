import LocalAuthentication
import SwiftUI

@MainActor
@Observable
final class FolderLockModel {
    private(set) var lockedFolders: Set<String>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lockedFolders = Set(defaults.stringArray(forKey: "lockedFolders") ?? [])
    }

    func setLocked(_ locked: Bool, folder: URL) {
        if locked {
            lockedFolders.insert(folder.standardizedFileURL.path)
        } else {
            lockedFolders.remove(folder.standardizedFileURL.path)
        }
        defaults.set(Array(lockedFolders), forKey: "lockedFolders")
    }

    func unlock(folder: URL) async -> Bool {
        guard lockedFolders.contains(folder.standardizedFileURL.path) else { return true }
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return false }
        return
            (try? await context.evaluatePolicy(
                .deviceOwnerAuthentication, localizedReason: "Open this locked Pearl folder")) == true
    }
}
