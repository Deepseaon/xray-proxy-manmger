#!/bin/bash

# Xray Complete Config Generator
# 从分享链接生成完整的 xray 配置文件

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# URL decode function
urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

# Generate complete config with parsed outbound
generate_complete_config() {
    local outbound_json="$1"
    local node_name="$2"

    cat <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "mixed-in",
      "port": 10808,
      "listen": "0.0.0.0",
      "protocol": "mixed",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "settings": {
        "auth": "noauth",
        "udp": true
      }
    },
    {
      "tag": "tproxy-in",
      "port": 12345,
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "streamSettings": {
        "sockopt": {
          "tproxy": "tproxy",
          "mark": 1
        }
      }
    }
  ],
  "outbounds": [
$(echo "$outbound_json" | sed 's/^/    /'),
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "inboundTag": ["tproxy-in"],
        "outboundTag": "proxy"
      },
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
  }
}
EOF
}

# Parse VLESS share link
parse_vless() {
    local link="$1"
    link="${link#vless://}"

    # Extract remark
    local remark="Unnamed"
    if [[ "$link" =~ "#"(.+)$ ]]; then
        remark=$(urldecode "${BASH_REMATCH[1]}")
        link="${link%%#*}"
    fi

    # Extract query parameters
    local params=""
    if [[ "$link" =~ "?"(.+)$ ]]; then
        params="${BASH_REMATCH[1]}"
        link="${link%%\?*}"
    fi

    # Extract UUID and server
    local uuid="${link%%@*}"
    local server_part="${link#*@}"
    local address="${server_part%:*}"
    local port="${server_part#*:}"

    # Parse query parameters
    local encryption="" flow="" security="" sni="" fp="" alpn="" type="" host="" path="" mode=""
    local insecure="false" ech=""

    IFS='&' read -ra PARAMS <<< "$params"
    for param in "${PARAMS[@]}"; do
        key="${param%%=*}"
        value=$(urldecode "${param#*=}")

        case "$key" in
            encryption) encryption="$value" ;;
            flow) flow="$value" ;;
            security) security="$value" ;;
            sni) sni="$value" ;;
            fp) fp="$value" ;;
            alpn) alpn="$value" ;;
            type) type="$value" ;;
            host) host="$value" ;;
            path) path="$value" ;;
            mode) mode="$value" ;;
            insecure|allowInsecure)
                [[ "$value" == "1" ]] && insecure="true"
                ;;
            ech) ech="$value" ;;
        esac
    done

    # Generate outbound JSON
    local outbound=$(cat <<EOF
{
  "tag": "proxy",
  "protocol": "vless",
  "settings": {
    "vnext": [
      {
        "address": "$address",
        "port": $port,
        "users": [
          {
            "id": "$uuid",
            "encryption": "${encryption:-none}"$(
            if [[ -n "$flow" ]]; then
                echo ","
                echo "            \"flow\": \"$flow\""
            fi
            )
          }
        ]
      }
    ]
  },
  "streamSettings": {
$(
    if [[ -n "$type" ]]; then
        echo "    \"network\": \"$type\","
    fi
)$(
    if [[ "$security" == "tls" ]]; then
        echo "    \"security\": \"tls\","
        echo "    \"tlsSettings\": {"
        echo "      \"allowInsecure\": $insecure"
        [[ -n "$sni" ]] && echo "      ,\"serverName\": \"$sni\""
        if [[ -n "$alpn" ]]; then
            alpn_array=$(echo "$alpn" | sed 's/,/", "/g')
            echo "      ,\"alpn\": [\"$alpn_array\"]"
        fi
        [[ -n "$fp" ]] && echo "      ,\"fingerprint\": \"$fp\""
        if [[ -n "$ech" ]]; then
            echo "      ,\"echConfigList\": \"$ech\""
            echo "      ,\"echForceQuery\": \"full\""
        fi
        echo "    },"
    fi
)$(
    case "$type" in
        ws)
            echo "    \"wsSettings\": {"
            [[ -n "$path" ]] && echo "      \"path\": \"$path\","
            if [[ -n "$host" ]]; then
                echo "      \"headers\": {"
                echo "        \"Host\": \"$host\""
                echo "      },"
            fi
            echo "      \"maxEarlyData\": 2048"
            echo "    },"
            ;;
        xhttp)
            echo "    \"xhttpSettings\": {"
            [[ -n "$path" ]] && echo "      \"path\": \"$path\","
            [[ -n "$host" ]] && echo "      \"host\": \"$host\","
            [[ -n "$mode" ]] && echo "      \"mode\": \"$mode\","
            echo "      \"downloadSettings\": {}"
            echo "    },"
            ;;
    esac
)    "sockopt": {
      "mark": 0
    }
  }
}
EOF
)

    # Generate complete config
    generate_complete_config "$outbound" "$remark"
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        cat <<EOF
${BLUE}Xray Complete Config Generator${NC}

Usage:
    $0 <share-link> [output-file]

Examples:
    $0 "vless://..." config.json
    $0 "vmess://..." my-node.json

Output:
    Generates complete xray configuration file

EOF
        exit 0
    fi

    local link="$1"
    local output="${2:-config.json}"

    # Detect protocol
    if [[ "$link" =~ ^vless:// ]]; then
        print_info "Parsing VLESS link..."
        local config=$(parse_vless "$link")

        # Save to file
        echo "$config" > "$output"
        print_success "Complete configuration saved to: $output"
        print_info "You can now use: sudo cp $output /usr/local/etc/xray/config.json"

    elif [[ "$link" =~ ^vmess:// ]]; then
        print_error "VMess support coming soon"
        exit 1
    else
        print_error "Unknown protocol. Supported: vless://"
        exit 1
    fi
}

main "$@"
