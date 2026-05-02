# Baby Time 前期架构设计与技术方案

## 1. 文档目标

本文基于 `baby_time.md` 产品需求文档，确定 Baby Time App 在 MVP 阶段的前期架构设计、核心技术选型、系统模块拆分、数据与存储方案、关键业务流程、非功能设计和阶段性交付建议。

MVP 的核心目标是完成：

- 用户账号与孩子档案管理。
- 照片上传、照片集创建和时间线归档。
- 录音或音频上传，并绑定到照片或照片集。
- tag、分类、备注和基础搜索。
- 云端同步、私密访问和基础数据安全。

首版不优先实现复杂社区、自由排版编辑器、AI 识别、家庭协作、视频、成长册导出等能力，但架构需为后续扩展预留空间。

## 2. 总体架构

### 2.1 架构形态

采用「移动端 App + 后端 API 服务 + 对象存储 + 关系型数据库 + 搜索能力」的标准架构。

```text
React Native App
  |
  | HTTPS API
  v
API Gateway / Backend Service
  |
  |-- Auth & User Module
  |-- Child Profile Module
  |-- Timeline Module
  |-- Media Metadata Module
  |-- Photo Collection Module
  |-- Audio Module
  |-- Tag & Category Module
  |-- Search Module
  |-- Upload Task Module
  |
  | SQL
  v
PostgreSQL

  |
  | Object files
  v
Object Storage

  |
  | Async jobs
  v
Worker / Queue
```

### 2.2 前期架构原则

- 移动端优先，围绕家长碎片时间内的快速记录设计。
- 媒体文件与业务元数据分离，图片和音频存对象存储，结构化信息存数据库。
- 默认私密，所有儿童照片、音频、孩子档案均需要账号鉴权和归属校验。
- MVP 先采用单体后端模块化架构，避免过早拆分微服务。
- 上传、缩略图生成、音频处理等耗时任务采用异步任务架构。
- 数据模型以照片、照片集、音频、时间线节点为核心，tag 与分类使用统一绑定模型支持扩展。

## 3. 技术选型

### 3.0 MVP 低成本默认方案

前期版本以“低固定成本、可上线、可扩展”为优先级。除非用户规模或性能指标已经证明需要升级，否则默认采用以下方案：

- 客户端使用 Expo + React Native + TypeScript，减少原生工程维护和打包成本。
- 后端使用 NestJS 模块化单体，部署为一个 API 服务，避免拆分多个微服务。
- 数据库使用托管 PostgreSQL 的低配实例或免费/低价套餐，优先保证自动备份和迁移能力。
- 媒体文件使用 S3 兼容对象存储私有桶，优先选择低存储成本、低流量成本方案。
- MVP 不单独部署 Redis，上传任务、异步处理状态先存 PostgreSQL。
- MVP 不启用 BullMQ 常驻队列，先使用 API 服务内的轻量后台任务或定时任务处理缩略图、清理失败上传等工作。
- MVP 不接独立搜索服务，先使用 PostgreSQL 普通索引、`ILIKE` 或全文索引。
- MVP 不接 CDN，媒体访问通过短期签名 URL；访问量上升后再按区域接入 CDN。
- MVP 不做服务端强制音频转码，先保存客户端可播放格式和 mime type；后续再补异步转码。
- MVP 默认保存压缩展示图和缩略图，原图是否保留通过配置控制，便于后续做容量策略。

升级触发条件：

- 上传任务明显堆积或缩略图处理影响 API 响应时，增加 Redis + BullMQ + 独立 Worker。
- 搜索响应慢或搜索体验不足时，引入 Meilisearch、Typesense 或 Elasticsearch。
- 媒体访问流量成本明显上升或跨地域访问慢时，引入 CDN。
- 音频格式兼容问题增多时，启用异步转码。
- 数据库 CPU、连接数或存储逼近套餐上限时，升级数据库实例或引入读写优化。

### 3.1 客户端

推荐技术栈：

- React Native：跨平台开发 iOS 和 Android。
- TypeScript：提升类型安全和长期维护性。
- React Navigation：页面导航和底部 Tab。
- TanStack Query：服务端状态、缓存、请求重试和分页加载。
- Zustand：本地轻量状态管理，例如当前孩子、上传队列 UI 状态。
- Expo：MVP 默认使用 Expo managed workflow。若后续录音、后台上传、原生 SDK 或 App Store 能力无法满足，再切换到 prebuild/bare workflow。

