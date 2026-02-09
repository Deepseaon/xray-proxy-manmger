#!/bin/bash

# Xray Proxy Manager - Enhanced tool for managing Xray with system/transparent proxy
# Version: 2.0.0

set -e
# Get script directory (resolve symlinks)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$SCRIPT_DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
XRAY_BIN="/usr/local/bin/xray"
XRAY_CONFIG_DIR="/usr/local/etc/xray"
XRAY_CONFIG_FILE="${XRAY_CONFIG_DIR}/config.json"
XRAY_SERVICE="xray.service"
XRAY_LOG_DIR="/var/log/xray"

# Proxy settings
PROXY_STATE_FILE="/tmp/xray-proxy-state"
SOCKS_PORT="10808"
HTTP_PORT="10809"
TPROXY_PORT="12345"
TPROXY_MARK="1"
BYPASS_CONFIG="${XRAY_CONFIG_DIR}/tproxy-bypass.conf"

# Helper functions
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This operation requires root privileges"
        exit 1
    fi
}

# Check if xray is running
is_xray_running() {
    systemctl is-active --quiet "$XRAY_SERVICE" 2>/dev/null
}

# System Proxy Management
enable_system_proxy() {
    print_info "Enabling system proxy..."

    # Create proxy script for shell sessions
    cat > /etc/profile.d/xray-proxy.sh <<EOF
# Xray Proxy Settings
export http_proxy="http://127.0.0.1:${HTTP_PORT}"
export https_proxy="http://127.0.0.1:${HTTP_PORT}"
export HTTP_PROXY="http://127.0.0.1:${HTTP_PORT}"
export HTTPS_PROXY="http://127.0.0.1:${HTTP_PORT}"
export all_proxy="socks5://127.0.0.1:${SOCKS_PORT}"
export ALL_PROXY="socks5://127.0.0.1:${SOCKS_PORT}"
export no_proxy="localhost,127.0.0.1,::1"
export NO_PROXY="localhost,127.0.0.1,::1"
EOF

    # Set for GNOME desktop (if available)
    if command -v gsettings &> /dev/null; then
        gsettings set org.gnome.system.proxy mode 'manual'
        gsettings set org.gnome.system.proxy.http host '127.0.0.1'
        gsettings set org.gnome.system.proxy.http port ${HTTP_PORT}
        gsettings set org.gnome.system.proxy.https host '127.0.0.1'
        gsettings set org.gnome.system.proxy.https port ${HTTP_PORT}
        gsettings set org.gnome.system.proxy.socks host '127.0.0.1'
        gsettings set org.gnome.system.proxy.socks port ${SOCKS_PORT}
        print_info "GNOME proxy settings updated"
    fi

    # Set for KDE desktop (if available)
    if command -v kwriteconfig5 &> /dev/null; then
        kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key ProxyType 1
        kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key httpProxy "http://127.0.0.1:${HTTP_PORT}"
        kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key httpsProxy "http://127.0.0.1:${HTTP_PORT}"
        kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key socksProxy "socks://127.0.0.1:${SOCKS_PORT}"
        print_info "KDE proxy settings updated"
    fi

    echo "enabled" > "$PROXY_STATE_FILE"
    print_success "System proxy enabled"
    print_info "HTTP/HTTPS Proxy: 127.0.0.1:${HTTP_PORT}"
    print_info "SOCKS5 Proxy: 127.0.0.1:${SOCKS_PORT}"
    print_warning "New terminal sessions will use proxy automatically"
    print_warning "Current session: run 'source /etc/profile.d/xray-proxy.sh'"
}

disable_system_proxy() {
    print_info "Disabling system proxy..."

    # Remove proxy script
    rm -f /etc/profile.d/xray-proxy.sh

    # Unset for GNOME desktop
    if command -v gsettings &> /dev/null; then
        gsettings set org.gnome.system.proxy mode 'none'
        print_info "GNOME proxy settings cleared"
    fi

    # Unset for KDE desktop
    if command -v kwriteconfig5 &> /dev/null; then
        kwriteconfig5 --file kioslaverc --group 'Proxy Settings' --key ProxyType 0
        print_info "KDE proxy settings cleared"
    fi

    rm -f "$PROXY_STATE_FILE"
    print_success "System proxy disabled"
    print_warning "Restart terminal or run: unset http_proxy https_proxy all_proxy"
}

