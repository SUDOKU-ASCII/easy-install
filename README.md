# Sudoku 一键部署脚本

[English](#english) | [中文](#中文)

---

<a name="中文"></a>
## 🚀 快速开始

在你的 Linux 服务器上运行以下命令：

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"
```


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
