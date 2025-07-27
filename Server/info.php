<?php
// 车辆信息获取接口 - Vehicle Information API
// 此接口用于获取车辆详细信息

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, timaToken');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$server = $input['server'] ?? '';

if (!isset($input['vin'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing required parameter: vin']);
    exit;
}

// 根据server参数选择API基础地址
$baseApiUrl = ($server === 'spare') ? 'https://yiweiauto.cn' : 'https://jacsupperapp.jac.com.cn';
logMessage('使用服务器: ' . ($server === 'spare' ? '备用服务器' : '主服务器') . ' - ' . $baseApiUrl, 'INFO');

// 从请求头获取timaToken
$headers = getallheaders();
$timaToken = $input['timaToken'] ?? '';

if (!$timaToken) {
    http_response_code(401);
    logMessage('Missing timaToken in headers');
    echo json_encode(['error' => 'Missing timaToken in headers']);
    exit;
}

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
    // 获取车辆详细信息
    $carInfoUrl = $baseApiUrl . '/api/jac-energy/jacenergy/vehicleInformation/energy-query-vehicle-new-condition';
    $carInfoData = [
        'vins' => [$input['vin']]
    ];
    
    $carInfoHeaders = [
        'timaToken: ' . $timaToken
    ];
    
    $carInfoResponse = makeRequest($carInfoUrl, $carInfoData, $carInfoHeaders);
    $code = $carInfoResponse['code'] ?? 200;
    
    if ($code == 403) {
        http_response_code(403);
        echo json_encode([
            'code' => 403,
            'message' => 'Authentication failure'
        ]);
        logMessage('Authentication failure');
        exit;
    }
    
    if (!$carInfoResponse['returnSuccess']) {
        http_response_code(500);
        echo json_encode([
            'code' => 500,
            'message' => 'Failed to get car info'
        ]);
        logMessage('Failed to get car info');
        exit;
    }

    // 接口返回数据示例
//     {
//   "operationId": 3069156,
//   "returnErrCode": null,
//   "returnSuccess": true,
//   "returnErrMsg": null,
//   "data": {
//     "doorStsRearRight": 0,
//     "keyStatus": 2,
//     "defrostStatus": 0,
//     "soc": "64",
//     "quickChgLeftTime": 327670,
//     "rfTirePresure": 0,
//     "latitude": "30.89352189668428",
//     "chgPlugStatus": 1,
//     "topWindowOpen": 0,
//     "longtitude": "103.62002502212343",
//     "acOnMile": 211,
//     "quickcoolACStatus": null,
//     "doorStsFrontRight": 0,
//     "totalMileage": "9006.0",
//     "lowlightStatus": 0,
//     "lfWindowOpen": 0,
//     "doorStsRearLeft": 0,
//     "lrTirePresure": 0,
//     "quickheatACStatus": 0,
//     "lrWindowOpen": 0,
//     "lfTirePresure": 0,
//     "rfWindowOpen": 0,
//     "doorsLockStatus": null,
//     "highlightStatus": 0,
//     "mainLockStatus": 0,
//     "trunkLockStatus": 0,
//     "doorStsFrontLeft": 0,
//     "temperatureInCar": 214,
//     "chgStatus": 2,
//     "slowChgLeftTime": 327670,
//     "batteryHeatStatus": 3,
//     "acStatus": 2,
//     "acOffMile": 211,
//     "rrWindowOpen": 0,
//     "rrTirePresure": 0
//   },
//   "message": null,
//   "jobId": null,
//   "jobs": null,
//   "requestId": null,
//   "status": null,
//   "body": null
// }

    // 返回车辆信息
    $responseData = [
        'code' => 200,
        'data' => $carInfoResponse['data']
    ];
    
    echo json_encode($responseData);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'code' => 500,
        'message' => $e->getMessage()
    ]);
}
?>