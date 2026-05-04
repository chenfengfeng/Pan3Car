import Foundation
import CoreData
import CloudKit

/// Core Data + CloudKit 数据管理器
/// 负责管理应用的数据持久化和CloudKit同步
class CoreDataManager {

    // MARK: - Singleton
    static let shared = CoreDataManager()

    private init() {
        setupNotifications()

        // 初始化CloudKit同步管理器
        DispatchQueue.main.async {
            _ = CloudKitSyncManager.shared
            print("[CoreData] CloudKit同步管理器已初始化")
        }
    }

    // MARK: - Core Data Stack

    /// 持久化容器，支持CloudKit同步
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "Model")

        // 配置CloudKit
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        // 启用CloudKit同步
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // 配置轻量级迁移（适配版本升级）
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        // 配置CloudKit容器标识符
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.dream.pan3car"
        )

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // 在生产环境中，应该有更好的错误处理
                print("Core Data error: \(error), \(error.userInfo)")

                // 如果是迁移错误，尝试删除并重建（仅用于开发调试）
                #if DEBUG
                if error.code == NSPersistentStoreIncompatibleVersionHashError {
                    print("[CoreData] 检测到模型版本不兼容，尝试自动迁移...")
                }
                #endif

                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("[CoreData] 成功加载持久化存储: \(storeDescription.url?.lastPathComponent ?? "unknown")")
            }
        }

        // 自动合并来自父上下文的更改
        container.viewContext.automaticallyMergesChangesFromParent = true

        return container
    }()

    /// 主上下文（UI线程）
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    /// 创建后台上下文
    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }

    // MARK: - Core Data Saving

    /// 保存主上下文
    func saveContext() {
        let context = persistentContainer.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("保存上下文失败: \(nsError), \(nsError.userInfo)")
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    /// 保存指定上下文
    func save(context: NSManagedObjectContext) {
        context.perform {
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("保存上下文失败: \(error)")
                }
            }
        }
    }

    // MARK: - CloudKit Notifications

    private func setupNotifications() {
        // 监听远程更改通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator
        )
    }

    @objc private func storeRemoteChange(_ notification: Notification) {
        // 通知UI更新
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .coreDataDidUpdateFromCloudKit, object: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - ChargeTaskRecord CRUD Operations

extension CoreDataManager {

    /// 创建新的充电记录
    func createChargeRecord(
        startTime: Date,
        startSoc: Int16,
        startKm: Int64,
        lat: Double? = nil,
        lon: Double? = nil,
        address: String? = nil
    ) -> ChargeTaskRecord {
        let context = viewContext
        let record = ChargeTaskRecord(context: context)

        record.startTime = startTime
        record.startSoc = startSoc
        record.startKm = startKm
        record.lat = lat ?? 0.0
        record.lon = lon ?? 0.0
        record.address = address

        saveContext()
        return record
    }

    /// 创建完整的充电记录（包含结束信息）
    func createChargeRecord(
        startTime: Date,
        endTime: Date?,
        startSoc: Int16,
        endSoc: Int16,
        startKm: Int64,
        endKm: Int64,
        lat: Double? = nil,
        lon: Double? = nil,
        address: String? = nil,
        recordID: String? = nil
    ) -> ChargeTaskRecord {
        let context = viewContext
        let record = ChargeTaskRecord(context: context)

        record.startTime = startTime
        record.endTime = endTime
        record.startSoc = startSoc
        record.endSoc = endSoc
        record.startKm = startKm
        record.endKm = endKm
        record.lat = lat ?? 0.0
        record.lon = lon ?? 0.0
        record.address = address
        record.recordID = recordID

        saveContext()
        return record
    }

    /// 更新充电记录结束信息
    func updateChargeRecord(
        _ record: ChargeTaskRecord,
        endTime: Date? = nil,
        endSoc: Int16? = nil,
        endKm: Int64? = nil,
        address: String? = nil
    ) {
        if let endTime = endTime {
            record.endTime = endTime
        }
        if let endSoc = endSoc {
            record.endSoc = endSoc
        }
        if let endKm = endKm {
            record.endKm = endKm
        }
        if let address = address {
            record.address = address
        }

        saveContext()
    }

    /// 获取所有充电记录，按开始时间降序排列
    func fetchChargeRecords(limit: Int? = nil, offset: Int = 0) -> [ChargeTaskRecord] {
        let request: NSFetchRequest<ChargeTaskRecord> = ChargeTaskRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

        if let limit = limit {
            request.fetchLimit = limit
            request.fetchOffset = offset
        }

        do {
            return try viewContext.fetch(request)
        } catch {
            print("获取充电记录失败: \(error)")
            return []
        }
    }

    /// 在指定上下文中获取充电记录（支持后台线程）
    func fetchChargeRecords(limit: Int? = nil, offset: Int = 0, context: NSManagedObjectContext) -> [ChargeTaskRecord] {
        let request: NSFetchRequest<ChargeTaskRecord> = ChargeTaskRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

        if let limit = limit {
            request.fetchLimit = limit
            request.fetchOffset = offset
        }

        do {
            return try context.fetch(request)
        } catch {
            print("获取充电记录失败: \(error)")
            return []
        }
    }

    /// 执行后台任务的便捷方法
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) -> T, completion: @escaping (T) -> Void) {
        let context = newBackgroundContext()
        context.perform {
            let result = block(context)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// 获取最新的未完成充电记录（没有结束时间的记录）
    func fetchLatestUnfinishedChargeRecord() -> ChargeTaskRecord? {
        let request: NSFetchRequest<ChargeTaskRecord> = ChargeTaskRecord.fetchRequest()
        request.predicate = NSPredicate(format: "endTime == nil")
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        request.fetchLimit = 1

        do {
            return try viewContext.fetch(request).first
        } catch {
            print("获取未完成充电记录失败: \(error)")
            return nil
        }
    }

    /// 删除充电记录
    func deleteChargeRecord(_ record: ChargeTaskRecord) {
        viewContext.delete(record)
        saveContext()
    }

    /// 通过ID删除充电记录
    func deleteChargeRecord(withID id: Int64?) throws {
        guard let id = id else {
            throw NSError(domain: "CoreDataManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "无效的记录ID"])
        }

        // 由于ChargeTaskModel使用时间戳作为ID，我们需要通过startTime查找记录
        let timestamp = TimeInterval(id)
        let targetDate = Date(timeIntervalSince1970: timestamp)

        let request: NSFetchRequest<ChargeTaskRecord> = ChargeTaskRecord.fetchRequest()
        request.predicate = NSPredicate(format: "startTime == %@", targetDate as NSDate)
        request.fetchLimit = 1

        do {
            let records = try viewContext.fetch(request)
            if let record = records.first {
                viewContext.delete(record)
                saveContext()
            } else {
                throw NSError(domain: "CoreDataManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "未找到指定的充电记录"])
            }
        } catch {
            throw error
        }
    }

    /// 删除所有充电记录
    func deleteAllChargeRecords() {
        let request: NSFetchRequest<NSFetchRequestResult> = ChargeTaskRecord.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try viewContext.execute(deleteRequest)
            saveContext()
        } catch {
            print("删除所有充电记录失败: \(error)")
        }
    }

    /// 从服务器同步充电记录到本地数据库
    /// - Parameter chargesData: 服务器返回的充电记录数组（包含data_points）
    /// - Returns: 成功保存的充电记录数组
    func syncChargeRecordsFromServer(_ chargesData: [[String: Any]]) -> [ChargeTaskRecord] {
        var savedRecords: [ChargeTaskRecord] = []

        // 使用后台上下文进行批量操作
        let context = newBackgroundContext()

        context.performAndWait {
            for chargeJson in chargesData {
                // 解析充电记录基本信息
                guard let startTimeString = chargeJson["start_time"] as? String else {
                    print("[CoreDataManager] 跳过无效的充电记录：缺少start_time")
                    continue
                }

                // 解析时间 - 支持多种格式
                func parseDate(_ dateString: String) -> Date? {
                    // 尝试ISO8601格式（服务器返回格式：2025-11-02T04:43:06.286Z）
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

                    // 尝试标准格式（yyyy-MM-dd HH:mm:ss）
                    let standardFormatter = DateFormatter()
                    standardFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    standardFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    if let date = standardFormatter.date(from: dateString) {
                        return date
                    }

                    return nil
                }

                guard let startTime = parseDate(startTimeString) else {
                    print("[CoreDataManager] 时间解析失败：\(startTimeString)")
                    continue
                }

                let endTime: Date?
                if let endTimeString = chargeJson["end_time"] as? String {
                    endTime = parseDate(endTimeString)
                } else {
                    endTime = nil
                }

                // 检查是否已存在该记录（只通过startTime，避免服务器ID重用导致的误判）
                let recordID = String(chargeJson["id"] as? Int ?? 0)
                let existingRecordRequest: NSFetchRequest<ChargeTaskRecord> = ChargeTaskRecord.fetchRequest()
                existingRecordRequest.predicate = NSPredicate(format: "startTime == %@", startTime as NSDate)
                existingRecordRequest.fetchLimit = 1

                do {
                    let existingRecords = try context.fetch(existingRecordRequest)
                    if let existingRecord = existingRecords.first {
                        print("[CoreDataManager] 跳过已存在的充电记录：开始时间=\(startTime), ID=\(recordID)")
                        continue
                    }
                } catch {
                    print("[CoreDataManager] 查询已存在记录失败：\(error)")
                }

                // 创建新的充电记录
                let record = ChargeTaskRecord(context: context)
                record.recordID = recordID
                record.startTime = startTime
                record.endTime = endTime
                record.startSoc = Int16(chargeJson["start_soc"] as? Int ?? 0)
                record.endSoc = Int16(chargeJson["end_soc"] as? Int ?? 0)
                record.startKm = Int64(chargeJson["start_range_km"] as? Int ?? 0)
                record.endKm = Int64(chargeJson["end_range_km"] as? Int ?? 0)
                record.lat = chargeJson["lat"] as? Double ?? 0.0
                record.lon = chargeJson["lon"] as? Double ?? 0.0
                record.address = chargeJson["address"] as? String
                // 保存数据来源和状态
                record.dataSource = chargeJson["data_source"] as? String
                record.summaryStatus = chargeJson["summary_status"] as? String

                // 解析并创建数据点
                if let dataPointsArray = chargeJson["data_points"] as? [[String: Any]] {
                    print("[CoreDataManager] 正在保存 \(dataPointsArray.count) 个数据点...")

                    // 打印第一个数据点的原始数据用于调试
                    if let firstPoint = dataPointsArray.first {
                        print("[CoreDataManager] 第一个数据点原始数据: \(firstPoint)")
                    }

                    for dataPointJson in dataPointsArray {
                        if let dataPoint = ChargeDataPoint.create(from: dataPointJson, context: context, chargeRecord: record) {
                            // 数据点已自动关联到record
                        } else {
                            print("[CoreDataManager] 数据点创建失败，原始数据: \(dataPointJson)")
                        }
                    }
                } else {
                    print("[CoreDataManager] data_points 字段不存在或格式错误，原始值: \(chargeJson["data_points"] ?? "nil")")
                }

                savedRecords.append(record)
                print("[CoreDataManager] 成功保存充电记录：ID=\(recordID), 数据点数量=\(record.dataPoints?.count ?? 0)")
            }

            // 批量保存
            if context.hasChanges {
                do {
                    try context.save()
                    print("[CoreDataManager] 批量保存成功：共 \(savedRecords.count) 条充电记录")
                } catch {
                    print("[CoreDataManager] 保存失败：\(error)")
                    savedRecords.removeAll()
                }
            }
        }

        return savedRecords
    }

    @discardableResult
    func syncChargeSummariesV3(upserts: [ChargeSyncItem], deletes: [String]) -> Int {
        var changedCount = 0
        let context = newBackgroundContext()

        context.performAndWait {
            for clientChargeID in deletes {
                if let record = fetchChargeRecord(clientChargeID: clientChargeID, context: context) {
                    context.delete(record)
                    changedCount += 1
                }
            }

            for item in upserts {
                let record = fetchChargeRecord(clientChargeID: item.clientChargeID, context: context) ?? ChargeTaskRecord(context: context)
                applyChargeSyncItem(item, to: record)
                changedCount += 1
            }

            if context.hasChanges {
                do {
                    try context.save()
                    print("[CoreDataManager] V3充电摘要保存成功：upserts=\(upserts.count), deletes=\(deletes.count)")
                } catch {
                    print("[CoreDataManager] V3充电摘要保存失败：\(error)")
                    changedCount = 0
                }
            }
        }

        return changedCount
    }

    @discardableResult
    func saveChargePointsV3(_ points: [ChargePointItem], clientChargeID: String) -> Int {
        guard !points.isEmpty else { return 0 }
        var savedCount = 0
        let context = newBackgroundContext()

        context.performAndWait {
            guard let record = fetchChargeRecord(clientChargeID: clientChargeID, context: context) else {
                print("[CoreDataManager] 未找到充电记录，跳过过程点保存：\(clientChargeID)")
                return
            }

            for item in points {
                let point = fetchChargePoint(timestampMs: item.timestampMs, chargeRecord: record, context: context) ?? ChargeDataPoint(context: context)
                point.chargeRecord = record
                point.timestampMs = item.timestampMs
                point.timestamp = dateFromMilliseconds(item.timestampMs)
                point.voltage = item.voltage
                point.current = item.current
                point.power = item.powerKw
                point.soc = Int16(clamping: item.soc ?? 0)
                point.remainingRangeKmDouble = item.remainingRangeKm ?? 0
                point.remainingRangeKm = Int32(clamping: Int((item.remainingRangeKm ?? 0).rounded()))
                point.lat = 0
                point.lon = 0
                point.totalMileage = nil
                point.keyStatus = nil
                point.mainLockStatus = nil
                point.chgPlugStatus = nil
                point.chgStatus = nil
                point.chgLeftTime = 0
                savedCount += 1
            }

            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("[CoreDataManager] V3充电过程点保存失败：\(error)")
                    savedCount = 0
                }
            }
        }

        return savedCount
    }

    func chargePointsTargetCount(clientChargeID: String) -> Int64 {
        var count: Int64 = 0
        let context = newBackgroundContext()
        context.performAndWait {
            count = fetchChargeRecord(clientChargeID: clientChargeID, context: context)?.pointsCount ?? 0
        }
        return count
    }
}

