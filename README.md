# Baby Time

Baby Time 是一款面向家长的儿童成长记录 App。产品核心是以时间线为主轴，保存孩子成长过程中的照片、照片集、录音、文字备注、tag 和分类信息，形成一份“带声音的成长档案”。

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

当前版本使用本地 JSON 文件和 App Documents 目录存储数据与媒体文件，暂未接入真实后端、云同步和对象存储。

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

## 后续开发方向

后续正式上线前需要补齐：

- 真实后端 API。
- 账号密码哈希、token 登录和权限校验。
- PostgreSQL 元数据存储。
- 私有对象存储。
- 短期签名上传和下载 URL。
- 云同步。
- 上传队列和失败重试。
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
