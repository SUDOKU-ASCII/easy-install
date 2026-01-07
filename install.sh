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
#   SUDOKU_CLIENT_PORT - Client local proxy port used in exported short link (default: 10233)
#   SUDOKU_FALLBACK  - Fallback address (default: 127.0.0.1:80)
#   SUDOKU_CF_FALLBACK - Enable CF 500 error page fallback service (default: true)
#   SUDOKU_CF_FALLBACK_BIND - Bind address for CF fallback service (default: 127.0.0.1)
#   SUDOKU_CF_FALLBACK_PORT - Preferred port for CF fallback service (default: 10232)
#   SUDOKU_CF_FALLBACK_FALLBACK_PORT - Port to try when preferred port fails (default: 80)
#   SUDOKU_CF_FALLBACK_FORCE - Force override SUDOKU_FALLBACK when CF fallback starts (default: false)
#   SERVER_IP        - Override public host/IP used in short link & Clash config (default: auto-detect)
#   SUDOKU_HTTP_MASK - Enable HTTP mask (default: true)
#   SUDOKU_HTTP_MASK_MODE - HTTP mask mode: auto/stream/poll/legacy (default: auto)
#   SUDOKU_HTTP_MASK_TLS  - Use HTTPS in HTTP mask tunnel modes (default: false)
#   SUDOKU_HTTP_MASK_MULTIPLEX - HTTP mask mux: off/auto/on (default: on)
#   SUDOKU_HTTP_MASK_HOST - Override HTTP Host/SNI in tunnel modes (default: empty)
#

set -e

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration Defaults
# ═══════════════════════════════════════════════════════════════════════════════

SUDOKU_PORT="${SUDOKU_PORT:-10233}"
SUDOKU_CLIENT_PORT="${SUDOKU_CLIENT_PORT:-10233}"
DEFAULT_SUDOKU_FALLBACK="127.0.0.1:80"
SUDOKU_FALLBACK="${SUDOKU_FALLBACK:-${DEFAULT_SUDOKU_FALLBACK}}"
SUDOKU_REPO="${SUDOKU_REPO:-SUDOKU-ASCII/sudoku}"
SUDOKU_CF_FALLBACK="${SUDOKU_CF_FALLBACK:-true}"
SUDOKU_CF_FALLBACK_BIND="${SUDOKU_CF_FALLBACK_BIND:-127.0.0.1}"
SUDOKU_CF_FALLBACK_PORT="${SUDOKU_CF_FALLBACK_PORT:-10232}"
SUDOKU_CF_FALLBACK_FALLBACK_PORT="${SUDOKU_CF_FALLBACK_FALLBACK_PORT:-80}"
SUDOKU_CF_FALLBACK_FORCE="${SUDOKU_CF_FALLBACK_FORCE:-false}"
SUDOKU_CF_FALLBACK_REPO="${SUDOKU_CF_FALLBACK_REPO:-donlon/cloudflare-error-page}"
SUDOKU_CF_FALLBACK_BRANCH="${SUDOKU_CF_FALLBACK_BRANCH:-main}"
SUDOKU_HTTP_MASK="${SUDOKU_HTTP_MASK:-true}"
SUDOKU_HTTP_MASK_MODE="${SUDOKU_HTTP_MASK_MODE:-auto}"
SUDOKU_HTTP_MASK_TLS="${SUDOKU_HTTP_MASK_TLS:-false}"
SUDOKU_HTTP_MASK_MULTIPLEX="${SUDOKU_HTTP_MASK_MULTIPLEX:-on}"
SUDOKU_HTTP_MASK_HOST="${SUDOKU_HTTP_MASK_HOST:-}"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/sudoku"
SERVICE_NAME="sudoku"
FALLBACK_SERVICE_NAME="sudoku-fallback"
FALLBACK_LIB_DIR="/usr/local/lib/sudoku-fallback"
CUSTOM_TABLE=""
DISABLE_HTTP_MASK="false"
HTTP_MASK_MODE="auto"
HTTP_MASK_TLS="false"
HTTP_MASK_MULTIPLEX="on"
HTTP_MASK_HOST=""
CF_FALLBACK_ENABLED="true"
CF_FALLBACK_BIND="127.0.0.1"
CF_FALLBACK_PORT="10232"
CF_FALLBACK_PORT_FALLBACK="80"
CF_FALLBACK_FORCE="false"
PKG_MANAGER=""

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

