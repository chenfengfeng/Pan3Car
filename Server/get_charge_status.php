<?php
// 包含数据库连接代码,外部属性：$pdo
include $_SERVER['DOCUMENT_ROOT'] . '/db_connect.php';
// 主逻辑
header('Content-Type: application/json');

$params = json_decode(file_get_contents('php://input'), true);
if (empty($params)) {
    echo json_encode(['code' => 500, 'msg' => 'Decryption failed']);
    exit;
}

// 获取用户提交的 vin
$vin = $params['vin'];

// 验证必要参数
if (empty($vin)) {
    echo json_encode(['code' => 400, 'msg' => '参数不完整，缺少vin']);
    exit;
}

try {
    // 查询当前vin是否有正在运行的任务
    $stmt = $pdo->prepare("
        SELECT COUNT(*) as task_count 
        FROM charge_task 
        WHERE vin = ? AND (status = 'pending' OR status = 'ready')
    ");
    $stmt->execute([$vin]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    $hasRunningTask = $result['task_count'] > 0;
    
    $responseData = [
        'has_running_task' => $hasRunningTask
    ];
    
    // 如果有正在运行的任务，获取任务详细信息
    if ($hasRunningTask) {
        $detailStmt = $pdo->prepare("
            SELECT id, vin, status, initial_km, target_km, initial_kwh, target_kwh, 
                   charged_kwh, message, create_time, finish_time
            FROM charge_task 
            WHERE vin = ? AND (status = 'pending' OR status = 'ready')
            ORDER BY create_time DESC
            LIMIT 1
        ");
        $detailStmt->execute([$vin]);
        $taskDetail = $detailStmt->fetch(PDO::FETCH_ASSOC);
        
        if ($taskDetail) {
            // 格式化任务数据，保持与 get_charge_list.php 一致的格式
            $responseData['task'] = [
                'id' => (int)$taskDetail['id'],
                'vin' => $taskDetail['vin'],
                'initialKwh' => (float)$taskDetail['initial_kwh'],
                'targetKwh' => (float)$taskDetail['target_kwh'],
                'chargedKwh' => (float)$taskDetail['charged_kwh'],
                'initialKm' => (float)$taskDetail['initial_km'],
                'targetKm' => (float)$taskDetail['target_km'],
                'status' => $taskDetail['status'],
                'message' => $taskDetail['message'],
                'createTime' => $taskDetail['create_time'],
                'finishTime' => $taskDetail['finish_time']
            ];
        }
    }
    
    echo json_encode([
        'code' => 200,
        'msg' => '查询成功',
        'data' => $responseData
    ]);
    
} catch (PDOException $e) {
    echo json_encode(['code' => 500, 'msg' => '数据库错误: ' . $e->getMessage()]);
} catch (Exception $e) {
    echo json_encode(['code' => 500, 'msg' => '系统错误: ' . $e->getMessage()]);
}
?>