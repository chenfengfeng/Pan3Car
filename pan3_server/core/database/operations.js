// /www/wwwroot/pan3/core/database/operations.js

import { getDatabase } from './db.js';

// ==================== Vehicles 表操作 ====================

/**
 * 插入或更新车辆
 * @param {string} vin - 车辆 VIN
 * @param {string} apiToken - API Token (timaToken)
 * @returns {object} 操作结果
 */
export function upsertVehicle(vin, apiToken) {
    const db = getDatabase();
    const stmt = db.prepare(`
        INSERT INTO vehicles (vin, api_token, internal_state, next_poll_time)
        VALUES (?, ?, 'idle', datetime('now'))
        ON CONFLICT(vin) DO UPDATE SET
            api_token = excluded.api_token,
            next_poll_time = datetime('now')
    `);
    
    const result = stmt.run(vin, apiToken);
    return { success: true, changes: result.changes };
}

/**
 * 删除车辆
 * @param {string} vin - 车辆 VIN
 * @returns {object} 操作结果
 */
export function deleteVehicle(vin) {
    const db = getDatabase();
    const stmt = db.prepare('DELETE FROM vehicles WHERE vin = ?');
    const result = stmt.run(vin);
    return { success: true, changes: result.changes };
}

/**
 * 清空车辆的 API Token（用户退出登录时调用）
 * @param {string} vin - 车辆 VIN
 * @returns {object} 操作结果
 */
export function clearVehicleApiToken(vin) {
    const db = getDatabase();
    const stmt = db.prepare('UPDATE vehicles SET api_token = NULL WHERE vin = ?');
    const result = stmt.run(vin);
    return { success: true, changes: result.changes };
}

/**
 * 更新车辆的推送 Token
 * @param {string} vin - 车辆 VIN
 * @param {string} pushToken - 推送 Token
 * @returns {object} 操作结果
 */
export function updateVehiclePushToken(vin, pushToken) {
    const db = getDatabase();
    const stmt = db.prepare(`
        UPDATE vehicles 
        SET push_token = ? 
        WHERE vin = ?
    `);
    const result = stmt.run(pushToken, vin);
    return { success: true, changes: result.changes };
}

/**
 * 根据 VIN 获取车辆信息
 * @param {string} vin - 车辆 VIN
 * @returns {object|null} 车辆信息，包含 push_token 等字段
 */
export function getVehicleByVin(vin) {
    const db = getDatabase();
    const stmt = db.prepare('SELECT * FROM vehicles WHERE vin = ?');
    return stmt.get(vin);
}

/**
 * 获取待轮询的车辆列表
 * @returns {array} 车辆列表
 */
export function getVehiclesDueForPolling() {
    const db = getDatabase();
    const stmt = db.prepare(`
        SELECT * FROM vehicles 
        WHERE next_poll_time <= datetime('now')
            AND api_token IS NOT NULL
        ORDER BY next_poll_time ASC
    `);
    return stmt.all();
}

/**
 * 设置车辆为 active 状态（用户主动操作时调用）
 * @param {string} vin - 车辆 VIN
 */
export function setVehicleActive(vin) {
    const db = getDatabase();
    const stmt = db.prepare(`
        UPDATE vehicles SET
            internal_state = 'active',
            next_poll_time = datetime('now')
        WHERE vin = ?
    `);
    stmt.run(vin);
}

/**
 * 更新车辆轮询后的状态
 * @param {string} vin - 车辆 VIN
 * @param {object} updateData - 更新数据
 */