// MARK: - CloudKit Status

extension CoreDataManager {

    /// 检查CloudKit账户状态
    func checkCloudKitAccountStatus(completion: @escaping (CKAccountStatus) -> Void) {
        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("CloudKit账户状态检查失败: \(error)")
                }
                completion(status)
            }
        }
    }

    /// 获取CloudKit同步状态描述
    func getCloudKitStatusDescription() -> String {
        // 这里可以添加更详细的CloudKit状态检查逻辑
        return "CloudKit同步已启用"
    }
}

// MARK: - ChargeDataPoint CRUD Operations

extension CoreDataManager {

    /// 批量创建充电数据点
    /// - Parameters:
    ///   - dataPointsData: 数据点数据数组
    ///   - chargeRecord: 关联的充电记录
    /// - Returns: 创建的数据点数组
    func createChargeDataPoints(from dataPointsData: [[String: Any]], for chargeRecord: ChargeTaskRecord) -> [ChargeDataPoint] {
        let context = viewContext
        var dataPoints: [ChargeDataPoint] = []

        for data in dataPointsData {
            if let dataPoint = ChargeDataPoint.create(from: data, context: context, chargeRecord: chargeRecord) {
                dataPoints.append(dataPoint)
            }
        }

        saveContext()
        return dataPoints
    }

