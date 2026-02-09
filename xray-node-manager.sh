#!/bin/bash

# Xray Node Manager
# 管理多个节点配置并支持切换

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
NODES_DIR="/usr/local/etc/xray/nodes"
ACTIVE_CONFIG="/usr/local/etc/xray/config.json"
CURRENT_NODE_FILE="/tmp/xray-current-node"
XRAY_SERVICE="xray.service"

# Initialize nodes directory
init_nodes_dir() {
    if [[ ! -d "$NODES_DIR" ]]; then
        mkdir -p "$NODES_DIR"
        print_info "Created nodes directory: $NODES_DIR"
    fi
}

# Add a new node
add_node() {
    local link="$1"
    local name="$2"

    if [[ -z "$link" ]]; then
        print_error "Please provide a share link"
        return 1
    fi

    if [[ -z "$name" ]]; then
        # Auto-generate name from link remark
        if [[ "$link" =~ "#"(.+)$ ]]; then
            name=$(echo "${BASH_REMATCH[1]}" | sed 's/%20/ /g' | sed 's/[^a-zA-Z0-9_-]/_/g')
        else
            name="node_$(date +%s)"
        fi
    fi

    init_nodes_dir

    local node_file="${NODES_DIR}/${name}.json"

    if [[ -f "$node_file" ]]; then
        print_warning "Node '$name' already exists"
        read -p "Overwrite? (y/n): " confirm
        if [[ "$confirm" != "y" ]]; then
            print_info "Cancelled"
            return 0
        fi
    fi

    print_info "Generating configuration for node: $name"

    # Check if config generator exists
    if [[ ! -f "./xray-config-generator.sh" ]]; then
        print_error "xray-config-generator.sh not found"
        print_info "Make sure xray-config-generator.sh is in the current directory"
        return 1
    fi

    # Generate config
    if ./xray-config-generator.sh "$link" "$node_file"; then
        print_success "Node '$name' added successfully"
        print_info "Config saved to: $node_file"
    else
        print_error "Failed to generate configuration"
        return 1
    fi
}

