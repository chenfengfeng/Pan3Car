// /www/wwwroot/pan3/api/charge/charge.controller.js
import fs from 'fs';
import path from 'path';
import schedule from 'node-schedule';
import { execFile } from 'child_process';

const TASKS_FILE_PATH = path.join(process.cwd(), 'charge_tasks.json');
const TIME_TASKS_FILE_PATH = path.join(process.cwd(), 'time_tasks.json');

// 存储time模式的scheduled jobs，用于管理和取消
const scheduledJobs = new Map(); // key: vin, value: job对象
/**
 * 启动充电监控任务
 */
export async function startMonitoring(req, res) {
    const timaToken = req.headers.timatoken;
    const { 
        vin, 
        monitoringMode, 
        targetTimestamp, 
        targetRange, 
        autoStopCharge, 
        pushToken
    } = req.body;

    if (!vin || !timaToken || !monitoringMode) {
        return res.status(400).json({ 
            code: 400, 
            message: '关键参数缺失：vin、timaToken 或 monitoringMode' 
        });
    }

    try {
        if (monitoringMode === 'time') {
            // Time模式：使用node-schedule调度任务
            if (!targetTimestamp) {
                return res.status(400).json({ 
                    code: 400, 
                    message: 'time模式需要提供targetTimestamp参数' 
                });
            }

            const targetDate = new Date(parseInt(targetTimestamp) * 1000);
            
            // 调度任务
            const job = schedule.scheduleJob(targetDate, async () => {
                console.log(`[Time Mode] 到达目标时间，VIN: ${vin}`);
                
                // 发送推送通知
                if (pushToken) {
                    await sendPushNotification(
                        pushToken, 
                        '充电监控提醒', 
                        '已到达设定时间，请检查充电状态'
                    );
                }

                // 如果需要自动停止充电，调用停止充电API
                if (autoStopCharge) {
                    try {
                        await stopChargeAPI(vin, timaToken);
                        console.log(`[Time Mode] 自动停止充电成功，VIN: ${vin}`);
                    } catch (error) {
                        console.error(`[Time Mode] 自动停止充电失败，VIN: ${vin}`, error);
                    }
                }

                // 任务完成后从scheduledJobs中移除
                scheduledJobs.delete(vin);
                
                // 从时间任务文件中删除已完成的任务
                const timeTasks = loadTimeTasks();
                delete timeTasks[vin];
                saveTimeTasks(timeTasks);
            });

            if (job) {
                // 将job存储到Map中，用于后续管理
                scheduledJobs.set(vin, job);
                
                // 将时间任务信息保存到JSON文件
                const timeTasks = loadTimeTasks();
                timeTasks[vin] = {
                    targetTimestamp: parseInt(targetTimestamp),
                    autoStopCharge: autoStopCharge || false,
                    pushToken: pushToken || null,
                    timaToken: timaToken,
                    createdAt: Date.now()
                };
                saveTimeTasks(timeTasks);
                
                console.log(`[Time Mode] 任务调度成功，VIN: ${vin}, 目标时间: ${targetDate}`);
                return res.json({ 
                    code: 200, 
                    message: '时间模式监控任务启动成功',
                    data: { 
                        vin, 
                        mode: 'time', 
                        targetTime: targetDate.toISOString() 
                    }
                });
            } else {
                return res.status(500).json({ 
                    code: 500, 
                    message: '任务调度失败' 
                });
            }

        } else if (monitoringMode === 'range') {
            // Range模式：创建任务数据并启动CLI监控
            if (!targetRange) {
                return res.status(400).json({ 
                    code: 400, 
                    message: 'range模式需要提供targetRange参数' 
                });
            }

            // 加载现有任务
            const tasks = loadTasks();
            
            // 检查是否已存在该VIN的任务
            if (tasks[vin]) {
                return res.status(409).json({ 
                    code: 409, 
                    message: '该车辆已存在监控任务' 
                });
            }

            // 获取当前车辆数据作为初始数据
            const vehicleData = await getVehicleData(vin, timaToken);
            
            const taskData = {
                startTime: Math.floor(Date.now() / 1000), // 当前时间戳
                initialSoc: vehicleData.soc || 0,
                initialKm: vehicleData.acOnMile || 0,
                targetMile: targetRange,
                token: {
                    timaToken: timaToken,
                    pushToken: pushToken || ''
                }
            };

            // 添加新任务
            tasks[vin] = taskData;
            saveTasks(tasks);

            // 检查任务数量，只在第一个任务时启动CLI监控进程
            const taskCount = Object.keys(tasks).length;
            if (taskCount === 1) {
                // 这是第一个任务，启动CLI监控进程
                const cliPath = path.join(process.cwd(), 'cli', 'tasks', 'range-monitor.js');
                execFile('node', [cliPath], (error, stdout, stderr) => {
                    if (error) {
                        console.error(`[Range Mode] CLI启动失败`, error);
                    } else {
                        console.log(`[Range Mode] CLI启动成功，开始监控所有range任务`);
                    }
                });
            } else {
                console.log(`[Range Mode] 任务已添加到现有CLI监控中，VIN: ${vin}，当前任务总数: ${taskCount}`);
            }

            return res.json({ 
                code: 200, 
                message: '里程模式监控任务启动成功',
                data: { 
                    vin, 
                    mode: 'range', 
                    initialKm: taskData.initialKm,
                    targetMile: taskData.targetMile,
                    initialSoc: taskData.initialSoc
                }
            });

        } else {
            return res.status(400).json({ 
                code: 400, 
                message: '不支持的监控模式，仅支持 time 或 range' 
            });
        }

    } catch (error) {
        console.error('[startMonitoring] 启动监控任务异常:', error);
        return res.status(500).json({ 
            code: 500, 
            message: '启动监控任务失败: ' + error.message 
        });
    }
}

