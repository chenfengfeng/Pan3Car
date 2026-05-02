//
//  TripRecordModel.swift
//  Pan3
//
//  Created by Assistant on 2024
//

import Foundation

// MARK: - 行程记录数据模型

struct TripRecordData {
    let id: Int
    let vin: String
    let departureAddress: String
    let destinationAddress: String
    let departureTime: String // 格式化的时间显示 (HH:mm)
    let duration: String
    let drivingMileage: Double
    let consumedMileage: Double
    let achievementRate: Double // 达成率百分比
    let powerConsumption: Double // SOC消耗（轮询模式）或消耗电量kWh（车机模式）
    let averageSpeed: Double
    let energyEfficiency: Double // 每公里耗电（轮询模式）或里程能耗kWh/100km（车机模式）
    
    // 数据来源类型
    let trackSource: String? // "device" 或 "polling"/nil
    
    // 车机模式专用字段（当trackSource == "device"时使用）
    let energyConsumptionKwh: Double? // 消耗电量（度/kWh）
    let energyConsumptionPer100km: Double? // 里程能耗（kWh/100km）
    
    // 完整的日期时间信息
    let startTime: String // 完整的开始时间 (yyyy-MM-dd HH:mm:ss)
    let endTime: String // 完整的结束时间 (yyyy-MM-dd HH:mm:ss)
    let startLocation: String
    let endLocation: String
    let startLatLng: String?
    let endLatLng: String?
    let startMileage: Double
    let endMileage: Double
    let startRange: Double
    let endRange: Double
    let startSoc: Int
    let endSoc: Int
    let createdAt: String
    let updatedAt: String
}