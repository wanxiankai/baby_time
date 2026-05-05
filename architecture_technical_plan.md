# Baby Time 前期架构设计与技术方案

## 1. 文档目标

本文基于 `baby_time.md` 产品需求文档，确定 Baby Time App 在 MVP 阶段的前期架构设计、核心技术选型、系统模块拆分、数据与存储方案、关键业务流程、非功能设计和阶段性交付建议。

MVP 的核心目标是完成：

- 用户账号与孩子档案管理。
- 隐私说明、媒体保存方式选择、照片导入、照片集创建和时间线归档。
- 本机索引模式：记录系统相册资产引用，不上传、不长期复制照片原文件。
- 授权云端备份模式：用户授权自己的云端存储，照片备份到用户云端目录。
- 录音或音频上传，并绑定到照片或照片集。
- tag、分类、备注和基础搜索。
- 照片索引同步、私密访问和基础数据安全。

首版不优先实现复杂社区、自由排版编辑器、AI 识别、家庭协作、视频、成长册导出等能力，但架构需为后续扩展预留空间。

## 2. 总体架构

### 2.1 架构形态

采用「移动端 App + 后端索引 API 服务 + 关系型数据库 + 用户授权云端存储 + 搜索能力」的隐私优先架构。Baby Time 后端默认只保存账号、孩子档案、照片索引、照片集、tag、分类、时间线和云端定位信息，不保存儿童照片原文件。

```text
React Native App
  |
  | HTTPS API
  v
API Gateway / Backend Service
  |
  |-- Auth & User Module
  |-- Child Profile Module
  |-- Privacy & Storage Mode Module
  |-- Timeline Module
  |-- Media Index Module
  |-- Photo Collection Module
  |-- Audio Module
  |-- Tag & Category Module
  |-- Search Module
  |-- Cloud Backup Task Module
  |
  | SQL
  v
PostgreSQL

  |
  | User-authorized backup
  v
User Cloud Storage
  |-- iCloud Drive
  |-- Google Drive
  |-- OneDrive
  |-- Dropbox

  |
  | Optional async jobs
  v
Worker / Queue
```

### 2.2 前期架构原则

- 移动端优先，围绕家长碎片时间内的快速记录设计。
- 媒体原文件与业务索引分离，照片原文件默认保留在系统相册或用户授权云端，结构化索引存数据库。
- 默认私密，儿童照片原文件默认不进入 Baby Time 后端。
- MVP 先采用单体后端模块化架构，避免过早拆分微服务。
- 云端备份、manifest 生成、音频处理等耗时任务采用客户端队列或异步任务架构。
- 数据模型以照片、照片集、音频、时间线节点为核心，tag 与分类使用统一绑定模型支持扩展。

## 3. 技术选型

### 3.0 MVP 低成本默认方案

前期版本以“低固定成本、可上线、可扩展”为优先级。除非用户规模或性能指标已经证明需要升级，否则默认采用以下方案：

- 客户端使用 Expo + React Native + TypeScript，减少原生工程维护和打包成本。
- 后端使用 NestJS 模块化单体，部署为一个 API 服务，避免拆分多个微服务。
- 数据库使用托管 PostgreSQL 的低配实例或免费/低价套餐，优先保证自动备份和迁移能力。
- 照片原文件优先使用本机索引和用户授权云端备份，不默认接入 Baby Time 自有对象存储。
- MVP 不单独部署 Redis，云端备份任务、异步处理状态先存本地队列和 PostgreSQL。
- MVP 不启用 BullMQ 常驻队列，先使用客户端可恢复队列或 API 服务内的轻量后台任务处理 manifest、失败任务和状态同步。
- MVP 不接独立搜索服务，先使用 PostgreSQL 普通索引、`ILIKE` 或全文索引。
- MVP 不接 CDN；只有未来启用 Baby Time 托管存储时，才需要短期签名 URL 和 CDN 策略。
- MVP 不做服务端强制音频转码，先保存客户端可播放格式和 mime type；后续再补异步转码。
- MVP 默认不保存照片原文件到 Baby Time 后端；缩略图是否缓存需与用户选择的保存方式保持一致。

升级触发条件：

- 云端备份任务明显堆积、manifest 合并或音频处理影响 API 响应时，增加 Redis + BullMQ + 独立 Worker。
- 搜索响应慢或搜索体验不足时，引入 Meilisearch、Typesense 或 Elasticsearch。
- 未来启用 Baby Time 托管存储且媒体访问流量成本明显上升或跨地域访问慢时，引入 CDN。
- 音频格式兼容问题增多时，启用异步转码。
- 数据库 CPU、连接数或存储逼近套餐上限时，升级数据库实例或引入读写优化。

