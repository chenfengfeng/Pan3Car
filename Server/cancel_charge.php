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
    // 查询该VIN最新的一次充电任务
    $stmt = $pdo->prepare("
        SELECT id, status 
        FROM charge_task 
        WHERE vin = ? 
        ORDER BY create_time DESC 
        LIMIT 1
    ");
    $stmt->execute([$vin]);
    $latestTask = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$latestTask) {
        echo json_encode(['code' => 404, 'msg' => '未找到该车辆的充电任务']);
        exit;
    }
    
    // 检查任务状态，只有pending或ready状态的任务才能取消
    if ($latestTask['status'] !== 'pending' && $latestTask['status'] !== 'ready') {
        echo json_encode(['code' => 400, 'msg' => '当前任务状态不允许取消']);
        exit;
    }
    
    // 更新任务状态为cancel，并设置取消消息
    $updateStmt = $pdo->prepare("
        UPDATE charge_task 
        SET status = 'cancelled', 
            message = '用户主动取消充电任务',
            finish_time = NOW()
        WHERE id = ?
    ");
    
    $result = $updateStmt->execute([$latestTask['id']]);
    
    if ($result) {
        echo json_encode([
            'code' => 200,
            'msg' => '充电任务已成功取消',
            'data' => [
                'task_id' => (int)$latestTask['id'],
                'vin' => $vin,
                'status' => 'cancel'
            ]
        ]);
    } else {
        echo json_encode(['code' => 500, 'msg' => '取消充电任务失败']);
    }
    
} catch (PDOException $e) {
    echo json_encode(['code' => 500, 'msg' => '数据库错误: ' . $e->getMessage()]);
} catch (Exception $e) {
    echo json_encode(['code' => 500, 'msg' => '系统错误: ' . $e->getMessage()]);
}
?>