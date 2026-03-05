import SwiftUI

struct RecordView: View {
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var showSaveAlert = false
    @State private var audioLevel: Float = -160
    
    // 語音轉文字相關
    @State private var transcribedText: String = ""
    @State private var isTranscribing: Bool = false
    
    // 音頻特徵分析
    @State private var audioFeatures: AudioAnalyzer.AudioFeatures?
    @State private var isAnalyzing: Bool = false
    
    // 顯示結果
    @State private var showResults: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    private let audioRecorder = AudioRecorder()
    private let speechToText = SpeechToText()
    private let audioAnalyzer = AudioAnalyzer()
    
    var body: some View {
        VStack(spacing: 20) {
            // 標題
            Text("錄製語音")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 錄音時間顯示
            Text(formatTime(recordingTime))
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .foregroundColor(isRecording ? .red : .secondary)
            
            // 音頻視覺化 (Bar Chart)
            AudioVisualizerView(audioLevel: audioLevel, isRecording: isRecording)
                .frame(height: 80)
                .padding(.horizontal)
            
            // 狀態文字
            HStack(spacing: 12) {
                if isTranscribing {
                    ProgressView()
                    Text("轉換文字中...")
                        .foregroundColor(.secondary)
                } else if isAnalyzing {
                    ProgressView()
                    Text("分析語音特徵中...")
                        .foregroundColor(.secondary)
                } else {
                    Text(statusText)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            
            // 結果顯示區域
            if showResults {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 轉文字結果
                        if !transcribedText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("📝 轉換文字：")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(transcribedText)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        
                        // 音頻特徵結果
                        if let features = audioFeatures {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("📊 語音特徵分析：")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                AudioFeaturesView(features: features)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 300)
            }
            
            Spacer()
            
            // 按鈕區域
            VStack(spacing: 16) {
                // 錄音/停止按鈕
                Button(action: {
                    if isRecording {
                        // 停止錄音
                        let url = audioRecorder.stopRecording()
                        isRecording = false
                        showResults = false
                        
                        // 開始轉文字同分析
                        if let audioURL = url {
                            isTranscribing = true
                            isAnalyzing = true
                            
                            // 轉文字
                            speechToText.transcribe(audioURL: audioURL)
                            
                            // 分析音頻特徵
                            audioAnalyzer.analyze(audioURL: audioURL)
                            
                            // 延遲獲取結果
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [self] in
                                isTranscribing = false
                                isAnalyzing = false
                                transcribedText = speechToText.transcribedText
                                audioFeatures = audioAnalyzer.audioFeatures
                                showResults = true
                            }
                        }
                    } else {
                        // 開始錄音
                        audioRecorder.startRecording()
                        isRecording = true
                        recordingTime = 0
                        transcribedText = ""
                        audioFeatures = nil
                        showResults = false
                        startTimer()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.blue)
                            .frame(width: 80, height: 80)
                        
                        if isRecording {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                .shadow(radius: 5)
                
                // 完成後既返回按鈕
                if showResults {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("完成")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var statusText: String {
        if isRecording {
            return "錄音中... 請說話"
        } else if recordingTime > 0 {
            return "錄音完成"
        } else {
            return "點擊下方按鈕開始錄音"
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
    
    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 0.05)
        timer.setEventHandler { [self] in
            if self.isRecording {
                self.recordingTime += 0.05
                self.audioLevel = self.audioRecorder.audioLevel
            } else {
                timer.cancel()
            }
        }
        timer.resume()
    }
}

// 音頻特徵顯示組件
struct AudioFeaturesView: View {
    let features: AudioAnalyzer.AudioFeatures
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 準確率
            HStack {
                Text("準確率：")
                    .font(.subheadline)
                ProgressView(value: features.confidence)
                    .tint(confidenceColor)
                Text("\(Int(features.confidence * 100))%")
                    .font(.subheadline)
                    .foregroundColor(confidenceColor)
            }
            
            // 特徵列表
            HStack(spacing: 16) {
                FeatureBadge(title: "語速", value: speedText, color: .blue)
                FeatureBadge(title: "停頓", value: pauseText, color: .green)
                FeatureBadge(title: "音量", value: volumeText, color: .orange)
            }
            
            // 詳細解釋
            Text(getDetailedDescription())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var speedText: String {
        if features.speechRate < 100 { return "慢" }
        else if features.speechRate < 180 { return "正常" }
        else { return "快" }
    }
    
    private var pauseText: String {
        if features.pauseRatio > 0.4 { return "多" }
        else if features.pauseRatio > 0.2 { return "適中" }
        else { return "少" }
    }
    
    private var volumeText: String {
        if features.volumeVariation > 0.5 { return "大" }
        else if features.volumeVariation > 0.2 { return "適中" }
        else { return "穩" }
    }
    
    private var confidenceColor: Color {
        if features.confidence > 0.7 { return .green }
        else if features.confidence > 0.4 { return .yellow }
        else { return .red }
    }
    
    private func getDetailedDescription() -> String {
        var desc = ""
        
        // 語速描述
        if features.speechRate < 100 {
            desc += "語速較慢，可能係思考緊或者謹慎表達。"
        } else if features.speechRate < 180 {
            desc += "語速適中，表达自然流暢。"
        } else {
            desc += "語速較快，可能情緒激動或急性子。"
        }
        
        // 停頓描述
        if features.pauseRatio > 0.4 {
            desc += "\n停頓較多，可能係思考中或謹慎表達。"
        } else if features.pauseRatio > 0.2 {
            desc += "\n停頓適中。"
        } else {
            desc += "\n停頓較少，表達流暢自信。"
        }
        
        return desc
    }
}

struct FeatureBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// 音頻視覺化 Bar Chart
struct AudioVisualizerView: View {
    let audioLevel: Float
    let isRecording: Bool
    
    private var normalizedLevel: Double {
        guard isRecording else { return 0 }
        return max(0, min(1, Double(audioLevel + 60) / 60))
    }
    
    private let barCount = 20
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                AudioBar(
                    index: index,
                    totalBars: barCount,
                    normalizedLevel: normalizedLevel,
                    isRecording: isRecording
                )
            }
        }
    }
}

struct AudioBar: View {
    let index: Int
    let totalBars: Int
    let normalizedLevel: Double
    let isRecording: Bool
    
    private var barHeight: CGFloat {
        guard isRecording else { return 4 }
        
        let centerIndex = totalBars / 2
        let distanceFromCenter = abs(index - centerIndex)
        let centerFactor = 1.0 - (Double(distanceFromCenter) / Double(centerIndex)) * 0.5
        
        let randomFactor = Double.random(in: 0.7...1.3)
        
        let level = normalizedLevel * centerFactor * randomFactor
        return max(4, CGFloat(level) * 80)
    }
    
    private var barColor: Color {
        let ratio = Double(index) / Double(totalBars)
        if ratio < 0.4 {
            return .green
        } else if ratio < 0.7 {
            return .yellow
        } else {
            return .red
        }
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(barColor)
            .frame(width: 10, height: barHeight)
            .animation(.easeInOut(duration: 0.05), value: barHeight)
    }
}

#Preview {
    RecordView()
}
