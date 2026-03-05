import SwiftUI

struct RecordView: View {
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var audioLevel: Float = -160
    
    // 當前錄音
    @State private var currentRecording: CurrentRecording?
    @State private var isProcessing: Bool = false
    
    // 累積統計
    @State private var totalRecordings: Int = 0
    @State private var averageAccuracy: Double = 0
    @State private var totalDuration: TimeInterval = 0
    
    @Environment(\.dismiss) private var dismiss
    
    private let audioRecorder = AudioRecorder()
    private let speechToText = SpeechToText()
    private let audioAnalyzer = AudioAnalyzer()
    private let storage = StorageService.shared
    
    // 觸發分析既準確率閾值
    private let analysisThreshold: Double = 0.6
    
    var body: some View {
        VStack(spacing: 20) {
            // 標題
            Text("錄製語音")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 累積統計
            CumulativeStatsView(
                totalRecordings: totalRecordings,
                averageAccuracy: averageAccuracy,
                totalDuration: totalDuration,
                threshold: analysisThreshold
            )
            
            // 錄音時間顯示
            Text(formatTime(recordingTime))
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .foregroundColor(isRecording ? .red : .secondary)
            
            // 音頻視覺化
            AudioVisualizerView(audioLevel: audioLevel, isRecording: isRecording)
                .frame(height: 80)
                .padding(.horizontal)
            
            // 當前錄音結果
            if let recording = currentRecording {
                CurrentRecordingView(recording: recording)
            }
            
            Spacer()
            
            // 按鈕區域
            VStack(spacing: 16) {
                // 錄音/停止按鈕
                Button(action: {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
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
                
                // 分析按鈕 (當有錄音數據時顯示)
                if !isRecording && totalRecordings > 0 {
                    VStack(spacing: 12) {
                        Button(action: {
                            performAnalysis()
                        }) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                Text("開始性格分析")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(averageAccuracy >= analysisThreshold ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(averageAccuracy < analysisThreshold)
                        
                        if averageAccuracy < analysisThreshold {
                            Text("累積數據不足，等 \(Int(analysisThreshold * 100))% 再分析\n（目前：\(Int(averageAccuracy * 100))%，需要 \(totalRecordings) 次錄音）")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 40)
                }
                
                // 完成按鈕
                if totalRecordings > 0 && currentRecording == nil && !isRecording {
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
        .onAppear {
            loadCumulativeStats()
        }
    }
    
    private func startRecording() {
        audioRecorder.startRecording()
        isRecording = true
        recordingTime = 0
        currentRecording = nil
        startTimer()
    }
    
    private func stopRecording() {
        let url = audioRecorder.stopRecording()
        isRecording = false
        
        guard let audioURL = url else { return }
        
        // 保存錄音
        _ = storage.saveRecording(from: audioURL)
        
        // 處理中
        isProcessing = true
        
        // 轉文字 + 分析
        speechToText.transcribe(audioURL: audioURL)
        audioAnalyzer.analyze(audioURL: audioURL)
        
        // 延遲獲取結果
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [self] in
            let text = speechToText.transcribedText
            let features = audioAnalyzer.audioFeatures
            
            // 保存分析結果
            if let audioFeatures = features {
                let analysis = RecordingAnalysis(
                    recordingId: audioURL.lastPathComponent,
                    transcribedText: text,
                    audioFeatures: audioFeatures,
                    accuracy: audioFeatures.confidence
                )
                _ = storage.saveAnalysis(analysis)
            }
            
            // 更新當前錄音顯示
            currentRecording = CurrentRecording(
                transcribedText: text,
                audioFeatures: features
            )
            
            // 重新加載統計
            loadCumulativeStats()
            
            isProcessing = false
        }
    }
    
    private func loadCumulativeStats() {
        totalRecordings = storage.getTotalAnalysesCount()
        averageAccuracy = storage.getAverageAccuracy()
        
        // 計算總時長
        let analyses = storage.getAllAnalyses()
        totalDuration = analyses.reduce(0) { $0 + ($1.audioFeatures.totalDuration) }
    }
    
    private func performAnalysis() {
        // TODO: 用 MiniMax AI 做深入性格分析
        print("執行性格分析...")
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

// MARK: - 累積統計組件
struct CumulativeStatsView: View {
    let totalRecordings: Int
    let averageAccuracy: Double
    let totalDuration: TimeInterval
    let threshold: Double
    
    var body: some View {
        VStack(spacing: 12) {
            // 標題
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("累積數據")
                    .font(.headline)
                Spacer()
                if averageAccuracy >= threshold {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            // 統計數字
            HStack(spacing: 20) {
                StatItem(title: "錄音次數", value: "\(totalRecordings)", icon: "mic.fill", color: .blue)
                StatItem(title: "平均準確率", value: "\(Int(averageAccuracy * 100))%", icon: "percent", color: averageAccuracy >= threshold ? .green : .orange)
                StatItem(title: "總時長", value: "\(Int(totalDuration))秒", icon: "clock.fill", color: .purple)
            }
            
            // 進度條
            VStack(spacing: 4) {
                ProgressView(value: min(averageAccuracy, 1.0))
                    .tint(averageAccuracy >= threshold ? .green : .orange)
                
                HStack {
                    Text("0%")
                        .font(.caption2)
                    Spacer()
                    Text("\(Int(threshold * 100))% (目標)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("100%")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 當前錄音結果
struct CurrentRecordingView: View {
    let recording: CurrentRecording
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最新錄音結果")
                    .font(.headline)
                Spacer()
                if let features = recording.audioFeatures {
                    Text("\(Int(features.confidence * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            
            if !recording.transcribedText.isEmpty {
                Text(recording.transcribedText)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundColor(.secondary)
            }
            
            if let features = recording.audioFeatures {
                HStack(spacing: 16) {
                    Label("\(Int(features.speechRate)) WPM", systemImage: "waveform")
                    Label(features.pauseRatio > 0.2 ? "多停頓" : "流暢", systemImage: features.pauseRatio > 0.2 ? "pause.circle" : "play.circle")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct CurrentRecording {
    let transcribedText: String
    let audioFeatures: AudioAnalyzer.AudioFeatures?
}

// MARK: - 音頻視覺化
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
        if ratio < 0.4 { return .green }
        else if ratio < 0.7 { return .yellow }
        else { return .red }
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