关键原生能力：

- 图片选择：优先系统照片选择器。
- 拍照：仅用户主动拍摄时申请相机权限。
- 录音：仅用户主动录音时申请麦克风权限。
- 音频播放：支持进度、暂停、继续和多音频列表。
- 本地缓存：缓存缩略图、上传任务状态、最近浏览数据。

### 3.2 服务端

推荐技术栈：

- Node.js + NestJS：适合 TypeScript 全栈一致性，模块化清晰。
- PostgreSQL：存储用户、孩子、时间线、媒体元数据、绑定关系。
- Prisma：数据库 schema 管理、迁移和类型安全访问。
- Redis：MVP 暂不强依赖，用户规模上升后用于缓存、队列和限流。
- BullMQ：MVP 暂不强依赖，后续用于缩略图生成、音频转码、重复检测等异步任务。
- OpenAPI：定义移动端与后端接口契约。

MVP 阶段采用模块化单体服务，按领域划分模块，不拆独立服务。后续当媒体处理、搜索或家庭协作复杂度上升时，再拆分 Worker、Search Service 或 Notification Service。

### 3.3 存储

推荐方案：

- 关系型数据库：PostgreSQL。
- 对象存储：S3 兼容存储、阿里云 OSS、腾讯云 COS 或 Cloudflare R2。
- CDN：后续根据访问量接入，MVP 可先使用对象存储签名 URL。
- 本地缓存：移动端缓存缩略图和最近数据，避免重复加载。

媒体文件建议路径：

```text
users/{user_id}/children/{child_id}/photos/{photo_id}/original
users/{user_id}/children/{child_id}/photos/{photo_id}/thumbnail
users/{user_id}/children/{child_id}/audio/{audio_id}/source
users/{user_id}/children/{child_id}/audio/{audio_id}/processed
```

对象存储桶默认私有，不允许公开读。客户端通过后端获取短期签名上传 URL 和短期签名下载 URL。

## 4. 客户端架构

### 4.1 页面结构

底部导航建议：

- 时间线：主入口，按孩子年龄阶段展示照片、照片集和音频摘要。
- 相册：照片墙、照片集列表、模板浏览。
- 录音：录音入口、声音记录列表。
- 搜索：标题、备注、tag、分类、音频标题检索。
- 我的：账号、孩子档案、tag 管理、分类管理、设置。

关键页面：

- 登录/注册页。
- 孩子档案选择与创建页。
- 时间线首页。
- 时间节点详情页。
- 上传照片页。
- 照片详情页。
- 照片集详情页。
- 照片集排版页。
- 录音页。
- tag 管理页。
- 分类管理页。
- 搜索结果页。
- 设置页。

### 4.2 客户端分层

```text
src/
  app/
  screens/
  components/
  features/
    auth/
    child/
    timeline/
    media/
    collection/
    audio/
    taxonomy/
    search/
    upload/
  services/
    api/
    storage/
    permissions/
    media/
  stores/
  types/
  utils/
```

分层说明：

- `screens`：页面容器，负责组合功能模块。
- `features`：按业务领域封装 hooks、组件和交互逻辑。
- `services/api`：后端 API 客户端和请求封装。
- `services/media`：图片压缩、录音、播放、文件选择等能力封装。
- `stores`：当前孩子、上传任务状态等跨页面状态。
- `types`：由 OpenAPI 或共享类型生成的接口类型。

### 4.3 上传队列设计

上传流程需支持批量上传、失败重试、弱网提示和进度展示。

客户端维护上传任务队列：

- `pending`：待上传。
- `uploading`：上传中。
- `processing`：服务端处理中，例如缩略图生成。
- `completed`：完成。
- `failed`：失败，可重试。

上传采用两段式：

1. 客户端向后端申请上传凭证，创建媒体占位记录。
2. 客户端直传对象存储，完成后通知后端确认并触发异步处理。

这样可以减少后端大文件传输压力。

## 5. 后端模块设计

### 5.1 账号模块

职责：

- 注册、登录、退出登录。
- 找回账号。
- 注销账号。
- 删除个人数据。
- 维护用户基础信息。

