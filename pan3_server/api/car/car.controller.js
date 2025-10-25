// /www/wwwroot/pan3/api/car/car.controller.js

import { makeRequest, baseApiUrl } from '../../core/utils/request.js';
import { execFile } from 'child_process'; // <-- 引入Node.js内置的子进程模块
import path from 'path'; // <-- 引入Node.js内置的路径处理模块

const TASKS_FILE_PATH = path.join(process.cwd(), 'charge_tasks.json');

/**
 * 获取车辆信息的接口 - 纯查询功能，不主动推送
 */
export async function getVehicleInfo(req, res) {
    try {
        const timaToken = req.headers.timatoken;
        const { vin } = req.body; // 移除pushToken参数，保持接口纯净
        if (!vin || !timaToken) {
            return res.status(400).json({ code: 400, message: 'Missing required parameters' });
        }
        const targetUrl = `${baseApiUrl}/api/jac-energy/jacenergy/vehicleInformation/energy-query-vehicle-new-condition`;
        const jacPayload = { vins: [vin] };
        const jacHeaders = { 'Content-Type': 'application/json', 'timaToken': timaToken };
        const jacResponse = await fetch(targetUrl, { method: 'POST', headers: jacHeaders, body: JSON.stringify(jacPayload) });
        const jacBodyText = await jacResponse.text();
        if (!jacResponse.ok) { return res.status(jacResponse.status).json({ code: jacResponse.status, message: 'Upstream API HTTP error' }); }
        const jacData = JSON.parse(jacBodyText);
        if (jacData.returnSuccess && jacData.data) {
            return res.status(200).json({ code: 200, message: '获取车辆信息成功', data: jacData.data });
        } else {
            const errorMessage = jacData.msg || jacData.returnErrorMsg || '获取车辆信息失败，但未提供明确原因';
            const errorCode = jacData.code || jacData.returnErrorCode || 5001;
            return res.status(200).json({ code: errorCode, message: errorMessage, data: null });
        }
    } catch (e) {
        res.status(500).json({ code: 500, message: `Function error: ${e.message}` });
    }
}


/**
 * 停止充电接口
 */
export async function stopCharging(req, res) {
    try {
        const timaToken = req.headers.timatoken;
        const { vin } = req.body;

        // 参数验证
        if (!vin || !timaToken) {
            return res.status(400).json({ 
                code: 400, 
                message: '缺少必要参数 (vin, timaToken)' 
            });
        }

        console.log(`[停止充电] - VIN: ${vin} - 开始执行停止充电操作...`);

        // 构建停止充电的请求数据
        const postData = {
            operation: 1,
            extParams: {
                bookTime: 0
            },
            vin: vin,
            operationType: 'RESERVATION_RECHARGE'
        };

        const jacHeaders = { timaToken };
        const controlUrl = `${baseApiUrl}/api/jac-energy/jacenergy/vehicleControl/energy-remote-vehicle-control`;
        
        // 发送停止充电指令
        const initialResponse = await makeRequest(controlUrl, postData, jacHeaders);

        if (!initialResponse || !initialResponse.operationId) {
            console.error(`[停止充电] - VIN: ${vin} - 发送停止充电指令失败`, initialResponse);
            return res.status(200).json(initialResponse || { 
                code: 5003, 
                message: '停止充电指令发送失败，未收到operationId' 
            });
        }

        // 检查异步操作状态
        const asyncUrl = `${baseApiUrl}/api/jac-energy/jacenergy/callBack/energy-vehicle-async-results`;
        const asyncData = { operationId: initialResponse.operationId };
        const asyncResponse = await makeRequest(asyncUrl, asyncData, jacHeaders);
        
        if (!asyncResponse || asyncResponse.returnSuccess !== true) {
            console.error(`[停止充电] - VIN: ${vin} - 停止充电状态确认失败`, asyncResponse);
            return res.status(200).json(asyncResponse || { 
                code: 5004, 
                message: '停止充电指令状态确认失败' 
            });
        }
        
        console.log(`[停止充电] - VIN: ${vin} - 停止充电操作成功`);
        
        return res.status(200).json({
            code: 200,
            message: '停止充电操作成功',
            data: asyncResponse
        });

    } catch (error) {
        console.error(`[停止充电] - 接口异常:`, error.message);
        res.status(500).json({ 
            code: 500, 
            message: `停止充电操作失败: ${error.message}` 
        });
    }
}

