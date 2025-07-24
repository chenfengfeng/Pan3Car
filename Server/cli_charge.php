<?php

// 设置错误报告级别
error_reporting(E_ALL);
ini_set('display_errors', 0); // CLI模式下不显示错误到屏幕
ini_set('log_errors', 1);

// 设置时区
date_default_timezone_set('Asia/Shanghai');

// 包含数据库连接代码,外部属性：$pdo
include __DIR__ . '/db_connect.php';

// 包含APNs JWT生成器
require_once __DIR__ . '/apns_jwt_generator.php';

// 配置常量
define('TASK_TIMEOUT_HOURS', 6); // 任务超时时间（小时）
define('API_TIMEOUT', 30); // API超时时间（秒）
define('API_CONNECT_TIMEOUT', 10); // API连接超时时间（秒）
define('TOLERANCE_KM', 20.0); // 车型识别误差范围（公里）

// 车型配置信息：型号 => [总里程, 电池容量(kWh)] <mcreference link="https://www.php.net/ChangeLog-8.php" index="5">5</mcreference>
$carModels = [
    '330' => ['range' => 330.0, 'battery' => 34.5],
    '405' => ['range' => 405.0, 'battery' => 41.0],
    '505' => ['range' => 505.0, 'battery' => 51.5]
];

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
    
    // 写入文件,展示不写入
    // file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);
    
    // 同时输出到终端
    echo $logEntry;
}

