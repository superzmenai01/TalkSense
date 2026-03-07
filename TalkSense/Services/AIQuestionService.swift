import Foundation

class AIQuestionService {
    static let shared = AIQuestionService()
    
    private let miniMax = MiniMaxService.shared
    
    private init() {}
    
    // 生成跟進問題
    func generateFollowUpQuestion(
        originalQuestion: String,
        previousAnswer: String,
        category: QuestionCategory,
        questionCount: Int,
        completion: @escaping (Result<FollowUpQuestion, Error>) -> Void
    ) {
        // 決定係咪應該繼續追問
        let shouldContinue = shouldAskFollowUp(
            answer: previousAnswer,
            category: category,
            questionCount: questionCount
        )
        
        if !shouldContinue {
            // 唔洗追問，可以去下一題
            completion(.success(FollowUpQuestion(
                question: "",
                shouldMoveNext: true,
                reason: "已收集足夠數據"
            )))
            return
        }
        
        // 生成跟進問題既 prompt
        let prompt = """
        用戶正在回答呢條問題：「\(originalQuestion)」
        用戶既回答係：「\(previousAnswer)」
        
        呢個係第 \(questionCount + 1) 次問題。
        
        請根據用戶既回答，生成一條跟進問題黎深入了解佢。
        
        要求：
        1. 問題要自然，同用戶既回答有關連
        2. 用廣東話
        3. 問題要短而精準
        4. 最多20字
        
        重要：請務必生成一條跟進問題，唔好回覆 SKIP！
        """
        
        miniMax.sendChatRequest(prompt: prompt) { (result: Result<String, Error>) in
            switch result {
            case .success(let response):
                let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 最少問 2 次，唔理 AI 點答
                if questionCount < 2 {
                    // 繼續問
                    completion(.success(FollowUpQuestion(
                        question: cleanResponse,
                        shouldMoveNext: false,
                        reason: ""
                    )))
                } else if cleanResponse.uppercased() == "SKIP" || cleanResponse.contains("下一題") {
                    // 已經問夠，可以去下一題
                    completion(.success(FollowUpQuestion(
                        question: "",
                        shouldMoveNext: true,
                        reason: "用戶回答已足夠"
                    )))
                } else {
                    // 問多一次都得
                    completion(.success(FollowUpQuestion(
                        question: cleanResponse,
                        shouldMoveNext: false,
                        reason: ""
                    )))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 決定係咪應該繼續追問
    private func shouldAskFollowUp(answer: String, category: QuestionCategory, questionCount: Int) -> Bool {
        let wordCount = answer.split(separator: " ").count
        
        // 最少會問 2 次跟進問題
        if questionCount < 2 {
            return true
        }
        
        // 如果已經問咗 2 次，原則上可以去下一題
        // 但如果回答太短，都係問多次好啲
        if wordCount < 5 && questionCount < 3 {
            return true
        }
        
        return false
    }
    
    // 決定係咪可以去下一題
    func shouldMoveToNext(
        originalQuestion: String,
        answers: [String],
        completion: @escaping (Bool, String) -> Void
    ) {
        let allAnswers = answers.joined(separator: "\n")
        
        let prompt = """
        用戶回答呢條問題：「\(originalQuestion)」
        
        用戶既所有回答：
        \(allAnswers)
        
        請問收集既數據夠唔夠做性格分析？如果夠，請回覆「ENOUGH」，如果唔夠，請回覆「NOT_ENOUGH」。
        
        考慮因素：
        - 回答既深度
        - 內容既豐富程度
        - 係咪涉及足夠既例子或詳細既描述
        """
        
        miniMax.sendChatRequest(prompt: prompt) { (result: Result<String, Error>) in
            switch result {
            case .success(let response):
                let isEnough = response.uppercased().contains("ENOUGH")
                let reason = isEnough ? "數據已足夠" : "可以繼續深入"
                completion(isEnough, reason)
                
            case .failure:
                // 如果出錯，就默認去下一題
                completion(true, "系統默認")
            }
        }
    }
}

// MARK: - 數據模型
struct FollowUpQuestion {
    let question: String
    let shouldMoveNext: Bool
    let reason: String
}
