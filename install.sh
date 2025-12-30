#!/bin/bash
#
# Sudoku Server One-Click Installation Script
# https://github.com/SUDOKU-ASCII/sudoku
#
# Usage:
#   sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh)"
#
# Environment Variables:
#   SUDOKU_PORT      - Server port (default: 10233)
#   SUDOKU_FALLBACK  - Fallback address (default: 127.0.0.1:80)
#   SERVER_IP        - Override public host/IP used in short link & Clash config (default: auto-detect)
#   SUDOKU_HTTP_MASK - Enable HTTP mask (default: true)
#   SUDOKU_HTTP_MASK_MODE - HTTP mask mode: auto/stream/poll/legacy (default: auto)
#   SUDOKU_HTTP_MASK_TLS  - Use HTTPS in HTTP mask tunnel modes (default: false)
#   SUDOKU_HTTP_MASK_HOST - Override HTTP Host/SNI in tunnel modes (default: empty)
#

set -e

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration Defaults
# ═══════════════════════════════════════════════════════════════════════════════

SUDOKU_PORT="${SUDOKU_PORT:-10233}"
SUDOKU_FALLBACK="${SUDOKU_FALLBACK:-127.0.0.1:80}"
SUDOKU_REPO="${SUDOKU_REPO:-SUDOKU-ASCII/sudoku}"
SUDOKU_HTTP_MASK="${SUDOKU_HTTP_MASK:-true}"
SUDOKU_HTTP_MASK_MODE="${SUDOKU_HTTP_MASK_MODE:-auto}"
SUDOKU_HTTP_MASK_TLS="${SUDOKU_HTTP_MASK_TLS:-false}"
SUDOKU_HTTP_MASK_HOST="${SUDOKU_HTTP_MASK_HOST:-}"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/sudoku"
SERVICE_NAME="sudoku"
CUSTOM_TABLE=""
DISABLE_HTTP_MASK="false"
HTTP_MASK_MODE="auto"
HTTP_MASK_TLS="false"
HTTP_MASK_HOST=""

# ═══════════════════════════════════════════════════════════════════════════════
# Color Output
# ═══════════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
  ███████╗██╗   ██╗██████╗  ██████╗ ██╗  ██╗██╗   ██╗
  ██╔════╝██║   ██║██╔══██╗██╔═══██╗██║ ██╔╝██║   ██║
  ███████╗██║   ██║██║  ██║██║   ██║█████╔╝ ██║   ██║
  ╚════██║██║   ██║██║  ██║██║   ██║██╔═██╗ ██║   ██║
  ███████║╚██████╔╝██████╔╝╚██████╔╝██║  ██╗╚██████╔╝
  ╚══════╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝
EOF
    echo -e "${NC}"
    echo -e "${BOLD}  One-Click Server Installation Script${NC}"
    echo ""
}

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ═══════════════════════════════════════════════════════════════════════════════
# Input Normalization
# ═══════════════════════════════════════════════════════════════════════════════

normalize_bool() {
    local raw="${1:-}"
    raw=$(echo "$raw" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    case "$raw" in
        1|true|yes|y|on) echo "true" ;;
        0|false|no|n|off) echo "false" ;;
        *) return 1 ;;
    esac
}

