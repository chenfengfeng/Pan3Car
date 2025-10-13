// /www/wwwroot/pan3/app.js

import path from 'path';
import express from 'express';
import { execFile } from 'child_process';

import authRoutes from './api/auth/auth.routes.js'; // 导入您的用户认证路由
import pushRoutes from './api/push/push.routes.js'; // 导入推送路由
import carRoutes from './api/car/car.routes.js'; // 导入车辆路由
import chargeRoutes from './api/charge/charge.routes.js'; // 导入充电路由

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
  // 在服务成功启动后，立即执行一次任务恢复脚本
  console.log('正在启动任务恢复脚本...');
  const resumeScriptPath = path.join(process.cwd(), 'cli', 'resume-tasks.js');
  execFile('node', [resumeScriptPath], (error, stdout, stderr) => {
      if (error) {
          console.error('任务恢复脚本执行失败:', error);
          return;
      }
      if (stdout) console.log('任务恢复脚本输出:', stdout);
      if (stderr) console.error('任务恢复脚本错误输出:', stderr);
  });
});