    /// 创建单个充电数据点
    /// - Parameters:
    ///   - timestamp: 时间戳
    ///   - lat: 纬度
    ///   - lon: 经度
    ///   - soc: 电量百分比
    ///   - remainingRangeKm: 剩余续航
    ///   - totalMileage: 总里程
    ///   - keyStatus: 钥匙状态
    ///   - mainLockStatus: 主锁状态
    ///   - chgPlugStatus: 充电插头状态
    ///   - chgStatus: 充电状态
    ///   - chgLeftTime: 剩余充电时间
    ///   - chargeRecord: 关联的充电记录
    /// - Returns: 创建的数据点
    func createChargeDataPoint(
        timestamp: Date,
        lat: Double,
        lon: Double,
        soc: Int16,
        remainingRangeKm: Int32,
        totalMileage: String?,
        keyStatus: String?,
        mainLockStatus: String?,
        chgPlugStatus: String?,
        chgStatus: String?,
        chgLeftTime: Int32,
        for chargeRecord: ChargeTaskRecord
    ) -> ChargeDataPoint {
        let context = viewContext
        let dataPoint = ChargeDataPoint(
            context: context,
            timestamp: timestamp,
            lat: lat,
            lon: lon,
            soc: soc,
            remainingRangeKm: remainingRangeKm,
            totalMileage: totalMileage,
            keyStatus: keyStatus,
            mainLockStatus: mainLockStatus,
            chgPlugStatus: chgPlugStatus,
            chgStatus: chgStatus,
            chgLeftTime: chgLeftTime
        )

        dataPoint.chargeRecord = chargeRecord
        saveContext()
        return dataPoint
    }

