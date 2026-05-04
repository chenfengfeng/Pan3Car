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

    /// 分批导入指定行程的轨迹点。当前只提供数据能力，UI后续接入进度条和渲染。
    func importTripPoints(
        clientTripID: String,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let totalExpected = CoreDataManager.shared.tripPointsTargetCount(clientTripID: clientTripID)
        importTripPointsPage(
            clientTripID: clientTripID,
            timestamp: 0,
            totalExpected: totalExpected,
            savedCount: 0,
            progress: progress,
            completion: completion
        )
    }

    /// 分批导入指定充电记录的过程点。当前只提供数据能力，UI后续接入进度条和渲染。
    func importChargePoints(
        clientChargeID: String,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        let totalExpected = CoreDataManager.shared.chargePointsTargetCount(clientChargeID: clientChargeID)
        importChargePointsPage(
            clientChargeID: clientChargeID,
            timestamp: 0,
            totalExpected: totalExpected,
            savedCount: 0,
            progress: progress,
            completion: completion
        )
    }

    // MARK: - Private Methods

    private func importTripPointsPage(
        clientTripID: String,
        timestamp: Int64,
        totalExpected: Int64,
        savedCount: Int,
        progress: ((Double) -> Void)?,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        NetworkManager.shared.getTripPointsV3(clientTripID: clientTripID, timestamp: timestamp) { result in
            switch result {
            case .success(let page):
                if page.count == 0 || page.points.isEmpty {
                    DispatchQueue.main.async {
                        progress?(1.0)
                        completion(.success(savedCount))
                    }
                    return
                }

                let batchSaved = CoreDataManager.shared.saveTripPointsV3(page.points, clientTripID: clientTripID)
                let newSavedCount = savedCount + batchSaved
                DispatchQueue.main.async {
                    if totalExpected > 0 {
                        progress?(min(1.0, Double(newSavedCount) / Double(totalExpected)))
                    }
                }

                guard page.hasMore else {
                    DispatchQueue.main.async {
                        progress?(1.0)
                        completion(.success(newSavedCount))
                    }
                    return
                }

                guard page.nextTimestamp > timestamp else {
                    let error = NSError(
                        domain: "TripPointsImportError",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "行程轨迹点分页游标未前进"]
                    )
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }

                self.importTripPointsPage(
                    clientTripID: clientTripID,
                    timestamp: page.nextTimestamp,
                    totalExpected: totalExpected,
                    savedCount: newSavedCount,
                    progress: progress,
                    completion: completion
                )

            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func importChargePointsPage(
        clientChargeID: String,
        timestamp: Int64,
        totalExpected: Int64,
        savedCount: Int,
        progress: ((Double) -> Void)?,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        NetworkManager.shared.getChargePointsV3(clientChargeID: clientChargeID, timestamp: timestamp) { result in
            switch result {
            case .success(let page):
                if page.count == 0 || page.points.isEmpty {
                    DispatchQueue.main.async {
                        progress?(1.0)
                        completion(.success(savedCount))
                    }
                    return
                }

                let batchSaved = CoreDataManager.shared.saveChargePointsV3(page.points, clientChargeID: clientChargeID)
                let newSavedCount = savedCount + batchSaved
                DispatchQueue.main.async {
                    if totalExpected > 0 {
                        progress?(min(1.0, Double(newSavedCount) / Double(totalExpected)))
                    }
                }

                guard page.hasMore else {
                    DispatchQueue.main.async {
                        progress?(1.0)
                        completion(.success(newSavedCount))
                    }
                    return
                }

                guard page.nextTimestamp > timestamp else {
                    let error = NSError(
                        domain: "ChargePointsImportError",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "充电过程点分页游标未前进"]
                    )
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }

                self.importChargePointsPage(
                    clientChargeID: clientChargeID,
                    timestamp: page.nextTimestamp,
                    totalExpected: totalExpected,
                    savedCount: newSavedCount,
                    progress: progress,
                    completion: completion
                )

            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// 同步充电数据
    private func syncChargeData(completion: @escaping (Int, Error?) -> Void) {
        print("[DataSyncManager] 开始同步V3充电摘要...")

        NetworkManager.shared.getChargeSyncV3 { result in
            switch result {
            case .success(let syncResponse):
                print("[DataSyncManager] 获取到V3充电摘要：upserts=\(syncResponse.upserts.count), deletes=\(syncResponse.deletes.count)")

                DispatchQueue.global(qos: .userInitiated).async {
                    let changedCount = CoreDataManager.shared.syncChargeSummariesV3(
                        upserts: syncResponse.upserts,
                        deletes: syncResponse.deletes
                    )
                    let ackIDs = syncResponse.deletes + syncResponse.upserts
                        .filter { $0.status == 1 }
                        .map { $0.clientChargeID }

                    guard !ackIDs.isEmpty else {
                        DispatchQueue.main.async {
                            completion(changedCount, nil)
                        }
                        return
                    }

                    NetworkManager.shared.ackChargeSyncV3(clientChargeIDs: ackIDs) { ackResult in
                        DispatchQueue.main.async {
                            switch ackResult {
                            case .success:
                                print("[DataSyncManager] V3充电同步确认成功：\(ackIDs.count) 条")
                                completion(changedCount, nil)
                            case .failure(let error):
                                print("[DataSyncManager] V3充电同步确认失败: \(error.localizedDescription)")
                                completion(changedCount, error)
                            }
                        }
                    }
                }

            case .failure(let error):
                print("[DataSyncManager] V3充电摘要同步失败: \(error.localizedDescription)")
                completion(0, error)
            }
        }
    }

    /// 同步行程数据
    private func syncTripData(completion: @escaping (Int, Error?) -> Void) {
        print("[DataSyncManager] 开始同步V3行程摘要...")

        NetworkManager.shared.getTripSyncV3 { result in
            switch result {
            case .success(let syncResponse):
                print("[DataSyncManager] 获取到V3行程摘要：upserts=\(syncResponse.upserts.count), deletes=\(syncResponse.deletes.count)")

                DispatchQueue.global(qos: .userInitiated).async {
                    let changedCount = CoreDataManager.shared.syncTripSummariesV3(
                        upserts: syncResponse.upserts,
                        deletes: syncResponse.deletes
                    )
                    let ackIDs = syncResponse.deletes + syncResponse.upserts
                        .filter { $0.status == 2 }
                        .map { $0.clientTripID }

                    guard !ackIDs.isEmpty else {
                        DispatchQueue.main.async {
                            completion(changedCount, nil)
                        }
                        return
                    }

                    NetworkManager.shared.ackTripSyncV3(clientTripIDs: ackIDs) { ackResult in
                        DispatchQueue.main.async {
                            switch ackResult {
                            case .success:
                                print("[DataSyncManager] V3行程同步确认成功：\(ackIDs.count) 条")
                                completion(changedCount, nil)
                            case .failure(let error):
                                print("[DataSyncManager] V3行程同步确认失败: \(error.localizedDescription)")
                                completion(changedCount, error)
                            }
                        }
                    }
                }

            case .failure(let error):
                print("[DataSyncManager] V3行程摘要同步失败: \(error.localizedDescription)")
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
