// /www/wwwroot/pan3/cli/tasks/vehicle-control-workflow.js

const API_BASE_URL = 'http://127.0.0.1:3333'; // 您Node.js服务的内部地址

// ======================= 辅助函数区 =======================

/**
 * 调用我们自己的内部API，获取最新的车辆信息
 * @param {string} vin 
 * @param {string} timaToken 
 * @returns {Promise<object|null>} 返回车辆数据对象，或在失败时返回null
 */
async function getVehicleData(vin, timaToken) {
    try {
        const response = await fetch(`${API_BASE_URL}/api/car/info`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'timatoken': timaToken
            },
            body: JSON.stringify({ vin })
        });
        const result = await response.json();
        // 我们只关心业务成功且data有内容的情况
        if (result.code === 200 && result.data) {
            return result.data;
        }
        console.error(`[CLI] 获取车辆信息失败: Code: ${result.code}, Message: ${result.message}`);
        return null; // 其他情况都视为失败
    } catch (error) {
        console.error('[CLI] 调用 /api/car/info 接口时网络或解析异常:', error);
        return null;
    }
}

/**
 * 调用我们自己的内部API，发送苹果推送通知
 * @param {string} title 
 * @param {string} body 
 * @param {string} pushToken 
 * @param {string} operationType 
 */
async function sendPushNotification(title, body, pushToken, operationType) {
    try {
        await fetch(`${API_BASE_URL}/api/push`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ title, body, pushToken, operationType })
        });
        console.log(`[CLI] 推送指令已发送: "${title} - ${body}"`);
    } catch (error) {
        console.error('[CLI] 调用 /api/push 接口时网络异常:', error);
    }
}


// ======================= 主逻辑函数 =======================

/**
 * 后台轮询任务，通过对比车辆状态来确认操作结果
 */
async function runBackgroundTask(vin, timaToken, pushToken, operationType, operation) {
    console.log(`[CLI Task Started] - VIN: ${vin}, Operation: ${operationType}(${operation})`);

    const MAX_RETRIES = 10; // 最多重试10次
    const RETRY_DELAY = 1000; // 每次重试间隔1秒 (1000毫秒)

    for (let i = 0; i < MAX_RETRIES; i++) {
        console.log(`[CLI] 正在进行第 ${i + 1}/${MAX_RETRIES} 次状态检查...`);
        
        const vehicleData = await getVehicleData(vin, timaToken);

        // 检查1：如果获取车辆信息失败 (例如token失效)
        if (!vehicleData) {
            await sendPushNotification('操作失败', '账号登录状态异常，请重新登录', pushToken, operationType);
            console.log('[CLI] 因无法获取车辆信息，任务失败并退出。');
            return; // 结束任务
        }

        let isSuccess = false;
        let successMessage = '';

        // 检查2：根据操作类型，判断车辆状态是否已变更
        switch (operationType) {
            case 'LOCK':
                // operation '1' 是锁门, '2' 是解锁
                if (operation === '1' && vehicleData.mainLockStatus !== 0) { /* 非0是锁门状态 */
                    isSuccess = true;
                    successMessage = '车辆已成功上锁';
                } else if (operation === '2' && vehicleData.mainLockStatus === 0) { /* 0是解锁状态 */
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

        // 检查3：如果操作成功，发送通知并结束任务
        if (isSuccess) {
            await sendPushNotification('操作成功', successMessage, pushToken, operationType);
            console.log(`[CLI] 操作成功确认，任务完成。`);
            return; // 结束任务
        }

        // 如果未成功，等待一段时间再进行下一次循环
        await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
    }

    // 检查4：如果循环完成，但操作仍未成功，视为超时
    await sendPushNotification('操作超时', '车辆状态未在预期时间内变更，请稍后重试', pushToken, operationType);
    console.log('[CLI] 任务超时，发送通知后退出。');
}


// ======================= 脚本入口 =======================

const args = process.argv.slice(2);
if (args.length < 5) {
    console.error('Usage: node vehicle-control.js <vin> <timaToken> <pushToken> <operationType> <operation>');
    process.exit(1);
}

const [vin, timaToken, pushToken, operationType, operation] = args;
runBackgroundTask(vin, timaToken, pushToken, operationType, operation);