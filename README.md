# Sudoku 一键部署 & dash 管理面板

[English](#english) | [中文](#中文)

---

<a name="中文"></a>
## 中文

### 一键安装

在 Linux 服务器（systemd，amd64 / arm64）上以 root 运行：

```bash
curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh -o /tmp/sudoku-dash.sh && sudo bash /tmp/sudoku-dash.sh
```

全程只需一路回车：**端口**（默认随机）→ **AEAD 加密方式**（默认 `chacha20-poly1305`）→ **ASCII 模式**（默认 `up_ascii_down_entropy`）→ **是否启用 WARP**（默认否）。其余（自定义表 `custom_table` 自动随机生成、packed 下行、HTTP Mask `auto` + 随机路径前缀、CF 风格回落页）都用默认值，不会提问。装完会直接给出 `sudoku://` 分享链接。

安装后脚本会变成常驻的管理面板 **`sudoku-dash`**，随时启动：

```bash
sudo sudoku-dash
```

面板功能：

- **实时带宽**：服务端 RX / TX 速率、曲线、累计与峰值、各客户端 IP 速率
- **资源占用**：Sudoku 进程 CPU / 内存 / 连接数 / 线程 / FD，以及系统负载
- **用户管理**：添加 / 限速 / 限流量 / 封禁 / 删除用户，为每个用户生成独立分享链接
- **版本管理**：升级到最新 release、安装指定版本或预发布、失败自动回滚、手动回滚到备份
- **服务控制 / 设置**：重启、停止、查看与跟随日志、改端口、开关 WARP、改公网地址

> 非交互环境（`curl … | sudo bash`、CI）会自动采用默认值，不弹任何提问。

### 环境变量

全部可选，写在命令前即可，例如 `sudo SUDOKU_PORT=8443 SUDOKU_WARP=true bash /tmp/sudoku-dash.sh`。设置了某项，向导就不会再问它。

| 变量 | 默认值 | 含义 |
| --- | --- | --- |
| `SUDOKU_PORT` | 随机 50001-65535 | 服务端监听端口（**自定义端口**用它） |
| `SUDOKU_AEAD` | `chacha20-poly1305` | 加密方式：`chacha20-poly1305` / `aes-128-gcm` / `none` |
| `SUDOKU_ASCII` | `up_ascii_down_entropy` | ASCII 模式：`up_ascii_down_entropy` / `prefer_entropy` / `prefer_ascii` / `up_entropy_down_ascii` |
| `SUDOKU_WARP` | `false` | `true` = 所有代理流量经 Cloudflare WARP 出站（隐藏 VPS 出口 IP、解锁地区限制）。会改用 [sudoku-sing-box](https://github.com/SUDOKU-ASCII/sudoku-sing-box) 内核，旧名 `SUDOKU_WARP_GOOGLE` 仍可用 |
| `SUDOKU_VERSION` | 最新 release | 指定安装的 Sudoku 版本 tag，如 `v0.5.1` |
| `SERVER_IP` | 自动检测 | 写入分享链接的公网 IP 或域名 |
| `SUDOKU_YES` | 自动 | `1` = 永不提问；无 TTY 时默认为 `1` |
| `SUDOKU_LANG` | 跟随 `$LANG` | 界面语言：`zh` / `en` |
| `SUDOKU_CLIENT_PORT` | `10233` | 导出的客户端配置里本地代理端口 |
| `SUDOKU_FALLBACK` | 内置 CF 风格 500 页 | 可疑流量的回落地址 `host:port`；自定义后不再覆盖 |
| `SUDOKU_CF_FALLBACK` | `true` | `false` = 不部署内置回落页，回落到 `127.0.0.1:80` |
| `SUDOKU_CF_FALLBACK_BIND` / `_PORT` / `_FALLBACK_PORT` / `_FORCE` | `127.0.0.1` / `10232` / `80` / `false` | 内置回落页的监听地址、端口、备用端口、是否强制覆盖 `SUDOKU_FALLBACK` |
| `SUDOKU_HTTP_MASK` | `true` | HTTP Mask 开关 |
| `SUDOKU_HTTP_MASK_MODE` | `auto` | `auto` / `stream` / `poll` / `legacy` / `ws` |
| `SUDOKU_HTTP_MASK_TLS` | `false` | HTTP Mask 是否走 TLS |
| `SUDOKU_HTTP_MASK_HOST` | 空 | 覆盖 HTTP Mask 的 Host |
| `SUDOKU_HTTP_MASK_PATH_ROOT` | 随机 6-10 位小写字母 | 单段路径前缀 `[A-Za-z0-9_-]+` |
| `SUDOKU_HTTP_MASK_MULTIPLEX` | `on` | `off` / `auto` / `on` |
| `SUDOKU_SUBSCRIPTION_PATH` | `/etc/sudoku/subscription.yaml` | 本地生成的 Mihomo YAML 输出路径 |
| `SUDOKU_SUBSCRIPTION_NODE_NAME` | `sudoku` | YAML 中的节点名 |
| `SUDOKU_SUBSCRIPTION_TEMPLATE_URL` | 内置模板 | 自定义 Mihomo 模板（需含 `rule-providers:`） |
| `SUDOKU_REPO` | `SUDOKU-ASCII/sudoku` | 内核仓库 |

**自定义端口**

```bash
# 安装时
curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh -o /tmp/sudoku-dash.sh && sudo SUDOKU_PORT=8443 bash /tmp/sudoku-dash.sh
# 安装后：sudo sudoku-dash → 设置 → 修改端口（自动更新防火墙与服务；客户端需换用新链接）
```

**WARP**

```bash
# 安装时直接启用
curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh -o /tmp/sudoku-dash.sh && sudo SUDOKU_WARP=true bash /tmp/sudoku-dash.sh
# 安装后随时开关：sudo sudoku-dash → 设置 → 启用 / 关闭 WARP
```

### 用户管理说明

- 用户控制依赖内核的 `users` 白名单：当前 release（v0.5.1）会忽略该字段，需要 **Sudoku ≥ 0.5.2**（官方主线已合入、尚未发布），或启用 WARP 模式（自带的 sudoku-sing-box 已支持）。内核不支持时 dash 会明确提示，不会让你误以为限制已生效。
- 添加第一个用户时会把安装时的默认密钥自动加为 `default` 用户，避免现有客户端被锁出。
- 修改用户后需重启服务才生效（dash 会询问并代为重启）。
- 内核不暴露「单用户字节数」，用户列表展示的是限速 / 流量上限 / 状态，以及从日志统计的 24 小时会话数；实时流量是该端口的总 RX / TX。

### 升级 / 卸载

```bash
# 升级到最新 release（同时更新 dash）：
sudo sudoku-dash --upgrade
# 或在面板里：sudo sudoku-dash → 版本管理（可选版本、可回滚；新版本启动失败会自动回滚）

# 卸载（交互式会询问是否同时删除配置与密钥）：
sudo sudoku-dash --uninstall
# 脚本不在本机时：
curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh -o /tmp/sudoku-dash.sh
sudo bash /tmp/sudoku-dash.sh --uninstall
```

其它命令：`sudoku-dash status`（纯文本状态）、`sudoku-dash --help`。

> `dash` 同名命令仅在系统里不存在 `dash`（Debian/Ubuntu 的 shell）时才会创建；一律可用 `sudoku-dash`。

### 默认配置

| 项目 | 默认值 |
| --- | --- |
| 端口 | 随机 50001-65535 |
| ASCII 模式 | `up_ascii_down_entropy`（可选） |
| AEAD | `chacha20-poly1305`（可选） |
| 自定义表 `custom_table` | 每次安装随机生成（X / P / V 排列） |
| 下行 | packed（`enable_pure_downlink: false`） |
| Padding | 服务端 2–7 |
| HTTP Mask | 启用 · `auto` · multiplex `on` · 随机路径前缀（客户端导出为 `httpmask.disable: true`） |
| WARP | `false` |
| 回落 | 内置 Cloudflare 风格 500 页 `127.0.0.1:10232`（失败回退 80 端口） |
| 客户端本地端口 | `10233` |
| 路径 | 配置 `/etc/sudoku/config.json` · 二进制 `/usr/local/bin/sudoku` · 服务 `sudoku`（WARP 模式为 `sudoku-sing-box`） |

### 支持的客户端

完整列表见 [Sudoku 官方仓库](https://github.com/SUDOKU-ASCII/sudoku)，推荐：

- **Android**：[官方 Sudodroid / CMFA](https://github.com/SUDOKU-ASCII/sudoku-android)
- **iOS**：[Anywhere](https://apps.apple.com/us/app/anywhere-proxy/id6758235178)（[GitHub](https://github.com/NodePassProject/Anywhere)）
- **桌面端**：[官方 sudoku-desktop](https://github.com/SUDOKU-ASCII/sudoku-desktop)

此外支持 OpenWrt（OpenClash）与 Mihomo（> v1.19.21）。分享链接 `sudoku://…` 可直接导入。

---

<a name="english"></a>
## English

### One-line install

Run as root on a Linux server (systemd, amd64 / arm64):

```bash
curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh -o /tmp/sudoku-dash.sh && sudo bash /tmp/sudoku-dash.sh
```

Just keep pressing Enter: **port** (default: random) → **AEAD** (default `chacha20-poly1305`) → **ASCII mode** (default `up_ascii_down_entropy`) → **enable WARP** (default: no). Everything else (random `custom_table`, packed downlink, HTTP mask `auto` + random path root, CF-style fallback page) uses defaults and is never asked. You get a `sudoku://` share link right away.

After installing, the script lives on as a repeatable management TUI, **`sudoku-dash`**:

```bash
sudo sudoku-dash
```

- **Live bandwidth**: server RX / TX rate, sparkline, totals and peaks, per-client-IP rates
- **Resource usage**: Sudoku CPU / RAM / connections / threads / FDs, system load
- **Users**: add / rate-limit / data-cap / block / delete users, one share link per user
- **Versions**: upgrade to latest, install any release or pre-release, automatic rollback on failure, manual rollback to a backup
- **Service / settings**: restart, stop, view and follow logs, change port, toggle WARP, change public host

> Non-interactive runs (`curl … | sudo bash`, CI) take the defaults and never prompt.

### Environment variables

All optional; put them before the command, e.g. `sudo SUDOKU_PORT=8443 SUDOKU_WARP=true bash /tmp/sudoku-dash.sh`. A variable you set is never asked about in the wizard.

| Variable | Default | Meaning |
| --- | --- | --- |
| `SUDOKU_PORT` | random 50001-65535 | Server listen port (**use this to customize the port**) |
| `SUDOKU_AEAD` | `chacha20-poly1305` | Cipher: `chacha20-poly1305` / `aes-128-gcm` / `none` |
| `SUDOKU_ASCII` | `up_ascii_down_entropy` | ASCII mode: `up_ascii_down_entropy` / `prefer_entropy` / `prefer_ascii` / `up_entropy_down_ascii` |
| `SUDOKU_WARP` | `false` | `true` = send all proxied traffic out through Cloudflare WARP (hides the VPS egress IP, unlocks geo-restrictions). Switches to [sudoku-sing-box](https://github.com/SUDOKU-ASCII/sudoku-sing-box); legacy name `SUDOKU_WARP_GOOGLE` still works |
| `SUDOKU_VERSION` | latest release | Sudoku release tag to install, e.g. `v0.5.1` |
| `SERVER_IP` | auto-detect | Public IP or domain written into share links |
| `SUDOKU_YES` | auto | `1` = never prompt; defaults to `1` without a TTY |
| `SUDOKU_LANG` | from `$LANG` | UI language: `zh` / `en` |
| `SUDOKU_CLIENT_PORT` | `10233` | Local proxy port in the exported client config |
| `SUDOKU_FALLBACK` | built-in CF-style 500 page | Fallback `host:port` for suspicious traffic; when customized it is never overridden |
| `SUDOKU_CF_FALLBACK` | `true` | `false` = skip the built-in fallback page, fall back to `127.0.0.1:80` |
| `SUDOKU_CF_FALLBACK_BIND` / `_PORT` / `_FALLBACK_PORT` / `_FORCE` | `127.0.0.1` / `10232` / `80` / `false` | Bind address, port, backup port of the built-in page, and whether to force-override `SUDOKU_FALLBACK` |
| `SUDOKU_HTTP_MASK` | `true` | HTTP mask on/off |
| `SUDOKU_HTTP_MASK_MODE` | `auto` | `auto` / `stream` / `poll` / `legacy` / `ws` |
| `SUDOKU_HTTP_MASK_TLS` | `false` | Use TLS for the HTTP mask |
| `SUDOKU_HTTP_MASK_HOST` | empty | Override the HTTP mask Host |
| `SUDOKU_HTTP_MASK_PATH_ROOT` | random 6-10 lowercase letters | Single path segment `[A-Za-z0-9_-]+` |
| `SUDOKU_HTTP_MASK_MULTIPLEX` | `on` | `off` / `auto` / `on` |
| `SUDOKU_SUBSCRIPTION_PATH` | `/etc/sudoku/subscription.yaml` | Output path of the generated Mihomo YAML |
| `SUDOKU_SUBSCRIPTION_NODE_NAME` | `sudoku` | Node name in the YAML |
| `SUDOKU_SUBSCRIPTION_TEMPLATE_URL` | built-in template | Custom Mihomo template (must contain `rule-providers:`) |
| `SUDOKU_REPO` | `SUDOKU-ASCII/sudoku` | Kernel repository |

**Custom port**

```bash
# at install time
curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh -o /tmp/sudoku-dash.sh && sudo SUDOKU_PORT=8443 bash /tmp/sudoku-dash.sh
# afterwards: sudo sudoku-dash → Settings → Change port (firewall and service are updated; clients need the new link)
```

**WARP**

```bash
# enable at install time
curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh -o /tmp/sudoku-dash.sh && sudo SUDOKU_WARP=true bash /tmp/sudoku-dash.sh
# toggle any time: sudo sudoku-dash → Settings → Enable / Disable WARP
```

### About user management

- User control relies on the kernel's `users` whitelist. The current release (v0.5.1) silently ignores it; you need **Sudoku ≥ 0.5.2** (merged upstream, not released yet) or WARP mode (the bundled sudoku-sing-box already supports it). On an unsupported kernel dash says so instead of pretending limits are active.
- Adding the first user also adds your install-time key as user `default`, so existing clients are not locked out.
- User changes need a service restart (dash offers to do it for you).
- The core does not expose per-user byte counters. The user list shows speed limits / data quota / state plus 24 h session counts derived from logs; live traffic is the aggregate RX / TX of the listening port.

### Upgrade / uninstall

```bash
# upgrade to the latest release (also refreshes dash):
sudo sudoku-dash --upgrade
# or in the TUI: sudo sudoku-dash → Versions (pick a version, roll back; a failing upgrade rolls back automatically)

# uninstall (interactive runs ask whether to also delete config and keys):
sudo sudoku-dash --uninstall
# when the script is not on the box:
curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh -o /tmp/sudoku-dash.sh
sudo bash /tmp/sudoku-dash.sh --uninstall
```

Other commands: `sudoku-dash status` (plain-text status), `sudoku-dash --help`.

> The short name `dash` is only linked when no `dash` exists (Debian/Ubuntu ship a shell with that name); `sudoku-dash` always works.

### Default configuration

| Item | Default |
| --- | --- |
| Port | random 50001-65535 |
| ASCII mode | `up_ascii_down_entropy` (selectable) |
| AEAD | `chacha20-poly1305` (selectable) |
| `custom_table` | random per install (X / P / V layout) |
| Downlink | packed (`enable_pure_downlink: false`) |
| Padding | server 2–7 |
| HTTP mask | enabled · `auto` · multiplex `on` · random path root (client export uses `httpmask.disable: true`) |
| WARP | `false` |
| Fallback | built-in Cloudflare-style 500 page on `127.0.0.1:10232` (port 80 as backup) |
| Client local port | `10233` |
| Paths | config `/etc/sudoku/config.json` · binary `/usr/local/bin/sudoku` · service `sudoku` (`sudoku-sing-box` in WARP mode) |

### Supported clients

See the [official Sudoku repo](https://github.com/SUDOKU-ASCII/sudoku) for the full list. Recommended:

- **Android**: [official Sudodroid / CMFA](https://github.com/SUDOKU-ASCII/sudoku-android)
- **iOS**: [Anywhere](https://apps.apple.com/us/app/anywhere-proxy/id6758235178) ([GitHub](https://github.com/NodePassProject/Anywhere))
- **Desktop**: [official sudoku-desktop](https://github.com/SUDOKU-ASCII/sudoku-desktop)

OpenWrt (OpenClash) and Mihomo (> v1.19.21) are supported too. The `sudoku://…` share link imports directly.