    /// 获取指定充电记录的所有数据点
    /// - Parameter chargeRecord: 充电记录
    /// - Returns: 数据点数组，按时间升序排列
    func fetchChargeDataPoints(for chargeRecord: ChargeTaskRecord) -> [ChargeDataPoint] {
        let request = ChargeDataPoint.fetchRequest(for: chargeRecord)

        do {
            return try viewContext.fetch(request)
        } catch {
            print("获取充电数据点失败: \(error)")
            return []
        }
    }

    /// 获取指定时间范围内的数据点
    /// - Parameters:
    ///   - startDate: 开始时间
    ///   - endDate: 结束时间
    /// - Returns: 数据点数组
    func fetchChargeDataPoints(from startDate: Date, to endDate: Date) -> [ChargeDataPoint] {
        let request = ChargeDataPoint.fetchRequest(from: startDate, to: endDate)

        do {
            return try viewContext.fetch(request)
        } catch {
            print("获取充电数据点失败: \(error)")
            return []
        }
    }

    /// 删除指定充电记录的所有数据点
    /// - Parameter chargeRecord: 充电记录
    func deleteChargeDataPoints(for chargeRecord: ChargeTaskRecord) {
        let dataPoints = fetchChargeDataPoints(for: chargeRecord)

        for dataPoint in dataPoints {
            viewContext.delete(dataPoint)
        }

        saveContext()
    }

