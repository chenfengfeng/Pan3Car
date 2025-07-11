<?php

/**
 * APNs JWT Token 生成器
 * 用于生成 Apple Push Notification service 的 JWT 认证 Token
 */

class APNsJWTGenerator {
    private $teamId;
    private $keyId;
    private $privateKeyPath;
    
    public function __construct($teamId, $keyId, $privateKeyPath) {
        $this->teamId = $teamId;
        $this->keyId = $keyId;
        $this->privateKeyPath = $privateKeyPath;
    }
    
    /**
     * 生成 JWT Token
     * @param int $expiration Token 过期时间（秒），默认 1 小时
     * @return string|false JWT Token 或 false（失败时）
     */
    public function generateToken($expiration = 3600) {
        if (!file_exists($this->privateKeyPath)) {
            error_log("私钥文件不存在: {$this->privateKeyPath}");
            return false;
        }
        
        $privateKey = file_get_contents($this->privateKeyPath);
        if (!$privateKey) {
            error_log("无法读取私钥文件");
            return false;
        }
        
        $header = [
            'alg' => 'ES256',
            'kid' => $this->keyId
        ];
        
        $payload = [
            'iss' => $this->teamId,
            'iat' => time(),
            'exp' => time() + $expiration
        ];
        
        $headerEncoded = $this->base64UrlEncode(json_encode($header));
        $payloadEncoded = $this->base64UrlEncode(json_encode($payload));
        
        $data = $headerEncoded . '.' . $payloadEncoded;
        
        // 使用 ES256 算法签名
        $signature = '';
        $success = openssl_sign($data, $signature, $privateKey, OPENSSL_ALGO_SHA256);
        
        if (!$success) {
            error_log("JWT 签名失败");
            return false;
        }
        
        $signatureEncoded = $this->base64UrlEncode($signature);
        
        return $data . '.' . $signatureEncoded;
    }
    
    /**
     * Base64 URL 编码
     */
    private function base64UrlEncode($data) {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
    
    /**
     * 验证 Token 是否有效（简单检查）
     */
    public function isTokenValid($token) {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return false;
        }
        
        $payload = json_decode(base64_decode(strtr($parts[1], '-_', '+/')), true);
        if (!$payload || !isset($payload['exp'])) {
            return false;
        }
        
        return $payload['exp'] > time();
    }
}

/**
 * 获取 APNs JWT Token
 * @return string|false
 */
function getAPNsJWTToken() {
    static $cachedToken = null;
    static $tokenExpiry = 0;
    
    // 如果缓存的 Token 还有效，直接返回
    if ($cachedToken && time() < $tokenExpiry - 300) { // 提前 5 分钟刷新
        return $cachedToken;
    }
    
    $teamId = '2WP22Y7RSK';
    $keyId = 'K2U7MRND45';
    $privateKeyPath = __DIR__ . '/AuthKey_K2U7MRND45.p8';
    
    $generator = new APNsJWTGenerator($teamId, $keyId, $privateKeyPath);
    $token = $generator->generateToken(3600); // 1 小时有效期
    
    if ($token) {
        $cachedToken = $token;
        $tokenExpiry = time() + 3600;
        return $token;
    }
    
    return false;
}

// 如果直接运行此文件，生成并输出 Token（用于测试）
if (basename(__FILE__) === basename($_SERVER['SCRIPT_NAME'])) {
    $token = getAPNsJWTToken();
    if ($token) {
        echo "APNs JWT Token 生成成功:\n";
        echo $token . "\n";
        echo "\nToken 长度: " . strlen($token) . " 字符\n";
        echo "生成时间: " . date('Y-m-d H:i:s') . "\n";
    } else {
        echo "APNs JWT Token 生成失败\n";
        exit(1);
    }
}

?>