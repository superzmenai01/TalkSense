import Foundation

class StorageService {
    static let shared = StorageService()
    
    private let fileManager = FileManager.default
    
    // 數據存放既文件夾
    private var dataDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dataPath = documentsPath.appendingPathComponent("TalkSenseData", isDirectory: true)
        
        if !fileManager.fileExists(atPath: dataPath.path) {
            try? fileManager.createDirectory(at: dataPath, withIntermediateDirectories: true)
        }
        
        return dataPath
    }
    
    // 錄音文件夾
    var recordingsDirectory: URL {
        dataDirectory.appendingPathComponent("Recordings", isDirectory: true)
    }
    
    // 分析結果文件夾
    var analysisDirectory: URL {
        dataDirectory.appendingPathComponent("Analysis", isDirectory: true)
    }
    
    private init() {
        // 確保文件夾存在
        try? fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: analysisDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - 錄音相關
    
    // 保存錄音
    func saveRecording(from sourceURL: URL) -> URL? {
        let filename = "\(Int(Date().timeIntervalSince1970)).m4a"
        let destinationURL = recordingsDirectory.appendingPathComponent(filename)
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            print("Failed to save recording: \(error)")
            return nil
        }
    }
    
    // 獲取所有錄音
    func getAllRecordings() -> [Recording] {
        do {
            let files = try fileManager.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: [.creationDateKey])
            return files
                .filter { $0.pathExtension == "m4a" }
                .map { url in
                    let attributes = try? fileManager.attributesOfItem(atPath: url.path)
                    let date = attributes?[.creationDate] as? Date ?? Date()
                    return Recording(url: url, createdAt: date)
                }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            return []
        }
    }
    
    // 刪除錄音
    func deleteRecording(_ recording: Recording) {
        try? fileManager.removeItem(at: recording.url)
    }
    
    // MARK: - 分析結果相關
    
    // 保存分析結果
    func saveAnalysis(_ analysis: RecordingAnalysis) -> Bool {
        let filename = "analysis_\(analysis.id).json"
        let url = analysisDirectory.appendingPathComponent(filename)
        
        do {
            let data = try JSONEncoder().encode(analysis)
            try data.write(to: url)
            return true
        } catch {
            print("Failed to save analysis: \(error)")
            return false
        }
    }
    
    // 獲取所有分析結果
    func getAllAnalyses() -> [RecordingAnalysis] {
        do {
            let files = try fileManager.contentsOfDirectory(at: analysisDirectory, includingPropertiesForKeys: [.creationDateKey])
            return files
                .filter { $0.pathExtension == "json" }
                .compactMap { url in
                    try? JSONDecoder().decode(RecordingAnalysis.self, from: Data(contentsOf: url))
                }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            return []
        }
    }
    
    // 刪除分析結果
    func deleteAnalysis(_ analysis: RecordingAnalysis) {
        let filename = "analysis_\(analysis.id).json"
        let url = analysisDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }
    
    // MARK: - 統計數據
    
    // 獲取總錄音次數
    func getTotalRecordingsCount() -> Int {
        getAllRecordings().count
    }
    
    // 獲取總分析次數
    func getTotalAnalysesCount() -> Int {
        getAllAnalyses().count
    }
    
    // 計算累積準確率 (所有錄音既準確率加埋)
    func getCumulativeAccuracy() -> Double {
        let analyses = getAllAnalyses()
        guard !analyses.isEmpty else { return 0 }
        
        // 累積加曬所有錄音既 confidence
        let total = analyses.reduce(0.0) { $0 + $1.accuracy }
        
        // 如果得1-2次錄音，就直接用
        // 如果有多次錄音，可以 cap 最高100%
        return min(1.0, total)
    }
    
    // 兼容舊既 method
    func getAverageAccuracy() -> Double {
        return getCumulativeAccuracy()
    }
    
    // 獲取累積既音頻特徵平均值
    func getAverageAudioFeatures() -> AudioAnalyzer.AudioFeatures? {
        let analyses = getAllAnalyses()
        guard !analyses.isEmpty else { return nil }
        
        var totalFeatures = AudioAnalyzer.AudioFeatures()
        
        for analysis in analyses {
            totalFeatures.speechRate += analysis.audioFeatures.speechRate
            totalFeatures.averageVolume += analysis.audioFeatures.averageVolume
            totalFeatures.volumeVariation += analysis.audioFeatures.volumeVariation
            totalFeatures.pauseRatio += analysis.audioFeatures.pauseRatio
            totalFeatures.pitchVariation += analysis.audioFeatures.pitchVariation
            totalFeatures.speakingDuration += analysis.audioFeatures.speakingDuration
            totalFeatures.totalDuration += analysis.audioFeatures.totalDuration
        }
        
        let count = Double(analyses.count)
        return AudioAnalyzer.AudioFeatures(
            speechRate: totalFeatures.speechRate / count,
            averageVolume: totalFeatures.averageVolume / Float(count),
            volumeVariation: totalFeatures.volumeVariation / Float(count),
            pauseRatio: totalFeatures.pauseRatio / count,
            pitchVariation: totalFeatures.pitchVariation / Float(count),
            speakingDuration: totalFeatures.speakingDuration / count,
            totalDuration: totalFeatures.totalDuration / count,
            confidence: getAverageAccuracy()
        )
    }
}

// MARK: - 數據模型

struct Recording: Identifiable {
    let id = UUID()
    let url: URL
    let createdAt: Date
}

struct RecordingAnalysis: Codable, Identifiable {
    let id: String
    let recordingId: String
    let createdAt: Date
    let transcribedText: String
    let audioFeatures: AudioFeaturesData
    let accuracy: Double
    
    init(recordingId: String, transcribedText: String, audioFeatures: AudioAnalyzer.AudioFeatures, accuracy: Double) {
        self.id = UUID().uuidString
        self.recordingId = recordingId
        self.createdAt = Date()
        self.transcribedText = transcribedText
        self.audioFeatures = AudioFeaturesData(from: audioFeatures)
        self.accuracy = accuracy
    }
}

struct AudioFeaturesData: Codable {
    let speechRate: Double
    let averageVolume: Float
    let volumeVariation: Float
    let pauseRatio: Double
    let pitchVariation: Float
    let speakingDuration: TimeInterval
    let totalDuration: TimeInterval
    let confidence: Double
    
    init(from features: AudioAnalyzer.AudioFeatures) {
        self.speechRate = features.speechRate
        self.averageVolume = features.averageVolume
        self.volumeVariation = features.volumeVariation
        self.pauseRatio = features.pauseRatio
        self.pitchVariation = features.pitchVariation
        self.speakingDuration = features.speakingDuration
        self.totalDuration = features.totalDuration
        self.confidence = features.confidence
    }
    
    func toAudioFeatures() -> AudioAnalyzer.AudioFeatures {
        var features = AudioAnalyzer.AudioFeatures()
        features.speechRate = speechRate
        features.averageVolume = averageVolume
        features.volumeVariation = volumeVariation
        features.pauseRatio = pauseRatio
        features.pitchVariation = pitchVariation
        features.speakingDuration = speakingDuration
        features.totalDuration = totalDuration
        features.confidence = confidence
        return features
    }
}
