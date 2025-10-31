// /www/wwwroot/pan3/core/services/polling.service.js

import { getVehiclesDueForPolling, updateVehicleAfterPoll, insertDataPoint, createDrive, updateDrive, createCharge, updateCharge } from '../database/operations.js';
import { getVehicleDataInternal, sendPushNotificationInternal } from './internal.service.js';
import { calculateSpeed } from '../utils/geo.js';

// 轮询间隔（毫秒）
const POLL_INTERVAL_ACTIVE = 5000;  // 5 秒（active 状态）
const POLL_INTERVAL_IDLE = 60000;   // 1 分钟（idle 状态）

// 轮询服务状态
let isPollingActive = false;
let pollingTimeoutId = null;

/**
 * 启动轮询服务
 */
export function startPollingService() {
    if (isPollingActive) {
        console.log('[Polling Service] 轮询服务已在运行中');
        return;
    }
    
    isPollingActive = true;
    console.log('[Polling Service] 轮询服务已启动');
    scheduleNextPoll();
}

/**
 * 停止轮询服务
 */
export function stopPollingService() {
    isPollingActive = false;
    if (pollingTimeoutId) {
        clearTimeout(pollingTimeoutId);
        pollingTimeoutId = null;
    }
    console.log('[Polling Service] 轮询服务已停止');
}

/**
 * 调度下一次轮询
 */
function scheduleNextPoll() {
    if (!isPollingActive) return;
    
    pollingTimeoutId = setTimeout(async () => {
        await performPollingCycle();
        scheduleNextPoll(); // 递归链
    }, POLL_INTERVAL_ACTIVE); // 使用 active 间隔（5秒）作为检查频率
}

/**
 * 执行一次完整的轮询周期
 */
async function performPollingCycle() {
    try {
        // 获取待轮询车辆
        const vehicles = getVehiclesDueForPolling();
        
        if (vehicles.length === 0) {
            return; // 没有待轮询车辆
        }
        
        console.log(`[Polling Service] 开始轮询 ${vehicles.length} 辆车辆`);
        
        // 并发处理所有车辆
        const results = await Promise.allSettled(
            vehicles.map(vehicle => pollSingleVehicle(vehicle))
        );
        
        // 统计结果
        const successful = results.filter(r => r.status === 'fulfilled').length;
        const failed = results.filter(r => r.status === 'rejected').length;
        
        console.log(`[Polling Service] 轮询完成 - 成功: ${successful}, 失败: ${failed}`);
        
    } catch (error) {
        console.error('[Polling Service] 轮询周期执行异常:', error);
    }
}

/**
 * 判断车辆是否应该处于 active 状态
 * @param {string} keyStatus - 钥匙状态
 * @param {string} mainLockStatus - 锁车状态
 * @param {string} chgStatus - 充电状态
 * @returns {boolean}
 */
function shouldBeActive(keyStatus, mainLockStatus, chgStatus) {
    return keyStatus === '1' ||           // 启动状态
           mainLockStatus === '1' ||      // 开锁
           chgStatus === '3';             // 充电中
}

/**
 * 判断车辆是否应该回到 idle 状态
 * @param {string} keyStatus - 钥匙状态
 * @param {string} mainLockStatus - 锁车状态
 * @param {string} chgStatus - 充电状态
 * @returns {boolean}
 */
function shouldBeIdle(keyStatus, mainLockStatus, chgStatus) {
    return mainLockStatus === '0' &&      // 锁车
           keyStatus === '2' &&           // 非启动
           chgStatus === '2';             // 非充电
}

/**
 * 轮询单个车辆
 * @param {object} vehicle - 车辆记录
 */
