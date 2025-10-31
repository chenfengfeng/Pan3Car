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

// MARK: - 实时活动类型枚举
enum LiveActivityType: String {
    case charge = "charge"
    case trip = "trip"
}

@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    /// Callback for receiving the push token with type information
    var onPushTokenReceived: ((String, LiveActivityType) -> Void)?
    
    private init() {}
    
    // 当前活跃的充电任务实时活动
    private var currentChargeActivity: Activity<ChargeAttributes>?
    
    // 当前活跃的行程实时活动
    private var currentTripActivity: Activity<TripAttributes>?
    
    // MARK: - 通用方法
    /// 清理所有实时活动
    func cleanupAllActivities() {
        Task {
            for activity in Activity<ChargeAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        Task {
            for activity in Activity<TripAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentChargeActivity = nil
        currentTripActivity = nil
    }
    
    /// 检查是否有活跃的实时活动
    func hasActiveActivity() -> Bool {
        return currentChargeActivity != nil || currentTripActivity != nil
    }
}

// MARK: - 充电实时活动管理
@available(iOS 16.1, *)
extension LiveActivityManager {
    
    /// 启动充电实时活动
    func startChargeActivity(attributes: ChargeAttributes, initialState: ChargeAttributes.ContentState) {
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
            let activity = try Activity<ChargeAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token
            )
            
            // 监听推送token更新
            Task {
                for await tokenData in activity.pushTokenUpdates {
                    let mytoken = tokenData.map { String(format: "%02x", $0) }.joined()
                    self.onPushTokenReceived?(mytoken, .charge)
                }
            }
            
            currentChargeActivity = activity
            print("充电实时活动已启动，ID: \(activity.id)")
        } catch {
            print("启动充电实时活动失败: \(error)")
        }
    }
    
    /// 关闭充电实时活动
    func closeChargeActivity() {
        Task {
            for activity in Activity<ChargeAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentChargeActivity = nil
    }
    
    /// 检查是否有活跃的充电实时活动
    func hasActiveChargeActivity() -> Bool {
        return currentChargeActivity != nil
    }
    
    /// 获取当前充电活动进度
    func getCurrentChargeActivityProgress() -> Int? {
        return currentChargeActivity?.content.state.chargeProgress
    }
    
    /// 计算SOC进度百分比 (基于当前SOC相对于初始SOC的变化)
    private func calculateSocProgress(from initialSoc: Int, current currentSoc: Int) -> Int {
        // 简单计算SOC变化的百分比，这里可以根据实际需求调整计算逻辑
        let socChange = currentSoc - initialSoc
        return max(0, socChange) // 返回SOC增加的数值
    }
}

// MARK: - 行程实时活动管理
@available(iOS 16.1, *)
extension LiveActivityManager {
    
    /// 启动行程实时活动
    func startTripActivity(attributes: TripAttributes, initialState: TripAttributes.ContentState) {
        // 检查实时活动权限
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("实时活动未启用")
            return
        }
        
        do {
            // 启动实时活动
            let activity = try Activity<TripAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token
            )
            
            // 监听推送token更新
            Task {
                for await tokenData in activity.pushTokenUpdates {
                    let mytoken = tokenData.map { String(format: "%02x", $0) }.joined()
                    self.onPushTokenReceived?(mytoken, .trip)
                }
            }
            
            currentTripActivity = activity
            print("行程实时活动已启动，ID: \(activity.id)")
        } catch {
            print("启动行程实时活动失败: \(error)")
        }
    }
    
    /// 关闭行程实时活动
    func closeTripActivity() {
        Task {
            for activity in Activity<TripAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentTripActivity = nil
    }
    
    /// 检查是否有活跃的行程实时活动
    func hasActiveTripActivity() -> Bool {
        return currentTripActivity != nil
    }
    
    /// 计算里程进度百分比
    private func calculateMileageProgress(from startKm: Int, to endKm: Int, current currentKm: Int) -> Int {
        guard endKm > startKm else { return 0 }
        let progress = Float(currentKm - startKm) / Float(endKm - startKm)
        return Int(max(0, min(1, progress)) * 100)
    }
}

#endif
