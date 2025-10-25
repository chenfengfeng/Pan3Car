//
//  TripAttributes.swift
//  Pan3Car
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import ActivityKit

// MARK: - Trip Activity Attributes
struct TripAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 动态状态数据
        
        /// 已行驶时间（分钟）
        var elapsedTimeMinutes: Int
        
        /// 实际行驶里程（公里）
        var actualMileage: Double
        
        /// 行程效率（公里/小时）
        var tripEfficiency: Double
        
        /// 消耗里程与实际里程对比（消耗里程）
        var consumedMileage: Double
        
        /// 当前状态消息（可选）
        var statusMessage: String?
        
        /// 最后更新时间
        var lastUpdated: Date
        
        public init(
            elapsedTimeMinutes: Int,
            actualMileage: Double,
            tripEfficiency: Double,
            consumedMileage: Double,
            statusMessage: String? = nil,
            lastUpdated: Date = Date()
        ) {
            self.elapsedTimeMinutes = elapsedTimeMinutes
            self.actualMileage = actualMileage
            self.tripEfficiency = tripEfficiency
            self.consumedMileage = consumedMileage
            self.statusMessage = statusMessage
            self.lastUpdated = lastUpdated
        }
    }
    
    // 固定属性（活动创建时设定，不会改变）
    
    /// 车辆VIN码
    let vinCode: String
    
    /// 出发时间
    let departureTime: Date
    
    /// 出发时里程（公里）
    let initialMileage: Double
    
    /// 计划目的地（可选）
    let destination: String?
    
    public init(
        vinCode: String,
        departureTime: Date,
        initialMileage: Double,
        destination: String? = nil
    ) {
        self.vinCode = vinCode
        self.departureTime = departureTime
        self.initialMileage = initialMileage
        self.destination = destination
    }
}

// MARK: - Helper Extensions
extension TripAttributes.ContentState {
    /// 格式化已行驶时间为小时:分钟格式
    var formattedElapsedTime: String {
        let hours = elapsedTimeMinutes / 60
        let minutes = elapsedTimeMinutes % 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    /// 计算里程效率百分比（实际里程 vs 消耗里程）
    var mileageEfficiencyPercentage: Double {
        guard consumedMileage > 0 else { return 0 }
        return (actualMileage / consumedMileage) * 100
    }
}

extension TripAttributes {
    /// 格式化出发时间
    var formattedDepartureTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: departureTime)
    }
}