//
//  LiveActivityManager.swift
//  Pan3
//
//  Created by Feng on 2025/1/2.
//

import WidgetKit
import Foundation
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    /// Callback for receiving the push token as a hex string
    var onPushTokenReceived: ((String) -> Void)?
    
    private init() {}
    
    // 当前活跃的充电任务实时活动
    private var currentActivity: Activity<CarWidgetAttributes>?
    
    // MARK: - 启动实时活动
    /// 启动实时活动
    func startChargeActivity(attributes: CarWidgetAttributes, initialState: CarWidgetAttributes.ContentState) {
        // 检查实时活动权限
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("实时活动未启用")
            return
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let json = try! encoder.encode(initialState)
        print(String(data: json, encoding: .utf8)!)
        
        do {
            // 启动实时活动
            let activity = try Activity<CarWidgetAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token
            )
            //监听回调
            Task {
                //监听PushToken变化
                for await tokenData in activity.pushTokenUpdates {
                    let mytoken = tokenData.map { String(format: "%02x", $0) }.joined()
                    self.onPushTokenReceived?(mytoken)
                }
            }
            
            currentActivity = activity
            print("实时活动已启动，ID: \(activity.id)")
        } catch {
            print("启动实时活动失败: \(error)")
        }
    }
    
    // MARK: - 更新实时活动
    /// 更新实时活动
    func updateChargeActivity(with state: CarWidgetAttributes.ContentState) {
        guard let activity = currentActivity else {
            print("没有活跃的实时活动")
            return
        }
        
        Task {
            do {
                await activity.update(using: state)
                print("实时活动已更新")
            }
        }
    }
    
    // MARK: - 结束实时活动
    func endCurrentActivity(dismissalPolicy: ActivityUIDismissalPolicy = .default) {
        guard let activity = currentActivity else {
            return
        }
        
        Task {
            await activity.end(nil, dismissalPolicy: dismissalPolicy)
            print("实时活动已结束")
        }
        
        currentActivity = nil
    }
    
    // MARK: - 结束指定任务的实时活动
    // MARK: - 检查是否有活跃的实时活动
    func hasActiveActivity() -> Bool {
        return currentActivity != nil
    }
    
    // MARK: - 获取当前活动进度
    func getCurrentActivityProgress() -> Int? {
        return currentActivity?.content.state.chargeProgress
    }
    
    // MARK: - 私有方法
    /// 计算里程进度百分比
    private func calculateMileageProgress(from startKm: Int, to endKm: Int, current currentKm: Int) -> Int {
        guard endKm > startKm else { return 0 }
        let progress = Float(currentKm - startKm) / Float(endKm - startKm)
        return Int(max(0, min(1, progress)) * 100)
    }
    
    /// 计算SOC进度百分比 (基于当前SOC相对于初始SOC的变化)
    private func calculateSocProgress(from initialSoc: Int, current currentSoc: Int) -> Int {
        // 简单计算SOC变化的百分比，这里可以根据实际需求调整计算逻辑
        let socChange = currentSoc - initialSoc
        return max(0, socChange) // 返回SOC增加的数值
    }
}

// MARK: - 扩展：便捷方法
@available(iOS 16.1, *)
extension LiveActivityManager {
    
    // 根据充电任务状态自动管理实时活动
    func manageActivityForTask(attributes: CarWidgetAttributes, state: CarWidgetAttributes.ContentState) {
        // 基于充电进度判断充电状态
        switch state.chargeProgress {
        case 0..<100:
            // 充电进行中，启动或更新实时活动
            if hasActiveActivity() {
                updateChargeActivity(with: state)
            } else {
                startChargeActivity(attributes: attributes, initialState: state)
            }
            
        case 100:
            // 充电完成，更新状态并延迟结束
            if hasActiveActivity() {
                updateChargeActivity(with: state)
                // 5秒后自动结束实时活动
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    let endTime = Date().addingTimeInterval(10)
                    self.endCurrentActivity(dismissalPolicy: .after(endTime))
                }
            }
            
        default:
            // 其他情况（如负值表示失败），立即结束实时活动
            if hasActiveActivity() {
                updateChargeActivity(with: state)
                // 3秒后结束实时活动
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.endCurrentActivity(dismissalPolicy: .default)
                }
            }
        }
    }
    
    // 清理所有实时活动（应用启动时调用）
    func cleanupAllActivities() {
        Task {
            for activity in Activity<CarWidgetAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }
    
    // 根据VIN清理相关的实时活动
    func cleanupActivitiesForVin(_ vin: String) {
        Task {
            for activity in Activity<CarWidgetAttributes>.activities {
                // 检查活动的VIN是否匹配
                if activity.attributes.vin == vin {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    print("已清理VIN \(vin) 的实时活动: \(activity.id)")
                }
            }
            
            // 如果当前活动的VIN匹配，也清理掉
            if let currentActivity = currentActivity,
               currentActivity.attributes.vin == vin {
                self.currentActivity = nil
            }
        }
    }
}

#endif
