// /www/wwwroot/pan3/api/auth/auth.controller.js

import { makeRequest, baseApiUrl } from '../../core/utils/request.js';
import { upsertVehicle, updateVehiclePushToken } from '../../core/database/operations.js';

/**
 * 用户登录处理函数
 * @param {object} req - Express的请求对象
 * @param {object} res - Express的响应对象
 */
export async function login(req, res) {
  try {
    // 1. 从Express的req.body中解析用户名和密码
    const { userCode, password } = req.body;

    if (!userCode || !password) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }

    // 2. 第一步：登录获取token (逻辑和云函数一致)
    const loginUrl = `${baseApiUrl}/api/jac-admin/admin/userBaseInformation/userLogin`;
    const loginPayload = { userType: '1', userCode, password };
    const loginResponse = await makeRequest(loginUrl, loginPayload);

    if (loginResponse.code !== 0) {
      const errorMsg = loginResponse.msg || '登录失败';
      return res.status(200).json({ code: loginResponse.code, message: errorMsg });
    }
    
    // (后续获取车辆信息的逻辑和云函数完全一致，直接复用)
    const loginData = loginResponse.data;
    const { token: timaToken, phone, id: userId, aaaid, aaaToken } = loginData;
    let userVehicles = [];
    const commonHeaders = { 'timaToken': timaToken, 'identityParam': JSON.stringify({ token: aaaToken }) };

    try {
      const vehicleListUrl = `${baseApiUrl}/api/jac-car-control/vehicle/find-vehicle-list`;
      const vehicleListPayload = { phone, userId, tspUserId: aaaid, aaaUserID: aaaid };
      const vehicleListResponse = await makeRequest(vehicleListUrl, vehicleListPayload, commonHeaders);
      if (vehicleListResponse.returnSuccess && vehicleListResponse.data?.length > 0) {
        userVehicles = vehicleListResponse.data;
      }
    } catch (e) {
      console.warn('调用车辆列表API时发生异常，尝试后备方案:', e.message);
    }
    
    if (userVehicles.length === 0) {
      try {
        const digitalKeyUrl = `${baseApiUrl}/api/bluetooth-control/public/digitalKey/getVehicleCode`;
        const digitalKeyPayload = { unitType: 'iPhone15,5' };
        const digitalKeyResponse = await makeRequest(digitalKeyUrl, digitalKeyPayload, commonHeaders);
        if (digitalKeyResponse.status === 'SUCCEED' && digitalKeyResponse.data?.length > 0) {
          userVehicles = [digitalKeyResponse.data[0]].map(v => ({...v, def:1, plateLicenseNo: '未设置车牌'}));
        }
      } catch (e) {
        console.warn('调用数字钥匙API时发生异常:', e.message);
      }
    }

    if (userVehicles.length === 0) {
      return res.status(200).json({ code: 404, message: '未找到绑定的车辆' });
    }
    
    // 3. 整合数据并使用res.json()返回
    const defaultVehicle = userVehicles.find(v => v.def == 1) || userVehicles[0];
    const finalResponseData = {
      code: 200,
      data: {
        vin: defaultVehicle.vin,
        token: timaToken,
        user: {
          userName: loginData.userName ?? '未设置用户名',
          headUrl: loginData.headUrl ?? 'https://upload.dreamforge.top/i/2025/07/16/fnitqt.jpeg',
          realPhone: loginData.realPhone,
          plateLicenseNo: defaultVehicle.plateLicenseNo ?? '未设置车牌',
          no: loginData.no ?? ''
        }
      }
    };

    // 4. 插入或更新车辆到数据库，启动轮询
    try {
      upsertVehicle(defaultVehicle.vin, timaToken);
      console.log(`[Auth] 车辆 ${defaultVehicle.vin} 已加入轮询队列`);
    } catch (dbError) {
      console.error('[Auth] 插入车辆到数据库失败:', dbError);
    }

    return res.status(200).json(finalResponseData);

  } catch (e) {
    console.error('登录函数执行异常:', e.message);
    return res.status(500).json({ code: 500, message: e.message });
  }
}

/**
 * 用户退出登录处理函数
 * @param {object} req - Express的请求对象
 * @param {object} res - Express的响应对象
 */
export async function logout(req, res) {
  try {
    // 1. 从Express的请求头和请求体中获取参数
    // 注意: Express会自动将请求头中的Key转为小写
    const timaToken = req.headers.timatoken;
    const { no } = req.body;

    if (!no || !timaToken) {
      return res.status(400).json({ error: 'Missing required parameters in body or headers' });
    }

    // 2. 调用JAC官方退出登录API (逻辑和云函数一致)
    const logoutUrl = `${baseApiUrl}/api/jac-admin/admin/userBaseInformation/userLoginOut`;
    const logoutData = { no };
    const logoutHeaders = { timaToken };
    const logoutResponse = await makeRequest(logoutUrl, logoutData, logoutHeaders);

    // 3. 根据返回结果，构造响应
    if (logoutResponse.code === 0) {
      // 不再删除车辆记录，只返回成功（数据继续保留）
      console.log('[Auth] 用户退出登录成功，车辆数据继续保留');
      return res.status(200).json({ code: 200, message: '退出登录成功' });
    } else {
      const errorMsg = logoutResponse.msg || '退出登录失败';
      return res.status(200).json({ code: logoutResponse.code, message: errorMsg });
    }
  } catch (e) {
    console.error('退出登录函数执行异常:', e.message);
    return res.status(500).json({ code: 500, message: e.message });
  }
}

/**
 * 更新推送 Token
 * @param {object} req - Express的请求对象
 * @param {object} res - Express的响应对象
 */
export async function updatePushToken(req, res) {
  try {
    const timaToken = req.headers.timatoken;
    const { vin, pushToken } = req.body;

    // 参数验证
    if (!vin || !pushToken) {
      return res.status(400).json({ 
        code: 400, 
        message: '缺少必要参数: vin, pushToken' 
      });
    }

    // 更新推送 Token
    try {
      updateVehiclePushToken(vin, pushToken);
      console.log(`[Auth] 车辆 ${vin} 推送 Token 已更新`);
      
      return res.status(200).json({ 
        code: 200, 
        message: '推送 Token 更新成功',
        data: { vin }
      });
    } catch (dbError) {
      console.error('[Auth] 更新推送 Token 失败:', dbError);
      return res.status(500).json({ 
        code: 500, 
        message: '更新推送 Token 失败' 
      });
    }

  } catch (e) {
    console.error('更新推送 Token 异常:', e.message);
    return res.status(500).json({ code: 500, message: e.message });
  }
}