// 调用停止充电API - 参考stop_charge.php实现
function stopCharging(string $vin, string $token): array {
    $url = 'https://jacsupperapp.jac.com.cn/api/jac-energy/jacenergy/vehicleControl/energy-remote-vehicle-control';
    
    $data = [
        'operation' => 1,
        'extParams' => [
            'bookTime' => 0
        ],
        'vin' => $vin,
        'operationType' => 'RESERVATION_RECHARGE'
    ];
    
    $headers = [
        'Content-Type: application/json',
        'timaToken: ' . $token,
        'User-Agent: PHP-CLI-ChargeMonitor/1.0'
    ];
    
    $ch = curl_init();
    
    $curlOptions = [
        CURLOPT_URL => $url,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($data, JSON_THROW_ON_ERROR),
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => API_TIMEOUT,
        CURLOPT_CONNECTTIMEOUT => API_CONNECT_TIMEOUT,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_FOLLOWLOCATION => false,
        CURLOPT_MAXREDIRS => 0,
        CURLOPT_ENCODING => '',
        CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_2_0,
    ];
    
    curl_setopt_array($ch, $curlOptions);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    $totalTime = curl_getinfo($ch, CURLINFO_TOTAL_TIME);
    curl_close($ch);
    
    if ($error) {
        logMessage('停止充电CURL错误: ' . $error, 'ERROR');
        return ['success' => false, 'error' => '停止充电CURL错误: ' . $error];
    }
    
    if ($httpCode !== 200) {
        logMessage("停止充电HTTP错误: {$httpCode}", 'ERROR');
        return ['success' => false, 'error' => "停止充电HTTP错误: {$httpCode}"];
    }
    
    try {
        $result = json_decode($response, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $e) {
        logMessage('停止充电JSON解析错误: ' . $e->getMessage(), 'ERROR');
        return ['success' => false, 'error' => '停止充电JSON解析错误: ' . $e->getMessage()];
    }
    
    if (!$result || !isset($result['returnSuccess']) || !$result['returnSuccess']) {
        $errorMsg = $result['returnErrMsg'] ?? '停止充电未知错误';
        logMessage("停止充电API返回错误: {$errorMsg}", 'ERROR');
        return ['success' => false, 'error' => "停止充电API返回错误: {$errorMsg}"];
    }
    
    logMessage("停止充电API调用成功，耗时: {$totalTime}秒", 'DEBUG');
    return ['success' => true, 'data' => $result];
}

// 调用第三方API获取车辆信息 - 使用现代PHP最佳实践
function getVehicleInfo(string $vin, string $token): array {
    $url = 'https://jacsupperapp.jac.com.cn/api/jac-energy/jacenergy/vehicleInformation/energy-query-vehicle-new-condition';
    
    $data = [
        'vins' => [$vin]
    ];
    
    $headers = [
        'Content-Type: application/json',
        'timaToken: ' . $token,
        'User-Agent: PHP-CLI-ChargeMonitor/1.0'
    ];
    
    $ch = curl_init();
    
    // 使用现代cURL配置和安全设置
    $curlOptions = [
        CURLOPT_URL => $url,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($data, JSON_THROW_ON_ERROR),
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => API_TIMEOUT,
         CURLOPT_CONNECTTIMEOUT => API_CONNECT_TIMEOUT,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_FOLLOWLOCATION => false,
        CURLOPT_MAXREDIRS => 0,
        CURLOPT_ENCODING => '', // 支持所有编码
        CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_2_0, // 优先使用HTTP/2
    ];
    
    curl_setopt_array($ch, $curlOptions);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    $totalTime = curl_getinfo($ch, CURLINFO_TOTAL_TIME);
    curl_close($ch);
    
    if ($error) {
        logMessage('CURL错误: ' . $error, 'ERROR');
        return ['success' => false, 'error' => 'CURL错误: ' . $error];
    }
    
    if ($httpCode !== 200) {
        logMessage("HTTP错误: {$httpCode}", 'ERROR');
        return ['success' => false, 'error' => "HTTP错误: {$httpCode}"];
    }
    
    try {
        $result = json_decode($response, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $e) {
        logMessage('JSON解析错误: ' . $e->getMessage(), 'ERROR');
        return ['success' => false, 'error' => 'JSON解析错误: ' . $e->getMessage()];
    }
    
    if (!$result || !isset($result['returnSuccess']) || !$result['returnSuccess']) {
        $errorMsg = $result['returnErrMsg'] ?? '未知错误';
        logMessage("API返回错误: {$errorMsg}", 'ERROR');
        return ['success' => false, 'error' => "API返回错误: {$errorMsg}"];
    }
    
    logMessage("API调用成功，耗时: {$totalTime}秒", 'DEBUG');
    return ['success' => true, 'data' => $result['data']];
}

// 计算当前电量 - 使用现代PHP类型声明
function calculateCurrentKwh(int $soc, int $acOnMile, array $carModels): ?float {
    if ($soc <= 0 || $acOnMile <= 0) {
        return null;
    }
    
    // 计算理论满电续航里程
    $estimatedFullMileage = $acOnMile / ($soc / 100.0);
    
    $detectedModel = null;
    $minDifference = PHP_FLOAT_MAX;
    $tolerance = TOLERANCE_KM; // 允许的误差范围
    
    // 根据续航里程推断车型 - 精确匹配
    foreach ($carModels as $model => $config) {
        $difference = abs($config['range'] - $estimatedFullMileage);
        
        if ($difference <= $tolerance && $difference < $minDifference) {
            $minDifference = $difference;
            $detectedModel = $model;
        }
    }
    
    // 如果无法精确匹配，选择最接近的车型
    if ($detectedModel === null) {
        $minDifference = PHP_FLOAT_MAX;
        foreach ($carModels as $model => $config) {
            $difference = abs($config['range'] - $estimatedFullMileage);
            
            if ($difference < $minDifference) {
                $minDifference = $difference;
                $detectedModel = $model;
            }
        }
    }
    
    // 计算当前电量
    if ($detectedModel && isset($carModels[$detectedModel])) {
        $batteryCapacity = (float) $carModels[$detectedModel]['battery'];
        $currentKwh = round($batteryCapacity * ($soc / 100.0), 2);
        logMessage("检测到车型: {$detectedModel}, 电池容量: {$batteryCapacity}kWh, 当前电量: {$currentKwh}kWh");
        return $currentKwh;
    }
    
    // 默认使用405车型
    $defaultKwh = round(41.0 * ($soc / 100.0), 2);
    logMessage("使用默认车型405, 当前电量: {$defaultKwh}kWh");
    return $defaultKwh;
}

// 发送APNs推送通知
function sendAPNsPushNotification(array $task, string $status, string $message, ?float $chargedKwh = null): bool {
    // 检查是否有push_token
    if (empty($task['push_token'])) {
        logMessage("任务 {$task['id']} 没有push_token，跳过推送通知");
        return false;
    }
    
    $pushToken = $task['push_token'];
    
    // 获取JWT Token
    $jwtToken = getAPNsJWTToken();
    if (!$jwtToken) {
        logMessage("获取APNs JWT Token失败", 'ERROR');
        return false;
    }
    
    // 计算充电百分比
    $initialKwh = floatval($task['initial_kwh']);
    $targetKwh = floatval($task['target_kwh']);
    $targetChargeAmount = $targetKwh - $initialKwh;
    $percentage = 0;
    
    if ($targetChargeAmount > 0 && $chargedKwh !== null) {
        $progress = $chargedKwh / $targetChargeAmount;
        $percentage = (int)min(max($progress * 100, 0), 100);
    }

    // 事件
    $event = 'update';
    // if ($status != 'pending') {
    //     $event = 'end';
    // }
    
    // 构建Live Activity APNs推送payload
    $payload = [
        'aps' => [
            'timestamp' => time(),
            'event' => $event,
            'content-state' => [
                'status' => $status,
                'chargedKwh' => floatval($chargedKwh ?? 0.0),
                'percentage' => intval($percentage),
                'message' => $message,
                'lastUpdateTime' => microtime(true) // 返回如 1720686543.087624 的 float 时间戳
            ]
        ]
    ];
    
    $payloadJson = json_encode($payload, JSON_UNESCAPED_UNICODE);
    
    // APNs推送URL (生产环境)
    $apnsUrl = 'https://api.push.apple.com/3/device/' . $pushToken;
    // APNs推送URL (测试环境)
    // $apnsUrl = 'https://api.sandbox.push.apple.com/3/device/' . $pushToken;
    
    // 设置HTTP头
    $headers = [
        'Authorization: Bearer ' . $jwtToken,
        'apns-topic: com.dream.pan3car.push-type.liveactivity',
        'apns-push-type: liveactivity',
        'apns-priority: 10'
    ];
    
    // 发送推送请求
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => $apnsUrl,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $payloadJson,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_2_0
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);
    
    if ($error) {
        logMessage("APNs推送CURL错误: {$error}", 'ERROR');
        return false;
    }
    
    if ($httpCode === 200) {
        logMessage("任务 {$task['id']} APNs推送发送成功");
        return true;
    } else {
        logMessage("任务 {$task['id']} APNs推送失败，HTTP状态码: {$httpCode}，响应: {$response}", 'ERROR');
        return false;
    }
}

// 更新任务状态 - 使用现代PDO最佳实践
function updateTaskStatus(PDO $pdo, int $taskId, string $status, string $message, ?float $chargedKwh = null, bool $finishTime = false, ?array $task = null): bool {
    try {
        $sql = "UPDATE charge_task SET status = :status, message = :message, update_time = NOW()";
        $params = [
            ':status' => $status,
            ':message' => $message,
            ':task_id' => $taskId
        ];
        
        if ($chargedKwh !== null) {
            $sql .= ", charged_kwh = :charged_kwh";
            $params[':charged_kwh'] = $chargedKwh;
        }
        
        if ($finishTime) {
            $sql .= ", finish_time = NOW()";
        }
        
        $sql .= " WHERE id = :task_id";
        
        $stmt = $pdo->prepare($sql);
        $result = $stmt->execute($params);
        
        if ($result) {
            logMessage("任务 {$taskId} 状态更新成功: {$status} - {$message}");
            
            // 如果提供了任务数据，发送推送通知
            if ($task !== null) {
                sendAPNsPushNotification($task, $status, $message, $chargedKwh);
            }
        } else {
            logMessage("任务 {$taskId} 状态更新失败");
        }
        
        return $result;
    } catch (PDOException $e) {
        logMessage("数据库错误: " . $e->getMessage(), 'ERROR');
        return false;
    }
}

// 开始执行监控
$startTime = microtime(true);
$startMemory = memory_get_usage();
$processedTasks = 0;
$errorTasks = 0;
$completedTasks = 0;

logMessage("开始执行充电任务监控...");

try {
    // 查询需要处理的充电任务 - 使用现代PDO最佳实践 <mcreference link="https://www.runoob.com/php/php-pdo.html" index="1">1</mcreference>
    $sql = "SELECT * FROM charge_task WHERE status IN (:pending, :ready) ORDER BY create_time ASC";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':pending' => 'pending',
        ':ready' => 'ready'
    ]);
    $tasks = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    logMessage("找到 " . count($tasks) . " 个待处理的充电任务");
    
    foreach ($tasks as $task) {
        $processedTasks++;
        $taskId = $task['id'];
        $vin = $task['vin'];
        $token = $task['token'];
        $currentStatus = $task['status'];
        $createTime = new DateTime($task['create_time']);
        $now = new DateTime();
        
        logMessage("处理任务 ID: {$taskId}, VIN: {$vin}, 状态: {$currentStatus}");
        
        // 规则1: 检查是否超过设定的超时时间
        $interval = $now->diff($createTime);
        $hoursDiff = ($interval->days * 24) + $interval->h;
        if ($hoursDiff > TASK_TIMEOUT_HOURS) {
            updateTaskStatus($pdo, $taskId, 'timeout', '任务超时：创建时间超过6小时', null, true, $task);
            logMessage("任务 {$taskId} 已超时，创建时间: {$task['create_time']}");
            $errorTasks++;
            continue;
        }
        
        // 调用第三方API获取车辆信息
        $vehicleInfo = getVehicleInfo($vin, $token);
        
        // 规则2: 检查API调用是否失败
        if (!$vehicleInfo['success']) {
            updateTaskStatus($pdo, $taskId, 'error', 'API调用失败：' . $vehicleInfo['error'], null, true, $task);
            logMessage("任务 {$taskId} API调用失败: " . $vehicleInfo['error']);
            $errorTasks++;
            continue;
        }
        
        $vehicleData = $vehicleInfo['data'];
        $soc = intval($vehicleData['soc'] ?? 0);
        $acOnMile = intval($vehicleData['acOnMile'] ?? 0);
        $chgStatus = intval($vehicleData['chgStatus'] ?? 2);
        $quickChgLeftTime = intval($vehicleData['quickChgLeftTime'] ?? 0);
        
        logMessage("车辆数据 - SOC: {$soc}%, 剩余里程: {$acOnMile}km, 充电状态: {$chgStatus}");
        
        // 计算当前电量
        $currentKwh = calculateCurrentKwh($soc, $acOnMile, $carModels);
        
        if ($currentStatus === 'ready') {
            // 规则3: ready状态下检查是否开始充电
            if ($chgStatus !== 2) {
                updateTaskStatus($pdo, $taskId, 'pending', '充电已开始，正在监控充电进度...', null, false, $task);
                logMessage("任务 {$taskId} 开始充电，状态更新为pending");
            }else{
                // 测试状态
                updateTaskStatus($pdo, $taskId, 'ready', '充电口：现在赶紧拿充电枪插我吧', null, false, $task);
            }
        } elseif ($currentStatus === 'pending') {
            if ($chgStatus !== 2) {
                // 正在充电中
                $initialKwh = floatval($task['initial_kwh']);
                $targetKwh = floatval($task['target_kwh']);
                $chargedKwh = max(0, $currentKwh - $initialKwh);
                
                // 规则4: 检查是否达到目标电量
                if ($currentKwh >= $targetKwh) {
                    // 调用停止充电API，忽略返回结果
                    $stopResult = stopCharging($vin, $token);
                    logMessage("任务 {$taskId} 已调用停止充电API");
                    
                    // 无论停止充电API是否成功，都标记任务为完成
                    updateTaskStatus($pdo, $taskId, 'done', '充电完成：已达到目标电量', $chargedKwh, true, $task);
                    logMessage("任务 {$taskId} 充电完成：已达到目标电量");
                    $completedTasks++;
                } 
                // 规则6: 检查是否已充满（SOC=100%）
                elseif ($soc >= 100) {
                    updateTaskStatus($pdo, $taskId, 'done', '充电完成：电池已充满，再多就溢出来了', $chargedKwh, true, $task);
                    logMessage("任务 {$taskId} 充电完成：电池已充满");
                    $completedTasks++;
                } 
                else {
                    // 更新充电进度
                    updateTaskStatus($pdo, $taskId, 'pending', "充电中：当前电量 {$currentKwh}kWh ({$soc}%), 已充电 {$chargedKwh}kWh", $chargedKwh, false, $task);
                    logMessage("任务 {$taskId} 充电进度更新");
                }
            } else {
                // 规则5: 充电过程中停止充电
                $initialKwh = floatval($task['initial_kwh']);
                $chargedKwh = max(0, $currentKwh - $initialKwh);
                updateTaskStatus($pdo, $taskId, 'done', '充电结束：用户主动停止充电', $chargedKwh, true, $task);
                logMessage("任务 {$taskId} 用户主动停止充电");
                $completedTasks++;
            }
        }
    }
    
    // 执行完成统计
    $endTime = microtime(true);
    $endMemory = memory_get_usage();
    $executionTime = round($endTime - $startTime, 3);
    $memoryUsed = round(($endMemory - $startMemory) / 1024 / 1024, 2);
    $peakMemory = round(memory_get_peak_usage() / 1024 / 1024, 2);
    
    logMessage("充电任务监控完成");
    logMessage("=== 执行统计 ===");
    logMessage("处理任务总数: {$processedTasks}");
    logMessage("完成任务数: {$completedTasks}");
    logMessage("错误任务数: {$errorTasks}");
    logMessage("执行时间: {$executionTime}秒");
    logMessage("内存使用: {$memoryUsed}MB");
    logMessage("峰值内存: {$peakMemory}MB");
    
} catch (PDOException $e) {
    logMessage("数据库错误: " . $e->getMessage(), 'ERROR');
    logMessage("错误代码: " . $e->getCode(), 'ERROR');
    exit(1);
} catch (JsonException $e) {
    logMessage("JSON处理错误: " . $e->getMessage(), 'ERROR');
    exit(1);
} catch (Exception $e) {
    logMessage("系统错误: " . $e->getMessage(), 'ERROR');
    logMessage("错误文件: " . $e->getFile() . ":" . $e->getLine(), 'ERROR');
    exit(1);
} finally {
    // 清理资源
    if (isset($pdo)) {
        $pdo = null;
    }
}

?>
