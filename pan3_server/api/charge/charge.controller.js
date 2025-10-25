// /www/wwwroot/pan3/api/charge/charge.controller.js
import fs from 'fs';
import path from 'path';
import schedule from 'node-schedule';
import { VehicleDataCircuitBreaker } from '../../core/utils/circuit-breaker.js';
import { 
    getVehicleDataInternal, 
    sendPushNotificationInternal, 
    sendLiveActivityPushInternal,
    stopChargingInternal 
} from '../../core/services/internal.service.js';


// 新架构：基于文件夹的VIN独立存储
const TASKS_DIR = path.join(process.cwd(), 'tasks');
const RANGE_TASKS_DIR = path.join(TASKS_DIR, 'range');
const TIME_TASKS_DIR = path.join(TASKS_DIR, 'time');

// 存储time模式的scheduled jobs，用于管理和取消
const scheduledJobs = new Map(); // key: vin, value: job对象

// 存储range模式的轮询定时器，全局只有一个
let rangeMonitoringInterval = null;
let isRangeMonitoringActive = false;
let isMonitoringExecuting = false; // 标记是否有监控任务正在执行
let shouldStopMonitoring = false; // 标记是否应该停止监控

// 车辆数据获取熔断器实例
const vehicleDataCircuitBreaker = new VehicleDataCircuitBreaker();

