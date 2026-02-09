# 快速开始指南

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/your-username/xray-manager/main/manager/install.sh | sudo bash
```

**注意**: 请将 `your-username` 替换为你的 GitHub 用户名

## 基本使用

### 1. 添加节点

```bash
xray-manager node-add "vless://..." "节点名称"
```

### 2. 启动服务

```bash
sudo xray-manager start
```

启动时会提示：
- 是否选择节点（如果有多个）
- 选择代理模式（系统代理/透明代理/两者/不配置）

### 3. 测试连接

```bash
xray-manager test
```

### 4. 查看状态

```bash
xray-manager status
```

## 常用命令

```bash
# 节点管理
xray-manager node-list              # 列出所有节点
xray-manager node-switch 节点名     # 切换节点

# 路由模式
sudo xray-manager route-mode bypass-cn    # 绕过大陆（推荐）
sudo xray-manager route-mode global       # 全局代理

# 代理管理
sudo xray-manager proxy-on          # 启用系统代理
sudo xray-manager tproxy-on         # 启用透明代理

# 服务管理
sudo xray-manager stop              # 停止服务
sudo xray-manager restart           # 重启服务
xray-manager logs                   # 查看日志
```

## 完整文档

查看 [README.md](README.md) 获取完整文档。