/**
 * 手动停止一个正在运行的监控任务
 */
export async function stopMonitoring(req, res) {
    const { vin, monitoringMode } = req.body;

    if (!vin || !monitoringMode) {
        return res.status(400).json({ code: 400, message: '关键参数缺失：vin 或 monitoringMode' });
    }

    try {
        if (monitoringMode === 'time') {
            // Time模式：取消对应的scheduled job
            const job = scheduledJobs.get(vin);
            
            if (!job) {
                return res.status(404).json({ 
                    code: 404, 
                    message: '未找到对应的时间监控任务' 
                });
            }

            // 取消scheduled job
            job.cancel();
            scheduledJobs.delete(vin);
            
            // 从时间任务文件中删除
            const timeTasks = loadTimeTasks();
            delete timeTasks[vin];
            saveTimeTasks(timeTasks);
            
            console.log(`[Time Mode] 已取消时间监控任务，VIN: ${vin}`);
            
            return res.json({ 
                code: 200, 
                message: '时间模式监控任务已停止',
                data: { vin, mode: 'time' }
            });

        } else if (monitoringMode === 'range') {
            // Range模式：从JSON文件中删除对应的VIN
            const tasks = loadTasks();
            
            if (!tasks[vin]) {
                return res.status(404).json({ 
                    code: 404, 
                    message: '未找到对应的续航监控任务' 
                });
            }

            // 发送停止通知
            const task = tasks[vin];
            if (task.token && task.token.pushToken) {
                await sendPushNotification(
                    task.token.pushToken, 
                    '充电任务已停止', 
                    '您的充电监控已手动停止。'
                );
            }

            // 从tasks中删除该VIN
            delete tasks[vin];
            saveTasks(tasks);

            console.log(`[Range Mode] 已删除续航监控任务，VIN: ${vin}`);

            return res.json({ 
                code: 200, 
                message: '续航模式监控任务已停止',
                data: { vin, mode: 'range' }
            });

        } else {
            return res.status(400).json({ 
                code: 400, 
                message: '不支持的监控模式，请使用 time 或 range' 
            });
        }

    } catch (error) {
        console.error(`[Stop Monitoring] 停止监控任务失败，VIN: ${vin}, Mode: ${monitoringMode}`, error);
        return res.status(500).json({ 
            code: 500, 
            message: '停止监控任务失败',
            error: error.message 
        });
    }
}