# Transparent Proxy Management

# Load bypass configuration
load_bypass_config() {
    # Initialize arrays
    BYPASS_USERS=()
    BYPASS_UIDS=()
    BYPASS_IPS=()
    BYPASS_PORTS=()
    BYPASS_SOURCE_PORTS=()
    BYPASS_PROCESSES=()

    # Load config file if exists
    if [[ -f "$BYPASS_CONFIG" ]]; then
        source "$BYPASS_CONFIG"
        print_info "Loaded bypass configuration from $BYPASS_CONFIG"
    fi
}

# Apply bypass rules to iptables
apply_bypass_rules() {
    local rule_count=0

    # Bypass by user
    for user in "${BYPASS_USERS[@]}"; do
        if id "$user" &>/dev/null; then
            local uid=$(id -u "$user")
            iptables -t nat -A XRAY -m owner --uid-owner "$uid" -j RETURN
            print_info "Bypass rule added for user: $user (UID: $uid)"
            ((rule_count++))
        else
            print_warning "User not found: $user"
        fi
    done

    # Bypass by UID
    for uid in "${BYPASS_UIDS[@]}"; do
        iptables -t nat -A XRAY -m owner --uid-owner "$uid" -j RETURN
        print_info "Bypass rule added for UID: $uid"
        ((rule_count++))
    done

    # Bypass by destination IP
    for ip in "${BYPASS_IPS[@]}"; do
        iptables -t nat -A XRAY -d "$ip" -j RETURN
        print_info "Bypass rule added for IP: $ip"
        ((rule_count++))
    done

    # Bypass by destination port
    for port in "${BYPASS_PORTS[@]}"; do
        iptables -t nat -A XRAY -p tcp --dport "$port" -j RETURN
        iptables -t nat -A XRAY -p udp --dport "$port" -j RETURN
        print_info "Bypass rule added for port: $port"
        ((rule_count++))
    done

    # Bypass by source port
    for port in "${BYPASS_SOURCE_PORTS[@]}"; do
        iptables -t nat -A XRAY -p tcp --sport "$port" -j RETURN
        iptables -t nat -A XRAY -p udp --sport "$port" -j RETURN
        print_info "Bypass rule added for source port: $port"
        ((rule_count++))
    done

    if [[ $rule_count -gt 0 ]]; then
        print_success "Applied $rule_count bypass rule(s)"
    fi
}

