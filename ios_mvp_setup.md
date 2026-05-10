# Baby Time iOS MVP 配置与运行说明

## 1. 当前实现说明

当前 iOS MVP 是一个原生 SwiftUI 模拟器版本，用于先验证产品闭环：

- 本地邮箱账号注册/登录。
- 创建和切换孩子档案。
- 时间线自动归档。
- 添加模拟器样例照片。
- 从系统相册导入单张或多张照片。
- 创建照片集，并编辑备注、模板和封面。
- 创建 tag 和分类。
- 给照片、照片集绑定 tag/分类；给音频绑定 tag。
- 录音、保存音频、导入本地音频文件。
- 音频绑定到照片或照片集。
- 音频播放。
- 基础搜索，支持通过已绑定 tag/分类命中内容。
- App Shortcuts/App Intents：打开时间线、打开录音入口。
- XCTest 单元测试覆盖账号、孩子档案、时间线、照片集、音频绑定、本地持久化、tag/分类和搜索。

MVP 暂未接入真实后端、云同步和对象存储。当前阶段先完整保留本地 JSON 存储闭环；上线前再把 `AppStore` 中的本地 JSON 存储替换或同步到 API client，并按最新产品方案接入授权云端备份模式、后端索引 API 和 PostgreSQL。

根据最新产品方案，正式版本不应默认把照片原文件上传到 Baby Time 后端或自有对象存储。后续改造目标是：

- 本机索引模式：保存系统相册资产引用和整理信息，照片仍在用户手机相册。
- 授权云端备份模式：用户授权云端存储服务后，照片备份到用户自己的云端目录。
- Baby Time 后端只保存账号、孩子档案、时间线、照片索引、照片集、tag、分类和云端定位信息。
- 当前 App Documents 中复制样例照片的实现仅用于模拟器验证；真实相册导入已改为保存系统相册资产引用。

## 2. Xcode 与模拟器配置

当前机器检测结果：

- Xcode 版本：16.4。
- 当前没有可用 iOS Simulator 设备。
- `xcrun simctl list devices available` 只返回 `Unavailable: com.apple.CoreSimulator.SimRuntime.iOS-18-5`。

需要在 Xcode 中安装 iOS Simulator Runtime：

1. 打开 Xcode。
2. 进入 `Xcode > Settings... > Platforms`。
3. 安装一个可用 iOS runtime，例如 iOS 18.5 或 Xcode 当前支持的最新 iOS Simulator。
4. 安装完成后进入 `Window > Devices and Simulators`。
5. 在 `Simulators` 页新增设备，例如：
   - Device Type：`iPhone 16` 或 `iPhone 15`
   - OS Version：刚安装的 iOS runtime

Apple 官方入口：

- [Xcode 下载](https://developer.apple.com/xcode/)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Creating your first app intent](https://developer.apple.com/documentation/appintents/creating-your-first-app-intent)
- [Making actions and content discoverable and widely available](https://developer.apple.com/documentation/appintents/making-actions-and-content-discoverable-and-widely-available)

## 3. 本地构建命令

在项目根目录执行：

```text
xcodebuild -project BabyTime.xcodeproj -scheme BabyTime -destination 'generic/platform=iOS Simulator' -derivedDataPath ./DerivedData build
```

编译测试包：

```text
xcodebuild -project BabyTime.xcodeproj -scheme BabyTime -destination 'generic/platform=iOS Simulator' -derivedDataPath ./DerivedData build-for-testing
```

安装模拟器 runtime 并创建设备后，执行单元测试：

```text
xcodebuild -project BabyTime.xcodeproj -scheme BabyTime -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath ./DerivedData test
```

如果设备名不同，先查看可用设备：

```text
xcrun simctl list devices available
```

然后替换 `name=iPhone 16`。

## 4. Xcode 项目配置

当前项目：

- Project：`BabyTime.xcodeproj`
- Scheme：`BabyTime`
- Bundle ID：`com.babytime.mvp`
- Minimum iOS：17.0
- Display Name：`Baby Time`

真实发布前需要在 Xcode 中配置：

1. 打开 `BabyTime.xcodeproj`。
2. 选择 `BabyTime` target。
3. 进入 `Signing & Capabilities`。
4. 选择你的 Apple Developer Team。
5. 将 Bundle ID 改成你的真实 ID，例如 `com.yourcompany.babytime`。

Apple Developer 配置地址：

- [Apple Developer Account](https://developer.apple.com/account/)
- [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/)
- [App Store Connect](https://appstoreconnect.apple.com/)

## 5. 权限配置

当前 `BabyTime/Info.plist` 已配置：

- `NSMicrophoneUsageDescription`
- `NSPhotoLibraryUsageDescription`

如果后续增加相机拍摄，需要补充：

```text
NSCameraUsageDescription
```

如果后续增加授权云端备份的后台任务，需要评估：

```text
UIBackgroundModes
```

## 6. 后端与云端备份接入配置

当前 iOS MVP 不需要后端即可运行。接入真实服务时建议新增环境配置文件或 build settings：

```text
API_BASE_URL=
APP_ENV=staging|production
SENTRY_DSN=
ANALYTICS_ENABLED=
```

如果接入用户云端备份，还需要按 Provider 配置客户端授权信息，例如：

```text
GOOGLE_DRIVE_CLIENT_ID=
ONEDRIVE_CLIENT_ID=
DROPBOX_APP_KEY=
ICLOUD_CONTAINER_ID=
```

对应后端和云资源配置详见：

- `launch_preparation_checklist.md`
- `architecture_technical_plan.md`
- `mvp_task_breakdown.md`

## 7. MVP 验收路径

模拟器可用后，手动验收路径：

1. 注册本地账号。
2. 创建孩子档案。
3. 时间线页点击添加样例照片。
4. 相册页从系统相册导入照片。
5. 相册页选择照片并创建照片集。
6. 我的页创建 tag 和分类。
7. 照片详情绑定 tag 和分类。
8. 录音页录制声音并绑定到照片集。
9. 照片集详情播放绑定音频。
10. 搜索页搜索照片标题、照片集、tag、分类和音频。
11. 使用 Shortcuts 搜索 Baby Time，验证“打开时间线”和“记录声音”快捷入口。

自动化验收：

- `StoreTests` 覆盖本地核心业务逻辑。
- 安装可用模拟器 runtime 后执行 `xcodebuild test`。

## 8. 上线前必须补齐

当前版本适合模拟器和早期产品验证。正式上线前必须补齐：

- 真实后端 API。
- PostgreSQL 数据库。
- 本机索引模式。
- 至少一种主流云端存储授权与备份。
- 云端备份队列、进度、失败重试和授权失效处理。
- 相册原图删除、相册权限撤销和有限照片访问变化处理。
- Baby Time 托管存储如需上线，应作为可选模式单独评估。
- 密码哈希和 token 登录。
- 云端 Provider 最小权限校验。
- 崩溃监控。
- 隐私政策和用户协议。
- App Store Connect App 隐私问卷。
- TestFlight 内测配置。
