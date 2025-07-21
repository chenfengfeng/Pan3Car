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
// 获取用户提交的 charge_kwh (用户要充的电量)
$charge_kwh = floatval($params['charge_kwh']);
// 获取服务器参数
$server = $params['server'] ?? '';

// 根据server参数选择API基础地址
$baseApiUrl = ($server === 'spare') ? 'https://yiweiauto.cn' : 'https://jacsupperapp.jac.com.cn';

// 验证必要参数
if (empty($vin) || empty($token) || empty($charge_kwh)) {
    echo json_encode(['code' => 400, 'msg' => '参数不完整']);
    exit;
}

try {
    // 1. 检查当前vin是否有正在运行的任务
    $stmt = $pdo->prepare("SELECT id FROM charge_task WHERE vin = ? AND status = 'pending'");
    $stmt->execute([$vin]);
    $existingTask = $stmt->fetch();
    
    if ($existingTask) {
        echo json_encode(['code' => 409, 'msg' => '当前车辆已有正在运行的充电任务，无法重复创建']);
        exit;
    }
    
    // 2. 通过API获取车辆信息
    $carInfoUrl = $baseApiUrl . '/api/jac-energy/jacenergy/vehicleInformation/energy-query-vehicle-new-condition';
    $carInfoData = [
        'vins' => [$vin]
    ];
    
    $carInfoHeaders = [
        'Content-Type: application/json',
        'timaToken: ' . $token
    ];
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $carInfoUrl);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($carInfoData));
    curl_setopt($ch, CURLOPT_HTTPHEADER, $carInfoHeaders);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    
    $carInfoResponse = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($carInfoResponse === false || $httpCode !== 200) {
        echo json_encode(['code' => 500, 'msg' => '获取车辆信息失败']);
        exit;
    }
    
    $carInfo = json_decode($carInfoResponse, true);
    if (!$carInfo || !$carInfo['returnSuccess']) {
        $errorMsg = isset($carInfo['returnErrMsg']) ? $carInfo['returnErrMsg'] : '获取车辆信息失败';
        echo json_encode(['code' => 500, 'msg' => $errorMsg]);
        exit;
    }
    
    // 车型配置信息：型号 => [总里程, 电池容量(kWh)]
    $carModels = [
        '330' => ['range' => 330.0, 'battery' => 34.5],
        '405' => ['range' => 405.0, 'battery' => 41.0],
        '505' => ['range' => 505.0, 'battery' => 51.5]
    ];
    
    // 获取当前电量和里程
    $initialKwh = null;
    $initialKm = null;
    $detectedModel = null;
    
    if (isset($carInfo['data']) && is_array($carInfo['data'])) {
        $vehicleData = $carInfo['data'];
        
        if (isset($vehicleData['soc']) && isset($vehicleData['acOnMile'])) {
            $soc = intval($vehicleData['soc']); // SOC百分比
            $acOnMile = intval($vehicleData['acOnMile']); // 空调开启里程（当前续航里程）
            $initialKm = $acOnMile; // 初始里程（剩余里程）
            
            // 根据当前续航里程推断车型
            $minDifference = PHP_FLOAT_MAX;
            
            // 计算理论满电续航里程
            $estimatedFullMileage = ($soc > 0) ? ($acOnMile / ($soc / 100.0)) : 0;
            
            foreach ($carModels as $model => $config) {
                $difference = abs($config['range'] - $estimatedFullMileage);
                
                // 允许20km的误差范围
                $tolerance = 20.0;
                
                if ($difference <= $tolerance && $difference < $minDifference) {
                    $minDifference = $difference;
                    $detectedModel = $model;
                }
            }
            
            // 如果无法精确匹配，选择最接近的车型
            if ($detectedModel === null) {
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
                $batteryCapacity = floatval($carModels[$detectedModel]['battery']);
                $initialKwh = round($batteryCapacity * ($soc / 100.0), 2);
            } else {
                // 如果无法确定车型，使用默认计算（假设405车型）
                $initialKwh = round(41.0 * ($soc / 100.0), 2);
                $detectedModel = '405'; // 设置默认车型
            }
        }
    }
    
    // 3. 计算目标电量和目标里程
    $targetKwh = $initialKwh + $charge_kwh; // 目标电量 = 初始电量 + 用户设置要充的电
    $targetKm = null;
    if ($detectedModel && isset($carModels[$detectedModel]) && $initialKm !== null) {
        $batteryCapacity = floatval($carModels[$detectedModel]['battery']);
        $maxRange = floatval($carModels[$detectedModel]['range']);
        
        // 计算每kWh能增加的里程数
        $kmPerKwh = $maxRange / $batteryCapacity;
        
        // 计算充电后增加的里程
        $additionalKm = round($charge_kwh * $kmPerKwh, 0);
        
        // 目标里程 = 初始里程 + 增加的里程
        $targetKm = $initialKm + $additionalKm;
    }
    
    // 4. 根据充电状态设置任务状态
    $taskStatus = 'pending';
    $taskMessage = '正在充电中...';
    if (isset($carInfo['data']['chgStatus']) && intval($carInfo['data']['chgStatus']) == 2) {
        $taskStatus = 'ready';
        $taskMessage = '已准备好充电';
    }
    
    // 插入新的充电任务
    $stmt = $pdo->prepare("
        INSERT INTO charge_task (vin, token, initial_kwh, target_kwh, charged_kwh, initial_km, target_km, status, message) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    
    $result = $stmt->execute([$vin, $token, $initialKwh, $targetKwh, 0, $initialKm, $targetKm, $taskStatus, $taskMessage]);
    
    if ($result) {
        $taskId = $pdo->lastInsertId();
        echo json_encode([
            'code' => 200, 
            'msg' => '充电任务创建成功',
            'data' => [
                'id' => $taskId,
                'vin' => $vin,
                'initialKwh' => $initialKwh,
                'targetKwh' => $targetKwh,
                'chargedKwh' => 0,
                'initialKm' => $initialKm,
                'targetKm' => $targetKm,
                'status' => $taskStatus,
                'message' => '已准备好充电',
                'createdAt' => date('Y-m-d H:i:s')
            ]
        ]);
    } else {
        echo json_encode(['code' => 500, 'msg' => '创建充电任务失败']);
    }
    
} catch (PDOException $e) {
    echo json_encode(['code' => 500, 'msg' => '数据库错误: ' . $e->getMessage()]);
} catch (Exception $e) {
    echo json_encode(['code' => 500, 'msg' => '系统错误: ' . $e->getMessage()]);
}
?>