    /// 删除单个数据点
    /// - Parameter dataPoint: 数据点
    func deleteChargeDataPoint(_ dataPoint: ChargeDataPoint) {
        viewContext.delete(dataPoint)
        saveContext()
    }
}

// MARK: - TripRecord CRUD Operations

extension CoreDataManager {

    /// 获取所有行程记录，按开始时间降序排列
    func fetchTripRecords(limit: Int? = nil, offset: Int = 0) -> [TripRecord] {
        let request: NSFetchRequest<TripRecord> = TripRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

        if let limit = limit {
            request.fetchLimit = limit
            request.fetchOffset = offset
        }

        do {
            return try viewContext.fetch(request)
        } catch {
            print("获取行程记录失败: \(error)")
            return []
        }
    }

    /// 删除行程记录
    func deleteTripRecord(_ record: TripRecord) {
        viewContext.delete(record)
        saveContext()
    }

    /// 删除所有行程记录
    func deleteAllTripRecords() {
        let request: NSFetchRequest<NSFetchRequestResult> = TripRecord.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try viewContext.execute(deleteRequest)
            saveContext()
        } catch {
            print("删除所有行程记录失败: \(error)")
        }
    }

    /// 从服务器同步行程记录到本地数据库
    /// - Parameter tripsData: 服务器返回的行程记录数组（包含data_points）
    /// - Returns: 成功保存的行程记录数组
    func syncTripRecordsFromServer(_ tripsData: [[String: Any]]) -> [TripRecord] {
        var savedRecords: [TripRecord] = []

        // 使用后台上下文进行批量操作
        let context = newBackgroundContext()

        context.performAndWait {
            // Any -> Double 解析（兼容 JSONSerialization/SwiftyJSON 可能产生的 NSNumber/Double/String）
            func toDouble(_ value: Any?) -> Double? {
                if let d = value as? Double { return d }
                if let n = value as? NSNumber { return n.doubleValue }
                if let s = value as? String { return Double(s) }
                return nil
            }

            for tripJson in tripsData {
                // 解析行程记录基本信息
                guard let startTimeString = tripJson["start_time"] as? String else {
                    print("[CoreDataManager] 跳过无效的行程记录：缺少start_time")
                    continue
                }

                // 解析时间 - 支持多种格式
                func parseDate(_ dateString: String) -> Date? {
                    // 尝试ISO8601格式（服务器返回格式）
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

                    // 尝试标准格式（yyyy-MM-dd HH:mm:ss）
                    let standardFormatter = DateFormatter()
                    standardFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    standardFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                    if let date = standardFormatter.date(from: dateString) {
                        return date
                    }

                    return nil
                }

                guard let startTime = parseDate(startTimeString) else {
                    print("[CoreDataManager] 时间解析失败：\(startTimeString)")
                    continue
                }

                let endTime: Date?
                if let endTimeString = tripJson["end_time"] as? String {
                    endTime = parseDate(endTimeString)
                } else {
                    endTime = nil
                }

                // 检查是否已存在该记录（只通过startTime，避免服务器ID重用导致的误判）
                let recordID = String(tripJson["id"] as? Int ?? 0)
                let existingRecordRequest: NSFetchRequest<TripRecord> = TripRecord.fetchRequest()
                existingRecordRequest.predicate = NSPredicate(format: "startTime == %@", startTime as NSDate)
                existingRecordRequest.fetchLimit = 1

                do {
                    let existingRecords = try context.fetch(existingRecordRequest)
                    if let existingRecord = existingRecords.first {
                        print("[CoreDataManager] 跳过已存在的行程记录：开始时间=\(startTime), ID=\(recordID)")
                        continue
                    }
                } catch {
                    print("[CoreDataManager] 查询已存在记录失败：\(error)")
                }

                // 创建新的行程记录
                let record = TripRecord(context: context)
                record.recordID = recordID
                record.startTime = startTime
                record.endTime = endTime
                record.startSoc = Int16(tripJson["start_soc"] as? Int ?? 0)
                record.endSoc = Int16(tripJson["end_soc"] as? Int ?? 0)
                record.startRangeKm = Int32(tripJson["start_range_km"] as? Int ?? 0)
                record.endRangeKm = Int32(tripJson["end_range_km"] as? Int ?? 0)
                record.startLat = tripJson["start_lat"] as? Double ?? 0.0
                record.startLon = tripJson["start_lon"] as? Double ?? 0.0
                record.endLat = tripJson["end_lat"] as? Double ?? 0.0
                record.endLon = tripJson["end_lon"] as? Double ?? 0.0
                record.totalDistance = tripJson["total_distance"] as? Double ?? 0.0
                record.consumedRange = Int32(tripJson["consumed_range"] as? Int ?? 0)
                record.maxSpeed = Int32(tripJson["max_speed"] as? Int ?? 0)
                record.avgSpeed = Int32(tripJson["avg_speed"] as? Int ?? 0)

                // 解析新字段
                if let summaryStatus = tripJson["summary_status"] as? String {
                    record.summaryStatus = summaryStatus
                }
                if let trackSource = tripJson["track_source"] as? String {
                    record.trackSource = trackSource
                }
                if let dataPointsCount = tripJson["data_points_count"] as? Int {
                    record.dataPointsCount = Int32(dataPointsCount)
                } else {
                    // 如果没有提供，稍后从实际数据点数量计算
                    record.dataPointsCount = 0
                }

                // 解析并创建数据点
                if let dataPointsArray = tripJson["data_points"] as? [[String: Any]] {
                    print("[CoreDataManager] 正在保存 \(dataPointsArray.count) 个数据点...")

                    // bug1(iOS兜底)：车机轨迹行程以“轨迹最早点”为起点坐标（用于修复历史数据 start_lat/start_lon 不准）
                    if record.trackSource == "device" {
                        // data_points 已按时间排序（后端也会排序），这里取第一个有效点即可
                        if let first = dataPointsArray.first,
                           let lat = toDouble(first["lat"]),
                           let lon = toDouble(first["lon"]),
                           lat != 0, lon != 0 {
                            record.startLat = lat
                            record.startLon = lon
                        }
                    }

                    for dataPointJson in dataPointsArray {
                        if let dataPoint = TripDataPoint.create(from: dataPointJson, context: context, tripRecord: record) {
                            // 数据点已自动关联到record
                        } else {
                            print("[CoreDataManager] 数据点创建失败")
                        }
                    }

                    // 更新实际数据点数量（如果之前没有从API获取）
                    if record.dataPointsCount == 0 {
                        record.dataPointsCount = Int32(dataPointsArray.count)
                    }
                }

                savedRecords.append(record)
                print("[CoreDataManager] 成功保存行程记录：ID=\(recordID), 数据点数量=\(record.dataPoints?.count ?? 0), trackSource=\(record.trackSource ?? "nil"), summaryStatus=\(record.summaryStatus ?? "nil")")
            }

            // 批量保存
            if context.hasChanges {
                do {
                    try context.save()
                    print("[CoreDataManager] 批量保存成功：共 \(savedRecords.count) 条行程记录")

                    // 保存成功后，触发地址解析
                    if !savedRecords.isEmpty {
                        DispatchQueue.main.async {
                            self.triggerGeocodingForRecords(savedRecords)
                        }
                    }
                } catch {
                    print("[CoreDataManager] 保存失败：\(error)")
                    savedRecords.removeAll()
                }
            }
        }

        return savedRecords
    }

    @discardableResult
    func syncTripSummariesV3(upserts: [TripSyncItem], deletes: [String]) -> Int {
        var changedCount = 0
        let context = newBackgroundContext()
        var savedObjectIDs: [NSManagedObjectID] = []

        context.performAndWait {
            for clientTripID in deletes {
                if let record = fetchTripRecord(clientTripID: clientTripID, context: context) {
                    context.delete(record)
                    changedCount += 1
                }
            }

            for item in upserts {
                let record = fetchTripRecord(clientTripID: item.clientTripID, context: context) ?? TripRecord(context: context)
                applyTripSyncItem(item, to: record)
                changedCount += 1
                savedObjectIDs.append(record.objectID)
            }

            if context.hasChanges {
                do {
                    try context.save()
                    print("[CoreDataManager] V3行程摘要保存成功：upserts=\(upserts.count), deletes=\(deletes.count)")
                } catch {
                    print("[CoreDataManager] V3行程摘要保存失败：\(error)")
                    changedCount = 0
                    savedObjectIDs.removeAll()
                }
            }
        }

        if !savedObjectIDs.isEmpty {
            DispatchQueue.main.async {
                let records = savedObjectIDs.compactMap { objectID in
                    try? self.viewContext.existingObject(with: objectID) as? TripRecord
                }
                self.triggerGeocodingForRecords(records)
            }
        }

        return changedCount
    }

    @discardableResult
    func saveTripPointsV3(_ points: [TripPointItem], clientTripID: String) -> Int {
        guard !points.isEmpty else { return 0 }
        var savedCount = 0
        let context = newBackgroundContext()

        context.performAndWait {
            guard let record = fetchTripRecord(clientTripID: clientTripID, context: context) else {
                print("[CoreDataManager] 未找到行程记录，跳过轨迹点保存：\(clientTripID)")
                return
            }

            for item in points {
                let point = fetchTripPoint(timestampMs: item.timestampMs, tripRecord: record, context: context) ?? TripDataPoint(context: context)
                point.tripRecord = record
                point.timestampMs = item.timestampMs
                point.timestamp = dateFromMilliseconds(item.timestampMs)
                point.lat = item.lat
                point.lon = item.lon
                point.speed = item.speed
                point.calculatedSpeedKmh = Int32(clamping: Int(item.speed.rounded()))
                point.powerKw = item.powerKw
                point.tripDistanceKm = item.tripDistanceKm ?? 0
                point.soc = Int16(clamping: item.soc ?? 0)
                point.remainingRangeKm = Int32(clamping: Int((item.remainingRangeKm ?? 0).rounded()))
                point.totalMileage = nil
                point.keyStatus = nil
                point.mainLockStatus = nil
                point.direction = 0
                savedCount += 1
            }

            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("[CoreDataManager] V3行程轨迹点保存失败：\(error)")
                    savedCount = 0
                }
            }
        }

        return savedCount
    }

    func tripPointsTargetCount(clientTripID: String) -> Int64 {
        var count: Int64 = 0
        let context = newBackgroundContext()
        context.performAndWait {
            count = fetchTripRecord(clientTripID: clientTripID, context: context)?.pointsCount ?? 0
        }
        return count
    }

    /// 触发行程记录的地址解析
    /// - Parameter records: 需要解析的行程记录数组
    private func triggerGeocodingForRecords(_ records: [TripRecord]) {
        // 筛选需要解析的记录
        let recordsNeedingGeocoding = records.filter { $0.needsGeocoding }

        guard !recordsNeedingGeocoding.isEmpty else {
            print("[CoreDataManager] 所有记录已有地址，无需解析")
            return
        }

        print("[CoreDataManager] 触发地址解析：\(recordsNeedingGeocoding.count) 条记录")

        // 调用 GeocodingService 进行批量解析
        GeocodingService.shared.geocodeTripRecords(recordsNeedingGeocoding)
    }

    /// 获取所有需要地址解析的行程记录
    /// - Returns: 需要解析地址的行程记录数组
    func getTripRecordsNeedingGeocoding() -> [TripRecord] {
        let request: NSFetchRequest<TripRecord> = TripRecord.fetchRequest()

        // 筛选条件：地址为空（或标记为"位置解析中..."）且 GPS 坐标有效
        // 排除已标记为"解析失败"的记录
        let startCondition = NSPredicate(format: "(startAddress == nil OR startAddress == %@) AND startLat != 0 AND startLon != 0", "位置解析中...")
        let endCondition = NSPredicate(format: "(endAddress == nil OR endAddress == %@) AND endLat != 0 AND endLon != 0", "位置解析中...")
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [startCondition, endCondition])
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

        do {
            let records = try viewContext.fetch(request)
            print("[CoreDataManager] 查询到 \(records.count) 条需要解析地址的记录")
            return records
        } catch {
            print("[CoreDataManager] 查询需要解析的记录失败：\(error)")
            return []
        }
    }
}

