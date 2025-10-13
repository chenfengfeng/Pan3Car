// /www/wwwroot/pan3/api/car/car.routes.js

import express from 'express';
import { getVehicleInfo, controlVehicle } from './car.controller.js';
import { verifyToken } from '../../core/middlewares/auth.middleware.js';

const router = express.Router();

// 获取车辆信息的接口
router.post('/info', verifyToken, getVehicleInfo);
// 车辆控制接口
router.post('/sync', verifyToken, controlVehicle);

export default router;