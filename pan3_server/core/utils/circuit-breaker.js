/**
 * 熔断器模式实现
 * 用于防止连续失败时的无效重试，保护系统资源
 */

class CircuitBreaker {
    constructor(options = {}) {
        this.failureThreshold = options.failureThreshold || 5; // 失败阈值
        this.resetTimeout = options.resetTimeout || 60000; // 重置超时时间（毫秒）
        this.monitoringPeriod = options.monitoringPeriod || 10000; // 监控周期（毫秒）
        
        this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
        this.failureCount = 0;
        this.lastFailureTime = null;
        this.successCount = 0;
        this.nextAttempt = Date.now();
    }

    /**
     * 执行受保护的操作
     * @param {Function} operation 要执行的异步操作
     * @param {string} operationName 操作名称（用于日志）
     * @returns {Promise} 操作结果
     */
    async execute(operation, operationName = 'Unknown') {
        if (this.state === 'OPEN') {
            if (Date.now() < this.nextAttempt) {
                const waitTime = Math.round((this.nextAttempt - Date.now()) / 1000);
                throw new Error(`[CircuitBreaker] ${operationName} - 熔断器开启中，请等待 ${waitTime} 秒后重试`);
            } else {
                this.state = 'HALF_OPEN';
                this.successCount = 0;
                console.log(`[CircuitBreaker] ${operationName} - 熔断器进入半开状态，尝试恢复`);
            }
        }

        try {
            const result = await operation();
            this.onSuccess(operationName);
            return result;
        } catch (error) {
            this.onFailure(operationName, error);
            throw error;
        }
    }

    /**
     * 处理操作成功
     */
    onSuccess(operationName) {
        this.failureCount = 0;
        
        if (this.state === 'HALF_OPEN') {
            this.successCount++;
            console.log(`[CircuitBreaker] ${operationName} - 半开状态成功计数: ${this.successCount}`);
            
            // 连续成功3次后关闭熔断器
            if (this.successCount >= 3) {
                this.state = 'CLOSED';
                console.log(`[CircuitBreaker] ${operationName} - 熔断器已关闭，服务恢复正常`);
            }
        }
    }

    /**
     * 处理操作失败
     */
    onFailure(operationName, error) {
        this.failureCount++;
        this.lastFailureTime = Date.now();
                
        if (this.state === 'HALF_OPEN') {
            // 半开状态下失败，立即开启熔断器
            this.state = 'OPEN';
            this.nextAttempt = Date.now() + this.resetTimeout;
            console.log(`[CircuitBreaker] ${operationName} - 半开状态失败，熔断器重新开启`);
        } else if (this.failureCount >= this.failureThreshold) {
            // 达到失败阈值，开启熔断器
            this.state = 'OPEN';
            this.nextAttempt = Date.now() + this.resetTimeout;
            console.log(`[CircuitBreaker] ${operationName} - 达到失败阈值，熔断器开启，${Math.round(this.resetTimeout/1000)}秒后尝试恢复`);
        }
    }

    /**
     * 获取熔断器状态信息
     */
    getStatus() {
        return {
            state: this.state,
            failureCount: this.failureCount,
            successCount: this.successCount,
            lastFailureTime: this.lastFailureTime,
            nextAttempt: this.nextAttempt,
            isAvailable: this.state === 'CLOSED' || (this.state === 'OPEN' && Date.now() >= this.nextAttempt)
        };
    }

    /**
     * 手动重置熔断器
     */
    reset() {
        this.state = 'CLOSED';
        this.failureCount = 0;
        this.successCount = 0;
        this.lastFailureTime = null;
        this.nextAttempt = Date.now();
        console.log('[CircuitBreaker] 熔断器已手动重置');
    }
}

/**
 * APNs推送专用熔断器
 */
class APNsCircuitBreaker extends CircuitBreaker {
    constructor() {
        super({
            failureThreshold: 3, // APNs连接失败3次后熔断
            resetTimeout: 30000, // 30秒后尝试恢复
            monitoringPeriod: 5000 // 5秒监控周期
        });
    }

    /**
     * 执行APNs推送操作
     */
    async executePush(pushOperation, deviceToken) {
        return this.execute(pushOperation, `APNs推送[${deviceToken?.substring(0, 8)}...]`);
    }
}

/**
 * 车辆数据获取专用熔断器
 */
class VehicleDataCircuitBreaker extends CircuitBreaker {
    constructor() {
        super({
            failureThreshold: 5, // 车辆数据获取失败5次后熔断
            resetTimeout: 60000, // 60秒后尝试恢复
            monitoringPeriod: 10000 // 10秒监控周期
        });
    }

    /**
     * 执行车辆数据获取操作
     */
    async executeVehicleDataFetch(fetchOperation, vin) {
        return this.execute(fetchOperation, `车辆数据获取[${vin}]`);
    }
}

export { CircuitBreaker, APNsCircuitBreaker, VehicleDataCircuitBreaker };