// MARK: - TripDataPoint CRUD Operations

extension CoreDataManager {

    /// 获取指定行程记录的所有数据点
    /// - Parameter tripRecord: 行程记录
    /// - Returns: 数据点数组，按时间升序排列
    func fetchTripDataPoints(for tripRecord: TripRecord) -> [TripDataPoint] {
        let request = TripDataPoint.fetchRequest(for: tripRecord)

        do {
            return try viewContext.fetch(request)
        } catch {
            print("获取行程数据点失败: \(error)")
            return []
        }
    }

    /// 删除指定行程记录的所有数据点
    /// - Parameter tripRecord: 行程记录
    func deleteTripDataPoints(for tripRecord: TripRecord) {
        let dataPoints = fetchTripDataPoints(for: tripRecord)

        for dataPoint in dataPoints {
            viewContext.delete(dataPoint)
        }

        saveContext()
    }
}

// MARK: - V3 Core Data Helpers

private func dateFromMilliseconds(_ milliseconds: Int64) -> Date {
    Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000.0)
}

private func clampInt16(_ value: Int64?) -> Int16 {
    Int16(clamping: value ?? 0)
}

private func clampInt32FromDouble(_ value: Double?) -> Int32 {
    Int32(clamping: Int((value ?? 0).rounded()))
}

