//
//  ChargeTaskModel.swift
//  Pan3
//
//  Created by Feng on 2025/10/12.
//

import Foundation

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
        case "PREPARING":
            return "准备中"
        case "RUNNING", "CHARGING":
            return "充电中"
        case "COMPLETED":
            return "已完成"
        case "FAILED":
            return "失败"
        case "CANCELLED":
            return "已取消"
        default:
            return status
        }
    }
    
    // 直接初始化方法，接受所有属性作为参数
    init(id: Int, vin: String, initialKwh: Float, targetKwh: Float, chargedKwh: Float, 
         initialKm: Float, targetKm: Float, status: String, message: String?, 
         createdAt: String, finishTime: String?) {
        self.id = id
        self.vin = vin
        self.initialKwh = initialKwh
        self.targetKwh = targetKwh
        self.chargedKwh = chargedKwh
        self.initialKm = initialKm
        self.targetKm = targetKm
        self.status = status
        self.message = message
        self.createdAt = createdAt
        self.finishTime = finishTime
    }
    
    init(from record: ChargeTaskRecord, carModel: CarModel) {
        self.id = Int(record.id ?? 0)
        self.vin = record.vin
        self.status = record.finalStatus
        self.message = record.finalMessage
        
        // --- Perform Calculations ---
        let batteryCapacity = carModel.estimatedModelAndCapacity.batteryCapacity
        let startSoc = Double(record.startSoc ?? 0)
        let endSoc = Double(record.endSoc ?? 0)
        
        self.initialKwh = Float((startSoc / 100.0) * batteryCapacity)
        let finalKwh = Float((endSoc / 100.0) * batteryCapacity)
        self.chargedKwh = Float(max(0, finalKwh - initialKwh))
        
        self.initialKm = Float(record.startRange ?? 0)
        
        // Calculate targetKm based on monitoring mode
        if record.monitoringMode == "range" {
            self.targetKm = Float(record.targetValue) ?? 0.0
        } else {
            // For time mode, there's no specific km target, you can use endRange or initialKm
            self.targetKm = Float(record.endRange ?? record.startRange ?? 0)
        }
        
        // Target kWh can also be calculated if needed, otherwise set to a default
        self.targetKwh = 0 // Or calculate based on targetKm/targetSoc if necessary
        
        // --- Format Dates ---
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        self.createdAt = Self.format(date: record.startTime)
        self.finishTime = record.endTime != nil ? Self.format(date: record.endTime!) : nil
    }
    
    private static func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
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
