<?php
// 包含数据库连接代码,外部属性：$pdo
include $_SERVER['DOCUMENT_ROOT'] . '/db_connect.php';
// 包含车辆API函数
include $_SERVER['DOCUMENT_ROOT'] . '/vehicle_api.php';
// 主逻辑
header('Content-Type: application/json');

$params = json_decode(file_get_contents('php://input'), true);
if (empty($params)) {
    echo json_encode(['code' => 500, 'msg' => 'Decryption failed']);
    exit;
}

// 获取用户提交的 vin 和 token
$vin = $params['vin'];
$token = $params['token'];
$push_token = $params['push_token'] ?? '';
// 获取服务器参数
$server = $params['server'] ?? '';

// 根据server参数选择API基础地址
$baseApiUrl = ($server === 'spare') ? 'https://yiweiauto.cn' : 'https://jacsupperapp.jac.com.cn';

// 验证必要参数
if (empty($vin) || empty($token)) {
    echo json_encode(['code' => 400, 'msg' => '参数不完整，缺少vin或token']);
    exit;
}

try {
    // 1. 先调用停止充电的API
    $stopChargeUrl = $baseApiUrl . '/api/jac-energy/jacenergy/vehicleControl/energy-remote-vehicle-control';
    $stopChargeData = [
        'operation' => 1,
        'extParams' => [
            'bookTime' => 0
        ],
        'vin' => $vin,
        'operationType' => 'RESERVATION_RECHARGE'
    ];
    
    $stopChargeHeaders = [
        'Content-Type: application/json',
        'timaToken: ' . $token
    ];
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $stopChargeUrl);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($stopChargeData));
    curl_setopt($ch, CURLOPT_HTTPHEADER, $stopChargeHeaders);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    
    $stopChargeResponse = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($stopChargeResponse === false || $httpCode !== 200) {
        echo json_encode(['code' => 500, 'msg' => '调用停止充电API失败']);
        exit;
    }
    
    $stopChargeResult = json_decode($stopChargeResponse, true);
    if (!$stopChargeResult || !$stopChargeResult['returnSuccess']) {
        $errorMsg = isset($stopChargeResult['returnErrMsg']) ? $stopChargeResult['returnErrMsg'] : '停止充电失败';
        echo json_encode(['code' => 500, 'msg' => $errorMsg]);
        exit;
    }
    
    // 2. API调用成功后，查询数据库中是否有充电中的任务（状态为pending）
    $stmt = $pdo->prepare("
        SELECT id, status 
        FROM charge_task 
        WHERE vin = ? AND status = 'pending'
        ORDER BY create_time DESC 
        LIMIT 1
    ");
    $stmt->execute([$vin]);
    $chargingTask = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($chargingTask) {
        // 3. 如果有充电中的任务，更新状态为done
        $updateStmt = $pdo->prepare("
            UPDATE charge_task 
            SET status = 'done', 
                message = '用户主动停止充电',
                finish_time = NOW()
            WHERE id = ?
        ");
        
        $updateResult = $updateStmt->execute([$chargingTask['id']]);
        
        if ($updateResult) {
            // 停止充电成功后，获取车辆状态（行程记录现在自动处理）
            try {
                $vehicleData = getVehicleInfoForCLI($vin, $token, $push_token, $server);
                if ($vehicleData && isset($vehicleData['mainLockStatus'])) {
                    // 行程记录现在通过getVehicleInfoForCLI自动处理
                    error_log("[TRIP_RECORD] 停止充电后车辆状态同步完成，VIN: $vin, lockStatus: {$vehicleData['mainLockStatus']}");
                } else {
                    error_log("[TRIP_RECORD] 停止充电后无法获取车辆状态，VIN: $vin");
                }
            } catch (Exception $e) {
                error_log("[TRIP_RECORD] 停止充电后车辆状态同步异常，VIN: $vin, Error: " . $e->getMessage());
            }
            
            echo json_encode([
                'code' => 200,
                'msg' => '充电已成功停止',
                'data' => [
                    'operation_id' => isset($stopChargeResult['operationId']) ? $stopChargeResult['operationId'] : null,
                    'task_id' => (int)$chargingTask['id'],
                    'vin' => $vin,
                    'status' => 'done'
                ]
            ]);
        } else {
            echo json_encode(['code' => 500, 'msg' => '更新充电任务状态失败']);
        }
    } else {
        // 没有找到充电中的任务，但API调用成功
        echo json_encode([
            'code' => 200,
            'msg' => '停止充电指令已发送，但未找到对应的充电任务',
            'data' => [
                'operation_id' => isset($stopChargeResult['operationId']) ? $stopChargeResult['operationId'] : null,
                'vin' => $vin,
                'status' => 'stopped'
            ]
        ]);
    }
    
} catch (PDOException $e) {
    echo json_encode(['code' => 500, 'msg' => '数据库错误: ' . $e->getMessage()]);
} catch (Exception $e) {
    echo json_encode(['code' => 500, 'msg' => '系统错误: ' . $e->getMessage()]);
}
?>