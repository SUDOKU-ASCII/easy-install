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

客户端默认监听 `127.0.0.1:1080`（SOCKS5 + HTTP 混合代理）。

#### 3. 配置系统代理

**方法一：命令行设置（CMD 管理员权限）**

```cmd
:: 开启代理
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /t REG_SZ /d "127.0.0.1:1080" /f

:: 关闭代理
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
```

**方法二：PowerShell**

```powershell
# 开启代理
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 1
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyServer -Value "127.0.0.1:1080"

# 关闭代理
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0
```

**方法三：图形界面**

1. 打开 **设置** → **网络和 Internet** → **代理**
2. 关闭「自动检测设置」
3. 在「手动设置代理」下，打开开关
4. 填入：
   - 地址：`127.0.0.1`
   - 端口：`1080`
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

客户端默认监听 `127.0.0.1:1080`（SOCKS5 + HTTP 混合代理）。

#### 3. 配置系统代理

**方法一：终端命令行**

```bash
# 获取当前网络服务名称（通常是 "Wi-Fi" 或 "Ethernet"）
networksetup -listallnetworkservices

# 设置 SOCKS5 代理 (以 Wi-Fi 为例)
sudo networksetup -setsocksfirewallproxy "Wi-Fi" 127.0.0.1 1080
sudo networksetup -setsocksfirewallproxystate "Wi-Fi" on

# 设置 HTTP 代理
sudo networksetup -setwebproxy "Wi-Fi" 127.0.0.1 1080
sudo networksetup -setwebproxystate "Wi-Fi" on

# 设置 HTTPS 代理
sudo networksetup -setsecurewebproxy "Wi-Fi" 127.0.0.1 1080
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
   - ✅ **网页代理 (HTTP)**：`127.0.0.1` 端口 `1080`
   - ✅ **安全网页代理 (HTTPS)**：`127.0.0.1` 端口 `1080`
   - ✅ **SOCKS 代理**：`127.0.0.1` 端口 `1080`
5. 点击「好」保存

> 💡 **提示**：终端应用默认不走系统代理，需要设置环境变量：
> ```bash
> export http_proxy=http://127.0.0.1:1080
> export https_proxy=http://127.0.0.1:1080
> export all_proxy=socks5://127.0.0.1:1080
> ```

---

### 脚本功能

- ✅ 自动检测系统架构 (amd64/arm64)
- ✅ 从 GitHub Releases 下载最新版本
- ✅ 自动生成密钥对
- ✅ 自动获取服务器公网 IP
- ✅ 创建 systemd 服务（开机自启）
- ✅ 自动配置 UFW 防火墙（如果启用）
- ✅ 输出短链接和 Clash 节点配置

### 默认配置

| 配置项 | 默认值 |
|--------|--------|
| 端口 | `10233` |
| 模式 | `prefer_entropy` (低熵模式) |
| AEAD | `chacha20-poly1305` |
| 纯 Sudoku 下行 | `false` (带宽优化模式) |
| HTTP 掩码 | `false` |

### 自定义配置

通过环境变量自定义安装：

```bash
# 自定义端口
sudo SUDOKU_PORT=8443 bash -c "$(curl -fsSL ...)"

# 自定义回落地址
sudo SUDOKU_FALLBACK="127.0.0.1:8080" bash -c "$(curl -fsSL ...)"
```

### 卸载

```bash
sudo bash install.sh --uninstall
```

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
  table-type: prefer_entropy
  http-mask: false
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

### WispByte 部署

1. 创建一个 Linux 实例
2. SSH 连接到实例
3. 运行一键安装脚本：
   ```bash
   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/install.sh)"
   ```
4. 保存输出的短链接和 Clash 配置

### Cloudflare Workers / Vercel

> ⚠️ **限制说明**

Sudoku 协议基于 TCP，而 Cloudflare Workers 和 Vercel 仅支持 HTTP/WebSocket。因此**无法直接在这些 Serverless 平台上运行 Sudoku 服务端**。

**替代方案：**

1. **Cloudflare Tunnel（推荐）**
   - 在 VPS 上运行 Sudoku 服务端
   - 使用 `cloudflared` 创建隧道暴露服务
   - 客户端通过 Cloudflare 域名连接

2. **分流方案**
   - Cloudflare Workers 可以作为流量分流器
   - 将请求转发到后端 Sudoku 服务器

### Render / Railway

这些平台支持 Docker 容器，可以部署 Sudoku：

```dockerfile
FROM golang:1.22-alpine AS builder
RUN apk add --no-cache git
RUN git clone https://github.com/SUDOKU-ASCII/sudoku.git /app
WORKDIR /app
RUN go build -o sudoku ./cmd/sudoku-tunnel

