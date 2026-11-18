import PearlKit
import SwiftUI

@MainActor
@Observable
final class SettingsModel {
    var settings: AppSettings { didSet { try? store.save(settings) } }
    let store: JSONFileStore<AppSettings>

    init(baseDirectory: URL) {
        store = JSONFileStore(url: baseDirectory.appending(path: ".pearl-settings.json"), fallback: .default)
        settings = store.load()
    }

    func reset() { settings = .default }
}

struct SettingsView: View {
    @Bindable var model: SettingsModel
    @State private var query = ""

    private let sections: [(String, String)] = [
        ("Gestures", "hand.tap"), ("Playback", "play.circle"), ("Subtitles & Audio", "captions.bubble"),
        ("Appearance", "paintbrush"), ("Sources", "network"), ("Storage", "internaldrive"),
        ("Diagnostics & About", "stethoscope"), ("Advanced", "gearshape.2")
    ]

    var body: some View {
        List {
            ForEach(sections.filter { query.isEmpty || $0.0.localizedCaseInsensitiveContains(query) }, id: \.0) {
                section in
                NavigationLink {
                    destination(section.0)
                } label: {
                    Label(section.0, systemImage: section.1)
                }
            }
        }
        .navigationTitle("Settings")
        .searchable(text: $query, prompt: "Search settings")
    }

    @ViewBuilder private func destination(_ name: String) -> some View {
        switch name {
        case "Gestures": GestureSettingsView(settings: $model.settings.gestures)
        case "Playback": PlaybackSettingsView(settings: $model.settings.playback)
        case "Subtitles & Audio": TrackSettingsView(settings: $model.settings.tracks)
        case "Appearance": AppearanceSettingsView(settings: $model.settings.appearance)
        case "Sources": SourceSettingsView(settings: $model.settings.sources)
        case "Storage": StorageSettingsView(settings: $model.settings.storage)
        case "Diagnostics & About": DiagnosticsView(model: model)
        default: AdvancedSettingsView(settings: $model.settings.advanced)
        }
    }
}

private struct GestureSettingsView: View {
    @Binding var settings: GestureSettings
    var body: some View {
        Form {
            Section("Tap") {
                Picker("Double-tap seek", selection: $settings.doubleTapSeconds) {
                    ForEach(GestureSettings.doubleTapChoices, id: \.self) { Text("\(Int($0)) seconds").tag($0) }
                }
                Toggle("Center double tap plays or pauses", isOn: $settings.doubleTapCenterTogglesPlayback)
                Toggle("Two-finger tap plays or pauses", isOn: $settings.twoFingerTapTogglesPlayback)
                Toggle("Edge double tap skips chapter", isOn: $settings.edgeDoubleTapSkipsChapter)
            }
            Section("Hold & Drag") {
                Picker("Hold starts at", selection: $settings.holdBaseSpeed) {
                    ForEach(GestureSettings.holdSpeedChoices, id: \.self) { Text("\($0, specifier: "%.1f")x").tag($0) }
                }
                Picker("Maximum hold speed", selection: $settings.holdMaxSpeed) {
                    ForEach(GestureSettings.holdSpeedChoices, id: \.self) { Text("\($0, specifier: "%.1f")x").tag($0) }
                }
                Toggle("Left drag controls brightness", isOn: $settings.verticalDragDrivesBrightness)
                Toggle("Two-finger drag moves subtitles", isOn: $settings.twoFingerDragMovesSubtitles)
                Toggle("Swipe down closes player", isOn: $settings.swipeDownCloses)
            }
            Section("Zoom & Feedback") {
                Toggle("Pinch to zoom and pan", isOn: $settings.pinchToZoom)
                Toggle("Gesture HUDs", isOn: $settings.showHints)
                Toggle("Haptic ticks", isOn: $settings.haptics)
                Toggle("Keep screen awake", isOn: $settings.keepScreenAwake)
            }
        }.navigationTitle("Gestures")
    }
}

private struct PlaybackSettingsView: View {
    @Binding var settings: PlaybackSettings
    var body: some View {
        Form {
            Section("Engine") {
                Toggle("Hardware decoding", isOn: $settings.hardwareDecoding)
                Toggle("AC3/DTS pass-through", isOn: $settings.audioPassThrough)
                Toggle("Pitch correction", isOn: $settings.pitchCorrection)
                Toggle("Precise seeking", isOn: $settings.preciseSeeking)
            }
            Section("Continue Playing") {
                Toggle("Background audio", isOn: $settings.backgroundAudio)
                Toggle("Picture in Picture", isOn: $settings.pictureInPicture)
                Toggle("Autoplay next", isOn: $settings.autoplayNext)
                Toggle("Continue-watching prompt", isOn: $settings.continuePrompt)
                Toggle("Remember speed per source", isOn: $settings.rememberSpeed)
                Toggle("Shuffle", isOn: $settings.shuffle)
            }
        }.navigationTitle("Playback")
    }
}

