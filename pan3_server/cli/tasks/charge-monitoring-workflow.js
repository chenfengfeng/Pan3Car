// /www/wwwroot/pan3/cli/tasks/charge-monitoring-workflow.js

import fs from 'fs/promises';
import path from 'path';

const API_BASE_URL = 'http://127.0.0.1:3333'; // 您Node.js服务的内部地址
const TASKS_FILE_PATH = path.join(process.cwd(), 'charge_tasks.json');

// ======================= 辅助函数区 =======================

/**
 * 调用内部API获取最新车辆信息
 */
async function getVehicleData(vin, timaToken) {
    try {
        const response = await fetch(`${API_BASE_URL}/api/car/info`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'timatoken': timaToken },
            body: JSON.stringify({ vin })
        });
        const result = await response.json();
        if (result.code === 200 && result.data) {
            return result.data;
        }
        console.error(`[CLI] 获取车辆信息失败: Code: ${result.code}, Message: ${result.message}`);
        return null;
    } catch (error) {
        console.error('[CLI] 调用 /api/car/info 接口时异常:', error);
        return null;
    }
}

/**
 * 调用内部API发送标准推送
 */
async function sendStandardPush(pushToken, title, body, operationType = 'charge_notification', ext = {}) {
    if (!pushToken) {
        console.log('[CLI] 推送令牌为空，跳过推送');
        return;
    }
    
    try {
        const pushData = {
            pushToken,
            title,
            body,
            operationType,
            ext // 添加额外信息
        };
        
        console.log('[CLI] 发送推送:', pushData);
        
        const response = await fetch(`${API_BASE_URL}/api/push`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(pushData)
        });
        
        if (response.ok) {
            console.log('[CLI] 推送发送成功');
        } else {
            console.error('[CLI] 推送发送失败:', response.status);
        }
    } catch (error) {
        console.error('[CLI] 推送发送异常:', error);
    }
}

/**
 * 调用内部API发送实时活动更新
 */
async function sendLiveActivityUpdate(liveActivityPushToken, contentState) {
    try {
        await fetch(`${API_BASE_URL}/api/push/live-activity`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ liveActivityPushToken, contentState })
        });
        console.log(`[CLI] 实时活动更新已发送, 状态: ${contentState.status}`);
    } catch (error) {
        console.error('[CLI] 调用 /api/push/live-activity 接口时异常:', error);
    }
}

/**
 * 更新任务文件中的状态
 */
async function updateTaskStatus(vin, newStatus) {
    try {
        const fileData = await fs.readFile(TASKS_FILE_PATH, 'utf8');
        const tasks = JSON.parse(fileData);
        if (tasks[vin]) {
            tasks[vin].status = newStatus;
            await fs.writeFile(TASKS_FILE_PATH, JSON.stringify(tasks, null, 2));
            console.log(`[CLI] VIN: ${vin} 状态已更新为: ${newStatus}`);
        }
    } catch (error) {
        console.error(`[CLI] 更新任务状态失败, VIN: ${vin}`, error);
    }
}


/**
 * 清理任务文件中的记录
 */
async function cleanupTaskFile(vin) {
    try {
        const fileData = await fs.readFile(TASKS_FILE_PATH, 'utf8');
        const tasks = JSON.parse(fileData);
        if (tasks[vin]) {
            delete tasks[vin];
            await fs.writeFile(TASKS_FILE_PATH, JSON.stringify(tasks, null, 2));
            console.log(`[CLI] 清理任务文件成功, VIN: ${vin}`);
        }
    } catch (error) {
        console.error(`[CLI] 清理任务文件失败, VIN: ${vin}`, error);
    }
}

/**
 * 调用江淮API停止充电的函数
 * @param {string} vin 
 * @param {string} timaToken 
 * @returns {Promise<boolean>} 指令是否成功发送
 */
async function stopVehicleCharge(vin, timaToken) {
    console.log(`[CLI] 正在为 VIN: ${vin} 发送停止充电指令...`);
    try {
        const controlUrl = `${JAC_API_BASE_URL}/api/jac-energy/jacenergy/vehicleControl/energy-remote-vehicle-control`;
        
        // ** 核心逻辑参考自您的 stop_charge.php 文件 **
        const payload = {
            vin: vin,
            operationType: "RESERVATION_RECHARGE",
            operation: 1,
            extParams: {
                bookTime: 0
            }
        };
        const headers = { 
            'Content-Type': 'application/json', 
            'timaToken': timaToken 
        };
        
        const response = await fetch(controlUrl, { method: 'POST', headers: headers, body: JSON.stringify(payload) });
        const result = await response.json();

        if (result && result.returnSuccess) {
            console.log(`[CLI] 停止充电指令已成功发送。`);
            return true;
        } else {
            console.error(`[CLI] 停止充电指令发送失败:`, result);
            return false;
        }
    } catch (error) {
        console.error('[CLI] 调用停止充电接口时异常:', error);
        return false;
    }
}


/**
 * 更新任务文件中的最新车辆数据
 */
async function updateTaskVehicleData(vin, vehicleData) {
    try {
        const fileData = await fs.readFile(TASKS_FILE_PATH, 'utf8');
        const tasks = JSON.parse(fileData);
        if (tasks[vin]) {
            tasks[vin].latestVehicleData = vehicleData; // 更新最新车辆数据
            await fs.writeFile(TASKS_FILE_PATH, JSON.stringify(tasks, null, 2));
        }
    } catch (error) {
        console.error(`[CLI] 更新车辆数据失败, VIN: ${vin}`, error);
    }
}

// ======================= 主逻辑函数 =======================

