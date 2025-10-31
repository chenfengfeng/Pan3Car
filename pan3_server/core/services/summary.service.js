// /www/wwwroot/pan3/core/services/summary.service.js

import { getPendingDrives, getPendingCharges, updateDriveSummary, updateChargeSummary, getDataPointsByDriveId, getDataPointsByChargeId, getDriveStatistics, getChargeStatistics } from '../database/operations.js';

// 摘要计算间隔（毫秒）
const SUMMARY_INTERVAL = 30000;  // 30 秒

// 每次处理的最大数量
const BATCH_SIZE = 10;

// 服务状态
let isSummaryServiceActive = false;
let summaryTimeoutId = null;

/**
 * 启动摘要计算服务
 */
export function startSummaryService() {
    if (isSummaryServiceActive) {
        console.log('[Summary Service] 摘要服务已在运行中');
        return;
    }
    
    isSummaryServiceActive = true;
    console.log('[Summary Service] 摘要服务已启动');
    scheduleNextSummary();
}

/**
 * 停止摘要计算服务
 */
export function stopSummaryService() {
    isSummaryServiceActive = false;
    if (summaryTimeoutId) {
        clearTimeout(summaryTimeoutId);
        summaryTimeoutId = null;
    }
    console.log('[Summary Service] 摘要服务已停止');
}

/**
 * 调度下一次摘要计算
 */
function scheduleNextSummary() {
    if (!isSummaryServiceActive) return;
    
    summaryTimeoutId = setTimeout(async () => {
        await performSummaryCycle();
        scheduleNextSummary(); // 递归链
    }, SUMMARY_INTERVAL);
}

/**
 * 执行一次完整的摘要计算周期
 */
async function performSummaryCycle() {
    try {
        // 处理待计算的行程
        const pendingDrives = getPendingDrives(BATCH_SIZE);
        if (pendingDrives.length > 0) {
            console.log(`[Summary Service] 开始处理 ${pendingDrives.length} 个行程摘要`);
            await Promise.allSettled(
                pendingDrives.map(drive => processDriveSummary(drive))
            );
        }
        
        // 处理待计算的充电
        const pendingCharges = getPendingCharges(BATCH_SIZE);
        if (pendingCharges.length > 0) {
            console.log(`[Summary Service] 开始处理 ${pendingCharges.length} 个充电摘要`);
            await Promise.allSettled(
                pendingCharges.map(charge => processChargeSummary(charge))
            );
        }
        
    } catch (error) {
        console.error('[Summary Service] 摘要计算周期执行异常:', error);
    }
}

/**
 * 处理单个行程的摘要计算
 * @param {object} drive - 行程记录
 */
async function processDriveSummary(drive) {
    const driveId = drive.id;
    
    try {
        // 标记为计算中
        updateDriveSummary(driveId, { summary_status: 'calculating' });
        
        // ✅ 优化1：使用 SQL 聚合查询速度统计（~1ms）
        const statistics = getDriveStatistics(driveId);
        
        if (!statistics || statistics.data_points_count === 0) {
            updateDriveSummary(driveId, {
                summary_status: 'completed',
                total_distance: 0,
                consumed_range: 0,
                max_speed: 0,
                avg_speed: 0,
                data_points_count: 0
            });
            return;
        }
        
        // ✅ 优化2：只获取首尾两个数据点（用于计算距离和续航）
        const dataPoints = getDataPointsByDriveId(driveId);
        const firstPoint = dataPoints[0];
        const lastPoint = dataPoints[dataPoints.length - 1];
        
        // 计算实际行驶距离（基于 totalMileage 差值，最简单准确）
        let totalDistance = 0;
        if (firstPoint.total_mileage && lastPoint.total_mileage) {
            const startMileage = parseFloat(firstPoint.total_mileage);
            const endMileage = parseFloat(lastPoint.total_mileage);
            totalDistance = endMileage - startMileage;
        }
        
        // 计算消耗续航（基于 remaining_range_km）
        let consumedRange = 0;
        if (firstPoint.remaining_range_km && lastPoint.remaining_range_km) {
            consumedRange = firstPoint.remaining_range_km - lastPoint.remaining_range_km;
        }
        
        // 更新摘要数据（包含速度统计）
        updateDriveSummary(driveId, {
            summary_status: 'completed',
            total_distance: totalDistance,
            consumed_range: consumedRange,
            max_speed: statistics.max_speed || 0,        // 最高速度（来自SQL聚合）
            avg_speed: statistics.avg_speed || 0,        // 平均速度（来自SQL聚合）
            data_points_count: statistics.data_points_count
        });
        
        console.log(`[Summary Service] 行程 ${driveId} 摘要完成 - 距离: ${totalDistance.toFixed(2)}km, 消耗: ${consumedRange}km, 最高: ${statistics.max_speed}km/h, 平均: ${statistics.avg_speed}km/h, 点数: ${statistics.data_points_count}`);
        
    } catch (error) {
        console.error(`[Summary Service] 行程 ${driveId} 摘要计算失败:`, error.message);
        
        // 标记为失败
        updateDriveSummary(driveId, { summary_status: 'failed' });
    }
}

/**
 * 处理单个充电的摘要计算
 * @param {object} charge - 充电记录
 */
async function processChargeSummary(charge) {
    const chargeId = charge.id;
    
    try {
        // 标记为计算中
        updateChargeSummary(chargeId, { summary_status: 'calculating' });
        
        // ✅ 优化1：使用 SQL 聚合查询统计
        const statistics = getChargeStatistics(chargeId);
        
        if (!statistics || statistics.data_points_count === 0) {
            updateChargeSummary(chargeId, {
                summary_status: 'completed',
                added_range: 0,
                data_points_count: 0
            });
            return;
        }
        
        // ✅ 优化2：只获取首尾两个数据点
        const dataPoints = getDataPointsByChargeId(chargeId);
        const firstPoint = dataPoints[0];
        const lastPoint = dataPoints[dataPoints.length - 1];
        
        // 计算增加的续航
        let addedRange = 0;
        if (lastPoint.remaining_range_km && firstPoint.remaining_range_km) {
            addedRange = lastPoint.remaining_range_km - firstPoint.remaining_range_km;
        }
        
        // 更新摘要数据
        updateChargeSummary(chargeId, {
            summary_status: 'completed',
            added_range: addedRange,
            data_points_count: statistics.data_points_count
        });
        
        console.log(`[Summary Service] 充电 ${chargeId} 摘要完成 - 增加: ${addedRange}km, 点数: ${statistics.data_points_count}`);
        
    } catch (error) {
        console.error(`[Summary Service] 充电 ${chargeId} 摘要计算失败:`, error.message);
        
        // 标记为失败
        updateChargeSummary(chargeId, { summary_status: 'failed' });
    }
}

