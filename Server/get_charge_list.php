<?php
// 主逻辑
header('Content-Type: application/json');
// 引入数据库连接
include $_SERVER['DOCUMENT_ROOT'] . '/db_connect.php';

try {
    // 获取请求参数
    $params = json_decode(file_get_contents('php://input'), true);
    
    // 验证必需参数
    if (!isset($params['vin']) || empty($params['vin'])) {
        echo json_encode([
            'success' => false,
            'code' => 400,
            'message' => 'VIN参数不能为空'
        ]);
        exit;
    }
    
    $vin = $params['vin'];
    $page = isset($params['page']) ? (int)$params['page'] : 1;
    // 获取服务器参数
    $server = $params['server'] ?? '';
    
    // 根据server参数选择API基础地址
    $baseApiUrl = ($server === 'spare') ? 'https://yiweiauto.cn' : 'https://jacsupperapp.jac.com.cn';
    $pageSize = 20; // 每页20条数据
    $offset = ($page - 1) * $pageSize;
    
    // 验证页码
    if ($page < 1) {
        echo json_encode([
            'success' => false,
            'code' => 400,
            'message' => '页码必须大于0'
        ]);
        exit;
    }
    
    // 查询总记录数
    $countSql = "SELECT COUNT(*) as total FROM charge_task WHERE vin = ?";
    $countStmt = $pdo->prepare($countSql);
    $countStmt->execute([$vin]);
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // 计算总页数
    $totalPages = ceil($totalCount / $pageSize);
    
    // 查询充电任务历史数据，按创建时间倒序排列
    $sql = "SELECT 
                id,
                vin,
                initial_kwh,
                target_kwh,
                charged_kwh,
                initial_km,
                target_km,
                status,
                message,
                create_time,
                finish_time
            FROM charge_task 
            WHERE vin = ? 
            ORDER BY create_time DESC 
            LIMIT ? OFFSET ?";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$vin, $pageSize, $offset]);
    $tasks = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 格式化返回数据
    $formattedTasks = [];
    foreach ($tasks as $task) {
        $formattedTasks[] = [
            'id' => (int)$task['id'],
            'vin' => $task['vin'],
            'initialKwh' => (float)$task['initial_kwh'],
            'targetKwh' => (float)$task['target_kwh'],
            'chargedKwh' => (float)$task['charged_kwh'],
            'initialKm' => (float)$task['initial_km'],
            'targetKm' => (float)$task['target_km'],
            'status' => $task['status'],
            'message' => $task['message'],
            'createTime' => $task['create_time'],
            'finishTime' => $task['finish_time']
        ];
    }
    
    // 返回成功响应
    echo json_encode([
        'success' => true,
        'code' => 200,
        'data' => [
            'tasks' => $formattedTasks,
            'pagination' => [
                'current_page' => $page,
                'total_pages' => $totalPages,
                'total_count' => (int)$totalCount,
                'page_size' => $pageSize,
                'has_next' => $page < $totalPages,
                'has_prev' => $page > 1
            ]
        ]
    ]);
    
} catch (PDOException $e) {
    // 数据库错误
    echo json_encode([
        'success' => false,
        'message' => '数据库查询失败: ' . $e->getMessage()
    ]);
} catch (Exception $e) {
    // 其他系统错误
    echo json_encode([
        'success' => false,
        'message' => '系统错误: ' . $e->getMessage()
    ]);
}
?>