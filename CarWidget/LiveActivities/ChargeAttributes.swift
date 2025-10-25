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
struct ChargeAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 动态状态数据
        var currentKm: Int             // 当前里程
        var currentSoc: Int            // 当前SOC
        var chargeProgress: Int        // 充电任务完成进度百分比
        var message: String?           // 充电消息说明
    }
    
    // 固定属性
    var vin: String                   // 车辆VIN码
    var startKm: Int                  // 初始里程
    var endKm: Int                    // 目标里程
    var initialSoc: Int               // 初始SOC百分比
}

#endif