is_valid_port() {
    local p="${1:-}"
    [[ "${p}" =~ ^[0-9]+$ ]] || return 1
    if ((p < 1 || p > 65535)); then
        return 1
    fi
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
    local cf_fallback_enabled
    local cf_fallback_force

    if ! http_mask_enabled=$(normalize_bool "${SUDOKU_HTTP_MASK}"); then
        error "Invalid SUDOKU_HTTP_MASK=${SUDOKU_HTTP_MASK} (expected true/false)"
    fi
    if ! http_mask_tls=$(normalize_bool "${SUDOKU_HTTP_MASK_TLS}"); then
        error "Invalid SUDOKU_HTTP_MASK_TLS=${SUDOKU_HTTP_MASK_TLS} (expected true/false)"
    fi
    if ! cf_fallback_enabled=$(normalize_bool "${SUDOKU_CF_FALLBACK}"); then
        error "Invalid SUDOKU_CF_FALLBACK=${SUDOKU_CF_FALLBACK} (expected true/false)"
    fi
    if ! cf_fallback_force=$(normalize_bool "${SUDOKU_CF_FALLBACK_FORCE}"); then
        error "Invalid SUDOKU_CF_FALLBACK_FORCE=${SUDOKU_CF_FALLBACK_FORCE} (expected true/false)"
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

    HTTP_MASK_MULTIPLEX=$(trim_space "${SUDOKU_HTTP_MASK_MULTIPLEX}")
    HTTP_MASK_MULTIPLEX=$(echo "${HTTP_MASK_MULTIPLEX}" | tr '[:upper:]' '[:lower:]')
    if [[ -z "${HTTP_MASK_MULTIPLEX}" ]]; then
        HTTP_MASK_MULTIPLEX="on"
    fi
    case "${HTTP_MASK_MULTIPLEX}" in
        off|auto|on) ;;
        *) error "Invalid SUDOKU_HTTP_MASK_MULTIPLEX=${SUDOKU_HTTP_MASK_MULTIPLEX} (expected off/auto/on)" ;;
    esac

    if [[ "${http_mask_enabled}" == "true" ]]; then
        DISABLE_HTTP_MASK="false"
    else
        DISABLE_HTTP_MASK="true"
    fi

    CF_FALLBACK_ENABLED="${cf_fallback_enabled}"
    CF_FALLBACK_FORCE="${cf_fallback_force}"
    CF_FALLBACK_BIND=$(trim_space "${SUDOKU_CF_FALLBACK_BIND}")
    if [[ -z "${CF_FALLBACK_BIND}" ]]; then
        CF_FALLBACK_BIND="127.0.0.1"
    fi
    CF_FALLBACK_PORT=$(trim_space "${SUDOKU_CF_FALLBACK_PORT}")
    CF_FALLBACK_PORT_FALLBACK=$(trim_space "${SUDOKU_CF_FALLBACK_FALLBACK_PORT}")
    if ! is_valid_port "${CF_FALLBACK_PORT}"; then
        error "Invalid SUDOKU_CF_FALLBACK_PORT=${SUDOKU_CF_FALLBACK_PORT} (expected 1-65535)"
    fi
    if ! is_valid_port "${CF_FALLBACK_PORT_FALLBACK}"; then
        error "Invalid SUDOKU_CF_FALLBACK_FALLBACK_PORT=${SUDOKU_CF_FALLBACK_FALLBACK_PORT} (expected 1-65535)"
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

build_http_url() {
    local host="${1:-}"
    local port="${2:-}"
    printf 'http://%s/' "$(join_host_port "${host}" "${port}")"
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

detect_pkg_manager() {
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v apk &> /dev/null; then
        PKG_MANAGER="apk"
    else
        PKG_MANAGER=""
        return 1
    fi
}

install_packages() {
    local pkgs=("$@")
    if [[ ${#pkgs[@]} -eq 0 ]]; then
        return 0
    fi

    if [[ -z "${PKG_MANAGER}" ]]; then
        detect_pkg_manager || error "Cannot install dependencies. Please install manually: ${pkgs[*]}"
    fi

    case "${PKG_MANAGER}" in
        apt)
            apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkgs[@]}"
            ;;
        yum)
            yum install -y -q "${pkgs[@]}"
            ;;
        dnf)
            dnf install -y -q "${pkgs[@]}"
            ;;
        apk)
            apk add --quiet "${pkgs[@]}"
            ;;
        *)
            error "Cannot install dependencies. Please install manually: ${pkgs[*]}"
            ;;
    esac
}

check_dependencies() {
    local missing=()
    
    for cmd in curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ "${CF_FALLBACK_ENABLED}" == "true" ]]; then
        if ! command -v python3 &> /dev/null; then
            missing+=("python3")
        fi
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        info "Installing missing dependencies: ${missing[*]}"
        install_packages "${missing[@]}"
    fi

    if [[ "${CF_FALLBACK_ENABLED}" == "true" ]]; then
        if ! python3 -c 'import jinja2' >/dev/null 2>&1; then
            info "Installing Python dependency: jinja2"
            detect_pkg_manager || error "Cannot install python dependency 'jinja2' automatically; please install it manually."
            case "${PKG_MANAGER}" in
                apt|yum|dnf) install_packages python3-jinja2 ;;
                apk) install_packages py3-jinja2 ;;
                *) error "Unsupported package manager for installing jinja2; please install it manually." ;;
            esac
        fi
    fi
    success "Dependencies satisfied"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Cloudflare 500 Error Page Fallback (for suspicious traffic fallback)
