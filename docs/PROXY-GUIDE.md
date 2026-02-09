# Xray 代理管理器 - 使用指南

## 功能特性

这个增强版工具提供了完整的 Xray 代理管理功能：

### 1. **系统代理管理**
- 自动设置环境变量（HTTP_PROXY, HTTPS_PROXY, ALL_PROXY）
- 支持 GNOME 桌面环境代理设置
- 支持 KDE 桌面环境代理设置
- 新终端会话自动使用代理

### 2. **透明代理管理**
- 基于 iptables 的全局透明代理
- 自动配置路由规则
- 支持 TCP 和 UDP 流量
- 支持 IPv4 和 IPv6
- 自动绕过本地和保留地址

### 3. **联动功能**
- 启动 Xray 时可选择代理模式
- 停止 Xray 时自动清理代理设置
- 重启时保持代理配置
- 一键测试代理连接

## 快速开始

### 第一步：准备配置文件

将你现有的 `config.json` 放到正确位置：

```bash
# 创建配置目录
sudo mkdir -p /usr/local/etc/xray

# 复制你的配置文件
sudo cp config.json /usr/local/etc/xray/config.json

# 设置权限
sudo chmod 644 /usr/local/etc/xray/config.json
```

### 第二步：安装 Xray（如果还没安装）

```bash
# 使用之前的安装脚本
sudo ./xray-manager.sh install
```

或者手动安装 Xray 到 `/usr/local/bin/xray`

### 第三步：启动并配置代理

```bash
# 添加执行权限
chmod +x xray-proxy-manager.sh

# 启动 Xray 并配置代理
sudo ./xray-proxy-manager.sh start
```

启动时会提示选择代理模式：
1. **系统代理** - 适合桌面环境，设置环境变量
2. **透明代理** - 全局代理，所有流量自动走代理
3. **两者都启用** - 同时启用系统代理和透明代理
4. **不配置代理** - 只启动 Xray，手动配置

## 详细使用说明

### 服务管理命令

#### 启动服务
```bash
sudo ./xray-proxy-manager.sh start
```
- 启动 Xray 服务
- 交互式选择代理模式
- 自动配置选定的代理类型

#### 停止服务
```bash
sudo ./xray-proxy-manager.sh stop
```
- 停止 Xray 服务
- 自动清理所有代理设置
- 清理 iptables 规则

#### 重启服务
```bash
sudo ./xray-proxy-manager.sh restart
```
- 重启 Xray 服务
- 自动恢复之前的代理设置
- 保持代理状态不变

#### 查看状态
```bash
./xray-proxy-manager.sh status
```
显示：
- 系统代理状态
- 透明代理状态
- Xray 服务状态
- 当前 iptables 规则

### 代理管理命令

#### 启用系统代理
```bash
sudo ./xray-proxy-manager.sh proxy-on
```
效果：
- 创建 `/etc/profile.d/xray-proxy.sh`
- 设置 GNOME/KDE 桌面代理
- 新终端自动使用代理

当前终端使用代理：
```bash
source /etc/profile.d/xray-proxy.sh
```

#### 禁用系统代理
```bash
sudo ./xray-proxy-manager.sh proxy-off
```
效果：
- 删除代理配置文件
- 清除桌面环境代理设置

当前终端清除代理：
```bash
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
```

#### 启用透明代理
```bash
sudo ./xray-proxy-manager.sh tproxy-on
```
效果：
- 配置 iptables TPROXY 规则
- 设置路由表
- 所有 TCP/UDP 流量自动代理
- 自动绕过局域网地址

**注意**：透明代理需要你的 `config.json` 包含 dokodemo-door 入站配置（见下文）

#### 禁用透明代理
```bash
sudo ./xray-proxy-manager.sh tproxy-off
```
效果：
- 清除所有 iptables 规则
- 删除路由表规则
- 恢复正常网络

#### 查看代理状态
```bash
./xray-proxy-manager.sh proxy-status
```

### 实用工具命令

#### 测试代理连接
```bash
./xray-proxy-manager.sh test
```
测试内容：
- SOCKS5 代理连接
- HTTP 代理连接
- 获取外部 IP 地址

#### 查看日志
```bash
./xray-proxy-manager.sh logs
```
实时查看 Xray 日志（Ctrl+C 退出）

#### 编辑配置
```bash
sudo ./xray-proxy-manager.sh config
```
使用默认编辑器打开配置文件

#### 重新加载配置
```bash
sudo ./xray-proxy-manager.sh reload
```
重新加载配置文件，不中断连接

## 配置文件要求

### 系统代理模式

你的 `config.json` 需要包含 SOCKS5 和 HTTP 入站：

```json
{
  "inbounds": [
    {
      "port": 10808,
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      }
    },
    {
      "port": 10809,
      "protocol": "http"
    }
  ]
}
```

### 透明代理模式

需要额外添加 dokodemo-door 入站：

