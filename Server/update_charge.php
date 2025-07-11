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
// 获取用户提交的 token
$token = $params['token'];
// 获取用户提交的 push_token
$push_token = $params['push_token'];

// 验证必要参数
if (empty($vin) || empty($token)) {
    echo json_encode(['code' => 400, 'msg' => '参数不完整']);
    exit;
}

try {
    // 1. 检查当前vin是否有准备中或充电中的任务
    $stmt = $pdo->prepare("SELECT id, status FROM charge_task WHERE vin = ? AND status IN ('pending', 'ready') ORDER BY create_time DESC LIMIT 1");
    $stmt->execute([$vin]);
    $existingTask = $stmt->fetch();
    
    if (!$existingTask) {
        echo json_encode(['code' => 404, 'msg' => '当前车辆没有准备中或充电中的任务']);
        exit;
    }
    
    // 2. 更新任务的token和push_token
    $updateFields = ['token = ?'];
    $updateParams = [$token];
    
    // 如果提供了push_token，也一起更新
    if (!empty($push_token)) {
        $updateFields[] = 'push_token = ?';
        $updateParams[] = $push_token;
    }
    
    $updateParams[] = $existingTask['id'];
    
    $updateSql = "UPDATE charge_task SET " . implode(', ', $updateFields) . ", update_time = NOW() WHERE id = ?";
    $stmt = $pdo->prepare($updateSql);
    $result = $stmt->execute($updateParams);
    
    if ($result) {
        $responseData = [
            'code' => 200, 
            'msg' => '任务token更新成功'
        ];
        echo json_encode($responseData);
    } else {
        echo json_encode(['code' => 500, 'msg' => '更新任务token失败']);
    }
    
} catch (PDOException $e) {
    echo json_encode(['code' => 500, 'msg' => '数据库错误: ' . $e->getMessage()]);
} catch (Exception $e) {
    echo json_encode(['code' => 500, 'msg' => '系统错误: ' . $e->getMessage()]);
}
?>