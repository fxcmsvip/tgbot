# AdminBot 本地部署指南

## 快速开始

```bash
# 1. 克隆代码
git clone <repository-url>
cd AdminBot

# 2. 运行部署脚本
chmod +x deploy.sh
./deploy.sh

# 3. 访问
# ADMINCHAT Panel: http://localhost:3000
# ACP Market:      http://localhost:3001
# 账户: adminchat / adminchat
```

## 前置要求

### 系统要求
- CentOS 9 / Rocky Linux 9 / AlmaLinux 9
- Ubuntu 22.04+
- Debian 12+

### 必须安装的服务
- **PostgreSQL 16+** (端口 5432)
- **Redis 7+** (端口 6379)

### 脚本自动安装的依赖
- Python 3.12+
- Node.js 20+
- pnpm
- uv (Python 包管理器)

## 部署选项

```bash
# 部署所有项目
./deploy.sh

# 仅部署 ADMINCHAT_PANEL
./deploy.sh --admin-only

# 仅部署 ACP_Market
./deploy.sh --acp-only

# 跳过依赖安装（已安装过）
./deploy.sh --skip-deps
```

## 端口说明

| 服务 | 端口 | 说明 |
|------|------|------|
| ADMINCHAT 前端 | 3000 | Vite 开发服务器 |
| ADMINCHAT 后端 | 8000 | FastAPI 服务 |
| ACP 前端 | 3001 | Vite 开发服务器 |
| ACP 后端 | 8001 | FastAPI 服务 |
| PostgreSQL | 5432 | 数据库（共用） |
| Redis | 6379 | 缓存（共用） |

## 统一账户配置

所有服务的账户密码统一为：

| 项目 | 用户名/邮箱 | 密码 |
|------|-------------|------|
| ADMINCHAT Panel | adminchat | adminchat |
| ACP Market | adminchat@adminchat.local | adminchat |
| PostgreSQL | adminchat | adminchat |

## 手动部署步骤

如果脚本有问题，可以手动部署：

### 1. 安装系统依赖

```bash
# CentOS 9
sudo dnf install -y python3 python3-pip nodejs npm postgresql redis
sudo systemctl start postgresql redis
sudo systemctl enable postgresql redis

# Ubuntu
sudo apt update
sudo apt install -y python3 python3-pip nodejs npm postgresql redis-server
sudo systemctl start postgresql redis-server
sudo systemctl enable postgresql redis-server
```

### 2. 安装 Python 工具

```bash
# 安装 pnpm
sudo npm install -g pnpm

# 安装 uv
curl -Ls https://astral.sh/uv/install.sh | sh
source ~/.bashrc
```

### 3. 创建数据库用户

```bash
# 切换到 postgres 用户
sudo -i -u postgres

# 创建用户和数据库
psql -c "CREATE USER adminchat WITH PASSWORD 'adminchat' SUPERUSER;"
psql -c "CREATE DATABASE adminchat_panel OWNER adminchat;"
psql -c "CREATE DATABASE acp_market OWNER adminchat;"

# 退出
exit
```

### 4. 部署 ADMINCHAT_PANEL

```bash
cd AdminBot/ADMINCHAT_PANEL-main

# 后端
cd backend
cp .env.example .env
# 编辑 .env 文件，配置数据库连接
uv sync
uv run alembic upgrade head
nohup uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 > ../logs/backend.log 2>&1 &

# 前端
cd ../frontend
cp .env.example .env
pnpm install
nohup pnpm exec vite --host 0.0.0.0 --port 3000 > ../logs/frontend.log 2>&1 &
```

### 5. 部署 ACP_Market

```bash
cd AdminBot/ACP_Market-main

# 后端
cd backend
cp .env.example .env
uv sync
uv run alembic upgrade head
nohup uv run uvicorn app.main:app --host 0.0.0.0 --port 8001 > ../logs/backend.log 2>&1 &

# 前端
cd ../frontend
cp .env.example .env
pnpm install
nohup pnpm exec vite --host 0.0.0.0 --port 3001 > ../logs/frontend.log 2>&1 &
```

## 服务管理

### 启动服务

```bash
# ADMINCHAT 后端
cd AdminBot/ADMINCHAT_PANEL-main/backend
nohup uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 > ../logs/backend.log 2>&1 &

# ADMINCHAT 前端
cd AdminBot/ADMINCHAT_PANEL-main/frontend
nohup pnpm exec vite --host 0.0.0.0 --port 3000 > ../logs/frontend.log 2>&1 &

# ACP 后端
cd AdminBot/ACP_Market-main/backend
nohup uv run uvicorn app.main:app --host 0.0.0.0 --port 8001 > ../logs/backend.log 2>&1 &

# ACP 前端
cd AdminBot/ACP_Market-main/frontend
nohup pnpm exec vite --host 0.0.0.0 --port 3001 > ../logs/frontend.log 2>&1 &
```

### 停止服务

```bash
# 停止所有 Python 服务
pkill -f 'uvicorn app.main:app'

# 停止所有 Vite 服务
pkill -f 'vite'
```

### 查看日志

```bash
# ADMINCHAT 后端日志
tail -f AdminBot/ADMINCHAT_PANEL-main/logs/backend.log

# ADMINCHAT 前端日志
tail -f AdminBot/ADMINCHAT_PANEL-main/logs/frontend.log
```

## 常见问题

### 1. 数据库连接失败

检查 PostgreSQL 是否运行：
```bash
sudo systemctl status postgresql
```

检查端口是否被占用：
```bash
ss -tlnp | grep 5432
```

### 2. Redis 连接失败

检查 Redis 是否运行：
```bash
sudo systemctl status redis
```

### 3. 端口被占用

```bash
# 查看端口占用
ss -tlnp | grep :3000
ss -tlnp | grep :8000

# 杀死占用进程
kill -9 <PID>
```

### 4. 登录失败

检查后端日志：
```bash
tail -f AdminBot/ADMINCHAT_PANEL-main/logs/backend.log
```

重置管理员密码：
```bash
# 编辑 .env 文件，确认 INIT_ADMIN_USERNAME 和 INIT_ADMIN_PASSWORD
# 重启后端服务
pkill -f 'uvicorn app.main:app'
# 重新启动
```

## 生产部署

生产环境建议使用：
- Nginx 反向代理
- Supervisor 或 systemd 管理服务
- 配置 HTTPS
- 修改默认密码

```nginx
# Nginx 配置示例
server {
    listen 80;
    server_name panel.yourdomain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /api {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /ws {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```