export function updateVehicleAfterPoll(vin, updateData) {
    const db = getDatabase();
    
    const fields = [];
    const values = [];
    
    if (updateData.internal_state !== undefined) {
        fields.push('internal_state = ?');
        values.push(updateData.internal_state);
    }
    if (updateData.next_poll_time !== undefined) {
        fields.push('next_poll_time = ?');
        values.push(updateData.next_poll_time);
    }
    if (updateData.last_keyStatus !== undefined) {
        fields.push('last_keyStatus = ?');
        values.push(updateData.last_keyStatus);
    }
    if (updateData.last_mainLockStatus !== undefined) {
        fields.push('last_mainLockStatus = ?');
        values.push(updateData.last_mainLockStatus);
    }
    if (updateData.last_chgStatus !== undefined) {
        fields.push('last_chgStatus = ?');
        values.push(updateData.last_chgStatus);
    }
    if (updateData.last_lat !== undefined) {
        fields.push('last_lat = ?');
        values.push(updateData.last_lat);
    }
    if (updateData.last_lon !== undefined) {
        fields.push('last_lon = ?');
        values.push(updateData.last_lon);
    }
    if (updateData.last_timestamp !== undefined) {
        fields.push('last_timestamp = ?');
        values.push(updateData.last_timestamp);
    }
    if (updateData.last_total_mileage !== undefined) {
        fields.push('last_total_mileage = ?');
        values.push(updateData.last_total_mileage);
    }
    if (updateData.current_drive_id !== undefined) {
        fields.push('current_drive_id = ?');
        values.push(updateData.current_drive_id);
    }
    if (updateData.current_charge_id !== undefined) {
        fields.push('current_charge_id = ?');
        values.push(updateData.current_charge_id);
    }
    if (updateData.last_calculated_speed !== undefined) {
        fields.push('last_calculated_speed = ?');
        values.push(updateData.last_calculated_speed);
    }
    
    if (fields.length > 0) {
        values.push(vin);
        const sql = `UPDATE vehicles SET ${fields.join(', ')} WHERE vin = ?`;
        const stmt = db.prepare(sql);
        stmt.run(...values);
    }
}

// ==================== Drives 表操作 ====================

/**
 * 创建行程记录
 * @param {object} driveData - 行程数据
 * @returns {number} 新创建的行程 ID
 */
export function createDrive(driveData) {
    const db = getDatabase();
    const stmt = db.prepare(`
        INSERT INTO drives (
            vin, start_time, start_lat, start_lon, start_soc, start_range_km
        ) VALUES (?, ?, ?, ?, ?, ?)
    `);
    
    const result = stmt.run(
        driveData.vin,
        driveData.start_time,
        driveData.start_lat,
        driveData.start_lon,
        driveData.start_soc,
        driveData.start_range_km
    );
    
    return result.lastInsertRowid;
}

/**
 * 更新行程记录
 * @param {number} driveId - 行程 ID
 * @param {object} updateData - 更新数据
 */
export function updateDrive(driveId, updateData) {
    const db = getDatabase();
    const stmt = db.prepare(`
        UPDATE drives SET
            end_time = ?,
            end_lat = ?,
            end_lon = ?,
            end_soc = ?,
            end_range_km = ?
        WHERE id = ?
    `);
    
    stmt.run(
        updateData.end_time,
        updateData.end_lat,
        updateData.end_lon,
        updateData.end_soc,
        updateData.end_range_km,
        driveId
    );
}

/**
 * 获取行程记录
 * @param {number} driveId - 行程 ID
 * @returns {object|null} 行程数据
 */
export function getDriveById(driveId) {
    const db = getDatabase();
    const stmt = db.prepare('SELECT * FROM drives WHERE id = ?');
    return stmt.get(driveId);
}

/**
 * 获取行程记录及其所有数据点（用于同步到app）
 * @param {number} driveId - 行程 ID
 * @returns {object|null} 包含行程记录和数据点的完整对象
 */
export function getDriveWithDataPoints(driveId) {
    const drive = getDriveById(driveId);
    if (!drive) {
        return null;
    }
    
    const dataPoints = getDataPointsByDriveId(driveId);
    
    return {
        ...drive,
        data_points: dataPoints
    };
}

/**
 * 根据VIN获取所有已完成的行程记录（用于同步到app）
 * @param {string} vin - 车辆 VIN
 * @param {number} limit - 最大数量（可选）
 * @param {number} offset - 偏移量（可选）
 * @returns {array} 行程记录列表
 */
export function getCompletedDrivesByVin(vin, limit = null, offset = 0) {
    const db = getDatabase();
    let sql = `
        SELECT * FROM drives 
        WHERE vin = ? 
        AND end_time IS NOT NULL
        AND summary_status = 'completed'
        ORDER BY start_time DESC
    `;
    
    if (limit !== null) {
        sql += ` LIMIT ? OFFSET ?`;
    }
    
    const stmt = db.prepare(sql);
    
    let result;
    if (limit !== null) {
        result = stmt.all(vin, limit, offset);
    } else {
        result = stmt.all(vin);
    }
    
    return result;
}

/**
 * 批量获取行程记录及其数据点（用于同步到app）
 * @param {string} vin - 车辆 VIN
 * @param {number} limit - 最大数量（可选）
 * @returns {array} 包含行程记录和数据点的完整数组
 */
