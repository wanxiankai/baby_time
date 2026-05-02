# Baby Time MVP 上线前账号与配置准备清单

## 1. 基础账号

### 1.1 代码与协作

需要准备：

- Git 仓库账号和项目仓库。
- 分支保护规则。
- CI/CD 平台账号，例如 GitHub Actions、GitLab CI 或同类服务。
- 缺陷和任务管理工具，例如 GitHub Issues、Linear、飞书项目或 Jira。

必须配置：

- `main` 分支禁止直接推送。
- 合并前必须通过 CI。
- 至少需要 code review 后才能合并。
- 生产环境密钥不得提交到仓库。

### 1.2 Apple 与 Android 发布账号

需要准备：

- Apple Developer Program 账号。
- Google Play Console 账号。
- App 名称、Bundle ID、Package Name。
- App 图标、启动图、隐私说明。
- 测试人员邮箱或测试分发名单。

MVP 建议：

- 先使用 TestFlight 和 Google Play Internal Testing 验证。
- 正式上架前补齐隐私政策、用户协议和数据删除说明。

## 2. 云资源账号

### 2.1 API 服务部署

需要准备一个可部署 Node.js 服务的平台：

- 低成本容器平台。
- VPS。
- PaaS 平台。

需要配置：

- 生产环境 API 域名。
- 测试环境 API 域名。
- HTTPS 证书。
- 环境变量管理。
- 部署回滚能力。
- 日志查看能力。

建议环境：

- `development`：本地开发。
- `staging`：上线前测试。
- `production`：正式环境。

### 2.2 PostgreSQL 数据库

需要准备：

- PostgreSQL 托管实例或自建实例。
- staging 数据库。
- production 数据库。
- 数据库备份策略。
- 数据库连接字符串。

必须配置：

- 自动备份。
- 数据库访问白名单或安全访问方式。
- 最小权限数据库用户。
- Prisma migration 执行权限。

建议前期低成本配置：

- 使用低配托管 PostgreSQL。
- 不单独部署只读副本。
- 不引入复杂分库分表。
- 通过索引和分页控制查询成本。

### 2.3 对象存储

需要准备：

- S3 兼容对象存储账号。
- staging 私有桶。
- production 私有桶。
- Access Key 和 Secret Key。
- Bucket region。
- Endpoint。

必须配置：

- 桶默认私有。
- 禁止公开读。
- CORS 允许移动端直传所需方法。
- 生命周期规则：清理临时上传、失败上传和过期处理文件。
- 服务端只能下发短期签名上传/下载 URL。

建议目录：

```text
users/{user_id}/children/{child_id}/photos/{photo_id}/original
users/{user_id}/children/{child_id}/photos/{photo_id}/display
users/{user_id}/children/{child_id}/photos/{photo_id}/thumbnail
users/{user_id}/children/{child_id}/audio/{audio_id}/source
```

### 2.4 域名

需要准备：

- API 域名，例如 `api.example.com`。
- 官网或隐私政策域名，例如 `www.example.com`。
- 后续可选媒体 CDN 域名。

必须配置：

- DNS 解析。
- HTTPS 证书。
- staging 和 production 域名隔离。

## 3. 第三方服务

### 3.1 邮件服务

MVP 推荐先使用邮箱注册登录，短信登录后置。

需要准备：

- 邮件发送服务账号。
- 发信域名。
- SPF、DKIM、DMARC 配置。
- 邮件模板：注册验证、找回密码、账号安全提醒。

需要提供给开发：

- SMTP 或 API Key。
- 发件人邮箱。
- 发件人名称。

### 3.2 短信服务

MVP 可暂不接入。若必须手机号登录，需要准备：

- 短信服务账号。
- 短信签名。
- 验证码模板。
- 发送频率限制策略。

成本建议：

- 前期不默认启用短信登录。
- 如需国内用户手机号登录，可作为 V1.1 增量任务。

### 3.3 错误监控

需要准备：

- 客户端错误监控项目。
- 后端错误监控项目。
- staging 和 production DSN。

建议：

- 使用 Sentry 或同类服务。
- 前期只开启错误和崩溃采集，不采集儿童照片、音频内容和敏感字段。

### 3.4 数据分析

需要准备：

- 基础事件分析工具。
- 数据采集规则。

MVP 只采集非敏感事件：

- 注册成功。
- 创建孩子档案。
- 上传照片成功/失败。
- 创建照片集。
- 录音成功/失败。
- 音频播放。
- 搜索。

