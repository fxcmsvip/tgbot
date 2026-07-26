#!/bin/bash
# AdminBot 本地部署脚本
# 支持: CentOS 9 / Rocky Linux 9 / AlmaLinux 9 / Ubuntu 22.04+ / Debian 12+
# 
# 功能:
#   - 检测并安装依赖 (Python, Node.js, pnpm, uv)
#   - 检测 PostgreSQL 和 Redis 连接
#   - 启动后端和前端服务
#   - 支持只启动前端 (--frontend-only)
#
# 注意:
#   - 不会覆盖已有的 .env 文件
#   - 不会修改已有的数据库配置
#   - 如果后端已在运行，会提示并跳过

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 工作目录
WORKSPACE="/workspace/projects"
ADMIN_DIR="$WORKSPACE/AdminBot/ADMINCHAT_PANEL-main"
ACP_DIR="$WORKSPACE/AdminBot/ACP_Market-main"

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_fatal() { echo -e "${RED}[FATAL]${NC} $1"; exit 1; }

# 检查命令是否存在
check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    if ss -tlnp | grep -q ":$port "; then
        return 0  # 端口被占用
    else
        return 1  # 端口空闲
    fi
}

# 检查服务是否在运行
check_service() {
    local name=$1
    local port=$2
    
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port/health" 2>/dev/null | grep -q "200"; then
        return 0  # 服务在运行
    else
        return 1  # 服务未运行
    fi
}

# 检查数据库连接
check_database() {
    local host=$1
    local port=$2
    local user=$3
    local password=$4
    local dbname=$5
    
    if check_command psql; then
        if PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$dbname" -c "SELECT 1" &>/dev/null; then
            return 0
        fi
    elif check_command nc; then
        if nc -z "$host" "$port" &>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# 检查 Redis 连接
check_redis() {
    local host=$1
    local port=$2
    
    if check_command redis-cli; then
        if redis-cli -h "$host" -p "$port" ping &>/dev/null; then
            return 0
        fi
    elif check_command nc; then
        if nc -z "$host" "$port" &>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --admin-only      仅部署 ADMINCHAT_PANEL"
    echo "  --acp-only        仅部署 ACP_Market"
    echo "  --frontend-only   仅启动前端（后端已在运行时使用）"
    echo "  --skip-deps       跳过依赖安装"
    echo "  --help            显示帮助"
    echo ""
    echo "注意:"
    echo "  - 脚本不会覆盖已有的 .env 文件"
    echo "  - 如果 .env 不存在，会创建默认配置"
    echo "  - 请确保 PostgreSQL 和 Redis 已启动"
}

# 解析参数
DEPLOY_ADMIN=true
DEPLOY_ACP=true
FRONTEND_ONLY=false
SKIP_DEPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --admin-only)
            DEPLOY_ACP=false
            shift
            ;;
        --acp-only)
            DEPLOY_ADMIN=false
            shift
            ;;
        --frontend-only)
            FRONTEND_ONLY=true
            shift
            ;;
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

echo ""
echo "========================================"
echo "    AdminBot 本地部署脚本"
echo "========================================"
echo ""

# 检查 root 权限
if [ "$EUID" -eq 0 ]; then
    log_warn "以 root 用户运行，建议使用普通用户"
fi

# 检测操作系统
log_info "检测操作系统..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
    log_success "检测到: $PRETTY_NAME"
else
    log_fatal "无法检测操作系统"
fi

# 检查 PostgreSQL
log_info "检查 PostgreSQL..."
if check_database "localhost" "5432" "postgres" "" "postgres" 2>/dev/null || \
   check_database "localhost" "5432" "adminchat" "adminchat" "adminchat_panel" 2>/dev/null; then
    log_success "PostgreSQL 已运行"
    PG_RUNNING=true
else
    log_error "PostgreSQL 未运行或无法连接"
    log_info "请先启动 PostgreSQL:"
    echo "  sudo systemctl start postgresql"
    echo "  # 或"
    echo "  sudo service postgresql start"
    log_fatal "PostgreSQL 未运行，无法继续"
fi

# 检查 Redis
log_info "检查 Redis..."
if check_redis "localhost" "6379"; then
    log_success "Redis 已运行"
    REDIS_RUNNING=true
