// /www/wwwroot/pan3/api/charge/charge.controller.js

import path from 'path';
import fs from 'fs/promises';
import { execFile } from 'child_process';

const TASKS_FILE_PATH = path.join(process.cwd(), 'charge_tasks.json');

/**
 * 启动充电监控任务
 */
export async function startMonitoring(req, res) {
    const timaToken = req.headers.timatoken;
    const taskDetailsFromApp = req.body;
    const { vin } = taskDetailsFromApp;

    if (!vin || !taskDetailsFromApp.monitoringMode) {
        return res.status(400).json({ code: 400, message: '关键参数缺失' });
    }

    try {
        let tasks = {};
        try {
            const fileData = await fs.readFile(TASKS_FILE_PATH, 'utf8');
            tasks = JSON.parse(fileData);
        } catch (e) { console.log('任务文件不存在或为空...'); }

        if (tasks[vin] && (tasks[vin].status === 'CHARGING' || tasks[vin].status === 'PREPARING')) {
            return res.status(409).json({ code: 409, message: '该车辆已有正在运行的监控任务' });
        }
        
        // --- 【核心修正】 ---
        // 1. 构造一个包含所有必要信息的、完整的 taskDetails 对象
        const completeTaskDetails = {
            ...taskDetailsFromApp,
            timaToken // 将 timaToken 也包含进去
        };

        const payloadBase64 = Buffer.from(JSON.stringify(completeTaskDetails)).toString('base64');
        const scriptPath = path.join(process.cwd(), 'cli', 'tasks', 'charge-monitoring-workflow.js');
        const child = execFile('node', [scriptPath, payloadBase64], (error, stdout, stderr) => {
            if (stdout) console.log(`[CLI-${vin}] ${stdout}`);
            if (stderr) console.error(`[CLI-${vin}] ${stderr}`);
            if (error) console.error(`[CLI-${vin}] 进程错误:`, error);
        });
        
        // 实时转发子进程输出到主进程控制台
        child.stdout.on('data', (data) => {
            process.stdout.write(`[CLI-${vin}] ${data}`);
        });
        child.stderr.on('data', (data) => {
            process.stderr.write(`[CLI-${vin}] ${data}`);
        });

        // 2. 将这个“完整的” taskDetails 对象写入到文件中
        tasks[vin] = {
            pid: child.pid,
            status: 'PREPARING',
            startTime: new Date().toISOString(),
            taskDetails: completeTaskDetails, // 使用包含了 timaToken 的完整对象
            latestVehicleData: null
        };
        // --- 【修正结束】 ---

        await fs.writeFile(TASKS_FILE_PATH, JSON.stringify(tasks, null, 2));
        console.log(`[API /start] - VIN: ${vin} - 任务已创建, PID: ${child.pid}`);
        return res.status(200).json({ code: 200, message: '充电监控任务已成功启动' });

    } catch (error) {
        console.error('[API /start] - 接口执行异常:', error);
        return res.status(500).json({ code: 500, message: '服务器内部错误' });
    }
}

/**
 * 获取指定车辆的监控任务状态
 */
export async function getStatus(req, res) {
    const { vin } = req.params; 
    if (!vin) {
        return res.status(400).json({ code: 400, message: '缺少车辆 VIN 参数' });
    }
    try {
        const fileData = await fs.readFile(TASKS_FILE_PATH, 'utf8');
        const tasks = JSON.parse(fileData);
        const task = tasks[vin];

        // --- 【核心修改】 ---
        if (task && (task.status === 'CHARGING' || task.status === 'PREPARING')) {
            // 如果找到了正在运行或准备中的任务，则返回完整任务信息
            console.log(`[API /status] - VIN: ${vin} - 发现正在运行的任务。`);
            return res.status(200).json({
                code: 200,
                data: {
                    isRunning: true,
                    task: task // 将任务的详细信息也返回给App
                }
            });
        } else {
            // 没有找到任务
            console.log(`[API /status] - VIN: ${vin} - 未发现正在运行的任务。`);
            return res.status(200).json({
                code: 200,
                data: {
                    isRunning: false,
                    task: null
                }
            });
        }
        // --- 【修改结束】 ---

    } catch (error) {
        // 如果文件不存在或为空，也视为无任务运行
        if (error.code === 'ENOENT' || error instanceof SyntaxError) {
             console.log(`[API /status] - VIN: ${vin} - 任务文件不存在或为空。`);
             return res.status(200).json({ code: 200, data: { isRunning: false, task: null } });
        }
        console.error('[API /status] - 接口执行异常:', error);
        return res.status(500).json({ code: 500, message: '服务器内部错误' });
    }
}