enable_transparent_proxy() {
    check_root
    print_info "Enabling transparent proxy with iptables..."

    # Check if xray is running
    if ! is_xray_running; then
        print_error "Xray service is not running"
        print_info "Start it first with: xray-manager start"
        exit 1
    fi

    # Force xray to fetch ECH configuration before enabling transparent proxy
    if curl -s --socks5 127.0.0.1:${SOCKS_PORT} --max-time 10 --connect-timeout 5 https://www.google.com > /dev/null 2>&1; then
        sleep 1  # Give xray a moment to cache the ECH config
    fi

    # Load bypass configuration
    load_bypass_config

    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1 > /dev/null
    sysctl -w net.ipv6.conf.all.forwarding=1 > /dev/null

    # Create new chain
    iptables -t nat -N XRAY 2>/dev/null || iptables -t nat -F XRAY

    # Pre-resolve and bypass DNS servers for ECH compatibility
    local dns_domains=("dns.alidns.com" "dns.cloudflare.com" "dns.google" "one.one.one.one")
    local bypass_count=0
    for domain in "${dns_domains[@]}"; do
        # Resolve domain and extract IPs
        local ips=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | sort -u)
        if [[ -n "$ips" ]]; then
            while IFS= read -r ip; do
                # Add bypass rule for each resolved IP on port 443 (DoH)
                if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    # IPv4
                    iptables -t nat -A XRAY -d "$ip" -p tcp --dport 443 -j RETURN
                    iptables -t nat -A XRAY -d "$ip" -p udp --dport 443 -j RETURN
                    ((bypass_count++))
                elif [[ "$ip" =~ : ]]; then
                    # IPv6
                    if command -v ip6tables &> /dev/null; then
                        ip6tables -t nat -A XRAY -d "$ip" -p tcp --dport 443 -j RETURN 2>/dev/null || true
                        ip6tables -t nat -A XRAY -d "$ip" -p udp --dport 443 -j RETURN 2>/dev/null || true
                        ((bypass_count++))
                    fi
                fi
            done <<< "$ips"
        fi
    done
    [[ $bypass_count -gt 0 ]] && print_info "Bypassed $bypass_count DNS server IP(s) for ECH"
    done

    # Bypass xray's own traffic (by destination port to proxy server)
    local proxy_server=$(grep -oP '"address":\s*"\K[^"]+' "$XRAY_CONFIG_FILE" | head -1)
    local proxy_port=$(grep -oP '"port":\s*\K[0-9]+' "$XRAY_CONFIG_FILE" | grep -v "10808\|12345" | head -1)
    if [[ -n "$proxy_server" ]] && [[ -n "$proxy_port" ]]; then
        print_info "Bypassing proxy server: $proxy_server:$proxy_port"
        iptables -t nat -A XRAY -d "$proxy_server" -p tcp --dport "$proxy_port" -j RETURN
        iptables -t nat -A XRAY -d "$proxy_server" -p udp --dport "$proxy_port" -j RETURN
    fi

    # Bypass DNS traffic (port 53 UDP/TCP and 443 for DoH)
    iptables -t nat -A XRAY -p udp --dport 53 -j RETURN
    iptables -t nat -A XRAY -p tcp --dport 53 -j RETURN
    iptables -t nat -A XRAY -p tcp --dport 443 -d 8.8.8.8 -j RETURN
    iptables -t nat -A XRAY -p tcp --dport 443 -d 8.8.4.4 -j RETURN
    iptables -t nat -A XRAY -p tcp --dport 443 -d 1.1.1.1 -j RETURN
    iptables -t nat -A XRAY -p tcp --dport 443 -d 223.5.5.5 -j RETURN
    iptables -t nat -A XRAY -p tcp --dport 443 -d 223.6.6.6 -j RETURN

    # Apply custom bypass rules
    apply_bypass_rules

    # Bypass local and reserved addresses
    iptables -t nat -A XRAY -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A XRAY -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A XRAY -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A XRAY -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A XRAY -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A XRAY -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A XRAY -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A XRAY -d 240.0.0.0/4 -j RETURN

    # Redirect TCP traffic to dokodemo-door port (for transparent proxy)
    iptables -t nat -A XRAY -p tcp -j REDIRECT --to-ports ${TPROXY_PORT}

    # Apply to OUTPUT (for local traffic only, not PREROUTING)
    iptables -t nat -A OUTPUT -j XRAY

    # IPv6 support (optional)
    if command -v ip6tables &> /dev/null; then
        ip6tables -t nat -N XRAY 2>/dev/null || ip6tables -t nat -F XRAY
        # Note: IPv6 bypass rules don't include IPv4 addresses
        ip6tables -t nat -A XRAY -p udp --dport 53 -j RETURN
        ip6tables -t nat -A XRAY -p tcp --dport 53 -j RETURN
        ip6tables -t nat -A XRAY -p tcp -j REDIRECT --to-ports ${TPROXY_PORT}
        ip6tables -t nat -A OUTPUT -j XRAY
    fi

    echo "iptables-enabled" > "${PROXY_STATE_FILE}.tproxy"
    print_success "Transparent proxy enabled with iptables"
    print_info "Local TCP traffic will be proxied through port ${TPROXY_PORT} (dokodemo-door)"
    print_info "Bypassed: proxy server, DNS, local networks"
}

disable_transparent_proxy() {
    check_root
    print_info "Disabling transparent proxy..."

    # Remove iptables rules
    iptables -t nat -D OUTPUT -j XRAY 2>/dev/null || true
    iptables -t nat -F XRAY 2>/dev/null || true
    iptables -t nat -X XRAY 2>/dev/null || true

    # Remove IPv6 rules
    if command -v ip6tables &> /dev/null; then
        ip6tables -t nat -D OUTPUT -j XRAY 2>/dev/null || true
        ip6tables -t nat -F XRAY 2>/dev/null || true
        ip6tables -t nat -X XRAY 2>/dev/null || true
    fi

    rm -f "${PROXY_STATE_FILE}.tproxy"
    print_success "Transparent proxy disabled"
}