/**
 * 开始监听API
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
                // 从文件中读取任务数据以获取最新的token信息
                const taskData = loadVinTimeTasks(vin);
                
                // 发送推送通知
                if (taskData && taskData.token && taskData.token.pushToken) {
                    await sendPushNotification(
                        taskData.token.pushToken, 
                        '充电监控提醒', 
                        '已到达设定时间，请检查充电状态',
                        'time_task_ended'
                    );
                }

                // 如果需要自动停止充电，调用停止充电API
                if (taskData && taskData.autoStopCharge && taskData.token && taskData.token.timaToken) {
                    try {
                        await stopChargeAPI(vin, taskData.token.timaToken);
                    } catch (error) {
                        console.error(`[Time Mode] 自动停止充电失败，VIN: ${vin}`, error);
                    }
                }

                // 任务完成后从scheduledJobs中移除
                scheduledJobs.delete(vin);
                
                // 删除已完成的时间任务文件
                deleteVinTimeTasks(vin);
            });

            if (job) {
                // 将job存储到Map中，用于后续管理
                scheduledJobs.set(vin, job);
                
                // 将时间任务信息保存到VIN独立文件
                const timeTaskData = {
                    targetTimestamp: parseInt(targetTimestamp),
                    autoStopCharge: autoStopCharge || false,
                    token: {
                        timaToken: timaToken,
                        pushToken: pushToken || ''
                    },
                    createdAt: Date.now()
                };
                saveVinTimeTasks(vin, timeTaskData);
                
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
            // Range模式：创建任务数据并使用node-schedule管理监控
            if (!targetRange) {
                return res.status(400).json({ 
                    code: 400, 
                    message: 'range模式需要提供targetRange参数' 
                });
            }

            // 检查是否已存在该VIN的任务
            const existingTask = loadVinRangeTasks(vin);
            if (existingTask) {
                return res.status(409).json({ 
                    code: 409, 
                    message: '该车辆已存在监控任务' 
                });
            }

            // 获取当前车辆数据作为初始数据
            const vehicleData = await getVehicleData(vin, timaToken);
            
            // 创建任务数据
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

            // 保存新任务到VIN独立文件
            saveVinRangeTasks(vin, taskData);

            // 检查是否需要启动轮询监控
            const allRangeVins = getAllRangeVins();
            if (allRangeVins.length === 1) {
                // 这是第一个任务，启动node-schedule轮询监控
                startRangeMonitoring();
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
            
            // 在删除任务文件前，先获取任务数据以发送推送通知
            const taskData = loadVinTimeTasks(vin);
            if (taskData && taskData.token && taskData.token.pushToken) {
                await sendPushNotification(
                    taskData.token.pushToken, 
                    '时间监控任务已停止', 
                    '您的时间监控任务已手动停止。',
                    'time_task_ended'
                );
            }
            
            // 删除时间任务文件
            deleteVinTimeTasks(vin);
            
            return res.json({ 
                code: 200, 
                message: '时间模式监控任务已停止',
                data: { vin, mode: 'time' }
            });

        } else if (monitoringMode === 'range') {
            // Range模式：删除对应VIN的任务文件
            const task = loadVinRangeTasks(vin);
            
            if (!task) {
                return res.status(404).json({ 
                    code: 404, 
                    message: '未找到对应的续航监控任务' 
                });
            }

            // 发送停止通知
            if (task.token && task.token.pushToken) {
                await sendPushNotification(
                    task.token.pushToken, 
                    '充电任务已停止', 
                    '您的充电监控已手动停止。',
                    'range_task_ended'
                );
            }

            // 删除该VIN的任务文件
            deleteVinRangeTasks(vin);

            console.log(`[Range Mode] 已删除续航监控任务，VIN: ${vin}`);

            // 检查剩余任务数量，如果为0则停止轮询监控
            const remainingVins = getAllRangeVins();
            if (remainingVins.length === 0) {
                console.log(`[Range Mode] 所有任务已完成，停止轮询监控`);
                // 异步停止监控，不阻塞HTTP响应
                setImmediate(() => stopRangeMonitoring());
            } else {
                console.log(`[Range Mode] 剩余任务数量: ${remainingVins.length}，继续轮询监控`);
            }

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
    const { vin, activityToken, monitoringMode } = req.body;

    if (!vin || !activityToken) {
        return res.status(400).json({ code: 400, message: '关键参数缺失：vin 或 activityToken' });
    }

    // 根据监控模式查找对应的任务
    let task = null;
    
    // 如果指定了监控模式，优先使用指定的模式
    if (monitoringMode === 'range') {
        task = loadVinRangeTasks(vin);
    } else if (monitoringMode === 'time') {
        task = loadVinTimeTasks(vin);
    } else {
        // 如果没有指定模式，尝试从两种模式中查找
        task = loadVinRangeTasks(vin) || loadVinTimeTasks(vin);
    }

    if (!task) {
        return res.status(404).json({ code: 404, message: '未找到对应的充电任务' });
    }

    // 更新 activityToken
    task.token.activityToken = activityToken;

    // 根据任务类型保存到对应的文件
    try {
        if (task.targetMile !== undefined) {
            // Range 模式任务
            saveVinRangeTasks(vin, task);
        } else if (task.targetTimestamp !== undefined) {
            // Time 模式任务
            saveVinTimeTasks(vin, task);
        } else {
            return res.status(400).json({ code: 400, message: '无法确定任务类型' });
        }

        res.json({ code: 200, message: 'Live Activity Token 更新成功' });
    } catch (error) {
        console.error(`[updateLiveActivityToken] 更新失败，VIN: ${vin}`, error);
        res.status(500).json({ code: 500, message: '更新 Live Activity Token 失败' });
    }
}

/**
 * 获取车辆数据 - 直接调用内部服务
 * @param {string} vin - 车辆VIN号
 * @param {string} timaToken - 认证token
 * @returns {Promise<object>} - 车辆数据对象
 */
async function getVehicleData(vin, timaToken) {
    return await vehicleDataCircuitBreaker.executeVehicleDataFetch(async () => {
        return await getVehicleDataInternal(vin, timaToken);
    });
}

/**
 * 发送推送通知
 */
/**
 * 发送推送通知 - 直接调用内部服务
 */
async function sendPushNotification(pushToken, title, body, operationType = null) {
    try {
        await sendPushNotificationInternal(pushToken, title, body, operationType);
        console.log('[sendPushNotification] 推送通知发送成功');
    } catch (error) {
        console.error('[sendPushNotification] 发送推送通知异常:', error.message);
    }
}

/**
 * 停止充电API调用 - 直接调用内部服务
 */
