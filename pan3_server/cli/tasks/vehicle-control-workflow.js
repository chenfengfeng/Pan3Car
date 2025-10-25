// /www/wwwroot/pan3/cli/tasks/vehicle-control-workflow.js

import { 
    getVehicleDataInternal
} from '../../core/services/internal.service.js';

// 服务器配置
const SERVER_PORT = process.env.PORT || 3333;
const SERVER_HOST = 'localhost';

/**
 * 发送HTTP请求到主进程API
 */
async function sendHttpRequest(endpoint, data) {
    try {
        const response = await fetch(`http://${SERVER_HOST}:${SERVER_PORT}${endpoint}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        });

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(`HTTP ${response.status}: ${errorText}`);
        }

        return await response.json();
    } catch (error) {
        console.error(`[CLI] HTTP请求失败 - ${endpoint}:`, error.message);
        throw error;
    }
}

// ======================= 辅助函数区 =======================

/**
 * 获取最新的车辆信息 - 直接调用内部服务
 * @param {string} vin 
 * @param {string} timaToken 
 * @returns {Promise<object|null>} 返回车辆数据对象，或在失败时返回null
 */
async function getVehicleData(vin, timaToken) {
    try {
        const vehicleData = await getVehicleDataInternal(vin, timaToken);
        console.log(`[CLI] 获取车辆信息成功 - VIN: ${vin}`);
        return vehicleData;
    } catch (error) {
        console.error(`[CLI] 获取车辆信息失败 - VIN: ${vin}:`, error.message);
        return null;
    }
}

/**
 * 发送苹果推送通知 - 直接调用内部服务
 * @param {string} title 
 * @param {string} body 
 * @param {string} pushToken 
 * @param {string} operationType 
 */
/**
 * 发送推送通知（通过HTTP API调用主进程）
 */
async function sendPushNotification(title, body, pushToken, operationType) {
    try {
        const pushData = {
            pushToken: pushToken,
            title: title,
            body: body,
            operationType: operationType
        };

        await sendHttpRequest('/api/push/send', pushData);
        console.log(`[CLI] 推送通知发送成功 - ${title}: ${body}`);
    } catch (error) {
        console.error(`[CLI] 推送通知发送异常:`, error.message);
    }
}


// ======================= 主逻辑函数 =======================

/**
 * 后台轮询任务，通过对比车辆状态来确认操作结果
 */
/**
 * 发送车辆数据推送通知 - 使用新的结构化推送格式
 */
/**
 * 发送车辆数据推送通知 - 直接调用内部服务
 * @param {string} title 
 * @param {string} body 
 * @param {string} pushToken 
 * @param {string} operationType 
 * @param {object} vehicleData 
 */
/**
 * 发送车辆数据推送通知（通过HTTP API调用主进程）
 */
async function sendCarDataPushNotification(title, body, pushToken, operationType, vehicleData) {
    try {
        const carPushData = {
            pushToken: pushToken,
            car_data: vehicleData,
            title: title,
            body: body,
            operationType: operationType
        };

        await sendHttpRequest('/api/push/car-data', carPushData);
        console.log(`[CLI] 车辆数据推送发送成功 - ${title}: ${body}`);
    } catch (error) {
        console.error(`[CLI] 车辆数据推送发送异常:`, error.message);
    }
}

async function runBackgroundTask(vin, timaToken, pushToken, operationType, operation) {
    const MAX_RETRIES = 10; // 最大轮询次数
    const RETRY_DELAY = 3000; // 每次轮询间隔（毫秒）

    console.log(`[CLI] 开始后台任务 - VIN: ${vin}, 操作类型: ${operationType}, 操作: ${operation}`);

    for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
        console.log(`[CLI] 第 ${attempt}/${MAX_RETRIES} 次轮询车辆状态...`);

        // 检查1：获取车辆数据
        const vehicleData = await getVehicleData(vin, timaToken);
        if (!vehicleData) {
            console.log(`[CLI] 第 ${attempt} 次轮询失败，无法获取车辆数据`);
            continue; // 继续下一次轮询
        }

        // 检查2：根据操作类型判断是否成功
        let isSuccess = false;
        let successMessage = '';

        switch (operationType) {
            case 'LOCK':
                // operation '1' 是锁门, '2' 是解锁
                if (operation === '1' && vehicleData.mainLockStatus === 0) { /* 0是锁门状态 */
                    isSuccess = true;
                    successMessage = '车辆已成功上锁';
                } else if (operation === '2' && vehicleData.mainLockStatus !== 0) { /* 非0是解锁状态 */
                    isSuccess = true;
                    successMessage = '车辆已成功解锁';
                }
                break;
            
            case 'WINDOW':
                // operation '1' 是关窗, '2' 是开窗
                const areAllWindowsClosed = vehicleData.lfWindowOpen === 0 && vehicleData.rfWindowOpen === 0 && vehicleData.lrWindowOpen === 0 && vehicleData.rrWindowOpen === 0;
                if (operation === '1' && areAllWindowsClosed) {
                    isSuccess = true;
                    successMessage = '所有车窗已关闭';
                } else if (operation === '2' && !areAllWindowsClosed) {
                    isSuccess = true;
                    successMessage = '车窗已开启';
                }
                break;

            case 'INTELLIGENT_AIRCONDITIONER':
                // operation '1' 是关空调, '2' 是开空调
                if (operation === '1' && vehicleData.acStatus !== 1) { /* 非1都是关闭状态 */
                    isSuccess = true;
                    successMessage = '空调已关闭';
                } else if (operation === '2' && vehicleData.acStatus === 1) { /* 1是开启状态 */
                    isSuccess = true;
                    successMessage = '空调已开启，车内正在调节温度';
                }
                break;
        }

        // 检查3：如果操作成功，发送车辆数据推送并结束任务
        if (isSuccess) {
            await sendCarDataPushNotification('操作成功', successMessage, pushToken, operationType, vehicleData);
            console.log(`[CLI] 操作成功确认，任务完成。`);
            process.exit(0); // 显式退出进程，确保父进程能收到输出
        }

        // 如果未成功，等待一段时间再进行下一次循环
        await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
    }

    // 检查4：如果循环完成，但操作仍未成功，视为超时
    // 超时时也获取最新车辆数据发送推送
    await sendPushNotification('操作超时', '车辆状态未在预期时间内变更，请稍后重试', pushToken, operationType);
    console.log('[CLI] 任务超时，发送通知后退出。');
    process.exit(1); // 超时退出，使用退出码1表示异常
}


// ======================= 脚本入口 =======================

const args = process.argv.slice(2);
if (args.length < 5) {
    console.error('Usage: node vehicle-control.js <vin> <timaToken> <pushToken> <operationType> <operation>');
    process.exit(1);
}

const [vin, timaToken, pushToken, operationType, operation] = args;
runBackgroundTask(vin, timaToken, pushToken, operationType, operation);