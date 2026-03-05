import SwiftUI

struct ContentView: View {
    @State private var showRecordView = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("TalkSense")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("性格情緒分析")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.blue)
                
                Spacer()
                
                // 開始錄音按鈕
                NavigationLink(destination: RecordView(), isActive: $showRecordView) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("開始錄音")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                
                Text("點擊上方按鈕開始錄製語音")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
