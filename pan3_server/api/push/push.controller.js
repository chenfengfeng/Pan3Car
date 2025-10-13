// /www/wwwroot/pan3/api/push/push.controller.js

import { sendApplePush, sendLiveActivityPush } from '../../core/services/push.service.js';

export async function handlePushRequest(req, res) {
    try {
        const pushData = req.body;
        if (!pushData.pushToken) {
            return res.status(400).json({ code: 400, message: '请求体中缺少必需的 pushToken' });
        }

        // 调用核心推送服务
        await sendApplePush(pushData);
        
        // 推送成功，返回200 OK
        res.status(200).json({ code: 200, message: '推送指令已成功发送至APNs' });

    } catch (e) {
        console.error('推送接口异常:', e.message);
        res.status(500).json({ code: 500, message: `Push API error: ${e.message}` });
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