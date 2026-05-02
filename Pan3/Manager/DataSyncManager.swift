//
//  DataSyncManager.swift
//  Pan3
//
//  Created by Feng on 2025/1/25.
//

import Foundation

/// 数据同步管理器
/// 负责在APP启动时自动同步充电和行程数据
class DataSyncManager {
    
    // MARK: - Singleton
    static let shared = DataSyncManager()
    
    private init() {}
    
    // MARK: - Properties
    
    /// 同步状态
    enum SyncState {
        case idle
        case syncing
        case completed
        case failed(Error)
    }
    
    /// 当前同步状态
    private(set) var currentState: SyncState = .idle
    
    /// 是否正在同步
    var isSyncing: Bool {
        if case .syncing = currentState {
            return true
        }
        return false
    }
    
    /// 同步结果
    struct SyncResult {
        let chargeRecordsCount: Int
        let tripRecordsCount: Int
        let chargeError: Error?
        let tripError: Error?
        
        var isSuccess: Bool {
            return chargeError == nil && tripError == nil
        }
    }
    
    // MARK: - Public Methods
    
    /// 启动自动同步
    /// 按顺序同步：1. 充电数据 -> 2. 行程数据
    /// - Parameter completion: 完成回调
    func startAutoSync(completion: ((SyncResult) -> Void)? = nil) {
        // 检查是否已登录
        guard UserManager.shared.isLoggedIn else {
            print("[DataSyncManager] 用户未登录，跳过自动同步")
            completion?(SyncResult(chargeRecordsCount: 0, tripRecordsCount: 0, chargeError: nil, tripError: nil))
            return
        }
        
        // 检查是否正在同步
        guard !isSyncing else {
            print("[DataSyncManager] 正在同步中，跳过重复请求")
            return
        }
        
        currentState = .syncing
        print("[DataSyncManager] ========== 开始自动同步 ==========")
        
        // 第一步：同步充电数据
        syncChargeData { [weak self] chargeResult, chargeError in
            guard let self = self else { return }
            
            print("[DataSyncManager] 充电数据同步完成，获取 \(chargeResult) 条记录")
            
            // 第二步：同步行程数据（充电完成后）
            self.syncTripData { tripResult, tripError in
                print("[DataSyncManager] 行程数据同步完成，获取 \(tripResult) 条记录")
                print("[DataSyncManager] ========== 自动同步完成 ==========")
                
                self.currentState = .completed
                
                let result = SyncResult(
                    chargeRecordsCount: chargeResult,
                    tripRecordsCount: tripResult,
                    chargeError: chargeError,
                    tripError: tripError
                )
                
                DispatchQueue.main.async {
                    completion?(result)
                    
                    // 发送同步完成通知
                    NotificationCenter.default.post(
                        name: .dataSyncCompleted,
                        object: nil,
                        userInfo: [
                            "chargeRecordsCount": chargeResult,
                            "tripRecordsCount": tripResult
                        ]
                    )
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 同步充电数据
    private func syncChargeData(completion: @escaping (Int, Error?) -> Void) {
        print("[DataSyncManager] 开始同步充电数据...")
        
        // 获取上次同步时间
        let lastSyncTime = UserDefaults.standard.string(forKey: "lastChargeSyncTimeV2")
        print("[DataSyncManager] 充电数据上次同步时间: \(lastSyncTime ?? "从未同步")")
        
        // 从服务器获取增量数据
        NetworkManager.shared.getChargeRecordsFromServerV2(after: lastSyncTime) { [weak self] result in
            switch result {
            case .success(let chargesData):
                if chargesData.isEmpty {
                    print("[DataSyncManager] 服务器没有新的充电数据")
                    completion(0, nil)
                    return
                }
                
                print("[DataSyncManager] 获取到 \(chargesData.count) 条充电记录，开始保存...")
                
                // 在后台线程保存数据
                DispatchQueue.global(qos: .userInitiated).async {
                    let savedRecords = CoreDataManager.shared.syncChargeRecordsFromServer(chargesData)
                    
                    // 收集服务器返回的所有充电记录ID
                    var chargeIDs: [Int] = []
                    for chargeData in chargesData {
                        if let id = chargeData["id"] as? Int {
                            chargeIDs.append(id)
                        } else if let id = chargeData["id"] as? Int64 {
                            chargeIDs.append(Int(id))
                        }
                    }
                    
                    // 找出最新的end_time用于更新本地同步游标
                    var latestEndTime: String? = nil
                    for chargeData in chargesData {
                        if let endTime = chargeData["end_time"] as? String {
                            if latestEndTime == nil || endTime > latestEndTime! {
                                latestEndTime = endTime
                            }
                        }
                    }
                    
                    // 按ID列表确认同步完成
                    if !chargeIDs.isEmpty {
                        NetworkManager.shared.confirmChargeSyncCompleteV2(chargeIDs: chargeIDs) { confirmResult in
                            switch confirmResult {
                            case .success(let stats):
                                print("[DataSyncManager] 充电同步确认成功，服务器已标记 \(stats["syncedCharges"] ?? 0) 条记录为已同步")
                                // 更新本地同步游标
                                if let latestTime = latestEndTime {
                                    UserDefaults.standard.set(latestTime, forKey: "lastChargeSyncTimeV2")
                                }
                            case .failure(let error):
                                print("[DataSyncManager] 充电同步确认失败: \(error.localizedDescription)")
                            }
                            
                            DispatchQueue.main.async {
                                completion(savedRecords.count, nil)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(savedRecords.count, nil)
                        }
                    }
                }
                
            case .failure(let error):
                print("[DataSyncManager] 充电数据同步失败: \(error.localizedDescription)")
                completion(0, error)
            }
        }
    }
    
    /// 同步行程数据
    private func syncTripData(completion: @escaping (Int, Error?) -> Void) {
        print("[DataSyncManager] 开始同步行程数据...")
        
        // 获取上次同步时间
        let lastSyncTime = UserDefaults.standard.string(forKey: "LastTripSyncTime")
        print("[DataSyncManager] 行程数据上次同步时间: \(lastSyncTime ?? "从未同步")")
        
        // 从服务器获取增量数据
        NetworkManager.shared.getTripRecordsFromServerV2(after: lastSyncTime) { [weak self] result in
            switch result {
            case .success(let tripsData):
                if tripsData.isEmpty {
                    print("[DataSyncManager] 服务器没有新的行程数据")
                    completion(0, nil)
                    return
                }
                
                print("[DataSyncManager] 获取到 \(tripsData.count) 条行程记录，开始保存...")
                
                // 在后台线程保存数据
                DispatchQueue.global(qos: .userInitiated).async {
                    let savedRecords = CoreDataManager.shared.syncTripRecordsFromServer(tripsData)
                    
                    // 收集服务器返回的所有行程ID（无论本地是否已存在）
                    var tripIDs: [Int] = []
                    for tripData in tripsData {
                        if let id = tripData["id"] as? Int {
                            tripIDs.append(id)
                        } else if let id = tripData["id"] as? Int64 {
                            tripIDs.append(Int(id))
                        }
                    }
                    
                    // 找出最新的end_time用于更新本地同步游标
                    var latestEndTime: String? = nil
                    for tripData in tripsData {
                        if let endTime = tripData["end_time"] as? String {
                            if latestEndTime == nil || endTime > latestEndTime! {
                                latestEndTime = endTime
                            }
                        }
                    }
                    
                    // 按ID列表确认同步完成
                    if !tripIDs.isEmpty {
                        NetworkManager.shared.confirmTripSyncCompleteV2(tripIDs: tripIDs) { confirmResult in
                            switch confirmResult {
                            case .success(let stats):
                                print("[DataSyncManager] 行程同步确认成功，服务器已标记 \(stats["syncedTrips"] ?? 0) 条记录为已同步")
                                // 更新本地同步游标（用于下次增量拉取）
                                if let latestTime = latestEndTime {
                                    UserDefaults.standard.set(latestTime, forKey: "LastTripSyncTime")
                                }
                            case .failure(let error):
                                print("[DataSyncManager] 行程同步确认失败: \(error.localizedDescription)")
                            }
                            
                            DispatchQueue.main.async {
                                completion(savedRecords.count, nil)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(savedRecords.count, nil)
                        }
                    }
                }
                
            case .failure(let error):
                print("[DataSyncManager] 行程数据同步失败: \(error.localizedDescription)")
                completion(0, error)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// 数据同步完成通知
    static let dataSyncCompleted = Notification.Name("dataSyncCompleted")
}
