// /www/wwwroot/pan3/core/services/push.service.js

import apn from 'node-apn';
import fs from 'fs';

// 从环境变量读取配置
const { APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_KEY_PATH } = process.env;

// --- 1. 配置 node-apn ---
// node-apn 会自动处理密钥文件的读取和JWT的生成与刷新
const options = {
    token: {
        key: APNS_KEY_PATH, // 直接提供.p8文件的路径
        keyId: APNS_KEY_ID,
        teamId: APNS_TEAM_ID
    },
    production: process.env.NODE_ENV === 'production'
};

// --- 2. 创建可复用的 provider 对象 ---
let apnProvider;
// 启动时检查配置是否齐全，文件是否存在
if (APNS_KEY_PATH && APNS_KEY_ID && APNS_TEAM_ID) {
    if (fs.existsSync(APNS_KEY_PATH)) {
        apnProvider = new apn.Provider(options);
        console.log(`APNs Provider 初始化成功，密钥路径: ${APNS_KEY_PATH}`);
    } else {
        console.error(`APNs 密钥文件未在指定路径找到: ${APNS_KEY_PATH}`);
    }
} else {
    console.warn("APNs 推送服务的环境变量未完全配置，推送功能将不可用。");
}


/**
 * 使用 node-apn 发送苹果推送的通用服务函数
 */
export async function sendApplePush(pushData) {
    if (!apnProvider) {
        throw new Error("APNs Provider 未初始化，请检查环境变量。");
    }

    const { pushToken, title, body, operationType, ext } = pushData;

    if (!pushToken) {
        throw new Error("pushToken is missing.");
    }

    const notification = new apn.Notification();
    notification.topic = APNS_BUNDLE_ID;
    notification.expiry = Math.floor(Date.now() / 1000) + 3600;
    notification.sound = "default";
    notification.priority = 10;

    if (title && body) {
        notification.alert = { title, body };
        notification.payload['interruption-level'] = 'time-sensitive';
        if (operationType) {
            notification.contentAvailable = 1;
        }
    } else {
        notification.contentAvailable = 1;
    }
    
    if (operationType) {
        notification.payload['operation_type'] = operationType;
    }
    
    // 添加ext额外信息到payload
    if (ext && typeof ext === 'object') {
        notification.payload['ext'] = ext;
    }
    
    console.log(`准备使用 node-apn 向 ${pushToken.substring(0, 10)}... 发送推送...`);

    try {
        const result = await apnProvider.send(notification, pushToken);
        
        if (result.sent.length > 0) {
            console.log("node-apn 推送成功:", JSON.stringify(result.sent));
            return { success: true, result };
        } 
        
        if (result.failed.length > 0) {
            console.error("node-apn 推送失败:", JSON.stringify(result.failed, null, 2));
            const failure = result.failed[0];
            const reason = failure.response?.reason || failure.error || 'Unknown failure reason';
            throw new Error(`APNs push failed: ${reason}`);
        }

        return { success: false, result };

    } catch (error) {
        console.error("apnProvider.send 异常:", error);
        throw error;
    }
}

/**
 * 发送实时活动(Live Activity)更新推送
 * @param {object} liveActivityData
 * @param {string} liveActivityData.liveActivityPushToken - 实时活动的专用推送Token
 * @param {object} liveActivityData.contentState - 符合您App中ContentState结构的对象
 */
export async function sendLiveActivityPush(liveActivityData) {
    if (!apnProvider) {
        throw new Error("APNs Provider 未初始化。");
    }

    const { liveActivityPushToken, contentState } = liveActivityData;

    if (!liveActivityPushToken || !contentState) {
        throw new Error("实时活动推送缺少必需的 token 或 contentState。");
    }

    // --- 构造实时活动专用的通知 ---
    const notification = new apn.Notification();
    notification.topic = `${APNS_BUNDLE_ID}.push-type.liveactivity`; // 实时活动的topic通常需要加上后缀

    // --- 【核心】构造苹果要求的实时活动Payload ---
    notification.payload = {
        aps: {
            timestamp: Math.floor(Date.now() / 1000), // 必须是Unix时间戳 (秒)
            event: "update", // 'update'表示更新, 'end'表示结束
            'content-state': contentState // 这里的key必须是 'content-state'
        }
    };
    
    // --- 【核心】设置推送类型和优先级 ---
    notification.pushType = 'liveactivity'; // 必须设置为 'liveactivity'
    notification.priority = 10; // 实时活动建议使用高优先级

    console.log(`准备发送 Live Activity 更新到 ${liveActivityPushToken.substring(0, 10)}...`);

    try {
        const result = await apnProvider.send(notification, liveActivityPushToken);

        if (result.sent.length > 0) {
            console.log("Live Activity 更新成功:", JSON.stringify(result.sent));
            return { success: true, result };
        }
        
        if (result.failed.length > 0) {
            console.error("Live Activity 更新失败:", JSON.stringify(result.failed, null, 2));
            const failure = result.failed[0];
            const reason = failure.response?.reason || failure.error || 'Unknown failure reason';
            throw new Error(`Live Activity push failed: ${reason}`);
        }

        return { success: false, result };

    } catch (error) {
        console.error("sendLiveActivityPush 异常:", error);
        throw error;
    }
}