# List all nodes
list_nodes() {
    init_nodes_dir

    local nodes=($(ls -1 "$NODES_DIR"/*.json 2>/dev/null | xargs -n1 basename | sed 's/\.json$//'))

    if [[ ${#nodes[@]} -eq 0 ]]; then
        print_warning "No nodes found"
        print_info "Add a node with: $0 add \"vless://...\""
        return 0
    fi

    # Get current node
    local current_node=""
    if [[ -f "$CURRENT_NODE_FILE" ]]; then
        current_node=$(cat "$CURRENT_NODE_FILE")
    fi

    echo -e "\n${CYAN}=== Available Nodes ===${NC}\n"

    local i=1
    for node in "${nodes[@]}"; do
        if [[ "$node" == "$current_node" ]]; then
            echo -e "  ${GREEN}$i) $node ${YELLOW}(current)${NC}"
        else
            echo "  $i) $node"
        fi
        ((i++))
    done

    echo ""
}

# Switch to a node
switch_node() {
    local node_name="$1"

    init_nodes_dir

    local node_file="${NODES_DIR}/${node_name}.json"

    if [[ ! -f "$node_file" ]]; then
        print_error "Node '$node_name' not found"
        return 1
    fi

    print_info "Switching to node: $node_name"

    # Backup current config
    if [[ -f "$ACTIVE_CONFIG" ]]; then
        cp "$ACTIVE_CONFIG" "${ACTIVE_CONFIG}.backup"
    fi

    # Copy node config to active config
    cp "$node_file" "$ACTIVE_CONFIG"

    # Save current node
    echo "$node_name" > "$CURRENT_NODE_FILE"

    print_success "Switched to node: $node_name"

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
            cp "${ACTIVE_CONFIG}.backup" "$ACTIVE_CONFIG"
            return 1
        fi
    else
        print_warning "Xray service is not running"
        print_info "Start it with: systemctl start $XRAY_SERVICE"
    fi
}

# Interactive node selection
select_node() {
    init_nodes_dir

    local nodes=($(ls -1 "$NODES_DIR"/*.json 2>/dev/null | xargs -n1 basename | sed 's/\.json$//'))

    if [[ ${#nodes[@]} -eq 0 ]]; then
        print_warning "No nodes found"
        print_info "Add a node with: $0 add \"vless://...\""
        return 0
    fi

    list_nodes

    echo "Select a node to use:"
    read -p "Enter number [1-${#nodes[@]}]: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#nodes[@]} ]]; then
        print_error "Invalid choice"
        return 1
    fi

    local selected_node="${nodes[$((choice-1))]}"
    switch_node "$selected_node"
}

# Delete a node
delete_node() {
    local node_name="$1"

    if [[ -z "$node_name" ]]; then
        print_error "Please provide a node name"
        return 1
    fi

    local node_file="${NODES_DIR}/${node_name}.json"

    if [[ ! -f "$node_file" ]]; then
        print_error "Node '$node_name' not found"
        return 1
    fi

    print_warning "Delete node: $node_name"
    read -p "Are you sure? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        print_info "Cancelled"
        return 0
    fi

    rm "$node_file"
    print_success "Node '$node_name' deleted"

    # Clear current node if it was deleted
    if [[ -f "$CURRENT_NODE_FILE" ]]; then
        local current=$(cat "$CURRENT_NODE_FILE")
        if [[ "$current" == "$node_name" ]]; then
            rm "$CURRENT_NODE_FILE"
            print_warning "This was the active node. Please select another node."
        fi
    fi
}

# Show current node info
show_current() {
    if [[ ! -f "$CURRENT_NODE_FILE" ]]; then
        print_warning "No active node"
        return 0
    fi

    local current_node=$(cat "$CURRENT_NODE_FILE")
    local node_file="${NODES_DIR}/${current_node}.json"

    if [[ ! -f "$node_file" ]]; then
        print_error "Current node file not found: $node_file"
        return 1
    fi

    echo -e "\n${CYAN}=== Current Node ===${NC}"
    echo -e "Name: ${GREEN}$current_node${NC}"
    echo -e "Config: $node_file"

    # Extract server info if jq is available
    if command -v jq &> /dev/null; then
        local address=$(jq -r '.outbounds[0].settings.vnext[0].address' "$node_file" 2>/dev/null)
        local port=$(jq -r '.outbounds[0].settings.vnext[0].port' "$node_file" 2>/dev/null)
        local protocol=$(jq -r '.outbounds[0].protocol' "$node_file" 2>/dev/null)

        if [[ -n "$address" && "$address" != "null" ]]; then
            echo -e "Server: $address:$port"
            echo -e "Protocol: $protocol"
        fi
    fi

    echo ""
}

# Show usage
show_usage() {
    cat <<EOF
${CYAN}Xray Node Manager${NC}

Usage:
    $0 <command> [arguments]

Commands:
    add <link> [name]    添加新节点
    list                 列出所有节点
    select               交互式选择节点
    switch <name>        切换到指定节点
    delete <name>        删除节点
    current              显示当前节点信息

Examples:
    # 添加节点
    $0 add "vless://..." "US-Node"
    $0 add "vless://..."  # 自动命名

    # 列出节点
    $0 list

    # 选择节点（交互式）
    $0 select

    # 切换节点
    $0 switch US-Node

    # 删除节点
    $0 delete US-Node

    # 查看当前节点
    $0 current

Notes:
    - 节点配置保存在: $NODES_DIR
    - 当前配置: $ACTIVE_CONFIG
    - 切换节点会自动重启 xray 服务

EOF
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi

    case "$1" in
        add)
            shift
            add_node "$@"
            ;;
        list|ls)
            list_nodes
            ;;
        select|choose)
            select_node
            ;;
        switch|use)
            if [[ -z "$2" ]]; then
                print_error "Please provide a node name"
                exit 1
            fi
            switch_node "$2"
            ;;
        delete|del|rm)
            if [[ -z "$2" ]]; then
                print_error "Please provide a node name"
                exit 1
            fi
            delete_node "$2"
            ;;
        current|show)
            show_current
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
