import AVFoundation
import Foundation

@MainActor
final class RecorderService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    enum State: Equatable {
        case idle
        case recording
        case paused
        case finished(URL, TimeInterval)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startedAt: Date?

    func start() async {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            guard granted else {
                state = .failed("麦克风权限未开启。")
                return
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("babytime-recording-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.record()
            startedAt = Date()
            elapsed = 0
            state = .recording
            startTimer()
        } catch {
            state = .failed("录音启动失败。")
        }
    }

    func pause() {
        recorder?.pause()
        state = .paused
        stopTimer()
    }

    func resume() {
        recorder?.record()
        state = .recording
        startTimer()
    }

    func stop() {
        guard let recorder else { return }
        recorder.stop()
        stopTimer()
        elapsed = recorder.currentTime
        state = .finished(recorder.url, recorder.currentTime)
        self.recorder = nil
    }

    func reset() {
        recorder?.stop()
        recorder = nil
        stopTimer()
        elapsed = 0
        state = .idle
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsed = self?.recorder?.currentTime ?? self?.elapsed ?? 0
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

@MainActor
final class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingURL: URL?
    @Published private(set) var progress: TimeInterval = 0
    private var player: AVAudioPlayer?
    private var timer: Timer?

    func play(url: URL) {
        do {
            if playingURL == url, let player {
                player.play()
            } else {
                player = try AVAudioPlayer(contentsOf: url)
                player?.delegate = self
                playingURL = url
                player?.play()
            }
            startTimer()
        } catch {
            playingURL = nil
        }
    }

    func pause() {
        player?.pause()
        stopTimer()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopTimer()
            self.playingURL = nil
            self.progress = 0
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.progress = self?.player?.currentTime ?? 0
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
