import Foundation
import AVFoundation
import Accelerate

class AudioAnalyzer: ObservableObject {
    @Published var isAnalyzing: Bool = false
    @Published var audioFeatures: AudioFeatures?
    @Published var errorMessage: String?
    
    struct AudioFeatures {
        var speechRate: Double = 0 // 每分鐘字數
        var averageVolume: Float = 0 // 平均音量
        var volumeVariation: Float = 0 // 音量變化幅度
        var pauseRatio: Double = 0 // 停頓比例
        var pitchVariation: Float = 0 // 音調變化
        var speakingDuration: TimeInterval = 0 // 說話總時長
        var totalDuration: TimeInterval = 0 // 錄音總時長
        var confidence: Double = 0 // 數據充足程度 (0-1)
    }
    
    // 分析音頻文件
    func analyze(audioURL: URL) {
        isAnalyzing = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let features = try self.extractFeatures(from: audioURL)
                
                DispatchQueue.main.async {
                    self.audioFeatures = features
                    self.isAnalyzing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    private func extractFeatures(from url: URL) throws -> AudioFeatures {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = UInt32(file.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create buffer"])
        }
        
        try file.read(into: buffer)
        
        guard let floatData = buffer.floatChannelData?[0] else {
            throw NSError(domain: "AudioAnalyzer", code: 2, userInfo: [NSLocalizedDescriptionKey: "No audio data"])
        }
        
        let sampleRate = Float(format.sampleRate)
        let totalSamples = Int(buffer.frameLength)
        let totalDuration = Double(totalSamples) / Double(sampleRate)
        
        var features = AudioFeatures()
        features.totalDuration = totalDuration
        
        // 1. 計算平均音量同變化
        var sum: Float = 0
        var maxVolume: Float = -Float.infinity
        var minVolume: Float = Float.infinity
        var samplesAboveThreshold: Float = 0
        let threshold: Float = 0.01
        
        for i in 0..<totalSamples {
            let sample = abs(floatData[i])
            sum += sample
            
            if sample > maxVolume { maxVolume = sample }
            if sample < minVolume { minVolume = sample }
            if sample > threshold { samplesAboveThreshold += 1 }
        }
        
        let avgVolume = sum / Float(totalSamples)
        features.averageVolume = avgVolume
        features.volumeVariation = maxVolume - minVolume
        
        // 2. 計算說話時長 (有聲音既部分)
        let speakingDuration = Double(samplesAboveThreshold) / Double(sampleRate)
        features.speakingDuration = speakingDuration
        
        // 3. 計算停頓比例
        features.pauseRatio = max(0, 1 - (speakingDuration / totalDuration))
        
        // 4. 計算語速 (估算)
        // 假設平均每個詞 0.4秒 (基於中文/廣東話)
        let estimatedWordCount = speakingDuration / 0.4
        features.speechRate = (estimatedWordCount / totalDuration) * 60 // 每分鐘字數
        
        // 5. 計算音調變化 (使用 zero-crossing rate 近似)
        var zeroCrossings: Int = 0
        for i in 1..<totalSamples {
            if (floatData[i] >= 0 && floatData[i-1] < 0) || (floatData[i] < 0 && floatData[i-1] >= 0) {
                zeroCrossings += 1
            }
        }
        
        let zeroCrossingRate = Float(zeroCrossings) / Float(totalSamples)
        features.pitchVariation = zeroCrossingRate
        
        // 6. 計算準確率 (基於數據量)
        // 錄音越長、說話越多，信心越高
        let durationScore = min(1.0, totalDuration / 60.0) // 最少1分鐘
        let speakingScore = min(1.0, speakingDuration / 30.0) // 最少30秒說話
        let volumeScore = avgVolume > 0.001 ? 1.0 : 0.0 // 有聲音
        
        features.confidence = (durationScore * 0.3 + speakingScore * 0.5 + volumeScore * 0.2)
        
        return features
    }
    
    // 生成描述文字
    func getFeaturesDescription(_ features: AudioFeatures) -> String {
        var description = """
        📊 語音特徵分析：
        
        """
        
        // 語速
        if features.speechRate < 100 {
            description += "• 語速：慢 (悠閒、謹慎)\n"
        } else if features.speechRate < 180 {
            description += "• 語速：正常\n"
        } else {
            description += "• 語速：快 (急促、激動)\n"
        }
        
        // 停頓
        if features.pauseRatio > 0.4 {
            description += "• 停頓：多 (思考中、謹慎)\n"
        } else if features.pauseRatio > 0.2 {
            description += "• 停頓：適中\n"
        } else {
            description += "• 停頓：少 (流暢、自信)\n"
        }
        
        // 音量變化
        if features.volumeVariation > 0.5 {
            description += "• 音量變化：大 (情緒起伏)\n"
        } else if features.volumeVariation > 0.2 {
            description += "• 音量變化：適中\n"
        } else {
            description += "• 音量變化：穩定 (平靜)\n"
        }
        
        // 音調變化
        if features.pitchVariation > 0.1 {
            description += "• 音調變化：豐富 (生動)\n"
        } else {
            description += "• 音調變化：平穩\n"
        }
        
        // 準確率
        let confidencePercent = Int(features.confidence * 100)
        description += "• 數據準確率：\(confidencePercent)%"
        
        return description
    }
}
