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
            
            // 音頻level indicator - 簡化版
            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(index: index))
                        .frame(width: 20, height: barHeight(index: index))
                }
            }
            .frame(height: 40)
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
                        savedRecordingURL = audioRecorder.stopRecording()
                        showSaveAlert = true
                    } else {
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
            Text("錄音已保存！")
        }
    }
    
    private func barHeight(index: Int) -> CGFloat {
        guard audioRecorder.isRecording else { return 8 }
        
        let level = audioRecorder.audioLevel
        // Normalize -160dB~0dB to 0~1
        let normalized = max(0, min(1, (level + 60) / 60))
        let threshold = Double(index + 1) / 10.0
        
        return normalized > threshold ? 40 : 8
    }
    
    private func barColor(index: Int) -> Color {
        if index < 6 { return .green }
        if index < 8 { return .yellow }
        return .red
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
    }
}

#Preview {
    RecordView()
}
