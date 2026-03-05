import Foundation
import Speech
import AVFoundation

class SpeechToText: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isTranscribing: Bool = false
    @Published var errorMessage: String?
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    init() {
        // 初始化語音識別器 - 支援廣東話同普通話
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-HK"))
    }
    
    // 請求權限
    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion(true)
                case .denied:
                    self.errorMessage = "Speech recognition permission denied"
                    completion(false)
                case .restricted:
                    self.errorMessage = "Speech recognition restricted"
                    completion(false)
                case .notDetermined:
                    self.errorMessage = "Speech recognition not determined"
                    completion(false)
                @unknown default:
                    completion(false)
                }
            }
        }
    }
    
    // 從音頻文件轉文字
    func transcribe(audioURL: URL) {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer not available"
            return
        }
        
        isTranscribing = true
        errorMessage = nil
        
        // 創建識別請求
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        
        // 優先使用離線識別 (如果可用)
        if #available(iOS 13, *) {
            request.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
        }
        
        // 開始識別
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isTranscribing = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                }
            }
        }
    }
    
    // 停止識別
    func stopTranscribing() {
        recognitionTask?.cancel()
        recognitionTask = nil
        isTranscribing = false
    }
}
