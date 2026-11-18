import PearlKit
import Security
import SwiftUI

@MainActor
@Observable
final class NetworkSourceModel {
    var sources: [NetworkSource]
    private let store: JSONFileStore<[NetworkSource]>

    init(baseDirectory: URL) {
        store = JSONFileStore(url: baseDirectory.appending(path: ".pearl-sources.json"), fallback: [])
        sources = store.load()
    }

    func save(_ source: NetworkSource, password: String) {
        sources.removeAll { $0.id == source.id }
        sources.append(source)
        try? store.save(sources)
        if !password.isEmpty { KeychainCredentials.save(password, account: source.credentialID) }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets { KeychainCredentials.delete(account: sources[index].credentialID) }
        sources.remove(atOffsets: offsets)
        try? store.save(sources)
    }
}

enum KeychainCredentials {
    static func save(_ password: String, account: String) {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Pearl Network Sources",
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Pearl Network Sources",
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct NetworkSourcesView: View {
    @Bindable var model: NetworkSourceModel
    let play: (URL) -> Void
    @State private var editor: NetworkSource?

    var body: some View {
        List {
            ForEach(model.sources) { source in
                Button {
                    if let url = source.url { play(url) }
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text(source.name)
                            Text(source.url?.absoluteString ?? source.host).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "externaldrive.connected.to.line.below")
                    }
                }.swipeActions { Button("Edit") { editor = source }.tint(.blue) }
            }.onDelete(perform: model.delete)
        }
        .navigationTitle("Network Sources")
        .overlay {
            if model.sources.isEmpty {
                ContentUnavailableView(
                    "No network sources", systemImage: "network",
                    description: Text("Add a server to browse or play its URL."))
            }
        }
        .toolbar {
            Button("Add Source", systemImage: "plus") { editor = NetworkSource(name: "", protocolKind: .smb, host: "") }
        }
        .sheet(item: $editor) { source in
            SourceEditor(source: source) { edited, password in
                model.save(edited, password: password)
                editor = nil
            }
        }
    }
}

private struct SourceEditor: View {
    @State var source: NetworkSource
    let save: (NetworkSource, String) -> Void
    @State private var password = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Picker("Protocol", selection: $source.protocolKind) {
                    ForEach(NetworkProtocol.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
                }
                TextField("Name", text: $source.name)
                TextField("Host", text: $source.host).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Path", text: $source.path).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Username", text: $source.username).textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
                Text("Passwords are stored only in the device Keychain.").font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("Source")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(source, password) }.disabled(source.name.isEmpty || source.host.isEmpty)
                }
            }
        }
    }
}