/**
 * 后台轮询任务主逻辑 (状态机版本)
 */
async function runBackgroundTask(taskDetails) {
    const { vin, timaToken, standardPushToken, monitoringMode, targetTimestamp, targetRange, autoStopCharge } = taskDetails;
    let liveActivityPushToken = taskDetails.liveActivityPushToken;

    console.log(`[CLI Task Started] - VIN: ${vin}, Mode: ${monitoringMode}, AutoStop: ${!!autoStopCharge}`);
    
    // 准备阶段
    console.log('[CLI] 进入准备阶段，等待车辆开始充电...');
    const PREPARE_TIMEOUT_SECONDS = 60; // 修改为1分钟用于测试
    const RETRY_DELAY = 5000;
    let isChargingStarted = false;

    for (let i = 0; i < (PREPARE_TIMEOUT_SECONDS / (RETRY_DELAY / 1000)); i++) {
        const vehicleData = await getVehicleData(vin, timaToken);
        if (vehicleData) {
            await updateTaskVehicleData(vin, vehicleData);
        }
        if (vehicleData && vehicleData.chgStatus != 2) {
            console.log('[CLI] 检测到车辆已开始充电，进入监控阶段。');
            await updateTaskStatus(vin, 'CHARGING');
            isChargingStarted = true;
            break;
        }
        await sendLiveActivityUpdate(liveActivityPushToken, { status: "准备中", chargedKwh: 0, percentage: vehicleData?.soc || 0, lastUpdateTime: new Date().toISOString() });
        await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
    }

    if (!isChargingStarted) {
        console.log('[CLI] 准备阶段超时（1分钟），车辆未在规定时间内开始充电。');
        await sendStandardPush(standardPushToken, '任务失败', '车辆未在1分钟内开始充电', 'charge_task_failed', { vin, status: 'FAILED', reason: 'prepare_timeout' });
        await updateTaskStatus(vin, 'FAILED');
        return;
    }
    
    // 监控阶段
    let initialVehicleData = await getVehicleData(vin, timaToken);
    let counter = 1;

    while (true) {
        console.log(`[CLI] 正在进行第 ${counter} 次监控检查...`);
        
        try {
            const tasksData = await fs.readFile(TASKS_FILE_PATH, 'utf8');
            const tasks = JSON.parse(tasksData);
            if (tasks[vin] && tasks[vin].liveActivityPushToken) { liveActivityPushToken = tasks[vin].liveActivityPushToken; }
        } catch(e) { console.error('[CLI] 读取任务文件以更新Token失败:', e); }

        const vehicleData = await getVehicleData(vin, timaToken);
        if (!vehicleData) {
            await sendStandardPush(standardPushToken, '监控中断', '无法获取车辆信息', 'charge_task_failed', { vin, status: 'FAILED', reason: 'vehicle_data_error' });
            await updateTaskStatus(vin, 'FAILED');
            return;
        }
        
        await updateTaskVehicleData(vin, vehicleData);

        let shouldStop = false;
        let stopReason = '';

        if (vehicleData.chgStatus == 2) { 
            shouldStop = true;
            stopReason = '车辆已停止充电';
        } else {
            if (monitoringMode === 'time') {
                const targetTime = new Date(parseInt(targetTimestamp, 10) * 1000);
                if (new Date() >= targetTime) {
                    shouldStop = true;
                    stopReason = '已达到设定的充电时间';
                }
            } else if (monitoringMode === 'range') {
                if (vehicleData.acOnMile >= targetRange) { 
                    shouldStop = true;
                    stopReason = '已达到目标的剩余里程';
                }
            }
        }
        
        const chargedKwh = (vehicleData.soc - initialVehicleData.soc) * 0.1;
        await sendLiveActivityUpdate(liveActivityPushToken, { status: "充电中", chargedKwh: parseFloat(chargedKwh.toFixed(2)), percentage: vehicleData.soc, lastUpdateTime: new Date().toISOString() });
        
        if (shouldStop) {
            let finalMessage = stopReason;
            if (monitoringMode === 'time' && autoStopCharge) {
                console.log('[CLI] 达到预定时间，开始执行自动停止充电...');
                const stopSuccess = await stopVehicleCharge(vin, timaToken);
                finalMessage = stopSuccess ? '已按时为您停止充电' : '到达预定时间，但自动停止充电指令失败';
            }
            await sendStandardPush(standardPushToken, '充电提醒', finalMessage, 'charge_task_completed', { vin, status: 'COMPLETED', reason: stopReason, autoStopped: monitoringMode === 'time' && autoStopCharge });
            await updateTaskStatus(vin, 'COMPLETED');
            console.log(`[CLI] 任务完成，原因: ${finalMessage}`);
            return;
        }

        counter++;
        await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
    }
}


// ======================= 脚本入口 =======================

// 脚本执行完毕后（无论结果如何），都确保清理任务文件
process.on('exit', () => {
    if (vin) {
        cleanupTaskFile(vin);
    }
});
process.on('SIGINT', () => process.exit());
process.on('SIGTERM', () => process.exit());


let vin; // 将 vin 提升到全局作用域，以便 exit 事件可以访问

try {
    const args = process.argv.slice(2);
    if (args.length < 1) { throw new Error('缺少 Base64 载荷参数'); }
    
    const payloadBase64 = args[0];
    const payloadString = Buffer.from(payloadBase64, 'base64').toString('utf8');
    const taskDetails = JSON.parse(payloadString);
    
    vin = taskDetails.vin;
    
    runBackgroundTask(taskDetails);

} catch (error) {
    console.error('[CLI] 启动失败，无法解析参数:', error);
    process.exit(1);
}