export async function controlVehicle(req, res) {
    try {
        const timaToken = req.headers.timatoken;
        const input = req.body;
        // 确保从 input 中解构出 operation
        const { vin, operationType, pushToken, operation } = input;

        // 参数验证 (增加了对 operation 的验证)
        if (!vin || !operationType || !timaToken || operation === undefined) {
            return res.status(400).json({ error: 'Missing required parameters (vin, operationType, timaToken, operation)' });
        }

        // --- 步骤一: 执行“快速检查” (这部分逻辑不变) ---
        console.log(`[Quick Check] - VIN: ${vin} - Operation: ${operationType} - Starting...`);
        let postData = { vin, operationType, operation }; // 将 operation 直接加入 postData
        switch (operationType) {
            case 'WINDOW':
                postData.extParams = { openLevel: input.openLevel || (operation == 2 ? 2 : 0) };
                break;
            case 'INTELLIGENT_AIRCONDITIONER':
                postData.extParams = { temperature: input.temperature || 26, duringTime: input.duringTime || 30 };
                break;
        }

        const jacHeaders = { timaToken };
        const controlUrl = `${baseApiUrl}/api/jac-energy/jacenergy/vehicleControl/energy-remote-vehicle-control`;
        const initialResponse = await makeRequest(controlUrl, postData, jacHeaders);

        if (!initialResponse || !initialResponse.operationId) {
            console.error(`[Quick Check] - VIN: ${vin} - FAILED at step 1 (control command).`, initialResponse);
            return res.status(200).json(initialResponse || { code: 5003, message: '控制指令发送失败，未收到operationId' });
        }

        const asyncUrl = `${baseApiUrl}/api/jac-energy/jacenergy/callBack/energy-vehicle-async-results`;
        const asyncData = { operationId: initialResponse.operationId };
        const asyncResponse = await makeRequest(asyncUrl, asyncData, jacHeaders);
        
        if (!asyncResponse || asyncResponse.returnSuccess !== true) {
            console.error(`[Quick Check] - VIN: ${vin} - FAILED at step 2 (async status check).`, asyncResponse);
            return res.status(200).json(asyncResponse || { code: 5004, message: '指令状态确认失败' });
        }
        
        console.log(`[Quick Check] - VIN: ${vin} - SUCCESS. Command accepted by upstream.`);

        // --- 步骤二: 启动后台CLI任务
        if (pushToken && pushToken !== "") {
            console.log(`[CLI] - VIN: ${vin} - 开始后台任务...`);
            
            // 将脚本文件名更新为您修改后的名字
            const scriptPath = path.join(process.cwd(), 'cli', 'tasks', 'vehicle-control-workflow.js');
            
            const scriptArgs = [vin, timaToken, pushToken, operationType, operation];

            execFile('node', [scriptPath, ...scriptArgs], (error, stdout, stderr) => {
                if (error) { 
                    console.error(`[CLI] - VIN: ${vin} - Error:`, error); 
                    return; 
                }
                if (stdout) {
                    console.log(`[CLI] - VIN: ${vin} - STDOUT:\n${stdout}`);
                }
                if (stderr) { 
                    console.error(`[CLI] - VIN: ${vin} - STDERR:\n${stderr}`); 
                }
                console.log(`[CLI] - VIN: ${vin} - 子进程已完成`);
            });

            return res.status(200).json({ 
                code: 200, 
                message: '操作已受理，后台将确认最终状态并推送通知'
            });
        } else {
            return res.status(200).json(asyncResponse);
        }

    } catch (e) {
        console.error('控制车辆接口异常:', e.message);
        res.status(500).json({ code: 500, message: `Function error: ${e.message}` });
    }
}