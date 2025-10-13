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
        
        // --- 版本 v1 ---
        // 在这里定义我们第一次创建数据库时的所有操作。
        migrator.registerMigration("v1") { db in
            // 创建 "chargeTask" 表
            try db.create(table: "chargeTask") { t in
                // 任务的唯一ID，由数据库自动创建并递增
                t.autoIncrementedPrimaryKey("id")
                
                // 关联车辆的唯一标识符 (Vehicle Identification Number)
                t.column("vin", .text).notNull()
                
                // 用户选择的监控模式，例如 "time" 或 "range"
                t.column("monitoringMode", .text).notNull()
                
                // 用户设定的目标值 (对于时间模式，是时间戳字符串；对于里程模式，是里程数字符串)
                t.column("targetValue", .text).notNull()
                
                // 是否在达到时间目标后，自动调用API停止充电
                t.column("autoStopCharge", .boolean).notNull()
                
                // 任务的最终状态 (例如: "RUNNING", "COMPLETED", "CANCELLED", "FAILED")
                t.column("finalStatus", .text).notNull()
                
                // 任务结束时的最终消息，用于展示给用户 (例如: "车辆已停止充电" 或 "任务超时")
                t.column("finalMessage", .text)
                
                // 任务创建/开始的时间
                t.column("startTime", .datetime).notNull()
                
                // 任务结束的时间 (任务正在进行中时为 nil)
                t.column("endTime", .datetime)
                
                // 任务开始时的电量百分比 (State of Charge)
                t.column("startSoc", .integer)
                
                // 任务结束时的电量百分比
                t.column("endSoc", .integer)
                
                // 任务开始时的续航里程 (单位: km)
                t.column("startRange", .integer)
                
                // 任务结束时的续航里程 (单位: km)
                t.column("endRange", .integer)
            }
            
            // 如果未来有 tripRecord 表，也可以在这里创建
            // try db.create(table: "tripRecord") { ... }
        }
        
        // --- 版本 v2 (未来扩展用) ---
        // 如果未来您需要在 chargeTask 表中增加一个新字段，您可以这样写：
        // migrator.registerMigration("v2") { db in
        //     try db.alter(table: "chargeTask") { t in
        //         t.add(column: "newColumn", .text)
        //     }
        // }
        
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
