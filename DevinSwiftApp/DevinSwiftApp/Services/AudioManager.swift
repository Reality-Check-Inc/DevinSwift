import Foundation
import AVFoundation

enum AudioManagerError: Error {
    case recordPermissionDenied
    case recordSetupFailed
    case recordFailed
    case playbackFailed
}

class AudioManager: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingURL: URL?
    @Published var recordingLevels: [Float] = []
    
    private var recordingTimer: Timer?
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
        } catch {
            print("Failed to set up recording session: \(error.localizedDescription)")
        }
    }
    
    func requestRecordPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            recordingSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func startRecording() async throws {
        let granted = await requestRecordPermission()
        
        guard granted else {
            throw AudioManagerError.recordPermissionDenied
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(UUID().uuidString).m4a")
        recordingURL = fileURL
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            isRecording = true
            
            // Start monitoring levels for visualization
            startMonitoringAudioLevels()
        } catch {
            throw AudioManagerError.recordSetupFailed
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        // Stop monitoring levels
        stopMonitoringAudioLevels()
    }
    
    private func startMonitoringAudioLevels() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
            
            recorder.updateMeters()
            let level = recorder.averagePower(forChannel: 0)
            let normalizedLevel = self.normalizeAudioLevel(level)
            
            DispatchQueue.main.async {
                self.recordingLevels.append(normalizedLevel)
                if self.recordingLevels.count > 50 {
                    self.recordingLevels.removeFirst()
                }
            }
        }
    }
    
    private func stopMonitoringAudioLevels() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // Convert decibel values to a 0-1 range
    private func normalizeAudioLevel(_ level: Float) -> Float {
        // Audio levels are in decibels, typically -160 to 0
        // We want to map this to a 0-1 range for visualization
        let minDb: Float = -60.0
        let maxDb: Float = 0.0
        
        // Clamp the value to our min/max range
        let clampedLevel = max(minDb, min(maxDb, level))
        
        // Normalize to 0-1 range
        return (clampedLevel - minDb) / (maxDb - minDb)
    }
    
    func playAudio(from url: URL) throws {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            throw AudioManagerError.playbackFailed
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
    }
}

extension AudioManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        if !flag {
            recordingURL = nil
        }
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