async function stopChargeAPI(vin, timaToken) {
    try {
        const result = await stopChargingInternal(vin, timaToken);
        return { success: true, message: '停止充电成功', data: result };
    } catch (error) {
        console.error('[stopChargeAPI] 停止充电API调用异常:', error.message);
        return { success: false, message: `停止充电API调用异常: ${error.message}` };
    }
}

/**
 * Range模式监控轮询函数
 * 使用setInterval替代node-schedule进行高频监控，每5秒轮询一次
 */
async function startRangeMonitoring() {
    // 防止重复启动
    if (isRangeMonitoringActive) {
        console.log('[Range Monitor] 监控已在运行中，跳过重复启动');
        return;
    }

    console.log('[Range Monitor] 开始range模式轮询监控');
    isRangeMonitoringActive = true;
    shouldStopMonitoring = false;
    
    // 使用setInterval替代node-schedule进行高频轮询
    rangeMonitoringInterval = setInterval(async () => {
        // 检查是否应该停止监控
        if (shouldStopMonitoring) {
            console.log('[Range Monitor] 检测到停止信号，终止监控');
            stopRangeMonitoring();
            return;
        }
        
        // 防止重复执行
        if (isMonitoringExecuting) {
            console.log('[Range Monitor] 上一轮监控仍在执行中，跳过本轮');
            return;
        }
        
        isMonitoringExecuting = true;
        
        try {
            // 获取所有需要监控的VIN列表
            const taskVins = getAllRangeVins();
            
            // 检查是否还有任务需要监控
            if (taskVins.length === 0) {
                console.log('[Range Monitor] 没有任务需要监控，停止轮询');
                stopRangeMonitoring();
                return;
            }
            
            // 并发处理每个车辆的数据获取
            const monitoringPromises = taskVins.map(async (vin) => {
                try {
                    // 再次检查停止信号
                    if (shouldStopMonitoring) {
                        console.log(`[Range Monitor] 检测到停止信号，跳过VIN: ${vin}`);
                        return;
                    }
                    
                    // 加载该VIN的任务数据
                    const task = loadVinRangeTasks(vin);
                    
                    if (!task) {
                        console.warn(`[Range Monitor] 警告：VIN ${vin} 的任务数据不存在，跳过`);
                        return;
                    }
                    
                    // 获取最新车辆数据
                    const vehicleData = await getVehicleData(vin, task.token.timaToken);
                    
                    // 更新任务中的最新车辆数据
                    task.latestVehicleData = vehicleData;
                    
                    // 推送实时活动数据更新
                    await updateLiveActivity(vin, task, vehicleData);
                    
                    // 检查任务完成条件：达到目标里程 或 充电状态为停止(chgStatus=2)
                    const reachedTargetMile = vehicleData.acOnMile >= task.targetMile;
                    const chargingStopped = vehicleData.chgStatus === 2;
                    
                    if (reachedTargetMile || chargingStopped) {
                        let completionReason = '';
                        let notificationMessage = '';
                        
                        if (reachedTargetMile) {
                            completionReason = `达到目标里程 ${task.targetMile}km，当前里程 ${vehicleData.acOnMile}km`;
                            notificationMessage = `车辆已达到目标里程 ${task.targetMile}km，当前里程 ${vehicleData.acOnMile}km`;
                        } else if (chargingStopped) {
                            completionReason = `充电已停止(chgStatus=${vehicleData.chgStatus})，当前里程 ${vehicleData.acOnMile}km`;
                            notificationMessage = `充电已停止，当前里程 ${vehicleData.acOnMile}km`;
                        }
                        
                        console.log(`[Range Monitor] 任务完成！VIN: ${vin}, 原因: ${completionReason}`);
                        
                        // 发送完成通知
                        if (task.token.pushToken) {
                            await sendPushNotification(
                                task.token.pushToken,
                                '充电监控完成',
                                notificationMessage,
                                'range_task_ended'
                            );
                        }
                        
                        // 删除已完成的任务文件
                        deleteVinRangeTasks(vin);
                        console.log(`[Range Monitor] 任务清理完成，VIN: ${vin}`);
                    } else {
                        // 只有在没有停止信号时才保存任务数据
                        if (!shouldStopMonitoring) {
                            saveVinRangeTasks(vin, task);
                        }
                    }
                    
                } catch (vehicleError) {
                    console.error(`[Range Monitor] 获取车辆数据失败，VIN: ${vin}`, vehicleError);
                }
            });
            
            // 等待所有车辆的监控任务完成
            await Promise.all(monitoringPromises);
            console.log('[Range Monitor] 本轮监控完成');
            
        } catch (error) {
            console.error('[Range Monitor] 监控轮询异常:', error);
        } finally {
            isMonitoringExecuting = false;
        }
    }, 5000); // 每5秒执行一次
}