### 3.1 客户端

推荐技术栈：

- React Native：跨平台开发 iOS 和 Android。
- TypeScript：提升类型安全和长期维护性。
- React Navigation：页面导航和底部 Tab。
- TanStack Query：服务端状态、缓存、请求重试和分页加载。
- Zustand：本地轻量状态管理，例如当前孩子、媒体保存方式和云端备份队列 UI 状态。
- Expo：MVP 默认使用 Expo managed workflow。若后续录音、后台上传、原生 SDK 或 App Store 能力无法满足，再切换到 prebuild/bare workflow。

关键原生能力：

- 图片选择：优先系统照片选择器。
- 相册资产引用：保存和读取系统相册资产标识，并处理删除、撤权和有限照片访问变化。
- 云端授权：支持至少一种主流云端存储 OAuth 或系统文件目录授权。
- 拍照：仅用户主动拍摄时申请相机权限。
- 录音：仅用户主动录音时申请麦克风权限。
- 音频播放：支持进度、暂停、继续和多音频列表。
- 本地缓存：缓存索引、云端备份任务状态、最近浏览数据；照片缩略图缓存需符合用户选择的保存方式。

### 3.2 服务端

推荐技术栈：

- Node.js + NestJS：适合 TypeScript 全栈一致性，模块化清晰。
- PostgreSQL：存储用户、孩子、时间线、媒体索引、云端定位信息、绑定关系。
- Prisma：数据库 schema 管理、迁移和类型安全访问。
- Redis：MVP 暂不强依赖，用户规模上升后用于缓存、队列和限流。
- BullMQ：MVP 暂不强依赖，后续用于缩略图生成、音频转码、重复检测等异步任务。
- OpenAPI：定义移动端与后端接口契约。

MVP 阶段采用模块化单体服务，按领域划分模块，不拆独立服务。后续当媒体处理、搜索或家庭协作复杂度上升时，再拆分 Worker、Search Service 或 Notification Service。

### 3.3 存储

推荐方案：

- 关系型数据库：PostgreSQL。
- 本机照片：使用系统相册资产标识重新读取原照片。
- 用户云端备份：iCloud Drive、Google Drive、OneDrive、Dropbox 等用户授权目录。
- Baby Time 托管存储：S3 兼容存储、阿里云 OSS、腾讯云 COS 或 Cloudflare R2，仅作为后续可选模式。
- CDN：仅在启用 Baby Time 托管存储且访问量上升后接入。
- 本地缓存：移动端缓存索引和最近数据，避免重复加载；缩略图缓存遵循用户隐私选择。

用户云端备份建议路径：

```text
BabyTime/{child_id}/{yyyy}/{MM}/{photo_id}_{taken_at_yyyyMMdd_HHmmss}.{ext}
BabyTime/{child_id}/manifest.json
```

云端文件名不应直接包含孩子姓名、生日、地点、备注或 tag。OAuth token、云端授权凭据和安全书签应保存在设备安全存储中，不上传到 Baby Time 后端。

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
- 首次隐私说明页。
- 媒体保存方式选择页。
- 云端存储授权页。
- 时间线首页。
- 时间节点详情页。
- 照片导入页。
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
    backup/
  services/
    api/
    storage/
    permissions/
    media/
    cloud-providers/
  stores/
  types/
  utils/
