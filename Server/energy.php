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

// 包含数据库连接
include __DIR__ . '/db_connect.php';

// 函数：获取车辆信息
function getVehicleData($vin, $timaToken, $baseApiUrl) {
    $url = $baseApiUrl . '/api/jac-energy/jacenergy/vehicleInformation/energy-query-vehicle-new-condition';
    $data = ['vins' => [$vin]];
    $headers = ['Content-Type: application/json', 'timaToken: ' . $timaToken];

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode === 200) {
        $result = json_decode($response, true);
        if ($result['returnSuccess']) {
            return $result['data'];
        }
    }
    return null;
}

// 函数：转换经纬度到地址
function getLocationFromLatLng($longitude, $latitude) {
    $apiKey = 'ad43794c805061ae25622bc72c8f4763';
    $url = "https://restapi.amap.com/v3/geocode/regeo?key={$apiKey}&location={$longitude},{$latitude}&radius=1000&extensions=base";

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

    $response = curl_exec($ch);
    curl_close($ch);

    $result = json_decode($response, true);
    if ($result['status'] === '1' && isset($result['regeocode']['formatted_address'])) {
        return $result['regeocode']['formatted_address'];
    }
    return '未知位置';
}

// 函数：处理行程记录
function handleTripRecord($vin, $operation, $vehicleData, $pdo) {
    // 操作: 2=开锁(开始), 1=关锁(结束)
    $now = date('Y-m-d H:i:s');
    $lat = $vehicleData['latitude'] ?? '';
    $lng = $vehicleData['longtitude'] ?? '';
    $location = getLocationFromLatLng($lng, $lat);
    $latlng = "{$lng},{$lat}";
    $totalMileage = (float)($vehicleData['totalMileage'] ?? 0);
    $acOnMile = (float)($vehicleData['acOnMile'] ?? 0);
    $soc = (int)($vehicleData['soc'] ?? 0);

    // 获取最后一条未完成的行程 (end_time IS NULL)
    $stmt = $pdo->prepare("SELECT * FROM trip_record WHERE vin = :vin AND end_time IS NULL ORDER BY start_time DESC LIMIT 1");
    $stmt->execute([':vin' => $vin]);
    $lastTrip = $stmt->fetch();

    if ($operation == 2) { // 开锁
        if ($lastTrip) {
            // 检查里程消耗(1公里以下抛弃)
            $mileageDiff = $totalMileage - $lastTrip['start_mileage'];
            if ($mileageDiff >= 1) {
                // 结束上次行程
                $updateStmt = $pdo->prepare("UPDATE trip_record SET end_time = :end_time, end_location = :end_location, end_latlng = :end_latlng, end_mileage = :end_mileage, end_range = :end_range, end_soc = :end_soc WHERE id = :id");
                $updateStmt->execute([
                    ':end_time' => $now,
                    ':end_location' => $location,
                    ':end_latlng' => $latlng,
                    ':end_mileage' => $totalMileage,
                    ':end_range' => $acOnMile,
                    ':end_soc' => $soc,
                    ':id' => $lastTrip['id']
                ]);
            } else {
                // 无消耗，删除无效行程
                $deleteStmt = $pdo->prepare("DELETE FROM trip_record WHERE id = :id");
                $deleteStmt->execute([':id' => $lastTrip['id']]);
            }
        }
        // 开始新行程
        $insertStmt = $pdo->prepare("INSERT INTO trip_record (vin, start_time, start_location, start_latlng, start_mileage, start_range, start_soc) VALUES (:vin, :start_time, :start_location, :start_latlng, :start_mileage, :start_range, :start_soc)");
        $insertStmt->execute([
            ':vin' => $vin,
            ':start_time' => $now,
            ':start_location' => $location,
            ':start_latlng' => $latlng,
            ':start_mileage' => $totalMileage,
            ':start_range' => $acOnMile,
            ':start_soc' => $soc
        ]);
    } elseif ($operation == 1) { // 关锁
        if ($lastTrip) {
            $mileageDiff = $totalMileage - $lastTrip['start_mileage'];
            if ($mileageDiff >= 1) {
                // 结束行程
                $updateStmt = $pdo->prepare("UPDATE trip_record SET end_time = :end_time, end_location = :end_location, end_latlng = :end_latlng, end_mileage = :end_mileage, end_range = :end_range, end_soc = :end_soc WHERE id = :id");
                $updateStmt->execute([
                    ':end_time' => $now,
                    ':end_location' => $location,
                    ':end_latlng' => $latlng,
                    ':end_mileage' => $totalMileage,
                    ':end_range' => $acOnMile,
                    ':end_soc' => $soc,
                    ':id' => $lastTrip['id']
                ]);
            } else {
                // 无消耗，删除
                $deleteStmt = $pdo->prepare("DELETE FROM trip_record WHERE id = :id");
                $deleteStmt->execute([':id' => $lastTrip['id']]);
            }
        }
        // 如果没有lastTrip，只有关锁，忽略
    }
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

// 解析第一次请求的响应
$responseData = json_decode($response, true);

// 如果第一次请求成功且包含operationId，则调用异步结果查询接口
if ($httpCode === 200 && $responseData && isset($responseData['operationId'])) {
    $operationId = $responseData['operationId'];
    
    // 调用异步结果查询接口
    $asyncUrl = $baseApiUrl . '/api/jac-energy/jacenergy/callBack/energy-vehicle-async-results';
    $asyncData = ['operationId' => $operationId];
    
    $asyncCh = curl_init();
    curl_setopt($asyncCh, CURLOPT_URL, $asyncUrl);
    curl_setopt($asyncCh, CURLOPT_POST, true);
    curl_setopt($asyncCh, CURLOPT_POSTFIELDS, json_encode($asyncData));
    curl_setopt($asyncCh, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($asyncCh, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'timaToken: ' . $input['timaToken']
    ]);
    curl_setopt($asyncCh, CURLOPT_TIMEOUT, 30);
    curl_setopt($asyncCh, CURLOPT_SSL_VERIFYPEER, false);
    
    $asyncResponse = curl_exec($asyncCh);
    $asyncHttpCode = curl_getinfo($asyncCh, CURLINFO_HTTP_CODE);
    $asyncError = curl_error($asyncCh);
    curl_close($asyncCh);
    
    if ($asyncError) {
        http_response_code(500);
        echo json_encode(['error' => 'Async query network error: ' . $asyncError]);
        exit;
    }
    
    if ($asyncHttpCode === 200) {
        $asyncResponseData = json_decode($asyncResponse, true);
        if ($asyncResponseData && isset($asyncResponseData['data'])) {
            // 删除data字段后返回
            unset($asyncResponseData['data']);
            http_response_code(200);
            // 数据有延迟，所以加个1秒看看
            sleep(1);
            echo json_encode($asyncResponseData);
        } else {
            http_response_code($asyncHttpCode);
            echo $asyncResponse;
        }
    } else {
        http_response_code($asyncHttpCode);
        echo $asyncResponse;
    }
} else {
    // 如果第一次请求失败或没有operationId，直接返回原始响应
    http_response_code($httpCode);
    echo $response;
}

// 如果是LOCK操作，处理行程记录
if ($input['operationType'] === 'LOCK') {
    $vehicleData = getVehicleData($input['vin'], $input['timaToken'], $baseApiUrl);
    if ($vehicleData) {
        handleTripRecord($input['vin'], $input['operation'], $vehicleData, $pdo);
    }
}
?>