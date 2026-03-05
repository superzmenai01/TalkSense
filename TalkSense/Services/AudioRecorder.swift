import Foundation
import AVFoundation
import Combine

class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = -160
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: DispatchSourceTimer?
    private var audioSession: AVAudioSession = .sharedInstance()
    
    // 錄音文件路徑
    var recordingsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: recordingsPath.path) {
            try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }
        
        return recordingsPath
    }
    
    // 開始錄音
    func startRecording() {
        // 使用 iOS 17+ API
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.setupAndStartRecording()
                } else {
                    print("Microphone permission denied")
                }
            }
        }
    }
    
    private func setupAndStartRecording() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            let timestamp = Int(Date().timeIntervalSince1970)
            let audioFilename = recordingsDirectory.appendingPathComponent("recording_\(timestamp).m4a")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            audioLevel = -160
            
            // 啟動定時器
            startTimer()
            
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func startTimer() {
        timer = DispatchSource.makeTimerSource(queue: .main)
        timer?.schedule(deadline: .now(), repeating: 0.1)
        timer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            if self.isRecording {
                self.recordingTime += 0.1
                self.audioRecorder?.updateMeters()
                let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                self.audioLevel = max(-160, min(0, power))
            } else {
                self.timer?.cancel()
                self.timer = nil
            }
        }
        timer?.resume()
    }
    
    // 停止錄音
    func stopRecording() -> URL? {
        timer?.cancel()
        timer = nil
        
        let url = audioRecorder?.url
        audioRecorder?.stop()
        audioRecorder = nil
        
        isRecording = false
        audioLevel = -160
        
        return url
    }
    
    // 取消錄音
    func cancelRecording() {
        timer?.cancel()
        timer = nil
        
        if let url = audioRecorder?.url {
            try? FileManager.default.removeItem(at: url)
        }
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        isRecording = false
        recordingTime = 0
        audioLevel = -160
    }
    
    // 獲取所有錄音文件
    func getAllRecordings() -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: [.creationDateKey])
            return files.filter { $0.pathExtension == "m4a" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            return []
        }
    }
    
    // 刪除錄音
    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
