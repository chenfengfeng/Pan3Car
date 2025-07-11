//
//  CarWidgetAttributes.swift
//  Pan3
//
//  Created by Feng on 2025/7/7.
//

import UIKit
#if canImport(ActivityKit)
import ActivityKit

// MARK: - Activity Attributes
struct CarWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 动态状态数据
        var status: String              // 充电状态
        var chargedKwh: Float          // 已充电量
        var percentage: Int            // 充电百分比
        var message: String?           // 任务消息
        var lastUpdateTime: Date       // 最后更新时间
    }
    
    // 固定属性
    var taskId: Int                    // 任务ID
    var vin: String                    // 车辆VIN
    var createdAt: String             // 创建时间
    var initialKm: Float              // 初始里程
    var targetKm: Float               // 目标里程
    var initialKwh: Float             // 初始电量
    var targetKwh: Float              // 目标电量
}

// MARK: - 充电相关数据模型
struct ChargeTaskModel {
    let id: Int
    let vin: String
    let initialKwh: Float
    let targetKwh: Float
    let chargedKwh: Float
    let initialKm: Float
    let targetKm: Float
    let status: String
    let message: String?
    let createdAt: String
    let finishTime: String?
    
    var statusText: String {
        switch status {
        case "pending":
            return "充电中"
        case "ready":
            return "准备中"
        case "done":
            return "已完成"
        case "timeout":
            return "超时"
        case "cancelled":
            return "已取消"
        case "error":
            return "失败"
        default:
            return status
        }
    }
    
    var chargeDuration: String {
        guard let finishTime = finishTime, !finishTime.isEmpty else {
            return "--"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        guard let startDate = formatter.date(from: createdAt),
              let endDate = formatter.date(from: finishTime) else {
            return "--"
        }
        
        let duration = endDate.timeIntervalSince(startDate)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

#endif
