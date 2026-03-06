import SwiftUI

struct RecordView: View {
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var audioLevel: Float = -160
    
    // 問題相關
    @State private var currentQuestion: Question?
    @State private var currentFollowUpQuestion: String?
    @State private var questionAnswers: [String] = [] // 所有回答
    @State private var followUpCount: Int = 0 // 追問次數
    @State private var showNextQuestionPrompt: Bool = false
    
    // AI 處理中
    @State private var isAIThinking: Bool = false
    
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
    private let aiQuestionService = AIQuestionService.shared
    
    // 觸發分析既準 inúmer閾值
    private let analysisThreshold: Double = 0.6
    
    var body: some View {
        NavigationStack {
            ScrollView {
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
                        .frame(height: 60)
                        .padding(.horizontal)
                    
                    // 問題顯示區域
                    QuestionDisplayArea(
                        mainQuestion: currentQuestion,
                        followUpQuestion: currentFollowUpQuestion,
                        questionAnswers: questionAnswers,
                        isRecording: isRecording,
                        isAIThinking: isAIThinking,
                        showNextPrompt: showNextQuestionPrompt
                    )
                    
                    // AI 思考緊既顯示
                    if isAIThinking {
                        AIThinkingView()
                    }
                    
                    // 處理中既 Loading 顯示
                    if isProcessing && !isAIThinking {
                        ProcessingView()
                    }
                    
                    // 按鈕區域
                    VStack(spacing: 16) {
                        // 錄音/停止按鈕
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
                                        .fill(isRecording ? Color.red : (isAIThinking ? Color.gray : Color.blue))
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
                            .disabled(isProcessing || isAIThinking)
                            
                            Text(buttonLabel)
                                .font(.headline)
                                .foregroundColor(isRecording ? .red : .blue)
                        }
                        
                        // AI 建議去下一題既提示
                        if showNextQuestionPrompt && !isRecording && !isProcessing && !isAIThinking {
                            VStack(spacing: 12) {
                                Text("AI認為已經收集夠資料可以去下一題喇！")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: {
                                    goToNextQuestion()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.right.circle.fill")
                                        Text("去下一題")
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
                        }
                        
                        // 正常既分析按鈕
                        if !isRecording && !isProcessing && !isAIThinking && totalRecordings > 0 && !showNextQuestionPrompt {
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
                                    Text("累積數據不足，等 \(Int(analysisThreshold * 100))% 再分析")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                        
                        // 完成按鈕
                        if !isRecording && !isProcessing && !isAIThinking && totalRecordings > 0 && currentRecording == nil && !showNextQuestionPrompt {
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
                }
                .padding(.vertical)
            }
            .navigationTitle("錄製語音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if totalRecordings > 0 && !isProcessing && !isAIThinking {
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
    
    private var buttonLabel: String {
        if isRecording {
            return "停止"
        } else if isAIThinking {
            return "AI思考中..."
        } else if currentFollowUpQuestion != nil {
            return "回答"
        } else {
            return "開始"
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
        
        // 開始處理
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
            
            // 添加到回答歷史
            questionAnswers.append(text)
            
            // 更新當前錄音顯示
            currentRecording = CurrentRecording(
                transcribedText: text,
                audioFeatures: features
            )
            
            // 重新加載統計
            loadCumulativeStats()
            
            // 完成處理
            isProcessing = false
            
            // AI 生成跟進問題
            if let question = currentQuestion {
                askAIForFollowUp(question: question.question, answer: text)
            }
        }
    }
    
    private func askAIForFollowUp(question: String, answer: String) {
        isAIThinking = true
        
        aiQuestionService.generateFollowUpQuestion(
            originalQuestion: question,
            previousAnswer: answer,
            category: currentQuestion?.category ?? .situational,
            questionCount: followUpCount
        ) { [self] result in
            isAIThinking = false
            
            switch result {
            case .success(let followUp):
                if followUp.shouldMoveNext {
                    // AI 話可以去下一題
                    showNextQuestionPrompt = true
                } else if !followUp.question.isEmpty {
                    // AI 生成咗跟進問題
                    currentFollowUpQuestion = followUp.question
                    followUpCount += 1
                } else {
                    // 冇問題，去下一題
                    showNextQuestionPrompt = true
                }
                
            case .failure:
                // 出錯，去下一題
                showNextQuestionPrompt = true
            }
        }
    }
    
    private func goToNextQuestion() {
        // 保存呢個問題既所有回答
        let allAnswers = questionAnswers.joined(separator: "；")
        
        // 搵下一條新問題
        currentQuestion = questionService.getRandomQuestion()
        
        // 重置狀態
        currentFollowUpQuestion = nil
        questionAnswers = []
        followUpCount = 0
        showNextQuestionPrompt = false
        currentRecording = nil
    }
    
    private func loadCumulativeStats() {
        totalRecordings = storage.getTotalAnalysesCount()
        averageAccuracy = storage.getAverageAccuracy()
        
        let analyses = storage.getAllAnalyses()
        totalDuration = analyses.reduce(0) { $0 + ($1.audioFeatures.totalDuration) }
    }
    
    private func resetAllData() {
        let recordings = storage.getAllRecordings()
        for recording in recordings {
            storage.deleteRecording(recording)
        }
        
        let analyses = storage.getAllAnalyses()
        for analysis in analyses {
            storage.deleteAnalysis(analysis)
        }
        
        currentRecording = nil
        currentQuestion = questionService.getRandomQuestion()
        currentFollowUpQuestion = nil
        questionAnswers = []
        followUpCount = 0
        showNextQuestionPrompt = false
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

// MARK: - 問題顯示區域
struct QuestionDisplayArea: View {
    let mainQuestion: Question?
    let followUpQuestion: String?
    let questionAnswers: [String]
    let isRecording: Bool
    let isAIThinking: Bool
    let showNextPrompt: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // 主要問題
            if let q = mainQuestion {
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
                    }
                    
                    Text(q.question)
                        .font(.headline)
                    
                    Text(q.category.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            
            // 跟進問題
            if let followUp = followUpQuestion {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("跟進問題")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .cornerRadius(4)
                        
                        Spacer()
                    }
                    
                    Text(followUp)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            
            // 回答歷史
            if !questionAnswers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已回答 (\(questionAnswers.count)次)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(0..<questionAnswers.count, id: \.self) { index in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(questionAnswers[index])
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - AI 思考顯示
struct AIThinkingView: View {
    @State private var dots: String = ""
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                
                Text("AI 分析緊\(dots)")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text("緊係度諗跟進問題...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
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
        .padding(20)
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

// MARK: - CurrentRecording
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
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 10, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.05), value: barHeight(for: index))
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        guard isRecording else { return 4 }
        
        let centerIndex = totalBars / 2
        let distanceFromCenter = abs(index - centerIndex)
        let centerFactor = 1.0 - (Double(distanceFromCenter) / Double(centerIndex)) * 0.5
        let randomFactor = Double.random(in: 0.7...1.3)
        
        let level = normalizedLevel * centerFactor * randomFactor
        return max(4, CGFloat(level) * 60)
    }
    
    private func barColor(for index: Int) -> Color {
        let ratio = Double(index) / Double(totalBars)
        if ratio < 0.4 { return .green }
        else if ratio < 0.7 { return .yellow }
        else { return .red }
    }
}

#Preview {
    RecordView()
}
