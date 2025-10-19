//
//  ChargeTaskModel.swift
//  Pan3
//
//  Created by Feng on 2025/10/12.
//

import Foundation

// MARK: - 充电相关数据模型（严格以 ChargeTaskRecord/数据库字段为准）
struct ChargeTaskModel {
    // 数据库主键（对应 chargeTask.id）
    let id: Int64?

    // 时间字段（对应 chargeTask.startTime / endTime）
    let startTime: Date
    let endTime: Date?

    // SOC 信息（对应 chargeTask.startSoc / endSoc）
    let startSoc: Int
    let endSoc: Int?

    // 里程信息（对应 chargeTask.startKm / endKm）
    let startKm: Int
    let endKm: Int?

    // GPS 信息（对应 chargeTask.lat / lon / address）
    let lat: Double?
    let lon: Double?
    let address: String?

    // 从数据库记录初始化
    init(from record: ChargeTaskRecord) {
        self.id = record.id  // 现在是可选类型，直接赋值
        self.startTime = record.startTime
        self.endTime = record.endTime
        self.startSoc = record.startSoc
        self.endSoc = record.endSoc
        self.startKm = record.startKm
        self.endKm = record.endKm
        self.lat = record.lat
        self.lon = record.lon
        self.address = record.address
    }

    // 兼容网络返回的初始化方法（不保存多余属性，仅映射到数据库字段）
    // 注意：此初始化仅用于兼容已有调用，参数中的 vin/status/message 等不作为模型属性保存
    init(id: Int,
         vin: String,
         startKm: Int,
         endKm: Int,
         status: String,
         message: String,
         createdAt: String,
         finishTime: String?,
         lat: Double? = nil,
         lon: Double? = nil,
         address: String? = nil) {
        // 主键
        self.id = Int64(id)

        // 时间字段（字符串转 Date）
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.startTime = formatter.date(from: createdAt) ?? Date()
        if let finish = finishTime, let end = formatter.date(from: finish) {
            self.endTime = end
        } else {
            self.endTime = nil
        }

        // 里程与 SOC（网络返回不提供精确 SOC，则置为默认值；里程按 start/end 映射）
        self.startKm = startKm
        self.endKm = endKm
        self.startSoc = 0 // 网络返回时没有SOC信息，设为默认值
        self.endSoc = nil
        
        // GPS 信息
        self.lat = lat
        self.lon = lon
        self.address = address
    }

    // 充电时长（基于开始/结束时间）
    var chargeDuration: String {
        guard let endTime = endTime else { return "--" }
        let duration = endTime.timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }

    // MARK: - 兼容旧UI/调用的计算属性（不作为持久化字段）
    // 字符串形式的开始/结束时间（用于 Cell 展示）
    var createdAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter.string(from: startTime)
    }

    var finishTime: String? {
        guard let end = endTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: end)
    }
}