export function getDrivesWithDataPointsByVin(vin, limit = null) {
    const drives = getCompletedDrivesByVin(vin, limit);
    
    return drives.map(drive => {
        const dataPoints = getDataPointsByDriveId(drive.id);
        return {
            ...drive,
            data_points: dataPoints
        };
    });
}

/**
 * 删除行程记录及其相关数据点
 * @param {number} driveId - 行程 ID
 */
export function deleteDrive(driveId) {
    const db = getDatabase();
    
    // 删除相关数据点
    const deleteDataPointsStmt = db.prepare('DELETE FROM data_points WHERE drive_id = ?');
    deleteDataPointsStmt.run(driveId);
    
    // 删除行程记录
    const deleteDriveStmt = db.prepare('DELETE FROM drives WHERE id = ?');
    deleteDriveStmt.run(driveId);
}

/**
 * 批量删除行程记录及其数据点（用于清理已同步的数据）
 * @param {array} driveIds - 行程记录 ID 数组
 * @returns {object} 删除统计信息
 */
export function deleteDrivesByIds(driveIds) {
    const db = getDatabase();
    let deletedDrives = 0;
    let deletedDataPoints = 0;
    
    const deleteDataPointsStmt = db.prepare('DELETE FROM data_points WHERE drive_id = ?');
    const deleteDriveStmt = db.prepare('DELETE FROM drives WHERE id = ?');
    
    for (const driveId of driveIds) {
        const dataPointsResult = deleteDataPointsStmt.run(driveId);
        deletedDataPoints += dataPointsResult.changes;
        
        const driveResult = deleteDriveStmt.run(driveId);
        deletedDrives += driveResult.changes;
    }
    
    return {
        deletedDrives,
        deletedDataPoints
    };
}

// ==================== Charges 表操作 ====================

/**
 * 创建充电记录
 * @param {object} chargeData - 充电数据
 * @returns {number} 新创建的充电 ID
 */
export function createCharge(chargeData) {
    const db = getDatabase();
    const stmt = db.prepare(`
        INSERT INTO charges (
            vin, start_time, start_soc, start_range_km, lat, lon
        ) VALUES (?, ?, ?, ?, ?, ?)
    `);
    
    const result = stmt.run(
        chargeData.vin,
        chargeData.start_time,
        chargeData.start_soc,
        chargeData.start_range_km,
        chargeData.lat,
        chargeData.lon
    );
    
    return result.lastInsertRowid;
}

/**
 * 更新充电记录
 * @param {number} chargeId - 充电 ID
 * @param {object} updateData - 更新数据
 */
export function updateCharge(chargeId, updateData) {
    const db = getDatabase();
    const stmt = db.prepare(`
        UPDATE charges SET
            end_time = ?,
            end_soc = ?,
            end_range_km = ?
        WHERE id = ?
    `);
    
    stmt.run(
        updateData.end_time,
        updateData.end_soc,
        updateData.end_range_km,
        chargeId
    );
}

/**
 * 获取充电记录
 * @param {number} chargeId - 充电 ID
 * @returns {object|null} 充电数据
 */
export function getChargeById(chargeId) {
    const db = getDatabase();
    const stmt = db.prepare('SELECT * FROM charges WHERE id = ?');
    return stmt.get(chargeId);
}

/**
 * 根据VIN获取所有已完成的充电记录（用于同步到app）
 * @param {string} vin - 车辆 VIN
 * @param {number} limit - 最大数量（可选）
 * @param {number} offset - 偏移量（可选）
 * @returns {array} 充电记录列表
 */
export function getCompletedChargesByVin(vin, limit = null, offset = 0) {
    const db = getDatabase();
    let sql = `
        SELECT * FROM charges 
        WHERE vin = ? 
        AND end_time IS NOT NULL
        AND summary_status = 'completed'
        ORDER BY start_time DESC
    `;
    
    if (limit !== null) {
        sql += ` LIMIT ? OFFSET ?`;
    }
    
    const stmt = db.prepare(sql);
    
    let result;
    if (limit !== null) {
        result = stmt.all(vin, limit, offset);
    } else {
        result = stmt.all(vin);
    }
    
    return result;
}

/**
 * 获取充电记录及其所有数据点（用于同步到app）
 * @param {number} chargeId - 充电 ID
 * @returns {object|null} 包含充电记录和数据点的完整对象
 */
export function getChargeWithDataPoints(chargeId) {
    const charge = getChargeById(chargeId);
    if (!charge) {
        return null;
    }
    
    const dataPoints = getDataPointsByChargeId(chargeId);
    
    return {
        ...charge,
        data_points: dataPoints
    };
}