MVP 可先支持手机号或邮箱二选一登录，第三方登录放入后续版本。鉴权建议使用短期 access token + 长期 refresh token。

### 5.2 孩子档案模块

职责：

- 创建、编辑、删除孩子档案。
- 计算年龄、月龄和时间线节点归属。
- 支持用户拥有多个孩子档案。

关键规则：

- 所有照片、照片集、音频、tag/category 绑定均必须能追溯到 user 和 child。
- 时间线展示以孩子生日为基准计算。

### 5.3 时间线模块

职责：

- 根据孩子生日生成默认时间节点。
- 查询某个孩子的时间线摘要。
- 查询时间节点详情。
- 支持用户手动调整照片或照片集归属节点。

时间节点生成策略：

- 出生当天。
- 第 1 周。
- 第 1 个月至第 12 个月。
- 1 岁后按月份或年份聚合。

MVP 可先采用动态计算 + 缓存摘要的方案，避免为每个孩子提前生成大量空节点。照片、照片集和音频写入时保存 `timeline_node_id` 或标准化的 `age_month`，用于快速查询。

### 5.4 媒体模块

职责：

- 图片元数据管理。
- 上传凭证生成。
- 上传完成确认。
- 缩略图生成。
- 原图与压缩图存储策略。
- 重复照片检测。

MVP 建议：

- 保留压缩展示图和缩略图。
- 原图保存作为配置项，默认先保留原图，后续可用于会员容量策略。
- 重复检测先基于文件 hash 和拍摄时间做弱提醒，不阻断上传。

### 5.5 照片集模块

职责：

- 创建照片集。
- 添加、移除和排序照片。
- 设置封面。
- 保存基础模板和布局数据。
- 绑定 tag、分类和音频。

MVP 模板：

- 网格模板。
- 主图模板。
- 横向故事模板。
- 时间顺序模板。
- 封面加详情模板。

`layout_data` 使用 JSON 存储，记录模板所需的排序、主图、局部位置等信息。首版不实现自由画布。

### 5.6 音频模块

职责：

- 录音文件上传。
- 本地音频文件上传。
- 音频元数据管理。
- 音频绑定照片或照片集。
- 播放地址鉴权。
- 删除音频和解绑。

MVP 建议统一处理为 AAC 或 MP3，降低跨端播放和长期保存风险。转码可异步处理，前期若客户端录音格式稳定，可先保存源文件并记录 mime type。

### 5.7 tag 与分类模块

职责：

- 管理用户自定义 tag。
- 管理系统分类与用户自定义分类。
- 给照片、照片集、音频绑定或解绑 tag/category。
- 支持筛选和搜索。

设计原则：

- tag 灵活、细粒度，可多选。
- 分类稳定、较高层级，可作为内容组织主线。
- 删除 tag/category 不删除内容，只删除绑定关系。

### 5.8 搜索模块

MVP 搜索范围：

- 照片备注。
- 照片集标题与备注。
- tag 名称。
- 分类名称。
- 音频标题与备注。

前期可使用 PostgreSQL 全文索引或普通模糊查询。随着数据量增长，再引入 Meilisearch、Typesense 或 Elasticsearch。

搜索结果类型需要区分：

- `photo`
- `photo_collection`
- `audio`
- `timeline_node`

## 6. 数据模型设计

### 6.1 核心实体

核心表：

- `users`
- `children`
- `timeline_nodes`
- `photos`
- `photo_collections`
- `photo_collection_items`
- `audios`
- `audio_bindings`
- `tags`
- `tag_bindings`
- `categories`
- `category_bindings`
- `upload_tasks`

### 6.2 关键字段建议

`photos`：

- `id`
- `user_id`
- `child_id`
- `timeline_node_id`
- `file_url`
- `thumbnail_url`
- `original_file_url`
- `file_hash`
- `taken_at`
- `uploaded_at`
- `title`
- `note`
- `created_at`
- `updated_at`
- `deleted_at`

`photo_collections`：

- `id`
- `user_id`
- `child_id`
- `timeline_node_id`
- `title`
- `cover_photo_id`
- `layout_template`
- `layout_data`
- `note`
- `created_at`
- `updated_at`
- `deleted_at`

`audios`：

