# API 路由设计说明

**更新日期：** 2025-01-14

---

## 📍 模块职责划分

### `/api/auth/` - 认证和配置管理模块

**职责：**
- 用户登录/注销
- **车辆配置管理**
- 用户信息获取

**接口：**
```
POST /api/auth/login              # 用户登录
POST /api/auth/logout             # 用户注销
POST /api/auth/updatePushToken    # 更新推送Token配置 ← 这里！
```

**为什么 updatePushToken 在这里？**
- ✅ **配置管理**：管理 vehicles 表的 push_token 配置
- ✅ **一致性**：与 login/logout 同属用户/车辆配置
- ✅ **语义清晰**：`/api/auth/updatePushToken` 语义明确

---

### `/api/push/` - 推送执行模块

**职责：**
- **执行推送操作**
- 发送通知到 APNs
- Live Activity 更新

**接口：**
```
POST /api/push/                   # 发送标准推送
POST /api/push/send               # 发送推送（别名）
POST /api/push/car-data           # 发送车辆数据推送
POST /api/push/live-activity      # 发送Live Activity
```

**为什么没有 updatePushToken？**
- ❌ **不是推送操作**：只是配置管理
- ❌ **职责不同**：不发送通知，只更新数据库
- ❌ **模块混乱**：会混淆"配置"和"执行"

---

### `/api/car/` - 车辆控制模块

**职责：**
- 车辆信息查询
- 车辆控制操作
- 充电控制

**接口：**
```
POST /api/car/info                # 获取车辆信息
POST /api/car/control             # 车辆控制
POST /api/car/stopCharging        # 停止充电
```

---

### `/api/charge/` - 充电监控模块

**职责：**
- 充电任务管理
- 充电监控启动/停止

**接口：**
```
POST /api/charge/startMonitoring  # 启动监控
POST /api/charge/stopMonitoring   # 停止监控
POST /api/charge/updateToken      # 更新Live Activity Token
```

---

## 🔄 数据流示例

### 场景：用户注册推送 Token

**步骤 1：用户登录**
```javascript
POST /api/auth/login
→ 返回 vin, timaToken
```

**步骤 2：更新推送 Token**
```javascript
POST /api/auth/updatePushToken
{
  "vin": "LSJXXXX",
  "pushToken": "xxx"
}
→ 更新 vehicles.push_token
```

**步骤 3：充电完成自动推送**
```javascript
轮询服务检测充电结束
→ 读取 vehicles.push_token
→ 调用内部推送服务
→ 用户收到通知
```

---

## 📊 架构对比

| 方案 | 路由位置 | 优势 | 劣势 |
|------|---------|------|------|
| **方案 A（当前）** | `/api/auth/updatePushToken` | ✅ 配置管理语义清晰<br>✅ 模块职责明确 | - |
| 方案 B | `/api/push/updateToken` | ⚠️ 直观 | ❌ 不是推送操作<br>❌ 混淆配置和执行 |
| 方案 C | `/api/car/updatePushToken` | ⚠️ 车辆相关 | ❌ 不是车辆控制<br>❌ 配置vs控制混淆 |

---

## ✅ 设计原则

**1. 单一职责**
- 每个模块只负责一类操作
- 配置 ≠ 执行

**2. 语义清晰**
- 路径名明确表达功能
- RESTful 命名规范

**3. 高内聚低耦合**
- 相关操作放在同一模块
- 避免跨模块依赖

---

**结论：当前设计合理，无需改动。** ✅

`updatePushToken` 属于**配置管理**，应该放在 `/api/auth/` 而不是 `/api/push/`。

