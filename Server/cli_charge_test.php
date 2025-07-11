<?php

// 设置错误报告级别
error_reporting(E_ALL);
ini_set('display_errors', 0); // CLI模式下不显示错误到屏幕
ini_set('log_errors', 1);

// 设置时区
date_default_timezone_set('Asia/Shanghai');

// 包含数据库连接代码,外部属性：$pdo
include __DIR__ . '/../db_connect.php';

// 包含APNs JWT生成器
require_once __DIR__ . '/apns_jwt_generator.php';

// 配置常量
define('TASK_TIMEOUT_HOURS', 6); // 任务超时时间（小时）
define('CHARGE_INCREMENT_KWH', 1.0); // 每次充电增量（kWh）
define('TOLERANCE_KM', 20.0); // 车型识别误差范围（公里）

// 车型配置信息：型号 => [总里程, 电池容量(kWh)]
$carModels = [
    '330' => ['range' => 330.0, 'battery' => 34.5],
    '405' => ['range' => 405.0, 'battery' => 41.0],
    '505' => ['range' => 505.0, 'battery' => 51.5]
];

// 日志函数 - 支持文件存储
function logMessage($message, $level = 'INFO')
{
    $logDir = __DIR__ . '/logs';
    $logFile = $logDir . '/charge_test_' . date('Y-m-d') . '.log';

    // 确保日志目录存在
    if (!is_dir($logDir)) {
        mkdir($logDir, 0755, true);
    }

    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[{$timestamp}] [{$level}] [TEST] {$message}" . PHP_EOL;

    // 写入文件,展示不写入
    // file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);

    // 同时输出到终端
    echo $logEntry;
}

// 模拟车辆信息API - 返回模拟的充电数据
function getSimulatedVehicleInfo(array $task, array $carModels): array
{
    // 模拟充电状态：2=未充电，其他值=正在充电
    $chgStatus = 1; // 模拟正在充电

    // 获取当前已充电量，如果没有则从0开始
    $currentChargedKwh = floatval($task['charged_kwh'] ?? 0.0);
    $initialKwh = floatval($task['initial_kwh']);
    $targetKwh = floatval($task['target_kwh']);

    // 每次增加1kWh
    $newChargedKwh = $currentChargedKwh + CHARGE_INCREMENT_KWH;
    $currentTotalKwh = $initialKwh + $newChargedKwh;

    // 确保不超过目标电量
    if ($currentTotalKwh > $targetKwh) {
        $currentTotalKwh = $targetKwh;
        $newChargedKwh = $targetKwh - $initialKwh;
    }

    // 根据车型计算SOC和续航里程
    $detectedModel = detectCarModel($initialKwh, $carModels);
    $batteryCapacity = $carModels[$detectedModel]['battery'];
    $maxRange = $carModels[$detectedModel]['range'];

    $soc = min(100, round(($currentTotalKwh / $batteryCapacity) * 100));
    $acOnMile = round(($currentTotalKwh / $batteryCapacity) * $maxRange);

    logMessage("模拟车辆数据 - 车型: {$detectedModel}, SOC: {$soc}%, 续航: {$acOnMile}km, 当前总电量: {$currentTotalKwh}kWh, 已充电: {$newChargedKwh}kWh");

    return [
        'success' => true,
        'data' => [
            'soc' => $soc,
            'acOnMile' => $acOnMile,
            'chgStatus' => $chgStatus,
            'quickChgLeftTime' => 0,
            'currentKwh' => $currentTotalKwh,
            'chargedKwh' => $newChargedKwh
        ]
    ];
}

// 根据初始电量检测车型
function detectCarModel(float $initialKwh, array $carModels): string
{
    $minDifference = PHP_FLOAT_MAX;
    $detectedModel = '405'; // 默认车型

    foreach ($carModels as $model => $config) {
        $batteryCapacity = $config['battery'];
        // 假设初始电量对应某个SOC百分比
        $estimatedSoc = ($initialKwh / $batteryCapacity) * 100;

        // 选择最合理的车型（SOC在合理范围内）
        if ($estimatedSoc >= 10 && $estimatedSoc <= 100) {
            $difference = abs($batteryCapacity - ($initialKwh / 0.5)); // 假设初始SOC约50%
            if ($difference < $minDifference) {
                $minDifference = $difference;
                $detectedModel = $model;
            }
        }
    }

    return $detectedModel;
}

// 模拟停止充电API
function simulateStopCharging(string $vin, string $token): array
{
    logMessage("模拟调用停止充电API - VIN: {$vin}");

    // 模拟API调用成功
    return [
        'success' => true,
        'data' => [
            'returnSuccess' => true,
            'returnErrMsg' => ''
        ]
    ];
}