/**
 * 批量获取充电记录及其数据点（用于同步到app）
 * @param {string} vin - 车辆 VIN
 * @param {number} limit - 最大数量（可选）
 * @returns {array} 包含充电记录和数据点的完整数组
 */
export function getChargesWithDataPointsByVin(vin, limit = null) {
    const charges = getCompletedChargesByVin(vin, limit);
    
    return charges.map(charge => {
        const dataPoints = getDataPointsByChargeId(charge.id);
        return {
            ...charge,
            data_points: dataPoints
        };
    });
}

/**
 * 删除充电记录及其相关数据点
 * @param {number} chargeId - 充电 ID
 */
export function deleteCharge(chargeId) {
    const db = getDatabase();
    
    // 删除相关数据点
    const deleteDataPointsStmt = db.prepare('DELETE FROM data_points WHERE charge_id = ?');
    deleteDataPointsStmt.run(chargeId);
    
    // 删除充电记录
    const deleteChargeStmt = db.prepare('DELETE FROM charges WHERE id = ?');
    deleteChargeStmt.run(chargeId);
}

/**
 * 批量删除充电记录及其数据点（用于清理已同步的数据）
 * @param {array} chargeIds - 充电记录 ID 数组
 * @returns {object} 删除统计信息
 */
export function deleteChargesByIds(chargeIds) {
    const db = getDatabase();
    let deletedCharges = 0;
    let deletedDataPoints = 0;
    
    const deleteDataPointsStmt = db.prepare('DELETE FROM data_points WHERE charge_id = ?');
    const deleteChargeStmt = db.prepare('DELETE FROM charges WHERE id = ?');
    
    for (const chargeId of chargeIds) {
        const dataPointsResult = deleteDataPointsStmt.run(chargeId);
        deletedDataPoints += dataPointsResult.changes;
        
        const chargeResult = deleteChargeStmt.run(chargeId);
        deletedCharges += chargeResult.changes;
    }
    
    return {
        deletedCharges,
        deletedDataPoints
    };
}

// ==================== DataPoints 表操作 ====================

/**
 * 获取行程的所有数据点
 * @param {number} driveId - 行程 ID
 * @returns {array} 数据点列表
 */
export function getDataPointsByDriveId(driveId) {
    const db = getDatabase();
    const stmt = db.prepare(`
        SELECT * FROM data_points 
        WHERE drive_id = ? 
        ORDER BY timestamp ASC
    `);
    return stmt.all(driveId);
}

/**
 * 获取充电的所有数据点
 * @param {number} chargeId - 充电 ID
 * @returns {array} 数据点列表
 */
export function getDataPointsByChargeId(chargeId) {
    const db = getDatabase();
    const stmt = db.prepare(`
        SELECT * FROM data_points 
        WHERE charge_id = ? 
        ORDER BY timestamp ASC
    `);
    return stmt.all(chargeId);
}

/**
 * 获取行程的统计数据（使用 SQL 聚合，高效）
 * @param {number} driveId - 行程 ID
 * @returns {object} 统计数据
 */
export function getDriveStatistics(driveId) {
    const db = getDatabase();
    const stmt = db.prepare(`
        SELECT 
            COUNT(*) as data_points_count,
            0 as max_speed,
            CAST(AVG(calculated_speed_kmh) AS INTEGER) as avg_speed
        FROM data_points 
        WHERE drive_id = ? 
          AND calculated_speed_kmh IS NOT NULL
    `);
    return stmt.get(driveId);
}

/**
 * 获取充电的统计数据
 * @param {number} chargeId - 充电 ID
 * @returns {object} 统计数据
 */
export function getChargeStatistics(chargeId) {
    const db = getDatabase();
    const stmt = db.prepare(`
        SELECT 
            COUNT(*) as data_points_count
        FROM data_points 
        WHERE charge_id = ?
    `);
    return stmt.get(chargeId);
}

/**
 * 获取待计算摘要的行程（批量）
 * @param {number} limit - 最大数量
 * @returns {array} 行程列表
 */
export function getPendingDrives(limit = 10) {
    const db = getDatabase();
    const stmt = db.prepare(`
        SELECT * FROM drives 
        WHERE summary_status = 'pending' 
        AND end_time IS NOT NULL
        ORDER BY end_time ASC 
        LIMIT ?
    `);
    return stmt.all(limit);
}

