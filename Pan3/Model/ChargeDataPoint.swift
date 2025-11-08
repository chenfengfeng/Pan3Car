//
//  ChargeDataPoint.swift
//  Pan3
//
//  Created by AI Assistant on 2025
//

import Foundation
import CoreData

/// 充电数据点 - Core Data实体类
/// 对应Core Data模型中的ChargeDataPoint实体
/// 存储充电过程中的详细数据点信息
@objc(ChargeDataPoint)
public class ChargeDataPoint: NSManagedObject {
    
    // MARK: - Core Data Properties
    
    @NSManaged public var timestamp: Date?
    @NSManaged public var lat: Double
    @NSManaged public var lon: Double
    @NSManaged public var soc: Int16
    @NSManaged public var remainingRangeKm: Int32
    @NSManaged public var totalMileage: String?
    @NSManaged public var keyStatus: String?
    @NSManaged public var mainLockStatus: String?
    @NSManaged public var chgPlugStatus: String?
    @NSManaged public var chgStatus: String?
    @NSManaged public var chgLeftTime: Int32
    
    // MARK: - Relationships
    
    @NSManaged public var chargeRecord: ChargeTaskRecord?
    
    // MARK: - Computed Properties
    
    /// 格式化的时间戳字符串
    var formattedTimestamp: String {
        guard let timestamp = timestamp else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    /// 是否正在充电
    var isCharging: Bool {
        // chgStatus != "2" 表示正在充电
        return chgStatus != nil && chgStatus != "2"
    }
    
    /// 剩余充电时间（分钟）
    var remainingChargeMinutes: Int {
        return Int(chgLeftTime)
    }
    
    // MARK: - Convenience Initializers
    
    /// 创建新的充电数据点
    convenience init(
        context: NSManagedObjectContext,
        timestamp: Date?,
        lat: Double,
        lon: Double,
        soc: Int16,
        remainingRangeKm: Int32,
        totalMileage: String?,
        keyStatus: String?,
        mainLockStatus: String?,
        chgPlugStatus: String?,
        chgStatus: String?,
        chgLeftTime: Int32
    ) {
        self.init(context: context)
        
        self.timestamp = timestamp ?? Date()
        self.lat = lat
        self.lon = lon
        self.soc = soc
        self.remainingRangeKm = remainingRangeKm
        self.totalMileage = totalMileage
        self.keyStatus = keyStatus
        self.mainLockStatus = mainLockStatus
        self.chgPlugStatus = chgPlugStatus
        self.chgStatus = chgStatus
        self.chgLeftTime = chgLeftTime
    }
}

// MARK: - Core Data Fetch Request

extension ChargeDataPoint {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChargeDataPoint> {
        return NSFetchRequest<ChargeDataPoint>(entityName: "ChargeDataPoint")
    }
    
    /// 获取指定充电记录的所有数据点，按时间升序排列
    @nonobjc public class func fetchRequest(for chargeRecord: ChargeTaskRecord) -> NSFetchRequest<ChargeDataPoint> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "chargeRecord == %@", chargeRecord)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return request
    }
    
    /// 获取指定时间范围内的数据点
    @nonobjc public class func fetchRequest(from startDate: Date, to endDate: Date) -> NSFetchRequest<ChargeDataPoint> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return request
    }
}

// MARK: - Identifiable

extension ChargeDataPoint: Identifiable {
    public var id: NSManagedObjectID {
        return objectID
    }
}

// MARK: - JSON Conversion

extension ChargeDataPoint {
    
    /// 从服务器返回的JSON数据创建数据点
    /// - Parameters:
    ///   - json: JSON字典
    ///   - context: Core Data上下文
    ///   - chargeRecord: 关联的充电记录
    /// - Returns: 创建的数据点对象
    static func create(from json: [String: Any], context: NSManagedObjectContext, chargeRecord: ChargeTaskRecord) -> ChargeDataPoint? {
        let dataPoint = ChargeDataPoint(context: context)
        
        // 解析时间戳
        if let timestampString = json["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: timestampString) {
                dataPoint.timestamp = date
            } else {
                // 尝试其他格式
                let alternativeFormatter = DateFormatter()
                alternativeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                if let date = alternativeFormatter.date(from: timestampString) {
                    dataPoint.timestamp = date
                } else {
                    return nil
                }
            }
        } else {
            return nil
        }
        
        // 解析其他字段
        dataPoint.lat = json["lat"] as? Double ?? 0.0
        dataPoint.lon = json["lon"] as? Double ?? 0.0
        dataPoint.soc = Int16(json["soc"] as? Int ?? 0)
        dataPoint.remainingRangeKm = Int32(json["remaining_range_km"] as? Int ?? 0)
        dataPoint.totalMileage = json["total_mileage"] as? String
        dataPoint.keyStatus = json["keyStatus"] as? String
        dataPoint.mainLockStatus = json["mainLockStatus"] as? String
        dataPoint.chgPlugStatus = json["chgPlugStatus"] as? String
        dataPoint.chgStatus = json["chgStatus"] as? String
        dataPoint.chgLeftTime = Int32(json["chgLeftTime"] as? Int ?? 0)
        
        // 关联充电记录
        dataPoint.chargeRecord = chargeRecord
        
        return dataPoint
    }
}

