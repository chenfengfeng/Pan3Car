// /www/wwwroot/pan3/core/services/polling.service.js

import { getVehiclesDueForPolling, updateVehicleAfterPoll, insertDataPoint, createDrive, updateDrive, createCharge, updateCharge, deleteOrphanedDataPointsForVin } from '../database/operations.js';
import { getVehicleDataInternal, sendPushNotificationInternal } from './internal.service.js';

// 轮询间隔（毫秒）
const POLL_INTERVAL_ACTIVE_MIN = 5000;   // 5 秒（active 状态最小间隔）
const POLL_INTERVAL_ACTIVE_MAX = 10000;  // 10 秒（active 状态最大间隔）
const POLL_INTERVAL_IDLE_MIN = 55000;    // 55 秒（idle 状态最小间隔）
const POLL_INTERVAL_IDLE_MAX = 65000;    // 65 秒（idle 状态最大间隔）

// 轮询服务状态
let isPollingActive = false;
let pollingTimeoutId = null;

/**
 * 生成随机轮询间隔（毫秒）
 * @param {number} min - 最小间隔
 * @param {number} max - 最大间隔
 * @returns {number} 随机间隔
 */
function getRandomInterval(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

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
    
    // 使用随机间隔（5-10秒），避免风控
    const randomInterval = getRandomInterval(POLL_INTERVAL_ACTIVE_MIN, POLL_INTERVAL_ACTIVE_MAX);
    
    pollingTimeoutId = setTimeout(async () => {
        await performPollingCycle();
        scheduleNextPoll(); // 递归链
    }, randomInterval);
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
        
        // 并发处理所有车辆
        const results = await Promise.allSettled(
            vehicles.map(vehicle => pollSingleVehicle(vehicle))
        );
        
        // 统计结果（仅用于错误处理，不输出日志）
        const successful = results.filter(r => r.status === 'fulfilled').length;
        const failed = results.filter(r => r.status === 'rejected').length;
        
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
    const { vin, api_token, push_token, last_keyStatus, last_mainLockStatus, last_chgStatus, last_lat, last_lon, last_timestamp, last_total_mileage, last_calculated_speed, current_drive_id, current_charge_id, internal_state } = vehicle;
    
    try {
        // 1. 调用 JVC API 获取车辆数据
        const vehicleData = await getVehicleDataInternal(vin, api_token);
        
        // 2. 提取关键状态和数据
        const currentKeyStatus = String(vehicleData.keyStatus);
        const currentMainLockStatus = String(vehicleData.mainLockStatus);
        const currentChgStatus = String(vehicleData.chgStatus);
        const currentLat = vehicleData.latitude;
        const currentLon = vehicleData.longtitude;
        const currentTimestamp = Date.now();
        const currentSoc = vehicleData.soc;
        const currentRangeKm = vehicleData.acOnMile || 0;        // 剩余续航
        const currentTotalMileage = vehicleData.totalMileage || null;  // 总里程
        
        // 3. 基于总里程计算速度（加速度限制优化）
        let calculatedSpeed = 0;
        
        // 获取上次计算的速度
        const lastSpeed = last_calculated_speed || 0;
        
        // 只在有历史数据时计算
        if (last_total_mileage && currentTotalMileage && last_timestamp) {
            const mileageDiff = parseFloat(currentTotalMileage) - parseFloat(last_total_mileage);
            const timeSeconds = (currentTimestamp - last_timestamp) / 1000;
            
            // 里程未变化，速度为0
            if (mileageDiff === 0) {
                calculatedSpeed = 0;
            }
            // 确保时间差和里程差合理
            else if (timeSeconds > 0 && mileageDiff >= 0 && mileageDiff < 100) { // 100公里为单次轮询最大合理值
                const rawSpeed = (mileageDiff / timeSeconds) * 3600; // 转换为km/h
                
                // 速度合理性检查（0-200 km/h）
                if (rawSpeed >= 0 && rawSpeed <= 200) {
                    // 应用加速度限制（10 km/h/s，相当于百米加速10秒）
                    const maxSpeedChange = timeSeconds * 10;
                    
                    if (Math.abs(rawSpeed - lastSpeed) > maxSpeedChange) {
                        // 速度变化超过限制，进行平滑处理
                        if (rawSpeed > lastSpeed) {
                            calculatedSpeed = Math.round(lastSpeed + maxSpeedChange);
                        } else {
                            calculatedSpeed = Math.round(Math.max(0, lastSpeed - maxSpeedChange));
                        }
                    } else {
                        calculatedSpeed = Math.round(rawSpeed);
                    }
                } else {
                    calculatedSpeed = 0; // 超出合理范围，设为0
                }
            }
        }
        
        // 特殊状态处理：充电或停车时速度强制为0
        if (currentChgStatus === '3' || (currentKeyStatus === '2' && currentMainLockStatus === '0')) {
            calculatedSpeed = 0;
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
        
        // 6. 插入数据点前，如果是空闲状态（没有行程或充电），先删除该VIN旧的空闲数据点
        if (!newDriveId && !newChargeId) {
            deleteOrphanedDataPointsForVin(vin);
        }
        
        // 7. 插入数据点（包含新字段）
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
            chgLeftTime: vehicleData.quickChgLeftTime || 0,
            calculated_speed_kmh: calculatedSpeed,
            drive_id: newDriveId,
            charge_id: newChargeId
        });
        
        // 8. 计算下次轮询时间（随机间隔，避免风控）
        let pollInterval;
        if (newInternalState === 'active') {
            pollInterval = getRandomInterval(POLL_INTERVAL_ACTIVE_MIN, POLL_INTERVAL_ACTIVE_MAX);
        } else {
            pollInterval = getRandomInterval(POLL_INTERVAL_IDLE_MIN, POLL_INTERVAL_IDLE_MAX);
        }
        
        const nextPollTime = new Date(Date.now() + pollInterval).toISOString().replace('T', ' ').substring(0, 19);
        
        // 9. 更新 vehicles 表
        updateVehicleAfterPoll(vin, {
            internal_state: newInternalState,
            next_poll_time: nextPollTime,
            last_keyStatus: currentKeyStatus,
            last_mainLockStatus: currentMainLockStatus,
            last_chgStatus: currentChgStatus,
            last_lat: currentLat,
            last_lon: currentLon,
            last_timestamp: currentTimestamp,
            last_total_mileage: currentTotalMileage,
            last_calculated_speed: calculatedSpeed,
            current_drive_id: newDriveId,
            current_charge_id: newChargeId
        });
        
    } catch (error) {
        console.error(`[Polling Service] ${vin} 轮询失败:`, error.message);
        
        // 错误处理
        let delayMilliseconds; // 使用毫秒单位
        let newState = 'error';
        
        if (error.message.includes('500') || error.message.includes('502')) {
            // 500/502 错误：根据当前状态决定重试策略
            if (internal_state === 'active') {
                // 激活状态：1-2分钟随机重试，保持active状态
                delayMilliseconds = getRandomInterval(60000, 120000);
                newState = 'active';
            } else {
                // 非激活状态：5分钟重试，改为error_500状态
                delayMilliseconds = 5 * 60 * 1000;
                newState = 'error_500';
            }
        } else if (error.message.includes('403') || error.message.includes('Authentication failure')) {
            // 403错误或认证失败：token失效，30天后重试
            delayMilliseconds = 43200 * 60 * 1000; // 30天
            newState = 'token_invalid';
        } else {
            // 其他错误：默认5分钟重试
            delayMilliseconds = 5 * 60 * 1000;
        }
        
        const nextPollTime = new Date(Date.now() + delayMilliseconds).toISOString().replace('T', ' ').substring(0, 19);
        
        updateVehicleAfterPoll(vin, {
            internal_state: newState,
            next_poll_time: nextPollTime
        });
        
        console.log(`[Polling Service] ${vin} 轮询失败 [${newState}] 下次: ${(delayMilliseconds/1000).toFixed(1)}秒后 (${nextPollTime})`);
    }
}

