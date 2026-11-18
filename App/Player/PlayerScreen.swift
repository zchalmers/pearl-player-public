import PearlKit
import SwiftUI
import UIKit

/// The player screen: engine view at the bottom, gesture surface on top of it,
/// controls on top of that.
struct PlayerScreen: View {
    @State var model: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAudioPicker = false
    @State private var showingSubtitlePicker = false
    @State private var showingSpeedMenu = false
    @State private var showingStats = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let engine = model.engine {
                EngineHostView(renderView: engine.renderView)
                    .ignoresSafeArea()
            }

            GestureCatcherView(
                onSingleTap: { model.toggleControls() },
                onDoubleTap: { zone, _ in model.doubleTap(zone: zone) },
                onHoldBegan: { model.beginHold() },
                onHoldChanged: { model.updateHold(verticalOffset: $0) },
                onHoldEnded: { model.endHold() },
                onScrubBegan: { model.beginScrub() },
                onScrubChanged: { translation, width in
                    let delta = SeekMath.scrubDelta(
                        translation: translation,
                        width: width,
                        duration: model.duration,
                        precision: model.gestureSettings.scrubPrecision
                    )
                    model.updateScrub(to: model.currentTime + delta)
                },
                onScrubEnded: { model.commitScrub() },
                onVerticalDragBegan: { _ in },
                onVerticalDragChanged: { delta, left in
                    let fraction = Float(delta / 400)
                    if left, model.gestureSettings.verticalDragDrivesBrightness {
                        model.adjustBrightness(by: fraction)
                    } else {
                        model.adjustVolume(by: fraction)
                    }
                },
                onVerticalDragEnded: { _ in },
                onPinchChanged: { scale in
                    guard model.gestureSettings.pinchToZoom else { return }
                    model.setZoom(scale: scale)
                },
                onPinchEnded: { model.resetZoom() },
                onTwoFingerTap: {
                    guard model.gestureSettings.twoFingerTapTogglesPlayback else { return }
                    model.togglePlayPause()
                },
                onSwipeDown: {
                    guard model.gestureSettings.swipeDownCloses else { return }
                    model.exit()
                    dismiss()
                },
                isEnabled: !model.gestureSettings.lockControls
            )
            .ignoresSafeArea()

            if model.controlsVisible || !model.state.isPlaying {
                controls
                    .transition(.opacity)
            }