trim_space() {
    local s="${1:-}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

normalize_settings() {
    local http_mask_enabled
    local http_mask_tls

    if ! http_mask_enabled=$(normalize_bool "${SUDOKU_HTTP_MASK}"); then
        error "Invalid SUDOKU_HTTP_MASK=${SUDOKU_HTTP_MASK} (expected true/false)"
    fi
    if ! http_mask_tls=$(normalize_bool "${SUDOKU_HTTP_MASK_TLS}"); then
        error "Invalid SUDOKU_HTTP_MASK_TLS=${SUDOKU_HTTP_MASK_TLS} (expected true/false)"
    fi

    HTTP_MASK_MODE=$(trim_space "${SUDOKU_HTTP_MASK_MODE}")
    HTTP_MASK_MODE=$(echo "${HTTP_MASK_MODE}" | tr '[:upper:]' '[:lower:]')
    if [[ -z "${HTTP_MASK_MODE}" ]]; then
        HTTP_MASK_MODE="auto"
    fi
    case "${HTTP_MASK_MODE}" in
        auto|stream|poll|legacy) ;;
        *) error "Invalid SUDOKU_HTTP_MASK_MODE=${SUDOKU_HTTP_MASK_MODE} (expected auto/stream/poll/legacy)" ;;
    esac

    HTTP_MASK_HOST=$(trim_space "${SUDOKU_HTTP_MASK_HOST}")
    HTTP_MASK_TLS="${http_mask_tls}"

    if [[ "${http_mask_enabled}" == "true" ]]; then
        DISABLE_HTTP_MASK="false"
    else
        DISABLE_HTTP_MASK="true"
    fi
}

join_host_port() {
    local host="${1:-}"
    local port="${2:-}"
    if [[ -z "${host}" || -z "${port}" ]]; then
        return 1
    fi
    if [[ "${host}" == *:* && "${host}" != \[*\] ]]; then
        printf '[%s]:%s' "${host}" "${port}"
    else
        printf '%s:%s' "${host}" "${port}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# System Detection
# ═══════════════════════════════════════════════════════════════════════════════

detect_os() {
    if [[ "$(uname)" != "Linux" ]]; then
        error "This script only supports Linux servers."
    fi
    success "Operating system: Linux"
}

detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            error "Unsupported architecture: $arch"
            ;;
    esac
    success "Architecture: $ARCH"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
    success "Running as root"
}

