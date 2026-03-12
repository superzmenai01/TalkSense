

import SwiftUI

// MARK: - 性格分析結果顯示視圖
struct PersonalityResultView: View {
    let result: PersonalityAnalysis?
    let isAnalyzing: Bool
    let errorMessage: String?
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.gray.opacity(0.1)
                    .ignoresSafeArea()
                
                if isAnalyzing {
                    // 加載狀態
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(2.0)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        
                        Text("性格分析中...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("請稍候，AI 正在分析你既錄音數據")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else if let error = errorMessage {
                    // 錯誤狀態
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("分析失敗")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button("關閉") {
                            onDismiss()
                        }
                        .padding(.top, 20)
                    }
                } else if let result = result {
                    // 結果顯示
                    ScrollView {
                        VStack(spacing: 24) {
                            // 標題
                            Text("性格分析結果")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .padding(.top, 20)
                            
                            // 維度分數
                            VStack(spacing: 16) {
                                PersonalityDimensionView(
                                    title: "外向性",
                                    value: result.extraversion,
                                    description: "內向 ↔ 外向"
                                )
                                
                                PersonalityDimensionView(
                                    title: "穩定性",
                                    value: result.stability,
                                    description: "情緒波動 ↔ 情緒穩定"
                                )
                                
                                PersonalityDimensionView(
                                    title: "開放性",
                                    value: result.openness,
                                    description: "保守 ↔ 開放"
                                )
                                
                                PersonalityDimensionView(
                                    title: "親和性",
                                    value: result.agreeableness,
                                    description: "獨立 ↔ 友善"
                                )
                                
                                PersonalityDimensionView(
                                    title: "責任感",
                                    value: result.conscientiousness,
                                    description: "隨意 ↔ 謹慎"
                                )
                            }
                            .padding(.horizontal)
                            
                            // 總結
                            VStack(alignment: .leading, spacing: 12) {
                                Text("整體評估")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(result.summary)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 性格維度顯示
struct PersonalityDimensionView: View {
    let title: String
    let value: Int
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text("\(value)/100")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(colorForValue(value))
            }
            
            // 進度條
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 16)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorForValue(value))
                        .frame(width: geometry.size.width * CGFloat(value) / 100, height: 16)
                }
            }
            .frame(height: 16)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func colorForValue(_ value: Int) -> Color {
        if value < 30 { return .red }
        else if value < 70 { return .yellow }
        else { return .green }
    }
}

