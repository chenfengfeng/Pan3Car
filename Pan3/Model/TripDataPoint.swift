//
//  TripDataPoint.swift
//  Pan3
//
//  Created by AI Assistant on 2025-11-02
//

import Foundation
import CoreData

@objc(TripDataPoint)
public class TripDataPoint: NSManagedObject {
    
    // MARK: - Core Data Properties
    
    @NSManaged public var timestamp: Date?
    @NSManaged public var lat: Double
    @NSManaged public var lon: Double
    @NSManaged public var soc: Int16
    @NSManaged public var remainingRangeKm: Int32
    @NSManaged public var totalMileage: String?
    @NSManaged public var keyStatus: String?
    @NSManaged public var mainLockStatus: String?
    @NSManaged public var calculatedSpeedKmh: Int32
    @NSManaged public var tripRecord: TripRecord?
    
    // MARK: - Convenience Initializer
    
    /// 便捷初始化方法
    convenience init(
        context: NSManagedObjectContext,
        timestamp: Date,
        lat: Double,
        lon: Double,
        soc: Int16,
        remainingRangeKm: Int32,
        totalMileage: String?,
        keyStatus: String?,
        mainLockStatus: String?,
        calculatedSpeedKmh: Int32
    ) {
        self.init(context: context)
        self.timestamp = timestamp
        self.lat = lat
        self.lon = lon
        self.soc = soc
        self.remainingRangeKm = remainingRangeKm
        self.totalMileage = totalMileage
        self.keyStatus = keyStatus
        self.mainLockStatus = mainLockStatus
        self.calculatedSpeedKmh = calculatedSpeedKmh
    }
    
    /// 从服务器数据创建数据点
    /// - Parameters:
    ///   - data: 服务器返回的数据字典
    ///   - context: Core Data上下文
    ///   - tripRecord: 关联的行程记录
    /// - Returns: 创建的数据点对象，如果解析失败返回nil
    static func create(from data: [String: Any], context: NSManagedObjectContext, tripRecord: TripRecord) -> TripDataPoint? {
        // 解析时间戳
        guard let timestampString = data["timestamp"] as? String else {
            print("[TripDataPoint] 缺少timestamp字段")
            return nil
        }
        
        // 解析时间 - 支持多种格式
        func parseDate(_ dateString: String) -> Date? {
            // 尝试ISO8601格式
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            // 尝试不带毫秒的ISO8601格式
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            // 尝试标准格式
            let standardFormatter = DateFormatter()
            standardFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            standardFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = standardFormatter.date(from: dateString) {
                return date
            }
            
            return nil
        }
        
        guard let timestamp = parseDate(timestampString) else {
            print("[TripDataPoint] 时间解析失败：\(timestampString)")
            return nil
        }
        
        // 创建数据点
        let dataPoint = TripDataPoint(context: context)
        dataPoint.timestamp = timestamp
        dataPoint.lat = data["lat"] as? Double ?? 0.0
        dataPoint.lon = data["lon"] as? Double ?? 0.0
        dataPoint.soc = Int16(data["soc"] as? Int ?? 0)
        dataPoint.remainingRangeKm = Int32(data["remaining_range_km"] as? Int ?? 0)
        dataPoint.totalMileage = data["total_mileage"] as? String
        dataPoint.keyStatus = data["keyStatus"] as? String
        dataPoint.mainLockStatus = data["mainLockStatus"] as? String
        dataPoint.calculatedSpeedKmh = Int32(data["calculated_speed_kmh"] as? Int ?? 0)
        
        // 关联到行程记录
        dataPoint.tripRecord = tripRecord
        
        return dataPoint
    }
    
    /// 创建fetch request
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TripDataPoint> {
        return NSFetchRequest<TripDataPoint>(entityName: "TripDataPoint")
    }
    
    /// 创建fetch request（获取指定行程的数据点）
    public class func fetchRequest(for tripRecord: TripRecord) -> NSFetchRequest<TripDataPoint> {
        let request: NSFetchRequest<TripDataPoint> = fetchRequest()
        request.predicate = NSPredicate(format: "tripRecord == %@", tripRecord)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return request
    }
    
    /// 创建fetch request（获取指定时间范围的数据点）
    public class func fetchRequest(from startDate: Date, to endDate: Date) -> NSFetchRequest<TripDataPoint> {
        let request: NSFetchRequest<TripDataPoint> = fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return request
    }
}

extension TripDataPoint : Identifiable {
    
}

