# Baby Time

Baby Time 是一款面向家长的儿童成长记录 App。产品核心是以时间线为主轴，整理孩子成长过程中的照片、照片集、录音、文字备注、tag 和分类信息，形成一份“带声音的成长档案”。

最新产品方案采用隐私优先的媒体保存策略：照片默认不进入 Baby Time 后端。用户可以选择“本机索引模式”，只记录系统相册中的照片引用；也可以选择“授权云端备份模式”，把照片备份到自己授权的 iCloud Drive、Google Drive、OneDrive、Dropbox 等云端存储中。

当前仓库包含产品需求文档、前期架构设计、MVP 任务拆分、上线准备清单，以及一个可在 iOS 模拟器运行的原生 SwiftUI MVP。

## 当前版本

当前 iOS MVP 已实现本地可运行版本，用于验证核心产品闭环：

- 本地账号注册、登录、退出。
- 创建和切换孩子档案。
- 时间线浏览，支持上下滑动查看完整时间线节点。
- 添加模拟器样例照片。
- 从系统相册导入照片。
- 照片详情查看。
- 创建照片集。
- 创建 tag 和分类。
- 给照片绑定 tag 和分类。
- 录音、暂停、继续、停止、保存。
- 保存录音时绑定到照片集。
- 音频列表播放。
- 搜索照片、照片集、音频、tag 和分类。
- App Intents / Shortcuts：打开时间线、打开录音入口。
- XCTest 单元测试覆盖核心本地业务逻辑。

当前 iOS MVP 使用本地 JSON 文件保存业务数据。真实相册导入会保存系统相册资产引用；样例照片和录音仍保存在 App Documents 目录，主要用于模拟器验证核心交互。照片原文件不默认上传到 Baby Time 后端，也不默认进入 Baby Time 自有对象存储。

## 技术栈

- iOS：SwiftUI
- 本地状态与持久化：`ObservableObject` + JSON 文件
- 图片导入：PhotosUI
- 录音与播放：AVFoundation
- 系统快捷入口：AppIntents
- 测试：XCTest
- 最低 iOS 版本：iOS 17.0
- Xcode：16.4 或更新版本

## 目录结构

```text
BabyTime.xcodeproj/              Xcode 工程
BabyTime/                        iOS App 源码
  BabyTimeApp.swift              App 入口
  Models.swift                   数据模型
  AppStore.swift                 本地状态、持久化和业务逻辑
  MediaServices.swift            录音和播放服务
  Views.swift                    SwiftUI 页面
  BabyTimeIntents.swift          App Intents / Shortcuts
  Info.plist                     权限和 App 配置
BabyTimeTests/                   XCTest 单元测试
baby_time.md                     产品需求文档
architecture_technical_plan.md   前期架构设计与技术方案
mvp_task_breakdown.md            MVP 任务拆分与测试计划
launch_preparation_checklist.md  上线前账号与配置准备清单
ios_mvp_setup.md                 iOS MVP 配置与运行说明
```

## 本地运行

1. 使用 Xcode 打开：

```text
BabyTime.xcodeproj
```

2. 选择 Scheme：

```text
BabyTime
```

3. 选择 iOS Simulator，例如：

```text
iPhone 16 / iOS 18.6
```

4. 点击 Run。

也可以使用命令行构建：

```bash
xcodebuild -project BabyTime.xcodeproj \
  -scheme BabyTime \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/babytime-derived \
  build
```

运行到指定模拟器：

```bash
xcodebuild -project BabyTime.xcodeproj \
  -scheme BabyTime \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath /tmp/babytime-derived \
  build
```

## 测试

执行单元测试：

```bash
xcodebuild -project BabyTime.xcodeproj \
  -scheme BabyTime \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath /tmp/babytime-derived \
  test
```

如果本机模拟器名称不同，先查看可用设备：

```bash
xcrun simctl list devices available
```

当前测试覆盖：

- 账号注册、登录、退出。
- 孩子档案创建。
- 时间线节点计算。
- 添加照片。
- 创建照片集。
- tag 和分类绑定。
- 搜索。

## MVP 验收路径

在模拟器中可以按以下路径验证当前版本：

1. 注册本地账号。
2. 创建孩子档案。
3. 在时间线页上下滑动查看完整节点。
4. 点击添加样例照片。
5. 在相册页从系统相册导入照片。
6. 选择照片创建照片集。
7. 在我的页创建 tag 和分类。
8. 进入照片详情绑定 tag 和分类。
9. 在录音页录制声音并绑定照片集。
10. 在照片集详情播放绑定音频。
11. 在搜索页搜索照片、照片集、tag、分类和音频。

## 媒体保存方案

正式产品需要支持两种隐私优先模式：

- 本机索引模式：App 只保存系统相册资产引用、时间线归属、照片集、tag、分类和备注等索引信息。照片仍在用户手机相册中；用户删除原图或撤销相册权限后，App 展示照片缺失提示。
- 授权云端备份模式：用户授权自己的云端存储服务后，App 将照片按规则命名并上传到用户授权目录。Baby Time 只保存索引、绑定关系、云端服务类型和云端文件定位信息，不保存照片原文件。

删除 Baby Time 内的照片记录时，默认只删除 App 内索引和绑定关系，不删除系统相册原图，也不删除用户云盘文件。若未来支持删除云端备份文件，需要单独确认。

## 后续开发方向

后续正式上线前需要补齐：

- 真实后端 API。
- 账号密码哈希、token 登录和权限校验。
- PostgreSQL 元数据与索引存储。
- 本机索引模式改造。
- 至少一种主流云端存储服务授权与备份。
- 云端备份队列、进度展示和失败重试。
- 相册权限失效、原照片删除、云端文件缺失和云端授权过期处理。
- Baby Time 托管存储能力作为后续可选模式评估。
- 隐私政策、用户协议和账号注销流程。
- CI 自动化测试流程。
- TestFlight 内测配置。

详细任务见：

- `mvp_task_breakdown.md`
- `launch_preparation_checklist.md`
- `architecture_technical_plan.md`

## GitHub

远程仓库：

[https://github.com/wanxiankai/baby_time](https://github.com/wanxiankai/baby_time)