# ═══════════════════════════════════════════════════════════════════════════════

should_override_fallback_address() {
    if [[ "${CF_FALLBACK_FORCE}" == "true" ]]; then
        return 0
    fi
    [[ "${SUDOKU_FALLBACK}" == "${DEFAULT_SUDOKU_FALLBACK}" ]]
}

write_cf_fallback_server() {
    mkdir -p "${FALLBACK_LIB_DIR}"

    cat > "${FALLBACK_LIB_DIR}/server.py" << 'PY'
import argparse
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn


def _load_params(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=10232)
    parser.add_argument("--params", required=True)
    parser.add_argument("--lib-dir", required=True)
    args = parser.parse_args()

    sys.path.insert(0, args.lib_dir)
    from cloudflare_error_page import render as render_cf_error_page  # type: ignore

    base_params = _load_params(args.params)

    class Handler(BaseHTTPRequestHandler):
        def _write_page(self, method: str) -> None:
            params = dict(base_params)

            host = self.headers.get("Host")
            if host:
                host = host.split(":", 1)[0].strip()
                if host:
                    try:
                        host_status = dict(params.get("host_status") or {})
                        host_status["location"] = host
                        params["host_status"] = host_status
                    except Exception:
                        pass

            body = render_cf_error_page(params).encode("utf-8")
            self.send_response(500)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if method != "HEAD":
                self.wfile.write(body)

        def do_GET(self) -> None:  # noqa: N802
            self._write_page("GET")

        def do_HEAD(self) -> None:  # noqa: N802
            self._write_page("HEAD")

        def log_message(self, format: str, *args) -> None:  # noqa: A002
            return

    server = ThreadingHTTPServer((args.bind, args.port), Handler)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
}

download_cf_fallback_vendor() {
    mkdir -p "${FALLBACK_LIB_DIR}"
    local temp_dir tarball src_root
    temp_dir=$(mktemp -d)
    tarball="${temp_dir}/cf.tgz"

    local branches=("${SUDOKU_CF_FALLBACK_BRANCH}" "main" "master")
    local branch ok="false"
    for branch in "${branches[@]}"; do
        if [[ -z "${branch}" ]]; then
            continue
        fi
        if curl -fsSL "https://codeload.github.com/${SUDOKU_CF_FALLBACK_REPO}/tar.gz/refs/heads/${branch}" -o "${tarball}"; then
            ok="true"
            break
        fi
    done
    if [[ "${ok}" != "true" ]]; then
        rm -rf "${temp_dir}"
        return 1
    fi

    if ! tar -xzf "${tarball}" -C "${temp_dir}" >/dev/null 2>&1; then
        rm -rf "${temp_dir}"
        return 1
    fi

    src_root=$(find "${temp_dir}" -maxdepth 1 -type d -name 'cloudflare-error-page-*' | head -n 1)
    if [[ -z "${src_root}" ]]; then
        rm -rf "${temp_dir}"
        return 1
    fi

    rm -rf "${FALLBACK_LIB_DIR}/cloudflare_error_page"
    cp -R "${src_root}/cloudflare_error_page" "${FALLBACK_LIB_DIR}/"
    cp "${src_root}/examples/default.json" "${FALLBACK_LIB_DIR}/params.json"

    rm -rf "${temp_dir}"
    return 0
}

