# GitHub 部署指南

## 📦 文件夹结构

```
manager/
├── .gitignore                    # Git 忽略文件
├── LICENSE                       # MIT 许可证
├── README.md                     # 主说明文档
├── QUICKSTART.md                 # 快速开始指南
├── install.sh                    # 一键安装脚本
├── xray-proxy-manager.sh         # 主管理脚本
├── xray-config-generator.sh      # 配置生成器
├── xray-node-manager.sh          # 节点管理器
├── xray-routing-mode.sh          # 路由模式切换
├── tproxy-bypass.conf            # 透明代理排除规则配置
└── docs/                         # 文档目录
    ├── 中文使用手册.md
    ├── 快速参考.md
    ├── BYPASS-GUIDE.md
    ├── PROXY-GUIDE.md
    └── CONFIG-ANALYSIS.md
```

## 🚀 部署到 GitHub

### 1. 创建 GitHub 仓库

1. 访问 https://github.com/new
2. 仓库名称：`xray-manager`（或其他名称）
3. 描述：`Xray 代理管理工具 - 功能完整的 Linux Xray 管理脚本`
4. 选择 Public（公开）
5. 不要初始化 README（我们已经有了）
6. 点击 "Create repository"

### 2. 上传文件

#### 方法 A：使用 Git 命令行

```bash
# 进入 manager 文件夹
cd manager

# 初始化 Git 仓库
git init

# 添加所有文件
git add .

# 提交
git commit -m "Initial commit: Xray Manager v2.0.0"

# 添加远程仓库（替换 your-username 为你的 GitHub 用户名）
git remote add origin https://github.com/your-username/xray-manager.git

# 推送到 GitHub
git branch -M main
git push -u origin main
```

#### 方法 B：使用 GitHub 网页上传

1. 在 GitHub 仓库页面点击 "uploading an existing file"
2. 将 manager 文件夹中的所有文件拖拽上传
3. 提交更改

### 3. 修改 install.sh 中的仓库地址

上传后，编辑 `install.sh` 文件，修改以下行：

```bash
# 第 23-25 行
GITHUB_USER="${GITHUB_USER:-your-username}"  # 改为你的 GitHub 用户名
GITHUB_REPO="${GITHUB_REPO:-xray-manager}"   # 改为你的仓库名
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
```

例如：
```bash
GITHUB_USER="${GITHUB_USER:-zhangsan}"
GITHUB_REPO="${GITHUB_REPO:-xray-manager}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
```

### 4. 修改 README.md 中的链接

在 README.md 中，将所有 `your-username` 替换为你的 GitHub 用户名。

可以使用查找替换：
```bash
# 在 manager 目录下
sed -i 's/your-username/你的用户名/g' README.md
sed -i 's/your-username/你的用户名/g' QUICKSTART.md
```

### 5. 提交更改

```bash
git add install.sh README.md QUICKSTART.md
git commit -m "Update repository URLs"
git push
```

## 📝 使用方式

部署完成后，用户可以通过以下命令安装：

```bash
# 一键安装
curl -fsSL https://raw.githubusercontent.com/your-username/xray-manager/main/manager/install.sh | sudo bash
```

或者：

```bash
# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/your-username/xray-manager/main/manager/install.sh -o install.sh

# 运行安装
chmod +x install.sh
sudo ./install.sh
```

## 🎯 测试安装

部署后，建议在一个干净的 Linux 环境中测试：

```bash
# 测试一键安装
curl -fsSL https://raw.githubusercontent.com/your-username/xray-manager/main/manager/install.sh | sudo bash

# 测试基本功能
xray-manager help
xray-manager node-add "vless://..." "测试节点"
sudo xray-manager start
xray-manager test
```

## 📢 推广

### 在 README.md 中添加徽章

```markdown
[![GitHub stars](https://img.shields.io/github/stars/your-username/xray-manager.svg?style=social&label=Star)](https://github.com/your-username/xray-manager)
[![GitHub forks](https://img.shields.io/github/forks/your-username/xray-manager.svg?style=social&label=Fork)](https://github.com/your-username/xray-manager/fork)
```

### 创建 Release

1. 在 GitHub 仓库页面点击 "Releases"
2. 点击 "Create a new release"
3. Tag version: `v2.0.0`
4. Release title: `Xray Manager v2.0.0`
5. 描述发布内容
6. 点击 "Publish release"

## 🔄 更新流程

当你修改代码后：

```bash
# 1. 提交更改
git add .
git commit -m "描述你的更改"
git push

# 2. 用户更新（重新运行安装脚本即可）
curl -fsSL https://raw.githubusercontent.com/your-username/xray-manager/main/manager/install.sh | sudo bash
```

## 📊 仓库设置建议

### Topics（主题标签）

在仓库设置中添加以下 topics：
- `xray`
- `proxy`
- `v2ray`
- `linux`
- `bash`
- `proxy-manager`
- `transparent-proxy`
- `china`

### About（关于）

- Website: 留空或填写文档链接
- Description: `功能完整的 Xray 代理管理工具，支持多节点管理、透明代理、路由切换等功能`

### Features（功能）

勾选：
- ✅ Issues
- ✅ Discussions（可选）
- ✅ Wiki（可选）

## 🎉 完成

现在你的 Xray Manager 已经成功部署到 GitHub！

用户可以通过一条命令安装：
```bash
curl -fsSL https://raw.githubusercontent.com/your-username/xray-manager/main/manager/install.sh | sudo bash
```

## 📝 注意事项

1. **安全性**: install.sh 会从 GitHub 下载文件，确保仓库是公开的
2. **分支名**: 默认使用 `main` 分支，如果你使用 `master`，需要修改 install.sh
3. **测试**: 部署后务必在干净环境中测试安装流程
4. **文档**: 保持 README.md 和文档的更新

## 🔗 相关链接

- GitHub 仓库: `https://github.com/your-username/xray-manager`
- 安装脚本: `https://raw.githubusercontent.com/your-username/xray-manager/main/manager/install.sh`
- 文档: `https://github.com/your-username/xray-manager/tree/main/manager/docs`
