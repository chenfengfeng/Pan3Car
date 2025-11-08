// /www/wwwroot/pan3/api/charge/charge.routes.js

import express from 'express';
import { verifyToken } from '../../core/middlewares/auth.middleware.js';
import { 
    startMonitoring, 
    stopMonitoring, 
    updateLiveActivityToken,
    getChargeRecords,
    confirmChargeSyncComplete
} from './charge.controller.js';

const router = express.Router();

// 定义启动充电监控的接口
router.post('/start', verifyToken, startMonitoring);
// 定义手动停止任务的接口
router.post('/stop', verifyToken, stopMonitoring);
// 获取充电记录列表（包含data_points）
router.post('/records', verifyToken, getChargeRecords);
// 确认充电数据同步完成
router.post('/sync-complete', verifyToken, confirmChargeSyncComplete);
// 定义更新实时活动Token的接口
router.post('/update-token', verifyToken, updateLiveActivityToken);

export default router;