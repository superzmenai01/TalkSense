import SwiftUI

struct RecordView: View {
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var audioLevel: Float = -160
    
    // 問題相關
    @State private var currentQuestion: Question?
    @State private var questionHistory: [QuestionAnswer] = []
    @State private var showNextQuestion: Bool = false
    
    // 當前錄音
    @State private var currentRecording: CurrentRecording?
    @State private var isProcessing: Bool = false
    
    // 累積統計
    @State private var totalRecordings: Int = 0
    @State private var averageAccuracy: Double = 0
    @State private var totalDuration: TimeInterval = 0
    
    // 確認對話框
    @State private var showResetConfirmation: Bool = false
    @State private var showResetSuccess: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    private let audioRecorder = AudioRecorder()
    private let speechToText = SpeechToText()
    private let audioAnalyzer = AudioAnalyzer()
    private let storage = StorageService.shared
    private let questionService = QuestionService.shared
    
    // 觸發分析既準確率閾值
    private let analysisThreshold: Double = 0.6
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
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
                
                // 問題顯示區域
                QuestionDisplayView(
                    question: currentQuestion,
                    questionHistory: questionHistory,
                    isRecording: isRecording,
                    showNextQuestion: showNextQuestion,
                    onStartRecording: {
                        showNextQuestion = false
                    }
                )
                
                // 處理中既 Loading 顯示
                if isProcessing {
                    ProcessingView()
                }
                
                // 當前錄音結果
                if let recording = currentRecording {
                    CurrentRecordingView(recording: recording)
                }
                
                Spacer()
                
                // 按鈕區域
                VStack(spacing: 16) {
                    // 錄音/停止按鈕 + 標籤
                    VStack(spacing: 8) {
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
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .shadow(radius: 5)
                        .disabled(isProcessing)
                        
                        // 錄音按鈕既標籤
                        Text(isRecording ? "停止" : "開始")
                            .font(.headline)
                            .foregroundColor(isRecording ? .red : .blue)
                    }
                    
                    // 問題導航按鈕
                    if !isRecording && !isProcessing && currentQuestion != nil && currentRecording != nil {
                        Button(action: {
                            showNextQuestion = true
                            currentQuestion = questionService.getRandomQuestion()
                            currentRecording = nil
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("下一題")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    // 分析按鈕 (當有錄音數據時顯示)
                    if !isRecording && !isProcessing && totalRecordings > 0 {
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
                                Text("累積數據不足，等 \(Int(analysisThreshold * 100))% 再分析\n（目前：\(Int(averageAccuracy * 100))%，需要更多錄音）")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    // 完成按鈕
                    if !isRecording && !isProcessing && totalRecordings > 0 && currentRecording == nil {
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
            .padding(.top, 20)
            .navigationTitle("錄製語音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if totalRecordings > 0 && !isProcessing {
                        Button(action: {
                            showResetConfirmation = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("重新開始")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .onAppear {
                loadCumulativeStats()
                if currentQuestion == nil {
                    currentQuestion = questionService.getRandomQuestion()
                }
            }
            .alert("重新開始？", isPresented: $showResetConfirmation) {
                Button("取消", role: .cancel) { }
                Button("確認清除", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("呢個操作會清除曬所有錄音同分析記錄，唔可以復原。你確定要繼續？")
            }
            .alert("已清除", isPresented: $showResetSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("所有數據已經清除，你可以重新開始錄音喇！")
            }
        }
    }
    
    private func startRecording() {
        audioRecorder.startRecording()
        isRecording = true
        recordingTime = 0
        startTimer()
    }
    
    private func stopRecording() {
        let url = audioRecorder.stopRecording()
        isRecording = false
        
        guard let audioURL = url else { return }
        
        // 保存錄音
        _ = storage.saveRecording(from: audioURL)
        
        // 開始處理，顯示 loading
        isProcessing = true
        
        // 轉文字 + 分析
        speechToText.transcribe(audioURL: audioURL)
        audioAnalyzer.analyze(audioURL: audioURL)
        
        // 延遲獲取結果 (2.5秒)
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
                
                // 添加到問題歷史
                if let question = currentQuestion {
                    let qa = QuestionAnswer(
                        question: question.question,
                        answer: text,
                        audioFeatures: audioFeatures
                    )
                    questionHistory.append(qa)
                }
            }
            
            // 更新當前錄音顯示
            currentRecording = CurrentRecording(
                transcribedText: text,
                audioFeatures: features
            )
            
            // 重新加載統計
            loadCumulativeStats()
            
            // 完成處理
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
    
    private func resetAllData() {
        // 清除所有錄音
        let recordings = storage.getAllRecordings()
        for recording in recordings {
            storage.deleteRecording(recording)
        }
        
        // 清除所有分析
        let analyses = storage.getAllAnalyses()
        for analysis in analyses {
            storage.deleteAnalysis(analysis)
        }
        
        // 重置狀態
        currentRecording = nil
        currentQuestion = questionService.getRandomQuestion()
        questionHistory = []
        totalRecordings = 0
        averageAccuracy = 0
        totalDuration = 0
        
        showResetSuccess = true
    }
    
    private func performAnalysis() {
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

// MARK: - 問題顯示組件
struct QuestionDisplayView: View {
    let question: Question?
    let questionHistory: [QuestionAnswer]
    let isRecording: Bool
    let showNextQuestion: Bool
    let onStartRecording: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // 顯示當前問題
            if let q = question {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("問題")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(q.category.color)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        if isRecording {
                            Text("錄音中...")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text(q.question)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(q.category.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // 問題歷史
            if !questionHistory.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<questionHistory.count, id: \.self) { index in
                            VStack {
                                Text("Q\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Circle()
                                    .fill(index == questionHistory.count - 1 ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                            }
                            .padding(8)
                            .background(index == questionHistory.count - 1 ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - QuestionAnswer 數據模型
struct QuestionAnswer: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let audioFeatures: AudioAnalyzer.AudioFeatures?
}

// MARK: - Category Extension
extension QuestionCategory {
    var color: Color {
        switch self {
        case .situational: return .blue
        case .values: return .purple
        case .emotional: return .orange
        case .relationship: return .green
        case .decision: return .pink
        }
    }
}

// MARK: - 處理中顯示
struct ProcessingView: View {
    @State private var dots: String = ""
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
                Text("處理中\(dots)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Text("正在轉換文字同分析音頻...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                if dots.count >= 3 {
                    dots = ""
                } else {
                    dots += "."
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
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
            
            HStack(spacing: 20) {
                StatItem(title: "問題數", value: "\(totalRecordings)", icon: "questionmark.circle.fill", color: .blue)
                StatItem(title: "平均準確率", value: "\(Int(averageAccuracy * 100))%", icon: "percent", color: averageAccuracy >= threshold ? .green : .orange)
                StatItem(title: "總時長", value: "\(Int(totalDuration))秒", icon: "clock.fill", color: .purple)
            }
            
            ProgressView(value: min(averageAccuracy, 1.0))
                .tint(averageAccuracy >= threshold ? .green : .orange)
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
                Text("回答內容")
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
