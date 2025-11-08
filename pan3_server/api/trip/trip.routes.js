// /www/wwwroot/pan3/api/trip/trip.routes.js

import express from 'express';
import { getTripRecords, confirmTripSyncComplete } from './trip.controller.js';

const router = express.Router();

// 获取行程记录（包含完整数据点）
router.post('/records', getTripRecords);

// 确认行程数据同步完成（通知服务器删除数据）
router.post('/sync-complete', confirmTripSyncComplete);

export default router;