```json
{
  "inbounds": [
    {
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
  ]
}
```

## 使用场景

### 场景 1：桌面环境日常使用

```bash
# 启动 Xray 并启用系统代理
sudo ./xray-proxy-manager.sh start
# 选择选项 1（系统代理）

# 浏览器和应用会自动使用代理
# 终端需要执行：
source /etc/profile.d/xray-proxy.sh

# 不需要时关闭
sudo ./xray-proxy-manager.sh stop
```

### 场景 2：服务器全局代理

```bash
# 启动 Xray 并启用透明代理
sudo ./xray-proxy-manager.sh start
# 选择选项 2（透明代理）

# 所有流量自动走代理，无需配置应用

# 关闭
sudo ./xray-proxy-manager.sh stop
```

### 场景 3：临时切换代理

```bash
# Xray 已经在运行

# 临时启用系统代理
sudo ./xray-proxy-manager.sh proxy-on

# 使用一段时间后关闭
sudo ./xray-proxy-manager.sh proxy-off

# Xray 继续运行，只是代理设置被清除
```

### 场景 4：修改配置后重启

```bash
# 编辑配置
sudo ./xray-proxy-manager.sh config

# 重启并保持代理设置
sudo ./xray-proxy-manager.sh restart
```

## 端口配置

默认端口（可在脚本开头修改）：

```bash
SOCKS_PORT="10808"      # SOCKS5 代理端口
HTTP_PORT="10809"       # HTTP 代理端口
TPROXY_PORT="12345"     # 透明代理端口
```

如果你的配置文件使用不同端口，需要修改脚本中的这些变量。

## 常见问题

### 1. 透明代理不工作

**检查配置文件**：
```bash
# 确保有 dokodemo-door 入站
grep -A 10 "dokodemo-door" /usr/local/etc/xray/config.json
```

**检查 iptables 规则**：
```bash
sudo iptables -t mangle -L XRAY -n -v
```

**查看日志**：
```bash
./xray-proxy-manager.sh logs
```

### 2. 系统代理不生效

**当前终端**：
```bash
# 需要手动加载
source /etc/profile.d/xray-proxy.sh

# 验证
echo $http_proxy
```

**新终端**：
- 新打开的终端会自动加载代理设置

**桌面应用**：
- 重启应用或注销重新登录

### 3. 某些网站无法访问

可能是路由规则问题，检查你的 `config.json` 中的 routing 配置。

### 4. 如何查看当前使用的 IP

```bash
# 使用代理查看
curl --socks5 127.0.0.1:10808 https://api.ipify.org

# 或使用测试命令
./xray-proxy-manager.sh test
```

### 5. 停止后仍有代理残留

```bash
# 手动清理环境变量
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY

# 手动清理 iptables
sudo iptables -t mangle -F XRAY
sudo iptables -t mangle -X XRAY
```

## 高级用法

### 自定义透明代理规则

编辑脚本中的 `enable_transparent_proxy` 函数，可以：
- 添加更多绕过规则
- 修改代理的目标端口
- 添加特定 IP 或域名的规则

### 开机自动启动

```bash
# 创建 systemd 服务
sudo cat > /etc/systemd/system/xray-proxy-auto.service <<EOF
[Unit]
Description=Xray Proxy Auto Start
After=network.target xray.service

[Service]
Type=oneshot
ExecStart=/path/to/xray-proxy-manager.sh proxy-on
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 启用服务
sudo systemctl enable xray-proxy-auto.service
```

### 配合其他工具使用

**与 proxychains 配合**：
```bash
# /etc/proxychains.conf
socks5 127.0.0.1 10808

# 使用
proxychains curl https://www.google.com
```

**与 Docker 配合**：
```bash
# 设置 Docker 代理
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:10809"
Environment="HTTPS_PROXY=http://127.0.0.1:10809"
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
```

## 安全建议

1. **不要在公共网络上启用透明代理** - 可能影响其他设备
2. **定期更新 Xray** - 使用 `xray-manager.sh install` 更新
3. **保护配置文件** - 确保 config.json 权限正确（644 或 600）
4. **监控日志** - 定期检查是否有异常连接
5. **备份配置** - 修改前先备份 config.json

## 卸载

```bash
# 停止并清理
sudo ./xray-proxy-manager.sh stop

# 删除脚本
rm xray-proxy-manager.sh

# 如需完全卸载 Xray
sudo ./xray-manager.sh uninstall
```

## 总结

这个工具提供了三种代理模式：

| 模式 | 适用场景 | 优点 | 缺点 |
|------|---------|------|------|
| **系统代理** | 桌面日常使用 | 易于控制，不影响系统流量 | 需要应用支持代理 |
| **透明代理** | 服务器/路由器 | 全局生效，无需配置应用 | 可能影响某些服务 |
| **混合模式** | 复杂环境 | 灵活性最高 | 配置较复杂 |

根据你的需求选择合适的模式即可！
