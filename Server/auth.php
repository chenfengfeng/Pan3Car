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

$rawInput = file_get_contents('php://input');

$input = json_decode($rawInput, true);
if (json_last_error() !== JSON_ERROR_NONE) {
    $jsonError = json_last_error_msg();
    http_response_code(400);
    logMessage('JSON解析失败: ' . $jsonError, 'ERROR');
    echo json_encode(['error' => 'Invalid JSON format: ' . $jsonError]);
    exit;
}

$userCode = $input['userCode'] ?? null;
$password = $input['password'] ?? null;
$server = $input['server'] ?? '';

if (!isset($userCode) || !isset($password)) {
    http_response_code(400);
    logMessage('缺少必需参数', 'ERROR');
    echo json_encode(['error' => 'Missing required parameters']);
    exit;
}

// 根据server参数选择API基础地址
$baseApiUrl = ($server === 'spare') ? 'https://yiweiauto.cn' : 'https://jacsupperapp.jac.com.cn';

// 日志函数 - 支持文件存储
function logMessage($message, $level = 'INFO') {
    $logDir = __DIR__ . '/logs';
    $logFile = $logDir . '/auth_' . date('Y-m-d') . '.log';
    
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
    $requestData = json_encode($data);
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $requestData);
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
        logMessage('网络错误: ' . $error, 'ERROR');
        throw new Exception('Network error: ' . $error);
    }
    
    if ($httpCode !== 200) {
        logMessage('HTTP错误，状态码: ' . $httpCode . '，响应: ' . substr($response, 0, 200), 'ERROR');
        throw new Exception('HTTP error: ' . $httpCode . ', Response: ' . $response);
    }
    
    $decodedResponse = json_decode($response, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        $jsonError = json_last_error_msg();
        logMessage('响应JSON解析失败: ' . $jsonError . '，响应前200字符: ' . substr($response, 0, 200), 'ERROR');
        throw new Exception('Response JSON decode error: ' . $jsonError);
    }
    
    return $decodedResponse;
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
        $errorMsg = $loginResponse['msg'] ?? '登录失败';
        $responseData = [
            'code' => $loginResponse['code'],
            'message' => $errorMsg
        ];
        echo json_encode($responseData);
        logMessage('登录失败 - 错误码: ' . $loginResponse['code'] . ', 错误信息: ' . $errorMsg, 'ERROR');
        exit;
    }
    
    $loginData = $loginResponse['data'];
    $timaToken = $loginData['token'];
    $phone = $loginData['phone'];
    $identityType = $loginData['identityType'] ?? 0;

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
        } else {
            logMessage('车辆列表API调用失败，完整响应: ' . json_encode($userInfoResponse, JSON_UNESCAPED_UNICODE), 'ERROR');
        }
    } catch (Exception $e) {
        logMessage('车辆列表API请求异常: ' . $e->getMessage(), 'ERROR');
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
                    'plateLicenseNo' => '未设置车牌'
                ]];
            } else {
                logMessage('授权号API调用失败，完整响应: ' . json_encode($vehicleCodeResponse, JSON_UNESCAPED_UNICODE), 'ERROR');
            }
        } catch (Exception $e) {
            logMessage('授权号API请求异常: ' . $e->getMessage(), 'ERROR');
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
                'plateLicenseNo' => $defaultVehicle['plateLicenseNo'] ?? '未设置车牌',
                'no' => $loginData['no'] ?? ''
            ]
        ]
    ];
    
    echo json_encode($responseData);
    
} catch (Exception $e) {
    $errorMessage = $e->getMessage();
    $errorTrace = $e->getTraceAsString();
    
    $responseData = [
        'code' => 500,
        'message' => $errorMessage
    ];
    
    echo json_encode($responseData);
    logMessage('接口异常: ' . $errorMessage, 'ERROR');
    logMessage('异常堆栈: ' . $errorTrace, 'ERROR');
}
?>