else
    log_error "Redis 未运行或无法连接"
    log_info "请先启动 Redis:"
    echo "  sudo systemctl start redis"
    echo "  # 或"
    echo "  sudo service redis-server start"
    log_fatal "Redis 未运行，无法继续"
fi

# 检查后端是否已在运行
ADMIN_BACKEND_RUNNING=false
ACP_BACKEND_RUNNING=false

if check_service "ADMINCHAT_BACKEND" "8000"; then
    log_success "ADMINCHAT 后端已在运行 (端口 8000)"
    ADMIN_BACKEND_RUNNING=true
fi

if check_service "ACP_BACKEND" "8001"; then
    log_success "ACP 后端已在运行 (端口 8001)"
    ACP_BACKEND_RUNNING=true
fi

# 如果只启动前端，检查后端是否运行
if [ "$FRONTEND_ONLY" = true ]; then
    if [ "$DEPLOY_ADMIN" = true ] && [ "$ADMIN_BACKEND_RUNNING" = false ]; then
        log_fatal "ADMINCHAT 后端未运行，无法使用 --frontend-only"
    fi
    if [ "$DEPLOY_ACP" = true ] && [ "$ACP_BACKEND_RUNNING" = false ]; then
        log_fatal "ACP 后端未运行，无法使用 --frontend-only"
    fi
fi

# 安装依赖
if [ "$SKIP_DEPS" = false ]; then
    log_info "检查依赖..."
    
    # 检查 Python
    if ! check_command python3; then
        log_info "安装 Python 3..."
        if [[ "$OS" == "centos" || "$OS" == "rocky" || "$OS" == "almalinux" ]]; then
            sudo dnf install -y python3 python3-pip
        elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            sudo apt update && sudo apt install -y python3 python3-pip
        fi
    fi
    
    # 检查 Node.js
    if ! check_command node; then
        log_info "安装 Node.js..."
        if [[ "$OS" == "centos" || "$OS" == "rocky" || "$OS" == "almalinux" ]]; then
            curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
            sudo dnf install -y nodejs
        elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt install -y nodejs
        fi
    fi
    
    # 检查 pnpm
    if ! check_command pnpm; then
        log_info "安装 pnpm..."
        sudo npm install -g pnpm
    fi
    
    # 检查 uv
    if ! check_command uv; then
        log_info "安装 uv..."
        curl -Ls https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    log_success "依赖检查完成"
fi

# 部署 ADMINCHAT_PANEL
if [ "$DEPLOY_ADMIN" = true ]; then
    echo ""
    log_info "========================================"
    log_info "部署 ADMINCHAT_PANEL"
    log_info "========================================"
    
    cd "$ADMIN_DIR"
    
    # 检查 .env 文件
    if [ -f "backend/.env" ]; then
        log_warn "backend/.env 已存在，跳过创建"
        log_info "请确认配置正确，特别是数据库连接信息"
    else
        log_info "创建 backend/.env..."
        cp backend/.env.example backend/.env
        log_warn "已创建默认 .env，请根据需要修改"
    fi
    
    # 检查前端 .env
    if [ -f "frontend/.env" ]; then
        log_warn "frontend/.env 已存在，跳过创建"
    else
        log_info "创建 frontend/.env..."
        cp frontend/.env.example frontend/.env 2>/dev/null || echo "# Frontend config" > frontend/.env
    fi
    
    # 安装后端依赖
    if [ ! -d "backend/.venv" ]; then
        log_info "安装后端依赖..."
        cd backend
        uv sync
        cd ..
    else
        log_success "后端依赖已安装"
    fi
    
    # 安装前端依赖
    if [ ! -d "frontend/node_modules" ]; then
        log_info "安装前端依赖..."
        cd frontend
        pnpm install
        cd ..
    else
        log_success "前端依赖已安装"
    fi
    
    # 启动后端
    if [ "$FRONTEND_ONLY" = false ] && [ "$ADMIN_BACKEND_RUNNING" = false ]; then
        log_info "启动 ADMINCHAT 后端..."
        mkdir -p logs
        cd backend
        nohup uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 > ../logs/backend.log 2>&1 &
        cd ..
        sleep 3
        
        if check_service "ADMINCHAT_BACKEND" "8000"; then
            log_success "ADMINCHAT 后端已启动 (端口 8000)"
        else
            log_error "ADMINCHAT 后端启动失败，请检查日志:"
            echo "  tail -f logs/backend.log"
        fi
    elif [ "$ADMIN_BACKEND_RUNNING" = true ]; then
        log_success "ADMINCHAT 后端已在运行，跳过"
    fi
    
    # 启动前端
    if check_port "3000"; then
        log_warn "端口 3000 已被占用"
        log_info "请停止占用进程或修改配置"
    else
        log_info "启动 ADMINCHAT 前端..."
        mkdir -p logs
        cd frontend
        nohup pnpm exec vite --host 0.0.0.0 --port 3000 > ../logs/frontend.log 2>&1 &
        cd ..
        sleep 3
        
        if check_port "3000"; then
            log_success "ADMINCHAT 前端已启动 (端口 3000)"
        else
            log_error "ADMINCHAT 前端启动失败，请检查日志:"
            echo "  tail -f logs/frontend.log"
        fi
    fi
