// /www/wwwroot/pan3/core/database/db.js

import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';

// 获取当前文件的目录（ES 模块需要手动处理 __dirname）
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 数据库文件路径：项目根目录下的 pan3_data.db
const DB_PATH = path.join(__dirname, '../../pan3_data.db');

// 数据库实例（单例）
let dbInstance = null;

/**
 * 获取数据库连接实例
 * @returns {Database} SQLite 数据库实例
 */
export function getDatabase() {
    if (!dbInstance) {
        dbInstance = new Database(DB_PATH);
        // 启用 WAL 模式，提升并发性能
        dbInstance.pragma('journal_mode = WAL');
        // 启用外键约束
        dbInstance.pragma('foreign_keys = ON');
        console.log(`[Database] 数据库连接已建立: ${DB_PATH}`);
    }
    return dbInstance;
}

/**
 * 关闭数据库连接
 */
export function closeDatabase() {
    if (dbInstance) {
        dbInstance.close();
        dbInstance = null;
        console.log('[Database] 数据库连接已关闭');
    }
}

