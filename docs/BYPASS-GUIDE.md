# 透明代理排除规则 - 详细说明

## 问题 1：系统代理对已运行程序无效

### 原因
系统代理通过**环境变量**工作（`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`）。环境变量的特点：
- 在进程**启动时**从父进程继承
- 进程运行后，环境变量**不会动态更新**
- 已运行的程序无法感知后续的环境变量变化

### 示例场景
```bash
# 1. 启动一个长期运行的程序
python my_server.py &
# 此时 my_server.py 的环境变量中没有代理设置

# 2. 启用系统代理
sudo ./xray-proxy-manager.sh proxy-on
# 这会创建 /etc/profile.d/xray-proxy.sh

# 3. my_server.py 仍然不使用代理
# 因为它启动时环境变量还没设置
```

### 解决方案

#### 方案 A：重启程序（推荐）
```bash
# 启用系统代理
sudo ./xray-proxy-manager.sh proxy-on

# 重启需要使用代理的程序
killall my_server.py
python my_server.py &  # 新进程会继承代理环境变量
```

#### 方案 B：使用透明代理
```bash
# 启用透明代理（对所有流量生效，包括已运行的程序）
sudo ./xray-proxy-manager.sh tproxy-on
```

#### 方案 C：手动设置环境变量后启动
```bash
# 先设置环境变量
export http_proxy="http://127.0.0.1:10809"
export https_proxy="http://127.0.0.1:10809"
export all_proxy="socks5://127.0.0.1:10808"

# 再启动程序
python my_server.py &
```

---

## 问题 2：透明代理排除特定应用

### 可用的排除方法

透明代理支持多种排除方式，通过 iptables 规则实现：

#### 方法 1：按用户排除（最推荐）

**原理**：为不需要代理的程序创建专用用户，排除该用户的所有流量。

**步骤**：

1. 创建专用用户：
```bash
sudo useradd -r -s /bin/false noproxy
```

2. 编辑配置文件：
```bash
sudo vi /usr/local/etc/xray/tproxy-bypass.conf
```

添加：
```bash
BYPASS_USERS=(
    "noproxy"
)
```

3. 重新启用透明代理：
```bash
sudo ./xray-proxy-manager.sh tproxy-off
sudo ./xray-proxy-manager.sh tproxy-on
```

4. 以该用户运行程序：
```bash
sudo -u noproxy python my_app.py
sudo -u noproxy nginx
```

**优点**：
- 简单可靠
- 易于管理
- 适合长期运行的服务

**示例：排除 Nginx**
```bash
# 创建用户
sudo useradd -r -s /bin/false nginx_noproxy

# 配置排除
echo 'BYPASS_USERS=("nginx_noproxy")' | sudo tee -a /usr/local/etc/xray/tproxy-bypass.conf

# 重启透明代理
sudo ./xray-proxy-manager.sh tproxy-off
sudo ./xray-proxy-manager.sh tproxy-on

# 以该用户运行 Nginx
sudo -u nginx_noproxy nginx
```

#### 方法 2：按 UID 排除

**适用场景**：已知程序的 UID，不想创建新用户。

```bash
# 查看程序的 UID
ps aux | grep my_app
# 假设 UID 是 1001

# 编辑配置
sudo vi /usr/local/etc/xray/tproxy-bypass.conf
```

添加：
```bash
BYPASS_UIDS=(
    1001
)
```

#### 方法 3：按目标 IP/网段排除

**适用场景**：排除访问特定服务器的流量。

```bash
# 编辑配置
sudo vi /usr/local/etc/xray/tproxy-bypass.conf
```

添加：
```bash
BYPASS_IPS=(
    "192.168.1.100"      # 单个 IP
    "10.0.0.0/8"         # 整个网段
    "172.16.50.0/24"     # 子网
)
```

**示例：排除访问内网数据库**
```bash
BYPASS_IPS=(
    "192.168.1.10"       # MySQL 服务器
    "192.168.1.11"       # Redis 服务器
)
```

#### 方法 4：按目标端口排除

**适用场景**：排除特定服务端口的流量。

```bash
# 编辑配置
sudo vi /usr/local/etc/xray/tproxy-bypass.conf
```

添加：
```bash
BYPASS_PORTS=(
    22        # SSH
    3306      # MySQL
    5432      # PostgreSQL
    6379      # Redis
    27017     # MongoDB
)
```

**效果**：所有访问这些端口的流量都不走代理。

#### 方法 5：按源端口排除

**适用场景**：排除从特定端口发出的流量。

```bash
BYPASS_SOURCE_PORTS=(
    8080      # 本地 Web 服务
    9000      # 本地 API 服务
)
```

### 预定义规则集

配置文件提供了预定义的规则集，可以快速启用：

#### 排除数据库服务
```bash
# 在 tproxy-bypass.conf 中取消注释：
enable_database_bypass
```

自动排除端口：3306 (MySQL), 5432 (PostgreSQL), 6379 (Redis), 27017 (MongoDB)

#### 排除本地开发服务
```bash
enable_dev_bypass
```

自动排除：
- 127.0.0.0/8 (本地回环)
- 端口：3000, 8080, 8000, 5000, 9000

#### 排除 Web 服务器
```bash
enable_webserver_bypass
```

自动排除：
- 用户：www-data, nginx, apache
- 端口：80, 443

---

## 完整使用示例

### 示例 1：排除 MySQL 和 Redis

```bash
# 1. 编辑配置文件
sudo vi /usr/local/etc/xray/tproxy-bypass.conf

# 2. 添加以下内容：
BYPASS_PORTS=(
    3306      # MySQL
    6379      # Redis
)

# 或者使用预定义规则：
enable_database_bypass

# 3. 重新启用透明代理
sudo ./xray-proxy-manager.sh tproxy-off
sudo ./xray-proxy-manager.sh tproxy-on

# 4. 验证规则
sudo iptables -t mangle -L XRAY -n -v
```