fi

# 部署 ACP_Market
if [ "$DEPLOY_ACP" = true ]; then
    echo ""
    log_info "========================================"
    log_info "部署 ACP_Market"
    log_info "========================================"
    
    cd "$ACP_DIR"
    
    # 检查 .env 文件
    if [ -f "backend/.env" ]; then
        log_warn "backend/.env 已存在，跳过创建"
    else
        log_info "创建 backend/.env..."
        cp backend/.env.example backend/.env
    fi
    
    if [ -f "frontend/.env" ]; then
        log_warn "frontend/.env 已存在，跳过创建"
    else
        log_info "创建 frontend/.env..."
        cp frontend/.env.example frontend/.env 2>/dev/null || echo "# Frontend config" > frontend/.env
    fi
    
    # 安装后端依赖
    if [ ! -d "backend/.venv" ]; then
        log_info "安装后端依赖..."
        cd backend
        uv sync
        cd ..
    else
        log_success "后端依赖已安装"
    fi
    
    # 安装前端依赖
    if [ ! -d "frontend/node_modules" ]; then
        log_info "安装前端依赖..."
        cd frontend
        pnpm install
        cd ..
    else
        log_success "前端依赖已安装"
    fi
    
    # 启动后端
    if [ "$FRONTEND_ONLY" = false ] && [ "$ACP_BACKEND_RUNNING" = false ]; then
        log_info "启动 ACP 后端..."
        mkdir -p logs
        cd backend
        nohup uv run uvicorn app.main:app --host 0.0.0.0 --port 8001 > ../logs/backend.log 2>&1 &
        cd ..
        sleep 3
        
        if check_service "ACP_BACKEND" "8001"; then
            log_success "ACP 后端已启动 (端口 8001)"
        else
            log_error "ACP 后端启动失败，请检查日志:"
            echo "  tail -f logs/backend.log"
        fi
    elif [ "$ACP_BACKEND_RUNNING" = true ]; then
        log_success "ACP 后端已在运行，跳过"
    fi
    
    # 启动前端
    if check_port "3001"; then
        log_warn "端口 3001 已被占用"
    else
        log_info "启动 ACP 前端..."
        mkdir -p logs
        cd frontend
        nohup pnpm exec vite --host 0.0.0.0 --port 3001 > ../logs/frontend.log 2>&1 &
        cd ..
        sleep 3
        
        if check_port "3001"; then
            log_success "ACP 前端已启动 (端口 3001)"
        else
            log_error "ACP 前端启动失败，请检查日志:"
            echo "  tail -f logs/frontend.log"
        fi
    fi
fi

# 显示结果
echo ""
echo "========================================"
echo "    部署完成"
echo "========================================"
echo ""

if [ "$DEPLOY_ADMIN" = true ]; then
    echo "ADMINCHAT Panel:"
    echo "  前端: http://localhost:3000"
    echo "  后端: http://localhost:8000"
    echo "  日志: tail -f $ADMIN_DIR/logs/backend.log"
    echo ""
fi

if [ "$DEPLOY_ACP" = true ]; then
    echo "ACP Market:"
    echo "  前端: http://localhost:3001"
    echo "  后端: http://localhost:8001"
    echo "  日志: tail -f $ACP_DIR/logs/backend.log"
    echo ""
fi

echo "管理命令:"
echo "  停止所有服务: pkill -f 'uvicorn app.main:app'; pkill -f 'vite'"
echo "  查看后端日志: tail -f <project>/logs/backend.log"
echo "  查看前端日志: tail -f <project>/logs/frontend.log"
echo ""
