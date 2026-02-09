#!/bin/bash

# Xray 管理工具 - 一键安装脚本
# 支持从 GitHub 仓库下载
# Version: 2.0.0

set -e

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[信息]${NC} $1"; }
print_success() { echo -e "${GREEN}[成功]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[警告]${NC} $1"; }
print_error() { echo -e "${RED}[错误]${NC} $1"; }

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════╗
║   Xray 管理工具 - 一键安装脚本        ║
║   Version: 2.0.0                      ║
╚═══════════════════════════════════════╝
EOF
echo -e "${NC}"

# GitHub 仓库配置
GITHUB_USER="${GITHUB_USER:-Deepseaon}"  # 替换为你的 GitHub 用户名
GITHUB_REPO="${GITHUB_REPO:-xray-proxy-manmger}"   # 替换为你的仓库名
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
GITHUB_RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/manager"

# 安装目录
INSTALL_DIR="/opt/xray-manager"
BIN_LINK="/usr/local/bin/xray-manager"

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    print_error "此脚本需要 root 权限运行"
    print_info "请使用: sudo $0"
    exit 1
fi

print_info "安装目录: $INSTALL_DIR"
print_info "命令链接: $BIN_LINK"
echo ""

# 必需文件列表
REQUIRED_FILES=(
    "xray-proxy-manager.sh"
    "xray-config-generator.sh"
    "xray-node-manager.sh"
    "xray-routing-mode.sh"
    "tproxy-bypass.conf"
)

# 检查是否在本地目录（开发模式）
LOCAL_MODE=false
if [[ -f "xray-proxy-manager.sh" ]]; then
    print_info "检测到本地文件，使用本地安装模式"
    LOCAL_MODE=true
fi

# 创建临时目录
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

if [[ "$LOCAL_MODE" == "true" ]]; then
    # 本地安装模式
    print_info "从本地目录复制文件..."

    for file in "${REQUIRED_FILES[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "缺少文件: $file"
            exit 1
        fi
        cp "$file" "$TEMP_DIR/"
        echo "  ✓ $file"
    done
else
    # 从 GitHub 下载
    print_info "从 GitHub 仓库下载文件..."
    print_info "仓库: ${GITHUB_USER}/${GITHUB_REPO}"
    echo ""

    # 检查 curl 或 wget
    if command -v curl &> /dev/null; then
        DOWNLOAD_CMD="curl -fsSL"
    elif command -v wget &> /dev/null; then
        DOWNLOAD_CMD="wget -qO-"
    else
        print_error "需要 curl 或 wget 来下载文件"
        print_info "请安装: sudo apt install curl"
        exit 1
    fi

    # 下载文件
    for file in "${REQUIRED_FILES[@]}"; do
        print_info "下载: $file"
        if ! $DOWNLOAD_CMD "${GITHUB_RAW_URL}/${file}" > "$TEMP_DIR/$file"; then
            print_error "下载失败: $file"
            print_info "请检查网络连接或仓库地址"
            exit 1
        fi
        echo "  ✓ 下载完成"
    done
fi

print_success "文件准备完成"
echo ""

# 创建安装目录
print_info "创建安装目录..."
mkdir -p "$INSTALL_DIR"
print_success "目录创建完成"

# 复制文件
print_info "安装文件..."
for file in "${REQUIRED_FILES[@]}"; do
    cp "$TEMP_DIR/$file" "$INSTALL_DIR/"
    echo "  ✓ 已安装: $file"
done
print_success "文件安装完成"

# 添加执行权限
print_info "设置执行权限..."
chmod +x "$INSTALL_DIR"/*.sh
print_success "权限设置完成"

# 创建符号链接
print_info "创建命令链接..."
if [[ -L "$BIN_LINK" ]] || [[ -f "$BIN_LINK" ]]; then
    print_warning "链接已存在，正在更新..."
    rm -f "$BIN_LINK"
fi
ln -s "$INSTALL_DIR/xray-proxy-manager.sh" "$BIN_LINK"
print_success "命令链接创建完成"

# 创建配置目录
print_info "创建配置目录..."
mkdir -p /usr/local/etc/xray/nodes
print_success "配置目录创建完成"

# 检查依赖
echo ""
print_info "检查系统依赖..."

check_command() {
    if command -v "$1" &> /dev/null; then
        echo "  ✓ $1 已安装"
        return 0
    else
        echo "  ✗ $1 未安装"
        return 1
    fi
}

MISSING_DEPS=()

check_command "jq" || MISSING_DEPS+=("jq")
check_command "curl" || MISSING_DEPS+=("curl")
check_command "unzip" || MISSING_DEPS+=("unzip")

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo ""
    print_warning "缺少以下依赖: ${MISSING_DEPS[*]}"
    print_info "请手动安装:"
    echo ""
    echo "  Debian/Ubuntu:"
    echo "    sudo apt update"
    echo "    sudo apt install ${MISSING_DEPS[*]}"
    echo ""
    echo "  CentOS/RHEL:"
    echo "    sudo yum install ${MISSING_DEPS[*]}"
    echo ""
else
    print_success "所有依赖已安装"
fi

# 安装完成
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          安装完成！                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""

print_info "使用方法:"
echo ""
echo "  # 查看帮助"
echo "  xray-manager help"
echo ""
echo "  # 添加节点"
echo "  xray-manager node-add \"vless://...\" \"节点名\""
echo ""
echo "  # 启动服务"
echo "  sudo xray-manager start"
echo ""
echo "  # 测试连接"
echo "  xray-manager test"
echo ""
echo "  # 查看状态"
echo "  xray-manager status"
echo ""

print_info "完整文档:"
echo "  https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
echo ""

print_success "祝使用愉快！"
