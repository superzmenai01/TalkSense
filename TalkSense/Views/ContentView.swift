import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 首頁 - 錄音
            HomeView()
                .tabItem {
                    Label("錄音", systemImage: "mic.fill")
                }
                .tag(0)
            
            // 圖表
            ChartsView(analyses: StorageService.shared.getAllAnalyses())
                .tabItem {
                    Label("數據", systemImage: "chart.bar.fill")
                }
                .tag(1)
            
            // 設定
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Logo
                Image("TalkSenseLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .shadow(color: .gray.opacity(0.3), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 8) {
                    Text("TalkSense")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("性格情緒分析")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 開始錄音按鈕
                NavigationLink(destination: RecordView()) {
                    VStack(spacing: 12) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 60))
                        
                        Text("開始錄音")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 40)
                
                Text("點擊上方按鈕開始錄製語音")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                Spacer()
            }
            .padding()
            .navigationTitle("TalkSense")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