/**
 * 获取待计算摘要的充电（批量）
 * @param {number} limit - 最大数量
 * @returns {array} 充电列表
 */
export function getPendingCharges(limit = 10) {
    const db = getDatabase();
    const stmt = db.prepare(`
        SELECT * FROM charges 
        WHERE summary_status = 'pending' 
        AND end_time IS NOT NULL
        ORDER BY end_time ASC 
        LIMIT ?
    `);
    return stmt.all(limit);
}

/**
 * 更新行程摘要状态和数据
 * @param {number} driveId - 行程 ID
 * @param {object} summaryData - 摘要数据
 */
export function updateDriveSummary(driveId, summaryData) {
    const db = getDatabase();
    const stmt = db.prepare(`
        UPDATE drives SET
            summary_status = ?,
            total_distance = ?,
            consumed_range = ?,
            max_speed = ?,
            avg_speed = ?,
            data_points_count = ?
        WHERE id = ?
    `);
    
    stmt.run(
        summaryData.summary_status,
        summaryData.total_distance !== undefined ? summaryData.total_distance : null,
        summaryData.consumed_range !== undefined ? summaryData.consumed_range : null,
        summaryData.max_speed !== undefined ? summaryData.max_speed : null,
        summaryData.avg_speed !== undefined ? summaryData.avg_speed : null,
        summaryData.data_points_count !== undefined ? summaryData.data_points_count : null,
        driveId
    );
}

/**
 * 更新充电摘要状态和数据
 * @param {number} chargeId - 充电 ID
 * @param {object} summaryData - 摘要数据
 */
export function updateChargeSummary(chargeId, summaryData) {
    const db = getDatabase();
    const stmt = db.prepare(`
        UPDATE charges SET
            summary_status = ?,
            added_range = ?,
            data_points_count = ?
        WHERE id = ?
    `);
    
    stmt.run(
        summaryData.summary_status,
        summaryData.added_range !== undefined ? summaryData.added_range : null,
        summaryData.data_points_count !== undefined ? summaryData.data_points_count : null,
        chargeId
    );
}

// ==================== Charge Tasks 表操作 ====================

/**
 * 创建充电任务
 * @param {object} taskData - 任务数据
 * @returns {number} 任务 ID
 */
