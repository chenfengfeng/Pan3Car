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

#endif
