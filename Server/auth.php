<?php
// 用户认证接口 - User Authentication API
// 此接口用于用户身份验证，整合登录、用户信息

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    logMessage('Method not allowed', 'ERROR');
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$userCode = $input['userCode'];
$password = $input['password'];
$server = $input['server'] ?? '';

if (!isset($userCode) || !isset($password)) {
    http_response_code(400);
    logMessage('Missing required parameters', 'ERROR');
    echo json_encode(['error' => 'Missing required parameters']);
    exit;
}

// 根据server参数选择API基础地址
$baseApiUrl = ($server === 'spare') ? 'https://yiweiauto.cn' : 'https://jacsupperapp.jac.com.cn';
logMessage('使用服务器: ' . ($server === 'spare' ? '备用服务器' : '主服务器') . ' - ' . $baseApiUrl, 'INFO');

// 日志函数 - 支持文件存储
function logMessage($message, $level = 'INFO') {
    $logDir = __DIR__ . '/logs';
    $logFile = $logDir . '/charge_' . date('Y-m-d') . '.log';
    
    // 确保日志目录存在
    if (!is_dir($logDir)) {
        mkdir($logDir, 0755, true);
    }
    
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[{$timestamp}] [{$level}] {$message}" . PHP_EOL;
    
    // 只写入文件，不输出到终端（避免破坏JSON响应）
    file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);
}

function makeRequest($url, $data, $headers = []) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, array_merge([
        'Content-Type: application/json'
    ], $headers));
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    
    if ($error) {
        throw new Exception('Network error: ' . $error);
    }
    
    if ($httpCode !== 200) {
        throw new Exception('HTTP error: ' . $httpCode);
    }
    
    return json_decode($response, true);
}

try {
    // 第一步：登录获取token
    $loginUrl = $baseApiUrl . '/api/jac-admin/admin/userBaseInformation/userLogin';
    $loginData = [
        'userType' => '1',
        'userCode' => $userCode,
        'password' => $password
    ];
    
    $loginResponse = makeRequest($loginUrl, $loginData);
    
    if ($loginResponse['code'] !== 0) {
        echo json_encode([
            'code' => $loginResponse['code'],
            'message' => $loginResponse['msg'] ?? '登录失败'
        ]);
        logMessage('登录失败: ' . $loginResponse['msg'], 'ERROR');
        exit;
    }
    
    $loginData = $loginResponse['data'];
    $timaToken = $loginData['token'];
    $phone = $loginData['phone'];
    $identityType = $loginData['identityType'] ?? 0;
    
    logMessage('登录成功: ' . $phone . ', identityType: ' . $identityType, 'INFO');

    // 第二步：获取用户车辆信息（先尝试车辆列表API，失败后再尝试授权号API）
    $identityParam = [
        'token' => $loginData['aaaToken']
    ];
    
    $headers = [
        'timaToken: ' . $timaToken,
        'identityParam: ' . json_encode($identityParam)
    ];
    
    $userVehicles = [];
    
    // 第一次尝试：使用车辆列表API
    try {
        $userInfoUrl = $baseApiUrl . '/api/jac-car-control/vehicle/find-vehicle-list';
        $userInfoData = [
            'phone' => $phone,
            'userId' => $loginData['id'],
            'tspUserId' => $loginData['aaaid'],
            'aaaUserID' => $loginData['aaaid']
        ];
        
        $userInfoResponse = makeRequest($userInfoUrl, $userInfoData, $headers);
        
        if ($userInfoResponse['returnSuccess'] && !empty($userInfoResponse['data'])) {
            $userVehicles = $userInfoResponse['data'];
            logMessage('通过车辆列表API获取到车辆信息: ' . json_encode($userVehicles), 'INFO');
        } else {
            logMessage('车辆列表API调用失败或无数据: ' . ($userInfoResponse['returnErrMsg'] ?? '无数据'), 'WARNING');
        }
    } catch (Exception $e) {
        logMessage('车辆列表API请求异常: ' . $e->getMessage(), 'WARNING');
    }
    
    // 如果车辆列表API没有获取到数据，尝试授权号API
    if (empty($userVehicles)) {
        try {
            $vehicleCodeUrl = $baseApiUrl . '/api/bluetooth-control/public/digitalKey/getVehicleCode';
            $vehicleCodeData = [
                'unitType' => 'iPhone15,5'
            ];
            
            $vehicleCodeResponse = makeRequest($vehicleCodeUrl, $vehicleCodeData, $headers);
            
            if ($vehicleCodeResponse['status'] === 'SUCCEED' && !empty($vehicleCodeResponse['data'])) {
                // 从授权号API获取到车辆信息，构造车辆数据
                $vehicleData = $vehicleCodeResponse['data'][0];
                $userVehicles = [[
                    'vin' => $vehicleData['vin'],
                    'vehicleCode' => $vehicleData['vehicleCode'],
                    'dataHash' => $vehicleData['dataHash'],
                    'def' => 1,
                    'plateLicenseNo' => '电A88888'
                ]];
                logMessage('通过授权号API获取到车辆信息: ' . json_encode($userVehicles), 'INFO');
            } else {
                logMessage('授权号API调用失败或无数据: ' . ($vehicleCodeResponse['message'] ?? '无数据'), 'WARNING');
            }
        } catch (Exception $e) {
            logMessage('授权号API请求异常: ' . $e->getMessage(), 'WARNING');
        }
    }
    
    // 检查是否获取到车辆信息
    if (empty($userVehicles)) {
        echo json_encode([
            'code' => 404,
            'message' => '未找到绑定的车辆'
        ]);
        logMessage('未找到绑定的车辆', 'ERROR');
        exit;
    }

    logMessage('获取到用户车辆信息: ' . json_encode($userVehicles), 'INFO');
    
    // 获取默认车辆（第一个或def=1的车辆）
    $defaultVehicle = null;
    foreach ($userVehicles as $vehicle) {
        if ($vehicle['def'] == 1) {
            $defaultVehicle = $vehicle;
            break;
        }
    }
    if (!$defaultVehicle) {
        $defaultVehicle = $userVehicles[0];
    }
    
    $vin = $defaultVehicle['vin'];
    
    // 整合返回数据
    $responseData = [
        'code' => 200,
        'data' => [
            'vin' => $vin,
            'token' => $timaToken,
            'user' => [
                'userName' => $loginData['userName'] ?? '未设置用户名',
                'headUrl' => $loginData['headUrl'] ?? 'https://upload.dreamforge.top/i/2025/07/16/fnitqt.jpeg',
                'realPhone' => $loginData['realPhone'],
                'plateLicenseNo' => $defaultVehicle['plateLicenseNo'] ?? '电A88888',
                'no' => $loginData['no'] ?? ''
            ]
        ]
    ];
    
    logMessage('返回数据: ' . json_encode($responseData), 'INFO');
    echo json_encode($responseData);
    
} catch (Exception $e) {
    echo json_encode([
        'code' => 500,
        'message' => $e->getMessage()
    ]);
    logMessage('接口出错了:'.$e->getMessage());
}
?>