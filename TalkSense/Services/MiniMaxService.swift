import Foundation

class MiniMaxService {
    static let shared = MiniMaxService()
    
    private let baseURL = "https://api.minimax.io"
    
    private var apiKey: String {
        get {
            if let savedKey = UserDefaults.standard.string(forKey: "minimax_api_key") {
                return savedKey
            }
            return ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "minimax_api_key")
        }
    }
    
    private init() {}
    
    var isConfigured: Bool {
        !apiKey.isEmpty
    }
    
    func setAPIKey(_ key: String) {
        apiKey = key
    }
    
    func clearAPIKey() {
        apiKey = ""
    }
    
    // 性格分析
    func analyzePersonality(
        transcripts: [String],
        audioFeatures: [AudioFeaturesData],
        completion: @escaping (Result<PersonalityAnalysis, Error>) -> Void
    ) {
        guard isConfigured else {
            completion(.failure(NSError(domain: "MiniMax", code: 99, userInfo: [NSLocalizedDescriptionKey: "API Key 未設置"])))
            return
        }
        
        let combinedText = transcripts.joined(separator: "\n")
        
        let featuresText = audioFeatures.map { """
        - 語速: \($0.speechRate) WPM
        - 停頓比例: \($0.pauseRatio)
        - 音量變化: \($0.volumeVariation)
        - 音調變化: \($0.pitchVariation)
        - 說話時長: \($0.speakingDuration)秒
        """ }.joined(separator: "\n")
        
        let prompt = """
        你係一個專業既性格分析師。請根據以下既語音轉文字內容同音頻特徵，分析呢個人既性格特徵。

        ## 語音轉文字內容：
        \(combinedText)

        ## 音頻特徵：
        \(featuresText)

        請分析以下既性格維度：
        1. 外向性 (Extraversion) - 內向定外向？
        2. 穩定性 (Stability) - 情緒穩定定波動？
        3. 開放性 (Openness) - 開放定保守？
        4. 親和性 (Agreeableness) - 友善定獨立？
        5. 責任感 (Conscientiousness) - 謹慎定隨意？

        請用廣東話回覆，並提供：
        - 每個維度既分數 (0-100)
        - 簡短既分析 (每個維度 1-2 句)
        - 整體性格總結 (3-4 句)
        """
        
        sendChatRequest(prompt: prompt) { [weak self] result in
            switch result {
            case .success(let response):
                let analysis = self?.parsePersonalityResponse(response) ?? PersonalityAnalysis(
                    extraversion: 50,
                    stability: 50,
                    openness: 50,
                    agreeableness: 50,
                    conscientiousness: 50,
                    summary: response,
                    timestamp: Date()
                )
                completion(.success(analysis))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 解析 AI 回覆
    private func parsePersonalityResponse(_ response: String) -> PersonalityAnalysis {
        return PersonalityAnalysis(
            extraversion: 50,
            stability: 50,
            openness: 50,
            agreeableness: 50,
            conscientiousness: 50,
            summary: response,
            timestamp: Date()
        )
    }
    
    // 發送聊天請求 (通用)
    func sendChatRequest(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard isConfigured else {
            completion(.failure(NSError(domain: "MiniMax", code: 99, userInfo: [NSLocalizedDescriptionKey: "API Key 未設置"])))
            return
        }
        
        // 使用正確既 endpoint 同 model
        guard let url = URL(string: "\(baseURL)/v1/text/chatcompletion_v2") else {
            completion(.failure(NSError(domain: "MiniMax", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 使用正確既 model 名稱
        let body: [String: Any] = [
            "model": "M2-her",
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "MiniMax", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                    return
                }
                
                // 打印 response (調試用)
                if let responseString = String(data: data, encoding: .utf8) {
                    print("MiniMax Response: \(responseString)")
                    
                    // 檢查係咪有 error
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let baseResp = json["base_resp"] as? [String: Any],
                           let statusCode = baseResp["status_code"] as? Int,
                           statusCode != 0 {
                            let errorMsg = baseResp["status_msg"] as? String ?? "Unknown error"
                            completion(.failure(NSError(domain: "MiniMax", code: statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                            return
                        }
                        
                        // 正確既 response 格式
                        if let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first,
                           let message = firstChoice["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            completion(.success(content))
                            return
                        }
                    }
                    
                    completion(.failure(NSError(domain: "MiniMax", code: 4, userInfo: [NSLocalizedDescriptionKey: "Parse error: \(responseString)"])))
                } else {
                    completion(.failure(NSError(domain: "MiniMax", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot decode response"])))
                }
            }
        }.resume()
    }
}

// MARK: - 數據模型

struct PersonalityAnalysis: Codable {
    let extraversion: Int
    let stability: Int
    let openness: Int
    let agreeableness: Int
    let conscientiousness: Int
    let summary: String
    let timestamp: Date
    
    var overallScore: Int {
        (extraversion + stability + openness + agreeableness + conscientiousness) / 5
    }
}

struct EmotionAnalysis: Codable {
    let primaryEmotion: String
    let intensity: Int
    let reason: String
    let timestamp: Date
}
