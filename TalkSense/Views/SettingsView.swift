import SwiftUI

struct SettingsView: View {
    @State private var reminderEnabled: Bool = false
    @State private var reminderHour: Int = 9
    @State private var reminderMinute: Int = 0
    @State private var nextReminderTime: Date?
    @State private var showPermissionAlert: Bool = false
    
    // API Key 設置
    @State private var apiKeyInput: String = ""
    @State private var showAPIKeySet: Bool = false
    
    private let notificationService = NotificationService.shared
    private let miniMaxService = MiniMaxService.shared
    
    var body: some View {
        List {
            // API Key 設置
            Section {
                if miniMaxService.isConfigured {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("API Key 已設置")
                            .foregroundColor(.green)
                    }
                    
                    Button("清除 API Key") {
                        miniMaxService.clearAPIKey()
                    }
                    .foregroundColor(.red)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MiniMax API Key")
                            .font(.headline)
                        
                        SecureField("輸入 API Key", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("保存") {
                            if !apiKeyInput.isEmpty {
                                miniMaxService.setAPIKey(apiKeyInput)
                                apiKeyInput = ""
                                showAPIKeySet = true
                            }
                        }
                        .disabled(apiKeyInput.isEmpty)
                    }
                }
            } header: {
                Text("AI 配置")
            } footer: {
                Text("呢個 Key 會保存在你既手機度，唔會上傳到其他地方。")
            }
            
            // 提醒設置
            Section {
                Toggle("開啟每日提醒", isOn: $reminderEnabled)
                    .onChange(of: reminderEnabled) { _, newValue in
                        if newValue {
                            requestNotificationPermission()
                        } else {
                            notificationService.cancelAllReminders()
                        }
                    }
                
                if reminderEnabled {
                    DatePicker(
                        "提醒時間",
                        selection: Binding(
                            get: {
                                var components = DateComponents()
                                components.hour = reminderHour
                                components.minute = reminderMinute
                                return Calendar.current.date(from: components) ?? Date()
                            },
                            set: { newDate in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                reminderHour = components.hour ?? 9
                                reminderMinute = components.minute ?? 0
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: reminderHour) { _, _ in
                        saveReminder()
                    }
                    .onChange(of: reminderMinute) { _, _ in
                        saveReminder()
                    }
                    
                    if let nextTime = nextReminderTime {
                        HStack {
                            Text("下一次提醒")
                            Spacer()
                            Text(nextTime, style: .time)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("定時提醒")
            } footer: {
                Text("設定每日提醒，幫助你建立錄音習慣。")
            }
            
            // 關於
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("App")
                    Spacer()
                    Text("TalkSense")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("關於")
            }
        }
        .navigationTitle("設定")
        .onAppear {
            loadSettings()
        }
        .alert("需要通知權限", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("請允許通知權限，先可以使用提醒功能。")
        }
        .alert("API Key 已保存", isPresented: $showAPIKeySet) {
            Button("OK", role: .cancel) { }
        }
    }
    
    private func requestNotificationPermission() {
        notificationService.requestPermission { granted in
            if granted {
                saveReminder()
            } else {
                showPermissionAlert = true
                reminderEnabled = false
            }
        }
    }
    
    private func saveReminder() {
        guard reminderEnabled else { return }
        
        notificationService.scheduleDailyReminder(hour: reminderHour, minute: reminderMinute) { success in
            if success {
                notificationService.getNextReminder { date in
                    nextReminderTime = date
                }
            }
        }
    }
    
    private func loadSettings() {
        reminderEnabled = UserDefaults.standard.bool(forKey: "reminderEnabled")
        reminderHour = UserDefaults.standard.integer(forKey: "reminderHour")
        reminderMinute = UserDefaults.standard.integer(forKey: "reminderMinute")
        
        if reminderHour == 0 && reminderMinute == 0 {
            reminderHour = 9
            reminderMinute = 0
        }
        
        notificationService.getNextReminder { date in
            nextReminderTime = date
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