# Check proxy status
check_proxy_status() {
    echo -e "\n${CYAN}=== Proxy Status ===${NC}"

    # System proxy
    if [[ -f "$PROXY_STATE_FILE" ]]; then
        echo -e "System Proxy: ${GREEN}Enabled${NC}"
        echo "  HTTP/HTTPS: 127.0.0.1:${HTTP_PORT}"
        echo "  SOCKS5: 127.0.0.1:${SOCKS_PORT}"
    else
        echo -e "System Proxy: ${RED}Disabled${NC}"
    fi

    # Transparent proxy
    if [[ -f "${PROXY_STATE_FILE}.tproxy" ]]; then
        echo -e "Transparent Proxy: ${GREEN}Enabled${NC}"
        echo "  Mode: iptables REDIRECT"
        echo "  Dokodemo-door Port: ${TPROXY_PORT}"
        echo "  Active iptables rules:"
        iptables -t nat -L XRAY -n --line-numbers 2>/dev/null | head -n 15
    else
        echo -e "Transparent Proxy: ${RED}Disabled${NC}"
    fi

    # Xray service
    echo ""
    if is_xray_running; then
        echo -e "Xray Service: ${GREEN}Running${NC}"
    else
        echo -e "Xray Service: ${RED}Stopped${NC}"
    fi
}

# Start xray with proxy
start_with_proxy() {
    check_root

    # Check if node manager is available and has nodes
    local nodes_dir="/usr/local/etc/xray/nodes"
    if [[ -d "$nodes_dir" ]] && [[ -n "$(ls -A $nodes_dir/*.json 2>/dev/null)" ]]; then
        echo -e "\n${CYAN}=== Node Selection ===${NC}"
        echo "Do you want to select a node?"
        echo "  1) Use current configuration"
        echo "  2) Select from saved nodes"
        read -p "Enter choice [1-2]: " node_choice

        if [[ "$node_choice" == "2" ]]; then
            if [[ -f "$SCRIPT_DIR/xray-node-manager.sh" ]]; then
                $SCRIPT_DIR/xray-node-manager.sh select
                if [[ $? -ne 0 ]]; then
                    print_error "Node selection failed"
                    exit 1
                fi
            else
                print_warning "xray-node-manager.sh not found, using current config"
            fi
        fi
    fi

    if [[ ! -f "$XRAY_CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $XRAY_CONFIG_FILE"
        print_info "Add a node with: $SCRIPT_DIR/xray-node-manager.sh add \"vless://...\""
        exit 1
    fi

    print_info "Starting Xray service..."
    systemctl start "$XRAY_SERVICE"
    sleep 2

    if ! is_xray_running; then
        print_error "Failed to start Xray service"
        print_info "Check logs: journalctl -u $XRAY_SERVICE -n 50"
        exit 1
    fi

    print_success "Xray service started"

    # Ask user what proxy mode to enable
    echo ""
    echo "Select proxy mode:"
    echo "  1) System proxy only (recommended for desktop)"
    echo "  2) Transparent proxy only (全局透明代理)"
    echo "  3) Both system and transparent proxy"
    echo "  4) No proxy (manual configuration)"
    read -p "Enter choice [1-4]: " choice

    case $choice in
        1)
            enable_system_proxy
            ;;
        2)
            enable_transparent_proxy
            ;;
        3)
            enable_system_proxy
            enable_transparent_proxy
            ;;
        4)
            print_info "Xray started without automatic proxy configuration"
            ;;
        *)
            print_warning "Invalid choice, no proxy configured"
            ;;
    esac

    print_success "Setup complete!"
}

# Stop xray and cleanup proxy
stop_with_cleanup() {
    check_root

    print_info "Stopping Xray and cleaning up proxy settings..."

    # Disable proxies first
    if [[ -f "${PROXY_STATE_FILE}.tproxy" ]]; then
        disable_transparent_proxy
    fi

    if [[ -f "$PROXY_STATE_FILE" ]]; then
        disable_system_proxy
    fi

    # Stop xray service
    if is_xray_running; then
        systemctl stop "$XRAY_SERVICE"
        print_success "Xray service stopped"
    else
        print_info "Xray service is not running"
    fi

    print_success "Cleanup complete"
}

