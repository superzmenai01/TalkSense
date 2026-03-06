import SwiftUI

@main
struct TalkSenseApp: App {
    init() {
        // 嘗試從本地文件加載 API Key (如果存在的話)
        if let apiKey = loadAPIKey(), !apiKey.isEmpty {
            if !MiniMaxService.shared.isConfigured {
                MiniMaxService.shared.setAPIKey(apiKey)
            }
        }
    }
    
    private func loadAPIKey() -> String? {
        let fileURL = Bundle.main.path(forResource: "APIKey", ofType: "txt")
        if let url = fileURL {
            return try? String(contentsOfFile: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
