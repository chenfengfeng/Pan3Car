//
//  BatteryCalculationUtility.swift
//  Pan3
//
//  Created by AI Assistant on 2025/1/17.
//

import Foundation

/// 电池电量计算工具类
/// 提供统一的电量、SOC、续航里程等相关计算方法
class BatteryCalculationUtility {
    
    // MARK: - 常量定义
    
    /// 充电损耗系数（考虑充电过程中的能量损失）
    static let chargingLossCoefficient: Double = 1.08
    
    /// 默认能耗比（kWh/100km）- 当无法获取准确数据时使用
    static let defaultEnergyConsumption: Double = 15.0
    
    /// 默认每kWh续航里程（km/kWh）
    static let defaultKmPerKwh: Double = 5.0
    
    // MARK: - 基础电量计算
    
    /// 根据SOC和电池容量计算当前电量
    /// - Parameters:
    ///   - soc: 电池电量百分比 (0-100)
    ///   - batteryCapacity: 电池总容量 (kWh)
    /// - Returns: 当前电量 (kWh)
    static func calculateCurrentKwh(soc: Double, batteryCapacity: Double) -> Double {
        guard soc >= 0, soc <= 100, batteryCapacity > 0 else { return 0 }
        return batteryCapacity * (soc / 100.0)
    }
    
    /// 根据电量和电池容量计算SOC
    /// - Parameters:
    ///   - currentKwh: 当前电量 (kWh)
    ///   - batteryCapacity: 电池总容量 (kWh)
    /// - Returns: SOC百分比 (0-100)
    static func calculateSoc(currentKwh: Double, batteryCapacity: Double) -> Double {
        guard batteryCapacity > 0 else { return 0 }
        return min(100.0, max(0.0, (currentKwh / batteryCapacity) * 100.0))
    }
    
    /// 计算目标电量（考虑充电损耗）
    /// - Parameters:
    ///   - currentKwh: 当前电量 (kWh)
    ///   - chargeAmount: 需要充电的电量 (kWh)
    ///   - includeLoss: 是否考虑充电损耗，默认为true
    /// - Returns: 目标电量 (kWh)
    static func calculateTargetKwh(currentKwh: Double, chargeAmount: Double, includeLoss: Bool = true) -> Double {
        let actualChargeAmount = includeLoss ? chargeAmount * chargingLossCoefficient : chargeAmount
        return currentKwh + actualChargeAmount
    }
    
    /// 计算充电进度百分比
    /// - Parameters:
    ///   - initialKwh: 初始电量 (kWh)
    ///   - targetKwh: 目标电量 (kWh)
    ///   - chargedKwh: 已充电量 (kWh)
    /// - Returns: 充电进度百分比 (0-100)
    static func calculateChargingProgress(initialKwh: Double, targetKwh: Double, chargedKwh: Double) -> Double {
        let targetChargeAmount = targetKwh - initialKwh
        guard targetChargeAmount > 0 else { return 0 }
        let progress = chargedKwh / targetChargeAmount
        return min(100.0, max(0.0, progress * 100.0))
    }
    
    // MARK: - 续航里程计算
    
    /// 根据当前SOC和续航里程计算每1%SOC对应的续航里程
    /// - Parameters:
    ///   - currentSoc: 当前SOC (0-100)
    ///   - currentRange: 当前续航里程 (km)
    /// - Returns: 每1%SOC对应的续航里程 (km)
    static func calculateKmPerSocPercent(currentSoc: Double, currentRange: Int) -> Double {
        guard currentSoc > 0 else { return 0 }
        return Double(currentRange) / currentSoc
    }
    
    /// 根据目标SOC计算目标续航里程
    /// - Parameters:
    ///   - targetSoc: 目标SOC (0-100)
    ///   - currentSoc: 当前SOC (0-100)
    ///   - currentRange: 当前续航里程 (km)
    /// - Returns: 目标续航里程 (km)
    static func calculateTargetRange(targetSoc: Double, currentSoc: Double, currentRange: Int) -> Int {
        guard currentSoc > 0 else {
            // 如果当前SOC为0，使用默认能耗比估算
            return Int(targetSoc * defaultKmPerKwh)
        }
        
        let kmPerSocPercent = calculateKmPerSocPercent(currentSoc: currentSoc, currentRange: currentRange)
        return Int(targetSoc * kmPerSocPercent)
    }
    
    /// 根据电量计算续航里程（使用默认能耗比）
    /// - Parameter kwh: 电量 (kWh)
    /// - Returns: 续航里程 (km)
    static func calculateRangeFromKwh(_ kwh: Double) -> Int {
        return Int(kwh * defaultKmPerKwh)
    }
    
    /// 根据SOC和车型计算续航里程
    /// - Parameters:
    ///   - soc: 电池电量百分比 (0-100)
    ///   - carModel: 车型信息
    /// - Returns: 续航里程 (km)
    static func calculateRange(soc: Double, carModel: CarModel) -> Int {
        let batteryCapacity = getBatteryCapacity(from: carModel)
        let currentKwh = calculateCurrentKwh(soc: soc, batteryCapacity: batteryCapacity)
        
        // 使用车型的最大续航里程来计算每kWh的续航能力
        let (_, estimatedCapacity) = carModel.estimatedModelAndCapacity
        let maxRange = carModelConfigs.first { $0.value.batteryCapacity == estimatedCapacity }?.value.maxRange ?? 500
        let kmPerKwh = Double(maxRange) / estimatedCapacity
        
        return Int(currentKwh * kmPerKwh)
    }
    
