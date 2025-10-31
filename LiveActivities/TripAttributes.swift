//
//  TripAttributes.swift
//  Pan3Car
//
//  Created by AI Assistant on 2025/1/27.
//

import Foundation
import ActivityKit
import SwiftUI

// MARK: - 车辆状态枚举
enum VehicleStatus: String, CaseIterable {
    case driving = "driving"
    case parking = "parking"
    
    var displayTitle: String {
        switch self {
        case .driving:
            return "🚗 正在用车"
        case .parking:
            return "🅿️ 等待启动"
        }
    }
    
    var statusEmoji: String {
        switch self {
        case .driving:
            return "🚗"
        case .parking:
            return "🅿️"
        }
    }
}

// MARK: - Trip Activity Attributes
struct TripAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 实际行驶里程（公里）
        var actualMileage: Double
        
        /// 消耗里程与实际里程对比（消耗里程）
        var consumedMileage: Double
        
        /// 是否行驶中
        var isDriving: Bool
        
        public init(
            actualMileage: Double,
            consumedMileage: Double,
            isDriving: Bool
        ) {
            self.actualMileage = actualMileage
            self.consumedMileage = consumedMileage
            self.isDriving = isDriving
        }
    }
    
    // 固定属性（活动创建时设定，不会改变）
    /// 出发时间
    let departureTime: Date
    
    /// 出发时总里程（公里）
    let totalMileageAtStart: Double
    
    public init(
        departureTime: Date,
        totalMileageAtStart: Double
    ) {
        self.departureTime = departureTime
        self.totalMileageAtStart = totalMileageAtStart
    }
}

// MARK: - Helper Extensions
extension TripAttributes.ContentState {
    /// 计算行驶时间（基于出发时间和当前时间）
    func elapsedTime(from departureTime: Date) -> TimeInterval {
        return Date().timeIntervalSince(departureTime)
    }
    
    /// 格式化行驶时间显示
    func formattedElapsedTime(from departureTime: Date) -> String {
        let elapsed = elapsedTime(from: departureTime)
        let hours = Int(elapsed) / 3600
        let minutes = Int(elapsed) % 3600 / 60
        
        if hours > 0 {
            return String(format: "%02d:%02d", hours, minutes)
        } else {
            return String(format: "%02d分钟", minutes)
        }
    }
    
    /// 计算行程效率（公里/小时）
    func tripEfficiency(from departureTime: Date) -> Double {
        let elapsedHours = elapsedTime(from: departureTime) / 3600
        guard elapsedHours > 0 else { return 0 }
        return actualMileage / elapsedHours
    }
    
    /// 计算里程效率百分比
    var mileageEfficiencyPercentage: Double {
        guard consumedMileage > 0 else { return 100 }
        return (actualMileage / consumedMileage) * 100
    }
    
    /// 车辆状态
    var vehicleStatus: VehicleStatus {
        return isDriving ? .driving : .parking
    }
    
    /// 根据效率返回对应颜色
    var efficiencyColor: Color {
        let efficiency = mileageEfficiencyPercentage
        if efficiency >= 90 {
            return .green
        } else if efficiency >= 70 {
            return .orange
        } else {
            return .red
        }
    }
    
    /// 进度条颜色
    var progressBarColor: Color {
        return efficiencyColor
    }
    
    /// 进度条显示值（0-1之间）
    var progressValue: Double {
        return min(mileageEfficiencyPercentage / 100, 1.0)
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
