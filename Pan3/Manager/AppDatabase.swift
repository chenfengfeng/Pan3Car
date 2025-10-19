//
//  AppDatabase.swift
//  Pan3
//
//  Created by Feng on 2025/10/12.
//

// AppDatabase.swift

import Foundation
import GRDB

struct AppDatabase {
    /// 保持一个全局可访问的数据库连接队列。
    static var dbQueue: DatabaseQueue!
    
    /// 定义一个数据库迁移器，用于创建和更新表结构。
    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        // 在这里定义我们第一次创建数据库时的所有操作。
        migrator.registerMigration("v1") { db in
            // 创建 "chargeTask" 表
            try db.create(table: "chargeTask") { t in
                // 任务的唯一ID，由数据库自动创建并递增
                t.autoIncrementedPrimaryKey("id")
                // 任务创建/开始的时间
                t.column("startTime", .datetime).notNull()
                // 任务结束的时间 (任务正在进行中时为 nil)
                t.column("endTime", .datetime)
                // 任务开始时的电量百分比 (State of Charge)
                t.column("startSoc", .integer)
                // 任务结束时的电量百分比
                t.column("endSoc", .integer)
                // 任务开始时的续航里程 (单位: km)
                t.column("startKm", .integer)
                // 任务结束时的续航里程 (单位: km)
                t.column("endKm", .integer)
                // GPS相关字段
                t.column("lat", .double)      // 纬度
                t.column("lon", .double)      // 经度
                t.column("address", .text)    // 地址
            }
        }
        
        return migrator
    }
    
    /// 设置并初始化数据库。这个方法应该在App启动时调用一次。
    static func setup(for application: UIApplication) throws {
        // 1. 定义数据库文件的路径。
        // Application Support 目录是存放App数据的推荐位置。
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("database.sqlite")
        
        // 2. 初始化数据库连接队列。
        dbQueue = try DatabaseQueue(path: databaseURL.path)
        
        // 3. 执行数据库迁移（如果需要，会自动创建或更新表）。
        try migrator.migrate(dbQueue)
        
        print("数据库初始化和迁移成功，路径: \(databaseURL.path)")
    }
}