/**
 * 更新正在运行任务的实时活动Token
 */
export async function updateLiveActivityToken(req, res) {
    const { vin, activityToken } = req.body;

    if (!vin || !activityToken) {
        return res.status(400).json({ code: 400, message: '关键参数缺失：vin 或 activityToken' });
    }

    const tasks = loadTasks();
    const task = tasks[vin];

    if (!task) {
        return res.status(404).json({ code: 404, message: '未找到对应的充电任务' });
    }

    task.token.activityToken = activityToken;
    saveTasks(tasks);

    res.json({ code: 200, message: 'Live Activity Token 更新成功' });
}

// 辅助函数
/**
 * 加载任务数据
 */
function loadTasks() {
    try {
        const fileData = fs.readFileSync(TASKS_FILE_PATH, 'utf8');
        return JSON.parse(fileData);
    } catch (error) {
        console.error('[loadTasks] 读取任务文件失败:', error);
        return {};
    }
}

/**
 * 保存任务到文件
 */
function saveTasks(tasks) {
    try {
        fs.writeFileSync(TASKS_FILE_PATH, JSON.stringify(tasks, null, 2));
        console.log('[saveTasks] 任务文件保存成功');
    } catch (error) {
        console.error('[saveTasks] 保存任务文件失败:', error);
        throw error;
    }
}

/**
 * 加载时间任务数据
 */
function loadTimeTasks() {
    try {
        const fileData = fs.readFileSync(TIME_TASKS_FILE_PATH, 'utf8');
        return JSON.parse(fileData);
    } catch (error) {
        if (error.code === 'ENOENT') {
            // 文件不存在，返回空对象
            console.log('[loadTimeTasks] 时间任务文件不存在，创建新文件');
            return {};
        }
        console.error('[loadTimeTasks] 读取时间任务文件失败:', error);
        return {};
    }
}

/**
 * 保存时间任务到文件
 */
function saveTimeTasks(timeTasks) {
    try {
        fs.writeFileSync(TIME_TASKS_FILE_PATH, JSON.stringify(timeTasks, null, 2));
        console.log('[saveTimeTasks] 时间任务文件保存成功');
    } catch (error) {
        console.error('[saveTimeTasks] 保存时间任务文件失败:', error);
        throw error;
    }
}

/**
 * 恢复时间任务（服务启动时调用）
 */
function restoreTimeTasks() {
    try {
        const timeTasks = loadTimeTasks();
        const now = Date.now();
        let restoredCount = 0;
        let expiredCount = 0;
        
        for (const [vin, taskData] of Object.entries(timeTasks)) {
            const { targetTimestamp, autoStopCharge, pushToken, timaToken } = taskData;
            
            // 检查任务是否已过期
            if (targetTimestamp <= now) {
                console.log(`[restoreTimeTasks] 任务已过期，删除VIN: ${vin}`);
                delete timeTasks[vin];
                expiredCount++;
                continue;
            }
            
            // 重新创建scheduled job
            const targetDate = new Date(targetTimestamp);
            const job = schedule.scheduleJob(targetDate, async () => {
                console.log(`[Time Mode] 定时任务触发，VIN: ${vin}`);
                
                try {
                    // 获取车辆数据
                    const vehicleData = await getVehicleData(vin, timaToken);
                    
                    if (vehicleData && vehicleData.data) {
                        const { batteryLevel, chargingStatus } = vehicleData.data;
                        
                        // 发送通知
                        if (pushToken) {
                            await sendPushNotification(pushToken, {
                                title: '充电监控提醒',
                                body: `车辆 ${vin} 当前电量: ${batteryLevel}%, 充电状态: ${chargingStatus === 1 ? '充电中' : '未充电'}`
                            });
                        }
                        
                        // 如果需要自动停止充电
                        if (autoStopCharge && chargingStatus === 1) {
                            // 这里可以添加停止充电的逻辑
                            console.log(`[Time Mode] 自动停止充电功能触发，VIN: ${vin}`);
                        }
                    }
                } catch (error) {
                    console.error(`[Time Mode] 执行定时任务失败，VIN: ${vin}`, error);
                }
                
                // 任务完成后从scheduledJobs中移除
                scheduledJobs.delete(vin);
                
                // 从时间任务文件中删除已完成的任务
                const currentTimeTasks = loadTimeTasks();
                delete currentTimeTasks[vin];
                saveTimeTasks(currentTimeTasks);
            });
            
            if (job) {
                scheduledJobs.set(vin, job);
                restoredCount++;
                console.log(`[restoreTimeTasks] 恢复任务成功，VIN: ${vin}, 目标时间: ${targetDate}`);
            }
        }
        
        // 保存清理后的任务文件（移除过期任务）
        if (expiredCount > 0) {
            saveTimeTasks(timeTasks);
        }
        
        console.log(`[restoreTimeTasks] 任务恢复完成，恢复: ${restoredCount}个，过期清理: ${expiredCount}个`);
        
    } catch (error) {
        console.error('[restoreTimeTasks] 恢复时间任务失败:', error);
    }
}