// 发送APNs推送通知
function sendAPNsPushNotification(array $task, string $status, string $message, ?float $chargedKwh = null): bool
{
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

    // 构建Live Activity APNs推送payload
    $payload = [
        'aps' => [
            'timestamp' => time(),
            'event' => 'update',
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
    // $apnsUrl = 'https://api.push.apple.com/3/device/' . $pushToken;
    // APNs推送URL (测试环境)
    $apnsUrl = 'https://api.sandbox.push.apple.com/3/device/' . $pushToken;

    // 设置HTTP头
    $headers = [
        'Authorization: Bearer ' . $jwtToken,
        'apns-topic: com.dream.car.pan3.push-type.liveactivity',
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
function updateTaskStatus(PDO $pdo, int $taskId, string $status, string $message, ?float $chargedKwh = null, bool $finishTime = false, ?array $task = null): bool
{
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

// 开始执行模拟充电监控
$startTime = microtime(true);
$startMemory = memory_get_usage();
$processedTasks = 0;
$errorTasks = 0;
$completedTasks = 0;

logMessage("开始执行模拟充电任务监控...");

try {
    // 查询需要处理的充电任务 - 查找ready状态的任务并改为pending
    $sql = "SELECT * FROM charge_task WHERE status IN (:ready, :pending) ORDER BY create_time ASC";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':ready' => 'ready',
        ':pending' => 'pending'
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

        // 如果是ready状态，先改为pending
        if ($currentStatus === 'ready') {
            updateTaskStatus($pdo, $taskId, 'pending', '模拟充电已开始，正在监控充电进度...', null, false, $task);
            logMessage("任务 {$taskId} 状态从ready改为pending");
            continue; // 下次循环再处理充电逻辑
        }

        // 处理pending状态的任务
        if ($currentStatus === 'pending') {
            // 获取模拟车辆信息
            $vehicleInfo = getSimulatedVehicleInfo($task, $carModels);

            if (!$vehicleInfo['success']) {
                updateTaskStatus($pdo, $taskId, 'error', '模拟API调用失败', null, true, $task);
                logMessage("任务 {$taskId} 模拟API调用失败");
                $errorTasks++;
                continue;
            }

            $vehicleData = $vehicleInfo['data'];
            $soc = intval($vehicleData['soc']);
            $acOnMile = intval($vehicleData['acOnMile']);
            $chgStatus = intval($vehicleData['chgStatus']);
            $currentKwh = floatval($vehicleData['currentKwh']);
            $chargedKwh = floatval($vehicleData['chargedKwh']);

            $initialKwh = floatval($task['initial_kwh']);
            $targetKwh = floatval($task['target_kwh']);

            logMessage("模拟车辆数据 - SOC: {$soc}%, 剩余里程: {$acOnMile}km, 充电状态: {$chgStatus}");

            // 检查是否达到目标电量
            if ($currentKwh >= $targetKwh) {
                // 调用模拟停止充电API
                $stopResult = simulateStopCharging($vin, $token);
                logMessage("任务 {$taskId} 已调用模拟停止充电API");

                // 标记任务为完成
                updateTaskStatus($pdo, $taskId, 'done', '模拟充电完成：已达到目标电量', $chargedKwh, true, $task);
                logMessage("任务 {$taskId} 模拟充电完成：已达到目标电量");
                $completedTasks++;
            }
            // 检查是否已充满（SOC=100%）
            elseif ($soc >= 100) {
                updateTaskStatus($pdo, $taskId, 'done', '模拟充电完成：电池已充满', $chargedKwh, true, $task);
                logMessage("任务 {$taskId} 模拟充电完成：电池已充满");
                $completedTasks++;
            } else {
                // 更新充电进度
                updateTaskStatus($pdo, $taskId, 'pending', "模拟充电中：当前电量 {$currentKwh}kWh ({$soc}%), 已充电 {$chargedKwh}kWh", $chargedKwh, false, $task);
                logMessage("任务 {$taskId} 模拟充电进度更新");
            }
        }
    }

    // 执行完成统计
    $endTime = microtime(true);
    $endMemory = memory_get_usage();
    $executionTime = round($endTime - $startTime, 3);
    $memoryUsed = round(($endMemory - $startMemory) / 1024 / 1024, 2);
    $peakMemory = round(memory_get_peak_usage() / 1024 / 1024, 2);

    logMessage("模拟充电任务监控完成");
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
