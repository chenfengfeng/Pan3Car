// /www/wwwroot/pan3/core/services/push.service.js
import fs from 'fs';
import apn from '@parse/node-apn';
import { APNsCircuitBreaker } from '../utils/circuit-breaker.js';

// === 环境变量和配置 ===
const { APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_KEY_PATH } = process.env;

// === 全局 Provider 管理 ===
let apnProvider = null;
let providerState = 'IDLE'; // IDLE, CONNECTING, READY, ERROR

// 熔断器实例
const apnsCircuitBreaker = new APNsCircuitBreaker();

// === 请求队列机制 ===
const pushQueue = [];
let isProcessingQueue = false;

function createProvider() {
    console.log("🔧 开始创建APNs Provider...");
    try {
        providerState = 'CONNECTING';

        const provider = new apn.Provider({
            token: {
                key: APNS_KEY_PATH,
                keyId: APNS_KEY_ID,
                teamId: APNS_TEAM_ID,
            },
            production: false
        });

        // 增强事件监听，提供更丰富的诊断信息
        provider.on('error', (error) => {
            console.error("❌ APNs Provider 错误:", error);
            providerState = 'ERROR';
        });

        // 监听推送传输成功事件
        provider.on('transmitted', (notification, device) => {
            console.log(`📤 APNs 推送已传输到设备: ${device}`);
        });

        // 监听推送失败事件 - APNs服务器明确拒绝的通知
        provider.on('failed', (notification, device) => {
            const reason = device.response?.reason || device.error?.message || "未知原因";
            const status = device.status || "未知状态";
            console.error(`📤❌ APNs 推送被服务器拒绝 - 设备: ${device.device}, 状态: ${status}, 原因: ${reason}`);

            // 根据具体错误类型进行不同处理
            if (reason === 'BadDeviceToken' || reason === 'Unregistered') {
                console.warn(`⚠️ 设备令牌可能需要更新或移除: ${device.device}`);
            } else if (reason === 'TopicDisallowed') {
                console.error(`🚫 推送主题不被允许，请检查Bundle ID配置`);
            }
        });

        // 监听网络传输错误事件 - 网络层面的传输失败
        provider.on('transmissionError', (errorCode, notification, device) => {
            console.error(`🌐❌ APNs 网络传输失败 - 设备: ${device}, 错误码: ${errorCode}`);
        });

        // Provider创建成功后立即标记为就绪状态
        // APNs库会在需要时自动建立连接，无需等待连接事件
        providerState = 'READY';
        console.log("✅ APNs Provider 创建成功，已就绪");

        return provider;
    } catch (error) {
        console.error("❌ 创建 APNs Provider 失败:", error.message);
        providerState = 'ERROR';
        return null;
    }
}

// 懒加载：仅在需要时初始化 Provider
console.log("📱 APNs 推送服务已启动（懒加载模式）");

// === 按需连接管理 ===
async function ensureConnection() {
    // 如果已有活跃连接，直接使用
    if (apnProvider && providerState === 'READY') {
        console.log("🔄 使用现有APNs连接");
        return apnProvider;
    }

    // 创建新连接
    console.log("🔄 按需建立 APNs 连接...");
    console.log(`🔍 环境变量检查: APNS_KEY_ID=${APNS_KEY_ID ? '已设置' : '未设置'}, APNS_TEAM_ID=${APNS_TEAM_ID ? '已设置' : '未设置'}, APNS_BUNDLE_ID=${APNS_BUNDLE_ID ? '已设置' : '未设置'}, APNS_KEY_PATH=${APNS_KEY_PATH ? '已设置' : '未设置'}`);

    apnProvider = createProvider();

    if (!apnProvider) {
        throw new Error("无法建立 APNs 连接：Provider创建失败");
    }

    // Provider创建成功即可使用，无需等待连接事件
    console.log("✅ APNs连接建立成功");
    return apnProvider;
}

// === 连接状态监控 ===
let connectionStats = {
    totalRequests: 0,
    successfulRequests: 0,
    failedRequests: 0,
    lastSuccessTime: null,
    lastFailureTime: null,
    consecutiveFailures: 0
};

// === 统计更新函数 ===
function updateConnectionStats(success, error = null) {
    connectionStats.totalRequests++;

    if (success) {
        connectionStats.successfulRequests++;
        connectionStats.lastSuccessTime = Date.now();
        connectionStats.consecutiveFailures = 0;
    } else {
        connectionStats.failedRequests++;
        connectionStats.lastFailureTime = Date.now();
        connectionStats.consecutiveFailures++;
    }

    // 每100次请求输出一次统计信息
    if (connectionStats.totalRequests % 100 === 0) {
        const successRate = (connectionStats.successfulRequests / connectionStats.totalRequests * 100).toFixed(2);
        console.log(`📊 APNs 推送统计: 成功率 ${successRate}%, 总计 ${connectionStats.totalRequests} 次`);
    }
}

// === 队列处理机制 ===
async function processQueue() {
    if (isProcessingQueue || pushQueue.length === 0) {
        return;
    }

    isProcessingQueue = true;

    while (pushQueue.length > 0) {
        const task = pushQueue.shift();
        try {
            const result = await executeDirectSend(task.notification, task.token, task.desc);
            task.resolve(result);
            // 移除重复的统计调用，executeDirectSend 内部已经处理了统计
        } catch (error) {
            task.reject(error);
            // 移除重复的统计调用，executeDirectSend 内部已经处理了统计
        }

        // 在请求之间添加小延迟，避免过于频繁的请求
        await new Promise(resolve => setTimeout(resolve, 100));
    }

    isProcessingQueue = false;
}