### 示例 2：排除特定应用（Nginx）

```bash
# 1. 创建专用用户
sudo useradd -r -s /bin/false nginx_direct

# 2. 配置排除
sudo vi /usr/local/etc/xray/tproxy-bypass.conf

BYPASS_USERS=(
    "nginx_direct"
)

# 3. 重新启用透明代理
sudo ./xray-proxy-manager.sh tproxy-off
sudo ./xray-proxy-manager.sh tproxy-on

# 4. 以该用户运行 Nginx
sudo -u nginx_direct /usr/sbin/nginx

# 5. 验证（Nginx 的流量不走代理）
sudo -u nginx_direct curl http://ipinfo.io/ip
# 应该显示你的真实 IP，不是代理 IP
```

### 示例 3：排除访问内网服务器

```bash
# 1. 配置排除内网 IP
sudo vi /usr/local/etc/xray/tproxy-bypass.conf

BYPASS_IPS=(
    "192.168.1.0/24"     # 整个内网段
    "10.0.0.50"          # 特定服务器
)

# 2. 重新启用透明代理
sudo ./xray-proxy-manager.sh tproxy-off
sudo ./xray-proxy-manager.sh tproxy-on

# 3. 测试
curl http://192.168.1.100  # 不走代理
curl http://google.com     # 走代理
```

### 示例 4：混合排除规则

```bash
# 编辑配置文件
sudo vi /usr/local/etc/xray/tproxy-bypass.conf

# 排除特定用户
BYPASS_USERS=(
    "mysql"
    "redis"
    "nginx"
)

# 排除特定 IP
BYPASS_IPS=(
    "192.168.1.0/24"     # 内网
    "10.0.0.100"         # 特定服务器
)

# 排除特定端口
BYPASS_PORTS=(
    22        # SSH
    3306      # MySQL
    5432      # PostgreSQL
)

# 重新启用
sudo ./xray-proxy-manager.sh tproxy-off
sudo ./xray-proxy-manager.sh tproxy-on
```

---

## 验证排除规则

### 查看 iptables 规则
```bash
# 查看所有 XRAY 链规则
sudo iptables -t mangle -L XRAY -n -v --line-numbers

# 输出示例：
# Chain XRAY (1 references)
# num   pkts bytes target     prot opt in     out     source               destination
# 1        0     0 RETURN     all  --  *      *       0.0.0.0/0            0.0.0.0/0            owner UID match 1001
# 2        0     0 RETURN     all  --  *      *       0.0.0.0/0            192.168.1.0/24
# 3        0     0 RETURN     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:3306
```

### 测试排除是否生效

#### 测试用户排除
```bash
# 以排除的用户运行
sudo -u noproxy curl http://ipinfo.io/ip
# 应该显示真实 IP

# 以普通用户运行
curl http://ipinfo.io/ip
# 应该显示代理 IP
```

#### 测试端口排除
```bash
# 访问排除的端口（如 3306）
telnet 192.168.1.10 3306
# 应该直连，不走代理

# 访问其他端口
curl http://google.com
# 应该走代理
```

---

## 常见问题

### 1. 修改配置后不生效

**原因**：iptables 规则已经加载，需要重新应用。

**解决**：
```bash
sudo ./xray-proxy-manager.sh tproxy-off
sudo ./xray-proxy-manager.sh tproxy-on
```

### 2. 如何查看当前排除了哪些规则

```bash
# 查看详细规则
sudo iptables -t mangle -L XRAY -n -v

# 查看配置文件
cat /usr/local/etc/xray/tproxy-bypass.conf
```

### 3. 排除规则的优先级

iptables 规则按顺序匹配，**先匹配先生效**。排除规则（RETURN）在 TPROXY 规则之前，所以：
1. 先检查排除规则（用户、IP、端口等）
2. 如果匹配排除规则，直接 RETURN（不走代理）
3. 如果不匹配，继续到 TPROXY 规则（走代理）

### 4. 如何临时禁用某个排除规则

```bash
# 查看规则编号
sudo iptables -t mangle -L XRAY -n --line-numbers

# 删除特定规则（假设是第 3 条）
sudo iptables -t mangle -D XRAY 3

# 恢复：重新启用透明代理
sudo ./xray-proxy-manager.sh tproxy-off
sudo ./xray-proxy-manager.sh tproxy-on
```

---

## 总结

### 系统代理 vs 透明代理

| 特性 | 系统代理 | 透明代理 |
|------|---------|---------|
| 对已运行程序生效 | ❌ 否 | ✅ 是 |
| 需要程序支持 | ✅ 需要 | ❌ 不需要 |
| 可排除特定应用 | ❌ 难 | ✅ 易 |
| 配置复杂度 | 低 | 中 |
| 适用场景 | 桌面环境 | 服务器/路由器 |

### 推荐方案

**无桌面环境的服务器**：
- 使用**透明代理** + **排除规则**
- 为不需要代理的服务创建专用用户
- 排除内网 IP 段和特定端口

**配置示例**：
```bash
# 1. 复制配置文件
sudo cp tproxy-bypass.conf /usr/local/etc/xray/

# 2. 编辑排除规则
sudo vi /usr/local/etc/xray/tproxy-bypass.conf

# 3. 启用透明代理
sudo ./xray-proxy-manager.sh start
# 选择选项 2（透明代理）

# 4. 验证
./xray-proxy-manager.sh status
```

这样就可以实现：
- ✅ 所有流量默认走代理
- ✅ 特定应用/服务不走代理
- ✅ 已运行的程序也能使用代理
- ✅ 灵活的排除规则