            hints
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .animation(.easeInOut(duration: 0.18), value: model.controlsVisible)
        .onAppear { model.showControls() }
        .sheet(isPresented: $showingAudioPicker) {
            TrackPicker(
                title: "Audio",
                tracks: model.audioTracks,
                onSelect: { model.selectAudio(id: $0.id) },
                onDismiss: { model.showControls() }
            )
        }
        .sheet(isPresented: $showingSubtitlePicker) {
            TrackPicker(
                title: "Subtitles",
                tracks: model.subtitleTracks,
                multiSelect: true,
                onToggle: { model.toggleSubtitle(id: $0.id) },
                onDisableAll: { model.disableSubtitles() },
                onDismiss: { model.showControls() }
            )
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack {
            topBar
            Spacer()
            if model.state.isPlaying == false {
                playButton
            }
            Spacer()
            bottomBar
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.65), .clear, .clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var topBar: some View {
        HStack(spacing: 18) {
            Button {
                model.exit()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.request?.title ?? model.request.map { Format.title(from: $0.url) } ?? "Pearl Player")
                    .font(.headline)
                    .lineLimit(1)
                if let source = model.request?.sourceApp {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                showingStats.toggle()
            } label: {
                Image(systemName: "chart.bar.doc.horizontal")
            }
            Button {
                model.togglePictureInPicture()
            } label: {
                Image(systemName: "pip.enter")
            }
            Button {
                showingSubtitlePicker = true
            } label: {
                Image(systemName: model.selectedSubtitleTracks.isEmpty ? "captions.bubble" : "captions.bubble.fill")
            }
            Menu {
                Button("Audio track") { showingAudioPicker = true }
                Button("Subtitles") { showingSubtitlePicker = true }
                Divider()
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0], id: \.self) { rate in
                    Button(Format.rate(Float(rate))) { model.setPlaybackRate(Float(rate)) }
                }
                Divider()
                ForEach(AspectRatioMode.allCases, id: \.self) { mode in
                    Button(mode.displayName) { model.aspectRatio = mode }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .tint(.white)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var playButton: some View {
        Button {
            model.togglePlayPause()
        } label: {
            Image(systemName: model.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 46))
                .padding(24)
                .background(.ultraThinMaterial, in: Circle())
        }
        .tint(.white)
        .opacity(model.state == .ended ? 0 : 1)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            SeekBar(
                currentTime: model.isScrubbing ? model.scrubTarget : model.currentTime,
                duration: model.duration,
                bufferProgress: model.bufferProgress,
                onScrub: { model.updateScrub(to: $0) },
                onBegin: { model.beginScrub() },
                onEnd: { model.commitScrub() }
            )
            HStack(spacing: 22) {
                Button {
                    model.seek(by: -model.gestureSettings.doubleTapSeconds, side: .back)
                } label: {
                    Image(systemName: "gobackward.\(Int(model.gestureSettings.doubleTapSeconds))")
                }
                Button {
                    model.togglePlayPause()
                } label: {
                    Image(systemName: model.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30))
                }
                Button {
                    model.seek(by: model.gestureSettings.doubleTapSeconds, side: .forward)
                } label: {
                    Image(systemName: "goforward.\(Int(model.gestureSettings.doubleTapSeconds))")
                }
                Spacer()
                Text(Format.duration(model.isScrubbing ? model.scrubTarget : model.currentTime))
                    .font(.footnote.monospacedDigit())
                Text("/")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(Format.duration(model.duration))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.toggleLock()
                } label: {
                    Image(systemName: model.gestureSettings.lockControls ? "lock.fill" : "lock.open")
                }
            }
            .tint(.white)
            .font(.system(size: 22))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - HUDs

    private var hints: some View {
        ZStack {
            if let hint = model.seekHint {
                HUDLabel(text: "\(hint.text)\n\(Format.duration(hint.target))", alignment: hint.side)
            }
            if let rate = model.holdRate {
                HUDLabel(text: "\(Format.rate(rate))", alignment: .center)
            }
            if let volume = model.volumeHint {
                HUDLabel(text: "Volume \(Int(volume * 100))%", alignment: .center)
            }
            if let brightness = model.brightnessHint {
                HUDLabel(text: "Brightness \(Int(brightness * 100))%", alignment: .center)
            }
            if showingStats {
                StatsOverlay(stats: model.stats, engineVersion: model.engineVersion)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 70)
                    .padding(.leading, 20)
            }
            if case .failed(let message) = model.state {
                HUDLabel(text: message, alignment: .center)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Puts the engine's own view on screen. The view is owned by the engine, so it
/// is added once and never recreated, which is what lets playback survive a
/// SwiftUI update.
struct EngineHostView: UIViewRepresentable {
    let renderView: UIView

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.backgroundColor = .black
        renderView.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(renderView)
        NSLayoutConstraint.activate([
            renderView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            renderView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            renderView.topAnchor.constraint(equalTo: host.topAnchor),
            renderView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// A seek bar that understands a long drag as a slow, precise scrub and a short
/// drag as a quick jump, and shows the buffered range.
struct SeekBar: View {
    var currentTime: TimeInterval
    var duration: TimeInterval
    var bufferProgress: Double
    var onScrub: (TimeInterval) -> Void
    var onBegin: () -> Void
    var onEnd: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let progress = duration > 0 ? min(max(currentTime / duration, 0), 1) : 0

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.22))
                Capsule()
                    .fill(.white.opacity(0.35))
                    .frame(width: width * min(max(bufferProgress, 0), 1))
                Capsule()
                    .fill(.white)
                    .frame(width: width * progress)
                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .offset(x: max(width * progress - 7, 0))
            }
            .frame(height: 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onBegin()
                        guard duration > 0, width > 0 else { return }
                        let fraction = min(max(value.location.x / width, 0), 1)
                        onScrub(fraction * duration)
                    }
                    .onEnded { _ in onEnd() }
            )
        }
        .frame(height: 22)
    }
}

private struct HUDLabel: View {
    var text: String
    var alignment: SeekMath.TapZone

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
            .padding(.horizontal, 40)
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .back: return .leading
        case .forward: return .trailing
        case .center: return .center
        }
    }
}

private struct StatsOverlay: View {
    var stats: PlaybackStats
    var engineVersion: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(engineVersion)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            ForEach(stats.lines, id: \.0) { line in
                HStack(spacing: 8) {
                    Text(line.0)
                        .foregroundStyle(.secondary)
                    Text(line.1)
                }
                .font(.caption.monospaced())
            }
        }
        .padding(12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.white)
    }
}

/// Audio and subtitle selection. Subtitles are multi select on purpose: Pearl
/// can show two tracks at once, which is how dual language subtitles work.
struct TrackPicker: View {
    var title: String
    var tracks: [TrackInfo]
    var multiSelect = false
    var onSelect: (TrackInfo) -> Void = { _ in }
    var onToggle: (TrackInfo) -> Void = { _ in }
    var onDisableAll: () -> Void = {}
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if tracks.isEmpty {
                    Text("No tracks reported for this stream yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(tracks) { track in
                    Button {
                        multiSelect ? onToggle(track) : onSelect(track)
                        if !multiSelect { onDismiss() }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(track.detailLabel)
                                if !track.name.isEmpty, track.name != track.detailLabel {
                                    Text(track.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if track.isSelected {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                if multiSelect {
                    Button("Turn subtitles off", role: .destructive) { onDisableAll() }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }
}
