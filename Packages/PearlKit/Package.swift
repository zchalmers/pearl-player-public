// swift-tools-version: 6.4
import PackageDescription

// PearlKit is the part of Pearl Player that has no SwiftUI and no VLCKit in it,
// so the whole thing builds and its tests run on Linux in seconds. Deep link
// parsing, playlist parsing, settings, resume state and gesture math all live
// here. If a rule matters, its test belongs in Tests/PearlKitTests.
let package = Package(
    name: "PearlKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(name: "PearlKit", targets: ["PearlKit"])
    ],
    targets: [
        .target(
            name: "PearlKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "PearlKitTests",
            dependencies: ["PearlKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
