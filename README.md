# Sudoku 一键部署脚本

[English](#english) | [中文](#中文)

---

<a name="中文"></a>
## 🚀 快速开始

在你的 Linux 服务器上运行以下命令：

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"
```

---

## 💻 客户端配置

服务端部署完成后，脚本会输出 **短链接** 和 **Clash 配置**。下面介绍如何在 Windows 和 macOS 上使用官方 Sudoku 客户端。

### Windows 客户端

#### 1. 下载客户端

从 [GitHub Releases](https://github.com/SUDOKU-ASCII/sudoku/releases) 下载 `sudoku-windows-amd64.zip`，解压获得 `sudoku.exe`。

#### 2. 启动客户端

打开 **命令提示符 (cmd)** 或 **PowerShell**，运行：

```cmd
# 使用短链接启动（推荐）
sudoku.exe -link "sudoku://你的短链接..."

# 或使用配置文件启动
sudoku.exe -c client.json
```

客户端默认监听 `127.0.0.1:10233`（SOCKS5 + HTTP 混合代理）。

#### 3. 配置系统代理

**方法一：命令行设置（CMD 管理员权限）**

```cmd
:: 开启代理
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /t REG_SZ /d "127.0.0.1:10233" /f

:: 关闭代理
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
```

**方法二：PowerShell**

```powershell
# 开启代理
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 1
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyServer -Value "127.0.0.1:10233"

# 关闭代理
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0
```

**方法三：图形界面**

1. 打开 **设置** → **网络和 Internet** → **代理**
2. 关闭「自动检测设置」
3. 在「手动设置代理」下，打开开关
4. 填入：
   - 地址：`127.0.0.1`
   - 端口：`10233`
5. 点击「保存」

> 💡 **提示**：部分应用（如终端、游戏）不走系统代理，需单独配置 SOCKS5 代理或使用 Proxifier 等工具。

---

### macOS 客户端

#### 1. 下载客户端

从 [GitHub Releases](https://github.com/SUDOKU-ASCII/sudoku/releases) 下载对应版本：
- Intel Mac: `sudoku-darwin-amd64.tar.gz`
- Apple Silicon: `sudoku-darwin-arm64.tar.gz`

解压后赋予执行权限：
```bash
chmod +x sudoku
```

#### 2. 启动客户端

```bash
# 使用短链接启动（推荐）
./sudoku -link "sudoku://你的短链接..."

# 或使用配置文件启动
./sudoku -c client.json
```

客户端默认监听 `127.0.0.1:10233`（SOCKS5 + HTTP 混合代理）。

#### 3. 配置系统代理

**方法一：终端命令行**

```bash
# 获取当前网络服务名称（通常是 "Wi-Fi" 或 "Ethernet"）
networksetup -listallnetworkservices

# 设置 SOCKS5 代理 (以 Wi-Fi 为例)
sudo networksetup -setsocksfirewallproxy "Wi-Fi" 127.0.0.1 10233
sudo networksetup -setsocksfirewallproxystate "Wi-Fi" on

# 设置 HTTP 代理
sudo networksetup -setwebproxy "Wi-Fi" 127.0.0.1 10233
sudo networksetup -setwebproxystate "Wi-Fi" on

# 设置 HTTPS 代理
sudo networksetup -setsecurewebproxy "Wi-Fi" 127.0.0.1 10233
sudo networksetup -setsecurewebproxystate "Wi-Fi" on

# 关闭所有代理
sudo networksetup -setsocksfirewallproxystate "Wi-Fi" off
sudo networksetup -setwebproxystate "Wi-Fi" off
sudo networksetup -setsecurewebproxystate "Wi-Fi" off
```

**方法二：图形界面**

1. 打开 **系统设置**（或系统偏好设置）
2. 点击 **网络** → 选择当前连接（如 Wi-Fi）
3. 点击 **详细信息...** → **代理**
4. 勾选以下选项并填入配置：
   - ✅ **网页代理 (HTTP)**：`127.0.0.1` 端口 `10233`
   - ✅ **安全网页代理 (HTTPS)**：`127.0.0.1` 端口 `10233`
   - ✅ **SOCKS 代理**：`127.0.0.1` 端口 `10233`
5. 点击「好」保存

> 💡 **提示**：终端应用默认不走系统代理，需要设置环境变量：
> ```bash
> export http_proxy=http://127.0.0.1:10233
> export https_proxy=http://127.0.0.1:10233
> export all_proxy=socks5://127.0.0.1:10233
> ```

---

### Android 客户端 (Sudodroid)

#### 1. 下载安装

从 [GitHub Releases](https://github.com/SUDOKU-ASCII/sudoku-android/releases) 下载最新 APK 并安装。

> 💡 如需自行编译，请参考项目的 [README](https://github.com/SUDOKU-ASCII/sudoku-android)。

#### 2. 导入短链接

打开 Sudodroid 后，有以下方式导入节点：

**方法一：使用「Quick Import」快捷导入**

1. 点击右下角 **「+」** 浮动按钮
2. 在弹出的对话框顶部找到 **「Quick Import」** 区域
3. 将 `sudoku://...` 短链接粘贴到输入框中
4. 点击 **「Import Short Link」** 按钮
5. 节点会自动导入并被选中

**方法二：使用剪贴板粘贴**

1. 复制服务端生成的短链接（以 `sudoku://` 开头）
2. 打开 Sudodroid，点击 **「+」** 按钮
3. 在 **「sudoku:// link」** 输入框右侧点击 **📋 粘贴图标**
4. 系统会自动从剪贴板读取内容
5. 点击 **「Import Short Link」** 完成导入

**方法三：手动配置**

如果不使用短链接，也可以在「Add node」对话框中手动填写：
- **Display name**：节点名称（可选）
- **Server host**：服务器 IP/域名
- **Port**：服务器端口（默认 10233）
- **Key**：私钥（Available Private Key）
- 其他选项按需配置

#### 3. 连接 VPN

1. 选择一个节点（点击节点卡片）
2. 点击顶部 **「Start VPN」** 按钮
3. 首次连接会请求 VPN 权限，点击「确定」授权
4. 连接成功后，状态栏会显示 VPN 图标

#### 4. 其他功能

| 功能 | 说明 |
|------|------|
| **测速 (Ping)** | 点击节点卡片的 🔄 刷新图标测试延迟 |
| **复制短链接** | 点击 🔗 链接图标可复制当前节点的短链接 |
| **编辑节点** | 点击 ✏️ 编辑图标修改配置 |
| **删除节点** | 点击 🗑️ 删除图标移除节点 |
| **切换节点** | VPN 运行时点击其他节点可热切换 |

---

### 脚本功能

- ✅ 自动检测系统架构 (amd64/arm64)
- ✅ 从 GitHub Releases 下载最新版本
- ✅ 自动生成密钥对
- ✅ 自动获取服务器公网 IP
- ✅ 创建 systemd 服务（开机自启）
- ✅ 自动部署 Cloudflare 风格 500 错误页回落站（默认 `127.0.0.1:10232`，失败则回落 `127.0.0.1:80`）
- ✅ 自动配置 UFW 防火墙（如果启用）
- ✅ 输出短链接和 Clash 节点配置

### 默认配置

| 配置项 | 默认值 |
|--------|--------|
| 端口 | `10233` |
| 模式 | `prefer_entropy` (低熵模式) |
| AEAD | `chacha20-poly1305` |
| 纯 Sudoku 下行 | `false` (带宽优化模式) |
| HTTP 掩码 | `true` (`auto`) |

### 自定义配置

通过环境变量自定义安装：

```bash
# 自定义端口
sudo SUDOKU_PORT=8443 bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# 自定义回落地址
sudo SUDOKU_FALLBACK="127.0.0.1:8080" bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# 关闭 Cloudflare 500 错误页回落站（将不会自动覆盖 SUDOKU_FALLBACK）
sudo SUDOKU_CF_FALLBACK=false bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# 自定义 Cloudflare 500 错误页回落站端口（优先 10232，失败再尝试 80）
sudo SUDOKU_CF_FALLBACK_PORT=10232 SUDOKU_CF_FALLBACK_FALLBACK_PORT=80 bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# 指定短链接/Clash 输出使用的域名或 IP（例如走 CDN 时用域名）
sudo SERVER_IP="example.com" bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# 关闭 HTTP 掩码（直连 TCP）
sudo SUDOKU_HTTP_MASK=false bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# 指定 HTTP 掩码模式（auto / stream / poll / legacy）
sudo SUDOKU_HTTP_MASK_MODE=poll bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# 开启 tunnel 模式 HTTPS（v0.1.4 起不再按端口自动推断 TLS）
sudo SUDOKU_HTTP_MASK_TLS=true bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"
```

### 卸载

```bash
sudo bash install.sh --uninstall
```

### 更新内核

再次运行一键命令会自动检测已有安装，仅更新 `/usr/local/bin/sudoku` 并重启服务，不会覆盖 `/etc/sudoku/config.json`。

---

## 📋 输出说明

安装完成后，脚本会输出：

### 1. 短链接 (Short Link)

```
sudoku://eyJoIjoiMS4yLjMuNCIsInAiOjEwMjMzLC...
```

客户端直接使用：
```bash
./sudoku -link "sudoku://..."
```

### 2. Clash/Mihomo 节点配置

```yaml
# sudoku
- name: sudoku
  type: sudoku
  server: 1.2.3.4
  port: 10233
  key: "你的私钥"
  aead-method: chacha20-poly1305
  padding-min: 2
  padding-max: 7
  custom-table: xpxvvpvv
  table-type: prefer_entropy
	  http-mask: true
	  http-mask-mode: auto
	  http-mask-tls: false
	  http-mask-multiplex: "on"
	  enable-pure-downlink: false
```

将此配置添加到你的 Clash 配置文件的 `proxies` 部分。

---

## 🌐 平台部署指南

### VPS 部署 (推荐)

直接使用一键脚本即可。支持：
- Ubuntu / Debian
- CentOS / RHEL / AlmaLinux
- Alpine Linux

---

## 🔧 服务管理

```bash
# 查看状态
sudo systemctl status sudoku

# 查看 Cloudflare 500 回落站状态
sudo systemctl status sudoku-fallback

# 重启服务
sudo systemctl restart sudoku

# 查看日志
sudo journalctl -u sudoku -f

# 停止服务
sudo systemctl stop sudoku
```

---

## 📁 文件位置

| 文件 | 路径 |
|------|------|
| 二进制 | `/usr/local/bin/sudoku` |
| 配置文件 | `/etc/sudoku/config.json` |
| 服务文件 | `/etc/systemd/system/sudoku.service` |
| Cloudflare 500 回落站服务 | `/etc/systemd/system/sudoku-fallback.service` |
| Cloudflare 500 回落站文件 | `/usr/local/lib/sudoku-fallback` |

---

<a name="english"></a>
## 🚀 Quick Start (English)

Run on your Linux server:

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"
```

---

## 💻 Client Configuration

After server deployment, the script outputs a **short link** and **Clash config**. Below is how to use the official Sudoku client on Windows and macOS.

### Windows Client

#### 1. Download

Download `sudoku-windows-amd64.zip` from [GitHub Releases](https://github.com/SUDOKU-ASCII/sudoku/releases) and extract `sudoku.exe`.

#### 2. Start Client

Open **Command Prompt** or **PowerShell**:

```cmd
# Start with short link (recommended)
sudoku.exe -link "sudoku://your-short-link..."

# Or use config file
sudoku.exe -c client.json
```

Client listens on `127.0.0.1:10233` (SOCKS5 + HTTP mixed proxy).

#### 3. Configure System Proxy

**Option 1: Command Line (Admin CMD)**

```cmd
:: Enable proxy
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /t REG_SZ /d "127.0.0.1:10233" /f

:: Disable proxy
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
```

**Option 2: PowerShell**

```powershell
# Enable proxy
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 1
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyServer -Value "127.0.0.1:10233"

# Disable proxy
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0
```

**Option 3: GUI**

1. Open **Settings** → **Network & Internet** → **Proxy**
2. Turn off "Automatically detect settings"
3. Under "Manual proxy setup", turn on the toggle
4. Enter:
   - Address: `127.0.0.1`
   - Port: `10233`
5. Click "Save"

> 💡 **Note**: Some apps (terminals, games) don't use system proxy. Use Proxifier or configure SOCKS5 directly.

---

### macOS Client

#### 1. Download

Download from [GitHub Releases](https://github.com/SUDOKU-ASCII/sudoku/releases):
- Intel Mac: `sudoku-darwin-amd64.tar.gz`
- Apple Silicon: `sudoku-darwin-arm64.tar.gz`

Extract and make executable:
```bash
chmod +x sudoku
```

#### 2. Start Client

```bash
# Start with short link (recommended)
./sudoku -link "sudoku://your-short-link..."

# Or use config file
./sudoku -c client.json
```

Client listens on `127.0.0.1:10233` (SOCKS5 + HTTP mixed proxy).

#### 3. Configure System Proxy

**Option 1: Terminal**

```bash
# List network services
networksetup -listallnetworkservices

# Set SOCKS5 proxy (using Wi-Fi as example)
sudo networksetup -setsocksfirewallproxy "Wi-Fi" 127.0.0.1 10233
sudo networksetup -setsocksfirewallproxystate "Wi-Fi" on

# Set HTTP proxy
sudo networksetup -setwebproxy "Wi-Fi" 127.0.0.1 10233
sudo networksetup -setwebproxystate "Wi-Fi" on

# Set HTTPS proxy
sudo networksetup -setsecurewebproxy "Wi-Fi" 127.0.0.1 10233
sudo networksetup -setsecurewebproxystate "Wi-Fi" on

# Disable all proxies
sudo networksetup -setsocksfirewallproxystate "Wi-Fi" off
sudo networksetup -setwebproxystate "Wi-Fi" off
sudo networksetup -setsecurewebproxystate "Wi-Fi" off
```

**Option 2: GUI**

1. Open **System Settings** (or System Preferences)
2. Click **Network** → Select current connection (e.g., Wi-Fi)
3. Click **Details...** → **Proxies**
4. Enable and configure:
   - ✅ **Web Proxy (HTTP)**: `127.0.0.1` port `10233`
   - ✅ **Secure Web Proxy (HTTPS)**: `127.0.0.1` port `10233`
   - ✅ **SOCKS Proxy**: `127.0.0.1` port `10233`
5. Click "OK"

> 💡 **Note**: Terminal apps don't use system proxy. Set environment variables:
> ```bash
> export http_proxy=http://127.0.0.1:10233
> export https_proxy=http://127.0.0.1:10233
> export all_proxy=socks5://127.0.0.1:10233
> ```

---

### Android Client (Sudodroid)

#### 1. Download

Download the latest APK from [GitHub Releases](https://github.com/SUDOKU-ASCII/sudoku-android/releases).

#### 2. Import Short Link

Open Sudodroid and import nodes using one of these methods:

**Option 1: Quick Import**

1. Tap the **"+"** floating button (bottom right)
2. Find the **"Quick Import"** section at the top of the dialog
3. Paste the `sudoku://...` short link into the input field
4. Tap **"Import Short Link"** button
5. The node will be imported and selected automatically

**Option 2: Clipboard Paste**

1. Copy the short link from server (starts with `sudoku://`)
2. Open Sudodroid, tap **"+"** button
3. Tap the **📋 paste icon** next to the "sudoku:// link" input field
4. The link will be read from clipboard automatically
5. Tap **"Import Short Link"** to complete

**Option 3: Manual Configuration**

You can also fill in the fields manually in the "Add node" dialog:
- **Display name**: Node name (optional)
- **Server host**: Server IP/domain
- **Port**: Server port (default 10233)
- **Key**: Private key (Available Private Key)
- Configure other options as needed

#### 3. Connect VPN

1. Select a node (tap the node card)
2. Tap **"Start VPN"** button at the top
3. Grant VPN permission when prompted (first time only)
4. VPN icon appears in status bar when connected

#### 4. Other Features

| Feature | Description |
|---------|-------------|
| **Ping** | Tap 🔄 refresh icon to test latency |
| **Copy Link** | Tap 🔗 link icon to copy node's short link |
| **Edit** | Tap ✏️ edit icon to modify settings |
| **Delete** | Tap 🗑️ delete icon to remove node |
| **Switch Node** | Tap another node while VPN is running to hot-switch |

---

### Features

- ✅ Auto-detect system architecture (amd64/arm64)
- ✅ Download latest release from GitHub
- ✅ Generate keypair automatically
- ✅ Detect server public IP
- ✅ Create systemd service (auto-start)
- ✅ Deploy Cloudflare-style 500 error fallback page (default `127.0.0.1:10232`, falls back to `127.0.0.1:80`)
- ✅ Configure UFW firewall (if enabled)
- ✅ Output short link and Clash node config

### Default Configuration

| Setting | Default |
|---------|---------|
| Port | `10233` |
| Mode | `prefer_entropy` (low entropy) |
| AEAD | `chacha20-poly1305` |
| Pure Sudoku Downlink | `false` (bandwidth optimized) |
| HTTP Mask | `true` (`auto`) |

### Customization

```bash
# Custom port
sudo SUDOKU_PORT=8443 bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# Custom fallback
sudo SUDOKU_FALLBACK="127.0.0.1:8080" bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# Disable Cloudflare 500 fallback page service (will not override SUDOKU_FALLBACK)
sudo SUDOKU_CF_FALLBACK=false bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# Customize Cloudflare 500 fallback page ports (try 10232 first, then 80)
sudo SUDOKU_CF_FALLBACK_PORT=10232 SUDOKU_CF_FALLBACK_FALLBACK_PORT=80 bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# Override advertised host (domain/IP) used in short link & Clash config (use a domain for CDN)
sudo SERVER_IP="example.com" bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# Disable HTTP mask (raw TCP)
sudo SUDOKU_HTTP_MASK=false bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# HTTP mask mode (auto / stream / poll / legacy)
sudo SUDOKU_HTTP_MASK_MODE=poll bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"

# Enable HTTPS in tunnel modes (since v0.1.4, no port-based TLS inference)
sudo SUDOKU_HTTP_MASK_TLS=true bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"
```

### Uninstall

```bash
sudo bash install.sh --uninstall
```

### Update

Re-run the one-click command to update `/usr/local/bin/sudoku` and restart the service; it will not overwrite `/etc/sudoku/config.json`.

---

## 📋 Output

After installation, the script outputs:

### 1. Short Link

```
sudoku://eyJoIjoiMS4yLjMuNCIsInAiOjEwMjMzLC...
```

Use with client:
```bash
./sudoku -link "sudoku://..."
```

### 2. Clash/Mihomo Node Config

```yaml
# sudoku
- name: sudoku
  type: sudoku
  server: 1.2.3.4
  port: 10233
  key: "your-private-key"
  aead-method: chacha20-poly1305
  padding-min: 2
  padding-max: 7
  custom-table: xpxvvpvv
  table-type: prefer_entropy
	  http-mask: true
	  http-mask-mode: auto
	  http-mask-tls: false
	  http-mask-multiplex: "on"
	  enable-pure-downlink: false
```

Add to the `proxies` section of your Clash config.

---

## 🌐 Platform Deployment

### VPS (Recommended)

Use the one-click script directly. Supports:
- Ubuntu / Debian
- CentOS / RHEL / AlmaLinux
- Alpine Linux

---

## 🔧 Service Management

```bash
sudo systemctl status sudoku    # Status
sudo systemctl status sudoku-fallback   # CF fallback page status
sudo systemctl restart sudoku   # Restart
sudo journalctl -u sudoku -f    # Logs
```

---

## License

GPL-3.0
