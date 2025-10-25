// /www/wwwroot/pan3/api/push/push.controller.js

import { sendApplePush, sendLiveActivityPush, sendCarDataPush } from '../../core/services/push.service.js';

export async function handlePushRequest(req, res) {
    try {
        const pushData = req.body;
        
        // 兼容两种参数格式：pushToken 和 token
        const pushToken = pushData.pushToken || pushData.token;
        
        if (!pushToken) {
            return res.status(400).json({ code: 400, message: '请求体中缺少必需的 pushToken 或 token' });
        }

        // 构造推送数据对象，确保格式正确
        const formattedPushData = {
            pushToken: pushToken,
            title: pushData.title || '通知',
            body: pushData.body || '您有新的消息'
        };

        // 调用核心推送服务
        await sendApplePush(formattedPushData);
        
        // 推送成功，返回200 OK
        res.status(200).json({ code: 200, message: '推送指令已成功发送至APNs' });

    } catch (e) {
        console.error('推送接口异常:', e.message);
        res.status(500).json({ code: 500, message: `Push API error: ${e.message}` });
    }
}

/**
 * 处理车辆数据推送请求的控制器
 */
export async function handleCarDataPush(req, res) {
    try {
        const carPushData = req.body;
        
        if (!carPushData.pushToken || !carPushData.car_data) {
            return res.status(400).json({ 
                code: 400, 
                message: '请求体中缺少必需的 pushToken 或 car_data' 
            });
        }

        // 调用车辆数据推送服务
        await sendCarDataPush(carPushData);
        
        res.status(200).json({ 
            code: 200, 
            message: '车辆数据推送已成功发送' 
        });

    } catch (e) {
        console.error('车辆数据推送接口异常:', e.message);
        res.status(500).json({ 
            code: 500, 
            message: `Car Data Push API error: ${e.message}` 
        });
    }
}

/**
 * 处理实时活动推送请求的控制器
 */
export async function handleLiveActivityPush(req, res) {
    try {
        const liveActivityData = req.body;
        if (!liveActivityData.liveActivityPushToken || !liveActivityData.contentState) {
            return res.status(400).json({ code: 400, message: '请求体中缺少必需的 liveActivityPushToken 或 contentState' });
        }

        await sendLiveActivityPush(liveActivityData);
        
        res.status(200).json({ code: 200, message: '实时活动更新已成功发送' });

    } catch (e) {
        console.error('实时活动推送接口异常:', e.message);
        res.status(500).json({ code: 500, message: `Live Activity API error: ${e.message}` });
    }
}