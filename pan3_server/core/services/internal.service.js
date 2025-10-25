// /www/wwwroot/pan3/core/services/internal.service.js

import { makeRequest, baseApiUrl } from '../utils/request.js';
import { VehicleDataCircuitBreaker } from '../utils/circuit-breaker.js';
import { sendApplePush, sendLiveActivityPush, sendCarDataPush } from './push.service.js';

// 车辆数据获取熔断器实例
const vehicleDataCircuitBreaker = new VehicleDataCircuitBreaker();

/**
 * 内部服务：获取车辆数据
 * @param {string} vin 车辆VIN码
 * @param {string} timaToken 认证令牌
 * @returns {Promise<object>} 车辆数据对象
 */
export async function getVehicleDataInternal(vin, timaToken) {
    return await vehicleDataCircuitBreaker.execute(async () => {
        const targetUrl = `${baseApiUrl}/api/jac-energy/jacenergy/vehicleInformation/energy-query-vehicle-new-condition`;
        const jacPayload = { vins: [vin] };
        const jacHeaders = { 'Content-Type': 'application/json', 'timaToken': timaToken };
        
        const jacResponse = await fetch(targetUrl, { 
            method: 'POST', 
            headers: jacHeaders, 
            body: JSON.stringify(jacPayload) 
        });
        
        const jacBodyText = await jacResponse.text();
        
        if (!jacResponse.ok) {
            throw new Error(`HTTP错误! 状态: ${jacResponse.status}`);
        }
        
        const jacData = JSON.parse(jacBodyText);
        
        if (jacData.returnSuccess && jacData.data) {
            return jacData.data;
        } else {
            const errorMessage = jacData.msg || jacData.returnErrorMsg || '获取车辆信息失败，但未提供明确原因';
            throw new Error(`获取车辆数据失败: ${errorMessage}`);
        }
    });
}

/**
 * 内部服务：发送推送通知
 * @param {string} pushToken 推送令牌
 * @param {string} title 推送标题
 * @param {string} body 推送内容
 * @param {string} operationType 操作类型（可选）
 */
export async function sendPushNotificationInternal(pushToken, title, body, operationType = null) {
    try {
        const pushData = {
            pushToken: pushToken,
            title: title || '通知',
            body: body || '您有新的消息',
            operationType: operationType
        };

        await sendApplePush(pushData);
        console.log('[Internal Service] 推送通知发送成功');
    } catch (error) {
        console.error('[Internal Service] 发送推送通知异常:', error);
        throw error;
    }
}

/**
 * 内部服务：发送车辆数据推送
 * @param {string} pushToken 推送令牌
 * @param {object} vehicleData 车辆数据
 * @param {string} title 推送标题
 * @param {string} body 推送内容
 * @param {string} operationType 操作类型
 */
export async function sendCarDataPushInternal(pushToken, vehicleData, title, body, operationType) {
    try {
        const carPushData = {
            pushToken: pushToken,
            car_data: vehicleData,
            title: title,
            body: body,
            operationType: operationType
        };

        await sendCarDataPush(carPushData);
        console.log('[Internal Service] 车辆数据推送发送成功');
    } catch (error) {
        console.error('[Internal Service] 发送车辆数据推送异常:', error);
        throw error;
    }
}

/**
 * 内部服务：发送Live Activity推送
 * @param {object} liveActivityData Live Activity数据
 */
export async function sendLiveActivityPushInternal(liveActivityData) {
    try {
        await sendLiveActivityPush(liveActivityData);
        console.log('[Internal Service] Live Activity推送发送成功');
    } catch (error) {
        console.error('[Internal Service] 发送Live Activity推送异常:', error);
        throw error;
    }
}

/**
 * 内部服务：停止充电
 * @param {string} vin 车辆VIN码
 * @param {string} timaToken 认证令牌
 * @returns {Promise<object>} 操作结果
 */
export async function stopChargingInternal(vin, timaToken) {
    try {
        const targetUrl = `${baseApiUrl}/api/jac-energy/jacenergy/vehicleControl/energy-remote-vehicle-control`;
        const jacPayload = {
            operation: 1,
            extParams: {
                bookTime: 0
            },
            vin: vin,
            operationType: 'RESERVATION_RECHARGE'
        };
        const jacHeaders = { 
            'Content-Type': 'application/json', 
            'timaToken': timaToken,
            'User-Agent': 'Node-CLI-ChargeMonitor/1.0'
        };

        const jacResponse = await fetch(targetUrl, { 
            method: 'POST', 
            headers: jacHeaders, 
            body: JSON.stringify(jacPayload) 
        });

        if (!jacResponse.ok) {
            throw new Error(`HTTP错误! 状态: ${jacResponse.status}`);
        }

        const jacData = await jacResponse.json();
        
        if (jacData.returnSuccess) {
            return { success: true, message: '停止充电成功', data: jacData.data };
        } else {
            const errorMessage = jacData.msg || jacData.returnErrorMsg || '停止充电失败';
            console.error(`[Internal Service] 停止充电失败，VIN: ${vin}，错误:`, errorMessage);
            return { success: false, message: errorMessage };
        }
        
    } catch (error) {
        console.error('[Internal Service] 停止充电API调用异常:', error);
        return { success: false, message: `停止充电API调用异常: ${error.message}` };
    }
}

/**
 * 内部服务：车辆控制（通用）
 * @param {string} vin 车辆VIN码
 * @param {string} timaToken 认证令牌
 * @param {number} controlType 控制类型
 * @param {number} controlValue 控制值
 * @returns {Promise<object>} 操作结果
 */
export async function controlVehicleInternal(vin, timaToken, controlType, controlValue) {
    try {
        const targetUrl = `${baseApiUrl}/api/jac-energy/jacenergy/vehicleControl/energy-remote-control`;
        const jacPayload = {
            vin: vin,
            controlType: controlType,
            controlValue: controlValue
        };
        const jacHeaders = { 
            'Content-Type': 'application/json', 
            'timaToken': timaToken 
        };

        const jacResponse = await fetch(targetUrl, { 
            method: 'POST', 
            headers: jacHeaders, 
            body: JSON.stringify(jacPayload) 
        });

        if (!jacResponse.ok) {
            throw new Error(`HTTP错误! 状态: ${jacResponse.status}`);
        }

        const jacData = await jacResponse.json();
        
        if (jacData.returnSuccess) {
            return { success: true, message: '车辆控制成功', data: jacData.data };
        } else {
            const errorMessage = jacData.msg || jacData.returnErrorMsg || '车辆控制失败';
            console.error(`[Internal Service] 车辆控制失败，VIN: ${vin}，错误:`, errorMessage);
            return { success: false, message: errorMessage };
        }
        
    } catch (error) {
        console.error('[Internal Service] 车辆控制API调用异常:', error);
        return { success: false, message: `车辆控制API调用异常: ${error.message}` };
    }
}