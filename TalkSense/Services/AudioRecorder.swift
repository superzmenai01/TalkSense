import Foundation
import AVFoundation
import Combine

class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
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
        // 請求權限
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
            
            let audioFilename = recordingsDirectory.appendingPathComponent("\(Date().timeIntervalSince1970).m4a")
            
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
            
            // 啟動定時器更新錄音時間
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.recordingTime += 0.1
                self.audioRecorder?.updateMeters()
                self.audioLevel = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            }
            
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    // 停止錄音
    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil
        
        let url = audioRecorder?.url
        audioRecorder?.stop()
        audioRecorder = nil
        
        isRecording = false
        audioLevel = 0
        
        return url
    }
    
    // 取消錄音
    func cancelRecording() {
        timer?.invalidate()
        timer = nil
        
        if let url = audioRecorder?.url {
            try? FileManager.default.removeItem(at: url)
        }
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        isRecording = false
        recordingTime = 0
        audioLevel = 0
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