// === 直接发送函数（集成熔断器）===
async function executeDirectSend(notification, token, desc = "推送") {
    // 使用熔断器保护APNs推送操作
    console.log(`🔄 尝试发送 ${desc} 到设备 ${token}...`);
    return await apnsCircuitBreaker.executePush(async () => {
        const maxRetries = 3;

        for (let attempt = 1; attempt <= maxRetries; attempt++) {
            try {
                // 确保连接可用
                const provider = await ensureConnection();

                const result = await provider.send(notification, token);

                if (result.sent.length > 0) {
                    console.log(`✅ ${desc} 发送成功`);
                    updateConnectionStats(true);
                    // 保持持久连接，不启动空闲计时器
                    return result;
                }

                if (result.failed.length > 0) {
                    const failure = result.failed[0];
                    const reason = failure.response?.reason || failure.error?.message || "未知原因";
                    console.error(`❌ ${desc} 失败: ${reason}`);

                    // 让node-apn库自己管理连接恢复，不主动断开连接
                    console.log("🔄 推送失败，让node-apn库处理连接管理...");

                    if (attempt < maxRetries) {
                        // 增加重试延迟，给APNs服务器更多时间
                        await new Promise(r => setTimeout(r, 2000 * attempt));
                        continue;
                    }

                    // 最后一次重试失败，记录统计并抛出错误
                    const error = new Error(reason);
                    updateConnectionStats(false, error);
                    throw error;
                }

            } catch (err) {
                console.error(`❌ ${desc} 异常: ${err.message}`);

                // 让node-apn库自己管理连接异常恢复，不主动断开连接
                console.log("🔄 捕获到异常，让node-apn库处理连接管理...");

                if (attempt < maxRetries) {
                    // 增加重试延迟，给APNs服务器更多时间
                    await new Promise(r => setTimeout(r, 2000 * attempt));
                    continue;
                }

                // 最后一次重试失败，记录统计并抛出错误
                updateConnectionStats(false, err);
                throw err;
            }
        }

        // 理论上不会到达这里，但为了安全起见
        const finalError = new Error("推送失败：所有重试均失败");
        updateConnectionStats(false, finalError);
        throw finalError;
    }, token);
}

// === 通用发送函数（通过队列）===
async function safeSend(notification, token, desc = "推送") {
    return new Promise((resolve, reject) => {
        pushQueue.push({
            notification,
            token,
            desc,
            resolve,
            reject
        });

        // 启动队列处理
        processQueue().catch(error => {
            console.error("队列处理异常:", error);
        });
    });
}

// === 通用推送 ===
export async function sendApplePush(pushData) {
    const { pushToken, title, body, operationType, ext } = pushData;
    if (!pushToken) throw new Error("pushToken 缺失");

    const n = new apn.Notification();
    n.topic = APNS_BUNDLE_ID;
    n.expiry = Math.floor(Date.now() / 1000) + 3600;
    n.sound = "default";
    n.priority = 10;
    n.contentAvailable = 1;

    if (title && body) n.alert = { title, body };
    if (operationType) n.payload.operation_type = operationType;
    if (ext) n.payload.ext = ext;

    const result = await safeSend(n, pushToken, "Apple 通用推送");
    return { success: true, result };
}

// === 车辆数据推送 ===
export async function sendCarDataPush(carPushData) {
    const { pushToken, car_data, title, body } = carPushData;
    if (!pushToken || !car_data) throw new Error("缺少必需的 pushToken 或 car_data");

    const notification = new apn.Notification();
    notification.topic = APNS_BUNDLE_ID;
    notification.contentAvailable = 1;
    notification.mutableContent = 1;

    notification.sound = "default";
    notification.priority = 10;
    if (title && body) notification.alert = { title, body };

    notification.payload = {
        'car_data': car_data,
        'operation_type': 'car_data_update',
        'timestamp': Math.floor(Date.now() / 1000),
        'interruption-level': 'active'
    };

    const result = await safeSend(notification, pushToken, "车辆数据推送");
    return { success: true, result };
}

// === Live Activity 推送 ===
export async function sendLiveActivityPush(data) {
    const { liveActivityPushToken, contentState } = data;
    if (!liveActivityPushToken || !contentState) throw new Error("缺少参数");

    const topic = `${APNS_BUNDLE_ID}.push-type.liveactivity`;
    // --- 这里是修改的起点 ---

    const currentTimestamp = Math.floor(Date.now() / 1000);
    const validContentState = {
        currentKm: contentState.currentKm ?? 0,
        currentSoc: contentState.currentSoc ?? 0,
        chargeProgress: contentState.chargeProgress ?? 0,
        message: contentState.message ?? ""
    };

    // 1. 先定义好完整的 payload 对象
    const payload = {
        aps: {
            timestamp: currentTimestamp,
            event: "update",
            "content-state": validContentState
        }
    };

    // 2. 将 payload 直接传入 Notification 的构造函数
    const notification = new apn.Notification(payload);

    // 3. 然后再设置其他的元数据
    notification.topic = topic;
    notification.pushType = "liveactivity";
    notification.priority = 10;

    const result = await safeSend(notification, liveActivityPushToken, "Live Activity 推送");
    return { success: true, result };
}