import SwiftUI

struct RecordView: View {
    // 改用 @State 替代 @StateObject
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var showSaveAlert = false
    
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
        timer.setEventHandler { [self] in
            recordingTime += 0.1
            if !isRecording {
                timer.cancel()
            }
        }
        timer.resume()
    }
}

#Preview {
    RecordView()
}
