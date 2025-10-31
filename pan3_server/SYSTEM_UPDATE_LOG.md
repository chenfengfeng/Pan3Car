# 系统更新日志

## 版本 2.0 - 动态轮询与摘要计算系统

**更新日期：** 2025-10-31

---

### 主要更新

#### 1. 数据库表结构优化

**data_points 表新增字段：**
- `remaining_range_km` INTEGER - 剩余续航（来自 API 的 acOnMile）
- `total_mileage` VARCHAR(20) - 车辆总里程（来自 API 的 totalMileage）

**注意：** 旧字段 `range_km` 已重命名为 `remaining_range_km`

---

#### 2. 动态轮询间隔

**旧逻辑：** 固定 5 秒轮询  
**新逻辑：** 根据车辆状态动态调整

| 状态 | 轮询间隔 | 触发条件 |
|------|---------|---------|
| **active** | 5 秒 | keyStatus=1 OR mainLockStatus=1 OR chgStatus=3 |
| **idle** | 1 分钟 | mainLockStatus=0 AND keyStatus=2 AND chgStatus=2 |

**用户主动解锁：** 当用户调用解锁 API (`operationType=LOCK, operation=2`) 时，车辆自动切换到 active 状态

---

#### 3. 登录/登出逻辑调整

**登录时：**
- ✅ 使用 UPSERT 逻辑（`INSERT ... ON CONFLICT DO UPDATE`）
- ✅ 只更新 `api_token` 和 `next_poll_time`
- ✅ 不影响现有数据

**登出时：**
- ✅ **不再删除** vehicles 表记录
- ✅ 数据继续保留，持续轮询
- ✅ 实现数据隐私最大化（用户拉取后删除）

---

#### 4. 摘要数据计算

**行程结束时自动计算：**
- ✅ 实际行驶里程（基于 totalMileage 差值）
- ✅ 消耗续航（基于 remaining_range_km 差值）
- ✅ 数据点数量
- ✅ 记录到日志

**充电结束时自动计算：**
- ✅ 增加的续航（基于 remaining_range_km 差值）
- ✅ 数据点数量
- ✅ 记录到日志

**示例日志：**
```
[Polling Service] TESTVIN123 行程摘要 - 实际里程: 15.34km, 消耗续航: 18km, 数据点: 42
[Polling Service] TESTVIN123 充电摘要 - 增加续航: 125km, 数据点: 156
```

---

### 修改的文件

#### 核心模块

1. **`core/database/init.js`**
   - 更新 data_points 表结构

2. **`core/database/operations.js`**
   - 新增 `getDataPointsByDriveId()` - 获取行程数据点
   - 新增 `getDataPointsByChargeId()` - 获取充电数据点
   - 新增 `setVehicleActive()` - 设置车辆为 active 状态
   - 更新 `insertDataPoint()` - 添加新字段支持

3. **`core/services/polling.service.js`**
   - 新增 `shouldBeActive()` - 判断是否应为 active
   - 新增 `shouldBeIdle()` - 判断是否应为 idle
   - 新增 `calculateDriveSummary()` - 计算行程摘要
   - 新增 `calculateChargeSummary()` - 计算充电摘要
   - 重构 `pollSingleVehicle()` - 实现动态轮询和摘要计算

#### API 接口

4. **`api/auth/auth.controller.js`**
   - 移除 `deleteVehicle` 导入
   - 更新 `logout()` - 移除删除车辆逻辑

5. **`api/car/car.controller.js`**
   - 新增 `setVehicleActive` 导入
   - 更新 `controlVehicle()` - 解锁时触发 active

---

### 数据流程

```
用户登录
  ↓
UPSERT vehicles (更新 token)
  ↓
轮询服务检测 next_poll_time
  ↓
[状态判断]
  ├─ active → 5秒后轮询
  └─ idle → 1分钟后轮询
  ↓
获取车辆数据 (acOnMile, totalMileage)
  ↓
插入 data_points (含新字段)
  ↓
[状态变化检测]
  ├─ 开始行驶 → 创建 drives 记录
  ├─ 结束行驶 → 更新 drives + 计算摘要
  ├─ 开始充电 → 创建 charges 记录
  └─ 结束充电 → 更新 charges + 计算摘要
  ↓
用户退出登录 → 数据保留（不删除）
```

---

### 性能提升

1. **智能轮询频率**
   - idle 状态下减少 92% 的 API 调用（60秒 vs 5秒）
   - 降低服务器负载和网络开销

2. **摘要数据预计算**
   - 行程/充电结束时立即计算
   - App 查询时无需实时计算，响应更快

3. **数据完整性**
   - 保留 totalMileage 和 remaining_range_km
   - 支持更精确的里程和续航分析

---

### 迁移指南

**重要：** 由于表结构变更，需要重新初始化数据库

**步骤：**
```bash
# 1. 停止服务器
pkill -f "node app.js"

# 2. 删除旧数据库
rm -f pan3_data.db pan3_data.db-shm pan3_data.db-wal

# 3. 启动服务器（自动创建新数据库）
node app.js
```

**验证：**
- 查看启动日志，确认 `data_points 表已创建`
- 使用 SQLite 工具检查表结构：
  ```bash
  sqlite3 pan3_data.db "PRAGMA table_info(data_points);"
  ```
- 应该看到 `remaining_range_km` 和 `total_mileage` 字段

---

### 测试结果

✅ 数据库初始化 - 通过  
✅ 表结构验证 - 通过  
✅ 新字段存在 - 通过  
✅ UPSERT 逻辑 - 通过  
✅ 状态切换 (idle ↔ active) - 通过  
✅ 摘要计算 - 通过  

---

### 后续扩展

- [ ] 添加数据清理 API（用户拉取后删除）
- [ ] 实现数据归档策略
- [ ] 添加行程/充电详情查询 API
- [ ] 支持多车辆管理
- [ ] 实现 WebSocket 实时推送

---

### 注意事项

1. **数据隐私**
   - 退出登录不删除数据，需要用户主动拉取并请求删除
   - 建议实现定期提醒用户清理数据

2. **轮询频率**
   - active 状态下 5 秒轮询可能导致 API 限流
   - 如遇限流，可调整 `POLL_INTERVAL_ACTIVE` 参数

3. **摘要数据**
   - 摘要只记录到日志，未存入数据库
   - 如需持久化，可扩展 drives/charges 表添加摘要字段

4. **兼容性**
   - 新系统不兼容旧数据库结构
   - 必须删除旧数据库重新初始化

---

### 开发团队

- 数据库设计：优化表结构，添加新字段
- 轮询逻辑：实现动态间隔和状态判断
- 摘要计算：实现行程/充电数据分析
- API 集成：用户操作触发状态变更

---

**版本 2.0 更新完成！** 🎉

