<?php
// 设备控制接口 - Device Control API
// 此接口用于统一的设备控制功能，支持多种操作类型

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
$headers = getallheaders();
$server = $input['server'] ?? '';

if (!isset($input['vin']) || !isset($input['operationType']) || !isset($input['timaToken'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing required parameters']);
    exit;
}

// 根据server参数选择API基础地址
$baseApiUrl = ($server === 'spare') ? 'https://yiweiauto.cn' : 'https://jacsupperapp.jac.com.cn';

// 验证操作类型
$allowedOperations = ['FIND_VEHICLE', 'LOCK', 'WINDOW', 'INTELLIGENT_AIRCONDITIONER'];
if (!in_array($input['operationType'], $allowedOperations)) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid operation type']);
    exit;
}

// 转发到原始API
$targetUrl = $baseApiUrl . '/api/jac-energy/jacenergy/vehicleControl/energy-remote-vehicle-control';

// 构建基础参数
$postData = [
    'vin' => $input['vin'],
    'operationType' => $input['operationType']
];

// 根据操作类型添加特定参数
switch ($input['operationType']) {
    case 'FIND_VEHICLE':
        // 寻车鸣笛
        $postData['operation'] = 1;
        break;
        
    case 'LOCK':
        // 车锁控制
        if (!isset($input['operation'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing operation parameter for LOCK']);
            exit;
        }
        $postData['operation'] = $input['operation']; // 1=锁定, 2=解锁
        break;
        
    case 'WINDOW':
        // 车窗控制
        if (!isset($input['operation'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing operation parameter for WINDOW']);
            exit;
        }
        $postData['operation'] = $input['operation']; // 1=关闭, 2=开启
        $postData['extParams'] = [
            'openLevel' => isset($input['openLevel']) ? $input['openLevel'] : ($input['operation'] == 2 ? 2 : 0)
        ];
        break;
        
    case 'INTELLIGENT_AIRCONDITIONER':
        // 空调控制
        if (!isset($input['operation'])) {
            http_response_code(400);
            echo json_encode(['error' => 'Missing operation parameter for AIRCONDITIONER']);
            exit;
        }
        $postData['operation'] = $input['operation']; // 1=关闭, 2=开启
        $postData['extParams'] = [
            'temperature' => isset($input['temperature']) ? $input['temperature'] : 26,
            'duringTime' => isset($input['duringTime']) ? $input['duringTime'] : 30
        ];
        break;
}

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $targetUrl);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($postData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'timaToken: ' . $input['timaToken']
]);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

if ($error) {
    http_response_code(500);
    echo json_encode(['error' => 'Network error: ' . $error]);
    exit;
}

http_response_code($httpCode);
echo $response;
?>