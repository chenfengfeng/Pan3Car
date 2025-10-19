// /www/wwwroot/pan3/api/push/push.routes.js

import express from 'express';
import { handlePushRequest, handleLiveActivityPush } from './push.controller.js';

const router = express.Router();

// 已有的标准推送接口
router.post('/', handlePushRequest);

// 添加/send路由以匹配charge.controller.js中的调用
router.post('/send', handlePushRequest);

// 实时活动推送接口
router.post('/live-activity', handleLiveActivityPush);

export default router;