```

分层说明：

- `screens`：页面容器，负责组合功能模块。
- `features`：按业务领域封装 hooks、组件和交互逻辑。
- `services/api`：后端 API 客户端和请求封装。
- `services/media`：系统相册资产读取、录音、播放、文件选择等能力封装。
- `services/cloud-providers`：云端存储授权、上传、文件校验和错误映射。
- `stores`：当前孩子、媒体保存方式、云端备份任务状态等跨页面状态。
- `types`：由 OpenAPI 或共享类型生成的接口类型。

### 4.3 导入与云端备份队列设计

照片导入分为本机索引和授权云端备份两条路径。本机索引不需要上传照片原文件；授权云端备份需要支持批量备份、失败重试、弱网提示和进度展示。

客户端维护云端备份任务队列：

- `pending`：待备份。
- `uploading`：上传中。
- `synced`：已备份。
- `completed`：完成。
- `failed`：失败，可重试。
- `auth_expired`：云端授权失效。
- `quota_exceeded`：云端空间不足。
- `missing`：源照片或云端文件不存在。

本机索引流程：

1. 用户通过系统照片选择器选择照片。
2. 客户端保存系统相册资产标识和基础元数据。
3. 客户端调用后端创建照片索引记录。
4. 展示照片时根据资产标识重新向系统相册请求图片。

授权云端备份流程：

1. 客户端确认用户已授权云端存储服务。
2. 客户端从系统相册读取用户选择的照片。
3. 客户端按规则命名并上传到用户授权云端目录。
4. 上传完成后，客户端把云端服务类型、文件 ID、路径和同步状态写入后端索引。
5. 后端不接收照片原文件，只保存索引和云端定位信息。

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

- 媒体索引管理。
- 媒体保存方式管理。
- 系统相册资产引用状态管理。
- 用户云端备份状态管理。
- 云端服务类型、文件 ID 和路径记录。
- 原照片缺失、权限撤销、云端授权过期和云端文件缺失状态管理。
- 重复照片检测。

MVP 建议：

- 优先实现本机索引模式。
- 授权云端备份模式至少接入一种主流云端存储服务。
- Baby Time 后端不保存照片原文件。
- 重复检测先基于系统相册资产标识、拍摄时间和文件元数据做弱提醒，不阻断导入。

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

- 录音文件保存与备份。
- 本地音频文件导入。
- 音频元数据管理。
- 音频绑定照片或照片集。
- 播放地址鉴权。
- 删除音频和解绑。

MVP 建议统一处理为 AAC 或 MP3，降低跨端播放和长期保存风险。音频文件的保存策略应与用户选择的媒体保存方式保持一致；如首版暂未覆盖音频云端备份，需要在产品文案中明确说明。转码可异步处理，前期若客户端录音格式稳定，可先保存源文件并记录 mime type。

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
- `cloud_provider_accounts`
- `media_backup_tasks`
- `tags`
- `tag_bindings`
- `categories`
- `category_bindings`

### 6.2 关键字段建议

`photos`：

- `id`
- `user_id`
- `child_id`
- `timeline_node_id`
- `storage_mode`
- `local_asset_identifier`
- `local_asset_status`
- `cloud_provider`
- `cloud_file_id`
- `cloud_path`
- `cloud_sync_status`
- `cloud_synced_at`
- `babytime_hosted_file_url`
- `babytime_hosted_thumbnail_url`
- `babytime_hosted_original_url`
- `file_hash`
- `taken_at`
- `imported_at`
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
- `storage_mode`
- `local_file_ref`
- `cloud_provider`
- `cloud_file_id`
- `cloud_path`
- `cloud_sync_status`
- `babytime_hosted_file_url`
- `babytime_hosted_processed_url`
- `duration`
- `mime_type`
- `audio_type`
- `title`
- `note`
- `created_at`
- `updated_at`
- `deleted_at`

绑定表均建议冗余 `user_id`，便于权限过滤和查询优化。

`cloud_provider_accounts`：

- `id`
- `user_id`
- `provider`
- `display_name`
- `authorization_status`
- `token_storage_ref`
- `app_folder_id`
- `root_path`
- `last_verified_at`
- `created_at`
- `updated_at`

`media_backup_tasks`：

- `id`
- `photo_id`
- `child_id`
- `provider_account_id`
- `source_type`
- `source_ref`
- `target_path`
- `status`
- `progress`
- `retry_count`
- `error_code`
- `created_at`
- `updated_at`

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
- 删除 Baby Time 照片记录默认只删除索引和绑定关系，不删除系统相册原图，也不删除用户云盘文件。
- 如果用户选择同时删除云端备份文件，需要单独勾选并二次确认；失败时记录补偿任务。
- Baby Time 托管模式下，对象存储文件删除需要与数据库状态一致，失败时记录补偿任务。
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

- `POST /photos/import`
- `PATCH /photos/{photoId}/local-asset-status`
- `PATCH /photos/{photoId}/cloud-backup`
- `GET /children/{childId}/photos`
- `GET /photos/{photoId}`
- `PATCH /photos/{photoId}`
- `DELETE /photos/{photoId}`

云端备份：

- `GET /cloud-providers`
- `POST /cloud-provider-accounts`
- `PATCH /cloud-provider-accounts/{accountId}`
- `DELETE /cloud-provider-accounts/{accountId}`
- `POST /media-backup-tasks`
- `PATCH /media-backup-tasks/{taskId}`
- `GET /children/{childId}/media-backup-tasks`

照片集：

- `POST /collections`
- `GET /children/{childId}/collections`
- `GET /collections/{collectionId}`
- `PATCH /collections/{collectionId}`
- `POST /collections/{collectionId}/items`
- `PATCH /collections/{collectionId}/items/order`
- `DELETE /collections/{collectionId}`

音频：

- `POST /audios`
- `PATCH /audios/{audioId}/backup`
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

### 8.1 照片导入并创建照片集

1. 用户在 App 选择多张照片。
2. 客户端读取拍摄时间、文件大小、mime type 等基础信息。
3. 如果当前宝宝使用本机索引模式，客户端保存系统相册资产标识并调用后端创建照片索引。
4. 如果当前宝宝使用授权云端备份模式，客户端先保存本机引用并创建云端备份任务。
5. 客户端将照片上传到用户授权的云端目录，完成后更新云端文件 ID、路径和同步状态。
6. 系统根据拍摄时间与孩子生日推荐时间线节点。
7. 用户确认或调整时间节点。
8. 用户创建照片集、选择模板、设置标题、tag 和分类。
9. 后端只保存索引、绑定关系和云端定位信息，不接收照片原文件。

### 8.2 给照片集绑定录音

1. 用户进入照片集详情页并点击录音。
2. 客户端申请麦克风权限。
3. 用户录音、暂停、继续、试听或重录。
4. 保存时根据媒体保存方式创建本地保存或云端备份任务。
5. 后端保存音频索引和绑定关系，必要时异步转码。
7. 后端创建 `audio_binding`，绑定目标为 `photo_collection`。
8. 照片集详情页刷新音频列表并支持播放。

### 8.3 时间线浏览

1. App 加载当前孩子信息。
2. 请求时间线摘要接口。
3. 后端返回节点标题、封面、照片数量、照片集数量、音频数量、最近更新和常用 tag。
4. 用户点击时间节点后分页加载照片、照片集和音频。
5. 本机索引照片从系统相册读取；云端备份照片从用户授权云端读取；缺失或授权失效时展示明确占位和恢复入口。

## 9. 安全与隐私设计

### 9.1 鉴权与授权

- 所有接口默认需要登录。
- 所有资源查询必须附带 `user_id` 归属校验。
- Baby Time 后端默认不提供儿童照片原文件下载。
- 用户云端备份通过用户授权的云端服务读取，不把第三方云端 token 上传到 Baby Time 后端。
- 未来 Baby Time 托管模式下，文件下载不暴露永久公开 URL，并使用短期签名 URL。
- 管理端或运维操作需记录审计日志。

### 9.2 数据隐私

- 默认不公开任何内容。
- 首版不提供公开社区和公开分享。
- 前置展示隐私说明，明确 Baby Time 可以不托管儿童照片原文件。
- 本机索引模式只保存系统相册资产引用和整理信息。
- 用户云端备份模式只保存云端服务类型、文件 ID、路径和同步状态。
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
- 列表优先请求适合当前尺寸的图片，详情页按需请求高清图。
- 音频点击后尽快开始播放。
- 时间线摘要接口避免返回大体积媒体详情。

### 10.2 稳定性策略

- 云端备份任务可重试。
- App 重启后恢复未完成云端备份任务。
- 弱网状态显示明确提示。
- 删除操作二次确认。
- 异步任务失败记录状态并支持后台重试。
- 数据库关键写操作使用事务。

### 10.3 可观测性

前期至少接入：

- 后端接口访问日志。
- 错误日志和 request id。
- 照片导入成功率。
- 云端备份成功率、失败率和耗时。
- 相册权限失效、原照片缺失、云端授权过期和云端文件缺失事件。
- 客户端崩溃日志。

### 10.4 自动化测试与上线准入

所有版本功能必须配套自动化测试。功能未通过测试不得上线。

测试分层：

- 单元测试：覆盖服务函数、权限判断、时间线计算、绑定逻辑、备份状态机、表单校验等核心逻辑。
- API 集成测试：覆盖鉴权、资源归属校验、CRUD、照片导入、云端备份状态更新、绑定/解绑、搜索等接口。
- 客户端组件测试：覆盖关键表单、列表状态、云端备份队列状态、录音状态和错误提示。
- 端到端测试：覆盖注册登录、创建孩子、选择保存方式、导入照片、创建照片集、录音绑定、播放入口、搜索等核心路径。
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
- 首次隐私说明。
- 媒体保存方式选择。
- 本机索引模式。
- 授权云端备份模式接入至少一种主流云端存储服务。
- 照片单张、多张导入。
- 时间线自动归档。
- 时间线首页和节点详情。
- 创建照片集。
- 照片集排序、封面、基础模板。
- tag 创建、绑定、编辑、筛选。
- 录音、试听、保存。
- 音频绑定照片或照片集。
- 音频播放。
- 基础搜索。
- 照片缺失、权限失效和云端授权失效提示。

### 11.2 V1.0 可降级实现

- 分类体系可先内置固定分类，再开放自定义。
- 重复照片检测可先提示，不做强阻断。
- 音频转码可先延后，只记录源文件格式并保证客户端可播放。
- 多云盘服务可先只接一种，后续扩展 Provider。
- 用户云盘 manifest 可先预留结构，后续完善换机恢复。
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

### 阶段二：照片导入、云端备份与时间线

- 完成本机索引照片导入。
- 完成至少一种云端存储授权和备份任务。
- 完成照片缺失、权限失效和云端授权失效状态处理。
- 完成时间线节点计算和时间线摘要。
- 完成照片列表、照片详情和时间节点详情。

### 阶段三：照片集、tag、分类

- 完成照片集 CRUD。
- 完成照片排序、封面和基础模板数据保存。
- 完成 tag/category 创建、绑定、解绑和筛选。

### 阶段四：录音与音频绑定

- 完成客户端录音、试听、重录和保存。
- 完成音频元数据、绑定关系和播放入口。
- 完成照片详情、照片集详情中的音频播放列表。

### 阶段五：搜索、稳定性与上线准备

- 完成基础搜索。
- 完成云端备份失败重试和任务恢复。
- 完成删除确认、软删除和数据补偿任务。
- 完成日志、错误监控、基础隐私设置和上线检查。

## 13. 主要技术风险与应对

### 13.1 媒体保存与备份成本

风险：照片和音频会长期增长。如果默认使用 Baby Time 自有对象存储，会带来明显存储和流量成本；如果使用用户云端备份，则会受到第三方云端空间、授权、接口限流和地区可用性影响。

应对：

- 首版优先使用本机索引和用户云端备份，降低 Baby Time 自有存储压力。
- Baby Time 托管存储作为后续可选能力，不作为默认方案。
- 预留用户容量统计字段。
- 对云端备份失败、空间不足和授权过期建立明确状态。

### 13.2 云端备份链路复杂

风险：移动端弱网、后台切换、批量备份、第三方云端授权过期或限流会导致失败率上升。

应对：

- 客户端维护可恢复云端备份队列。
- 后端记录备份任务状态和错误码。
- 上传完成前照片仍可通过本机索引展示。
- 对授权过期、空间不足、文件缺失和服务限流做统一错误映射。

### 13.3 儿童隐私信任

风险：用户对儿童照片和声音非常敏感，任何越权访问都会造成严重信任损失。

应对：

- 前置展示隐私说明。
- 默认提供本机索引模式。
- 用户云端备份使用最小权限目录或 App Folder。
- 所有资源按 user_id 做权限校验。
- 不把第三方云端访问 token 上传到 Baby Time 后端。
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
- 首批云端备份服务：建议先选择 iCloud Drive 或 Google Drive 中的一种。
- 免费用户是否提供 Baby Time 托管存储：建议先不作为 MVP 默认能力。
- 用户云盘 manifest 是否进入 MVP：建议预留结构，若做换机恢复则进入 V1.1。
- 音频是否统一转码：建议预留转码任务，MVP 可先保存源文件。
- 是否支持离线查看：建议先支持最近内容缓存，不做完整离线模式。
- 是否支持数据导出：架构预留，产品入口可放后续版本。
- 是否面向海外市场：若计划海外上线，需要提前考虑手机号登录、云端服务可用性、隐私合规和多语言。
- 是否允许分享到微信或朋友圈：建议首版不做公开分享。

## 15. 结论

Baby Time 的 MVP 应以“隐私说明 + 媒体保存方式选择 + 成长时间线 + 照片/照片集 + 声音绑定 + tag 搜索”为最小核心闭环。前期架构建议采用 Expo + React Native + TypeScript 客户端、Node.js/NestJS 模块化单体后端、PostgreSQL 元数据与索引存储、本机索引模式和用户授权云端备份模式。Baby Time 后端默认不托管儿童照片原文件；Redis/BullMQ、独立搜索、CDN、音频转码和 Baby Time 托管存储等能力在用户规模或明确产品需求触发后再引入。

该方案能在首版控制复杂度，同时为多孩子、家庭协作、AI tag、音频转文字、成长册导出、会员容量等后续能力保留清晰扩展路径。
