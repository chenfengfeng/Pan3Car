<?php

/**
 * APNs 推送配置 Web 测试页面
 * 通过浏览器访问此页面来测试 JWT Token 生成和配置
 */

header('Content-Type: text/html; charset=utf-8');

require_once __DIR__ . '/apns_jwt_generator.php';

// 配置信息
define('APNS_ENVIRONMENT', 'sandbox');
define('APNS_BUNDLE_ID', 'com.dream.car.pan3'); // 需要替换为实际的 Bundle ID
define('APNS_TEAM_ID', '2WP22Y7RSK');
define('APNS_KEY_ID', 'K2U7MRND45');
define('APNS_PRIVATE_KEY_PATH', __DIR__ . '/AuthKey_K2U7MRND45.p8');

?>
<!DOCTYPE html>
<html>
<head>
    <title>APNs 推送配置测试</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .success { color: #28a745; }
        .error { color: #dc3545; }
        .warning { color: #ffc107; }
        .info { color: #17a2b8; }
        .test-section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .test-title { font-size: 18px; font-weight: bold; margin-bottom: 10px; }
        pre { background: #f8f9fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
        .config-item { margin: 5px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>APNs 推送配置测试</h1>
        <p>测试时间: <?php echo date('Y-m-d H:i:s'); ?></p>
        
        <div class="test-section">
            <div class="test-title">1. 私钥文件检查</div>
            <?php
            if (file_exists(APNS_PRIVATE_KEY_PATH)) {
                echo '<div class="success">✓ 私钥文件存在: ' . APNS_PRIVATE_KEY_PATH . '</div>';
                
                $perms = fileperms(APNS_PRIVATE_KEY_PATH);
                $octal = substr(sprintf('%o', $perms), -4);
                echo '<div class="info">文件权限: ' . $octal . '</div>';
                
                if ($octal === '0600' || $octal === '0644') {
                    echo '<div class="success">✓ 文件权限正确</div>';
                } else {
                    echo '<div class="warning">⚠ 建议设置文件权限为 600</div>';
                }
            } else {
                echo '<div class="error">✗ 私钥文件不存在: ' . APNS_PRIVATE_KEY_PATH . '</div>';
            }
            ?>
        </div>
        
        <div class="test-section">
            <div class="test-title">2. JWT Token 生成测试</div>
            <?php
            $token = getAPNsJWTToken();
            if ($token) {
                echo '<div class="success">✓ JWT Token 生成成功</div>';
                echo '<div class="info">Token 长度: ' . strlen($token) . ' 字符</div>';
                echo '<div class="info">Token 前缀: ' . substr($token, 0, 50) . '...</div>';
                
                // 验证 Token 格式
                $parts = explode('.', $token);
                if (count($parts) === 3) {
                    echo '<div class="success">✓ Token 格式正确 (3 部分)</div>';
                    
                    // 解析 Header
                    $header = json_decode(base64_decode(strtr($parts[0], '-_', '+/')), true);
                    if ($header && isset($header['alg']) && $header['alg'] === 'ES256') {
                        echo '<div class="success">✓ Header 正确 (ES256 算法)</div>';
                    }
                    
                    // 解析 Payload
                    $payload = json_decode(base64_decode(strtr($parts[1], '-_', '+/')), true);
                    if ($payload && isset($payload['iss']) && $payload['iss'] === APNS_TEAM_ID) {
                        echo '<div class="success">✓ Payload 正确 (Team ID 匹配)</div>';
                        echo '<div class="info">过期时间: ' . date('Y-m-d H:i:s', $payload['exp']) . '</div>';
                    }
                } else {
                    echo '<div class="error">✗ Token 格式错误</div>';
                }
            } else {
                echo '<div class="error">✗ JWT Token 生成失败</div>';
            }
            ?>
        </div>
        
        <div class="test-section">
            <div class="test-title">3. 配置信息</div>
            <div class="config-item"><strong>环境:</strong> <?php echo APNS_ENVIRONMENT; ?></div>
            <div class="config-item"><strong>Bundle ID:</strong> <?php echo APNS_BUNDLE_ID; ?></div>
            <div class="config-item"><strong>Team ID:</strong> <?php echo APNS_TEAM_ID; ?></div>
            <div class="config-item"><strong>Key ID:</strong> <?php echo APNS_KEY_ID; ?></div>
            <div class="config-item"><strong>APNs 服务器:</strong> 
                <?php echo APNS_ENVIRONMENT === 'production' ? 'https://api.push.apple.com' : 'https://api.sandbox.push.apple.com'; ?>
            </div>
            
            <?php if (APNS_BUNDLE_ID === 'com.yourcompany.Pan3'): ?>
            <div class="warning">⚠ 请修改 APNS_BUNDLE_ID 为实际的应用 Bundle ID</div>
            <?php endif; ?>
        </div>
        
        <div class="test-section">
            <div class="test-title">4. 系统信息</div>
            <div class="config-item"><strong>PHP 版本:</strong> <?php echo PHP_VERSION; ?></div>
            <div class="config-item"><strong>OpenSSL 支持:</strong> 
                <?php echo extension_loaded('openssl') ? '<span class="success">✓ 已启用</span>' : '<span class="error">✗ 未启用</span>'; ?>
            </div>
            <div class="config-item"><strong>cURL 支持:</strong> 
                <?php echo extension_loaded('curl') ? '<span class="success">✓ 已启用</span>' : '<span class="error">✗ 未启用</span>'; ?>
            </div>
            <div class="config-item"><strong>JSON 支持:</strong> 
                <?php echo extension_loaded('json') ? '<span class="success">✓ 已启用</span>' : '<span class="error">✗ 未启用</span>'; ?>
            </div>
        </div>
        
        <div class="test-section">
            <div class="test-title">5. 下一步操作</div>
            <ol>
                <li>修改 <code>APNS_BUNDLE_ID</code> 为实际的应用 Bundle ID</li>
                <li>在 iOS 端获取 Live Activity 的 push token</li>
                <li>将 push token 发送到服务器并存储到数据库</li>
                <li>运行充电任务监控脚本进行实际测试</li>
                <li>生产环境时将 <code>APNS_ENVIRONMENT</code> 改为 'production'</li>
            </ol>
        </div>
        
        <?php if ($token): ?>
        <div class="test-section">
            <div class="test-title">6. 完整 JWT Token（用于调试）</div>
            <pre style="word-break: break-all; white-space: pre-wrap;"><?php echo htmlspecialchars($token); ?></pre>
        </div>
        <?php endif; ?>
    </div>
</body>
</html>