- `id`
- `user_id`
- `child_id`
- `timeline_node_id`
- `file_url`
- `processed_file_url`
- `duration`
- `mime_type`
- `audio_type`
- `title`
- `note`
- `created_at`
- `updated_at`
- `deleted_at`

绑定表均建议冗余 `user_id`，便于权限过滤和查询优化。

### 6.3 多态绑定

音频、tag、分类都需要支持不同目标对象。MVP 可采用 `target_type + target_id` 多态绑定。

约束：

- `target_type` 仅允许明确枚举值。
- 写入绑定前必须校验目标对象归属同一 `user_id` 和 `child_id`。
- 删除目标对象时软删除或级联删除绑定关系。

后续如果查询复杂度显著上升，可拆分为明确关联表，例如 `photo_tag_bindings`、`collection_tag_bindings`。

### 6.4 删除策略

儿童照片和音频属于敏感数据，删除策略需明确：

- 普通内容删除先采用软删除，避免误删后无法恢复。
- 用户注销或删除个人数据时，进入异步硬删除流程。
- 对象存储文件删除需要与数据库状态一致，失败时记录补偿任务。
- 删除照片集时，按 PRD 要求让用户选择是否保留其中单张照片。

## 7. API 设计

### 7.1 API 风格

采用 REST API + JSON，使用 OpenAPI 维护接口契约。

统一约定：

- 所有业务接口使用 HTTPS。
- 鉴权头：`Authorization: Bearer <access_token>`。
- 列表接口使用 cursor 或 page 分页。
- 创建、更新、删除接口返回最新资源摘要。
- 错误响应包含稳定错误码、错误消息和 request id。

### 7.2 关键接口分组

