//
//  TripRecordModel.swift
//  Pan3
//
//  Created by Assistant on 2024
//

import Foundation

// MARK: - 行程记录数据模型

struct TripRecordData {
    let departureAddress: String
    let destinationAddress: String
    let departureTime: String
    let duration: String
    let drivingMileage: Double
    let consumedMileage: Double
    let achievementRate: Double // 达成率百分比
    let powerConsumption: Double // SOC消耗
    let averageSpeed: Double
    let energyEfficiency: Double // 每公里耗电
}