async function pollSingleVehicle(vehicle) {
    const { vin, api_token, push_token, last_keyStatus, last_mainLockStatus, last_chgStatus, last_lat, last_lon, last_timestamp, current_drive_id, current_charge_id, internal_state } = vehicle;
    
    try {
        // 1. 调用 JVC API 获取车辆数据
        const vehicleData = await getVehicleDataInternal(vin, api_token);
        
        // 2. 提取关键状态和数据
        const currentKeyStatus = String(vehicleData.keyStatus);
        const currentMainLockStatus = String(vehicleData.mainLockStatus);
        const currentChgStatus = String(vehicleData.chgStatus);
        const currentLat = vehicleData.lat;
        const currentLon = vehicleData.lon;
        const currentTimestamp = Date.now();
        const currentSoc = vehicleData.soc;
        const currentRangeKm = vehicleData.acOnMile || 0;        // 剩余续航
        const currentTotalMileage = vehicleData.totalMileage || null;  // 总里程
        
        // 3. 计算速度
        let calculatedSpeed = 0;
        if (last_lat && last_lon && last_timestamp) {
            calculatedSpeed = calculateSpeed(
                last_lat, last_lon, last_timestamp,
                currentLat, currentLon, currentTimestamp
            );
        }
        
        // 4. 判断新的状态
        const newStateActive = shouldBeActive(currentKeyStatus, currentMainLockStatus, currentChgStatus);
        const newStateIdle = shouldBeIdle(currentKeyStatus, currentMainLockStatus, currentChgStatus);
        
        let newInternalState = internal_state || 'idle';
        if (newStateActive) {
            newInternalState = 'active';
        } else if (newStateIdle) {
            newInternalState = 'idle';
        }
        
        // 5. 状态检测与处理（充电优先级 > 行驶）
        let newDriveId = current_drive_id;
        let newChargeId = current_charge_id;
        
        // 5.1 检测充电状态（优先级最高）
        if (currentChgStatus === '3' && last_chgStatus !== '3') {
            // 开始充电
            console.log(`[Polling Service] ${vin} 开始充电`);
            
            // 如果正在行驶，先结束行驶
            if (current_drive_id) {
                updateDrive(current_drive_id, {
                    end_time: new Date(currentTimestamp).toISOString(),
                    end_lat: currentLat,
                    end_lon: currentLon,
                    end_soc: currentSoc,
                    end_range_km: currentRangeKm
                });
                
                newDriveId = null;
                console.log(`[Polling Service] ${vin} 结束行驶（进入充电），摘要计算已加入队列`);
            }
            
            // 创建充电记录
            newChargeId = createCharge({
                vin,
                start_time: new Date(currentTimestamp).toISOString(),
                start_soc: currentSoc,
                start_range_km: currentRangeKm,
                lat: currentLat,
                lon: currentLon
            });
            
        } else if (currentChgStatus === '2' && last_chgStatus === '3') {
            // 结束充电
            console.log(`[Polling Service] ${vin} 结束充电，摘要计算已加入队列`);
            
            if (current_charge_id) {
                updateCharge(current_charge_id, {
                    end_time: new Date(currentTimestamp).toISOString(),
                    end_soc: currentSoc,
                    end_range_km: currentRangeKm
                });
                
                newChargeId = null;
            }
            
            // 发送充电结束推送通知
            if (push_token) {
                setImmediate(async () => {
                    try {
                        await sendPushNotificationInternal(
                            push_token,
                            '充电完成',
                            `您的车辆充电已完成，当前电量 ${currentSoc}%，续航 ${currentRangeKm}km`,
                            'charge_completed'
                        );
                        console.log(`[Polling Service] ${vin} 充电完成推送已发送`);
                    } catch (pushError) {
                        console.error(`[Polling Service] ${vin} 充电完成推送失败:`, pushError.message);
                    }
                });
            }
        }
        
        // 5.2 检测行驶状态（仅在非充电状态下）
        if (currentChgStatus !== '3') {
            if (currentKeyStatus === '1' && currentMainLockStatus === '0' && 
                !(last_keyStatus === '1' && last_mainLockStatus === '0')) {
                // 开始行驶
                console.log(`[Polling Service] ${vin} 开始行驶`);
                
                // 如果已经有未结束的行程，先结束它
                if (current_drive_id) {
                    updateDrive(current_drive_id, {
                        end_time: new Date(currentTimestamp).toISOString(),
                        end_lat: currentLat,
                        end_lon: currentLon,
                        end_soc: currentSoc,
                        end_range_km: currentRangeKm
                    });
                    console.log(`[Polling Service] ${vin} 结束旧行程（开始新行程）`);
                }
                
                newDriveId = createDrive({
                    vin,
                    start_time: new Date(currentTimestamp).toISOString(),
                    start_lat: currentLat,
                    start_lon: currentLon,
                    start_soc: currentSoc,
                    start_range_km: currentRangeKm
                });
                
            } else if (currentKeyStatus === '2' && currentMainLockStatus === '0' && 
                       current_drive_id) {
                // 结束行驶
                console.log(`[Polling Service] ${vin} 结束行驶，摘要计算已加入队列`);
                
                updateDrive(current_drive_id, {
                    end_time: new Date(currentTimestamp).toISOString(),
                    end_lat: currentLat,
                    end_lon: currentLon,
                    end_soc: currentSoc,
                    end_range_km: currentRangeKm
                });
                
                newDriveId = null;
            }
        }
        
        // 6. 插入数据点（包含新字段）
        insertDataPoint({
            timestamp: new Date(currentTimestamp).toISOString(),
            vin,
            lat: currentLat,
            lon: currentLon,
            soc: currentSoc,
            remaining_range_km: currentRangeKm,
            total_mileage: currentTotalMileage,
            keyStatus: currentKeyStatus,
            mainLockStatus: currentMainLockStatus,
            chgPlugStatus: String(vehicleData.chgPlugStatus || ''),
            chgStatus: currentChgStatus,
            chgLeftTime: vehicleData.chgLeftTime || 0,
            calculated_speed_kmh: calculatedSpeed,
            drive_id: newDriveId,
            charge_id: newChargeId
        });
        
        // 7. 计算下次轮询时间（动态间隔）
        const pollInterval = newInternalState === 'active' ? POLL_INTERVAL_ACTIVE : POLL_INTERVAL_IDLE;
        const nextPollTime = new Date(Date.now() + pollInterval).toISOString().replace('T', ' ').substring(0, 19);
        
        // 8. 更新 vehicles 表
        updateVehicleAfterPoll(vin, {
            internal_state: newInternalState,
            next_poll_time: nextPollTime,
            last_keyStatus: currentKeyStatus,
            last_mainLockStatus: currentMainLockStatus,
            last_chgStatus: currentChgStatus,
            last_lat: currentLat,
            last_lon: currentLon,
            last_timestamp: currentTimestamp,
            current_drive_id: newDriveId,
            current_charge_id: newChargeId
        });
        
        console.log(`[Polling Service] ${vin} 轮询成功 [${newInternalState}] 下次: ${pollInterval/1000}秒后`);
        
    } catch (error) {
        console.error(`[Polling Service] ${vin} 轮询失败:`, error.message);
        
        // 错误处理
        let delayMinutes = 5; // 默认 5 分钟
        let newState = 'error';
        
        if (error.message.includes('500')) {
            delayMinutes = 5;
            newState = 'error_500';
        } else if (error.message.includes('403')) {
            delayMinutes = 43200; // 30 天 = 30 * 24 * 60 分钟
            newState = 'token_invalid';
        }
        
        const nextPollTime = new Date(Date.now() + delayMinutes * 60 * 1000).toISOString().replace('T', ' ').substring(0, 19);
        
        updateVehicleAfterPoll(vin, {
            internal_state: newState,
            next_poll_time: nextPollTime
        });
        
        console.log(`[Polling Service] ${vin} 设置下次轮询时间: ${nextPollTime}`);
    }
}

