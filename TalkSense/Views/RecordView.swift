import SwiftUI

struct RecordView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showSaveAlert = false
    @State private var savedRecordingURL: URL?
    
    var body: some View {
        VStack(spacing: 30) {
            // 標題
            Text("錄製語音")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 錄音時間顯示
            Text(formatTime(audioRecorder.recordingTime))
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .foregroundColor(audioRecorder.isRecording ? .red : .secondary)
            
            // 音頻level indicator
            AudioLevelView(level: audioRecorder.audioLevel, isRecording: audioRecorder.isRecording)
                .frame(height: 20)
                .padding(.horizontal)
            
            // 錄音狀態文字
            Text(statusText)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // 錄音按鈕
            RecordButton(
                isRecording: audioRecorder.isRecording,
                action: {
                    if audioRecorder.isRecording {
                        // 停止錄音
                        savedRecordingURL = audioRecorder.stopRecording()
                        showSaveAlert = true
                    } else {
                        // 開始錄音
                        audioRecorder.startRecording()
                    }
                }
            )
            
            Spacer()
        }
        .padding()
        .alert("錄音完成", isPresented: $showSaveAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            if savedRecordingURL != nil {
                Text("錄音已保存！")
            }
        }
    }
    
    private var statusText: String {
        if audioRecorder.isRecording {
            return "錄音中... 請說話"
        } else if audioRecorder.recordingTime > 0 {
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
}

// 錄音按鈕組件
struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 80, height: 80)
                
                if isRecording {
                    // 停止圖標 (正方形)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                } else {
                    // 錄音圖標 (圓形)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .shadow(radius: 5)
    }
}

// 音頻level顯示
struct AudioLevelView: View {
    let level: Float
    let isRecording: Bool
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight(for: index))
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        guard isRecording else { return 4 }
        
        // 將 dB (-160 ~ 0) 轉換為 0 ~ 1
        let normalizedLevel = max(0, min(1, (level + 60) / 60))
        let segmentThreshold = CGFloat(index) / 20.0
        
        return normalizedLevel > segmentThreshold ? 20 : 4
    }
    
    private func barColor(for index: Int) -> Color {
        let ratio = Float(index) / 20.0
        if ratio < 0.6 {
            return .green
        } else if ratio < 0.8 {
            return .yellow
        } else {
            return .red
        }
    }
}

#Preview {
    RecordView()
}