export function createChargeTask(taskData) {
    const db = getDatabase();
    const stmt = db.prepare(`
        INSERT INTO charge_tasks (
            vin, mode, tima_token, push_token, activity_token,
            target_timestamp, auto_stop_charge,
            target_mile, initial_km, initial_soc, start_time,
            created_at, last_updated
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    
    const result = stmt.run(
        taskData.vin,
        taskData.mode,
        taskData.tima_token,
        taskData.push_token || null,
        taskData.activity_token || null,
        taskData.target_timestamp || null,
        taskData.auto_stop_charge || 0,
        taskData.target_mile || null,
        taskData.initial_km || null,
        taskData.initial_soc || null,
        taskData.start_time || null,
        taskData.created_at,
        new Date().toISOString()
    );
    
    return result.lastInsertRowid;
}

/**
 * 根据 VIN 获取充电任务
 * @param {string} vin - 车辆 VIN
 * @returns {object|null} 任务数据
 */
export function getChargeTaskByVin(vin) {
    const db = getDatabase();
    const stmt = db.prepare('SELECT * FROM charge_tasks WHERE vin = ?');
    return stmt.get(vin);
}

/**
 * 根据 ID 获取充电任务
 * @param {number} id - 任务 ID
 * @returns {object|null} 任务数据
 */
export function getChargeTaskById(id) {
    const db = getDatabase();
    const stmt = db.prepare('SELECT * FROM charge_tasks WHERE id = ?');
    return stmt.get(id);
}

/**
 * 获取指定模式的所有充电任务
 * @param {string} mode - 'time' 或 'range'
 * @returns {array} 任务列表
 */
export function getChargeTasksByMode(mode) {
    const db = getDatabase();
    const stmt = db.prepare('SELECT * FROM charge_tasks WHERE mode = ?');
    return stmt.all(mode);
}

/**
 * 获取所有待执行的时间任务（未过期）
 * @returns {array} 任务列表
 */
export function getPendingTimeChargeTasks() {
    const db = getDatabase();
    const now = Math.floor(Date.now() / 1000);
    const stmt = db.prepare(`
        SELECT * FROM charge_tasks 
        WHERE mode = 'time' 
          AND target_timestamp > ?
        ORDER BY target_timestamp ASC
    `);
    return stmt.all(now);
}

/**
 * 更新充电任务
 * @param {number} id - 任务 ID
 * @param {object} updates - 更新数据
 */
export function updateChargeTask(id, updates) {
    const db = getDatabase();
    const fields = [];
    const values = [];
    
    for (const [key, value] of Object.entries(updates)) {
        fields.push(`${key} = ?`);
        values.push(value);
    }
    
    if (fields.length === 0) return;
    
    // 添加 last_updated
    fields.push('last_updated = ?');
    values.push(new Date().toISOString());
    values.push(id);
    
    const stmt = db.prepare(`
        UPDATE charge_tasks 
        SET ${fields.join(', ')}
        WHERE id = ?
    `);
    
    stmt.run(...values);
}

/**
 * 更新充电任务的 Activity Token
 * @param {string} vin - 车辆 VIN
 * @param {string} activityToken - Activity Token
 */
export function updateChargeTaskActivityToken(vin, activityToken) {
    const db = getDatabase();
    const stmt = db.prepare(`
        UPDATE charge_tasks 
        SET activity_token = ?, last_updated = ?
        WHERE vin = ?
    `);
    
    stmt.run(activityToken, new Date().toISOString(), vin);
}

/**
 * 根据 ID 删除充电任务
 * @param {number} id - 任务 ID
 */
export function deleteChargeTask(id) {
    const db = getDatabase();
    const stmt = db.prepare('DELETE FROM charge_tasks WHERE id = ?');
    stmt.run(id);
}

/**
 * 根据 VIN 删除充电任务
 * @param {string} vin - 车辆 VIN
 */
export function deleteChargeTaskByVin(vin) {
    const db = getDatabase();
    const stmt = db.prepare('DELETE FROM charge_tasks WHERE vin = ?');
    stmt.run(vin);
}

// ==================== DataPoints 表操作 ====================

/**
 * 插入数据点
 * @param {object} dataPointData - 数据点数据
 */
export function insertDataPoint(dataPointData) {
    const db = getDatabase();
    const stmt = db.prepare(`
        INSERT INTO data_points (
            timestamp, vin, lat, lon, soc, remaining_range_km, total_mileage,
            keyStatus, mainLockStatus, chgPlugStatus, chgStatus, chgLeftTime,
            calculated_speed_kmh, drive_id, charge_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    
    stmt.run(
        dataPointData.timestamp,
        dataPointData.vin,
        dataPointData.lat,
        dataPointData.lon,
        dataPointData.soc,
        dataPointData.remaining_range_km || null,
        dataPointData.total_mileage || null,
        dataPointData.keyStatus,
        dataPointData.mainLockStatus,
        dataPointData.chgPlugStatus,
        dataPointData.chgStatus,
        dataPointData.chgLeftTime,
        dataPointData.calculated_speed_kmh,
        dataPointData.drive_id || null,
        dataPointData.charge_id || null
    );
}

/**
 * 删除指定VIN的所有空闲状态数据点
 * @param {string} vin - 车辆VIN
 * @returns {number} 删除的数据点数量
 */
export function deleteOrphanedDataPointsForVin(vin) {
    const db = getDatabase();
    
    // 删除该VIN的所有空闲数据点（插入新的后就只有1条）
    const stmt = db.prepare(`
        DELETE FROM data_points 
        WHERE vin = ? 
        AND drive_id IS NULL 
        AND charge_id IS NULL
    `);
    
    const result = stmt.run(vin);
    return result.changes;
}

/**
 * 清理所有VIN的孤立数据点（删除所有空闲状态的数据点）
 * @returns {number} 删除的数据点数量
 */
export function cleanAllOrphanedDataPoints() {
    const db = getDatabase();
    
    // 获取所有有空闲数据点的VIN
    const vinsStmt = db.prepare(`
        SELECT DISTINCT vin 
        FROM data_points 
        WHERE drive_id IS NULL 
        AND charge_id IS NULL
    `);
    const vins = vinsStmt.all();
    
    let totalDeleted = 0;
    
    for (const { vin } of vins) {
        const deleted = deleteOrphanedDataPointsForVin(vin);
        totalDeleted += deleted;
        if (deleted > 0) {
            console.log(`[cleanOrphanedDataPoints] VIN: ${vin}, 删除了 ${deleted} 条空闲数据点`);
        }
    }
    
    console.log(`[cleanOrphanedDataPoints] 总共删除了 ${totalDeleted} 条空闲数据点`);
    return totalDeleted;
}