    // MARK: - 充电时间估算
    
    /// 计算充电时间（分钟）
    /// - Parameters:
    ///   - remainingKwh: 需要充电的电量 (kWh)
    ///   - chargingPower: 充电功率 (kW)
    /// - Returns: 充电时间（分钟）
    static func calculateChargingTime(remainingKwh: Double, chargingPower: Double) -> Double {
        guard chargingPower > 0 else { return 0 }
        return remainingKwh / chargingPower * 60
    }
    
    /// 计算充电到指定SOC所需的电量
    /// - Parameters:
    ///   - currentSoc: 当前SOC (0-100)
    ///   - targetSoc: 目标SOC (0-100)
    ///   - batteryCapacity: 电池总容量 (kWh)
    /// - Returns: 需要充电的电量 (kWh)
    static func calculateRequiredChargeAmount(currentSoc: Double, targetSoc: Double, batteryCapacity: Double) -> Double {
        guard targetSoc > currentSoc, batteryCapacity > 0 else { return 0 }
        let currentKwh = calculateCurrentKwh(soc: currentSoc, batteryCapacity: batteryCapacity)
        let targetKwh = calculateCurrentKwh(soc: targetSoc, batteryCapacity: batteryCapacity)
        return targetKwh - currentKwh
    }
    
    // MARK: - 车型检测和电池容量估算
    
    /// 车型配置信息
    static let carModelConfigs: [String: (maxRange: Int, batteryCapacity: Double)] = [
        "405": (maxRange: 405, batteryCapacity: 41.0),
        "510": (maxRange: 510, batteryCapacity: 51.0),
        "610": (maxRange: 610, batteryCapacity: 61.0)
    ]
    
    /// 根据续航里程检测车型
    /// - Parameter range: 续航里程 (km)
    /// - Returns: 车型标识
    static func detectCarModel(byRange range: Int) -> String {
        let configs = carModelConfigs.sorted { $0.value.maxRange < $1.value.maxRange }
        
        for (model, config) in configs {
            if range <= config.maxRange + 20 { // 允许20km的误差
                return model
            }
        }
        
        return "405" // 默认返回405车型
    }
    
    /// 根据电量和SOC检测车型
    /// - Parameters:
    ///   - kwh: 当前电量 (kWh)
    ///   - soc: 当前SOC (0-100)
    /// - Returns: 车型标识
    static func detectCarModel(byKwh kwh: Double, soc: Double) -> String {
        guard soc > 0 else { return "405" }
        
        let estimatedCapacity = kwh / (soc / 100.0)
        var bestMatch = "405"
        var minDifference = Double.greatestFiniteMagnitude
        
        for (model, config) in carModelConfigs {
            let difference = abs(config.batteryCapacity - estimatedCapacity)
            if difference < minDifference {
                minDifference = difference
                bestMatch = model
            }
        }
        
        return bestMatch
    }
    
    // MARK: - 便利方法
    
    /// 从CarModel获取电池容量
    /// - Parameter carModel: 车辆模型
    /// - Returns: 电池容量 (kWh)
    static func getBatteryCapacity(from carModel: CarModel) -> Double {
        return carModel.estimatedModelAndCapacity.batteryCapacity
    }
    
    /// 从CarModel获取当前SOC
    /// - Parameter carModel: 车辆模型
    /// - Returns: 当前SOC (0-100)
    static func getCurrentSoc(from carModel: CarModel) -> Double {
        return Double(carModel.soc) ?? 0.0
    }
    
    /// 从CarModel计算当前电量
    /// - Parameter carModel: 车辆模型
    /// - Returns: 当前电量 (kWh)
    static func getCurrentKwh(from carModel: CarModel) -> Double {
        let soc = getCurrentSoc(from: carModel)
        let capacity = getBatteryCapacity(from: carModel)
        return calculateCurrentKwh(soc: soc, batteryCapacity: capacity)
    }
    
    /// 格式化电量显示
    /// - Parameter kwh: 电量 (kWh)
    /// - Returns: 格式化的电量字符串
    static func formatKwh(_ kwh: Double) -> String {
        return String(format: "%.1f", kwh)
    }
    
    /// 格式化SOC显示
    /// - Parameter soc: SOC百分比
    /// - Returns: 格式化的SOC字符串
    static func formatSoc(_ soc: Double) -> String {
        return String(format: "%.1f", soc)
    }
}

// MARK: - CarModel Extension

extension CarModel {
    /// 获取当前电量 (kWh)
    var currentKwh: Double {
        return BatteryCalculationUtility.getCurrentKwh(from: self)
    }
    
    /// 获取电池容量 (kWh)
    var batteryCapacity: Double {
        return BatteryCalculationUtility.getBatteryCapacity(from: self)
    }
    
    /// 获取当前SOC
    var currentSoc: Double {
        return BatteryCalculationUtility.getCurrentSoc(from: self)
    }
}