import Foundation

class MiniMaxService {
    static let shared = MiniMaxService()
    
    // 請填入你既 API Key
    private let apiKey = "YOUR_MINIMAX_API_KEY"
    private let baseURL = "https://api.minimax.chat/v1"
    
    private init() {}
    
    // 性格分析
    func analyzePersonality(
        transcripts: [String],
        audioFeatures: [AudioFeaturesData],
        completion: @escaping (Result<PersonalityAnalysis, Error>) -> Void
    ) {
        // 準備 prompt
        let combinedText = transcripts.joined(separator: "\n")
        
        let prompt = """
        你係一個專業既性格分析師。請根據以下既語音轉文字內容同音頻特徵，分析呢個人既性格特徵。

        ## 語音轉文字內容：
        \(combinedText)

        ## 音頻特徵：
        \(audioFeatures.map { """
        - 語速: \($0.speechRate) WPM
        - 停頓比例: \($0.pauseRatio)
        - 音量變化: \($0.volumeVariation)
        - 音調變化: \($0.pitchVariation)
        - 說話時長: \($0.speakingDuration)秒
        """ }.joined(separator: "\n"))

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
        
        // 發送請求
        sendChatRequest(prompt: prompt, completion: completion)
    }
    
    // 情緒分析
    func analyzeEmotion(
        transcript: String,
        audioFeatures: AudioFeaturesData,
        completion: @escaping (Result<EmotionAnalysis, Error>) -> Void
    ) {
        let prompt = """
        你係一個專業既情緒分析師。請根據以下既語音轉文字內容同音頻特徵，分析呢個人既情緒狀態。

        ## 語音轉文字內容：
        \(transcript)

        ## 音頻特徵：
        - 語速: \(audioFeatures.speechRate) WPM
        - 停頓比例: \(audioFeatures.pauseRatio)
        - 音量變化: \(audioFeatures.volumeVariation)
        - 音調變化: \(audioFeatures.pitchVariation)

        請分析：
        1. 主要情緒 (開心/傷心/緊張/憤怒/平靜/焦慮/其他)
        2. 情緒強度 (0-100)
        3. 情緒既可能原因 (如果可以推斷)

        請用廣東話回覆。
        """
        
        // 發送請求 - 用另一個completion type
        struct EmotionResponse: Codable {
            let emotion: String
            let intensity: Int
            let reason: String
        }
        
        sendChatRequest(prompt: prompt) { (result: Result<String, Error>) in
            switch result {
            case .success(let response):
                // 簡單解析 response
                let analysis = EmotionAnalysis(
                    primaryEmotion: "分析中", // 實際應該parse response
                    intensity: 50,
                    reason: response,
                    timestamp: Date()
                )
                completion(.success(analysis))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func sendChatRequest<T: Codable>(prompt: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/text/chatcompletion") else {
            completion(.failure(NSError(domain: "MiniMax", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "abab6.5s-chat",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
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
                
                // 解析 response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    // 根據返回類型處理
                    if T.self == PersonalityAnalysis.self {
                        let analysis = PersonalityAnalysis(
                            extraversion: 50,
                            stability: 50,
                            openness: 50,
                            agreeableness: 50,
                            conscientiousness: 50,
                            summary: content,
                            timestamp: Date()
                        )
                        completion(.success(analysis as! T))
                    } else if T.self == String.self {
                        completion(.success(content as! T))
                    } else {
                        completion(.failure(NSError(domain: "MiniMax", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unknown type"])))
                    }
                } else {
                    completion(.failure(NSError(domain: "MiniMax", code: 4, userInfo: [NSLocalizedDescriptionKey: "Parse error"])))
                }
            }
        }.resume()
    }
}

// MARK: - 數據模型

struct PersonalityAnalysis: Codable {
    let extraversion: Int      // 外向性 0-100
    let stability: Int        // 穩定性 0-100
    let openness: Int         // 開放性 0-100
    let agreeableness: Int    // 親和性 0-100
    let conscientiousness: Int // 責任感 0-100
    let summary: String       // 總結
    let timestamp: Date
    
    var overallScore: Int {
        (extraversion + stability + openness + agreeableness + conscientiousness) / 5
    }
}

struct EmotionAnalysis: Codable {
    let primaryEmotion: String
    let intensity: Int        // 0-100
    let reason: String
    let timestamp: Date
}
