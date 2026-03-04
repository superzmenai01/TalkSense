import SwiftUI

struct ContentView: View {
    var body: some View {
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
            
            Text("準備開始...")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
