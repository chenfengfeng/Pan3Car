<?php
// 用户退出登录接口 - User Logout API
// 此接口用于用户退出登录

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
$no = $input['no'];
$timaToken = $input['timaToken'];
$server = $input['server'] ?? '';

if (!isset($no) || !isset($timaToken)) {
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
    // 调用退出登录API
    $logoutUrl = $baseApiUrl . '/api/jac-admin/admin/userBaseInformation/userLoginOut';
    $logoutData = [
        'no' => $no
    ];
    
    $logoutHeaders = [
        'timaToken: ' . $timaToken
    ];
    
    logMessage('开始退出登录: ' . $no, 'INFO');
    
    $logoutResponse = makeRequest($logoutUrl, $logoutData, $logoutHeaders);
    
    if ($logoutResponse['code'] === 0) {
        echo json_encode([
            'code' => 200,
            'message' => '退出登录成功'
        ]);
        logMessage('退出登录成功: ' . $no, 'INFO');
    } else {
        echo json_encode([
            'code' => $logoutResponse['code'],
            'message' => $logoutResponse['msg'] ?? '退出登录失败'
        ]);
        logMessage('退出登录失败: ' . $logoutResponse['msg'], 'ERROR');
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'code' => 500,
        'message' => $e->getMessage()
    ]);
    logMessage('退出登录接口出错了: ' . $e->getMessage(), 'ERROR');
}
?>