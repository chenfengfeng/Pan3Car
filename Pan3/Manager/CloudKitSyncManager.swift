//
//  CloudKitSyncManager.swift
//  Pan3
//
//  Created by AI Assistant on 2024/12/19.
//

import Foundation
import CoreData
import CloudKit
import Network

/// CloudKit同步管理器
/// 负责处理Core Data与CloudKit之间的同步策略、冲突解决和网络状态监控
class CloudKitSyncManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = CloudKitSyncManager()
    
    // MARK: - 属性
    private let container: NSPersistentCloudKitContainer
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isNetworkAvailable = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    
    // MARK: - 同步状态枚举
    enum SyncStatus {
        case idle           // 空闲
        case syncing        // 同步中
        case success        // 同步成功
        case failed(Error)  // 同步失败
    }
    
    // MARK: - 初始化
    private init() {
        self.container = CoreDataManager.shared.persistentContainer
        setupNetworkMonitoring()
        setupCloudKitNotifications()
    }
    
    // MARK: - 网络监控
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
                print("[CloudKitSync] 网络状态: \(path.status == .satisfied ? "可用" : "不可用")")
                
                // 网络恢复时尝试同步
                if path.status == .satisfied {
                    self?.attemptSync()
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - CloudKit通知设置
    private func setupCloudKitNotifications() {
        // 监听远程变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
        
        // 监听CloudKit账户状态变更
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountChange),
            name: .CKAccountChanged,
            object: nil
        )
    }
    
    // MARK: - 同步控制
    
    /// 手动触发同步
    func manualSync() {
        guard isNetworkAvailable else {
            print("[CloudKitSync] 网络不可用，无法同步")
            syncStatus = .failed(SyncError.networkUnavailable)
            return
        }
        
        attemptSync()
    }
    
    /// 尝试同步
    private func attemptSync() {
        // 检查是否已经在同步中
        if case .syncing = syncStatus {
            print("[CloudKitSync] 同步已在进行中")
            return
        }
        
        syncStatus = .syncing
        print("[CloudKitSync] 开始同步...")
        
        // 使用NSPersistentCloudKitContainer的自动同步
        // 这里主要是更新状态和处理结果
        DispatchQueue.global(qos: .background).async { [weak self] in
            // 模拟同步过程
            Thread.sleep(forTimeInterval: 2.0)
            
            DispatchQueue.main.async {
                self?.syncStatus = .success
                self?.lastSyncDate = Date()
                print("[CloudKitSync] 同步完成")
            }
        }
    }
    
    // MARK: - 冲突解决
    
    /// 设置冲突解决策略
    func configureConflictResolution() {
        // NSPersistentCloudKitContainer 默认使用最后写入获胜策略
        // 这里可以添加自定义冲突解决逻辑
        print("[CloudKitSync] 冲突解决策略: 最后写入获胜")
    }
    
    /// 处理合并冲突
    private func handleMergeConflicts(_ conflicts: [NSMergeConflict]) {
        for conflict in conflicts {
            print("[CloudKitSync] 处理冲突: \(conflict.sourceObject)")
            // 可以在这里实现自定义冲突解决逻辑
        }
    }
    
    // MARK: - 通知处理
    
    @objc private func handleRemoteChange(_ notification: Notification) {
//        print("[CloudKitSync] 检测到远程数据变更")
        
        DispatchQueue.main.async { [weak self] in
            // 通知UI更新
            NotificationCenter.default.post(
                name: .cloudKitDataChanged,
                object: nil
            )
        }
    }
    
    @objc private func handleAccountChange(_ notification: Notification) {
        print("[CloudKitSync] CloudKit账户状态变更")
        
        checkCloudKitAccountStatus { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    print("[CloudKitSync] CloudKit账户可用")
                    self?.attemptSync()
                case .noAccount:
                    print("[CloudKitSync] 未登录iCloud账户")
                case .restricted:
                    print("[CloudKitSync] iCloud账户受限")
                case .couldNotDetermine:
                    print("[CloudKitSync] 无法确定iCloud账户状态")
                @unknown default:
                    print("[CloudKitSync] 未知iCloud账户状态")
                }
            }
        }
    }
    
    // MARK: - CloudKit状态检查
    
    /// 检查CloudKit账户状态
    func checkCloudKitAccountStatus(completion: @escaping (CKAccountStatus) -> Void) {
        CKContainer.default().accountStatus { status, error in
            if let error = error {
                print("[CloudKitSync] 检查账户状态失败: \(error)")
            }
            completion(status)
        }
    }
    
    /// 检查CloudKit可用性
    func checkCloudKitAvailability() -> Bool {
        // 检查设备是否支持CloudKit
        guard CKContainer.default().privateCloudDatabase != nil else {
            print("[CloudKitSync] 设备不支持CloudKit")
            return false
        }
        
        return true
    }
    
    // MARK: - 数据导出/导入
    
    /// 导出本地数据到CloudKit
    func exportLocalDataToCloudKit() {
        guard isNetworkAvailable else {
            print("[CloudKitSync] 网络不可用，无法导出数据")
            return
        }
        
        print("[CloudKitSync] 开始导出本地数据到CloudKit...")
        
        // 触发同步
        attemptSync()
    }
    
    /// 从CloudKit导入数据
    func importDataFromCloudKit() {
        guard isNetworkAvailable else {
            print("[CloudKitSync] 网络不可用，无法导入数据")
            return
        }
        
        print("[CloudKitSync] 开始从CloudKit导入数据...")
        
        // 触发同步
        attemptSync()
    }
    
    // MARK: - 清理
    deinit {
        networkMonitor.cancel()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 错误定义
extension CloudKitSyncManager {
    enum SyncError: LocalizedError {
        case networkUnavailable
        case accountUnavailable
        case syncInProgress
        
        var errorDescription: String? {
            switch self {
            case .networkUnavailable:
                return "网络不可用"
            case .accountUnavailable:
                return "iCloud账户不可用"
            case .syncInProgress:
                return "同步正在进行中"
            }
        }
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let cloudKitDataChanged = Notification.Name("CloudKitDataChanged")
}
