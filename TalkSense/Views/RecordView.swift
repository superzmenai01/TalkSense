import SwiftUI

struct RecordView: View {
    // 改用 @State 替代 @StateObject
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
            
            // 心跳動畫 (有聲音時跳動)
            HeartbeatView(audioLevel: audioLevel, isRecording: isRecording)
                .frame(width: 120, height: 120)
            
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
        // 使用 DispatchSourceTimer 替代 Timer
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 0.1)
        timer.setEventHandler { [weak self] in
            guard let self = self else {
                timer.cancel()
                return
            }
            
            if self.isRecording {
                self.recordingTime += 0.1
                // 更新 audio level
                self.audioLevel = self.audioRecorder.audioLevel
            } else {
                timer.cancel()
            }
        }
        timer.resume()
    }
}

// 心跳動畫組件
struct HeartbeatView: View {
    let audioLevel: Float
    let isRecording: Bool
    
    // 將 dB 轉換為 0-1
    private var normalizedLevel: Double {
        guard isRecording else { return 0 }
        return max(0, min(1, Double(audioLevel + 60) / 60))
    }
    
    var body: some View {
        ZStack {
            // 外圈 - 基礎圓形
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                .frame(width: 100, height: 100)
            
            // 動態圈 - 根據音量擴張
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: dynamicSize, height: dynamicSize)
            
            // 內圈 - 主圓形
            Circle()
                .fill(Color.blue.opacity(0.4))
                .frame(width: 60, height: 60)
            
            // 心跳圖標
            Image(systemName: "heart.fill")
                .font(.system(size: 30))
                .foregroundColor(.red)
                .scaleEffect(isRecording ? heartbeatScale : 1.0)
                .animation(.easeInOut(duration: heartbeatDuration), value: isRecording)
        }
    }
    
    // 根據音量計算大小
    private var dynamicSize: CGFloat {
        guard isRecording else { return 80 }
        let scale = 1 + normalizedLevel * 0.5 // 80 ~ 120
        return 80 * scale
    }
    
    // 心跳動畫 scale
    private var heartbeatScale: CGFloat {
        guard isRecording else { return 1.0 }
        return 1.0 + CGFloat(normalizedLevel) * 0.3 // 1.0 ~ 1.3
    }
    
    // 心跳動畫速度 - 聲音越大越快
    private var heartbeatDuration: Double {
        guard isRecording else { return 1.0 }
        return 1.0 - normalizedLevel * 0.5 // 1.0s ~ 0.5s
    }
}

#Preview {
    RecordView()
}
