<?php
// 车辆信息查询共享函数库 - Vehicle Information API Library
// 此库提供统一的车辆信息查询功能，供多个模块使用

// 设置错误报告级别
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// 设置时区
date_default_timezone_set('Asia/Shanghai');

// 配置常量
define('VEHICLE_API_TIMEOUT', 30); // API超时时间（秒）
define('VEHICLE_API_CONNECT_TIMEOUT', 10); // API连接超时时间（秒）

/**
 * 日志函数 - 支持文件存储
 * @param string $message 日志消息
 * @param string $level 日志级别
 * @param bool $outputToTerminal 是否输出到终端（CLI模式使用）
 */
function vehicleApiLogMessage($message, $level = 'INFO', $outputToTerminal = false)
{
    $logDir = __DIR__ . '/logs';
    $logFile = $logDir . '/vehicle_api_' . date('Y-m-d') . '.log';

    // 确保日志目录存在
    if (!is_dir($logDir)) {
        mkdir($logDir, 0755, true);
    }

    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[{$timestamp}] [{$level}] {$message}" . PHP_EOL;

    // 写入文件
    file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);

    // 根据需要输出到终端（CLI模式）
    if ($outputToTerminal) {
        echo $logEntry;
    }
}

/**
 * 统一的车辆信息查询函数
 * @param string $vin 车辆VIN码
 * @param string $token 认证令牌
 * @param string $server 服务器类型 ('main' 或 'spare')
 * @param bool $isCliMode 是否为CLI模式（影响日志输出）
 * @return array 返回格式: ['success' => bool, 'data' => array|null, 'error' => string|null, 'code' => int|null]
 */
