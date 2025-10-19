#!/usr/bin/env node

/**
 * Range模式充电监控CLI脚本
 * 功能：每5秒读取车辆数据，更新JSON文件，检测任务完成条件
 * 优化：监控所有任务，当任务数量为0时自动退出
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

console.log(`[Range Monitor] 启动监控服务，监控所有range任务`);

// 文件路径
const TASKS_FILE_PATH = path.join(process.cwd(), 'charge_tasks.json');
const API_BASE_URL = 'http://127.0.0.1:3333/api';

// 监控间隔（毫秒）
const MONITOR_INTERVAL = 5000; // 5秒

// 并发控制配置
const MAX_CONCURRENT_REQUESTS = 3; // 最大并发请求数

/**
 * 加载任务数据
 */
function loadTasks() {
    try {
        const fileData = fs.readFileSync(TASKS_FILE_PATH, 'utf8');
        return JSON.parse(fileData);
    } catch (error) {
        console.error('[Range Monitor] 读取任务文件失败:', error);
        return {};
    }
}

/**
 * 保存任务数据
 */
function saveTasks(tasks) {
    try {
        fs.writeFileSync(TASKS_FILE_PATH, JSON.stringify(tasks, null, 2));
        console.log(`[Range Monitor] 任务文件更新成功，VIN: ${vin}`);
    } catch (error) {
        console.error('[Range Monitor] 保存任务文件失败:', error);
        throw error;
    }
}

/**
 * 获取车辆数据
 */
async function getVehicleData(vin, timaToken) {
    try {
        const response = await fetch(`${API_BASE_URL}/car/info`, {
            method: 'POST',
            headers: { 
                'Content-Type': 'application/json', 
                'timatoken': timaToken 
            },
            body: JSON.stringify({ vin })
        });
        
        const result = await response.json();
        
        if (result.code === 200 && result.data) {
            return {
                soc: result.data.soc || 0,
                acOnMile: result.data.acOnMile || 0,
                quickChgLeftTime: result.data.quickChgLeftTime || 0
            };
        } else {
            throw new Error(`获取车辆数据失败: ${result.message}`);
        }
    } catch (error) {
        console.error(`[Range Monitor] 获取车辆数据异常，VIN: ${vin}`, error);
        throw error;
    }
}

/**
 * 发送推送通知
 */
async function sendPushNotification(pushToken, title, body) {
    try {
        const response = await fetch(`${API_BASE_URL}/push`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                token: pushToken,
                title: title,
                body: body
            })
        });
        
        const result = await response.json();
        if (result.code === 200) {
            console.log(`[Range Monitor] 推送通知发送成功，VIN: ${vin}`);
        } else {
            console.error(`[Range Monitor] 推送通知发送失败，VIN: ${vin}`, result.message);
        }
    } catch (error) {
        console.error(`[Range Monitor] 发送推送通知异常，VIN: ${vin}`, error);
    }
}

/**
 * 并发处理车辆数据获取
 * @param {Array} taskVins - VIN数组
 * @param {Object} tasks - 任务对象
 * @returns {Array} 处理结果数组
 */
async function processConcurrentVehicleData(taskVins, tasks) {
    const results = [];
    
    // 分批处理，每批最多3个请求
    for (let i = 0; i < taskVins.length; i += MAX_CONCURRENT_REQUESTS) {
        const batch = taskVins.slice(i, i + MAX_CONCURRENT_REQUESTS);
        
        console.log(`[Range Monitor] 处理第 ${Math.floor(i / MAX_CONCURRENT_REQUESTS) + 1} 批，VINs: [${batch.join(', ')}]`);
        
        const batchPromises = batch.map(async (vin) => {
            const task = tasks[vin];
            
            if (!task) {
                console.warn(`[Range Monitor] 警告：VIN ${vin} 的任务数据不存在，跳过`);
                return { vin, success: false, error: 'Task not found' };
            }
            
            try {
                // 获取最新车辆数据
                const vehicleData = await getVehicleData(vin, task.token.timaToken);
                
                console.log(`[Range Monitor] 车辆数据更新，VIN: ${vin}`, {
                    soc: vehicleData.soc,
                    acOnMile: vehicleData.acOnMile,
                    quickChgLeftTime: vehicleData.quickChgLeftTime,
                    targetMile: task.targetMile
                });
                
                return { vin, vehicleData, task, success: true };
                
            } catch (vehicleError) {
                console.error(`[Range Monitor] 获取车辆数据失败，VIN: ${vin}`, vehicleError);
                return { vin, success: false, error: vehicleError };
            }
        });
        
        const batchResults = await Promise.all(batchPromises);
        results.push(...batchResults);
        
        // 批次间短暂延迟，避免服务器压力
        if (i + MAX_CONCURRENT_REQUESTS < taskVins.length) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }
    }
    
    return results;
}

/**
 * 主监控循环
 */
async function monitorLoop() {
    try {
        // 加载任务数据
        const tasks = loadTasks();
        const taskVins = Object.keys(tasks);
        
        // 检查是否还有任务需要监控
        if (taskVins.length === 0) {
            console.log(`[Range Monitor] 🏁 所有任务已完成，没有需要监控的任务，退出CLI`);
            process.exit(0);
        }
        
        console.log(`[Range Monitor] 当前监控任务数量: ${taskVins.length}, VINs: [${taskVins.join(', ')}]`);
        
        // 并发处理所有车辆数据获取
        const results = await processConcurrentVehicleData(taskVins, tasks);
        
        // 处理获取结果
        for (const result of results) {
            if (!result.success) {
                // 跳过失败的请求
                continue;
            }
            
            const { vin, vehicleData, task } = result;
            
            // 更新任务中的最新车辆数据
            task.latestVehicleData = vehicleData;
            tasks[vin] = task;
            
            // 检查是否达到目标里程
            if (vehicleData.acOnMile >= task.targetMile) {
                console.log(`[Range Monitor] 🎉 任务完成！VIN: ${vin}, 当前里程: ${vehicleData.acOnMile}km, 目标里程: ${task.targetMile}km`);
                
                // 发送完成通知
                if (task.token.pushToken) {
                    await sendPushNotification(
                        task.token.pushToken,
                        '充电监控完成',
                        `车辆已达到目标里程 ${task.targetMile}km，当前里程 ${vehicleData.acOnMile}km`
                    );
                }
                
                // 从任务列表中删除已完成的任务
                delete tasks[vin];
                console.log(`[Range Monitor] 任务清理完成，VIN: ${vin}`);
            }
        }
        
        // 保存更新后的任务数据
        saveTasks(tasks);
        
        // 继续监控
        setTimeout(monitorLoop, MONITOR_INTERVAL);
        
    } catch (error) {
        console.error(`[Range Monitor] 监控循环异常`, error);
        
        // 等待一段时间后重试
        setTimeout(monitorLoop, MONITOR_INTERVAL * 2);
    }
}

/**
 * 优雅退出处理
 */
process.on('SIGINT', () => {
    console.log(`[Range Monitor] 收到退出信号，停止监控所有任务`);
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log(`[Range Monitor] 收到终止信号，停止监控所有任务`);
    process.exit(0);
});

// 启动监控
console.log(`[Range Monitor] 初始化完成，开始监控循环`);
monitorLoop().catch(error => {
    console.error(`[Range Monitor] 启动失败`, error);
    process.exit(1);
});