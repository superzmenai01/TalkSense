import SwiftUI
import Charts

// MARK: - 圖表視覺化主頁面
struct ChartsView: View {
    let analyses: [RecordingAnalysis]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 標題
                Text("數據趨勢")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                if analyses.isEmpty {
                    EmptyChartsView()
                } else {
                    // 準確率趨勢
                    AccuracyTrendChart(analyses: analyses)
                        .frame(height: 200)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    // 語速趨勢
                    SpeechRateChart(analyses: analyses)
                        .frame(height: 200)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    // 停頓比例
                    PauseRatioChart(analyses: analyses)
                        .frame(height: 200)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    // 總結統計
                    SummaryStatsView(analyses: analyses)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - 空數據視圖
struct EmptyChartsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暫時未有數據")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("錄製多幾次語音，就會見到圖表喇！")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - 準確率趨勢圖
struct AccuracyTrendChart: View {
    let analyses: [RecordingAnalysis]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("準確率趨勢", systemImage: "percent")
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(Array(analyses.enumerated()), id: \.element.id) { index, analysis in
                        LineMark(
                            x: .value("次數", index + 1),
                            y: .value("準確率", analysis.accuracy * 100)
                        )
                        .foregroundColor(.blue)
                        
                        PointMark(
                            x: .value("次數", index + 1),
                            y: .value("準確率", analysis.accuracy * 100)
                        )
                        .foregroundColor(.blue)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            } else {
                // iOS 15 fallback - 簡單文字顯示
                Text("需要 iOS 16+ 先可以睇到圖表")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 語速趨勢圖
struct SpeechRateChart: View {
    let analyses: [RecordingAnalysis]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("語速趨勢 (WPM)", systemImage: "waveform")
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(Array(analyses.enumerated()), id: \.element.id) { index, analysis in
                        BarMark(
                            x: .value("次數", "第\(index + 1)次"),
                            y: .value("語速", analysis.audioFeatures.speechRate)
                        )
                        .foregroundStyle(barColor(for: analysis.audioFeatures.speechRate).gradient)
                    }
                }
            } else {
                Text("需要 iOS 16+ 先可以睇到圖表")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func barColor(for rate: Double) -> Color {
        if rate < 100 { return .blue }
        else if rate < 180 { return .green }
        else { return .orange }
    }
}

// MARK: - 停頓比例圖
struct PauseRatioChart: View {
    let analyses: [RecordingAnalysis]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("停頓比例", systemImage: "pause.circle")
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(Array(analyses.enumerated()), id: \.element.id) { index, analysis in
                        BarMark(
                            x: .value("次數", "第\(index + 1)次"),
                            y: .value("停頓", analysis.audioFeatures.pauseRatio * 100)
                        )
                        .foregroundStyle(Color.purple.gradient)
                    }
                }
                .chartYScale(domain: 0...100)
            } else {
                Text("需要 iOS 16+ 先可以睇到圖表")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 總結統計
struct SummaryStatsView: View {
    let analyses: [RecordingAnalysis]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("總結", systemImage: "chart.pie")
                .font(.headline)
            
            HStack(spacing: 20) {
                SummaryStatItem(
                    title: "總錄音次數",
                    value: "\(analyses.count)",
                    icon: "mic.fill",
                    color: .blue
                )
                
                SummaryStatItem(
                    title: "平均準確率",
                    value: "\(Int(averageAccuracy * 100))%",
                    icon: "percent",
                    color: averageAccuracy >= 0.6 ? .green : .orange
                )
            }
            
            HStack(spacing: 20) {
                SummaryStatItem(
                    title: "平均語速",
                    value: "\(Int(averageSpeechRate)) WPM",
                    icon: "waveform",
                    color: .purple
                )
                
                SummaryStatItem(
                    title: "總錄音時長",
                    value: "\(Int(totalDuration)) 秒",
                    icon: "clock.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var averageAccuracy: Double {
        guard !analyses.isEmpty else { return 0 }
        return analyses.reduce(0) { $0 + $1.accuracy } / Double(analyses.count)
    }
    
    private var averageSpeechRate: Double {
        guard !analyses.isEmpty else { return 0 }
        return analyses.reduce(0) { $0 + $1.audioFeatures.speechRate } / Double(analyses.count)
    }
    
    private var totalDuration: Double {
        analyses.reduce(0) { $0 + $1.audioFeatures.totalDuration }
    }
}

struct SummaryStatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ChartsView(analyses: [])
}