function getVehicleInformation($vin, $token, $server = 'main', $isCliMode = false)
{
    // 参数验证
    if (empty($vin) || empty($token)) {
        $error = '缺少必需参数: vin 或 token';
        vehicleApiLogMessage($error, 'ERROR', $isCliMode);
        return ['success' => false, 'data' => null, 'error' => $error, 'code' => 400];
    }

    // 根据server参数选择API基础地址
    $baseApiUrl = ($server === 'spare') ? 'https://yiweiauto.cn' : 'https://jacsupperapp.jac.com.cn';
    $url = $baseApiUrl . '/api/jac-energy/jacenergy/vehicleInformation/energy-query-vehicle-new-condition';

    // 构建请求数据
    $data = [
        'vins' => [$vin]
    ];

    // 构建请求头
    $headers = [
        'Content-Type: application/json',
        'timaToken: ' . $token,
        'User-Agent: PHP-VehicleAPI/1.0'
    ];

    // 初始化cURL
    $ch = curl_init();

    // 使用现代cURL配置和安全设置
    $jsonData = json_encode($data);
    if ($jsonData === false) {
        $errorMsg = 'JSON编码错误: ' . json_last_error_msg();
        vehicleApiLogMessage($errorMsg, 'ERROR', $isCliMode);
        return ['success' => false, 'data' => null, 'error' => $errorMsg, 'code' => 500];
    }
    
    $curlOptions = [
        CURLOPT_URL => $url,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $jsonData,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => VEHICLE_API_TIMEOUT,
        CURLOPT_CONNECTTIMEOUT => VEHICLE_API_CONNECT_TIMEOUT,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_FOLLOWLOCATION => false,
        CURLOPT_MAXREDIRS => 0,
        CURLOPT_ENCODING => '', // 支持所有编码
    ];
    
    // 检查是否支持HTTP/2
    if (defined('CURL_HTTP_VERSION_2_0')) {
        $curlOptions[CURLOPT_HTTP_VERSION] = CURL_HTTP_VERSION_2_0;
    }

    curl_setopt_array($ch, $curlOptions);

    // 执行请求
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    $totalTime = curl_getinfo($ch, CURLINFO_TOTAL_TIME);
    curl_close($ch);

    // 检查cURL错误
    if ($error) {
        $errorMsg = 'CURL错误: ' . $error;
        vehicleApiLogMessage($errorMsg, 'ERROR', $isCliMode);
        return ['success' => false, 'data' => null, 'error' => $errorMsg, 'code' => 500];
    }

    // 检查HTTP状态码
    if ($httpCode !== 200) {
        $errorMsg = "HTTP错误: {$httpCode}";
        vehicleApiLogMessage($errorMsg, 'ERROR', $isCliMode);
        return ['success' => false, 'data' => null, 'error' => $errorMsg, 'code' => $httpCode];
    }

    // 解析JSON响应
    $result = json_decode($response, true, 512);
    if (json_last_error() !== JSON_ERROR_NONE) {
        $errorMsg = 'JSON解析错误: ' . json_last_error_msg();
        vehicleApiLogMessage($errorMsg, 'ERROR', $isCliMode);
        return ['success' => false, 'data' => null, 'error' => $errorMsg, 'code' => 500];
    }

    // 检查API返回的认证状态
    $code = $result['code'] ?? 200;
    if ($code == 403) {
        $errorMsg = '认证失败，返回403';
        vehicleApiLogMessage($errorMsg, 'ERROR', $isCliMode);
        return ['success' => false, 'data' => null, 'error' => 'Authentication failure', 'code' => 403];
    }

    // 检查API返回的成功状态
    if (!isset($result['returnSuccess']) || !$result['returnSuccess']) {
        $errorMsg = $result['returnErrMsg'] ?? '未知错误';
        vehicleApiLogMessage("API返回错误: {$errorMsg}", 'ERROR', $isCliMode);
        return ['success' => false, 'data' => null, 'error' => "API返回错误: {$errorMsg}", 'code' => 500];
    }

    // 成功返回数据
    vehicleApiLogMessage("API调用成功，耗时: {$totalTime}秒", 'DEBUG', $isCliMode);
    
    // 自动处理行程记录（基于车辆信息同步）
    if (isset($result['data']) && is_array($result['data']) && count($result['data']) > 0) {
        $vehicleData = $result['data'][0]; // 获取第一个车辆的数据
        if (isset($vehicleData['vin'])) {
            handleTripRecordByVehicleInfo($vehicleData['vin'], $vehicleData, $isCliMode);
        }
    }
    
    return [
        'success' => true,
        'data' => $result['data'],
        'error' => null,
        'code' => 200
    ];
}

/**
 * 为CLI模式优化的车辆信息查询函数
 * 兼容原有的 cli_charge.php 中的 getVehicleInfo 函数
 * @param string $vin 车辆VIN码
 * @param string $token 认证令牌
 * @return array 返回格式: ['success' => bool, 'data' => array|null, 'error' => string|null]
 */
function getVehicleInfoForCLI($vin, $token)
{
    $result = getVehicleInformation($vin, $token, 'main', true);
    
    // 转换为CLI模式期望的格式
    return [
        'success' => $result['success'],
        'data' => $result['data'],
        'error' => $result['error']
    ];
}

/**
 * 为Web API模式优化的车辆信息查询函数
 * 兼容原有的 info.php 的使用方式
 * @param string $vin 车辆VIN码
 * @param string $token 认证令牌
 * @param string $server 服务器类型
 * @return array 返回格式: ['success' => bool, 'data' => array|null, 'error' => string|null, 'code' => int]
 */
function getVehicleInfoForWeb($vin, $token, $server = 'main')
{
    return getVehicleInformation($vin, $token, $server, false);
}

/**
 * 转换经纬度到地址
 * @param float $longitude 经度
 * @param float $latitude 纬度
 * @return string 地址信息
 */
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





/**
 * 简化的行程记录处理函数 - 基于车辆信息同步自动处理
 * 通过比较车辆状态变化来判断是否需要记录行程，避免频繁操作
 * @param string $vin 车辆VIN码
 * @param array $vehicleData 当前车辆数据
 * @param bool $isCliMode 是否为CLI模式
 */
