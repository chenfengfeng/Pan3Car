//
//  TripRecord.swift
//  Pan3
//
//  Created by AI Assistant on 2025-11-02
//

import Foundation
import CoreData

@objc(TripRecord)
public class TripRecord: NSManagedObject {
    
    // MARK: - Core Data Properties
    
    @NSManaged public var id: Int64
    @NSManaged public var recordID: String?
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var startSoc: Int16
    @NSManaged public var endSoc: Int16
    @NSManaged public var startRangeKm: Int32
    @NSManaged public var endRangeKm: Int32
    @NSManaged public var startLat: Double
    @NSManaged public var startLon: Double
    @NSManaged public var endLat: Double
    @NSManaged public var endLon: Double
    @NSManaged public var totalDistance: Double
    @NSManaged public var consumedRange: Int32
    @NSManaged public var maxSpeed: Int32
    @NSManaged public var avgSpeed: Int32
    @NSManaged public var dataPoints: NSSet?
    
    // MARK: - Address Properties
    
    @NSManaged public var startAddress: String?
    @NSManaged public var endAddress: String?
    @NSManaged public var startCity: String?
    @NSManaged public var endCity: String?
    
    // MARK: - Computed Properties
    
    /// 计算行程持续时间（格式化字符串）
    var tripDuration: String {
        guard let endTime = endTime else {
            return "进行中"
        }
        
        let duration = endTime.timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return String(format: "%d小时%d分钟", hours, minutes)
        } else {
            return String(format: "%d分钟", minutes)
        }
    }
    
    /// 计算达成率（实际里程 / 消耗续航）
    var achievementRate: Double {
        guard consumedRange > 0, totalDistance > 0 else {
            return 0.0
        }
        return (totalDistance / Double(consumedRange)) * 100.0
    }
    
    /// 根据起始SOC和续航里程推断电池容量（kWh）
    var estimatedBatteryCapacity: Double {
        // 车型配置：(续航里程, 电池容量)
        let modelConfigs: [(maxRange: Int, batteryCapacity: Double)] = [
            (330, 34.5),
            (405, 41.0),
            (505, 51.5)
        ]
        
        // 方法1：根据起始续航里程和SOC推断
        if startSoc > 0 {
            // 计算满电续航 = 当前续航 / (当前SOC / 100)
            let estimatedFullRange = Double(startRangeKm) / (Double(startSoc) / 100.0)
            
            // 匹配最接近的车型配置（允许±20km误差）
            let tolerance = 20.0
            let matchedConfig = modelConfigs
                .filter { abs(Double($0.maxRange) - estimatedFullRange) <= tolerance }
                .min { abs(Double($0.maxRange) - estimatedFullRange) < abs(Double($1.maxRange) - estimatedFullRange) }
            
            if let config = matchedConfig {
                return config.batteryCapacity
            }
        }
        
        // 方法2：根据续航里程范围粗略判断（兜底方案）
        if startRangeKm <= 350 {
            return 34.5  // 330车型
        } else if startRangeKm <= 455 {
            return 41.0  // 405车型
        } else {
            return 51.5  // 505车型
        }
    }
    
    /// 计算能耗（kWh/100km）
    var energyEfficiency: Double {
        guard totalDistance > 0 else {
            return 0.0
        }
        let socConsumed = Double(startSoc - endSoc)
        let batteryCapacity = estimatedBatteryCapacity
        let energyConsumed = socConsumed / 100.0 * batteryCapacity
        return (energyConsumed / totalDistance) * 100.0
    }
    
    /// 计算电量消耗百分比
    var powerConsumption: Double {
        return Double(startSoc - endSoc)
    }
    
    // MARK: - Address Helper Methods
    
    /// 判断是否需要进行地址解析
    var needsGeocoding: Bool {
        // 如果起点或终点地址为空（或标记为解析中），且 GPS 坐标有效，则需要解析
        let hasValidStartCoords = startLat != 0 && startLon != 0
        let hasValidEndCoords = endLat != 0 && endLon != 0
        
        // 排除已标记为"解析失败"的记录
        let startNeedsGeocoding = hasValidStartCoords && 
            (startAddress == nil || startAddress == "位置解析中...")
        let endNeedsGeocoding = hasValidEndCoords && 
            (endAddress == nil || endAddress == "位置解析中...")
        
        return startNeedsGeocoding || endNeedsGeocoding
    }
    
    /// 获取起点地址显示文本（如果未解析则返回占位文本）
    var displayStartAddress: String {
        if let address = startAddress, !address.isEmpty {
            // 如果地址是"解析失败"，返回更友好的提示
            if address == "解析失败" {
                return "位置未知"
            }
            return address
        }
        if startLat == 0 && startLon == 0 {
            return "未知位置"
        }
        return "位置解析中..."
    }
    
    /// 获取终点地址显示文本（如果未解析则返回占位文本）
    var displayEndAddress: String {
        if let address = endAddress, !address.isEmpty {
            // 如果地址是"解析失败"，返回更友好的提示
            if address == "解析失败" {
                return "位置未知"
            }
            return address
        }
        if endLat == 0 && endLon == 0 {
            return "未知位置"
        }
        return "位置解析中..."
    }
    
    /// 更新起点地址信息
    /// - Parameters:
    ///   - address: 格式化后的地址
    ///   - city: 城市名（用于智能格式化比较）
    func updateStartAddress(_ address: String, city: String?) {
        self.startAddress = address
        self.startCity = city
    }
    
    /// 更新终点地址信息
    /// - Parameters:
    ///   - address: 格式化后的地址
    ///   - city: 城市名（用于智能格式化比较）
    func updateEndAddress(_ address: String, city: String?) {
        self.endAddress = address
        self.endCity = city
    }
}

// MARK: - Fetch Request

extension TripRecord {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TripRecord> {
        return NSFetchRequest<TripRecord>(entityName: "TripRecord")
    }
}

// MARK: - Generated accessors for dataPoints
extension TripRecord {
    
    @objc(addDataPointsObject:)
    @NSManaged public func addToDataPoints(_ value: TripDataPoint)
    
    @objc(removeDataPointsObject:)
    @NSManaged public func removeFromDataPoints(_ value: TripDataPoint)
    
    @objc(addDataPoints:)
    @NSManaged public func addToDataPoints(_ values: NSSet)
    
    @objc(removeDataPoints:)
    @NSManaged public func removeFromDataPoints(_ values: NSSet)
}

extension TripRecord : Identifiable {
    
}

