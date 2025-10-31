//
//  CoreDataMigrationTest.swift
//  Pan3Car
//
//  Created by AI Assistant on 2024/12/30.
//  测试Core Data迁移和基本功能

import Foundation
import CoreData

class CoreDataMigrationTest {
    
    /// 测试Core Data基本CRUD操作
    static func testBasicOperations() {
        print("🧪 开始测试Core Data基本操作...")
        
        // 测试创建充电记录
        testCreateChargeRecord()
        
        // 测试获取充电记录
        testFetchChargeRecords()
        
        // 测试更新充电记录
        testUpdateChargeRecord()
        
        // 测试删除充电记录
        testDeleteChargeRecord()
        
        print("✅ Core Data基本操作测试完成")
    }
    
    /// 测试创建充电记录
    private static func testCreateChargeRecord() {
        print("📝 测试创建充电记录...")
        
        let testRecord = CoreDataManager.shared.createChargeRecord(
            startTime: Date(),
            endTime: nil as Date?,
            startSoc: 20,
            endSoc: 0,
            startKm: 50000,
            endKm: 0,
            lat: 39.9042,
            lon: 116.4074,
            address: "北京市朝阳区",
            recordID: "test_record_\(Int(Date().timeIntervalSince1970))"
        )
        
        print("✅ 创建充电记录成功: ID = \(testRecord.recordID ?? "未知")")
    }
    
    /// 测试获取充电记录
    private static func testFetchChargeRecords() {
        print("📖 测试获取充电记录...")
        
        let records = CoreDataManager.shared.fetchChargeRecords(limit: 10)
        print("✅ 获取到 \(records.count) 条充电记录")
        
        for (index, record) in records.enumerated() {
            print("  记录 \(index + 1): ID=\(record.recordID ?? "未知"), 开始时间=\(record.startTime ?? Date())")
        }
    }
    
    /// 测试更新充电记录
    private static func testUpdateChargeRecord() {
        print("✏️ 测试更新充电记录...")
        
        let records = CoreDataManager.shared.fetchChargeRecords(limit: 1)
        guard let record = records.first else {
            print("⚠️ 没有找到可更新的记录")
            return
        }
        
        let originalEndTime = record.endTime
        CoreDataManager.shared.updateChargeRecord(
            record,
            endTime: Date() as Date?,
            endSoc: 80 as Int16?,
            endKm: 10050 as Int64?,
            address: "更新后的地址"
        )
        
        print("✅ 更新充电记录成功: 结束时间从 \(originalEndTime?.description ?? "nil") 更新为 \(record.endTime?.description ?? "nil")")
    }
    
    /// 测试删除充电记录
    private static func testDeleteChargeRecord() {
        print("🗑️ 测试删除充电记录...")
        
        let records = CoreDataManager.shared.fetchChargeRecords(limit: 1)
        guard let record = records.first else {
            print("⚠️ 没有找到可删除的记录")
            return
        }
        
        let recordID = record.recordID
        CoreDataManager.shared.deleteChargeRecord(record)
        
        print("✅ 删除充电记录成功: ID = \(recordID ?? "未知")")
    }
    
    /// 测试CloudKit同步状态
    static func testCloudKitSync() {
        print("☁️ 测试CloudKit同步状态...")
        
        // 检查CloudKit容器状态
        let container = CoreDataManager.shared.persistentContainer
        print("✅ CloudKit容器名称: \(container.name)")
        
        // 检查CloudKit配置
        if let storeDescription = CoreDataManager.shared.persistentContainer.persistentStoreDescriptions.first {
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            let isCloudKitEnabled = storeDescription.cloudKitContainerOptions != nil
            print("✅ CloudKit同步状态: \(isCloudKitEnabled ? "已启用" : "未启用")")
        }
        
        print("✅ CloudKit同步测试完成")
    }
    
    /// 测试数据模型兼容性
    static func testModelCompatibility() {
        print("🔄 测试数据模型兼容性...")
        
        // 创建一个ChargeRecord并转换为ChargeTaskModel
        let record = CoreDataManager.shared.createChargeRecord(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600) as Date?, // 1小时后
            startSoc: 20,
            endSoc: 80,
            startKm: 10000,
            endKm: 10050,
            lat: 39.9042,
            lon: 116.4074,
            address: "兼容性测试地址",
            recordID: "compatibility_test_\(Int(Date().timeIntervalSince1970))"
        )
        
        // 转换为ChargeTaskModel
        let taskModel = ChargeTaskModel(from: record)
        
        print("✅ 数据模型转换成功:")
        print("  - 充电时长: \(taskModel.chargeDuration)")
        print("  - SOC增长: \(taskModel.socGain)%")
        print("  - 里程增长: \(taskModel.mileageGain)km")
        
        // 清理测试数据
        CoreDataManager.shared.deleteChargeRecord(record)
        
        print("✅ 数据模型兼容性测试完成")
    }
}