private func fetchTripRecord(clientTripID: String, context: NSManagedObjectContext) -> TripRecord? {
    let request: NSFetchRequest<TripRecord> = TripRecord.fetchRequest()
    request.predicate = NSPredicate(format: "clientTripID == %@ OR recordID == %@", clientTripID, clientTripID)
    request.fetchLimit = 1
    return try? context.fetch(request).first
}

private func fetchChargeRecord(clientChargeID: String, context: NSManagedObjectContext) -> ChargeTaskRecord? {
    let request: NSFetchRequest<ChargeTaskRecord> = ChargeTaskRecord.fetchRequest()
    request.predicate = NSPredicate(format: "clientChargeID == %@ OR recordID == %@", clientChargeID, clientChargeID)
    request.fetchLimit = 1
    return try? context.fetch(request).first
}

private func fetchTripPoint(timestampMs: Int64, tripRecord: TripRecord, context: NSManagedObjectContext) -> TripDataPoint? {
    let request: NSFetchRequest<TripDataPoint> = TripDataPoint.fetchRequest()
    request.predicate = NSPredicate(format: "tripRecord == %@ AND timestampMs == %lld", tripRecord, timestampMs)
    request.fetchLimit = 1
    return try? context.fetch(request).first
}

private func fetchChargePoint(timestampMs: Int64, chargeRecord: ChargeTaskRecord, context: NSManagedObjectContext) -> ChargeDataPoint? {
    let request: NSFetchRequest<ChargeDataPoint> = ChargeDataPoint.fetchRequest()
    request.predicate = NSPredicate(format: "chargeRecord == %@ AND timestampMs == %lld", chargeRecord, timestampMs)
    request.fetchLimit = 1
    return try? context.fetch(request).first
}

