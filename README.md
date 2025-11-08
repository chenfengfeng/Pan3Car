# Pan3Car - 胖3助手

<div align="center">

![iOS](https://img.shields.io/badge/iOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![Node.js](https://img.shields.io/badge/Node.js-18+-green.svg)
![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)

一个功能完善的智能汽车控制应用，专为胖3（Pan3）车型设计，支持远程控制、实时监控、充电管理等核心功能。

[功能特性](#-功能特性) • [技术栈](#-技术栈) • [快速开始](#-快速开始) • [项目结构](#-项目结构) • [贡献指南](#-贡献指南)

</div>

---

## 📱 功能特性

### 🚗 车辆控制
- **远程车锁控制** - 一键锁定/解锁车辆
- **空调控制** - 远程开启/关闭空调，支持温度调节
- **车窗控制** - 远程控制四门车窗和天窗
- **寻车功能** - 远程鸣笛，快速定位车辆

### 📊 实时监控
- **电池状态** - 实时显示电量百分比（SOC）、剩余续航里程
- **充电管理** - 监控充电状态、剩余充电时间、充电记录统计
- **车辆位置** - 地图显示车辆实时位置，支持导航到车辆
- **温度监控** - 实时显示车内温度、空调状态
- **车辆状态** - 车门、车窗、胎压等全方位状态监控

### 📈 数据统计
- **行程记录** - 自动记录行程数据，支持行程详情查看
- **充电统计** - 充电记录、充电时长、充电量统计
- **里程统计** - 总里程、空调开启/关闭里程统计

### 🎯 智能功能
- **iOS 小组件** - 支持多种尺寸的小组件，快速查看车辆状态
- **Apple Watch 应用** - 在 Apple Watch 上查看和控制车辆
- **Live Activities** - 实时活动显示充电和行程状态
- **推送通知** - 车辆状态变化、充电完成等智能提醒
- **CloudKit 同步** - 数据云端同步，多设备无缝切换

### 🗺️ 地图导航
- **多地图支持** - 支持高德地图、百度地图、苹果地图
- **一键导航** - 快速导航到车辆位置
- **地址解析** - 自动解析车辆位置地址

## 🛠️ 技术栈

### 前端（iOS）
- **语言**: Swift 5.0+
- **UI框架**: UIKit + SwiftUI
- **最低支持**: iOS 16.2+
- **主要依赖**:
  - QMUIKit - UI组件库
  - SnapKit - 自动布局
  - SwifterSwift - Swift扩展
  - SwiftyJSON - JSON解析

### 后端（Node.js）
- **运行时**: Node.js 22+
- **框架**: Express 5.x
- **数据库**: SQLite3 (better-sqlite3)
- **主要功能**:
  - JWT 身份认证
  - APNs 推送通知
  - 定时任务调度
  - 数据轮询服务

### 平台特性
- **WidgetKit** - iOS 小组件
- **WatchKit** - Apple Watch 应用
- **ActivityKit** - Live Activities
- **CloudKit** - 数据云端同步
- **WatchConnectivity** - iPhone 与 Apple Watch 数据同步
- **Core Location** - 位置服务
- **Core Data** - 本地数据存储

## 📁 项目结构

```
Pan3Car/
├── Pan3/                          # iOS 主应用
│   ├── Controller/                # 视图控制器
│   │   ├── HomeViewController.swift
│   │   ├── ChargeViewController.swift
│   │   ├── TripViewController.swift
│   │   └── ...
│   ├── Manager/                   # 业务管理器
│   │   ├── NetworkManager.swift
│   │   ├── UserManager.swift
│   │   ├── LiveActivityManager.swift
│   │   └── ...
│   ├── Model/                     # 数据模型
│   ├── View/                      # 自定义视图
│   └── Utility/                   # 工具类
│
├── Car Watch App/                 # Apple Watch 应用
│   ├── ContentView.swift
│   ├── WatchConnectivityManager.swift
│   └── WatchAppIntents.swift
│
├── CarWidget/                     # iOS 小组件
│   ├── CarWidget.swift
│   ├── CarWidgetBundle.swift
│   └── AppIntent.swift
│
├── CarWatchWidget/                # Watch 小组件
│   └── ...
│
├── LiveActivities/                # 实时活动
│   ├── ChargeLiveActivity.swift
│   └── TripLiveActivity.swift
│
├── Shared/                        # 共享代码
│   ├── SharedCarModel.swift
│   ├── SharedNetworkManager.swift
│   └── SharedAppIntents.swift
│
└── pan3_server/                   # 后端服务器
    ├── api/                       # API 路由
    │   ├── auth/                  # 认证相关
    │   ├── car/                   # 车辆控制
    │   ├── charge/                # 充电管理
    │   ├── trip/                  # 行程记录
    │   └── push/                  # 推送通知
    ├── core/                      # 核心功能
    │   ├── database/              # 数据库
    │   ├── services/              # 后台服务
    │   └── middlewares/           # 中间件
    └── app.js                     # 服务器入口
```

## 🚀 快速开始

### 环境要求

- **macOS**: 12.0 或更高版本
- **Xcode**: 14.0 或更高版本
- **CocoaPods**: 1.11.0 或更高版本
- **Node.js**: 18.0 或更高版本
- **npm**: 9.0 或更高版本

### iOS 应用安装

1. **克隆仓库**
   ```bash
   git clone https://github.com/yourusername/Pan3Car.git
   cd Pan3Car
   ```

2. **安装 CocoaPods 依赖**
   ```bash
   pod install
   ```

3. **打开工作空间**
   ```bash
   open Pan3.xcworkspace
   ```

4. **配置项目**
   - 在 Xcode 中打开项目
   - 配置你的 Team 和 Bundle Identifier
   - 配置 App Groups: `group.com.feng.pan3`(你改自己的)
   - 配置 CloudKit Container: `iCloud.com.dream.pan3car`(你改自己的)
   - 配置推送通知证书

5. **运行项目**
   - 选择目标设备或模拟器
   - 按 `Cmd + R` 运行

### 后端服务器部署

1. **进入服务器目录**
   ```bash
   cd pan3_server
   ```

2. **安装依赖**
   ```bash
   npm install
   ```

3. **配置环境变量**
   创建 `.env` 文件（如果不存在）：
   ```env
   PORT=3333
   JWT_SECRET=your_jwt_secret_key
   APNS_KEY_PATH=path/to/your/apns_key.p8
   APNS_KEY_ID=your_apns_key_id
   APNS_TEAM_ID=your_team_id
   APNS_BUNDLE_ID=com.dream.pan3car
   ```

4. **初始化数据库**
   ```bash
   # 数据库会在首次启动时自动初始化
   ```

5. **启动服务器**
   ```bash
   node app.js
   ```

   或使用 PM2 进行进程管理：
   ```bash
   pm2 start app.js --name pan3-server
   ```

## 📖 使用说明

### 首次使用

1. **登录账号**
   - 打开应用，输入你的车辆账号和密码
   - 系统会自动保存登录状态

2. **授权通知权限**
   - 允许推送通知，以便接收车辆状态变化提醒
   - 允许位置权限，以便显示车辆位置

3. **添加小组件**
   - 长按主屏幕，点击左上角 `+` 号
   - 搜索 "胖3助手"，选择合适的小组件尺寸
   - 添加到主屏幕

### 主要功能使用

#### 车辆控制
- 在首页点击控制按钮（车锁、空调、车窗、寻车）
- 部分操作需要二次确认，确保安全

#### 充电管理
- 进入充电页面查看充电状态
- 可以启动/停止充电监控
- 查看充电记录和统计

#### 行程记录
- 进入行程页面查看历史行程
- 点击行程查看详细信息
- 查看行程统计

#### Apple Watch
- 在 Apple Watch 上打开应用
- 查看车辆状态
- 执行基本控制操作

## 🔧 配置说明

### App Groups 配置
应用使用 App Groups 在主应用、小组件和 Watch 应用之间共享数据：
- Group ID: `group.com.feng.pan3`(你改自己的)

### CloudKit 配置
- Container ID: `iCloud.com.dream.pan3car`(你改自己的)
- 用于数据云端同步

### 推送通知配置
- 需要配置 APNs 证书或密钥
- 支持生产环境和开发环境

## 🤝 贡献指南

我们欢迎所有形式的贡献！请遵循以下步骤：

1. **Fork 本仓库**
2. **创建特性分支** (`git checkout -b feature/AmazingFeature`)
3. **提交更改** (`git commit -m 'Add some AmazingFeature'`)
4. **推送到分支** (`git push origin feature/AmazingFeature`)
5. **开启 Pull Request**

### 代码规范
- 遵循 Swift API 设计指南
- 使用有意义的变量和函数名
- 添加必要的注释
- 保持代码简洁和可读性

## 📝 开发计划

- [ ] 使用swiftUI重构
- [ ] 添加车辆保养提醒
- [ ] 导入旧的行程数据

## ⚠️ 注意事项

1. **账号安全**
   - 请妥善保管你的账号密码
   - 不要将账号信息分享给他人

2. **网络要求**
   - 应用需要网络连接才能正常工作
   - 部分功能需要车辆在线状态

3. **权限说明**
   - 位置权限：用于显示车辆位置和导航
   - 通知权限：用于接收车辆状态提醒
   - 网络权限：用于与服务器通信

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🙏 致谢

- 感谢所有贡献者的支持
- 感谢使用本应用的用户反馈

## 📮 联系方式

- **Issues**: [GitHub Issues](https://github.com/chenfengfeng/Pan3Car/issues)

---

<div align="center">

**如果这个项目对你有帮助，请给个 ⭐ Star！**

Made with ❤️ by Pan3Car Team

</div>

