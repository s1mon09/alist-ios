# Alist iOS

Alist 苹果手机客户端，基于 SwiftUI 开发，支持 Alist 全部功能。

---

## 目录

- [架构总览](#架构总览)
- [各层职责详解](#各层职责详解)
- [关键设计决策](#关键设计决策)
- [数据流与状态管理](#数据流与状态管理)
- [网络层设计](#网络层设计)
- [后台下载系统](#后台下载系统)
- [GitHub 集成与外网能力](#github-集成与外网能力)
- [修复历史与注意事项](#修复历史与注意事项)
- [行业最佳实践对比](#行业最佳实践对比)
- [功能特性](#功能特性)
- [项目结构](#项目结构)
- [构建方法](#构建方法)
- [编译验证清单](#编译验证清单)
- [使用说明](#使用说明)

---

## 架构总览

本项目采用 **MVVM（Model-View-ViewModel）** 架构，这是 iOS SwiftUI 项目的行业标准写法（参考 [Apple 官方 SwiftUI 教程](https://developer.apple.com/tutorials/swiftui) 和主流开源项目如 [IOS-App-Template](https://github.com/rongguanhui/IOS-App-Template)）。

```
┌─────────────────────────────────────────────────┐
│  View 层 (SwiftUI Views)                        │
│  负责UI渲染、用户交互、状态展示                    │
│  ↓ @StateObject / @EnvironmentObject             │
├─────────────────────────────────────────────────┤
│  ViewModel 层 (@MainActor ObservableObject)     │
│  负责业务逻辑、状态管理、协调 Service             │
│  ↓ 调用                                          │
├─────────────────────────────────────────────────┤
│  Service 层 (单例, async/throws)                │
│  负责API调用、业务编排                            │
│  ↓ 调用                                          │
├─────────────────────────────────────────────────┤
│  Network 层 (APIClient + Alamofire)             │
│  负责HTTP请求、响应解析、错误处理                  │
│  ↓ HTTP                                          │
├─────────────────────────────────────────────────┤
│  Model 层 (Codable 结构体)                      │
│  纯数据模型，无业务逻辑                           │
└─────────────────────────────────────────────────┘
```

### 与行业写法的对比

| 方面 | 本项目 | 行业主流写法 | 说明 |
|------|--------|-------------|------|
| 架构 | MVVM | MVVM / TCA / Clean Architecture | MVVM 是 SwiftUI 最常见选择 |
| 网络层 | Alamofire + async/await | URLSession / Alamofire / Moya | Alamofire 是最流行的第三方网络库 |
| 状态管理 | @StateObject + @EnvironmentObject | @Observable (iOS 17+) / Combine | 本项目兼容 iOS 16，使用 @StateObject |
| 依赖注入 | @EnvironmentObject | Resolver / Factory / Environment | 原生方案足够简单场景 |
| 导航 | NavigationStack + sheet | NavigationStack / Coordinator | SwiftUI 原生方案 |
| 安全存储 | Keychain (KeychainAccess) | Keychain / UserDefaults | Token 必须存 Keychain |

---

## 各层职责详解

### 1. App 层 (`App/`)

#### `AppState.swift` — 全局应用状态
- **职责**：管理全局可变状态（token、用户信息、外观设置、服务器列表）
- **关键设计**：
  - Token 通过 `@Published` + `didSet` 双向同步到 Keychain 和 `ServerConfig`
  - `@AppStorage` 包装 UserDefaults，实现持久化偏好设置
  - `recentServers` 使用有序去重算法（`reversed().filter.inserted().reversed()`）保留最近使用顺序

```swift
// Token 变更时自动同步到 Keychain 和 ServerConfig
@Published var token: String = "" {
    didSet {
        ServerConfig.shared.update(token: token)
        if token.isEmpty {
            KeychainHelper.shared.delete(key: KeychainHelper.Key.token)
        } else {
            KeychainHelper.shared.save(token, forKey: KeychainHelper.Key.token)
        }
        isLoggedIn = !token.isEmpty
    }
}
```

#### `Theme.swift` — 主题配色
- **职责**：定义全局颜色常量（primary、success、warning、danger 等）
- **设计**：使用静态常量，便于全局统一修改配色

### 2. Model 层 (`Models/`)

纯数据模型，全部遵循 `Codable`，无业务逻辑。

| 文件 | 职责 | 关键点 |
|------|------|--------|
| `APIResponse.swift` | API 响应包装 | `APIResponse<T: Decodable>` 泛型包装 code/message/data |
| `User.swift` | 用户模型 | 权限位运算 `((permission ?? 0) >> n) & 1`，注意括号优先级 |
| `FileObject.swift` | 文件对象 | `FileType` 枚举判断预览类型，`sign` 字段用于带签直链 |
| `Storage.swift` | 存储驱动 | `DriverAddition.default` 是 Swift 保留字，必须用反引号 `` `default` `` |
| `Share.swift` | 分享模型 | `hasPassword` 检查 `password` 字段非空（不是 accessLimit） |
| `Task.swift` | 任务模型 | `TaskState` 10 个 case 必须穷举，`TaskType` 用于任务分类 |
| `Meta.swift` | 元数据/公共设置 | `PublicSettings` 包含权限开关和版本号 |
| `Archive.swift` | 归档模型 | 解压请求/响应结构 |
| `Session.swift` | 会话/SSH/标签 | `CreateLabelBindingReq` 可复用于 create 和 delete 接口 |

### 3. Network 层 (`Network/`)

#### `APIClient.swift` — 核心网络客户端
- **职责**：封装 Alamofire，提供泛型 `request<T: Decodable>` 方法
- **关键设计**：
  - 直接构造 `URLRequest` 并设置 `httpBody`，绕过 Alamofire 的 `parameters: [String: Any]` 类型要求（这是本项目最重要的修复点）
  - 统一处理 `APIResponse<T>` 包装，自动提取 `data` 字段
  - 自动注入 `Authorization` token 和 `Client-Id` header
  - `handleResponse` 方法统一处理 HTTP 状态码和业务 code

```swift
// 关键修复：直接构造 URLRequest，避免 Alamofire 参数类型不匹配
var urlRequest = URLRequest(url: url)
urlRequest.httpMethod = afMethod(method).rawValue
urlRequest.headers = headers
if let bodyData = bodyData {
    urlRequest.httpBody = bodyData
}
let dataReq = session.request(urlRequest)
```

#### `ServerConfig.swift` — 服务器配置单例
- **职责**：线程安全存储 baseURL 和 token
- **关键设计**：使用 `NSLock` 保护读写，因为 `DownloadManager` 的 delegate 在非隔离上下文访问

#### `APIError.swift` — 错误类型
- **职责**：定义所有 API 错误 case
- **关键设计**：`associatedMessage` 属性跨 case 统一提取后端消息，用于 2FA 检测

#### Service 类
每个 Service 是单例，封装对应 Alist API 端点：

| Service | 对应 API | 关键方法 |
|---------|---------|---------|
| `AuthService` | `/auth/*`, `/me` | `login`（SHA256 哈希）、`loginLDAP`、`generate2FA` |
| `FsService` | `/fs/*` | `list`、`get`、`mkdir`、`rename`、`move`、`copy`、`remove`、`uploadStream` |
| `ShareService` | `/share/*` | `list`、`create`、`update`、`delete`、`publicInfo`、`publicAuth` |
| `TaskService` | `/task/*` | `undone`、`done`、`cancel`、`delete`、`retry` |
| `AdminUserService` | `/admin/*` | 用户/存储/角色/Meta/设置/索引管理（含 6 个子 Service） |
| `PublicService` | `/public/settings` | `publicSettings`（无需登录） |
| `LabelService` | `/admin/label*` | 标签 CRUD、标签绑定 |
| `SessionSSHService` | `/me/session/*`, `/me/ssh/*` | 会话管理、SSH 公钥管理 |
| `GitHubService` | GitHub API | 版本检查、Releases 列表（连接外网） |

### 4. ViewModel 层 (`ViewModels/`)

#### `AuthViewModel.swift` — 认证 ViewModel
- **职责**：处理登录、注册、2FA、登出逻辑
- **关键设计**：2FA 检测通过检查 `APIError.associatedMessage` 是否包含 "2fa"/"两步"/"otp" 关键字

```swift
// 2FA 检测逻辑
let msg = error.associatedMessage ?? ""
let lowerMsg = msg.lowercased()
if lowerMsg.contains("2fa") || msg.contains("两步") || lowerMsg.contains("otp") {
    needs2FA = true
    pendingUsername = username
    pendingPassword = password
    pendingIsLDAP = isLDAP
}
```

#### `FileListViewModel.swift` — 文件列表 ViewModel
- **职责**：管理文件列表、分页、排序、选择模式
- **关键设计**：
  - `sortedFiles` 计算属性实时排序，文件夹始终在前
  - `loadMore` 分页加载，`hasMore` 控制是否还有更多
  - 排序字段持久化到 UserDefaults

### 5. View 层 (`Views/`)

#### 视图层次结构
```
RootView（根据登录状态切换）
├── LoginView（登录/注册/扫码/2FA）
└── MainTabView（5 个 Tab）
    ├── FileBrowserView（文件浏览，含面包屑导航）
    │   ├── FileActionsView（文件操作菜单，含 onComplete 闭包）
    │   ├── FilePreviewView（文件预览，支持图片/视频/音频/PDF/文本/Office）
    │   ├── UploadView（上传，支持相册/文件选择）
    │   ├── DownloadsView（下载管理）
    │   └── ArchiveOfflineView（归档/离线下载）
    ├── SearchView（全站搜索）
    ├── TaskListView（任务管理，自动刷新）
    ├── ShareListView（分享管理 + 公共分享访问）
    └── ProfileView（个人中心）
        ├── EditProfileView（编辑资料）
        ├── TwoFAView（两步验证）
        ├── SessionListView（会话管理）
        ├── SSHKeyListView（SSH 公钥管理）
        ├── SettingsView（设置 + GitHub Releases）
        ├── AboutView（关于）
        └── AdminView（管理后台，仅管理员可见）
            ├── StorageManageView（存储管理）
            ├── RoleMetaManageView（角色/Meta 管理）
            └── SettingIndexManageView（设置/索引/标签管理）
```

### 6. Utils 层 (`Utils/`)

#### `DownloadManager.swift` — 后台下载管理器（最复杂的组件）
- **职责**：管理后台下载任务，支持进度跟踪、暂停/恢复/取消、持久化
- **关键设计**：
  - `@MainActor` 隔离，但 delegate 方法 `nonisolated`，通过 `NSLock` 保护 `_taskIDMap` 和 `_downloadCache`
  - 使用 `URLSessionConfiguration.background` 实现真后台下载
  - `AppDelegate` 处理 `handleEventsForBackgroundURLSession` 回调
  - 下载记录持久化到 `downloads.json`

```swift
// 线程安全访问模式
nonisolated func taskIDMapFor(_ taskIdentifier: Int) -> UUID? {
    lock.lock(); defer { lock.unlock() }
    return _taskIDMap[taskIdentifier]
}
```

#### `KeychainHelper.swift` — Keychain 封装
- **职责**：安全存储 token、deviceKey、userID
- **设计**：基于 KeychainAccess 第三方库，简化 Keychain API

#### `Managers.swift` — 管理器集合
- `BackgroundTaskManager`：注册 `BGTaskScheduler` 后台刷新任务
- `AppReviewManager`：累计启动次数后请求 App 评价
- `HapticManager`：触觉反馈，受 `enable_haptic` 设置控制

#### `Extensions.swift` — 通用扩展
- `String.trimmedURL`：去除尾部斜杠
- `String.encodedPath`：URL 路径编码
- `Date.formatted`：统一日期格式
- `Int64.fileSizeFormatted`：文件大小人类可读格式
- `JSONDecoder.serverDecoder`：多策略日期解析（ISO8601 + 自定义格式）

---

## 关键设计决策

### 1. 为什么用 Alamofire 而不是原生 URLSession？
- Alamofire 提供更简洁的 API、自动重试、上传进度回调
- 但本项目在 `request` 方法中直接构造 `URLRequest`，因为 Alamofire 的 `parameters: [String: Any]` 不支持 `Encodable` body
- 上传仍使用 Alamofire 的 `session.upload` 方法

### 2. 为什么 DownloadManager 用 @MainActor + nonisolated delegate？
- `@MainActor` 确保 `@Published` 属性在主线程更新
- `URLSessionDelegate` 方法在后台线程调用，必须 `nonisolated`
- 通过 `NSLock` 保护共享状态（`_taskIDMap`、`_downloadCache`）
- 通过 `Task { @MainActor in ... }` 回到主线程更新 UI 状态

### 3. 为什么 ServerConfig 用 NSLock 而不是 actor？
- `DownloadManager` 的 delegate 在 `nonisolated` 上下文访问 `ServerConfig.shared.token`
- actor 隔离会导致 `async` 调用，delegate 方法不能是 `async`
- `NSLock` 是同步的，适合这种场景

### 4. 为什么 FileActionsView 有 onComplete 闭包？
- 删除/重命名/移动后需要刷新父级文件列表
- `FileBrowserView` 和 `SearchView` 都使用 `FileActionsView`
- `SearchView` 不需要刷新（用默认空闭包 `{}`）
- `FileBrowserView` 传入 `onComplete: { Task { await vm.loadList(...) } }`

### 5. 为什么 2FA 检测用关键字匹配？
- Alist 后端在需要 2FA 时返回 401 + message 含 "2fa" 关键字
- 没有专用错误码，只能通过 message 关键字检测
- `APIError.associatedMessage` 统一提取 message，支持 unauthorized/serverError/custom 三个 case

### 6. 为什么 DriverAddition.default 要加反引号？
- `default` 是 Swift 保留关键字（用于 switch 语句）
- 作为属性名必须加反引号：`` let `default`: String? ``
- Alist 后端 JSON 字段名就是 `default`，默认 Codable 映射保持一致

---

## 数据流与状态管理

### 登录流程
```
LoginView → AuthViewModel.login() → AuthService.login() → APIClient.request()
    ↓ 成功
KeychainHelper.save(token) → ServerConfig.update(token)
    ↓
AppState.token = resp.token（触发 didSet 同步 Keychain + ServerConfig）
    ↓
RootView 监听 isLoggedIn 变化 → 切换到 MainTabView
    ↓
loadInitialData() → PublicService.publicSettings() + AuthService.currentUser()
```

### 文件列表加载流程
```
FileBrowserView.onAppear → FileListViewModel.loadList(path: "/", refresh: true)
    ↓
FsService.shared.list(path:page:perPage:refresh:) → APIClient.request(/fs/list)
    ↓
返回 FsListResp（content/hasMore/total/canWrite/readme/provider）
    ↓
ViewModel 更新 @Published 属性 → View 自动刷新
```

### 下载流程
```
FileActionsView.downloadFile() → DownloadManager.addDownload(file:remoteURL:)
    ↓
创建 DownloadRecord（持久化到 downloads.json）
    ↓
session.downloadTask(with: URLRequest)（后台 URLSession）
    ↓
URLSessionDownloadDelegate.didWriteData（更新进度）
    ↓
URLSessionDownloadDelegate.didFinishDownloadingTo（移动文件到目标路径）
    ↓
更新 record.state = .completed + HapticManager.success() + ToastManager.show()
    ↓
urlSessionDidFinishEvents → AppDelegate.invokeBackgroundCompletionHandler()
```

---

## 网络层设计

### APIClient.request 泛型方法

```swift
@discardableResult
func request<T: Decodable>(
    path: String,              // API 路径，如 "/fs/list"
    method: HTTPMethod = .GET,
    body: Encodable? = nil,    // 请求体（自动 JSON 编码）
    query: [String: Any]? = nil, // URL 查询参数
    responseType: T.Type        // 响应数据类型
) async throws -> T
```

### 响应处理流程
```
HTTP 响应 → 检查状态码
    ↓ 2xx
解析 APIResponse<T> → 检查 code == 200
    ↓ 成功
返回 data 字段（T 类型）
    ↓ 失败
抛出 APIError.unauthorized / .forbidden / .notFound / .serverError
```

### 错误处理模式
所有 Service 方法 `throws`，View 层统一用 `do-catch` 捕获：
```swift
do {
    try await FsService.shared.remove(...)
} catch let error as APIError {
    ToastManager.shared.show(error.errorDescription ?? "操作失败", type: .error)
} catch {
    ToastManager.shared.show(error.localizedDescription, type: .error)
}
```

---

## 后台下载系统

### 核心组件
1. **DownloadManager**（`@MainActor` 单例）：管理下载任务
2. **AppDelegate**：处理后台 URLSession 完成回调
3. **URLSessionConfiguration.background**：系统级后台下载

### 后台下载生命周期
```
App 在前台 → 用户添加下载 → task.resume()
    ↓
App 进入后台 → 系统继续下载 → App 可能被挂起
    ↓
下载完成 → 系统唤醒 App → AppDelegate.handleEventsForBackgroundURLSession
    ↓
URLSession delegate 方法执行 → 移动文件、更新状态
    ↓
urlSessionDidFinishEvents → AppDelegate.invokeBackgroundCompletionHandler()
    ↓
系统知道任务完成，可以再次挂起 App
```

### 线程安全设计
- `@MainActor` 隔离 `@Published` 属性
- `nonisolated` delegate 方法 + `NSLock` 保护共享状态
- `Task { @MainActor in ... }` 回到主线程更新 UI

### 持久化
- 下载记录保存到 `Application Support/downloads.json`
- App 重启后恢复记录，未完成的任务状态设为 `.paused`
- resumeData 保存到临时目录，支持断点续传

---

## GitHub 集成与外网能力

### GitHubService
- 连接 GitHub API（`https://api.github.com/repos/alist-org/alist`）
- 获取最新 Release、版本列表
- 用于检查 Alist 服务端版本更新

### 外网能力
- `Info.plist` 配置 `NSAllowsArbitraryLoads: true` 支持 HTTP 服务器
- `URLSession.shared` 直接访问外网（GitHub API）
- `SettingsView` 中的「检查服务器版本更新」功能
- `GitHubReleasesView` 展示 Release 列表和下载链接

### 版本比较
```swift
func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
    // 按 "." 分割，逐段比较数字
}
```

---

## 修复历史与注意事项

### 已修复的关键问题

#### 编译错误修复
1. **APIClient parameters 类型不匹配**：Alamofire 的 `parameters: [String: Any]` 不支持 `Data?` → 改为直接构造 `URLRequest`
2. **DriverAddition.default 保留字**：`let default: String?` → `` let `default`: String? ``
3. **DriverName.id 类型不匹配**：`var id: String { self }` 中 self 是 DriverName 类型 → 删除未使用的 DriverName 结构体
4. **LabelService 异构字典**：`["label_id": Int, "file_name": String]` 不满足 Encodable → 复用 `CreateLabelBindingReq` 结构体
5. **FileActionsView 缺少 onComplete 闭包**：调用方传入 trailing closure 但定义无对应参数 → 添加 `onComplete: () -> Void = {}` 参数
6. **errorDescription 可选类型**：`error.errorDescription` 返回 `String?` 但 `ToastManager.show` 需要 `String` → 添加 `?? "操作失败"`
7. **LoadingView 参数标签**：`LoadingView("搜索中...")` → `LoadingView(message: "搜索中...")`
8. **UploadView 缺少 import PhotosUI**：`PHPickerViewController` 等类型无法编译 → 添加 `import PhotosUI`
9. **@ObservedObject 访问 @MainActor 单例**：`DownloadRowView` 和 `DownloadBadgeView` 中 `@ObservedObject` 立即求值违反隔离 → 改为 `@StateObject`

#### 运行时崩溃修复
1. **ShareListView force unwrap**：3 处 `URL(string:)!` → 改为 `guard let` + 错误提示
2. **DownloadManager 后台文件移动**：URLSession 临时文件必须在 delegate 方法中同步移动
3. **VideoPlayerView Combine 内存泄漏**：cancellables 类型不匹配 → 改为实例 `Set<AnyCancellable>`
4. **AudioPlayerView NotificationCenter 泄漏**：保存观察者 token 并在 cleanup 中移除
5. **2FA 检测失效**：检查 `APIError.associatedMessage` 中的 2FA 关键字
6. **Share.hasPassword 逻辑错误**：检查 `password` 字段非空，不是 `accessLimit > 0`
7. **AppState.recentServers 顺序丢失**：使用有序去重算法替代 Set 排序
8. **ServerConfig 读取未加锁**：添加 NSLock 保护 baseURL 和 token 读取

### 编码注意事项

1. **Swift 保留字作为属性名**：必须加反引号（`` `default` ``, `` `self` ``, `` `where` `` 等）
2. **异构字典不能作为 Encodable**：`["key1": Int, "key2": String]` 推断为 `[String: Any]`，不满足 Encodable → 定义专用结构体
3. **@MainActor 单例的访问**：
   - `@StateObject` 的 `@autoclosure @escaping` 会延迟求值，安全
   - `@ObservedObject` 的属性初始化器立即求值，在非隔离上下文会报错
4. **Alamofire parameters 类型**：`parameters: [String: Any]?` 不接受 `Data?`，需要直接构造 URLRequest
5. **errorDescription 是 String?**：`LocalizedError.errorDescription` 返回可选类型，使用时需要 `??` 兜底
6. **URLSession delegate 是 nonisolated**：`@MainActor` 类的 delegate 方法必须 `nonisolated`，共享状态用 `NSLock` 保护
7. **LoadingView 自定义结构体**：成员初始化器需要参数标签 `message:`（不是 `String` 字面量直接传）
8. **PhotosUI 不被 SwiftUI 重新导出**：使用 `PHPickerViewController` 等必须 `import PhotosUI`

---

## 行业最佳实践对比

### 1. 架构选择
- **本项目**：MVVM + Service 单例
- **行业主流**：MVVM 是 SwiftUI 最常见架构（[Apple 官方推荐](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)）
- **进阶选择**：TCA（The Composable Architecture）、Clean Architecture（适合大型项目）
- **本项目适配**：中小型项目用 MVVM + Service 单例足够，无需引入 Coordinator 或 Repository 层

### 2. 网络层
- **本项目**：Alamofire + async/await + 泛型 `request<T: Decodable>`
- **行业主流**：
  - 原生 URLSession + async/await（最轻量）
  - Alamofire（最流行的第三方库）
  - Moya（基于 Alamofire 的抽象层，适合大型 API）
- **本项目适配**：Alamofire 足够，但 `request` 方法直接构造 URLRequest 是必要的变通

### 3. 状态管理
- **本项目**：`@StateObject` + `@EnvironmentObject` + `@Published` + `Combine`
- **行业主流**：
  - iOS 17+：`@Observable` 宏（更简洁）
  - iOS 16-：`@StateObject` + `@Published`（本项目选择）
  - 第三方：Redux（TCA）、ReactorKit
- **本项目适配**：兼容 iOS 16，必须用 `@StateObject`，不能用 `@Observable`

### 4. 安全存储
- **本项目**：Keychain（通过 KeychainAccess 库）存 token，UserDefaults 存非敏感配置
- **行业主流**：Keychain 存敏感数据，UserDefaults 存偏好设置
- **最佳实践**：本项目做法正确，Token 必须存 Keychain

### 5. 后台下载
- **本项目**：`URLSessionConfiguration.background` + `BGTaskScheduler` + `AppDelegate`
- **行业主流**：
  - `URLSessionConfiguration.background`（标准方案）
  - 第三方：Kingfisher（图片）、Alamofire（一般下载）
- **本项目适配**：原生 background URLSession 是唯一支持真后台下载的方案

### 6. 错误处理
- **本项目**：自定义 `APIError` 枚举 + `LocalizedError` + `associatedMessage`
- **行业主流**：自定义 Error 枚举 + localizedDescription
- **本项目创新**：`associatedMessage` 跨 case 提取消息，用于 2FA 检测

### 7. 代码组织
- **本项目**：按功能分文件夹（Models/Network/Views/ViewModels/Utils）
- **行业主流**：
  - 按功能分文件夹（本项目）
  - 按模块分 Feature（适合大型项目）
- **本项目适配**：中小型项目按功能分文件夹足够清晰

---

## 功能特性

### 核心功能
- **认证登录**：密码登录（SHA256 哈希）、LDAP 登录、2FA 两步验证、SSO 单点登录、注册
- **文件浏览**：列表/网格视图、分页加载、排序（名称/大小/时间）、隐藏文件、README 渲染
- **文件操作**：新建文件夹、重命名、批量重命名、正则重命名、移动、递归移动、复制、删除、删除空目录
- **文件上传**：流式上传、表单上传、从相册/文件选择、多文件批量上传
- **文件下载**：后台下载、断点续传、进度跟踪、暂停/恢复/取消
- **文件预览**：
  - 图片（画廊模式、双指缩放、相关图片切换）
  - 视频（AVPlayer 播放器，自定义控制栏）
  - 音频（带播放控制、唱片动画）
  - PDF（PDFKit 渲染）
  - 文本/代码（等宽字体，支持 GB18030 编码）
  - Office 文档（QuickLook 预览）
  - Markdown 渲染（MarkdownUI）
- **搜索**：全站文件搜索
- **归档**：压缩包列表查看、解压到指定目录

### 分享管理
- 创建分享（密码保护、阅后即焚、访问限制、有效期、预览/下载权限）
- 编辑/禁用/删除分享
- 分享统计（访问次数、下载次数）
- 公共分享访问（含密码认证、过期状态显示）

### 任务管理
- 任务类型：上传、复制、离线下载、离线下载转存、S3 转换、解压、解压上传
- 进行中/已完成任务列表
- 任务操作：取消、删除、重试
- 批量操作：批量取消/删除/重试
- 清理已完成/重试失败
- 自动刷新进度（仅进行中页面）

### 离线下载
- 支持 aria2、qBittorrent、Transmission、115、PikPak、Thunder 等工具
- 多链接批量下载
- 下载完成后删除源文件

### 标签系统
- 标签列表查看
- 标签创建/编辑/删除
- 颜色自定义
- 文件标签绑定

### 个人中心
- 编辑个人资料（用户名、密码、基础路径）
- 两步验证启用
- 会话管理（查看/注销设备）
- SSH 公钥管理（添加/删除）

### 管理后台
- **用户管理**：列表、创建、编辑、删除、取消 2FA、清除缓存
- **角色管理**：列表、创建、编辑、删除、权限范围配置
- **存储管理**：列表、创建、编辑、删除、启用/禁用、重新加载、驱动配置
- **驱动列表**：查看所有支持的驱动及配置项
- **Meta 管理**：列表、创建、编辑、删除（密码保护、写入权限、隐藏文件、README、Header）
- **系统设置**：分组查看（站点/样式/预览/全局/离线下载/索引/SSO/LDAP/S3/FTP/流量/FRP）、编辑保存
- **索引管理**：构建/更新/停止/清空、进度查看
- **标签管理**：标签 CRUD

### GitHub 集成
- 检查 Alist 服务端最新版本
- 查看 GitHub Releases 列表
- 下载 Release 资源文件
- 跳转 GitHub 仓库/Issues/文档

### 其他特性
- 深色/浅色/跟随系统主题
- 中文本地化
- 触觉反馈（可开关）
- 后台音频播放
- 后台任务刷新
- 仅 WiFi 上传/下载选项
- App 评价提醒（累计启动 10 次后）
- Toast 全局提示系统

---

## 项目结构

```
alist-ios/
├── project.yml                    # XcodeGen 工程配置
├── README.md                      # 本文档
└── Alist/
    ├── AlistApp.swift             # App 入口 + AppDelegate（后台 URLSession）
    ├── Info.plist                 # 配置（ATS/后台模式/权限）
    ├── Assets.xcassets/           # 资源文件（AppIcon/AccentColor）
    ├── App/
    │   ├── AppState.swift         # 全局状态（token/用户/设置）
    │   └── Theme.swift            # 主题颜色
    ├── Models/                    # 数据模型（纯 Codable 结构体）
    │   ├── APIResponse.swift      # API 响应包装
    │   ├── User.swift             # 用户/权限/登录
    │   ├── FileObject.swift       # 文件对象/类型
    │   ├── Storage.swift          # 存储驱动
    │   ├── Share.swift            # 分享
    │   ├── Task.swift             # 任务
    │   ├── Meta.swift             # 元数据/公共设置
    │   ├── Archive.swift          # 归档
    │   └── Session.swift          # 会话/SSH/标签
    ├── Network/                   # 网络层
    │   ├── ServerConfig.swift     # 服务器配置（线程安全单例）
    │   ├── APIClient.swift        # 核心网络客户端（Alamofire）
    │   ├── APIError.swift         # 错误类型
    │   ├── AuthService.swift      # 认证服务
    │   ├── FsService.swift        # 文件系统服务
    │   ├── PublicService.swift    # 公共设置服务
    │   ├── ShareService.swift     # 分享服务
    │   ├── TaskService.swift      # 任务服务
    │   ├── LabelService.swift     # 标签服务
    │   ├── AdminUserService.swift # 管理员服务（含6个子Service）
    │   ├── SessionSSHService.swift# 会话/SSH 服务
    │   └── GitHubService.swift    # GitHub 集成（外网）
    ├── ViewModels/
    │   ├── AuthViewModel.swift    # 认证 VM（含2FA检测）
    │   └── FileListViewModel.swift# 文件列表 VM（分页/排序）
    ├── Views/
    │   ├── RootView.swift         # 根视图（登录状态切换）
    │   ├── Auth/
    │   │   └── LoginView.swift    # 登录/注册/扫码/2FA
    │   ├── Main/
    │   │   └── MainTabView.swift  # 主 Tab + 下载指示器
    │   ├── Files/
    │   │   ├── FileBrowserView.swift      # 文件浏览
    │   │   ├── FileActionsView.swift      # 文件操作菜单
    │   │   ├── FilePreviewView.swift      # 文件预览
    │   │   ├── UploadView.swift           # 上传
    │   │   ├── DownloadsView.swift        # 下载管理
    │   │   └── ArchiveOfflineView.swift   # 归档/离线下载
    │   ├── Search/
    │   │   └── SearchView.swift   # 搜索
    │   ├── Share/
    │   │   ├── ShareListView.swift           # 分享管理
    │   │   └── PublicShareBrowserView.swift  # 公共分享访问
    │   ├── Task/
    │   │   └── TaskListView.swift # 任务管理
    │   ├── Profile/
    │   │   ├── ProfileView.swift          # 个人中心
    │   │   └── SettingsView.swift         # 设置 + GitHub Releases
    │   ├── Admin/
    │   │   ├── AdminView.swift            # 管理后台入口
    │   │   ├── StorageManageView.swift    # 存储管理
    │   │   ├── RoleMetaManageView.swift   # 角色/Meta 管理
    │   │   └── SettingIndexManageView.swift# 设置/索引/标签
    │   └── Components/
    │       └── CommonViews.swift  # 通用组件（Toast/Loading/Error/Empty）
    └── Utils/
        ├── DownloadManager.swift  # 后台下载管理器（@MainActor + nonisolated）
        ├── Extensions.swift       # 通用扩展（String/Date/Int64/JSON）
        ├── KeychainHelper.swift   # Keychain 封装
        └── Managers.swift         # 后台任务/触觉/App 评价
```

---

## 构建方法

### 前置要求
- macOS 13.0+（推荐最新版本）
- Xcode 15.0+（推荐最新版本）
- iOS 16.0+ 设备或模拟器
- [XcodeGen](https://github.com/yonaskolb/xcodegen)（可选，推荐）

### 方法一：使用 XcodeGen（推荐）

1. 安装 XcodeGen：
```bash
# 使用 Homebrew
brew install xcodegen

# 或使用 Mint
mint install yonaskolb/xcodegen
```

2. 生成 Xcode 工程：
```bash
cd alist-ios
xcodegen generate
```

3. 打开生成的工程：
```bash
open Alist.xcodeproj
```

4. 在 Xcode 中选择你的开发团队，连接 iPhone 设备或模拟器，点击运行。

### 方法二：手动创建工程

1. 打开 Xcode，创建新的 iOS App 项目，命名为 `Alist`，选择 SwiftUI 界面、Swift 语言。

2. 将 `Alist/` 目录下所有 Swift 文件拖入项目，保持文件夹结构。

3. 将 `Info.plist` 替换为项目中的版本。

4. 添加 Swift Package Manager 依赖：
   - Alamofire (5.8.0+)
   - Kingfisher (7.0.0+)
   - MarkdownUI (2.0.0+)
   - CodeScanner (2.5.0+)
   - KeychainAccess (4.2.0+)

5. 配置 Capabilities：Background Modes（Audio, Fetch, Processing）。

6. 运行项目。

---

## 编译验证清单

在 Xcode 编译时，如遇错误，请按以下清单检查：

### 常见编译错误及解决方案

1. **`'jsonData' is not a member of type 'JSONEncoding'`**
   - 原因：旧代码使用 `.jsonData`（不存在）
   - 解决：已在 APIClient.swift 修复，改为直接构造 URLRequest

2. **`'default' is a keyword`**
   - 原因：`default` 是 Swift 保留字
   - 解决：已在 Storage.swift 修复，改为 `` `default` ``

3. **`Cannot convert value of type '[String: Any]' to expected argument type 'Encodable?'`**
   - 原因：异构字典不满足 Encodable
   - 解决：已在 LabelService.swift 修复，使用 `CreateLabelBindingReq` 结构体

4. **`Missing argument for parameter 'onComplete' in call`**
   - 原因：FileActionsView 调用方传入闭包但定义无对应参数
   - 解决：已在 FileActionsView.swift 修复，添加 `onComplete` 参数（有默认值）

5. **`Cannot convert value of type 'String?' to expected argument type 'String'`**
   - 原因：`error.errorDescription` 返回 `String?`
   - 解决：已修复，添加 `?? "操作失败"`

6. **`Cannot find type 'PHPickerViewController' in scope`**
   - 原因：缺少 `import PhotosUI`
   - 解决：已在 UploadView.swift 修复

7. **`Main actor-isolated static property 'shared' can not be referenced from a non-isolated context`**
   - 原因：`@ObservedObject` 属性初始化器立即求值
   - 解决：已在 DownloadsView.swift 修复，改为 `@StateObject`

8. **`Call to method 'show' in closure requires explicit 'self.' to make capture semantics explicit`**
   - 原因：闭包中引用 self 需要显式捕获
   - 解决：添加 `self.` 前缀或使用 `[weak self]`

### 编译前检查项

- [ ] 所有 `catch` 块都有错误处理（无空 catch）
- [ ] 所有 `URL(string:)!` 改为 `guard let` 或 `if let`
- [ ] 所有 `error.errorDescription` 都有 `??` 兜底
- [ ] 所有 `@MainActor` 单例用 `@StateObject` 而非 `@ObservedObject`
- [ ] 所有 Swift 保留字属性名加反引号
- [ ] 所有异构字典改为专用 Encodable 结构体
- [ ] 所有 PhotosUI 类型有 `import PhotosUI`
- [ ] `LoadingView` 调用有 `message:` 参数标签

---

## 使用说明

1. 启动 App 后，输入你的 Alist 服务器地址（例如 `https://your-server.com`）。
2. 输入用户名和密码登录（管理员默认 `admin`）。
3. 登录后可在「文件」标签浏览管理文件，「搜索」查找文件，「任务」查看上传/下载任务，「分享」管理文件分享，「我的」管理个人资料和后台。
4. 在「设置」中可检查服务器版本更新、查看 GitHub Releases。
5. 下载文件可在「下载」管理界面查看进度，支持暂停/恢复/取消。
6. 管理员用户可在「我的」→「管理后台」管理用户、存储、角色等。

---

## 兼容性

- 兼容 Alist v3.x 服务端
- 支持 iOS 16.0+ / iPadOS 16.0+
- 支持 iPhone 和 iPad

## 安全说明

- 密码使用 SHA256 静态哈希传输（与 Alist 后端一致：`SHA256(password-https://github.com/alist-org/alist)`）
- Token 存储在 Keychain（通过 KeychainAccess 库）
- 非敏感配置存储在 UserDefaults
- 支持 HTTP/HTTPS（已配置 ATS 允许任意域名以支持自建服务器）

## 依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| [Alamofire](https://github.com/Alamofire/Alamofire) | 5.8.0+ | HTTP 网络请求 |
| [Kingfisher](https://github.com/onevcat/Kingfisher) | 7.0.0+ | 图片加载和缓存 |
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) | 2.0.0+ | Markdown 渲染 |
| [CodeScanner](https://github.com/twostraws/CodeScanner) | 2.5.0+ | 二维码扫描 |
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | 4.2.0+ | Keychain 封装 |

## 许可证

遵循 Alist 的 AGPL-3.0 许可证。
