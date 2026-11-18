import CoreImage.CIFilterBuiltins
import Network
import SwiftUI

@MainActor
@Observable
final class WiFiTransferServer {
    private(set) var address: String?
    private(set) var isRunning = false
    private(set) var errorMessage: String?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "pearl.wifi-transfer")

    func start() {
        guard listener == nil else { return }
        do {
            let listener = try NWListener(using: .tcp, on: .any)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        self.isRunning = true
                        if let port = listener.port {
                            self.address = "http://\(ProcessInfo.processInfo.hostName):\(port.rawValue)"
                        }
                    case .failed(let error):
                        self.errorMessage = error.localizedDescription
                        self.stop()
                    default: break
                    }
                }
            }
            listener.start(queue: queue)
        } catch { errorMessage = error.localizedDescription }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        address = nil
    }

    nonisolated private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, accumulated: Data())
    }

    nonisolated private func receive(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8 * 1_024 * 1_024) {
            [weak self] data, _, complete, error in
            var request = accumulated
            if let data { request.append(data) }
            guard error == nil else {
                connection.cancel()
                return
            }
            if complete || self?.requestIsComplete(request) == true {
                self?.respond(to: request, on: connection)
            } else {
                self?.receive(on: connection, accumulated: request)
            }
        }
    }

    nonisolated private func requestIsComplete(_ data: Data) -> Bool {
        guard let split = data.range(of: Data("\r\n\r\n".utf8)),
            let head = String(data: data[..<split.lowerBound], encoding: .utf8)
        else { return false }
        let length =
            head.split(separator: "\r\n").first { $0.lowercased().hasPrefix("content-length:") }
            .flatMap { Int($0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)) } ?? 0
        return data.count >= split.upperBound + length
    }

    nonisolated private func respond(to request: Data, on connection: NWConnection) {
        guard let split = request.range(of: Data("\r\n\r\n".utf8)),
            let head = String(data: request[..<split.lowerBound], encoding: .utf8)
        else {
            send(status: "400 Bad Request", body: "Bad request", on: connection)
            return
        }
        if head.hasPrefix("PUT /upload") {
            let rawName =
                head.split(separator: "\r\n").first { $0.lowercased().hasPrefix("x-filename:") }
                .map { String($0.split(separator: ":", maxSplits: 1)[1]).trimmingCharacters(in: .whitespaces) }
                ?? "upload"
            let name = URL(fileURLWithPath: rawName).lastPathComponent
            let destination = LibraryModel.documentsDirectory.appending(path: name)
            do {
                try Data(request[split.upperBound...]).write(to: destination, options: .atomic)
                send(status: "201 Created", body: "Uploaded", on: connection)
            } catch { send(status: "500 Internal Server Error", body: "Could not save file", on: connection) }
        } else {
            send(status: "200 OK", body: Self.uploadPage, contentType: "text/html; charset=utf-8", on: connection)
        }
    }

    nonisolated private func send(
        status: String, body: String, contentType: String = "text/plain", on connection: NWConnection
    ) {
        let payload = Data(body.utf8)
        let header =
            "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
        connection.send(
            content: Data(header.utf8) + payload, completion: .contentProcessed { _ in connection.cancel() })
    }

    nonisolated private static let uploadPage = """
        <!doctype html><meta name="viewport" content="width=device-width"><title>Pearl Transfer</title>
        <style>body{font:18px system-ui;max-width:36rem;margin:4rem auto;padding:1rem}button,input{font:inherit;margin:1rem 0}</style>
        <h1>Send a video to Pearl</h1><input id="file" type="file"><button onclick="send()">Upload</button><p id="status"></p>
        <script>
        async function send() {
          let f=file.files[0]; if(!f)return; status.textContent='Uploading…';
          let r=await fetch('/upload',{method:'PUT',headers:{'X-Filename':f.name},body:f});
          status.textContent=r.ok?'Uploaded to Pearl':('Failed: '+r.status)
        }
        </script>
        """
}

struct WiFiTransferView: View {
    @State private var server = WiFiTransferServer()

    var body: some View {
        VStack(spacing: 24) {
            if let address = server.address {
                QRCodeView(text: address).frame(width: 220, height: 220).accessibilityLabel("QR code for \(address)")
                Text(address).font(.title3.monospaced()).textSelection(.enabled)
                Text("Open this address on a device connected to the same Wi-Fi network.").multilineTextAlignment(
                    .center
                ).foregroundStyle(.secondary)
            } else {
                ContentUnavailableView(
                    "Transfer is off", systemImage: "wifi",
                    description: Text("Start it while Pearl is open to receive files."))
            }
            Button(server.isRunning ? "Stop Transfer" : "Start Transfer") {
                server.isRunning ? server.stop() : server.start()
            }.buttonStyle(.borderedProminent)
        }.padding().navigationTitle("Wi-Fi Transfer").onDisappear { server.stop() }
    }
}

private struct QRCodeView: View {
    let text: String

    var body: some View {
        Group {
            if let image = code {
                Image(decorative: image, scale: 1).interpolation(.none).resizable()
            }
        }
    }

    /// Built outside `body` so the modifier chain stays a single expression.
    private var code: CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        guard let output = filter.outputImage else { return nil }
        return CIContext().createCGImage(
            output.transformed(by: .init(scaleX: 10, y: 10)),
            from: output.extent
        )
    }
}
