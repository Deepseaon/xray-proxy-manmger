# Xray Proxy Manager - Linux cli 代理管理工具

<div align="center">

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux-green.svg)](https://www.linux.org/)
[![Shell](https://img.shields.io/badge/shell-bash-orange.svg)](https://www.gnu.org/software/bash/)

一套功能完整的 Xray 代理管理工具，专为 Linux 服务器设计

[![GitHub stars](https://img.shields.io/github/stars/Deepseaon/xray-proxy-manmger.svg?style=social&label=Star)](https://github.com/your-username/xray-manager)
[![GitHub forks](https://img.shields.io/github/forks/Deepseaon/xray-proxy-manmger.svg?style=social&label=Fork)](https://github.com/your-username/xray-manager/fork)

[功能特性](#功能特性) • [快速开始](#快速开始) • [使用文档](#使用文档) • [常见问题](#常见问题)

</div>

---

## 功能特性

###  核心功能

- **一键生成配置** - 从 vless/vmess 分享链接直接生成完整配置
-  **多节点管理** - 保存多个节点，随时切换，启动时可选择
-  **系统代理** - 设置环境变量，支持 GNOME/KDE 桌面
-  **透明代理** - 基于 iptables 的全局透明代理
-  **排除规则** - 灵活的透明代理排除规则（按用户、IP、端口等）
-  **路由模式切换** - 绕过大陆/全局代理/直连三种模式
-  **服务管理** - 启动/停止/重启/状态查看
-  **连接测试** - 测试代理是否正常工作
-  **模块化** - 各功能可使用对应命令独立运行，可只使用代理模式管理

---

## 快速开始

### 一键安装

```bash
# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/Deepseaon/xray-proxy-manager/main/install.sh | sudo bash
```

或者手动安装：

```bash
# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/Deepseaon/xray-proxy-manager/main/install.sh -o install.sh

# 运行安装
chmod +x install.sh
sudo ./install.sh
```

### 前提事项（重要）

该脚本需要通过systemctl管理xray，请确保你正确安装了xray内核。
若你通过其他方式安装，请创建或修改service文件并且使其启动命令使用的是默认位置的配置文件```/usr/local/etc/xray/config.json```
##### 该脚本会在你导入链接后自动生成config.json覆写该位置的配置，若你原本有配置在该区域，请及时生成备份，再进行后面的操作

若你觉得该脚本生成配置比较简陋，你也可以在他生成之后手动替换你的config到指定区域，只要不在脚本切换节点config就不会被覆写，且依旧可以使用代理管理功能

若你不需要该脚本自动管理xray，也可以使用下面的代理模式切换命令，直接启动透明代理功能，高自定义程度

### 快速使用

```bash
# 1. 添加节点
xray-manager node-add "vless://..." "节点名称"

# 2. 启动服务
sudo xray-manager start

# 3. 测试连接
xray-manager test

# 4. 查看状态
xray-manager status
```

---

## 系统要求

- **操作系统**: Linux (Debian/Ubuntu/CentOS/RHEL/Arch)
- **Shell**: Bash 4.0+
- **权限**: Root (用于服务管理和代理配置)
- **依赖**: jq, curl, unzip

### 安装依赖

```bash
# Debian/Ubuntu
sudo apt update
sudo apt install jq curl unzip

# CentOS/RHEL
sudo yum install jq curl unzip

# Arch Linux
sudo pacman -S jq curl unzip
```

---

## 使用文档

### 基础命令

#### 节点管理

```bash
# 添加节点
xray-manager node-add "vless://..." "节点名"

# 列出所有节点
xray-manager node-list

# 选择节点（交互式）
xray-manager node-select

# 切换到指定节点
xray-manager node-switch 节点名

# 查看当前节点
xray-manager node-current

# 删除节点
xray-manager node-delete 节点名
```

#### 服务管理

```bash
# 启动服务（含节点选择）
sudo xray-manager start

# 停止服务并清理代理
sudo xray-manager stop

# 重启服务
sudo xray-manager restart

# 查看状态
xray-manager status

# 查看日志
xray-manager logs

# 测试连接
xray-manager test
```

#### 代理模式

```bash
# 启用系统代理
sudo xray-manager proxy-on

# 禁用系统代理
sudo xray-manager proxy-off

# 启用透明代理
sudo xray-manager tproxy-on

# 禁用透明代理
sudo xray-manager tproxy-off

# 查看代理状态
xray-manager proxy-status
```

#### 路由模式

```bash
# 绕过大陆模式（推荐）
sudo xray-manager route-mode bypass-cn

# 全局代理模式
sudo xray-manager route-mode global

# 直连模式
sudo xray-manager route-mode direct

# 查看当前路由模式
xray-manager route-status
```

### 完整文档



---

## 使用场景

### 场景一：无桌面服务器

```bash
# 1. 添加节点
xray-manager node-add "vless://..." "主节点"

# 2. 启动并选择透明代理
sudo xray-manager start
# 选择：透明代理模式

# 3. 设置绕过大陆路由
sudo xray-manager route-mode bypass-cn

# 4. 配置排除规则（可选）
sudo vi /usr/local/etc/xray/tproxy-bypass.conf
```

### 场景二：管理多个节点

```bash
# 添加多个节点
xray-manager node-add "vless://..." "美国节点"
xray-manager node-add "vless://..." "日本节点"
xray-manager node-add "vless://..." "香港节点"

# 查看所有节点
xray-manager node-list

# 启动时选择节点
sudo xray-manager start

# 随时切换节点
sudo xray-manager node-switch 日本节点
```

### 场景三：桌面环境

```bash
# 1. 添加节点
xray-manager node-add "vless://..." "主节点"

# 2. 启动并选择系统代理
sudo xray-manager start
# 选择：系统代理模式

# 3. 当前终端使用代理
source /etc/profile.d/xray-proxy.sh

# 4. 设置绕过大陆路由
sudo xray-manager route-mode bypass-cn
```

---

## 路由模式说明

| 模式 | 国内网站 | 国外网站 | 适用场景 |
|------|---------|---------|---------|
| **bypass-cn** | 直连 | 走代理 | 日常使用（推荐） |
| **global** | 走代理 | 走代理 | 完全隐藏 IP |
| **direct** | 直连 | 直连 | 临时禁用代理 |

---

## 代理模式对比

| 特性 | 系统代理 | 透明代理 |
|------|---------|---------|
| 对已运行程序生效 |  否 |  是 |
| 需要程序支持 |  需要 |  不需要 |
| 可排除特定应用 |  难 |  易 |
| 配置复杂度 | 低 | 中 |
| 适用场景 | 桌面环境 | 服务器 |

---

## 常见问题

### Q1: 如何使用分享链接？

```bash
# 直接使用 vless/vmess 分享链接
xray-manager node-add "vless://uuid@server:443?..." "节点名"
```

### Q2: 系统代理不生效？

系统代理只对新启动的程序生效。解决方法：
- 重启需要代理的程序
- 或使用透明代理模式

### Q3: 如何排除特定应用？

编辑排除规则配置：
```bash
sudo vi /usr/local/etc/xray/tproxy-bypass.conf
```

详见：[透明代理排除规则](manager/docs/BYPASS-GUIDE.md)

### Q4: 如何更新工具？

```bash
# 重新运行安装脚本即可
curl -fsSL https://raw.githubusercontent.com/Deepseaon/xray-proxy-manager/main/install.sh | sudo bash
```

### Q5: 如何卸载？

```bash
# 停止服务
sudo xray-manager stop

# 删除安装文件
sudo rm -rf /opt/xray-manager
sudo rm /usr/local/bin/xray-manager

# 删除配置（可选）
sudo rm -rf /usr/local/etc/xray
```

---

## 文件结构

```
xray-manager/
├── manager/
│   ├── install.sh                    # 安装脚本
│   ├── xray-proxy-manager.sh         # 主管理脚本
│   ├── xray-config-generator.sh      # 配置生成器
│   ├── xray-node-manager.sh          # 节点管理器
│   ├── xray-routing-mode.sh          # 路由模式切换
│   ├── tproxy-bypass.conf            # 透明代理排除规则配置
│   └── docs/                         # 文档目录
│       ├── 中文使用手册.md
│       ├── 快速参考.md
│       ├── BYPASS-GUIDE.md
│       ├── PROXY-GUIDE.md
│       └── CONFIG-ANALYSIS.md
├── README.md                         # 本文件
└── LICENSE                           # 许可证
```

---

## 端口说明

| 端口 | 协议 | 用途 |
|------|------|------|
| 10808 | mixed | SOCKS5 + HTTP 代理 |
| 12345 | dokodemo-door | 透明代理 |

---

## 贡献

欢迎提交 Issue 和 Pull Request！

### 开发

```bash
# 克隆仓库
git clone https://github.com/Deepseaon/xray-proxy-manager.git
cd xray-manager

# 本地测试
cd manager
chmod +x *.sh
sudo ./install.sh
```

---

## 许可证

[MIT License](LICENSE)

---

## 致谢

- [Xray-core](https://github.com/XTLS/Xray-core) - 强大的代理工具

---

## 联系方式

- **Issues**: [GitHub Issues](https://github.com/Deepseaon/xray-proxy-manmger/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Deepseaon/xray-proxy-manmger/discussions)

---

<div align="center">

**如果这个项目对你有帮助，请给个 ⭐ Star！**

Made with ❤️ by Deepseaon

</div>
