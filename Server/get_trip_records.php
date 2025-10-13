<?php
// 获取行程记录接口
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// 引入数据库连接
include __DIR__ . '/db_connect.php';

// 车型配置信息：型号 => [总里程, 电池容量(kWh)]
$carModels = [
    '330' => ['range' => 330.0, 'battery' => 34.5],
    '405' => ['range' => 405.0, 'battery' => 41.0],
    '505' => ['range' => 505.0, 'battery' => 51.5]
];

define('TOLERANCE_KM', 20.0); // 车型识别误差范围（公里）

// 计算当前电量 - 根据SOC和续航里程推断车型并计算实际kWh
function calculateCurrentKwh($soc, $acOnMile, $carModels) {
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
        return $currentKwh;
    }
    
    // 默认使用405车型
    $defaultKwh = round(41.0 * ($soc / 100.0), 2);
    return $defaultKwh;
}

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
    $pageSize = 30; // 默认每页30条数据
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
    
    // 查询总记录数（只统计已完成的行程）
    $countSql = "SELECT COUNT(*) as total FROM trip_record WHERE vin = ? AND end_time IS NOT NULL";
    $countStmt = $pdo->prepare($countSql);
    $countStmt->execute([$vin]);
    $totalCount = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // 计算总页数
    $totalPages = ceil($totalCount / $pageSize);
    
    // 查询行程记录数据，按开始时间倒序排列，只返回已完成的行程（end_time不为空）
    $sql = "SELECT 
                id,
                vin,
                start_time,
                end_time,
                start_location,
                end_location,
                start_latlng,
                end_latlng,
                start_mileage,
                end_mileage,
                start_range,
                end_range,
                start_soc,
                end_soc,
                created_at,
                updated_at
            FROM trip_record
            WHERE vin = ? AND end_time IS NOT NULL
            ORDER BY start_time DESC 
            LIMIT ? OFFSET ?";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$vin, $pageSize, $offset]);
    $trips = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // 格式化返回数据并计算相关指标
    $formattedTrips = [];
    foreach ($trips as $trip) {
        // 计算行驶里程
        $drivingMileage = $trip['end_mileage'] - $trip['start_mileage'];
        
        // 计算消耗里程（理论里程消耗）
        $consumedMileage = $trip['start_range'] - $trip['end_range'];
        
        // 计算达成率（实际/理论）
        $achievementRate = 0;
        if ($consumedMileage > 0) {
            $achievementRate = ($drivingMileage / $consumedMileage) * 100;
        }
        
        // 计算消耗电量（kWh）
        $startKwh = calculateCurrentKwh($trip['start_soc'], $trip['start_range'], $carModels);
        $endKwh = calculateCurrentKwh($trip['end_soc'], $trip['end_range'], $carModels);
        $powerConsumption = $startKwh - $endKwh;
        
        // 计算历时（分钟）
        $startTime = new DateTime($trip['start_time']);
        $endTime = new DateTime($trip['end_time']);
        $duration = $endTime->diff($startTime);
        $durationMinutes = ($duration->h * 60) + $duration->i;
        
        // 计算平均速度（km/h）
        $averageSpeed = 0;
        if ($durationMinutes > 0) {
            $averageSpeed = ($drivingMileage / $durationMinutes) * 60;
        }
        
        // 计算百公里耗电（kWh/100km）
        $energyEfficiency = 0;
        if ($drivingMileage > 0 && $powerConsumption > 0) {
            $energyEfficiency = ($powerConsumption / $drivingMileage) * 100;
        }
        
        // 格式化历时显示
        $durationText = '';
        if ($duration->h > 0) {
            $durationText .= $duration->h . '小时';
        }
        if ($duration->i > 0) {
            $durationText .= $duration->i . '分钟';
        }
        if (empty($durationText)) {
            $durationText = '不足1分钟';
        }
        
        $formattedTrips[] = [
            'id' => (int)$trip['id'],
            'vin' => $trip['vin'],
            'departureAddress' => $trip['start_location'] ?? '未知地点',
            'destinationAddress' => $trip['end_location'] ?? '未知地点',
            'departureTime' => date('H:i', strtotime($trip['start_time'])),
            'duration' => $durationText,
            'drivingMileage' => round($drivingMileage, 1),
            'consumedMileage' => round($consumedMileage, 1),
            'achievementRate' => round($achievementRate, 1),
            'powerConsumption' => round($powerConsumption, 2),
            'averageSpeed' => round($averageSpeed, 1),
            'energyEfficiency' => round($energyEfficiency, 2),
            'startTime' => $trip['start_time'],
            'endTime' => $trip['end_time'],
            'startLocation' => $trip['start_location'],
            'endLocation' => $trip['end_location'],
            'startLatLng' => $trip['start_latlng'],
            'endLatLng' => $trip['end_latlng'],
            'startMileage' => (float)$trip['start_mileage'],
            'endMileage' => (float)$trip['end_mileage'],
            'startRange' => (float)$trip['start_range'],
            'endRange' => (float)$trip['end_range'],
            'startSoc' => (int)$trip['start_soc'],
            'endSoc' => (int)$trip['end_soc'],
            'createdAt' => $trip['created_at'],
            'updatedAt' => $trip['updated_at']
        ];
    }
    
    // 返回成功响应
    echo json_encode([
        'success' => true,
        'code' => 200,
        'data' => [
            'tasks' => $formattedTrips,
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
        'code' => 500,
        'message' => '数据库查询失败: ' . $e->getMessage()
    ]);
} catch (Exception $e) {
    // 其他系统错误
    echo json_encode([
        'success' => false,
        'code' => 500,
        'message' => '系统错误: ' . $e->getMessage()
    ]);
}
?>