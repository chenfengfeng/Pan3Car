# Pan3 iOS 项目规则

这些规则适用于本仓库内的所有代码修改。当前重写目标是主 iPhone App `pan3car`，除非用户明确要求，不主动重构 Watch、Widget、Live Activities、App Intents 或 Push Service 相关目标。

## 核心方向

- 主 App 以 SwiftUI-first、iOS 17+ 为基线实现。
- 新 UI 优先使用 Apple 原生框架：SwiftUI、Observation、SwiftData、MapKit、Swift Charts、ActivityKit、WidgetKit、App Intents、WatchConnectivity、Security、UserNotifications。
- iOS 26+ 可用时优先采用原生 Liquid Glass 视觉系统，但必须保留 iOS 17-25 fallback。
- 旧 UIKit、Storyboard、Core Data、第三方 UI/网络工具只作为迁移参考，不作为新主架构继续扩散。
- 修改范围保持克制，优先贴合现有文件结构和风格，不做无关重构。

## 禁止事项

- 不为新主 App 页面引入 `UIViewController`、Storyboard、Xib、Auto Layout 约束代码、`UITableViewController`、`UICollectionViewController`。
- 不使用旧 SwiftUI 导航 API：`NavigationView`、旧式 `NavigationLink(isActive:)`、`.navigationBarTitle`、`@Environment(\.presentationMode)`。
- 不在新代码中使用 `ObservableObject`、`@Published`、`@StateObject`、`@ObservedObject` 作为默认状态模式；优先使用 Observation、`@State`、`@Environment`、`@Binding`。
- 不把 Core Data 作为新主 App 的主要持久化方案；新增本地模型默认使用 SwiftData。
- 不为普通网络请求新增 Alamofire，不用 SwiftyJSON；优先 `URLSession`、`async/await`、`Codable`。
- 不把 token、密码、refresh token 等秘密写入 `UserDefaults` 或 App Group；使用 Keychain access groups。
- 不手写大量自定义 blur/glass 效果来模拟系统能力；优先系统 Liquid Glass API 和 material fallback。

## 项目结构

- App 入口与根壳：`pan3car/App`
- 主 Tab：`pan3car/Features/MainTabs`
- 登录：`pan3car/Features/Auth`
- 车辆首页：`pan3car/Features/Vehicle`
- 占位页面：`pan3car/Features/Placeholders`
- 图片资源：`pan3car/Assets.xcassets`

新增功能优先放在对应 `Features/<FeatureName>` 下。共享服务、持久化、跨扩展数据契约应按需要新增清晰目录，例如 `Services`、`Persistence`、`SharedContracts`。

## SwiftUI 与状态

- 页面使用 `NavigationStack`、`TabView`、typed routing、`.sheet(item:)` 或明确的局部 sheet state。
- 从 Tab 首页进入的二级页面必须隐藏 TabBar，统一使用 `pan3SecondaryPage()` modifier。
- 视图保持声明式，小组件优先抽成专用 `View`，避免巨大 `body` 或复杂 computed view 堆叠。
- 视图内副作用放在 `.task`、`.task(id:)`、显式 action 方法中，避免在 `body` 中触发副作用。
- 异步任务必须可取消、生命周期感知；UI 绑定对象标记 `@MainActor`。
- 使用 `ContentUnavailableView`、loading、empty、error 状态来覆盖用户可见流程。
- 新用户界面需提供 Preview 和 accessibility identifier/label。

## Liquid Glass

- iOS 26+ 使用 `glassEffect(_:in:)`、`GlassEffectContainer`、`.buttonStyle(.glass)`、`.buttonStyle(.glassProminent)` 等原生 API。
- 所有 Liquid Glass API 必须用 `if #available(iOS 26, *)` 或封装好的可用性 wrapper。
- 被点击或拖动的玻璃控件才使用 `.interactive()`；纯展示卡片不要使用 interactive glass。
- iOS 17-25 fallback 使用 `.thinMaterial`、`.regularMaterial`、系统按钮样式或一致的本地 `liquidGlass` wrapper。
- 车辆数据优先级高于装饰效果；续航、SOC、锁车、温度、位置、车窗、车门、胎压等信息必须清晰可读。

## 车辆首页 UI 规则

- 首页是实际可用体验，不做营销落地页。
- 车辆相关视觉优先使用真实资源或 SF Symbols，不用无意义装饰图形。
- 状态卡片应体现车辆空间关系：左右门窗、四角胎压、后尾箱等位置语义要准确。
- 常用控制按钮需要完整交互状态和动画：锁车、空调、车窗、鸣笛等。
- 数字动画优先使用系统 `contentTransition(.numericText())`；需要真正插值跳动时使用专用可插值文本组件。
- 文案、数字和单位必须在小屏与大屏都不截断，必要时使用 `lineLimit`、`minimumScaleFactor`、固定尺寸或响应式布局。

## 数据与共享契约

- SwiftData 新模型应使用稳定领域 ID，常见字段包括 `vin`、`clientTripID`、`clientChargeID`、`timestampMs`、服务器记录 ID。
- 若迁移旧 Core Data 数据，旧库只读读取，批量迁移到 SwiftData，迁移过程可重试且幂等。
- Widget、Watch、Live Activities、App Intents 读取轻量快照，不直接依赖主 App 内部实现。
- App Group 只放非秘密快照；Keychain 保存身份和 token。
- 共享 payload 变更时同步更新写入方、读取方、兼容解码和受影响 target 构建。

## 依赖策略

- 默认不新增第三方依赖。
- 只有 Apple 原生 API 明显不足时才引入依赖，并在变更说明中写清原因和替代方案。
- 常见替代：
  - Alamofire -> `URLSession`
  - SwiftyJSON -> `Codable`
  - SnapKit -> SwiftUI layout
  - MJRefresh -> `.refreshable`
  - DGCharts/Charts -> Swift Charts
  - IQKeyboardManager -> `FocusState`

## 验证

- 有意义的代码修改后至少构建主 App：
  - Project: `pan3car.xcodeproj`
  - Scheme: `pan3car`
  - Platform: iOS Simulator
- UI 改动优先在模拟器或 Preview 中验证布局、暗黑模式、文字截断和交互状态。
- 涉及 Widget、Watch、Live Activities、App Intents、Push Service 或共享契约时，构建所有受影响目标。
- 每次完成修改后都要创建一次 Git 提交，提交信息和最终说明都要写清楚修改内容、原因和验证结果。
- 不提交或回滚与当前任务无关的用户改动。

## 协作习惯

- 修改前先读相关文件和现有模式。
- 优先小步实现、小步验证。
- 不把用户未要求的重构混进功能改动。
- 遇到脏工作区时，只处理本任务相关文件，不回退用户已有修改。
- 最终说明应列出关键文件、行为变化、验证结果和本次 Git 提交。