private func applyTripSyncItem(_ item: TripSyncItem, to record: TripRecord) {
    record.id = item.startTimeMs
    record.recordID = item.clientTripID
    record.clientTripID = item.clientTripID
    record.vin = item.vin
    record.status = Int16(clamping: item.status)
    record.startTime = dateFromMilliseconds(item.startTimeMs)
    record.endTime = item.endTimeMs.map(dateFromMilliseconds)
    record.startLat = item.startLat ?? 0
    record.startLon = item.startLon ?? 0
    record.endLat = item.endLat ?? 0
    record.endLon = item.endLon ?? 0
    record.totalDistance = item.distanceKm ?? 0
    record.drivingDurationMs = item.drivingDurationMs ?? 0
    record.energyConsumedKwh = item.energyConsumedKwh ?? 0
    record.parkedEnergyKwh = item.parkedEnergyKwh ?? 0
    record.avgEnergyPer100Km = item.avgEnergyPer100Km ?? 0
    record.maxSpeed = Int32(clamping: item.maxSpeed ?? 0)
    record.startSoc = clampInt16(item.startSoc)
    record.endSoc = clampInt16(item.endSoc)
    record.startRangeKm = clampInt32FromDouble(item.startRangeKm)
    record.endRangeKm = clampInt32FromDouble(item.endRangeKm)
    record.pointsCount = item.pointsCount ?? 0
    record.dataPointsCount = Int32(clamping: item.pointsCount ?? 0)
    record.consumedRange = Int32(clamping: Int(((item.startRangeKm ?? 0) - (item.endRangeKm ?? 0)).rounded()))
    record.avgSpeed = averageSpeed(distanceKm: item.distanceKm, durationMs: item.drivingDurationMs)
    record.summaryStatus = item.status == 2 ? "completed" : (item.status == 1 ? "pre_ended" : "running")
    record.trackSource = "device"
}

private func applyChargeSyncItem(_ item: ChargeSyncItem, to record: ChargeTaskRecord) {
    record.recordID = item.clientChargeID
    record.clientChargeID = item.clientChargeID
    record.vin = item.vin
    record.status = Int16(clamping: item.status)
    record.startTime = dateFromMilliseconds(item.startTimeMs)
    record.endTime = item.endTimeMs.map(dateFromMilliseconds)
    record.startSoc = clampInt16(item.startSoc)
    record.endSoc = clampInt16(item.endSoc)
    record.startKm = Int64((item.startRangeKm ?? 0).rounded())
    record.endKm = Int64((item.endRangeKm ?? 0).rounded())
    record.addedRangeKm = item.addedRangeKm ?? 0
    record.chargedEnergyKwh = item.chargedEnergyKwh ?? 0
    record.pointsCount = item.pointsCount ?? 0
    record.lat = item.lat ?? 0
    record.lon = item.lon ?? 0
    record.dataSource = "device"
    record.summaryStatus = item.status == 1 ? "completed" : "charging"
}

private func averageSpeed(distanceKm: Double?, durationMs: Int64?) -> Int32 {
    guard let distanceKm, let durationMs, durationMs > 0 else { return 0 }
    let hours = Double(durationMs) / 3_600_000.0
    guard hours > 0 else { return 0 }
    return Int32(clamping: Int((distanceKm / hours).rounded()))
}

// MARK: - Notification Names

extension Notification.Name {
    static let coreDataDidUpdateFromCloudKit = Notification.Name("coreDataDidUpdateFromCloudKit")
}
