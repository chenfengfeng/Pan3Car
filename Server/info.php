<?php
// 设置错误报告级别
error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// 设置时区
date_default_timezone_set('Asia/Shanghai');

// 包含车辆信息查询共享函数库
require_once __DIR__ . '/vehicle_api.php';

// 设置响应头
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// 处理OPTIONS请求
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

// 日志函数 - 支持文件存储
function logMessage($message, $level = 'INFO') {
    $logDir = __DIR__ . '/logs';
    $logFile = $logDir . '/info_' . date('Y-m-d') . '.log';
    
    // 确保日志目录存在
    if (!is_dir($logDir)) {
        mkdir($logDir, 0755, true);
    }
    
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[{$timestamp}] [{$level}] {$message}" . PHP_EOL;
    
    // 只写入文件，不输出到终端（避免破坏JSON响应）
    file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);
}

// 只记录错误信息，不记录正常请求

// 获取原始请求数据
$rawInput = file_get_contents('php://input');

// 解析JSON数据
$input = json_decode($rawInput, true);
if (json_last_error() !== JSON_ERROR_NONE) {
    $jsonError = json_last_error_msg();
    logMessage('JSON解析失败: ' . $jsonError, 'ERROR');
    http_response_code(400);
    echo json_encode(['error' => 'Invalid JSON: ' . $jsonError]);
    exit;
}
$server = $input['server'] ?? '';

if (!isset($input['vin'])) {
    logMessage('缺少必需参数: vin', 'ERROR');
    http_response_code(400);
    echo json_encode(['error' => 'Missing required parameter: vin']);
    exit;
}

// 移除正常请求的日志记录

// 根据server参数选择API基础地址
$baseApiUrl = ($server === 'spare') ? 'https://yiweiauto.cn' : 'https://jacsupperapp.jac.com.cn';
// 移除正常请求的日志记录

// 从请求头和请求体获取timaToken
$headers = getallheaders();

$timaToken = $input['timaToken'] ?? '';

if (!$timaToken) {
    logMessage('缺少timaToken', 'ERROR');
    http_response_code(401);
    echo json_encode(['error' => 'Missing timaToken']);
    exit;
}

// 移除正常请求的日志记录



// 发送请求的函数 - 已弃用，使用共享函数库
// 保留此函数以防向后兼容性问题
function makeRequest($url, $data, $headers = []) {
    // 此函数已被共享函数库替代，但保留以防兼容性问题
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
        logMessage('网络错误: ' . $error, 'ERROR');
        throw new Exception('Network error: ' . $error);
    }
    
    if ($httpCode !== 200) {
        logMessage('HTTP错误，状态码: ' . $httpCode . '，响应: ' . substr($response, 0, 200), 'ERROR');
        throw new Exception('HTTP error: ' . $httpCode);
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
    // 使用共享函数库获取车辆信息
    $result = getVehicleInfoForWeb($input['vin'], $timaToken, $server);
    
    if (!$result['success']) {
        echo json_encode([
            'success' => false,
            'message' => $result['error']
        ]);
        exit;
    }
    
    // 检查认证失败
    if ($result['code'] == 403) {
        echo json_encode([
            'success' => false,
            'message' => 'Authentication failure'
        ]);
        exit;
    }
    
    // 返回成功结果
    echo json_encode([
        'code' => 200,
        'success' => true,
        'data' => $result['data']
    ]);
    
} catch (Exception $e) {
    logMessage('异常发生: ' . $e->getMessage(), 'ERROR');
    logMessage('异常堆栈: ' . $e->getTraceAsString(), 'ERROR');
    
    http_response_code(500);
    echo json_encode([
        'code' => 500,
        'message' => $e->getMessage()
    ]);
    
    logMessage('=== 车辆信息请求异常结束 ===', 'ERROR');
}
?>