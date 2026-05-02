# 车辆状态字段说明

## keyStatus（钥匙/通电状态）
- `1` = 车辆启动/通电中（ON）
- `2` = 车辆熄火/断电（OFF）

## mainLockStatus（车门锁状态）
- `0` = 已锁车
- `1` = 未锁车（解锁状态）

**重要**：当车辆速度超过 15km/h 时会自动锁车门，所以行驶中的车辆可能是 `keyStatus=1`（通电）且 `mainLockStatus=0`（已锁）的状态。

## chgStatus（充电状态）
- `1` = 慢充中
- `2` = 未充电
- `3` = 快充中

## 状态组合判断

### 行驶中
- `keyStatus=1`（通电）且 `chgStatus=2`（未充电）
- 注意：不能依赖 `mainLockStatus` 判断是否行驶，因为速度超过 15km/h 会自动锁门

### 停车
- `keyStatus=2`（断电）且 `mainLockStatus=0`（已锁）且 `chgStatus=2`（未充电）

### 充电中
- `chgStatus=1`（慢充）或 `chgStatus=3`（快充）

### 行程开始条件
- 从断电变为通电（`keyStatus` 从 2 变为 1）
- 或：当前通电但没有行程记录（服务器重启恢复场景）

### 行程结束条件
- 断电锁车：`keyStatus=2` 且 `mainLockStatus=0`
- 或：开始充电（`chgStatus` 变为 1 或 3）