/**
 * 手动停止一个正在运行的监控任务
 */
export async function stopMonitoring(req, res) {
    const { vin } = req.body;
    if (!vin) {
        return res.status(400).json({ code: 400, message: '请求体中缺少 vin 参数' });
    }
    try {
        const fileData = await fs.readFile(TASKS_FILE_PATH, 'utf8');
        const tasks = JSON.parse(fileData);
        const task = tasks[vin];
        if (task && task.pid) {
            // 发送取消推送通知
            if (task.taskDetails && task.taskDetails.standardPushToken) {
                try {
                    const pushData = {
                        pushToken: task.taskDetails.standardPushToken,
                        title: '充电任务已取消',
                        body: '您的充电监控任务已被手动取消',
                        operationType: 'charge_task_cancelled',
                        ext: { vin, status: 'CANCELLED', reason: 'manual_cancellation' }
                    };
                    
                    const response = await fetch(`http://127.0.0.1:3333/api/push`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(pushData)
                    });
                    
                    if (response.ok) {
                        console.log(`[API /stop] - VIN: ${vin} - 取消推送已发送`);
                    } else {
                        console.error(`[API /stop] - VIN: ${vin} - 取消推送发送失败:`, response.status);
                    }
                } catch (pushError) {
                    console.error(`[API /stop] - VIN: ${vin} - 发送取消推送异常:`, pushError);
                }
            }
            
            try {
                process.kill(task.pid, 'SIGTERM'); 
                console.log(`[API /stop] - VIN: ${vin} - 终止信号已发送至 PID: ${task.pid}`);
            } catch (killError) {
                console.warn(`[API /stop] - VIN: ${vin} - 终止 PID: ${task.pid} 时出错:`, killError.message);
            }
            delete tasks[vin];
            await fs.writeFile(TASKS_FILE_PATH, JSON.stringify(tasks, null, 2));
            return res.status(200).json({ code: 200, message: '监控任务已成功停止' });
        } else {
            return res.status(404).json({ code: 404, message: '未找到该车辆的运行中任务' });
        }
    } catch (error) {
        return res.status(404).json({ code: 404, message: '未找到该车辆的运行中任务' });
    }
}

/**
 * 更新正在运行任务的实时活动Token
 */
export async function updateLiveActivityToken(req, res) {
    console.log(`[API /update-token] - 收到请求，Body:`, req.body);
    
    const { vin, newToken } = req.body;

    console.log(`[API /update-token] - 解析参数 - VIN: ${vin}, Token: ${newToken ? newToken.substring(0, 20) + '...' : 'undefined'}`);

    if (!vin || !newToken) {
        console.log(`[API /update-token] - 参数验证失败 - VIN: ${vin}, Token存在: ${!!newToken}`);
        return res.status(400).json({ code: 400, message: '缺少必需的参数' });
    }

    try {
        let tasks = {};

        try {
            const fileData = await fs.readFile(TASKS_FILE_PATH, 'utf8');
            tasks = JSON.parse(fileData);
            console.log(`[API /update-token] - 成功读取任务文件，包含VIN: ${Object.keys(tasks)}`);
        } catch (e) {
            console.log(`[API /update-token] - 读取任务文件失败:`, e.message);
            return res.status(404).json({ code: 404, message: '未找到任何运行中任务' });
        }

        const task = tasks[vin];
        console.log(`[API /update-token] - 查找VIN ${vin}的任务结果: ${task ? '找到' : '未找到'}`);

        if (task) {
            // 记录更新前的token
            const oldToken = task.taskDetails.liveActivityPushToken;
            console.log(`[API /update-token] - 更新前Token: ${oldToken || '空'}`);
            
            // 找到了任务，更新Token
            task.taskDetails.liveActivityPushToken = newToken;
            
            await fs.writeFile(TASKS_FILE_PATH, JSON.stringify(tasks, null, 2));
            
            console.log(`[API /update-token] - VIN: ${vin} - 实时活动Token已更新成功`);
            console.log(`[API /update-token] - 新Token: ${newToken.substring(0, 20)}...`);
            return res.status(200).json({ code: 200, message: 'Token更新成功' });

        } else {
            console.log(`[API /update-token] - VIN: ${vin} - 未找到该VIN的任务。可用VIN: ${Object.keys(tasks)}`);
            return res.status(404).json({ code: 404, message: '未找到该车辆的任务' });
        }

    } catch (error) {
        console.error('[API /update-token] - 接口执行异常:', error);
        return res.status(500).json({ code: 500, message: '服务器内部错误' });
    }
}