function handleTripRecordByVehicleInfo($vin, $vehicleData, $isCliMode = false) {
    // 获取数据库连接
    require_once __DIR__ . '/db_connect.php';
    
    try {
        $pdo = getDbConnection();
        
        $now = date('Y-m-d H:i:s');
        $lat = $vehicleData['latitude'] ?? '';
        $lng = $vehicleData['longtitude'] ?? '';
        $location = getLocationFromLatLng($lng, $lat);
        $latlng = "{$lng},{$lat}";
        $totalMileage = (float)($vehicleData['totalMileage'] ?? 0);
        $acOnMile = (float)($vehicleData['acOnMile'] ?? 0);
        $soc = (int)($vehicleData['soc'] ?? 0);
        $mainLockStatus = (int)($vehicleData['mainLockStatus'] ?? 0);
        $chargingStatus = (int)($vehicleData['chargingStatus'] ?? 0); // 0:未充电, 1:充电中
        
        // 记录日志
        $logMessage = "简化行程记录处理 - VIN: {$vin}, 锁状态: {$mainLockStatus}, 充电状态: {$chargingStatus}";
        vehicleApiLogMessage($logMessage, 'INFO', $isCliMode);
        
        // 获取最后一条未完成的行程记录
        $stmt = $pdo->prepare("SELECT * FROM trip_record WHERE vin = :vin AND end_time IS NULL ORDER BY start_time DESC LIMIT 1");
        $stmt->execute([':vin' => $vin]);
        $lastTrip = $stmt->fetch();
        
        // 核心逻辑：基于解锁状态判断行程记录
        if ($mainLockStatus === 0) { // 解锁状态 - 可能需要开始行程
            if (!$lastTrip) {
                // 没有未完成行程且车辆解锁，开始新行程
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
                vehicleApiLogMessage("车辆解锁：开始新行程", 'INFO', $isCliMode);
            } else {
                // 已有未完成行程，检查是否需要更新（避免频繁操作）
                $timeDiff = strtotime($now) - strtotime($lastTrip['start_time']);
                if ($timeDiff > 300) { // 5分钟以上才记录日志，避免频繁日志
                    vehicleApiLogMessage("车辆解锁：存在未完成行程 ID {$lastTrip['id']}，无需重复开始", 'DEBUG', $isCliMode);
                }
            }
        } elseif ($mainLockStatus === 1) { // 锁定状态 - 可能需要结束行程
            if ($lastTrip) {
                $mileageDiff = $totalMileage - $lastTrip['start_mileage'];
                if ($mileageDiff >= 1) {
                    // 有效里程变化，结束行程
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
                    vehicleApiLogMessage("车辆锁定：结束行程 ID {$lastTrip['id']}，里程变化: {$mileageDiff}公里", 'INFO', $isCliMode);
                } else {
                    // 无效里程变化，删除无效行程
                    $deleteStmt = $pdo->prepare("DELETE FROM trip_record WHERE id = :id");
                    $deleteStmt->execute([':id' => $lastTrip['id']]);
                    vehicleApiLogMessage("车辆锁定：删除无效行程 ID {$lastTrip['id']}，里程变化: {$mileageDiff}公里（小于1公里阈值）", 'INFO', $isCliMode);
                }
            } else {
                // 锁定状态但没有未完成行程，正常情况，无需处理
                vehicleApiLogMessage("车辆锁定：当前无未完成行程，状态正常", 'DEBUG', $isCliMode);
            }
        } else {
            // 未知锁定状态
            vehicleApiLogMessage("警告：未知的 mainLockStatus 值: {$mainLockStatus}", 'WARNING', $isCliMode);
        }
        
    } catch (Exception $e) {
        vehicleApiLogMessage("行程记录处理异常: " . $e->getMessage(), 'ERROR', $isCliMode);
    }
}

?>