/**
 * 停止Range模式监控轮询
 */
function stopRangeMonitoring() {
    console.log('[Range Monitor] 开始停止监控流程');
    
    // 设置停止标志
    shouldStopMonitoring = true;
    
    if (rangeMonitoringInterval) {
        clearInterval(rangeMonitoringInterval);
        rangeMonitoringInterval = null;
        console.log('[Range Monitor] 已清除定时器');
    }
    
    // 异步等待当前执行完成，不阻塞主线程
    const waitForCompletion = async () => {
        while (isMonitoringExecuting) {
            console.log('[Range Monitor] 等待当前监控任务完成...');
            await new Promise(resolve => setTimeout(resolve, 100));
        }
        isRangeMonitoringActive = false;
        shouldStopMonitoring = false;
        console.log('[Range Monitor] 已停止range模式轮询监控');
    };
    
    // 异步执行等待过程，不阻塞HTTP响应
    waitForCompletion().catch(error => {
        console.error('[Range Monitor] 停止监控过程中发生错误:', error);
        // 确保状态被重置
        isRangeMonitoringActive = false;
        shouldStopMonitoring = false;
    });
}

/**
 * 更新实时活动数据
 */
async function updateLiveActivity(vin, task, vehicleData) {
    try {
        if (!task.token.activityToken) {
            return; // 没有活动token，跳过更新
        }

        // 按推送服务约定构造 contentState
        const targetMile = Number(task.targetMile) || 0;
        const initialKm = Number(task.initialKm) || 0;
        const currentKm = Number(vehicleData?.acOnMile) || 0;
        const currentSoc = Number(vehicleData?.soc) || 0;
        
        // 正确的充电进度计算：(当前里程 - 初始里程) / (目标里程 - 初始里程) * 100
        const totalRange = targetMile - initialKm;
        const currentProgress = currentKm - initialKm;
        const chargeProgress = totalRange > 0 ? Math.min(Math.round((currentProgress / totalRange) * 100), 100) : 0;

        // 格式化当前时间为 HH:mm:ss
        const now = new Date();
        const timeString = now.toLocaleTimeString('zh-CN', { 
            hour: '2-digit', 
            minute: '2-digit',
            second: '2-digit',
            hour12: false 
        });

        const liveActivityData = {
            liveActivityPushToken: task.token.activityToken,
            contentState: {
                currentKm,
                currentSoc,
                chargeProgress,
                message: `更新于${timeString}`
            }
        };

        // 异步执行推送，不阻塞主流程
        setImmediate(async () => {
            try {
                await sendLiveActivityPushInternal(liveActivityData);
                console.log(`[Range Monitor] Live Activity更新成功，VIN: ${vin}`);
            } catch (pushError) {
                console.error(`[Range Monitor] Live Activity推送失败，VIN: ${vin}`, pushError.message);
                // 推送失败不影响监控流程
            }
        });
    } catch (error) {
        console.error(`[Range Monitor] Live Activity更新异常，VIN: ${vin}`, error);
    }
}

/**
 * 加载指定VIN的range任务数据
 * @param {string} vin - 车辆VIN码
 * @returns {Object} VIN任务数据
 */
