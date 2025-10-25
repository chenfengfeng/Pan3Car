# Pan3 充电管理应用

## 项目概述

Pan3 是一个iOS充电管理应用，支持充电任务的创建、监控和管理，并集成了iOS 16.1+ 的实时活动（Live Activities）功能，可在锁屏界面和灵动岛显示充电进度。

## 主要功能

### 1. 充电任务管理
- 创建充电任务
- 查看充电任务列表
- 监控充电进度
- 停止/取消充电任务

### 2. 实时活动（Live Activities）
- **锁屏界面显示**：显示充电状态、进度条、电量信息
- **灵动岛紧凑界面**：左侧电池图标，右侧充电百分比
- **灵动岛展开界面**：详细充电信息，包括里程、电量、进度条
- **自动状态管理**：根据充电任务状态自动启动、更新、结束实时活动

## 技术架构

### 核心组件

1. **ChargeViewController**: 充电控制界面
2. **ChargeListController**: 充电任务列表
3. **LiveActivityManager**: 实时活动管理器
4. **CarWidgetLiveActivity**: 实时活动UI组件
5. **NetworkManager**: 网络请求管理

### 数据模型

```swift
// 充电任务模型
struct ChargeTaskModel {
    let id: Int
    let vin: String
    let initialKwh: Double
    let targetKwh: Double
    let chargedKwh: Double
    let initialKm: Double
    let targetKm: Double
    let status: String
    let message: String?
    let createdAt: String
    let finishTime: String?
}

// 实时活动属性
struct CarWidgetAttributes: ActivityAttributes {
    let taskId: Int
    let vin: String
    let createdAt: String
    let initialKm: Double
    let targetKm: Double
    let initialKwh: Double
    let targetKwh: Double
    
    struct ContentState: ContentState {
        let status: String
        let chargedKwh: Double
        let percentage: Double
        let message: String?
    }
}
```

## 实时活动功能

### 支持的充电状态
- `pending`: 等待中
- `ready`: 准备就绪
- `pending`: 充电中
- `done`: 充电完成
- `timeout`: 充电超时
- `error`: 充电失败
- `cancelled`: 已取消

### 界面设计

#### 灵动岛紧凑界面
- **左侧**: 电池图标（根据充电状态动态变色）
- **右侧**: 充电百分比
- **最小化**: 仅显示百分比数字

#### 灵动岛展开界面
- **左侧**: 大号电池图标、百分比、充电状态文字
- **右侧**: 目标里程信息
- **底部**: 充电进度条、详细信息、当前电量

#### 锁屏界面
- 完整的充电信息展示
- 进度条显示充电进度
- 状态文字和图标

### 颜色主题
- **等待/准备**: 橙色
- **充电中**: 绿色
- **完成**: 蓝色
- **失败/取消**: 红色

## 使用说明

### 启动充电任务
1. 在充电界面设置目标里程和电量
2. 点击"开始充电"按钮
3. 系统自动启动实时活动显示充电进度

### 监控充电进度
1. 在锁屏界面查看充电状态
2. 在灵动岛查看实时进度
3. 在应用内查看详细信息

### 停止充电
1. 在应用内点击"停止充电"
2. 实时活动会自动更新状态并结束

## 开发环境要求

- iOS 16.1+ (实时活动功能)
- Xcode 14+
- Swift 5.7+

## 权限配置

### Info.plist 配置
```xml
<!-- 主应用 Info.plist -->
<key>NSSupportsLiveActivities</key>
<true/>

<!-- Widget扩展 Info.plist -->
<key>NSSupportsLiveActivities</key>
<true/>
```

## 注意事项

1. **实时活动权限**: 用户需要在系统设置中启用实时活动权限
2. **自动管理**: 系统会自动管理实时活动的生命周期
3. **状态同步**: 充电任务状态变化时会自动更新实时活动
4. **资源清理**: 应用会自动清理无效的实时活动

## 测试建议

1. **功能测试**: 测试充电任务的完整流程
2. **实时活动测试**: 验证锁屏和灵动岛显示效果
3. **状态切换测试**: 测试各种充电状态的切换
4. **权限测试**: 测试实时活动权限开启/关闭的情况

## 故障排除

### 实时活动不显示
1. 检查iOS版本是否为16.1+
2. 确认实时活动权限已开启
3. 检查Info.plist配置是否正确
4. 确认充电任务状态正确

### 状态不更新
1. 检查网络连接
2. 确认后端API正常
3. 检查LiveActivityManager的更新逻辑

现在你可以运行项目测试实时活动功能了！