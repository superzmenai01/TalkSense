import SwiftUI

struct RecordView: View {
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var audioLevel: Float = -160
    
    // 錄音會話
    @State private var currentSessionRecordings: [SessionRecording] = []
    @State private var sessionAccuracy: Double = 0
    
    // 分析狀態
    @State private var isTranscribing: Bool = false
    @State private var isAnalyzing: Bool = false
    @State private var showAnalysisResult: Bool = false
    
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
                    Text("處理中...")
                        .foregroundColor(.secondary)
                } else {
                    Text(statusText)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            
            // 錄音會話統計
            if !currentSessionRecordings.isEmpty {
                SessionStatsView(recordings: currentSessionRecordings, accuracy: sessionAccuracy)
            }
            
            // 結果顯示
            if showAnalysisResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(currentSessionRecordings) { recording in
                            RecordingResultCard(recording: recording)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 250)
            }
            
            Spacer()
            
            // 按鈕區域
            VStack(spacing: 16) {
                // 錄音/停止按鈕
                Button(action: {
                    if isRecording {
                        // 停止錄音
                        handleStopRecording()
                    } else {
                        // 開始錄音
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
                
                // 繼續錄音 / 開始分析 按鈕
                if !isRecording && !currentSessionRecordings.isEmpty && !showAnalysisResult {
                    VStack(spacing: 12) {
                        // 繼續錄音按鈕
                        Button(action: {
                            startRecording()
                        }) {
                            HStack {
                                Image(systemName: "mic.fill")
                                Text("繼續錄音")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        // 開始分析按鈕 (需要達到閾值)
                        Button(action: {
                            performAnalysis()
                        }) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                Text("開始分析")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(sessionAccuracy >= analysisThreshold ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(sessionAccuracy < analysisThreshold)
                        
                        // 提示文字
                        if sessionAccuracy < analysisThreshold {
                            Text("錄多幾次，等準確率達到 \(Int(analysisThreshold * 100))% 先好分析")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 40)
                }
                
                // 完成按鈕
                if showAnalysisResult {
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
    
    private func startRecording() {
        audioRecorder.startRecording()
        isRecording = true
        recordingTime = 0
        startTimer()
    }
    
    private func handleStopRecording() {
        let url = audioRecorder.stopRecording()
        isRecording = false
        
        guard let audioURL = url else { return }
        
        // 保存錄音
        _ = storage.saveRecording(from: audioURL)
        
        // 開始處理
        isTranscribing = true
        
        // 轉文字
        speechToText.transcribe(audioURL: audioURL)
        
        // 分析音頻
        audioAnalyzer.analyze(audioURL: audioURL)
        
        // 延遲獲取結果
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [self] in
            let text = speechToText.transcribedText
            let features = audioAnalyzer.audioFeatures
            
            // 添加到會話
            let recording = SessionRecording(
                audioURL: audioURL,
                transcribedText: text,
                audioFeatures: features
            )
            currentSessionRecordings.append(recording)
            
            // 更新準確率
            updateSessionAccuracy()
            
            isTranscribing = false
        }
    }
    
    private func updateSessionAccuracy() {
        // 計算會話既總準確率
        guard !currentSessionRecordings.isEmpty else {
            sessionAccuracy = 0
            return
        }
        
        let totalAccuracy = currentSessionRecordings.reduce(0.0) { $0 + ($1.audioFeatures?.confidence ?? 0) }
        sessionAccuracy = min(1.0, totalAccuracy / Double(currentSessionRecordings.count) * 1.5)
    }
    
    private func performAnalysis() {
        // 呢度可以加入 MiniMax AI 分析
        showAnalysisResult = true
    }
    
    private var statusText: String {
        if isRecording {
            return "錄音中... 請說話"
        } else if currentSessionRecordings.isEmpty {
            return "點擊開始錄音"
        } else {
            return "已錄 \(currentSessionRecordings.count) 次，準確率 \(Int(sessionAccuracy * 100))%"
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

// MARK: - 會話錄音數據
struct SessionRecording: Identifiable {
    let id = UUID()
    let audioURL: URL
    let transcribedText: String
    let audioFeatures: AudioAnalyzer.AudioFeatures?
    let createdAt: Date = Date()
}

// MARK: - 會話統計顯示
struct SessionStatsView: View {
    let recordings: [SessionRecording]
    let accuracy: Double
    
    private let threshold: Double = 0.6
    
    var body: some View {
        VStack(spacing: 12) {
            // 錄音次數
            HStack {
                Text("錄音次數：")
                    .font(.headline)
                Text("\(recordings.count) 次")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            // 準確率進度條
            VStack(spacing: 4) {
                HStack {
                    Text("準確率：")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(accuracy * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(accuracy >= threshold ? .green : .orange)
                }
                
                ProgressView(value: min(accuracy, 1.0))
                    .tint(accuracy >= threshold ? .green : .orange)
                
                // 目標線
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 2)
                        .position(x: geometry.size.width * threshold, y: geometry.size.height / 2)
                }
                .frame(height: 2)
            }
            
            // 總時長
            let totalDuration = recordings.reduce(0.0) { $0 + ($1.audioFeatures?.totalDuration ?? 0) }
            Text("總錄音時長：\(Int(totalDuration)) 秒")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - 單個錄音結果卡片
struct RecordingResultCard: View {
    let recording: SessionRecording
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("錄音 #\(recording.id.uuidString.prefix(8))")
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
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - 音頻視覺化 (同上)
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
