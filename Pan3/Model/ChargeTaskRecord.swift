import Foundation
import CoreData

/// 充电任务记录 - Core Data实体类
/// 对应Core Data模型中的ChargeRecord实体
@objc(ChargeTaskRecord)
public class ChargeTaskRecord: NSManagedObject {
    
    // MARK: - Core Data Properties
    
    @NSManaged public var startTime: Date
    @NSManaged public var endTime: Date?
    @NSManaged public var startSoc: Int16
    @NSManaged public var endSoc: Int16
    @NSManaged public var startKm: Int64
    @NSManaged public var endKm: Int64
    @NSManaged public var lat: Double
    @NSManaged public var lon: Double
    @NSManaged public var address: String?
    @NSManaged public var recordID: String?
    
    // MARK: - Relationships
    
    @NSManaged public var dataPoints: NSSet?
    
    // MARK: - Computed Properties
    
    /// 充电时长（基于开始/结束时间）
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
    
    /// 是否为未完成的充电记录
    var isUnfinished: Bool {
        return endTime == nil
    }
    
    /// 是否需要地理编码（有经纬度但没有地址）
    var needsGeocoding: Bool {
        return (lat != 0.0 && lon != 0.0) && (address == nil || address?.isEmpty == true)
    }
    
    /// SOC增量
    var socGain: Int16 {
        guard endTime != nil else { return 0 }
        return endSoc - startSoc
    }
    
    /// 里程增量
    var kmGain: Int64 {
        guard endTime != nil else { return 0 }
        return endKm - startKm
    }
    
    // MARK: - 兼容旧UI的计算属性
    
    /// 字符串形式的开始时间（用于Cell展示）
    var createdAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter.string(from: startTime)
    }
    
    /// 字符串形式的结束时间（用于Cell展示）
    var finishTime: String? {
        guard let end = endTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: end)
    }
    
    // MARK: - Convenience Initializers
    
    /// 创建新的充电记录
    convenience init(context: NSManagedObjectContext,
                    startTime: Date,
                    startSoc: Int16,
                    startKm: Int64,
                    lat: Double = 0.0,
                    lon: Double = 0.0,
                    address: String? = nil) {
        self.init(context: context)
        
        self.startTime = startTime
        self.startSoc = startSoc
        self.startKm = startKm
        self.lat = lat
        self.lon = lon
        self.address = address
        
        // 设置默认值
        self.endSoc = 0
        self.endKm = 0
    }
    
    // MARK: - Update Methods
    
    /// 更新充电结束信息
    func updateEndInfo(endTime: Date, endSoc: Int16, endKm: Int64) {
        self.endTime = endTime
        self.endSoc = endSoc
        self.endKm = endKm
    }
    
    /// 更新地址信息
    func updateAddress(_ address: String) {
        self.address = address
    }
    
    /// 更新位置信息
    func updateLocation(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

// MARK: - Core Data Fetch Request

extension ChargeTaskRecord {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChargeTaskRecord> {
        return NSFetchRequest<ChargeTaskRecord>(entityName: "ChargeRecord")
    }
    
    /// 获取所有充电记录的请求，按开始时间降序排列
    @nonobjc public class func fetchAllRequest() -> NSFetchRequest<ChargeTaskRecord> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        return request
    }
    
    /// 获取未完成充电记录的请求
    @nonobjc public class func fetchUnfinishedRequest() -> NSFetchRequest<ChargeTaskRecord> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "endTime == nil")
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        return request
    }
}

// MARK: - ChargeTaskModel Conversion

extension ChargeTaskRecord {
    
    /// 转换为ChargeTaskModel（用于兼容现有UI代码）
    func toChargeTaskModel() -> ChargeTaskModel {
        return ChargeTaskModel(
            id: Int(startTime.timeIntervalSince1970), // 使用时间戳作为临时ID
            vin: "", // ChargeTaskModel需要但ChargeTaskRecord不存储的字段
            startKm: Int(startKm),
            endKm: Int(endKm),
            status: endTime != nil ? "completed" : "charging",
            message: "",
            createdAt: ISO8601DateFormatter().string(from: startTime),
            finishTime: endTime != nil ? ISO8601DateFormatter().string(from: endTime!) : nil,
            lat: lat,
            lon: lon,
            address: address
        )
    }
}

// MARK: - Identifiable

extension ChargeTaskRecord: Identifiable {
    public var id: NSManagedObjectID {
        return objectID
    }
}

// MARK: - DataPoints Relationship Helpers

extension ChargeTaskRecord {
    
    /// 获取排序后的数据点数组
    var sortedDataPoints: [ChargeDataPoint] {
        let set = dataPoints as? Set<ChargeDataPoint> ?? []
        return set.sorted { $0.timestamp ?? Date() < $1.timestamp ?? Date() }
    }
    
    /// 数据点数量
    var dataPointsCount: Int {
        return dataPoints?.count ?? 0
    }
    
    /// 添加数据点
    @objc(addDataPointsObject:)
    @NSManaged public func addToDataPoints(_ value: ChargeDataPoint)
    
    /// 移除数据点
    @objc(removeDataPointsObject:)
    @NSManaged public func removeFromDataPoints(_ value: ChargeDataPoint)
    
    /// 批量添加数据点
    @objc(addDataPoints:)
    @NSManaged public func addToDataPoints(_ values: NSSet)
    
    /// 批量移除数据点
    @objc(removeDataPoints:)
    @NSManaged public func removeFromDataPoints(_ values: NSSet)
}
