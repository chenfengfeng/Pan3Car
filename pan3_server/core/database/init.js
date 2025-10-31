// /www/wwwroot/pan3/core/database/init.js

import { getDatabase } from './db.js';

/**
 * 初始化数据库表结构
 */
export function initDatabase() {
    console.log('[Database Init] 开始初始化数据库表结构...');
    
    const db = getDatabase();
    
    try {
        // 创建 vehicles 表
        db.exec(`
            CREATE TABLE IF NOT EXISTS vehicles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vin VARCHAR(32) UNIQUE NOT NULL,
                api_token VARCHAR(255),
                push_token TEXT,
                internal_state VARCHAR(20),
                next_poll_time DATETIME,
                last_keyStatus VARCHAR(16),
                last_mainLockStatus VARCHAR(16),
                last_chgStatus VARCHAR(16),
                last_lat DECIMAL(10, 7),
                last_lon DECIMAL(10, 7),
                last_timestamp BIGINT,
                current_drive_id INTEGER,
                current_charge_id INTEGER
            );
        `);
        console.log('[Database Init] ✓ vehicles 表已创建');
        
        // 创建 drives 表
        db.exec(`
            CREATE TABLE IF NOT EXISTS drives (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vin VARCHAR(32) NOT NULL,
                start_time DATETIME NOT NULL,
                end_time DATETIME,
                start_lat DECIMAL(10, 7),
                start_lon DECIMAL(10, 7),
                end_lat DECIMAL(10, 7),
                end_lon DECIMAL(10, 7),
                start_soc INTEGER,
                end_soc INTEGER,
                start_range_km INTEGER,
                end_range_km INTEGER,
                summary_status VARCHAR(20) DEFAULT 'pending',
                total_distance DECIMAL(10, 2),
                consumed_range INTEGER,
                max_speed INTEGER,
                avg_speed INTEGER,
                data_points_count INTEGER
            );
        `);
        console.log('[Database Init] ✓ drives 表已创建');
        
        // 创建 drives 表索引
        db.exec(`
            CREATE INDEX IF NOT EXISTS idx_drives_vin_start_time 
            ON drives(vin, start_time);
        `);
        console.log('[Database Init] ✓ drives 表索引已创建');
        
        // 创建 charges 表
        db.exec(`
            CREATE TABLE IF NOT EXISTS charges (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vin VARCHAR(32) NOT NULL,
                start_time DATETIME NOT NULL,
                end_time DATETIME,
                start_soc INTEGER,
                end_soc INTEGER,
                start_range_km INTEGER,
                end_range_km INTEGER,
                lat DECIMAL(10, 7),
                lon DECIMAL(10, 7),
                summary_status VARCHAR(20) DEFAULT 'pending',
                added_range INTEGER,
                data_points_count INTEGER
            );
        `);
        console.log('[Database Init] ✓ charges 表已创建');
        
        // 创建 charges 表索引
        db.exec(`
            CREATE INDEX IF NOT EXISTS idx_charges_vin_start_time 
            ON charges(vin, start_time);
        `);
        console.log('[Database Init] ✓ charges 表索引已创建');

        // 创建 charge_tasks 表（充电任务管理）
        db.exec(`
            CREATE TABLE IF NOT EXISTS charge_tasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vin VARCHAR(32) NOT NULL UNIQUE,
                mode VARCHAR(10) NOT NULL,
                tima_token TEXT NOT NULL,
                push_token TEXT,
                activity_token TEXT,
                target_timestamp INTEGER,
                auto_stop_charge INTEGER DEFAULT 0,
                target_mile INTEGER,
                initial_km INTEGER,
                initial_soc INTEGER,
                start_time INTEGER,
                created_at DATETIME NOT NULL,
                last_updated DATETIME,
                CHECK (mode IN ('time', 'range'))
            );
        `);
        console.log('[Database Init] ✓ charge_tasks 表已创建');

        // 创建 charge_tasks 表索引
        db.exec(`
            CREATE INDEX IF NOT EXISTS idx_charge_tasks_mode 
            ON charge_tasks(mode);
        `);
        db.exec(`
            CREATE INDEX IF NOT EXISTS idx_charge_tasks_target_timestamp 
            ON charge_tasks(target_timestamp);
        `);
        console.log('[Database Init] ✓ charge_tasks 表索引已创建');
        
        // 创建 data_points 表
        db.exec(`
            CREATE TABLE IF NOT EXISTS data_points (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME NOT NULL,
                vin VARCHAR(32) NOT NULL,
                lat DECIMAL(10, 7),
                lon DECIMAL(10, 7),
                soc INTEGER,
                remaining_range_km INTEGER,
                total_mileage VARCHAR(20),
                keyStatus VARCHAR(16),
                mainLockStatus VARCHAR(16),
                chgPlugStatus VARCHAR(16),
                chgStatus VARCHAR(16),
                chgLeftTime INTEGER,
                calculated_speed_kmh INTEGER,
                drive_id INTEGER,
                charge_id INTEGER
            );
        `);
        console.log('[Database Init] ✓ data_points 表已创建');
        
        // 创建 data_points 表索引
        db.exec(`
            CREATE INDEX IF NOT EXISTS idx_data_points_timestamp 
            ON data_points(timestamp);
            
            CREATE INDEX IF NOT EXISTS idx_data_points_vin 
            ON data_points(vin);
            
            CREATE INDEX IF NOT EXISTS idx_data_points_drive_id 
            ON data_points(drive_id);
            
            CREATE INDEX IF NOT EXISTS idx_data_points_charge_id 
            ON data_points(charge_id);
        `);
        console.log('[Database Init] ✓ data_points 表索引已创建');
        
        console.log('[Database Init] 数据库初始化完成！');
    } catch (error) {
        console.error('[Database Init] 数据库初始化失败:', error);
        throw error;
    }
}