FROM alpine:latest
COPY --from=builder /app/sudoku /usr/local/bin/
COPY config.json /etc/sudoku/
EXPOSE 10233
CMD ["sudoku", "-c", "/etc/sudoku/config.json"]
```

---

## 🔧 服务管理

```bash
# 查看状态
sudo systemctl status sudoku

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

Client listens on `127.0.0.1:1080` (SOCKS5 + HTTP mixed proxy).

#### 3. Configure System Proxy

**Option 1: Command Line (Admin CMD)**

```cmd
:: Enable proxy
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer /t REG_SZ /d "127.0.0.1:1080" /f

:: Disable proxy
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f
```

**Option 2: PowerShell**

```powershell
# Enable proxy
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 1
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyServer -Value "127.0.0.1:1080"

# Disable proxy
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0
```

**Option 3: GUI**

1. Open **Settings** → **Network & Internet** → **Proxy**
2. Turn off "Automatically detect settings"
3. Under "Manual proxy setup", turn on the toggle
4. Enter:
   - Address: `127.0.0.1`
   - Port: `1080`
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

Client listens on `127.0.0.1:1080` (SOCKS5 + HTTP mixed proxy).

#### 3. Configure System Proxy

**Option 1: Terminal**

```bash
# List network services
networksetup -listallnetworkservices

# Set SOCKS5 proxy (using Wi-Fi as example)
sudo networksetup -setsocksfirewallproxy "Wi-Fi" 127.0.0.1 1080
sudo networksetup -setsocksfirewallproxystate "Wi-Fi" on

# Set HTTP proxy
sudo networksetup -setwebproxy "Wi-Fi" 127.0.0.1 1080
sudo networksetup -setwebproxystate "Wi-Fi" on

# Set HTTPS proxy
sudo networksetup -setsecurewebproxy "Wi-Fi" 127.0.0.1 1080
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
   - ✅ **Web Proxy (HTTP)**: `127.0.0.1` port `1080`
   - ✅ **Secure Web Proxy (HTTPS)**: `127.0.0.1` port `1080`
   - ✅ **SOCKS Proxy**: `127.0.0.1` port `1080`
5. Click "OK"

> 💡 **Note**: Terminal apps don't use system proxy. Set environment variables:
> ```bash
> export http_proxy=http://127.0.0.1:1080
> export https_proxy=http://127.0.0.1:1080
> export all_proxy=socks5://127.0.0.1:1080
> ```

---

### Features

- ✅ Auto-detect system architecture (amd64/arm64)
- ✅ Download latest release from GitHub
- ✅ Generate keypair automatically
- ✅ Detect server public IP
- ✅ Create systemd service (auto-start)
- ✅ Configure UFW firewall (if enabled)
- ✅ Output short link and Clash node config

### Default Configuration

| Setting | Default |
|---------|---------|
| Port | `10233` |
| Mode | `prefer_entropy` (low entropy) |
| AEAD | `chacha20-poly1305` |
| Pure Sudoku Downlink | `false` (bandwidth optimized) |
| HTTP Mask | `false` |

### Customization

```bash
# Custom port
sudo SUDOKU_PORT=8443 bash -c "$(curl -fsSL ...)"

# Custom fallback
sudo SUDOKU_FALLBACK="127.0.0.1:8080" bash -c "$(curl -fsSL ...)"
```

### Uninstall

```bash
sudo bash install.sh --uninstall
```

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
  table-type: prefer_entropy
  http-mask: false
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

### Cloudflare Workers / Vercel

> ⚠️ **Limitation**

Sudoku uses TCP protocol. Cloudflare Workers and Vercel only support HTTP/WebSocket. **Cannot run Sudoku server directly on these platforms.**

**Alternatives:**

1. **Cloudflare Tunnel** - Run Sudoku on VPS, expose via `cloudflared`
2. **Relay** - Use Workers as traffic relay to backend Sudoku server

---

## 🔧 Service Management

```bash
sudo systemctl status sudoku    # Status
sudo systemctl restart sudoku   # Restart
sudo journalctl -u sudoku -f    # Logs
```

---

## License

GPL-3.0
