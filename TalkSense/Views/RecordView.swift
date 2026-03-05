import SwiftUI

struct RecordView: View {
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var showSaveAlert = false
    @State private var audioLevel: Float = -160
    
    // 語音轉文字相關
    @State private var transcribedText: String = ""
    @State private var isTranscribing: Bool = false
    @State private var showTranscriptionResult: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    private let audioRecorder = AudioRecorder()
    private let speechToText = SpeechToText()
    
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
            
            // 轉文字結果 (如果有)
            if !transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("轉換文字：")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        Text(transcribedText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 150)
                }
                .padding(.horizontal)
            }
            
            // 狀態文字
            if isTranscribing {
                HStack {
                    ProgressView()
                    Text("正在轉換文字...")
                        .foregroundColor(.secondary)
                }
            } else {
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(.secondary)
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
                        
                        // 自動開始轉文字
                        if let audioURL = url {
                            isTranscribing = true
                            speechToText.transcribe(audioURL: audioURL)
                            
                            // 模擬延遲獲取結果 (因為識別是異步的)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isTranscribing = false
                                transcribedText = speechToText.transcribedText
                                if !transcribedText.isEmpty {
                                    showSaveAlert = true
                                }
                            }
                        }
                    } else {
                        // 開始錄音
                        audioRecorder.startRecording()
                        isRecording = true
                        recordingTime = 0
                        transcribedText = "" // 清空之前既結果
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
                
                // 錄音完成後既提示
                if !isRecording && recordingTime > 0 && transcribedText.isEmpty && !isTranscribing {
                    Button("轉換為文字") {
                        let recordings = audioRecorder.getAllRecordings()
                        if let latestRecording = recordings.first {
                            isTranscribing = true
                            speechToText.transcribe(audioURL: latestRecording)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isTranscribing = false
                                transcribedText = speechToText.transcribedText
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Spacer()
        }
        .padding()
        .alert("錄音完成", isPresented: $showSaveAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            if !transcribedText.isEmpty {
                Text("錄音已保存！文字已轉換。")
            } else {
                Text("錄音已保存！")
            }
        }
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