禁止采集：

- 儿童照片内容。
- 音频内容。
- 孩子真实姓名等敏感信息。
- 用户备注全文。

## 4. 环境变量清单

后端环境变量：

```text
NODE_ENV=
APP_PORT=
APP_PUBLIC_API_URL=
DATABASE_URL=
JWT_ACCESS_SECRET=
JWT_REFRESH_SECRET=
JWT_ACCESS_TTL=
JWT_REFRESH_TTL=
S3_ENDPOINT=
S3_REGION=
S3_BUCKET=
S3_ACCESS_KEY_ID=
S3_SECRET_ACCESS_KEY=
S3_FORCE_PATH_STYLE=
UPLOAD_SIGNED_URL_TTL_SECONDS=
DOWNLOAD_SIGNED_URL_TTL_SECONDS=
EMAIL_PROVIDER=
EMAIL_API_KEY=
EMAIL_FROM=
SENTRY_DSN=
LOG_LEVEL=
```

客户端环境变量：

```text
EXPO_PUBLIC_API_BASE_URL=
EXPO_PUBLIC_ENV=
EXPO_PUBLIC_SENTRY_DSN=
EXPO_PUBLIC_ANALYTICS_ENABLED=
```

CI/CD 环境变量：

```text
CI_DATABASE_URL=
CI_JWT_ACCESS_SECRET=
CI_JWT_REFRESH_SECRET=
CI_S3_ENDPOINT=
CI_S3_BUCKET=
CI_S3_ACCESS_KEY_ID=
CI_S3_SECRET_ACCESS_KEY=
STAGING_DEPLOY_TOKEN=
PRODUCTION_DEPLOY_TOKEN=
```

密钥规则：

- staging 和 production 密钥必须隔离。
- 生产密钥只能放在部署平台或 CI secret。
- 本地 `.env` 不提交仓库。
- 密钥泄露后必须立即轮换。

## 5. 数据库初始化配置

需要准备：

- Prisma schema。
- 初始 migration。
- 内置分类 seed。
- 测试用户 seed，仅 staging 使用。

内置分类：

- 日常。
- 纪念日。
- 第一次。
- 声音记录。
- 家庭合影。
- 成长变化。
- 节日。
- 外出。
- 健康。
- 睡眠。

必须配置：

- `created_at`、`updated_at`。
- 软删除字段 `deleted_at`。
- user_id、child_id 相关索引。
- 常用查询索引：timeline、tag binding、category binding、audio binding。

## 6. 自动化测试配置

需要准备：

- CI 测试数据库。
- CI 对象存储测试桶或 S3 mock。
- E2E 测试账号。
- E2E 测试环境 API。
- 测试数据清理脚本。

CI 必跑命令：

```text
typecheck
lint
backend unit test
backend integration test
frontend unit/component test
database migration test
e2e smoke test
```

上线前必须确认：

- 所有测试通过。
- 覆盖率未下降到阈值以下。
- 没有跳过关键测试。
- E2E 测试环境和生产环境配置隔离。

## 7. 隐私与合规材料

需要准备：

- 用户协议。
- 隐私政策。
- 儿童信息保护说明。
- 账号注销说明。
- 个人数据删除说明。
- 数据导出说明，MVP 可说明暂未开放自助导出但保留用户申请渠道。

隐私政策必须说明：

- 收集哪些数据。
- 为什么收集。
- 照片、音频、孩子资料如何存储。
- 是否共享给第三方。
- 如何删除账号和数据。
- 不将儿童照片和音频用于广告训练或公开推荐。

## 8. 低成本上线建议

前期建议：

- 使用邮箱注册登录，暂不接短信。
- 使用单体 API 服务，暂不拆 Worker。
- 使用 PostgreSQL 承担任务状态和基础搜索。
- 使用对象存储短期签名 URL，暂不接 CDN。
- 使用托管数据库自动备份，减少运维成本。
- 日志设置保留周期，避免日志成本持续增长。
- staging 环境使用低配资源，非测试时可暂停或缩容。

暂缓开通：

- Redis。
- 独立搜索服务。
- CDN。
- 音频转码服务。
- 短信服务。
- AI 识别服务。
- 视频处理服务。

扩容时机：

- 上传处理延迟明显影响用户体验。
- 媒体访问延迟或流量成本不可接受。
- 数据库搜索响应慢。
- 用户反馈音频播放兼容问题。
- 日活、上传量或存储量超过当前资源稳定承载范围。
