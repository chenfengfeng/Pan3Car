// /www/wwwroot/pan3/api/trip/trip.controller.js

import { getDrivesWithDataPointsByVin, deleteDrivesByIds } from '../../core/database/operations.js';

/**
 * 获取行程记录接口（用于同步到app）
 * 返回包含完整data_points的行程记录
 */
export async function getTripRecords(req, res) {
    try {
        const timaToken = req.headers.timatoken;
        const { vin, limit } = req.body;
        
        // 参数验证
        if (!vin || !timaToken) {
            return res.status(400).json({
                code: 400,
                message: '缺少必要参数 (vin, timaToken)'
            });
        }
                
        // 从数据库获取已完成的行程记录（包含data_points）
        const trips = getDrivesWithDataPointsByVin(vin, limit);
        
        return res.status(200).json({
            code: 200,
            message: '获取行程记录成功',
            data: {
                trips: trips,
                count: trips.length
            }
        });
        
    } catch (error) {
        console.error('[getTripRecords] 接口异常:', error.message);
        res.status(500).json({
            code: 500,
            message: `获取行程记录失败: ${error.message}`
        });
    }
}

/**
 * 确认行程数据同步完成接口
 * app同步数据到本地CoreData后，调用此接口通知服务器删除对应数据
 */
export async function confirmTripSyncComplete(req, res) {
    try {
        const timaToken = req.headers.timatoken;
        const { vin, tripIds } = req.body;
        
        // 参数验证
        if (!vin || !timaToken || !tripIds || !Array.isArray(tripIds)) {
            return res.status(400).json({
                code: 400,
                message: '缺少必要参数 (vin, timaToken, tripIds)'
            });
        }
        
        console.log(`[confirmTripSyncComplete] VIN: ${vin}, 待删除行程数量: ${tripIds.length}`);
        
        // 批量删除行程记录及其数据点
        const result = deleteDrivesByIds(tripIds);
        
        console.log(`[confirmTripSyncComplete] 删除成功 - 行程记录: ${result.deletedDrives} 条, 数据点: ${result.deletedDataPoints} 个`);
        
        return res.status(200).json({
            code: 200,
            message: '同步确认成功',
            data: {
                deletedTrips: result.deletedDrives,
                deletedDataPoints: result.deletedDataPoints
            }
        });
        
    } catch (error) {
        console.error('[confirmTripSyncComplete] 接口异常:', error.message);
        res.status(500).json({
            code: 500,
            message: `同步确认失败: ${error.message}`
        });
    }
}