async function getVehicleData(vin, timaToken) {
    try {
        const response = await fetch(`http://127.0.0.1:3333/api/car/info`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'timatoken': timaToken },
            body: JSON.stringify({ vin })
        });
        const result = await response.json();
        
        if (result.code === 200 && result.data) {
            return result.data;
        } else {
            throw new Error(`获取车辆数据失败: ${result.message}`);
        }
    } catch (error) {
        console.error('[getVehicleData] 获取车辆数据异常:', error);
        throw error;
    }
}

/**
 * 发送推送通知
 */
async function sendPushNotification(pushToken, title, body) {
    try {
        console.log(`[sendPushNotification] 准备发送推送通知，token: ${pushToken?.substring(0, 10)}...`);
        
        const response = await fetch(`http://127.0.0.1:3333/api/push`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                token: pushToken,
                title: title,
                body: body
            })
        });
        
        console.log(`[sendPushNotification] 响应状态: ${response.status}, Content-Type: ${response.headers.get('content-type')}`);
        
        // 检查响应是否为JSON格式
        const contentType = response.headers.get('content-type');
        if (!contentType || !contentType.includes('application/json')) {
            const textResponse = await response.text();
            console.error('[sendPushNotification] 服务器返回非JSON响应:', textResponse.substring(0, 200));
            throw new Error(`服务器返回非JSON响应，状态码: ${response.status}`);
        }
        
        const result = await response.json();
        if (result.code === 200) {
            console.log('[sendPushNotification] 推送通知发送成功');
        } else {
            console.error('[sendPushNotification] 推送通知发送失败:', result.message);
        }
    } catch (error) {
        console.error('[sendPushNotification] 发送推送通知异常:', error);
    }
}

/**
 * 停止充电API调用
 */
async function stopChargeAPI(vin, timaToken) {
    try {
        console.log(`[stopChargeAPI] 开始调用停止充电API，VIN: ${vin}`);
        
        // 调用内部停止充电API
        const response = await fetch(`http://127.0.0.1:3333/api/car/stop-charging`, {
            method: 'POST',
            headers: { 
                'Content-Type': 'application/json', 
                'timatoken': timaToken 
            },
            body: JSON.stringify({
                vin: vin
            })
        });

        if (!response.ok) {
            throw new Error(`HTTP错误! 状态: ${response.status}`);
        }

        const result = await response.json();
        
        if (result.code === 200) {
            console.log(`[stopChargeAPI] 停止充电成功，VIN: ${vin}`);
            return { success: true, message: '停止充电成功', data: result.data };
        } else {
            console.error(`[stopChargeAPI] 停止充电失败，VIN: ${vin}，错误:`, result.message);
            return { success: false, message: result.message || '停止充电失败' };
        }
        
    } catch (error) {
        console.error('[stopChargeAPI] 停止充电API调用异常:', error);
        return { success: false, message: `停止充电API调用异常: ${error.message}` };
    }
}

export {
    restoreTimeTasks  // 导出恢复函数，供服务启动时调用
};