function loadVinRangeTasks(vin) {
    try {
        const filePath = path.join(RANGE_TASKS_DIR, `${vin}.json`);
        const fileData = fs.readFileSync(filePath, 'utf8');
        return JSON.parse(fileData);
    } catch (error) {
        if (error.code === 'ENOENT') {
            // 文件不存在，返回null表示没有任务
            return null;
        }
        console.error(`[loadVinRangeTasks] 读取VIN ${vin} 任务文件失败:`, error);
        return null;
    }
}

/**
 * 保存指定VIN的range任务数据
 * @param {string} vin - 车辆VIN码
 * @param {Object} vinData - VIN任务数据
 */
function saveVinRangeTasks(vin, vinData) {
    // 在函数开始就定义 filePath，确保在整个函数作用域内可用
    const filePath = path.join(RANGE_TASKS_DIR, `${vin}.json`);
    
    try {
        // 确保目录存在
        if (!fs.existsSync(RANGE_TASKS_DIR)) {
            fs.mkdirSync(RANGE_TASKS_DIR, { recursive: true });
        }
        
        vinData.lastUpdated = new Date().toISOString();
        
        // 使用同步方式写入文件
        fs.writeFileSync(filePath, JSON.stringify(vinData, null, 2));
        console.log(`[saveVinRangeTasks] VIN ${vin} 任务文件保存成功`);
        
    } catch (error) {
        console.error(`[saveVinRangeTasks] 保存VIN ${vin} 任务文件失败:`, error);
    }
}

/**
 * 加载指定VIN的time任务数据
 * @param {string} vin - 车辆VIN码
 * @returns {Object} VIN任务数据
 */
function loadVinTimeTasks(vin) {
    try {
        const filePath = path.join(TIME_TASKS_DIR, `${vin}.json`);
        const fileData = fs.readFileSync(filePath, 'utf8');
        return JSON.parse(fileData);
    } catch (error) {
        if (error.code === 'ENOENT') {
            // 文件不存在，返回null表示没有任务
            return null;
        }
        console.error(`[loadVinTimeTasks] 读取VIN ${vin} 时间任务文件失败:`, error);
        return null;
    }
}

/**
 * 保存指定VIN的time任务数据
 * @param {string} vin - 车辆VIN码
 * @param {Object} vinData - VIN任务数据
 */
function saveVinTimeTasks(vin, vinData) {
    // 在函数开始就定义 filePath，确保在整个函数作用域内可用
    const filePath = path.join(TIME_TASKS_DIR, `${vin}.json`);
    
    try {
        // 确保目录存在
        if (!fs.existsSync(TIME_TASKS_DIR)) {
            fs.mkdirSync(TIME_TASKS_DIR, { recursive: true });
        }
        
        vinData.lastUpdated = new Date().toISOString();
        
        // 使用同步方式写入文件
        fs.writeFileSync(filePath, JSON.stringify(vinData, null, 2));
        console.log(`[saveVinTimeTasks] VIN ${vin} 时间任务文件保存成功`);
        
    } catch (error) {
        console.error(`[saveVinTimeTasks] 保存VIN ${vin} 时间任务文件失败:`, error);
    }
}

/**
 * 获取所有range任务的VIN列表
 * @returns {Array} VIN列表
 */
function getAllRangeVins() {
    try {
        if (!fs.existsSync(RANGE_TASKS_DIR)) {
            return [];
        }
        
        const files = fs.readdirSync(RANGE_TASKS_DIR);
        return files
            .filter(file => file.endsWith('.json'))
            .map(file => file.replace('.json', ''));
    } catch (error) {
        console.error('[getAllRangeVins] 获取range VIN列表失败:', error);
        return [];
    }
}

/**
 * 获取所有time任务的VIN列表
 * @returns {Array} VIN列表
 */
function getAllTimeVins() {
    try {
        if (!fs.existsSync(TIME_TASKS_DIR)) {
            return [];
        }
        
        const files = fs.readdirSync(TIME_TASKS_DIR);
        return files
            .filter(file => file.endsWith('.json'))
            .map(file => file.replace('.json', ''));
    } catch (error) {
        console.error('[getAllTimeVins] 获取time VIN列表失败:', error);
        return [];
    }
}