private struct TrackSettingsView: View {
    @Binding var settings: TrackSettings
    var body: some View {
        Form {
            Section("Subtitles") {
                TextField(
                    "Preferred languages, comma separated", text: stringList($settings.preferredSubtitleLanguages))
                Toggle("Prefer forced subtitles", isOn: $settings.forcedSubtitles)
                Toggle("Auto-load matching sidecars", isOn: $settings.autoLoadSidecars)
                SecureField("OpenSubtitles API key", text: $settings.subtitleProviderKey)
            }
            Section("Audio") {
                TextField("Preferred languages, comma separated", text: stringList($settings.preferredAudioLanguages))
                Stepper("Volume boost: \(settings.volumeBoost)%", value: $settings.volumeBoost, in: 100...200, step: 10)
                Toggle("Normalize", isOn: $settings.normalizeAudio)
                Toggle("Mono", isOn: $settings.monoAudio)
                Toggle("Spatial audio", isOn: $settings.spatialAudio)
            }
            NavigationLink("Subtitle Style Presets") { SubtitlePresetHelpView() }
        }.navigationTitle("Subtitles & Audio")
    }

    private func stringList(_ value: Binding<[String]>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue.joined(separator: ", ") },
            set: {
                value.wrappedValue = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter {
                    !$0.isEmpty
                }
            })
    }
}

private struct SubtitlePresetHelpView: View {
    var body: some View {
        List {
            Text(
                "Presets include font, size, bold, italic, colors, outline, shadow, background, opacity, vertical position, and embedded-style override."
            )
        }.navigationTitle("Subtitle Styles")
    }
}

private struct AppearanceSettingsView: View {
    @Binding var settings: AppearanceSettings
    var body: some View {
        Form {
            Picker("Library layout", selection: $settings.libraryLayout) {
                Text("Grid").tag("grid")
                Text("List").tag("list")
            }
            Picker("Default aspect ratio", selection: $settings.defaultAspectRatio) {
                ForEach(["fit", "fill", "stretch", "original", "1:1", "4:3", "16:9", "2.35:1", "2.39:1"], id: \.self) {
                    Text($0).tag($0)
                }
            }
            Toggle("Clock", isOn: $settings.showClock)
            Toggle("Battery", isOn: $settings.showBattery)
            Toggle("Thumbnail previews", isOn: $settings.showThumbnails)
            Toggle("Reduce motion", isOn: $settings.reducedMotion)
        }.navigationTitle("Appearance")
    }
}

private struct SourceSettingsView: View {
    @Binding var settings: SourceSettings
    var body: some View {
        Form {
            TextField("User-Agent", text: $settings.userAgent)
            TextField("Referer", text: $settings.referer)
            Stepper(
                "Network cache: \(settings.networkCacheMilliseconds) ms", value: $settings.networkCacheMilliseconds,
                in: 0...10_000, step: 250)
            Toggle("Clipboard link detection", isOn: $settings.clipboardDetection)
            Toggle("Wi-Fi transfer enabled", isOn: $settings.wifiTransferEnabled)
            Section("Custom HTTP Headers") {
                Text("Headers are kept per source and passed only to playback requests.").foregroundStyle(.secondary)
            }
        }.navigationTitle("Sources")
    }
}

private struct StorageSettingsView: View {
    @Binding var settings: StorageSettings
    var body: some View {
        Form {
            Toggle("Download on Wi-Fi only", isOn: $settings.downloadOnWiFiOnly)
            Toggle("Keep finished downloads", isOn: $settings.keepFinishedDownloads)
            Toggle("Auto-delete watched downloads", isOn: $settings.autoDeleteWatched)
            Stepper("History: \(settings.historyLimit)", value: $settings.historyLimit, in: 0...1_000, step: 25)
            Stepper(
                "Thumbnail cache: \(settings.thumbnailCacheMegabytes) MB", value: $settings.thumbnailCacheMegabytes,
                in: 0...2_000, step: 50)
        }.navigationTitle("Storage")
    }
}

private struct DiagnosticsView: View {
    @Bindable var model: SettingsModel
    var body: some View {
        Form {
            Section("Diagnostics") {
                Toggle("Logging", isOn: $model.settings.diagnostics.loggingEnabled)
                Toggle("Playback statistics", isOn: $model.settings.diagnostics.showPlaybackStats)
                LabeledContent("Engine", value: "VLCKit")
                LabeledContent(
                    "Decode mode",
                    value: model.settings.playback.hardwareDecoding ? "Hardware with fallback" : "Software")
            }
            Section("Privacy") {
                Text(
                    "Pearl has no telemetry or account. Nothing leaves the device except streams and sources you open.")
            }
            Section("Reset") { Button("Reset All Settings", role: .destructive) { model.reset() } }
        }.navigationTitle("Diagnostics & About")
    }
}

private struct AdvancedSettingsView: View {
    @Binding var settings: AdvancedSettings
    var body: some View {
        Form {
            Picker("Deinterlace", selection: $settings.deinterlace) {
                ForEach(["off", "auto", "on"], id: \.self) { Text($0.capitalized).tag($0) }
            }
            Picker("HDR tone mapping", selection: $settings.toneMapping) {
                ForEach(["auto", "passthrough", "tone map"], id: \.self) { Text($0.capitalized).tag($0) }
            }
            Toggle("Renderer discovery", isOn: $settings.rendererDiscovery)
            Toggle("Cellular streaming", isOn: $settings.allowCellularStreaming)
            Section("Video adjustments") {
                Text(
                    "Brightness, contrast, saturation, hue, gamma, rotation, flip, zoom, snapshot, and recording are available from the player menu."
                )
            }
        }.navigationTitle("Advanced")
    }
}