check_dependencies() {
    local missing=()
    
    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        info "Installing missing dependencies: ${missing[*]}"
        if command -v apt-get &> /dev/null; then
            apt-get update -qq && apt-get install -y -qq "${missing[@]}"
        elif command -v yum &> /dev/null; then
            yum install -y -q "${missing[@]}"
        elif command -v dnf &> /dev/null; then
            dnf install -y -q "${missing[@]}"
        elif command -v apk &> /dev/null; then
            apk add --quiet "${missing[@]}"
        else
            error "Cannot install dependencies. Please install manually: ${missing[*]}"
        fi
    fi
    success "Dependencies satisfied"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Download Binary
# ═══════════════════════════════════════════════════════════════════════════════

get_latest_version() {
    local version
    # GitHub API is rate-limited; fall back to the releases/latest redirect when needed.
    version=$(
        curl -fsSL "https://api.github.com/repos/${SUDOKU_REPO}/releases/latest" 2>/dev/null \
            | jq -r '.tag_name' 2>/dev/null \
            || true
    )
    if [[ -z "$version" || "$version" == "null" ]]; then
        local url=""
        url=$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/${SUDOKU_REPO}/releases/latest" 2>/dev/null || true)
        version="${url##*/}"
    fi
    if [[ -z "$version" || "$version" == "null" ]]; then
        error "Failed to get latest version. Please check network connectivity."
    fi
    echo "$version"
}

download_binary() {
    local version="$1"
    local download_url="https://github.com/${SUDOKU_REPO}/releases/download/${version}/sudoku-linux-${ARCH}.tar.gz"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    info "Downloading Sudoku ${version} for linux-${ARCH}..."
    
    if ! curl -fsSL "$download_url" -o "${temp_dir}/sudoku.tar.gz"; then
        error "Failed to download binary from: $download_url"
    fi
    
    tar -xzf "${temp_dir}/sudoku.tar.gz" -C "${temp_dir}"
    
    # Install binary
    mv "${temp_dir}/sudoku" "${INSTALL_DIR}/sudoku"
    chmod +x "${INSTALL_DIR}/sudoku"
    
    rm -rf "${temp_dir}"
    success "Installed to ${INSTALL_DIR}/sudoku"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Update Kernel Only (Do Not Touch Config)
# ═══════════════════════════════════════════════════════════════════════════════

has_existing_install() {
    [[ -x "${INSTALL_DIR}/sudoku" ]] || [[ -f "${CONFIG_DIR}/config.json" ]] || \
        [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]] || \
        [[ -f "/lib/systemd/system/${SERVICE_NAME}.service" ]] || \
        [[ -f "/usr/lib/systemd/system/${SERVICE_NAME}.service" ]]
}

restart_service_if_present() {
    if ! command -v systemctl &> /dev/null; then
        warn "systemctl not found; please restart Sudoku manually if needed."
        return 0
    fi

    if [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" || -f "/lib/systemd/system/${SERVICE_NAME}.service" || -f "/usr/lib/systemd/system/${SERVICE_NAME}.service" ]]; then
        info "Restarting ${SERVICE_NAME} service..."
        systemctl daemon-reload > /dev/null 2>&1 || true
        systemctl restart "${SERVICE_NAME}" > /dev/null 2>&1 || systemctl start "${SERVICE_NAME}" > /dev/null 2>&1 || true
        sleep 2
        if systemctl is-active --quiet "${SERVICE_NAME}"; then
            success "Service restarted successfully"
        else
            warn "Service may have issues. Check: journalctl -u ${SERVICE_NAME}"
        fi
    else
        warn "Systemd service not found; skipped restart."
    fi
}

update_kernel_only() {
    echo ""
    warn "Existing installation detected. Updating binary only (config preserved)."
    if [[ -f "${CONFIG_DIR}/config.json" ]]; then
        info "Config preserved: ${CONFIG_DIR}/config.json"
    fi

    VERSION=$(get_latest_version)
    download_binary "$VERSION"
    restart_service_if_present
    success "Kernel update complete (${VERSION})"
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# Key Generation
# ═══════════════════════════════════════════════════════════════════════════════

generate_keypair() {
    info "Generating keypair..."
    
    local keygen_output
    keygen_output=$("${INSTALL_DIR}/sudoku" -keygen 2>&1)
    
    AVAILABLE_PRIVATE_KEY=$(echo "$keygen_output" | grep "Available Private Key:" | awk '{print $4}')
    MASTER_PUBLIC_KEY=$(echo "$keygen_output" | grep "Master Public Key:" | awk '{print $4}')
    
    if [[ -z "$AVAILABLE_PRIVATE_KEY" || -z "$MASTER_PUBLIC_KEY" ]]; then
        error "Failed to generate keypair"
    fi
    
    success "Keypair generated successfully"
}

# ═══════════════════════════════════════════════════════════════════════════════
# IP Detection
# ═══════════════════════════════════════════════════════════════════════════════

get_public_ip() {
    if [[ -n "${SERVER_IP:-}" ]]; then
        success "Public host: ${SERVER_IP}"
        return 0
    fi

    local ip=""
    local apis=(
        "https://api.ipify.org"
        "https://ifconfig.me"
        "https://icanhazip.com"
        "https://ipinfo.io/ip"
        "https://api.ip.sb/ip"
    )
    
    info "Detecting public IP address..."
    
    for api in "${apis[@]}"; do
        ip=$(curl -fsSL --connect-timeout 5 "$api" 2>/dev/null | tr -d '\n')
        if [[ -n "$ip" ]]; then
            # Basic IPv4 / IPv6 check (best effort).
            if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ || "$ip" =~ ^[0-9a-fA-F:]+$ ]]; then
                SERVER_IP="$ip"
                success "Public IP: $SERVER_IP"
                return 0
            fi
        fi
    done
    
    error "Failed to detect public IP. Please set SERVER_IP manually."
}

# ═══════════════════════════════════════════════════════════════════════════════
# X/P/V Custom Table (Sudoku v0.1.4+)
# ═══════════════════════════════════════════════════════════════════════════════

rand_uint32() {
    od -An -N4 -tu4 /dev/urandom 2>/dev/null | tr -d ' '
}

generate_xpv_table() {
    local chars=(x x p p v v v v)
    local i j tmp r

    for ((i=${#chars[@]}-1; i>0; i--)); do
        r=$(rand_uint32)
        if [[ -z "$r" ]]; then
            r=$RANDOM
        fi
        j=$((r % (i+1)))
        tmp="${chars[i]}"
        chars[i]="${chars[j]}"
        chars[j]="$tmp"
    done

    printf '%s' "${chars[@]}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

create_config() {
    info "Creating server configuration..."
    
    mkdir -p "$CONFIG_DIR"
    
    cat > "${CONFIG_DIR}/config.json" << EOF
{
  "mode": "server",
  "local_port": ${SUDOKU_PORT},
  "fallback_address": "${SUDOKU_FALLBACK}",
  "key": "${MASTER_PUBLIC_KEY}",
  "aead": "chacha20-poly1305",
  "suspicious_action": "fallback",
  "ascii": "prefer_entropy",
  "padding_min": 2,
  "padding_max": 7,
  "custom_table": "${CUSTOM_TABLE}",
  "enable_pure_downlink": false,
  "disable_http_mask": ${DISABLE_HTTP_MASK},
  "http_mask_mode": "${HTTP_MASK_MODE}",
  "http_mask_tls": ${HTTP_MASK_TLS},
  "http_mask_host": "${HTTP_MASK_HOST}"
}
EOF
    
    chmod 600 "${CONFIG_DIR}/config.json"
    success "Configuration saved to ${CONFIG_DIR}/config.json"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Firewall Configuration
# ═══════════════════════════════════════════════════════════════════════════════

configure_firewall() {
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            info "Configuring UFW firewall..."
            ufw allow "${SUDOKU_PORT}/tcp" > /dev/null 2>&1
            success "UFW: Opened port ${SUDOKU_PORT}/tcp"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            info "Configuring firewalld..."
            firewall-cmd --permanent --add-port="${SUDOKU_PORT}/tcp" > /dev/null 2>&1
            firewall-cmd --reload > /dev/null 2>&1
            success "firewalld: Opened port ${SUDOKU_PORT}/tcp"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Systemd Service
# ═══════════════════════════════════════════════════════════════════════════════

create_service() {
    info "Creating systemd service..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Sudoku Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/sudoku -c ${CONFIG_DIR}/config.json
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}" > /dev/null 2>&1
    systemctl start "${SERVICE_NAME}"
    
    sleep 2
    
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        success "Service started successfully"
    else
        warn "Service may have issues. Check: journalctl -u ${SERVICE_NAME}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Generate Short Link
# ═══════════════════════════════════════════════════════════════════════════════

generate_short_link() {
    info "Generating sudoku:// short link..."

    local temp_dir temp_cfg export_output
    temp_dir=$(mktemp -d)
    temp_cfg="${temp_dir}/client.json"
    local server_address
    server_address=$(join_host_port "${SERVER_IP}" "${SUDOKU_PORT}")

    cat > "${temp_cfg}" << EOF
{
  "mode": "client",
  "local_port": 1080,
  "server_address": "${server_address}",
  "key": "${AVAILABLE_PRIVATE_KEY}",
  "aead": "chacha20-poly1305",
  "ascii": "prefer_entropy",
  "padding_min": 5,
  "padding_max": 15,
  "custom_table": "${CUSTOM_TABLE}",
  "enable_pure_downlink": false,
  "disable_http_mask": ${DISABLE_HTTP_MASK},
  "http_mask_mode": "${HTTP_MASK_MODE}",
  "http_mask_tls": ${HTTP_MASK_TLS},
  "http_mask_host": "${HTTP_MASK_HOST}",
  "rule_urls": ["global"]
}
EOF

    export_output=$("${INSTALL_DIR}/sudoku" -c "${temp_cfg}" -export-link 2>/dev/null || true)
    SHORT_LINK=$(echo "${export_output}" | awk -F 'Short link: ' '/Short link: /{print $2; exit}')
    rm -rf "${temp_dir}"

    if [[ -z "${SHORT_LINK}" ]]; then
        error "Failed to generate short link"
    fi
    success "Short link generated"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Generate Clash Config
# ═══════════════════════════════════════════════════════════════════════════════

generate_clash_config() {
    local custom_table_yaml=""
    if [[ -n "${CUSTOM_TABLE:-}" ]]; then
        custom_table_yaml="  custom-table: ${CUSTOM_TABLE}"
    fi
    local http_mask_yaml="true"
    if [[ "${DISABLE_HTTP_MASK}" == "true" ]]; then
        http_mask_yaml="false"
    fi
    local http_mask_host_yaml=""
    if [[ -n "${HTTP_MASK_HOST:-}" ]]; then
        http_mask_host_yaml="  http-mask-host: \"${HTTP_MASK_HOST}\""
    fi
    CLASH_CONFIG=$(cat << EOF
# sudoku
- name: sudoku
  type: sudoku
  server: "${SERVER_IP}"
  port: ${SUDOKU_PORT}
  key: "${AVAILABLE_PRIVATE_KEY}"
  aead-method: chacha20-poly1305
  padding-min: 2
  padding-max: 7
${custom_table_yaml}
  table-type: prefer_entropy
  http-mask: ${http_mask_yaml}
  http-mask-mode: ${HTTP_MASK_MODE}
  http-mask-tls: ${HTTP_MASK_TLS}
${http_mask_host_yaml}
  enable-pure-downlink: false
EOF
)
}

# ═══════════════════════════════════════════════════════════════════════════════
# Output Results
# ═══════════════════════════════════════════════════════════════════════════════

print_results() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  Installation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}📱 Short Link (for sudoku client):${NC}"
    echo -e "${YELLOW}${SHORT_LINK}${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}📋 Clash/Mihomo Node Config:${NC}"
    echo -e "${YELLOW}${CLASH_CONFIG}${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}🔑 Keys (save these securely):${NC}"
    echo -e "  Client Key (Private): ${YELLOW}${AVAILABLE_PRIVATE_KEY}${NC}"
    echo -e "  Server Key (Public):  ${YELLOW}${MASTER_PUBLIC_KEY}${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}⚙️  Service Management:${NC}"
    echo -e "  Status:  ${YELLOW}systemctl status ${SERVICE_NAME}${NC}"
    echo -e "  Restart: ${YELLOW}systemctl restart ${SERVICE_NAME}${NC}"
    echo -e "  Logs:    ${YELLOW}journalctl -u ${SERVICE_NAME} -f${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}📂 Configuration:${NC}"
    echo -e "  Config file: ${YELLOW}${CONFIG_DIR}/config.json${NC}"
    echo -e "  Binary:      ${YELLOW}${INSTALL_DIR}/sudoku${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# Uninstall Function
# ═══════════════════════════════════════════════════════════════════════════════

uninstall() {
    echo -e "${RED}Uninstalling Sudoku...${NC}"
    
    systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload
    
    rm -f "${INSTALL_DIR}/sudoku"
    rm -rf "${CONFIG_DIR}"
    
    # Remove firewall rule
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        ufw delete allow "${SUDOKU_PORT}/tcp" > /dev/null 2>&1 || true
    fi
    
    echo -e "${GREEN}Uninstallation complete.${NC}"
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    # Handle uninstall
    if [[ "${1:-}" == "--uninstall" || "${1:-}" == "-u" ]]; then
        uninstall
    fi
    
    print_banner
    
    info "Starting installation..."
    echo ""
    
    # Pre-flight checks
    check_root
    detect_os
    detect_arch
    check_dependencies
    normalize_settings
    
    echo ""

    # If already installed, only update the binary (do not touch config)
    if has_existing_install; then
        update_kernel_only
    fi

    # Get latest version and download
    VERSION=$(get_latest_version)
    download_binary "$VERSION"
    
    # Generate keys and detect IP
    generate_keypair
    get_public_ip

    CUSTOM_TABLE=$(generate_xpv_table)
    success "Custom X/P/V table: ${CUSTOM_TABLE}"
    
    echo ""
    
    # Setup
    create_config
    configure_firewall
    create_service
    
    # Generate output
    generate_short_link
    generate_clash_config
    
    # Display results
    print_results
}

main "$@"