/**
 * 删除指定VIN的range任务文件
 * @param {string} vin - 车辆VIN码
 */
function deleteVinRangeTasks(vin) {
    try {
        const filePath = path.join(RANGE_TASKS_DIR, `${vin}.json`);
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
            console.log(`[deleteVinRangeTasks] VIN ${vin} 任务文件删除成功`);
        }
    } catch (error) {
        console.error(`[deleteVinRangeTasks] 删除VIN ${vin} 任务文件失败:`, error);
    }
}

/**
 * 删除指定VIN的time任务文件
 * @param {string} vin - 车辆VIN码
 */
function deleteVinTimeTasks(vin) {
    try {
        const filePath = path.join(TIME_TASKS_DIR, `${vin}.json`);
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
            console.log(`[deleteVinTimeTasks] VIN ${vin} 时间任务文件删除成功`);
        }
    } catch (error) {
        console.error(`[deleteVinTimeTasks] 删除VIN ${vin} 时间任务文件失败:`, error);
    }
}

/**
 * 恢复时间任务（服务启动时调用）
 */
function restoreTimeTasks() {
    try {
        const timeVins = getAllTimeVins();
        const now = Date.now();
        let restoredCount = 0;
        let expiredCount = 0;
        
        console.log(`[restoreTimeTasks] 发现 ${timeVins.length} 个VIN的时间任务文件`);
        
        for (const vin of timeVins) {
            const taskData = loadVinTimeTasks(vin);
            
            if (!taskData) {
                console.log(`[restoreTimeTasks] VIN ${vin} 的任务数据为空，跳过`);
                continue;
            }
            
            const { targetTimestamp, autoStopCharge, token } = taskData;
            
            // 检查任务是否已过期
            if (targetTimestamp <= now) {
                console.log(`[restoreTimeTasks] 任务已过期，删除VIN: ${vin}`);
                deleteVinTimeTasks(vin);
                expiredCount++;
                continue;
            }
            
            // 重新创建scheduled job
            const targetDate = new Date(targetTimestamp);
            const job = schedule.scheduleJob(targetDate, async () => {
                // 发送推送通知
                if (token.pushToken) {
                    await sendPushNotification(
                        token.pushToken, 
                        '充电监控提醒', 
                        '已到达设定时间，请检查充电状态'
                    );
                }

                // 如果需要自动停止充电，调用停止充电API
                if (autoStopCharge && token.timaToken) {
                    try {
                        await stopChargeAPI(vin, token.timaToken);
                    } catch (error) {
                        console.error(`[Time Mode] 自动停止充电失败，VIN: ${vin}`, error);
                    }
                }

                // 任务完成后从scheduledJobs中移除
                scheduledJobs.delete(vin);
                
                // 删除已完成的任务文件
                deleteVinTimeTasks(vin);
            });
            
            if (job) {
                scheduledJobs.set(vin, job);
                restoredCount++;
                console.log(`[restoreTimeTasks] 恢复时间任务成功，VIN: ${vin}, 目标时间: ${targetDate.toISOString()}`);
            } else {
                console.error(`[restoreTimeTasks] 恢复时间任务失败，VIN: ${vin}`);
            }
        }
    } catch (error) {
        console.error('[restoreTimeTasks] 恢复时间任务失败:', error);
    }
}

/**
 * 恢复range监控任务（服务启动时调用）
 */
export function restoreRangeTasks() {
    try {
        const rangeVins = getAllRangeVins();
        
        if (rangeVins.length > 0) {
            console.log(`[restoreRangeTasks] 发现 ${rangeVins.length} 个VIN的range监控任务，启动轮询监控`);
            startRangeMonitoring();
        } else {
            console.log(`[restoreRangeTasks] 没有发现range监控任务`);
        }
        
    } catch (error) {
        console.error('[restoreRangeTasks] 恢复range监控任务失败:', error);
    }
}

export {
    restoreTimeTasks  // 导出恢复函数，供服务启动时调用
};