write_cf_fallback_service() {
    local bind="${1:-}"
    local port="${2:-}"
    local pybin
    pybin=$(command -v python3 2>/dev/null || true)
    if [[ -z "${pybin}" ]]; then
        return 1
    fi

    cat > "/etc/systemd/system/${FALLBACK_SERVICE_NAME}.service" << EOF
[Unit]
Description=Sudoku Cloudflare 500 Error Page Fallback
After=network.target

[Service]
Type=simple
ExecStart=${pybin} ${FALLBACK_LIB_DIR}/server.py --bind ${bind} --port ${port} --params ${FALLBACK_LIB_DIR}/params.json --lib-dir ${FALLBACK_LIB_DIR}
Restart=on-failure
RestartSec=2
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

start_cf_fallback_service() {
    local bind="${1:-}"
    local port="${2:-}"

    if ! command -v systemctl &> /dev/null; then
        return 1
    fi
    if [[ ! -f "${FALLBACK_LIB_DIR}/server.py" || ! -f "${FALLBACK_LIB_DIR}/params.json" || ! -d "${FALLBACK_LIB_DIR}/cloudflare_error_page" ]]; then
        return 1
    fi

    write_cf_fallback_service "${bind}" "${port}" || return 1
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
    systemctl restart "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || systemctl start "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
    sleep 1
    if ! systemctl is-active --quiet "${FALLBACK_SERVICE_NAME}"; then
        return 1
    fi

    local url http_code
    url=$(build_http_url "${bind}" "${port}")
    http_code=$(curl -sS -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null || true)
    [[ "${http_code}" == "500" ]]
}

setup_cf_fallback() {
    if [[ "${CF_FALLBACK_ENABLED}" != "true" ]]; then
        return 0
    fi

    info "Setting up Cloudflare 500 error page fallback (from ${SUDOKU_CF_FALLBACK_REPO})..."

    if ! download_cf_fallback_vendor; then
        warn "Failed to download ${SUDOKU_CF_FALLBACK_REPO}; using fallback_address=${SUDOKU_FALLBACK}"
        return 0
    fi

    write_cf_fallback_server

    local selected_port=""
    if start_cf_fallback_service "${CF_FALLBACK_BIND}" "${CF_FALLBACK_PORT}"; then
        selected_port="${CF_FALLBACK_PORT}"
    else
        warn "CF fallback service failed on ${CF_FALLBACK_BIND}:${CF_FALLBACK_PORT}; trying ${CF_FALLBACK_PORT_FALLBACK}"
        if start_cf_fallback_service "${CF_FALLBACK_BIND}" "${CF_FALLBACK_PORT_FALLBACK}"; then
            selected_port="${CF_FALLBACK_PORT_FALLBACK}"
        fi
    fi

    if [[ -z "${selected_port}" ]]; then
        warn "CF fallback service setup failed; using fallback_address=${SUDOKU_FALLBACK}"
        if command -v systemctl &> /dev/null; then
            systemctl stop "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
            systemctl disable "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
            rm -f "/etc/systemd/system/${FALLBACK_SERVICE_NAME}.service"
            systemctl daemon-reload >/dev/null 2>&1 || true
        fi
        return 0
    fi

    success "CF fallback page listening: $(join_host_port "${CF_FALLBACK_BIND}" "${selected_port}") (always returns HTTP 500)"

    if should_override_fallback_address; then
        SUDOKU_FALLBACK=$(join_host_port "${CF_FALLBACK_BIND}" "${selected_port}")
        success "Sudoku fallback_address -> ${SUDOKU_FALLBACK}"
    else
        info "Keeping user-provided SUDOKU_FALLBACK=${SUDOKU_FALLBACK}"
    fi
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
  "http_mask_multiplex": "${HTTP_MASK_MULTIPLEX}",
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
  "local_port": ${SUDOKU_CLIENT_PORT},
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
  "http_mask_multiplex": "${HTTP_MASK_MULTIPLEX}",
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
    local http_mask_yaml="true"
    if [[ "${DISABLE_HTTP_MASK}" == "true" ]]; then
        http_mask_yaml="false"
    fi

    local lines=(
        "# sudoku"
        "- name: sudoku"
        "  type: sudoku"
        "  server: \"${SERVER_IP}\""
        "  port: ${SUDOKU_PORT}"
        "  key: \"${AVAILABLE_PRIVATE_KEY}\""
        "  aead-method: chacha20-poly1305"
        "  padding-min: 2"
        "  padding-max: 7"
    )

    if [[ -n "${CUSTOM_TABLE:-}" ]]; then
        lines+=("  custom-table: ${CUSTOM_TABLE}")
    fi

    lines+=(
        "  table-type: prefer_entropy"
        "  http-mask: ${http_mask_yaml}"
        "  http-mask-mode: ${HTTP_MASK_MODE}"
        "  http-mask-tls: ${HTTP_MASK_TLS}"
        "  http-mask-multiplex: \"${HTTP_MASK_MULTIPLEX}\""
    )

    if [[ -n "${HTTP_MASK_HOST:-}" ]]; then
        lines+=("  http-mask-host: \"${HTTP_MASK_HOST}\"")
    fi

    lines+=("  enable-pure-downlink: false")

    CLASH_CONFIG=$(printf '%s\n' "${lines[@]}")
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

    systemctl stop "${FALLBACK_SERVICE_NAME}" 2>/dev/null || true
    systemctl disable "${FALLBACK_SERVICE_NAME}" 2>/dev/null || true
    rm -f "/etc/systemd/system/${FALLBACK_SERVICE_NAME}.service"
    systemctl daemon-reload
    
    rm -f "${INSTALL_DIR}/sudoku"
    rm -rf "${CONFIG_DIR}"
    rm -rf "${FALLBACK_LIB_DIR}"
    
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
    normalize_settings
    check_dependencies
    
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
    setup_cf_fallback
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