# Restart with current proxy settings
restart_with_proxy() {
    check_root

    local had_system_proxy=false
    local had_tproxy=false

    # Remember current state
    [[ -f "$PROXY_STATE_FILE" ]] && had_system_proxy=true
    [[ -f "${PROXY_STATE_FILE}.tproxy" ]] && had_tproxy=true

    print_info "Restarting Xray..."

    # Disable proxies
    $had_tproxy && disable_transparent_proxy
    $had_system_proxy && disable_system_proxy

    # Restart xray
    systemctl restart "$XRAY_SERVICE"
    sleep 2

    if ! is_xray_running; then
        print_error "Failed to restart Xray service"
        exit 1
    fi

    print_success "Xray service restarted"

    # Re-enable proxies
    $had_system_proxy && enable_system_proxy
    $had_tproxy && enable_transparent_proxy

    print_success "Proxy settings restored"
}

# Test proxy connection
test_proxy() {
    print_info "Testing proxy connection..."

    if ! is_xray_running; then
        print_error "Xray service is not running"
        exit 1
    fi

    echo ""
    echo "Testing SOCKS5 proxy..."
    if curl -s --socks5 127.0.0.1:${SOCKS_PORT} --max-time 10 https://www.google.com > /dev/null 2>&1; then
        print_success "SOCKS5 proxy is working"
    else
        print_error "SOCKS5 proxy test failed"
    fi

    echo ""
    echo "Testing HTTP proxy..."
    if curl -s --proxy http://127.0.0.1:${HTTP_PORT} --max-time 10 https://www.google.com > /dev/null 2>&1; then
        print_success "HTTP proxy is working"
    else
        print_error "HTTP proxy test failed"
    fi

    echo ""
    echo "Getting external IP..."
    local ip=$(curl -s --socks5 127.0.0.1:${SOCKS_PORT} --max-time 10 https://api.ipify.org 2>/dev/null)
    if [[ -n "$ip" ]]; then
        print_success "External IP: $ip"
    else
        print_warning "Could not retrieve external IP"
    fi
}

# Show usage
show_usage() {
    cat <<EOF
${CYAN}Xray Proxy Manager${NC} - Enhanced tool for managing Xray with system/transparent proxy

${YELLOW}Usage:${NC}
    $0 <command>

${YELLOW}Service Commands:${NC}
    start           Start Xray with proxy configuration (with node selection)
    stop            Stop Xray and cleanup all proxy settings
    restart         Restart Xray and restore proxy settings
    status          Show Xray and proxy status

${YELLOW}Node Management:${NC}
    node-add        Add a new node from share link
    node-list       List all saved nodes
    node-select     Select a node to use
    node-switch     Switch to a specific node
    node-delete     Delete a node
    node-current    Show current node info

${YELLOW}Proxy Management:${NC}
    proxy-on        Enable system proxy (environment variables)
    proxy-off       Disable system proxy
    tproxy-on       Enable transparent proxy (iptables)
    tproxy-off      Disable transparent proxy
    proxy-status    Show current proxy status

${YELLOW}Routing Mode:${NC}
    route-mode      Switch routing mode (bypass-cn/global/direct)
    route-status    Show current routing mode

${YELLOW}Configuration:${NC}
    config          Edit configuration file
    reload          Reload configuration without stopping

${YELLOW}Utilities:${NC}
    test            Test proxy connection
    logs            View Xray logs

${YELLOW}Examples:${NC}
    # 添加节点
    $0 node-add "vless://..." "US-Node"

    # 启动并选择节点
    $0 start

    # 切换路由模式
    $0 route-mode bypass-cn

    # 测试代理
    $0 test

${YELLOW}Routing Modes:${NC}
    bypass-cn (pac)  - 国内直连，国外走代理 (推荐)
    global           - 全局代理，所有流量走代理
    direct           - 全部直连，不使用代理

${YELLOW}Proxy Ports:${NC}
    SOCKS5/HTTP: ${SOCKS_PORT} (mixed protocol)
    TPROXY:      ${TPROXY_PORT}

${YELLOW}Configuration:${NC}
    Active Config: $XRAY_CONFIG_FILE
    Nodes Dir:     /usr/local/etc/xray/nodes
    Service:       $XRAY_SERVICE

${YELLOW}Notes:${NC}
    - System proxy: Sets environment variables and desktop settings
    - Transparent proxy: Routes all traffic through iptables (requires root)
    - Node management: Save multiple nodes and switch between them
    - Routing mode requires jq: apt install jq

EOF
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi

    case "$1" in
        start)
            start_with_proxy
            ;;
        stop)
            stop_with_cleanup
            ;;
        restart)
            restart_with_proxy
            ;;
        status)
            check_proxy_status
            ;;
        node-add)
            if [[ -f "$SCRIPT_DIR/xray-node-manager.sh" ]]; then
                shift
                $SCRIPT_DIR/xray-node-manager.sh add "$@"
            else
                print_error "xray-node-manager.sh not found"
                print_info "Expected location: $SCRIPT_DIR/xray-node-manager.sh"
                print_info "Script directory: $SCRIPT_DIR"
                exit 1
            fi
            ;;
        node-list)
            if [[ -f "$SCRIPT_DIR/xray-node-manager.sh" ]]; then
                $SCRIPT_DIR/xray-node-manager.sh list
            else
                print_error "xray-node-manager.sh not found"
                print_info "Expected location: $SCRIPT_DIR/xray-node-manager.sh"
                print_info "Script directory: $SCRIPT_DIR"
                exit 1
            fi
            ;;
        node-select)
            if [[ -f "$SCRIPT_DIR/xray-node-manager.sh" ]]; then
                $SCRIPT_DIR/xray-node-manager.sh select
            else
                print_error "xray-node-manager.sh not found"
                print_info "Expected location: $SCRIPT_DIR/xray-node-manager.sh"
                exit 1
            fi
            ;;
        node-switch)
            if [[ -f "$SCRIPT_DIR/xray-node-manager.sh" ]]; then
                if [[ -z "$2" ]]; then
                    print_error "Please provide a node name"
                    exit 1
                fi
                $SCRIPT_DIR/xray-node-manager.sh switch "$2"
            else
                print_error "xray-node-manager.sh not found"
                print_info "Expected location: $SCRIPT_DIR/xray-node-manager.sh"
                exit 1
            fi
            ;;
        node-delete)
            if [[ -f "$SCRIPT_DIR/xray-node-manager.sh" ]]; then
                if [[ -z "$2" ]]; then
                    print_error "Please provide a node name"
                    exit 1
                fi
                $SCRIPT_DIR/xray-node-manager.sh delete "$2"
            else
                print_error "xray-node-manager.sh not found"
                print_info "Expected location: $SCRIPT_DIR/xray-node-manager.sh"
                exit 1
            fi
            ;;
        node-current)
            if [[ -f "$SCRIPT_DIR/xray-node-manager.sh" ]]; then
                $SCRIPT_DIR/xray-node-manager.sh current
            else
                print_error "xray-node-manager.sh not found"
                print_info "Expected location: $SCRIPT_DIR/xray-node-manager.sh"
                exit 1
            fi
            ;;
        node-current)
            if [[ -f "$SCRIPT_DIR/xray-node-manager.sh" ]]; then
                $SCRIPT_DIR/xray-node-manager.sh current
            else
                print_error "xray-node-manager.sh not found"
                exit 1
            fi
            ;;
        proxy-on)
            check_root
            enable_system_proxy
            ;;
        proxy-off)
            check_root
            disable_system_proxy
            ;;
        tproxy-on)
            enable_transparent_proxy
            ;;
        tproxy-off)
            disable_transparent_proxy
            ;;
        proxy-status)
            check_proxy_status
            ;;
        route-mode)
            # Call routing mode script
            if [[ -f "$SCRIPT_DIR/xray-routing-mode.sh" ]]; then
                shift
                $SCRIPT_DIR/xray-routing-mode.sh "$@"
            else
                print_error "xray-routing-mode.sh not found"
                print_info "Expected location: $SCRIPT_DIR/xray-routing-mode.sh"
                print_info "Script directory: $SCRIPT_DIR"
                exit 1
            fi
            ;;
        route-status)
            if [[ -f "$SCRIPT_DIR/xray-routing-mode.sh" ]]; then
                $SCRIPT_DIR/xray-routing-mode.sh status
            else
                print_error "xray-routing-mode.sh not found"
                print_info "Expected location: $SCRIPT_DIR/xray-routing-mode.sh"
                exit 1
            fi
            ;;
        test)
            test_proxy
            ;;
        logs)
            journalctl -u "$XRAY_SERVICE" -f --no-pager
            ;;
        config)
            ${EDITOR:-vi} "$XRAY_CONFIG_FILE"
            ;;
        reload)
            check_root
            systemctl reload-or-restart "$XRAY_SERVICE"
            print_success "Configuration reloaded"
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