账号：

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/logout`
- `DELETE /me`

孩子档案：

- `GET /children`
- `POST /children`
- `PATCH /children/{childId}`
- `DELETE /children/{childId}`

时间线：

- `GET /children/{childId}/timeline`
- `GET /children/{childId}/timeline/{nodeId}`
- `PATCH /photos/{photoId}/timeline`
- `PATCH /collections/{collectionId}/timeline`

照片：

- `POST /photos/upload-intent`
- `POST /photos/{photoId}/complete-upload`
- `GET /children/{childId}/photos`
- `GET /photos/{photoId}`
- `PATCH /photos/{photoId}`
- `DELETE /photos/{photoId}`

照片集：

- `POST /collections`
- `GET /children/{childId}/collections`
- `GET /collections/{collectionId}`
- `PATCH /collections/{collectionId}`
- `POST /collections/{collectionId}/items`
- `PATCH /collections/{collectionId}/items/order`
- `DELETE /collections/{collectionId}`

音频：

- `POST /audios/upload-intent`
- `POST /audios/{audioId}/complete-upload`
- `GET /children/{childId}/audios`
- `GET /audios/{audioId}`
- `PATCH /audios/{audioId}`
- `DELETE /audios/{audioId}`
- `POST /audios/{audioId}/bindings`
- `DELETE /audios/{audioId}/bindings/{bindingId}`

tag 与分类：

- `GET /tags`
- `POST /tags`
- `PATCH /tags/{tagId}`
- `DELETE /tags/{tagId}`
- `GET /categories`
- `POST /categories`
- `PATCH /categories/{categoryId}`
- `DELETE /categories/{categoryId}`
- `POST /bindings/tags`
- `DELETE /bindings/tags/{bindingId}`
- `POST /bindings/categories`
- `DELETE /bindings/categories/{bindingId}`

搜索：

- `GET /children/{childId}/search?q=&type=&cursor=`

## 8. 核心流程设计

### 8.1 照片上传并创建照片集

1. 用户在 App 选择多张照片。
2. 客户端读取拍摄时间、文件大小、mime type 等基础信息。
3. 客户端请求 `upload-intent`，后端创建照片占位记录和上传任务。
4. 后端返回对象存储签名上传 URL。
5. 客户端直传对象存储并展示进度。
6. 客户端通知后端上传完成。
7. 后端异步生成缩略图、计算 hash、更新照片状态。
8. 系统根据拍摄时间与孩子生日推荐时间线节点。
9. 用户确认或调整时间节点。
10. 用户创建照片集、选择模板、设置标题、tag 和分类。

### 8.2 给照片集绑定录音

1. 用户进入照片集详情页并点击录音。
2. 客户端申请麦克风权限。
3. 用户录音、暂停、继续、试听或重录。
4. 保存时创建音频上传任务。
5. 客户端上传录音文件。
6. 后端保存音频元数据，必要时异步转码。
7. 后端创建 `audio_binding`，绑定目标为 `photo_collection`。
8. 照片集详情页刷新音频列表并支持播放。

### 8.3 时间线浏览

1. App 加载当前孩子信息。
2. 请求时间线摘要接口。
3. 后端返回节点标题、封面、照片数量、照片集数量、音频数量、最近更新和常用 tag。
4. 用户点击时间节点后分页加载照片、照片集和音频。
5. 图片优先加载缩略图，详情页按需加载高清图。

## 9. 安全与隐私设计

### 9.1 鉴权与授权

- 所有接口默认需要登录。
- 所有资源查询必须附带 `user_id` 归属校验。
- 文件下载不暴露永久公开 URL。
- 对象存储使用短期签名 URL。
- 管理端或运维操作需记录审计日志。

### 9.2 数据隐私

- 默认不公开任何内容。
- 首版不提供公开社区和公开分享。
- 儿童照片、音频、孩子资料不得用于广告训练或公开推荐。
- 支持删除照片、音频、孩子档案、账号和个人数据。
- 支持后续实现数据导出。

### 9.3 移动端权限

- 相册选择优先使用系统照片选择器。
- 麦克风权限仅在主动录音时申请。
- 相机权限仅在主动拍摄时申请。
- 权限拒绝后提供清晰提示，不强制阻断其他功能。

## 10. 性能与稳定性

### 10.1 性能目标

- 时间线首屏目标 2 秒内可见。
- 照片列表使用分页和虚拟列表。
- 缩略图优先加载，原图按需加载。
- 音频点击后尽快开始播放。
- 时间线摘要接口避免返回大体积媒体详情。

### 10.2 稳定性策略

- 上传任务可重试。
- App 重启后恢复未完成上传任务。
- 弱网状态显示明确提示。
- 删除操作二次确认。
- 异步任务失败记录状态并支持后台重试。
- 数据库关键写操作使用事务。

### 10.3 可观测性

前期至少接入：

- 后端接口访问日志。
- 错误日志和 request id。
- 上传成功率、失败率和耗时。
- 缩略图生成任务成功率。
- 客户端崩溃日志。

### 10.4 自动化测试与上线准入

所有版本功能必须配套自动化测试。功能未通过测试不得上线。

测试分层：

- 单元测试：覆盖服务函数、权限判断、时间线计算、绑定逻辑、上传状态机、表单校验等核心逻辑。
- API 集成测试：覆盖鉴权、资源归属校验、CRUD、上传 intent、绑定/解绑、搜索等接口。
- 客户端组件测试：覆盖关键表单、列表状态、上传队列状态、录音状态和错误提示。
- 端到端测试：覆盖注册登录、创建孩子、上传照片、创建照片集、录音绑定、播放入口、搜索等核心路径。
- 数据库迁移测试：每次 schema 变更必须能在空库和已有测试库上成功执行。

上线准入：

- TypeScript 类型检查通过。
- Lint 通过。
- 后端单元测试通过。
- 后端 API 集成测试通过。
- 客户端单元/组件测试通过。
- E2E 冒烟测试通过。
- 数据库迁移测试通过。
- 测试覆盖率未低于项目设定阈值。

## 11. MVP 交付范围

### 11.1 V1.0 必做

- 账号注册登录。
- 创建和切换孩子档案。
- 照片单张、多张上传。
- 时间线自动归档。
- 时间线首页和节点详情。
- 创建照片集。
- 照片集排序、封面、基础模板。
- tag 创建、绑定、编辑、筛选。
- 录音、上传、试听、保存。
- 音频绑定照片或照片集。
- 音频播放。
- 基础搜索。
- 云端同步和访问权限控制。

### 11.2 V1.0 可降级实现

- 分类体系可先内置固定分类，再开放自定义。
- 重复照片检测可先提示，不做强阻断。
- 音频转码可先延后，只记录源文件格式并保证客户端可播放。
- 原图保留策略可先默认保留，后续接入容量限制和会员策略。
- 搜索可先用数据库查询，后续再引入独立搜索服务。

### 11.3 V1.0 暂不做

- 家庭成员协作。
- 视频上传。
- AI 自动 tag。
- 音频转文字。
- 成长册导出。
- 私密分享链接。
- 自由排版编辑器。
- 纪念日提醒。

## 12. 里程碑建议

### 阶段一：基础工程与账号闭环

- 建立 React Native App 工程。
- 建立后端 API 工程、数据库迁移和 OpenAPI。
- 完成注册登录、token 刷新、孩子档案 CRUD。
- 完成基础权限校验中间件。

### 阶段二：媒体上传与时间线

- 完成照片上传 intent、直传对象存储、上传完成确认。
- 完成缩略图生成 Worker。
- 完成时间线节点计算和时间线摘要。
- 完成照片列表、照片详情和时间节点详情。

### 阶段三：照片集、tag、分类

- 完成照片集 CRUD。
- 完成照片排序、封面和基础模板数据保存。
- 完成 tag/category 创建、绑定、解绑和筛选。

### 阶段四：录音与音频绑定

- 完成客户端录音、试听、重录和上传。
- 完成音频元数据、绑定关系和播放地址鉴权。
- 完成照片详情、照片集详情中的音频播放列表。

### 阶段五：搜索、稳定性与上线准备

- 完成基础搜索。
- 完成上传失败重试和任务恢复。
- 完成删除确认、软删除和数据补偿任务。
- 完成日志、错误监控、基础隐私设置和上线检查。

## 13. 主要技术风险与应对

### 13.1 媒体存储成本

风险：照片和音频会长期增长，带来对象存储和流量成本。

应对：

- 缩略图、压缩图、原图分层存储。
- 预留用户容量统计字段。
- 后续支持会员容量和原图策略。

### 13.2 上传链路复杂

风险：移动端弱网、后台切换、批量上传会导致失败率上升。

应对：

- 客户端维护可恢复上传队列。
- 后端记录上传任务状态。
- 对象存储直传减少后端压力。
- 上传完成确认后再进入可见状态。

### 13.3 儿童隐私信任

风险：用户对儿童照片和声音非常敏感，任何越权访问都会造成严重信任损失。

应对：

- 默认私有桶。
- 所有资源按 user_id 做权限校验。
- 下载使用短期签名 URL。
- 删除、导出、注销能力纳入首版架构。

### 13.4 排版功能膨胀

风险：照片集排版容易发展成复杂编辑器，影响 MVP 交付。

应对：

- 首版只做固定模板、顺序调整、封面设置。
- `layout_data` 保持扩展性，为后续自由排版预留。

## 14. 待确认决策

以下问题不影响前期架构启动，但会影响 MVP 的产品和成本边界：

- 首版是否必须支持视频：建议不支持。
- 首版是否支持家庭成员协作：建议不支持，仅预留数据结构扩展。
- 免费用户容量上限：建议在商业化方案确认后确定。
- 是否保留原图：建议 MVP 默认保留，但增加容量统计和后续策略开关。
- 音频是否统一转码：建议后端预留转码任务，MVP 可先保存源文件。
- 是否支持离线查看：建议先支持最近内容缓存，不做完整离线模式。
- 是否支持数据导出：架构预留，产品入口可放后续版本。
- 是否面向海外市场：若计划海外上线，需要提前考虑手机号登录、对象存储区域、隐私合规和多语言。
- 是否允许分享到微信或朋友圈：建议首版不做公开分享。

## 15. 结论

Baby Time 的 MVP 应以“成长时间线 + 照片/照片集 + 声音绑定 + tag 搜索”为最小核心闭环。前期架构建议采用 Expo + React Native + TypeScript 客户端、Node.js/NestJS 模块化单体后端、PostgreSQL 元数据与任务状态存储、对象存储承载媒体文件，并由 API 服务内的轻量后台任务处理缩略图和清理任务。Redis/BullMQ、独立搜索、CDN、音频转码等能力在用户规模或性能指标触发后再引入。

该方案能在首版控制复杂度，同时为多孩子、家庭协作、AI tag、音频转文字、成长册导出、会员容量等后续能力保留清晰扩展路径。
