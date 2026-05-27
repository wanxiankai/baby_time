# Baby Time

Baby Time 是一款面向家长的儿童成长记录 iOS 原生 App。产品以时间线节点为主轴，整理孩子成长过程中的照片、录音、文字备注、tag 和分类信息，形成一份"带声音的成长档案"。

技术方案明确为 **iOS 原生开发**，数据方案只保留**本地数据 + 系统相册引用**这一种方式：App **不会上传也不会保存**用户的照片原文件，只在本机记录用户选择的系统相册照片的引用以及节点关联关系。

## 当前版本

当前 iOS MVP 已实现本地可运行版本，覆盖以下核心闭环：

- 本地账号注册、登录、退出；**登录完成后自动进入首页 Tab**。
- 未登录打开 App 直接展示登录/注册页。
- 创建和切换孩子档案；首次创建孩子时**自动生成默认成长时间节点**（出生第一天、出生第一周、第 1~12 个月、一周岁）。
- 首页时间线 Tab：上下滑动浏览全部节点；每个节点展示**名称、具体日期、前 3 张照片**；超过 3 张时只展示前 3 张并提示"共 N 张"；没有任何照片时显示"去添加"占位入口。
- 首页右上角**新增时间节点**按钮：弹窗内选择日期、填写名称，确定后按时间顺序正确插入。
- 节点详情页：查看节点名称、日期、照片集、绑定音频；从系统相册导入照片自动归属本节点；点击照片可全屏查看大图；点击音频可播放。
- **长按**节点详情页的图片进入"解除关联模式"，照片右上角显示叉，点击叉后弹出二次确认弹窗，文案明确告知"仅解除当前节点关联，不会删除系统相册中的原始照片"。
- 创建照片集，支持备注、模板和封面设置。
- 创建 tag 和分类，给照片、照片集绑定 tag 和分类；给音频绑定 tag。
- 录音、暂停、继续、停止、保存；可在保存时绑定到节点 / 照片 / 照片集。
- 导入本地音频文件。
- 搜索时间节点、照片、照片集、音频、tag 和分类；已绑定 tag/分类也会命中对应内容。
- App Intents / Shortcuts：打开时间线、打开录音入口。
- XCTest 单元测试覆盖核心本地业务逻辑（包含节点 CRUD、默认节点生成、节点照片关联与解除等）。

当前 iOS MVP 使用本地 JSON 文件保存业务数据（账号、孩子档案、时间节点、照片索引、照片集、tag、分类、音频元数据）。从系统相册导入的照片只记录 `localAssetIdentifier`，照片原文件始终留在系统相册中。样例照片和录音文件仍保存在 App Documents 目录，仅用于模拟器验证核心交互。

当前阶段的开发边界是**本地优先且永久无云端**：本项目不会引入任何云端存储或后端服务来托管用户照片。

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

- 账号注册、登录、退出，登录后默认 Tab 校验。
- 注册输入校验。
- 创建孩子档案时**自动生成 15 个默认时间节点**（出生第一天 / 出生第一周 / 第 1~12 个月 / 一周岁）。
- 新增节点：按日期正确排序插入、空名称拒绝、未创建孩子时拒绝、重名重日去重。
- 修改节点信息。
- 删除节点时同时解除照片与音频对该节点的关联（不删除照片/音频记录本身）。
- 照片自动归属到最匹配的时间节点。
- 节点照片列表查询、手动挂载、手动解除节点关联（只断关联不删原始记录）。
- 首页聚合视图：超过 3 张照片时只展示前 3 张、不足 3 张时全部展示、0 张时展示空状态。
- 照片集创建、编辑、tag/分类绑定。
- 系统相册导入资产标识与原图缺失状态处理。
- 搜索节点、照片、tag、分类。
- tag/分类绑定。
- 音频绑定到照片、音频绑定到节点、音频持久化重载。

## MVP 验收路径

在模拟器中可以按以下路径验证当前版本：

1. 打开 App，默认进入登录/注册页，注册本地账号。
2. 登录完成自动进入首页时间线 Tab。
3. 在"我的"页创建孩子档案，回到首页查看自动生成的默认节点列表。
4. 在首页右上角点击新增节点按钮，填写名称和日期，确认后查看节点是否按日期正确插入。
5. 点击某个节点进入详情页，从系统相册导入照片或添加样例照片。
6. 返回首页，确认对应节点卡片显示了前 3 张照片缩略图。
7. 在节点详情页点击单张照片查看大图；长按任意照片进入解除关联模式，点击右上角叉，确认弹出二次确认弹窗，确定后照片从该节点移除。
8. 在录音页录制声音并绑定到时间节点 / 照片 / 照片集。
9. 返回节点详情页查看绑定音频并播放。
10. 在搜索页搜索时间节点名称、照片、tag、分类，确认结果正确。

## 媒体保存方案

Baby Time 永久遵循"App 不上传也不保存用户照片"的方案：

- 从系统相册导入的照片只在 App 本地 JSON 中记录系统相册的资产标识（`localAssetIdentifier`）以及节点关联关系。
- 用户在相册中删除原图或撤销相册权限后，App 会在对应位置展示"原照片不存在"或"相册权限失效"等占位状态。
- 在节点详情页解除关联或删除时间节点，只会移除 App 内的关联关系，**永远不会**触发删除系统相册中的原始照片。
- 录音与导入的本地音频文件会复制到 App 自己的 Documents 目录，仅用于本机播放，不会上传到任何服务端。

## 后续开发方向

后续可选优化方向：

- 真实账号体系（密码哈希、找回密码、注销流程）。
- 节点详情页支持音频删除关联。
- 节点详情页支持照片排序。
- 隐私政策、用户协议文案完善。
- CI 自动化测试流程。
- TestFlight 内测配置。

详细任务见：

- `mvp_task_breakdown.md`
- `launch_preparation_checklist.md`
- `architecture_technical_plan.md`

## GitHub

远程仓库：

[https://github.com/wanxiankai/baby_time](https://github.com/wanxiankai/baby_time)
