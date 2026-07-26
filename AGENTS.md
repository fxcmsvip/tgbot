# AdminBot - 项目规范与经验

## 项目概述

AdminBot 是一个多子项目工作区，核心产品为 **ADMINCHAT Panel** —— Telegram 双向消息转发 Bot + Web 客服管理面板。工作区包含插件市场、插件 SDK 和示例插件等配套项目。

## 技术栈

- **前端**: React 19 + Vite 8 + TypeScript 5.9 + Tailwind CSS v4 + Zustand + TanStack Query + i18next
- **后端**: Python 3.12 + FastAPI + SQLAlchemy 2.0 (async) + asyncpg + aiogram 3 (Telegram Bot)
- **数据库**: PostgreSQL 16 + Redis 7
- **部署**: Docker Compose + GHCR
- **包管理**: pnpm (前端), uv (Python)

## 国际化 (i18n)

两个前端项目均已集成 i18next：
- **ADMINCHAT_PANEL**: `frontend/src/i18n/` (zh-CN, en-US)
- **ACP_Market**: `frontend/src/i18n/` (zh-CN, en-US)
- 默认语言跟随系统 (`i18next-browser-languagedetector`)
- 语言切换在 Settings 页面生效，存储于 localStorage
- 翻译键结构：`common.*`, `nav.*`, `login.*`, `dashboard.*`, `botPool.*`, `settings.*` 等

## 目录结构

```
/workspace/projects/
├── .coze                          # 根配置
├── AGENTS.md                      # 本文件
└── AdminBot/
    ├── ADMINCHAT_PANEL-main/      # 核心项目 - Telegram 客服管理面板
    │   ├── backend/               # FastAPI 后端 + Telegram Bot
    │   ├── frontend/              # React SPA 前端
    │   ├── docs/                  # 设计文档
    │   ├── deploy/                # Docker 部署配置
    │   ├── docker-compose.yml     # 本地开发编排
    │   ├── VERSION                # 公开版本号 (semver)
    │   └── BUILD_VERSION          # 内部构建号 (YYYYMMDD.NNNN)
    ├── ACP_Market-main/           # ACP 插件市场
    │   ├── backend/               # FastAPI 后端
    │   ├── frontend/              # React 前端
    │   ├── deploy/                # 部署配置
    │   └── docker-compose.yml
    ├── ACP_PLUGIN_SDK-main/       # 插件 SDK + CLI 工具
    │   ├── acp_plugin_sdk/        # SDK 核心
    │   ├── acp_cli/               # CLI 工具
    │   └── templates/             # 插件模板
    └── ACP_PLUGINS-main/          # 插件集合
        └── movie-request/         # 电影请求插件示例
            ├── backend/
            └── frontend/
```

## 关键入口 / 核心模块

### ADMINCHAT_PANEL-main (核心)
- **后端入口**: `backend/app/main.py` (FastAPI app)
- **前端入口**: `frontend/src/main.tsx` (React SPA)
- **Bot 管理**: `backend/app/bot/manager.py`
- **消息分发**: `backend/app/bot/dispatcher.py`
- **FAQ 引擎**: `backend/app/bot/handlers/`
- **API 路由**: `backend/app/api/v1/`
- **数据库模型**: `backend/app/models/`
- **数据库迁移**: `backend/alembic/`

### ACP_Market-main
- **后端入口**: `backend/app/main.py`
- **前端入口**: `frontend/src/main.tsx`
- **Stripe 计费**: `backend/app/api/billing.py`
- **签名验证**: `backend/app/utils/signing.py`

## 运行与预览

- 前端开发服务器: `pnpm dev` (Vite, 默认端口 5173)
- 后端开发服务器: `uvicorn app.main:app --reload`
- 本地全栈: `docker-compose up`
- 数据库迁移: `alembic upgrade head`

### Coze 预览链路

- **判定依据**: 项目包含 React + Vite 前端 SPA，属于 Web 预览型项目
- **预览入口**: `ADMINCHAT_PANEL-main/frontend` (核心项目前端)
- **预览脚本**:
  - Build: `AdminBot/ADMINCHAT_PANEL-main/frontend/scripts/coze-preview-build.sh`
  - Run: `AdminBot/ADMINCHAT_PANEL-main/frontend/scripts/coze-preview-run.sh`
- **端口**: 5000 (Vite dev server)
- **根 .coze 映射**: `[dev]` 段指向上述脚本
- **注意**: 预览仅启动前端 dev server，后端 API 代理 (/api, /ws) 在预览环境不可用

### Coze 部署配置

- **部署类型**: service (web)
- **部署脚本**:
  - Build: `AdminBot/ADMINCHAT_PANEL-main/frontend/scripts/build.sh` (pnpm install + vite build)
  - Run: `AdminBot/ADMINCHAT_PANEL-main/frontend/scripts/run.sh` (serve dist on port 5000)
- **运行时**: nodejs-24, python-3.12
- **注意**: 部署仅包含前端静态产物，后端需独立部署（Docker Compose）

## 设计系统 (ADMINCHAT_PANEL)

- **背景色**: #0C0C0C (页面), #080808 (侧栏), #0A0A0A (卡片), #141414 (浮层)
- **主色调**: #00D9FF (cyan)
- **状态色**: #059669 (成功), #FF8800 (警告), #FF4444 (错误), #8B5CF6 (角色)
- **文字色**: #FFFFFF (主), #8a8a8a (次), #6a6a6a (弱), #4a4a4a (占位)
- **边框**: #2f2f2f (默认), #1A1A1A (细)
- **字体**: Space Grotesk (标题), Inter (正文), JetBrains Mono (数据/代码)
- **圆角**: 6-10px (卡片/按钮), 4px (标签/徽章)

## 版本管理规则

- **公开版本**: `VERSION` 文件 (semver: MAJOR.MINOR.PATCH)
- **内部版本**: `BUILD_VERSION` 文件 (YYYYMMDD.NNNN)
- 每次代码变更需递增 BUILD_VERSION 的 4 位计数器
- 页脚显示: "Powered By ADMINCHAT PANEL v{VERSION} ({BUILD_VERSION})"
- 版权: (R) 2026 NovaHelix & SAKAKIBARA

## 用户偏好与长期约束

- 前端使用 pnpm，禁止 npm/yarn
- Python 使用 uv 管理虚拟环境
- 后端全异步 (async def, await)
- SQLAlchemy 2.0 风格 + async session
- Pydantic v2 用于 schema 验证
- API 前缀: `/api/v1`
- 许可证: GPL-3.0，双重版权 NovaHelix & SAKAKIBARA

## 安全修复记录

- **Bot Token 加密存库**: 使用 Fernet 加密存储，新增 `token_hash` 字段用于去重查询
- **Fernet 密钥日志泄露**: 自动生成密钥时不再打印到日志，仅提示配置环境变量
- **数据库迁移**: `006_encrypt_bot_tokens.py` 处理现有明文 token 加密

## 常见问题和预防

- PostgreSQL 端口冲突: ADMINCHAT_PANEL 用 5432, ACP_Market 用 5433
- Redis 端口冲突: ADMINCHAT_PANEL 用 6379, ACP_Market 用 6380
- 前端依赖 React 19，注意 peer dependency 兼容性
- Docker 开发模式使用 bind mount 实现热重载
