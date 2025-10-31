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
        
        // 配置CloudKit容器标识符
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.dream.pan3car"
        )
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                // 在生产环境中，应该有更好的错误处理
                print("Core Data error: \(error), \(error.userInfo)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
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
        // 处理CloudKit远程更改
//        print("检测到CloudKit远程更改")
        
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

// MARK: - Notification Names

extension Notification.Name {
    static let coreDataDidUpdateFromCloudKit = Notification.Name("coreDataDidUpdateFromCloudKit")
}
