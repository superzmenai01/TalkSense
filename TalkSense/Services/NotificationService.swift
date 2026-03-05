import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    // 請求權限
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error)")
                }
                completion(granted)
            }
        }
    }
    
    // 檢查權限狀態
    func checkPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    // 設定每日提醒
    func scheduleDailyReminder(hour: Int, minute: Int, completion: @escaping (Bool) -> Void) {
        // 先清除之前既提醒
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // 創建提醒內容
        let content = UNMutableNotificationContent()
        content.title = "📣 TalkSense 錄音提醒"
        content.body = "是時候錄製語音喇！累積越多數據，分析越準確。"
        content.sound = .default
        content.badge = 1
        
        // 創建觸發器 (每日)
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // 創建請求
        let request = UNNotificationRequest(
            identifier: "daily_recording_reminder",
            content: content,
            trigger: trigger
        )
        
        // 安排提醒
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to schedule notification: \(error)")
                    completion(false)
                } else {
                    print("Daily reminder scheduled for \(hour):\(minute)")
                    completion(true)
                }
            }
        }
    }
    
    // 取消所有提醒
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // 獲取下一次提醒時間
    func getNextReminder(completion: @escaping (Date?) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                if let request = requests.first,
                   let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let nextDate = trigger.nextTriggerDate() {
                    completion(nextDate)
                } else {
                    completion(nil)
                }
            }
        }
    }
}
