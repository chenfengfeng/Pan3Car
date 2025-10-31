# 车辆轮询系统文档

## 系统概述

本系统实现了一个完整的车辆数据轮询和追踪系统，包含以下核心功能：

- 自动轮询车辆状态（每 5 秒一次）
- 检测行驶和充电状态变化
- 记录完整的数据点历史
- 计算车辆速度
- 错误处理和重试机制

## 系统架构

```
用户登录 → vehicles 表
    ↓
轮询服务（每 5 秒）
    ↓
JVC API → 状态检测 → 数据写入
    ↓
drives / charges / data_points 表
```

## 核心组件

### 1. 数据库模块 (`core/database/`)

#### `db.js`
- 数据库连接管理（单例模式）
- WAL 模式启用
- 外键约束支持

#### `init.js`
- 创建 4 张表：vehicles, drives, charges, data_points
- 创建索引优化查询性能

#### `operations.js`
- 封装所有数据库 CRUD 操作
- Vehicles 操作：upsertVehicle, deleteVehicle, getVehiclesDueForPolling, updateVehicleAfterPoll
- Drives 操作：createDrive, updateDrive, getDriveById
- Charges 操作：createCharge, updateCharge, getChargeById
- DataPoints 操作：insertDataPoint

### 2. 轮询服务 (`core/services/polling.service.js`)

#### 核心功能
- **启动服务**: `startPollingService()`
- **停止服务**: `stopPollingService()`
- **轮询间隔**: 5 秒（固定）
- **并发处理**: 使用 `Promise.allSettled` 同时处理多辆车

#### 状态检测规则

**充电状态（优先级高）：**
- 开始充电：`chgStatus` 从非 3 变为 3
- 结束充电：`chgStatus` 从 3 变为 2

**行驶状态：**
- 开始行驶：`keyStatus = 1` 且 `mainLockStatus = 0`
- 结束行驶：`keyStatus = 2` 且 `mainLockStatus = 0`

**优先级规则：**
- 充电 > 行驶
- 如果行驶中开始充电，自动结束行驶记录

#### 错误处理策略

| 错误类型 | 状态 | 下次轮询延迟 |
|---------|------|------------|
| 500 错误 | `error_500` | +5 分钟 |
| 403 错误 | `token_invalid` | +30 天 |
| 其他错误 | `error` | +5 分钟 |

### 3. 工具模块 (`core/utils/geo.js`)

#### 地理计算功能
- `calculateDistance(lat1, lon1, lat2, lon2)` - Haversine 公式计算距离（公里）
- `calculateSpeed(lat1, lon1, timestamp1, lat2, lon2, timestamp2)` - 计算速度（km/h）

### 4. 认证模块修改 (`api/auth/auth.controller.js`)

#### 登录时
- 插入或更新车辆到 `vehicles` 表
- 设置 `internal_state = 'idle'`
- 设置 `next_poll_time = NOW()`（立即开始轮询）

#### 登出时
- 从 `vehicles` 表删除车辆记录（需要传递 `vin` 参数）
- 停止该车辆的轮询

## 数据库表结构

### vehicles（车辆状态/作业表）
```sql
- id: 主键
- vin: 车辆 VIN（唯一）
- api_token: timaToken
- internal_state: 作业状态（idle, active, error_500, token_invalid）
- next_poll_time: 下次轮询时间
- last_keyStatus: 上次钥匙状态
- last_mainLockStatus: 上次锁车状态
- last_chgStatus: 上次充电状态
- last_lat/lon: 上次位置
- last_timestamp: 上次时间戳
- current_drive_id: 当前行程 ID
- current_charge_id: 当前充电 ID
```

### drives（行程记录表）
```sql
- id: 主键
- vin: 关联车辆
- start_time/end_time: 行程时间
- start_lat/lon, end_lat/lon: 位置
- start_soc/end_soc: 电量
- start_range_km/end_range_km: 续航
```

### charges（充电记录表）
```sql
- id: 主键
- vin: 关联车辆
- start_time/end_time: 充电时间
- start_soc/end_soc: 电量
- start_range_km/end_range_km: 续航
- lat/lon: 充电地点
```

### data_points（原始数据点表）
```sql
- id: 主键
- timestamp: 时间戳
- vin: 关联车辆
- lat/lon: GPS 位置
- soc: 电量
- range_km: 续航
- keyStatus: 钥匙状态
- mainLockStatus: 锁车状态
- chgPlugStatus: 充电枪状态
- chgStatus: 充电状态
- chgLeftTime: 充电剩余时间
- calculated_speed_kmh: 计算速度
- drive_id: 关联行程（可空）
- charge_id: 关联充电（可空）
```

## API 使用说明

### 登录（会自动加入轮询队列）
```bash
POST /api/auth/login
Content-Type: application/json

{
  "userCode": "用户名",
  "password": "密码"
}

响应：
{
  "code": 200,
  "data": {
    "vin": "车辆VIN",
    "token": "timaToken",
    "user": { ... }
  }
}
```

### 登出（会从轮询队列移除）
```bash
POST /api/auth/logout
Content-Type: application/json
timaToken: <token>

{
  "no": "用户编号",
  "vin": "车辆VIN"
}

响应：
{
  "code": 200,
  "message": "退出登录成功"
}
```

## 性能优化

1. **数据库优化**
   - 使用 WAL 模式提升并发性能
   - 为常用查询创建索引
   - 使用预编译语句（better-sqlite3 自动）

2. **轮询优化**
   - 使用 setTimeout 递归链避免累积延迟
   - 并发处理多辆车（Promise.allSettled）
   - 单例数据库连接

3. **错误处理**
   - 熔断机制避免频繁失败请求
   - 自动延长错误车辆的轮询间隔

## 监控和日志

系统会输出以下关键日志：

```
[Polling Service] 轮询服务已启动
[Polling Service] 开始轮询 N 辆车辆
[Polling Service] VIN 开始行驶
[Polling Service] VIN 结束行驶
[Polling Service] VIN 开始充电
[Polling Service] VIN 结束充电
[Polling Service] VIN 轮询成功
[Polling Service] VIN 轮询失败: 错误信息
[Auth] 车辆 VIN 已加入轮询队列
[Auth] 车辆 VIN 已从轮询队列移除
```

## 部署说明

1. 确保 Node.js 版本 >= 14
2. 安装依赖：`npm install`
3. 启动服务：`node app.js`
4. 轮询服务会自动启动

## 注意事项

1. **隐私保护**：建议用户定期拉取并删除服务器上的数据
2. **Token 管理**：403 错误会自动延长轮询间隔 30 天
3. **并发限制**：根据服务器性能调整 JVC API 调用频率
4. **数据清理**：定期清理 data_points 表避免数据过大

## 故障排查

### 轮询未启动
- 检查日志是否有 `[Polling Service] 轮询服务已启动`
- 确认数据库初始化成功

### 车辆未被轮询
- 检查 `vehicles` 表中是否有该 VIN
- 检查 `next_poll_time` 是否已过期
- 检查 `internal_state` 是否为错误状态

### API 调用失败
- 检查 timaToken 是否有效
- 检查网络连接
- 查看错误日志确认错误类型

## 未来扩展

- [ ] 添加 WebSocket 实时推送
- [ ] 实现数据归档和清理策略
- [ ] 添加管理后台查看轮询状态
- [ ] 支持动态调整轮询间隔
- [ ] 实现用户级别的数据隔离

