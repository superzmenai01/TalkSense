import Foundation

class QuestionService {
    static let shared = QuestionService()
    
    private init() {}
    
    // 問題庫
    private let questions: [Question] = [
        // 情境題 - 社交處理
        Question(
            id: "social_1",
            category: .situational,
            question: "如果你既朋友借咗你既錢，但係遲遲唔還，你會點做？",
            keywords: ["金錢", "朋友", "借錢", "催促"]
        ),
        Question(
            id: "social_2",
            category: .situational,
            question: "當你係公共交通工具上面遇到大聲講電話既人，你會點樣處理？",
            keywords: ["公眾", "噪音", "處理方式"]
        ),
        Question(
            id: "social_3",
            category: .situational,
            question: "如果有人係排隊既時候插隊，你會點樣反應？",
            keywords: ["排隊", "公平", "權益"]
        ),
        
        // 價值觀題
        Question(
            id: "value_1",
            category: .values,
            question: "你覺得工作同生活既平衡應該點樣分配？",
            keywords: ["工作", "生活", "平衡", "價值觀"]
        ),
        Question(
            id: "value_2",
            category: .values,
            question: "你認為成功既定義係咩？",
            keywords: ["成功", "定義", "目標"]
        ),
        Question(
            id: "value_3",
            category: .values,
            question: "如果中可以實現一個願望，你會許咩願？",
            keywords: ["願望", "希望", "價值"]
        ),
        
        // 情緒處理題
        Question(
            id: "emotion_1",
            category: .emotional,
            question: "當你遇到好大既壓力既時候，你通常會點樣舒發？",
            keywords: ["壓力", "情緒", "處理方式"]
        ),
        Question(
            id: "emotion_2",
            category: .emotional,
            question: "如果有人係到你面前講你既壞話，你會點樣既反應？",
            keywords: ["批評", "情緒", "反應"]
        ),
        Question(
            id: "emotion_3",
            category: .emotional,
            question: "當你失敗既時候，你會點樣重新調整自己既心情？",
            keywords: ["失敗", "調整", "心態"]
        ),
        
        // 人際關係題
        Question(
            id: "relationship_1",
            category: .relationship,
            question: "你同屋企人既關係點樣？你通常會點樣同佢地相處？",
            keywords: ["屋企人", "家庭", "關係"]
        ),
        Question(
            id: "relationship_2",
            category: .relationship,
            question: "你覺得友情既意義係咩？",
            keywords: ["友情", "意義", "朋友"]
        ),
        Question(
            id: "relationship_3",
            category: .relationship,
            question: "如果你既另一半做咗一件令你好唔開心既事，你會點樣表達你自己既感受？",
            keywords: ["另一半", "溝通", "感受"]
        ),
        
        // 決定題
        Question(
            id: "decision_1",
            category: .decision,
            question: "如果你既Job offer 一份人工高但係做得唔開心，另一份人工低啲但係好有滿足感，你會點樣揀？",
            keywords: ["工作", "選擇", "價值觀"]
        ),
        Question(
            id: "decision_2",
            category: .decision,
            question: "當你需要係短時間內做一個重要既決定，你會點樣諗？",
            keywords: ["決定", "思考方式", "優先順序"]
        ),
        Question(
            id: "decision_3",
            category: .decision,
            question: "你會點樣去評估一個決定既風險？",
            keywords: ["風險", "評估", "決定"]
        )
    ]
    
    // 隨機獲取一條問題
    func getRandomQuestion() -> Question {
        questions.randomElement() ?? questions[0]
    }
    
    // 根據類別獲取問題
    func getQuestion(from category: QuestionCategory) -> Question {
        let filtered = questions.filter { $0.category == category }
        return filtered.randomElement() ?? questions[0]
    }
    
    // 獲取所有問題類別
    func getAllCategories() -> [QuestionCategory] {
        return [.situational, .values, .emotional, .relationship, .decision]
    }
}

// MARK: - 數據模型

struct Question: Identifiable {
    let id: String
    let category: QuestionCategory
    let question: String
    let keywords: [String]
}

enum QuestionCategory: String, CaseIterable {
    case situational = "情境題"
    case values = "價值觀題"
    case emotional = "情緒處理題"
    case relationship = "人際關係題"
    case decision = "決定題"
    
    var description: String {
        switch self {
        case .situational: return "測試你既社交處理方式"
        case .values: return "了解你既價值觀"
        case .emotional: return "了解你既情緒管理模式"
        case .relationship: return "了解你既人際關係"
        case .decision: return "了解你既決定方式"
        }
    }
}
