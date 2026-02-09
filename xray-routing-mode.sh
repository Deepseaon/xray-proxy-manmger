#!/bin/bash

# Xray Routing Mode Manager
# 切换路由模式：绕过大陆、全局、直连

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
XRAY_CONFIG_FILE="/usr/local/etc/xray/config.json"
XRAY_CONFIG_BACKUP="/usr/local/etc/xray/config.json.backup"
XRAY_SERVICE="xray.service"
ROUTING_MODE_FILE="/tmp/xray-routing-mode"

# Check if jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed"
        print_info "Install: sudo apt install jq  (Debian/Ubuntu)"
        print_info "        sudo yum install jq  (CentOS/RHEL)"
        exit 1
    fi
}

# Backup current config
backup_config() {
    if [[ -f "$XRAY_CONFIG_FILE" ]]; then
        cp "$XRAY_CONFIG_FILE" "$XRAY_CONFIG_BACKUP"
        print_info "Configuration backed up"
    fi
}

# Get routing rules for different modes
get_bypass_cn_rules() {
    cat <<'EOF'
[
  {
    "type": "field",
    "outboundTag": "direct",
    "ip": ["geoip:private"]
  },
  {
    "type": "field",
    "outboundTag": "direct",
    "domain": ["geosite:private"]
  },
  {
    "type": "field",
    "outboundTag": "direct",
    "ip": ["geoip:cn"]
  },
  {
    "type": "field",
    "outboundTag": "direct",
    "domain": ["geosite:cn"]
  },
  {
    "type": "field",
    "outboundTag": "proxy",
    "network": "tcp,udp"
  }
]
EOF
}

get_global_rules() {
    cat <<'EOF'
[
  {
    "type": "field",
    "outboundTag": "direct",
    "ip": ["geoip:private"]
  },
  {
    "type": "field",
    "outboundTag": "proxy",
    "network": "tcp,udp"
  }
]
EOF
}

get_direct_rules() {
    cat <<'EOF'
[
  {
    "type": "field",
    "outboundTag": "direct",
    "network": "tcp,udp"
  }
]
EOF
}

# Apply routing mode
apply_routing_mode() {
    local mode="$1"
    check_jq

    if [[ ! -f "$XRAY_CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $XRAY_CONFIG_FILE"
        exit 1
    fi

    print_info "Applying routing mode: $mode"

    # Backup current config
    backup_config

    # Get new routing rules
    local new_rules=""
    case "$mode" in
        bypass-cn|pac)
            new_rules=$(get_bypass_cn_rules)
            ;;
        global)
            new_rules=$(get_global_rules)
            ;;
        direct)
            new_rules=$(get_direct_rules)
            ;;
        *)
            print_error "Unknown mode: $mode"
            exit 1
            ;;
    esac

    # Read current config
    local config=$(cat "$XRAY_CONFIG_FILE")

    # Preserve special rules (api, dns, etc.)
    local preserved_rules=$(echo "$config" | jq -c '[.routing.rules[] | select(.inboundTag != null or .type == "field" and (.domain // [] | any(startswith("geosite:") | not)))]')

    # Merge preserved rules with new rules
    local merged_rules=$(jq -s '.[0] + .[1]' <(echo "$preserved_rules") <(echo "$new_rules"))

    # Update config
    echo "$config" | jq ".routing.rules = $merged_rules" > "$XRAY_CONFIG_FILE"

    # Save current mode
    echo "$mode" > "$ROUTING_MODE_FILE"

    print_success "Routing mode changed to: $mode"

    # Restart xray if running
    if systemctl is-active --quiet "$XRAY_SERVICE" 2>/dev/null; then
        print_info "Restarting xray service..."
        systemctl restart "$XRAY_SERVICE"
        sleep 1
        if systemctl is-active --quiet "$XRAY_SERVICE"; then
            print_success "Xray service restarted"
        else
            print_error "Failed to restart xray service"
            print_warning "Restoring backup..."
            cp "$XRAY_CONFIG_BACKUP" "$XRAY_CONFIG_FILE"
            exit 1
        fi
    else
        print_warning "Xray service is not running"
        print_info "Start it with: systemctl start $XRAY_SERVICE"
    fi
}

# Show current routing mode
show_current_mode() {
    if [[ -f "$ROUTING_MODE_FILE" ]]; then
        local mode=$(cat "$ROUTING_MODE_FILE")
        echo -e "${CYAN}Current routing mode:${NC} ${GREEN}$mode${NC}"
    else
        echo -e "${CYAN}Current routing mode:${NC} ${YELLOW}Unknown${NC}"
    fi

    echo ""
    echo "Available modes:"
    echo "  ${BLUE}bypass-cn${NC} (pac)  - 国内直连，国外走代理 (推荐)"
    echo "  ${BLUE}global${NC}           - 全局代理，所有流量走代理"
    echo "  ${BLUE}direct${NC}           - 全部直连，不使用代理"
}

# Interactive mode selection
interactive_mode() {
    echo -e "${CYAN}=== Xray Routing Mode Selector ===${NC}"
    echo ""
    show_current_mode
    echo ""
    echo "Select routing mode:"
    echo "  1) Bypass CN (绕过大陆) - 国内直连，国外走代理"
    echo "  2) Global (全局代理) - 所有流量走代理"
    echo "  3) Direct (直连) - 所有流量直连"
    echo "  4) Cancel"
    echo ""
    read -p "Enter choice [1-4]: " choice

    case $choice in
        1)
            apply_routing_mode "bypass-cn"
            ;;
        2)
            apply_routing_mode "global"
            ;;
        3)
            apply_routing_mode "direct"
            ;;
        4)
            print_info "Cancelled"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# Show usage
show_usage() {
    cat <<EOF
${CYAN}Xray Routing Mode Manager${NC}

Usage:
    $0 <mode>
    $0 status
    $0 interactive

Modes:
    bypass-cn (pac)    国内直连，国外走代理 (推荐)
    global             全局代理，所有流量走代理
    direct             全部直连，不使用代理

Commands:
    status             显示当前路由模式
    interactive        交互式选择模式

Examples:
    $0 bypass-cn       # 切换到绕过大陆模式
    $0 global          # 切换到全局代理模式
    $0 status          # 查看当前模式
    $0 interactive     # 交互式选择

Notes:
    - 需要 root 权限
    - 需要安装 jq: apt install jq
    - 会自动重启 xray 服务
    - 原配置会备份到 config.json.backup

EOF
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi

    case "$1" in
        bypass-cn|pac)
            apply_routing_mode "bypass-cn"
            ;;
        global)
            apply_routing_mode "global"
            ;;
        direct)
            apply_routing_mode "direct"
            ;;
        status)
            show_current_mode
            ;;
        interactive|i)
            interactive_mode
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
