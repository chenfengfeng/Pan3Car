// /www/wwwroot/pan3/app.js

import path from 'path';
import express from 'express';
import { execFile } from 'child_process';

import authRoutes from './api/auth/auth.routes.js'; // 导入您的用户认证路由
import pushRoutes from './api/push/push.routes.js'; // 导入推送路由
import carRoutes from './api/car/car.routes.js'; // 导入车辆路由
import chargeRoutes from './api/charge/charge.routes.js'; // 导入充电路由
import { restoreTimeTasks } from './api/charge/charge.controller.js'; // 导入时间任务恢复函数

const app = express();
const PORT = process.env.PORT || 3333;

// [重要] 添加JSON解析中间件，这样才能解析 application/json 格式的请求体
app.use(express.json());

// --- 挂载路由 ---
app.use('/api/auth', authRoutes);
app.use('/api/push', pushRoutes);
app.use('/api/car', carRoutes);
app.use('/api/charge', chargeRoutes);

// --- 启动服务器 ---
app.listen(PORT, () => {
  console.log(`服务已启动，正在监听端口: ${PORT}`); 
  
  // 服务启动后恢复时间任务
  console.log('正在恢复时间任务...');
  try {
    restoreTimeTasks();
  } catch (error) {
    console.error('恢复时间任务失败:', error);
  }
});