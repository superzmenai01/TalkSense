import SwiftUI
import Charts

// MARK: - 圖表視覺化主頁面
struct ChartsView: View {
    let analyses: [RecordingAnalysis]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("數據趨勢")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                if analyses.isEmpty {
                    EmptyChartsView()
                } else {
                    SummaryStatsView(analyses: analyses)
                        .padding(.horizontal)
                    
                    SimpleAccuracyChart(analyses: analyses)
                        .frame(height: 180)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    
                    SimpleSpeechRateChart(analyses: analyses)
                        .frame(height: 180)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
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

// MARK: - 簡化版準確率圖
struct SimpleAccuracyChart: View {
    let analyses: [RecordingAnalysis]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("準確率趨勢")
                .font(.headline)
            
            if analyses.count == 1 {
                SingleAccuracyView(analysis: analyses[0])
            } else {
                MultiAccuracyView(analyses: analyses)
            }
        }
    }
}

struct SingleAccuracyView: View {
    let analysis: RecordingAnalysis
    
    var body: some View {
        VStack {
            Text("\(Int(analysis.accuracy * 100))%")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.blue)
            
            ProgressView(value: analysis.accuracy)
                .tint(.blue)
        }
    }
}

struct MultiAccuracyView: View {
    let analyses: [RecordingAnalysis]
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(analyses.enumerated()), id: \.element.id) { index, analysis in
                HStack {
                    Text("第\(index + 1)次")
                        .font(.caption)
                        .frame(width: 50, alignment: .leading)
                    
                    ProgressView(value: analysis.accuracy)
                        .tint(accuracyColor(analysis.accuracy))
                    
                    Text("\(Int(analysis.accuracy * 100))%")
                        .font(.caption)
                        .frame(width: 35, alignment: .trailing)
                }
            }
        }
    }
    
    func accuracyColor(_ value: Double) -> Color {
        if value >= 0.7 { return .green }
        else if value >= 0.4 { return .orange }
        else { return .red }
    }
}

// MARK: - 簡化版語速圖
struct SimpleSpeechRateChart: View {
    let analyses: [RecordingAnalysis]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("語速趨勢")
                .font(.headline)
            
            ForEach(Array(analyses.enumerated()), id: \.element.id) { index, analysis in
                HStack {
                    Text("第\(index + 1)次")
                        .font(.caption)
                        .frame(width: 50, alignment: .leading)
                    
                    Text("\(Int(analysis.audioFeatures.speechRate)) WPM")
                        .font(.caption)
                }
            }
        }
    }
}

// MARK: - 總結統計
struct SummaryStatsView: View {
    let analyses: [RecordingAnalysis]
    
    private var averageAccuracy: Double {
        guard !analyses.isEmpty else { return 0 }
        let total = analyses.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(analyses.count)
    }
    
    private var averageSpeechRate: Double {
        guard !analyses.isEmpty else { return 0 }
        let total = analyses.reduce(0.0) { $0 + $1.audioFeatures.speechRate }
        return total / Double(analyses.count)
    }
    
    private var totalDuration: Double {
        analyses.reduce(0) { $0 + $1.audioFeatures.totalDuration }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("總結")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatBox(title: "錄音次數", value: "\(analyses.count)", icon: "mic.fill", color: .blue)
                StatBox(title: "累積準確率", value: "\(Int(averageAccuracy * 100))%", icon: "percent", color: averageAccuracy >= 0.6 ? .green : .orange)
            }
            
            HStack(spacing: 20) {
                StatBox(title: "平均語速", value: "\(Int(averageSpeechRate))", icon: "waveform", color: .purple)
                StatBox(title: "總時長", value: "\(Int(totalDuration))秒", icon: "clock.fill", color: .orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatBox: View {
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
