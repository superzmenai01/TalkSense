import SwiftUI

struct RecordView: View {
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var showSaveAlert = false
    @State private var audioLevel: Float = -160
    
    @Environment(\.dismiss) private var dismiss
    
    private let audioRecorder = AudioRecorder()
    
    var body: some View {
        VStack(spacing: 30) {
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
                .frame(height: 100)
                .padding(.horizontal)
            
            // 狀態文字
            Text(statusText)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // 錄音按鈕
            Button(action: {
                if isRecording {
                    // 停止錄音
                    _ = audioRecorder.stopRecording()
                    isRecording = false
                    showSaveAlert = true
                } else {
                    // 開始錄音
                    audioRecorder.startRecording()
                    isRecording = true
                    recordingTime = 0
                    
                    // 啟動定時器
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
            
            Spacer()
        }
        .padding()
        .alert("錄音完成", isPresented: $showSaveAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("錄音已保存！")
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
    
    // 將 dB (-160 ~ 0) 轉換為 0 ~ 1
    private var normalizedLevel: Double {
        guard isRecording else { return 0 }
        return max(0, min(1, Double(audioLevel + 60) / 60))
    }
    
    // 20 條 bar
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
    
    // 每條 bar 既高度
    private var barHeight: CGFloat {
        guard isRecording else { return 4 }
        
        // 模擬不同頻率既響應 - 中間既 bar 高啲
        let centerIndex = totalBars / 2
        let distanceFromCenter = abs(index - centerIndex)
        let centerFactor = 1.0 - (Double(distanceFromCenter) / Double(centerIndex)) * 0.5
        
        // 加入隨機性模擬音樂既跳動
        let randomFactor = Double.random(in: 0.7...1.3)
        
        let level = normalizedLevel * centerFactor * randomFactor
        return max(4, CGFloat(level) * 100)
    }
    
    // Bar 既顏色 - 低音到高音 (綠->黃->紅)
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
            .frame(width: 12, height: barHeight)
            .animation(.easeInOut(duration: 0.05), value: barHeight)
    }
}

#Preview {
    RecordView()
}
