#!/usr/bin/env bash
#
# Sudoku easy-install & dash
# One-click installer + a repeatable terminal TUI to manage your Sudoku server.
# https://github.com/SUDOKU-ASCII/easy-install
#
# Install (or open dash when already installed):
#   curl -fsSL https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh -o /tmp/sudoku-dash.sh && sudo bash /tmp/sudoku-dash.sh
# Afterwards, manage everything any time with:
#   sudo sudoku-dash
#
# Sub-commands (append after the script, e.g.  sudo bash /tmp/sudoku-dash.sh --upgrade):
#   install | dash | status | --upgrade | --uninstall | --help | --version
#
# SUDOKU-DASH-MARKER
#
# Environment variables (all optional):
#   SUDOKU_PORT          Server port (default: random free port in 50001-65535)
#   SUDOKU_AEAD          chacha20-poly1305 | aes-128-gcm | none (default: chacha20-poly1305)
#   SUDOKU_ASCII         up_ascii_down_entropy | prefer_entropy | prefer_ascii | up_entropy_down_ascii
#   SUDOKU_WARP          Route all proxied traffic through Cloudflare WARP (default: false)
#   SUDOKU_VERSION       Sudoku kernel tag to install (default: latest release)
#   SUDOKU_YES           1 = never prompt, accept defaults / env values (default: auto, no TTY => 1)
#   SUDOKU_LANG          UI language: zh | en (default: from $LANG)
#   SERVER_IP            Public host/IP written into share links (default: auto-detect)
#   SUDOKU_CLIENT_PORT   Local proxy port inside exported client config (default: 10233)
#   SUDOKU_FALLBACK      Fallback address for suspicious traffic (default: built-in Cloudflare-style 500 page)
#   SUDOKU_CF_FALLBACK   Run the built-in Cloudflare-style 500 page (default: true)
#   SUDOKU_HTTP_MASK, SUDOKU_HTTP_MASK_MODE, SUDOKU_HTTP_MASK_TLS, SUDOKU_HTTP_MASK_HOST,
#   SUDOKU_HTTP_MASK_PATH_ROOT, SUDOKU_HTTP_MASK_MULTIPLEX   Advanced HTTP-mask tuning
#   SUDOKU_SUBSCRIPTION_PATH / _NODE_NAME / _TEMPLATE_URL    Local Mihomo YAML output
#   SUDOKU_REPO          Override kernel repository (default: SUDOKU-ASCII/sudoku)
#

if [ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
    # Alpine ships only busybox ash: fetch bash once and re-run ourselves with it.
    if [ -z "${SUDOKU_BASH_REEXEC:-}" ] && [ -f "$0" ] && [ "$(id -u)" = "0" ] && command -v apk >/dev/null 2>&1; then
        echo "[*] installing bash (apk)..." >&2
        if apk add --no-cache bash >/dev/null 2>&1; then
            SUDOKU_BASH_REEXEC=1 exec bash "$0" "$@"
        fi
    fi
    echo "[x] bash >= 4 is required (found: ${BASH_VERSION:-none})." >&2
    exit 1
fi
shopt -s extglob
set -o pipefail
export PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

DASH_VERSION="1.0.0"

SUDOKU_PORT="${SUDOKU_PORT:-}"
SUDOKU_AEAD="${SUDOKU_AEAD:-}"
SUDOKU_ASCII="${SUDOKU_ASCII:-}"
SUDOKU_VERSION="${SUDOKU_VERSION:-}"
SUDOKU_CLIENT_PORT_INPUT="${SUDOKU_CLIENT_PORT:-}"
SUDOKU_CLIENT_PORT="${SUDOKU_CLIENT_PORT:-10233}"
DEFAULT_SUDOKU_FALLBACK="127.0.0.1:80"
SUDOKU_FALLBACK="${SUDOKU_FALLBACK:-${DEFAULT_SUDOKU_FALLBACK}}"
SUDOKU_REPO="${SUDOKU_REPO:-SUDOKU-ASCII/sudoku}"
SING_BOX_REPO="${SUDOKU_SING_BOX_REPO:-SUDOKU-ASCII/sudoku-sing-box}"
DASH_URL="${SUDOKU_DASH_URL:-https://raw.githubusercontent.com/SUDOKU-ASCII/easy-install/main/install.sh}"
SUDOKU_CF_FALLBACK="${SUDOKU_CF_FALLBACK:-true}"
SUDOKU_CF_FALLBACK_BIND="${SUDOKU_CF_FALLBACK_BIND:-127.0.0.1}"
SUDOKU_CF_FALLBACK_PORT="${SUDOKU_CF_FALLBACK_PORT:-10232}"
SUDOKU_CF_FALLBACK_FALLBACK_PORT="${SUDOKU_CF_FALLBACK_FALLBACK_PORT:-80}"
SUDOKU_CF_FALLBACK_FORCE="${SUDOKU_CF_FALLBACK_FORCE:-false}"
SUDOKU_HTTP_MASK="${SUDOKU_HTTP_MASK:-true}"
SUDOKU_HTTP_MASK_MODE="${SUDOKU_HTTP_MASK_MODE:-auto}"
SUDOKU_HTTP_MASK_TLS="${SUDOKU_HTTP_MASK_TLS:-false}"
SUDOKU_HTTP_MASK_MULTIPLEX="${SUDOKU_HTTP_MASK_MULTIPLEX:-on}"
SUDOKU_HTTP_MASK_HOST="${SUDOKU_HTTP_MASK_HOST:-}"
SUDOKU_HTTP_MASK_PATH_ROOT="${SUDOKU_HTTP_MASK_PATH_ROOT:-}"
SUDOKU_SUBSCRIPTION_PATH="${SUDOKU_SUBSCRIPTION_PATH:-}"
SUDOKU_SUBSCRIPTION_NODE_NAME="${SUDOKU_SUBSCRIPTION_NODE_NAME:-sudoku}"
SUDOKU_SUBSCRIPTION_TEMPLATE_URL="${SUDOKU_SUBSCRIPTION_TEMPLATE_URL:-}"
SUDOKU_WARP_PRESET="${SUDOKU_WARP+x}${SUDOKU_WARP_GOOGLE+x}"
SUDOKU_WARP="${SUDOKU_WARP:-${SUDOKU_WARP_GOOGLE:-false}}"

INSTALL_DIR="${SUDOKU_INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="${SUDOKU_CONFIG_DIR:-/etc/sudoku}"
SYSTEMD_DIR="${SUDOKU_SYSTEMD_DIR:-/etc/systemd/system}"
SYSTEMCTL="${SUDOKU_SYSTEMCTL:-systemctl}"
JOURNALCTL="${SUDOKU_JOURNALCTL:-journalctl}"
OPENRC_DIR="${SUDOKU_OPENRC_DIR:-/etc/init.d}"
LOG_DIR="${SUDOKU_LOG_DIR:-/var/log}"
INIT_SYSTEM="systemd"
CONFIG_FILE="${CONFIG_DIR}/config.json"
EXPORT_STATE_FILE="${CONFIG_DIR}/export-state.env"
VERSIONS_FILE="${CONFIG_DIR}/versions.env"
APPLIED_FILE="${CONFIG_DIR}/.applied"
BACKUP_DIR="${CONFIG_DIR}/backup"
DASH_BIN="${INSTALL_DIR}/sudoku-dash"
SERVICE_NAME="sudoku"
FALLBACK_SERVICE_NAME="sudoku-fallback"
FALLBACK_LIB_DIR="${SUDOKU_FALLBACK_LIB_DIR:-/usr/local/lib/sudoku-fallback}"
LEGACY_SUBSCRIPTION_SERVICE_NAME="sudoku-subscription"
LEGACY_SUBSCRIPTION_ACME_TIMER_NAME="sudoku-acme-renew.timer"
LEGACY_SUBSCRIPTION_LIB_DIR="/usr/local/lib/sudoku-subscription"
LEGACY_SUBSCRIPTION_CERT_DIR="${CONFIG_DIR}/subscription-cert"
SING_BOX_SERVICE_NAME="sudoku-sing-box"
SING_BOX_CONFIG_DIR="${SUDOKU_SING_BOX_CONFIG_DIR:-/etc/sing-box}"
SING_BOX_CONFIG_FILE="${SING_BOX_CONFIG_DIR}/sudoku-warp.json"
SING_BOX_CACHE_DIR="${SUDOKU_SING_BOX_CACHE_DIR:-/var/lib/sudoku-sing-box}"
SUDOKU_WARP_DIR="${CONFIG_DIR}/warp"
SUDOKU_WARP_PROFILE="${SUDOKU_WARP_DIR}/wgcf-profile.conf"
DEFAULT_ASCII_MODE="up_ascii_down_entropy"
DEFAULT_AEAD="chacha20-poly1305"
ASCII_MODE="${DEFAULT_ASCII_MODE}"
AEAD_METHOD="${DEFAULT_AEAD}"

CUSTOM_TABLE=""
DISABLE_HTTP_MASK="false"
HTTP_MASK_MODE="auto"
CLIENT_DISABLE_HTTP_MASK="true"
HTTP_MASK_TLS="false"
HTTP_MASK_MULTIPLEX="on"
HTTP_MASK_HOST=""
HTTP_MASK_PATH_ROOT=""
CF_FALLBACK_ENABLED="true"
CF_FALLBACK_BIND="127.0.0.1"
CF_FALLBACK_PORT="10232"
CF_FALLBACK_PORT_FALLBACK="80"
CF_FALLBACK_FORCE="false"
SUBSCRIPTION_NODE_NAME="sudoku"
SUBSCRIPTION_OUTPUT_FILE=""
SUBSCRIPTION_TEMPLATE_URL=""
NODE_YAML=""
SHORT_LINK=""
PKG_MANAGER=""
WARP_ENABLED="false"
AVAILABLE_PRIVATE_KEY=""
MASTER_PUBLIC_KEY=""
SERVER_IP="${SERVER_IP:-}"
ARCH=""
NONFATAL_ISSUES=()

# ═══════════════════════════════════════════════════════════════════════════════
# Locale / language / glyphs / colors
# ═══════════════════════════════════════════════════════════════════════════════

ORIG_LOCALE_HINT="${SUDOKU_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}"
UI_UTF8=0
UI_LANG="en"

setup_locale() {
    local cm l
    cm=$(locale charmap 2>/dev/null || true)
    if [[ "${cm}" != "UTF-8" ]]; then
        for l in C.UTF-8 en_US.UTF-8 C.utf8 en_US.utf8; do
            if LC_ALL="${l}" locale charmap 2>/dev/null | grep -qi 'utf-8'; then
                export LC_ALL="${l}"
                cm="UTF-8"
                break
            fi
        done
    fi
    if [[ "${cm}" == "UTF-8" ]]; then
        UI_UTF8=1
    fi

    case "${ORIG_LOCALE_HINT}" in
        zh*|ZH*|*zh_*|*zh-*) UI_LANG="zh" ;;
        *) UI_LANG="en" ;;
    esac
    # Chinese text needs a UTF-8 terminal; otherwise stay with English/ASCII.
    if [[ "${UI_UTF8}" != "1" ]]; then
        UI_LANG="en"
    fi
}

# L "中文" "English" -> prints the string for the current UI language.
L() {
    if [[ "${UI_LANG}" == "zh" ]]; then
        printf '%s' "$1"
    else
        printf '%s' "$2"
    fi
}

UI_TTY=0
if [[ -t 0 && -t 1 ]]; then
    UI_TTY=1
fi

setup_style() {
    if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]; then
        C_RESET=$'\033[0m'
        C_BOLD=$'\033[1m'
        C_DIM=$'\033[38;5;245m'
        C_ACC=$'\033[38;5;80m'
        C_OK=$'\033[38;5;78m'
        C_WARN=$'\033[38;5;221m'
        C_ERR=$'\033[38;5;203m'
       

    else
        C_RESET="" C_BOLD="" C_DIM="" C_ACC="" C_OK="" C_WARN="" C_ERR=""
    fi

    if [[ "${UI_UTF8}" == "1" ]]; then
        G_OK="✓" G_ERR="✗" G_WARN="!" G_INFO="•" G_PTR="❯" G_DOT="●" G_RING="○"
        G_H="─" G_V="│" G_TL="╭" G_TR="╮" G_BL="╰" G_BR="╯" G_ML="├" G_MR="┤"
        G_UP="↑" G_DN="↓"
        SPARK=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
        SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
    else
        G_OK="+" G_ERR="x" G_WARN="!" G_INFO="-" G_PTR=">" G_DOT="*" G_RING="o"
        G_H="-" G_V="|" G_TL="+" G_TR="+" G_BL="+" G_BR="+" G_ML="+" G_MR="+"
        G_UP="^" G_DN="v"
        SPARK=(_ . - '=' + '#' '#' '#')
        SPIN=('|' '/' '-' '\')
    fi

    if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
        ESC_T=0.05
    else
        ESC_T=1
    fi
}

setup_locale
setup_style

# ═══════════════════════════════════════════════════════════════════════════════
# Output helpers
# ═══════════════════════════════════════════════════════════════════════════════

info()  { printf '  %s%s%s %s\n' "${C_ACC}" "${G_INFO}" "${C_RESET}" "$*"; }
ok()    { printf '  %s%s%s %s\n' "${C_OK}" "${G_OK}" "${C_RESET}" "$*"; }
warn()  { printf '  %s%s%s %s\n' "${C_WARN}" "${G_WARN}" "${C_RESET}" "$*" >&2; }
err()   { printf '  %s%s%s %s\n' "${C_ERR}" "${G_ERR}" "${C_RESET}" "$*" >&2; }
die()   { ui_cursor_show; err "$*"; exit 1; }
dim()   { printf '%s%s%s\n' "${C_DIM}" "$*" "${C_RESET}"; }

record_nonfatal_issue() {
    local message="${1:-}"
    [[ -n "${message}" ]] || return 0
    NONFATAL_ISSUES+=("${message}")
    warn "${message}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# TUI primitives
# ═══════════════════════════════════════════════════════════════════════════════

UI_W=72
ui_measure() {
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    [[ "${cols}" =~ ^[0-9]+$ ]] || cols=80
    UI_W=$((cols > 76 ? 76 : cols))
    ((UI_W < 56)) && UI_W=56
    return 0
}

ui_cursor_show() { [[ "${UI_TTY}" == "1" ]] && printf '\033[?25h'; return 0; }
ui_cursor_hide() { [[ "${UI_TTY}" == "1" ]] && printf '\033[?25l'; return 0; }
ui_clear() { [[ "${UI_TTY}" == "1" ]] && printf '\033[H\033[2J\033[3J'; return 0; }

strip_ansi() {
    local s="${1-}"
    printf '%s' "${s//$'\033'\[+([0-9;?])[a-zA-Z]/}"
}

# Display width: CJK full-width characters count as 2 columns.
dispw() {
    local s i c cp w=0
    s=$(strip_ansi "${1-}")
    if ( LC_ALL=C; [[ "${s}" != *[^\ -~]* ]] ); then
        printf '%s' "${#s}"
        return 0
    fi
    for ((i = 0; i < ${#s}; i++)); do
        c="${s:i:1}"
        printf -v cp '%d' "'${c}"
        if ((cp >= 0x1100 && (cp <= 0x115f || (cp >= 0x2e80 && cp <= 0xa4cf) || (cp >= 0xac00 && cp <= 0xd7a3) || (cp >= 0xf900 && cp <= 0xfaff) || (cp >= 0xfe30 && cp <= 0xfe6f) || (cp >= 0xff00 && cp <= 0xff60) || (cp >= 0xffe0 && cp <= 0xffe6)))); then
            w=$((w + 2))
        else
            w=$((w + 1))
        fi
    done
    printf '%s' "${w}"
}

rep() { # rep <char> <count>
    local s
    ((${2} > 0)) || return 0
    printf -v s '%*s' "${2}" ''
    printf '%s' "${s// /${1}}"
}

pad_right() { # pad_right <text> <width>
    local w pad
    w=$(dispw "$1")
    pad=$((${2} - w))
    printf '%s' "$1"
    ((pad > 0)) && printf '%*s' "${pad}" ''
    return 0
}

box_top() { # box_top <title>
    local title="${1:-}" w
    ui_measure
    if [[ -n "${title}" ]]; then
        w=$(dispw "${title}")
        printf '%s%s%s%s %s%s%s %s%s%s\n' "${C_DIM}" "${G_TL}" "${G_H}" "${C_RESET}" "${C_BOLD}${C_ACC}" "${title}" "${C_RESET}" \
            "${C_DIM}" "$(rep "${G_H}" $((UI_W - 5 - w)))${G_TR}" "${C_RESET}"
    else
        printf '%s%s%s%s%s\n' "${C_DIM}" "${G_TL}" "$(rep "${G_H}" $((UI_W - 2)))" "${G_TR}" "${C_RESET}"
    fi
}
box_row() {
    local text="${1-}" w pad
    w=$(dispw "${text}")
    pad=$((UI_W - 4 - w))
    ((pad < 0)) && pad=0
    printf '%s%s%s %s%*s %s%s%s\n' "${C_DIM}" "${G_V}" "${C_RESET}" "${text}" "${pad}" '' "${C_DIM}" "${G_V}" "${C_RESET}"
}
box_sep() { printf '%s%s%s%s%s\n' "${C_DIM}" "${G_ML}" "$(rep "${G_H}" $((UI_W - 2)))" "${G_MR}" "${C_RESET}"; }
box_bottom() { printf '%s%s%s%s%s\n' "${C_DIM}" "${G_BL}" "$(rep "${G_H}" $((UI_W - 2)))" "${G_BR}" "${C_RESET}"; }

ui_logo() {
    ui_measure
    printf '%s' "${C_ACC}"
    cat << 'EOF'
  ███████╗██╗   ██╗██████╗  ██████╗ ██╗  ██╗██╗   ██╗
  ██╔════╝██║   ██║██╔══██╗██╔═══██╗██║ ██╔╝██║   ██║
  ███████╗██║   ██║██║  ██║██║   ██║█████╔╝ ██║   ██║
  ╚════██║██║   ██║██║  ██║██║   ██║██╔═██╗ ██║   ██║
  ███████║╚██████╔╝██████╔╝╚██████╔╝██║  ██╗╚██████╔╝
  ╚══════╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝
EOF
    printf '%s\n' "${C_RESET}"
}

ui_title() { # ui_title <text> : section heading
    printf '\n  %s%s%s\n  %s%s%s\n' "${C_BOLD}${C_ACC}" "$1" "${C_RESET}" "${C_DIM}" "$(rep "${G_H}" $(($(dispw "$1"))))" "${C_RESET}"
}

# ui_menu <item>... : arrow keys / j k / digits / Enter. Sets MENU_SEL (0-based, -1 = back).
MENU_SEL=-1
MENU_DEFAULT=0
ui_menu() {
    local n=$# sel="${MENU_DEFAULT:-0}" i key k2 idx
    local -a items=("$@")
    ((sel >= n)) && sel=0
    ui_cursor_hide
    while :; do
        for ((i = 0; i < n; i++)); do
            if ((i == sel)); then
                printf '\033[K  %s%s %s%s\n' "${C_ACC}${C_BOLD}" "${G_PTR}" "${items[i]}" "${C_RESET}"
            else
                printf '\033[K    %s\n' "${items[i]}"
            fi
        done
        IFS= read -rsn1 key || { MENU_SEL=-1; break; }
        case "${key}" in
            $'\033')
                k2=""
                IFS= read -rsn2 -t "${ESC_T}" k2 || true
                case "${k2}" in
                    '[A') sel=$(((sel + n - 1) % n)) ;;
                    '[B') sel=$(((sel + 1) % n)) ;;
                    '') MENU_SEL=-1; break ;;
                esac
                ;;
            k|K) sel=$(((sel + n - 1) % n)) ;;
            j|J) sel=$(((sel + 1) % n)) ;;
            '') MENU_SEL="${sel}"; break ;;
            [1-9])
                idx=$((key - 1))
                if ((idx < n)); then
                    MENU_SEL="${idx}"
                    break
                fi
                ;;
            q|Q) MENU_SEL=-1; break ;;
        esac
        printf '\033[%dA' "${n}"
    done
    ui_cursor_show
    MENU_DEFAULT=0
}

# ui_ask <prompt> <default> [validator] -> ASK_RESULT
ASK_RESULT=""
ui_ask() {
    local prompt="$1" def="${2-}" validator="${3:-}" ans hint=""
    [[ -n "${def}" ]] && hint=" ${C_DIM}[${def}]${C_RESET}"
    while :; do
        if [[ "${UI_TTY}" == "1" ]]; then
            IFS= read -e -r -p "  ${C_ACC}?${C_RESET} ${prompt}${hint} " ans || ans=""
        else
            ans=""
        fi
        ans=$(trim_space "${ans}")
        [[ -z "${ans}" ]] && ans="${def}"
        if [[ -z "${validator}" ]] || "${validator}" "${ans}"; then
            ASK_RESULT="${ans}"
            return 0
        fi
        err "$(L '输入无效，请重试。' 'Invalid input, please try again.')"
    done
}

# ui_confirm <prompt> <y|n default> -> 0 yes / 1 no
ui_confirm() {
    local prompt="$1" def="${2:-y}" ans hint
    if [[ "${def}" == "y" ]]; then hint="Y/n"; else hint="y/N"; fi
    if [[ "${UI_TTY}" != "1" || "${ASSUME_YES}" == "1" ]]; then
        [[ "${def}" == "y" ]]
        return $?
    fi
    while :; do
        IFS= read -r -p "  ${C_ACC}?${C_RESET} ${prompt} ${C_DIM}[${hint}]${C_RESET} " ans || ans=""
        ans=$(trim_space "${ans}")
        ans="${ans,,}"
        case "${ans}" in
            "") [[ "${def}" == "y" ]]; return $? ;;
            y|yes|是|好) return 0 ;;
            n|no|否|不) return 1 ;;
        esac
    done
}

ui_pause() {
    [[ "${UI_TTY}" == "1" ]] || return 0
    printf '\n  %s%s%s' "${C_DIM}" "$(L '按任意键继续…' 'Press any key to continue…')" "${C_RESET}"
    IFS= read -rsn1 _ || true
    printf '\n'
}

# ui_run <message> <command...> : run with a spinner, show output tail on failure.
UI_RUN_LOG=""
ui_run() {
    local msg="$1" pid rc i=0
    shift
    UI_RUN_LOG=$(mktemp)
    if [[ "${UI_TTY}" != "1" ]]; then
        info "${msg}"
        "$@" >"${UI_RUN_LOG}" 2>&1
        rc=$?
    else
        "$@" >"${UI_RUN_LOG}" 2>&1 &
        pid=$!
        ui_cursor_hide
        while kill -0 "${pid}" 2>/dev/null; do
            printf '\r\033[K  %s%s%s %s' "${C_ACC}" "${SPIN[i % ${#SPIN[@]}]}" "${C_RESET}" "${msg}"
            i=$((i + 1))
            sleep 0.1
        done
        wait "${pid}"
        rc=$?
        ui_cursor_show
        printf '\r\033[K'
    fi
    if ((rc == 0)); then
        ok "${msg}"
    else
        err "${msg}"
        if [[ -s "${UI_RUN_LOG}" ]]; then
            tail -n 12 "${UI_RUN_LOG}" | sed "s/^/      ${C_DIM}/; s/\$/${C_RESET}/" >&2
        fi
    fi
    return "${rc}"
}

ASSUME_YES="${SUDOKU_YES:-}"
if [[ -z "${ASSUME_YES}" ]]; then
    if [[ "${UI_TTY}" == "1" ]]; then ASSUME_YES=0; else ASSUME_YES=1; fi
fi
case "${ASSUME_YES}" in 1|true|yes|y|on) ASSUME_YES=1 ;; *) ASSUME_YES=0 ;; esac

# ═══════════════════════════════════════════════════════════════════════════════
# Small utilities
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
    ((p >= 1 && p <= 65535))
}

is_nonneg_number() { [[ "${1:-}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; }
is_optional_number() { [[ -z "${1:-}" ]] || is_nonneg_number "$1"; }
is_hex_key() { [[ "${1:-}" =~ ^[0-9a-fA-F]+$ ]] && { ((${#1} == 64 || ${#1} == 128)) || ((${#1} >= 8 && ${#1} <= 16)); }; }
is_optional_hex_key() { [[ -z "${1:-}" ]] || is_hex_key "$1"; }
is_alias() { [[ -n "${1:-}" && "${1}" != *[\"\\]* && ${#1} -le 32 ]] && [[ "${1}" != *[[:cntrl:]]* ]]; }
is_port_or_empty() { [[ -z "${1:-}" ]] || is_valid_port "$1"; }

trim_space() {
    local s="${1:-}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

random_uint32() {
    local value=""
    value=$(od -An -N4 -tu4 /dev/urandom 2>/dev/null | tr -d ' ')
    [[ -n "${value}" ]] || value=$RANDOM
    printf '%s' "${value}"
}

generate_random_path_root() {
    local alphabet="abcdefghijklmnopqrstuvwxyz"
    local length=$((6 + ($(random_uint32) % 5)))
    local output="" i idx
    for ((i = 0; i < length; i++)); do
        idx=$(($(random_uint32) % ${#alphabet}))
        output+="${alphabet:${idx}:1}"
    done
    printf '%s' "${output}"
}

is_tcp_port_in_use() {
    local port="${1:-}"
    is_valid_port "${port}" || return 1
    if command -v ss >/dev/null 2>&1; then
        ss -Hltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:|\\])${port}$"
        return $?
    fi
    if command -v netstat >/dev/null 2>&1; then
        netstat -ltn 2>/dev/null | awk 'NR > 2 {print $4}' | grep -Eq "(^|:|\\])${port}$"
        return $?
    fi
    if command -v lsof >/dev/null 2>&1; then
        lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
        return $?
    fi
    return 1
}

pick_random_high_port() {
    local port=""
    for _ in $(seq 1 128); do
        port=$((50001 + ($(random_uint32) % 15535)))
        if ! is_tcp_port_in_use "${port}"; then
            printf '%s' "${port}"
            return 0
        fi
    done
    die "Failed to find an available random port in 50001-65535"
}

join_host_port() {
    local host="${1:-}" port="${2:-}"
    [[ -n "${host}" && -n "${port}" ]] || return 1
    if [[ "${host}" == *:* && "${host}" != \[*\] ]]; then
        printf '[%s]:%s' "${host}" "${port}"
    else
        printf '%s:%s' "${host}" "${port}"
    fi
}

build_http_url() { printf 'http://%s/' "$(join_host_port "${1:-}" "${2:-}")"; }

extract_port_from_hostport() {
    local hp="${1:-}"
    [[ -n "${hp}" ]] || return 1
    if [[ "${hp}" == \[*\]:* ]]; then printf '%s' "${hp##*]:}"; return 0; fi
    printf '%s' "${hp##*:}"
}

extract_host_from_hostport() {
    local hp="${1:-}"
    [[ -n "${hp}" ]] || return 1
    if [[ "${hp}" == \[*\]:* ]]; then
        hp="${hp#[}"
        printf '%s' "${hp%%]:*}"
        return 0
    fi
    printf '%s' "${hp%:*}"
}

yaml_escape_double_quoted() {
    local value="${1-}"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    printf '%s' "${value}"
}

# fmt_bytes <bytes> -> "1.23 MB"
fmt_bytes() {
    local b="${1:-0}" unit=0 whole frac
    local -a units=(B KB MB GB TB PB)
    local scaled=$((b * 100))
    while ((scaled >= 102400 && unit < 5)); do
        scaled=$((scaled / 1024))
        unit=$((unit + 1))
    done
    if ((unit == 0)); then
        printf '%d B' "${b}"
        return 0
    fi
    whole=$((scaled / 100))
    frac=$((scaled % 100))
    printf '%d.%02d %s' "${whole}" "${frac}" "${units[unit]}"
}

# fmt_rate <bytes/sec> -> "1.23 MB/s"
fmt_rate() { printf '%s/s' "$(fmt_bytes "${1:-0}")"; }

# fmt_mbps <bytes/sec> -> "9.8 Mbps"
fmt_mbps() {
    local bits=$((${1:-0} * 8 * 10 / 1000000))
    printf '%d.%d Mbps' $((bits / 10)) $((bits % 10))
}

fmt_duration() { # seconds -> 3d 4h 5m
    local s="${1:-0}" d h m
    d=$((s / 86400)); h=$(((s % 86400) / 3600)); m=$(((s % 3600) / 60))
    if ((d > 0)); then printf '%dd %dh %dm' "${d}" "${h}" "${m}"
    elif ((h > 0)); then printf '%dh %dm' "${h}" "${m}"
    elif ((m > 0)); then printf '%dm %ds' "${m}" $((s % 60))
    else printf '%ds' "${s}"; fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Compatibility shims for helper functions reused from the previous installer
# ═══════════════════════════════════════════════════════════════════════════════

success() { ok "$@"; }
return_error() { err "$*"; return 1; }
error() { die "$@"; }

# ═══════════════════════════════════════════════════════════════════════════════
# Settings (environment variables -> validated globals), install-time only
# ═══════════════════════════════════════════════════════════════════════════════

normalize_settings() {
    local http_mask_enabled http_mask_tls cf_fallback_enabled cf_fallback_force warp_enabled

    http_mask_enabled=$(normalize_bool "${SUDOKU_HTTP_MASK}") || die "Invalid SUDOKU_HTTP_MASK=${SUDOKU_HTTP_MASK} (expected true/false)"
    http_mask_tls=$(normalize_bool "${SUDOKU_HTTP_MASK_TLS}") || die "Invalid SUDOKU_HTTP_MASK_TLS=${SUDOKU_HTTP_MASK_TLS} (expected true/false)"
    cf_fallback_enabled=$(normalize_bool "${SUDOKU_CF_FALLBACK}") || die "Invalid SUDOKU_CF_FALLBACK=${SUDOKU_CF_FALLBACK} (expected true/false)"
    cf_fallback_force=$(normalize_bool "${SUDOKU_CF_FALLBACK_FORCE}") || die "Invalid SUDOKU_CF_FALLBACK_FORCE=${SUDOKU_CF_FALLBACK_FORCE} (expected true/false)"
    warp_enabled=$(normalize_bool "${SUDOKU_WARP}") || die "Invalid SUDOKU_WARP=${SUDOKU_WARP} (expected true/false)"

    if [[ -n "${SUDOKU_AEAD}" ]]; then
        AEAD_METHOD=$(trim_space "${SUDOKU_AEAD}"); AEAD_METHOD="${AEAD_METHOD,,}"
        case "${AEAD_METHOD}" in
            chacha20-poly1305|aes-128-gcm|none) ;;
            *) die "Invalid SUDOKU_AEAD=${SUDOKU_AEAD} (expected chacha20-poly1305/aes-128-gcm/none)" ;;
        esac
    fi
    if [[ -n "${SUDOKU_ASCII}" ]]; then
        ASCII_MODE=$(trim_space "${SUDOKU_ASCII}"); ASCII_MODE="${ASCII_MODE,,}"
        case "${ASCII_MODE}" in
            prefer_entropy|prefer_ascii|up_ascii_down_entropy|up_entropy_down_ascii) ;;
            *) die "Invalid SUDOKU_ASCII=${SUDOKU_ASCII} (expected prefer_entropy/prefer_ascii/up_ascii_down_entropy/up_entropy_down_ascii)" ;;
        esac
    fi

    SUDOKU_PORT=$(trim_space "${SUDOKU_PORT}")
    if [[ -n "${SUDOKU_PORT}" ]] && ! is_valid_port "${SUDOKU_PORT}"; then
        die "Invalid SUDOKU_PORT=${SUDOKU_PORT} (expected 1-65535)"
    fi
    is_valid_port "${SUDOKU_CLIENT_PORT}" || die "Invalid SUDOKU_CLIENT_PORT=${SUDOKU_CLIENT_PORT} (expected 1-65535)"

    SUDOKU_FALLBACK=$(trim_space "${SUDOKU_FALLBACK}")
    [[ -n "${SUDOKU_FALLBACK}" ]] || die "Invalid SUDOKU_FALLBACK (expected host:port)"
    local fallback_host fallback_port
    fallback_port="${SUDOKU_FALLBACK##*:}"
    fallback_host="${SUDOKU_FALLBACK%:*}"
    if [[ -z "${fallback_host}" || -z "${fallback_port}" ]] || ! is_valid_port "${fallback_port}"; then
        die "Invalid SUDOKU_FALLBACK=${SUDOKU_FALLBACK} (expected host:port)"
    fi
    if [[ "${fallback_host}" == *:* && "${fallback_host}" != \[*\] ]]; then
        die "Invalid SUDOKU_FALLBACK=${SUDOKU_FALLBACK} (IPv6 must be in [::1]:port form)"
    fi

    HTTP_MASK_MODE=$(trim_space "${SUDOKU_HTTP_MASK_MODE}")
    HTTP_MASK_MODE="${HTTP_MASK_MODE,,}"
    [[ -n "${HTTP_MASK_MODE}" ]] || HTTP_MASK_MODE="auto"
    case "${HTTP_MASK_MODE}" in
        auto|stream|poll|legacy|ws) ;;
        *) die "Invalid SUDOKU_HTTP_MASK_MODE=${SUDOKU_HTTP_MASK_MODE} (expected auto/stream/poll/legacy/ws)" ;;
    esac

    HTTP_MASK_HOST=$(trim_space "${SUDOKU_HTTP_MASK_HOST}")
    HTTP_MASK_TLS="${http_mask_tls}"

    HTTP_MASK_PATH_ROOT=$(trim_space "${SUDOKU_HTTP_MASK_PATH_ROOT}")
    while [[ "${HTTP_MASK_PATH_ROOT}" == /* ]]; do HTTP_MASK_PATH_ROOT="${HTTP_MASK_PATH_ROOT#/}"; done
    while [[ "${HTTP_MASK_PATH_ROOT}" == */ ]]; do HTTP_MASK_PATH_ROOT="${HTTP_MASK_PATH_ROOT%/}"; done
    if [[ -n "${HTTP_MASK_PATH_ROOT}" && ! "${HTTP_MASK_PATH_ROOT}" =~ ^[A-Za-z0-9_-]+$ ]]; then
        die "Invalid SUDOKU_HTTP_MASK_PATH_ROOT=${SUDOKU_HTTP_MASK_PATH_ROOT} (expected single segment [A-Za-z0-9_-], e.g. aabbcc)"
    fi
    if [[ "${http_mask_enabled}" == "true" && -z "${HTTP_MASK_PATH_ROOT}" ]]; then
        HTTP_MASK_PATH_ROOT=$(generate_random_path_root)
    fi

    HTTP_MASK_MULTIPLEX=$(trim_space "${SUDOKU_HTTP_MASK_MULTIPLEX}")
    HTTP_MASK_MULTIPLEX="${HTTP_MASK_MULTIPLEX,,}"
    [[ -n "${HTTP_MASK_MULTIPLEX}" ]] || HTTP_MASK_MULTIPLEX="on"
    case "${HTTP_MASK_MULTIPLEX}" in
        off|auto|on) ;;
        *) die "Invalid SUDOKU_HTTP_MASK_MULTIPLEX=${SUDOKU_HTTP_MASK_MULTIPLEX} (expected off/auto/on)" ;;
    esac

    if [[ "${http_mask_enabled}" == "true" ]]; then DISABLE_HTTP_MASK="false"; else DISABLE_HTTP_MASK="true"; fi

    CF_FALLBACK_ENABLED="${cf_fallback_enabled}"
    CF_FALLBACK_FORCE="${cf_fallback_force}"
    WARP_ENABLED="${warp_enabled}"
    CF_FALLBACK_BIND=$(trim_space "${SUDOKU_CF_FALLBACK_BIND}")
    [[ -n "${CF_FALLBACK_BIND}" ]] || CF_FALLBACK_BIND="127.0.0.1"
    CF_FALLBACK_PORT=$(trim_space "${SUDOKU_CF_FALLBACK_PORT}")
    CF_FALLBACK_PORT_FALLBACK=$(trim_space "${SUDOKU_CF_FALLBACK_FALLBACK_PORT}")
    is_valid_port "${CF_FALLBACK_PORT}" || die "Invalid SUDOKU_CF_FALLBACK_PORT=${SUDOKU_CF_FALLBACK_PORT} (expected 1-65535)"
    is_valid_port "${CF_FALLBACK_PORT_FALLBACK}" || die "Invalid SUDOKU_CF_FALLBACK_FALLBACK_PORT=${SUDOKU_CF_FALLBACK_FALLBACK_PORT} (expected 1-65535)"

    SUBSCRIPTION_OUTPUT_FILE=$(trim_space "${SUDOKU_SUBSCRIPTION_PATH}")
    if [[ -z "${SUBSCRIPTION_OUTPUT_FILE}" ]]; then
        SUBSCRIPTION_OUTPUT_FILE="${CONFIG_DIR}/subscription.yaml"
    elif [[ "${SUBSCRIPTION_OUTPUT_FILE}" != /* ]]; then
        SUBSCRIPTION_OUTPUT_FILE="${CONFIG_DIR}/${SUBSCRIPTION_OUTPUT_FILE}"
    fi
    case "${SUBSCRIPTION_OUTPUT_FILE}" in
        *$'\n'*|*$'\r'*) die "Invalid SUDOKU_SUBSCRIPTION_PATH: path must be a single line" ;;
    esac
    case "${SUBSCRIPTION_OUTPUT_FILE}" in
        *.yaml|*.yml) ;;
        *) die "Invalid SUDOKU_SUBSCRIPTION_PATH=${SUDOKU_SUBSCRIPTION_PATH} (expected a .yaml or .yml file)" ;;
    esac

    SUBSCRIPTION_NODE_NAME=$(trim_space "${SUDOKU_SUBSCRIPTION_NODE_NAME}")
    [[ -n "${SUBSCRIPTION_NODE_NAME}" ]] || SUBSCRIPTION_NODE_NAME="sudoku"
    SUBSCRIPTION_TEMPLATE_URL=$(trim_space "${SUDOKU_SUBSCRIPTION_TEMPLATE_URL}")
}

# ═══════════════════════════════════════════════════════════════════════════════
# System detection & dependencies
# ═══════════════════════════════════════════════════════════════════════════════

dev_mode() { [[ "${SUDOKU_DEV:-}" == "1" ]]; }

# ── Init system abstraction: systemd (default) or OpenRC (Alpine). ───────────────
# On OpenRC, SYSTEMCTL / JOURNALCTL point at small shims so the rest of the script
# keeps speaking "systemctl" and "journalctl".
openrc_ctl() { # systemctl-style verbs mapped onto rc-service / rc-update
    local verb="${1:-}" name
    shift || true
    case "${verb}" in
        daemon-reload|reset-failed) return 0 ;;
        enable) rc-update add "$1" default >/dev/null 2>&1 ;;
        disable) rc-update del "$1" default >/dev/null 2>&1 || true ;;
        start|stop|restart) rc-service "$1" "${verb}" >/dev/null ;;
        is-active)
            [[ "${1:-}" == "--quiet" ]] && shift
            rc-service "$1" status >/dev/null 2>&1
            ;;
        show) # show -p MainPID --value <name>
            name="${*: -1}"
            cat "/run/${name}.pid" 2>/dev/null || echo 0
            ;;
        *) return 0 ;;
    esac
}

openrc_logs() { # journalctl-style: -u <name> [-n N] [-f] [--since X] [-o X] [--no-pager]
    local name="" n=50 follow=0 since=0 file
    while (($# > 0)); do
        case "$1" in
            -u) name="${2:-}"; shift ;;
            -n) n="${2:-50}"; shift ;;
            -f) follow=1 ;;
            --since) since=1; shift ;;
            -o) shift ;;
        esac
        shift
    done
    file="${LOG_DIR}/${name}.log"
    [[ -f "${file}" ]] || return 0
    if ((follow)); then tail -n "${n}" -f "${file}"
    elif ((since)); then tail -n 20000 "${file}"
    else tail -n "${n}" "${file}"; fi
}

init_is_openrc() { [[ "${INIT_SYSTEM}" == "openrc" ]]; }

case "${SUDOKU_INIT:-auto}" in
    openrc) INIT_SYSTEM="openrc" ;;
    auto) if [[ -z "${SUDOKU_SYSTEMCTL:-}" && ! -d /run/systemd/system ]] && command -v rc-service >/dev/null 2>&1; then INIT_SYSTEM="openrc"; fi ;;
esac
if init_is_openrc; then
    SYSTEMCTL="openrc_ctl"
    JOURNALCTL="openrc_logs"
fi

unit_path() { # <service-name>
    if init_is_openrc; then printf '%s/%s' "${OPENRC_DIR}" "$1"; else printf '%s/%s.service' "${SYSTEMD_DIR}" "$1"; fi
}

# <name> <description> <command> <args> [workdir]  -> OpenRC init script (+ logrotate when available)
write_openrc_unit() {
    local name="$1" desc="$2" cmd="$3" args="$4" dir="${5:-}"
    mkdir -p "${OPENRC_DIR}" "${LOG_DIR}"
    {
        echo '#!/sbin/openrc-run'
        printf 'description="%s"\n' "${desc}"
        printf 'command="%s"\n' "${cmd}"
        printf 'command_args="%s"\n' "${args}"
        echo 'command_background=true'
        echo 'pidfile="/run/${RC_SVCNAME}.pid"'
        printf 'output_log="%s/%s.log"\n' "${LOG_DIR}" "${name}"
        printf 'error_log="%s/%s.log"\n' "${LOG_DIR}" "${name}"
        [[ -n "${dir}" ]] && printf 'directory="%s"\n' "${dir}"
        printf '\ndepend() {\n    use net\n    after firewall\n}\n'
    } >"${OPENRC_DIR}/${name}"
    chmod 755 "${OPENRC_DIR}/${name}"
    if [[ -d /etc/logrotate.d ]]; then
        printf '%s/%s.log {\n    weekly\n    rotate 2\n    compress\n    missingok\n    notifempty\n    copytruncate\n}\n' "${LOG_DIR}" "${name}" >"/etc/logrotate.d/${name}"
    fi
}

detect_os() {
    if [[ "$(uname)" != "Linux" ]] && ! dev_mode; then
        die "$(L '此脚本仅支持 Linux 服务器。' 'This script only supports Linux servers.')"
    fi
}

# SELinux: files moved from /tmp keep their temporary label, and systemd then
# refuses to exec / read them on enforcing hosts (RHEL, Rocky, Alma, Fedora…).
# Restore the default contexts right before anything is (re)started.
SELINUX_ACTIVE=""
selinux_active() {
    if [[ -z "${SELINUX_ACTIVE}" ]]; then
        SELINUX_ACTIVE=0
        if dev_mode; then :
        elif command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled >/dev/null 2>&1; then SELINUX_ACTIVE=1
        elif command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce 2>/dev/null)" =~ ^(Enforcing|Permissive)$ ]]; then SELINUX_ACTIVE=1
        fi
    fi
    ((SELINUX_ACTIVE == 1))
}

selinux_restore() {
    selinux_active || return 0
    if ! command -v restorecon >/dev/null 2>&1; then
        warn "$(L 'SELinux 已启用但缺少 restorecon，服务可能被策略拒绝（请安装 policycoreutils）。' 'SELinux is on but restorecon is missing; services may be denied (install policycoreutils).')"
        SELINUX_ACTIVE=0
        return 0
    fi
    local path
    for path in "${INSTALL_DIR}/sudoku" "${INSTALL_DIR}/sudoku-sing-box" "${INSTALL_DIR}/wgcf" "${INSTALL_DIR}/sudoku-dash" \
        "${CONFIG_DIR}" "${SING_BOX_CONFIG_DIR}" "${SING_BOX_CACHE_DIR}" "${FALLBACK_LIB_DIR}" \
        "${SYSTEMD_DIR}/${SERVICE_NAME}.service" "${SYSTEMD_DIR}/${SING_BOX_SERVICE_NAME}.service" "${SYSTEMD_DIR}/${FALLBACK_SERVICE_NAME}.service"; do
        [[ -e "${path}" || -L "${path}" ]] || continue
        restorecon -RF "${path}" >/dev/null 2>&1 || true
    done
}

detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) die "Unsupported architecture: $arch" ;;
    esac
}

ensure_root() {
    dev_mode && return 0
    [[ $EUID -eq 0 ]] && return 0
    if [[ -f "${0}" && -r "${0}" ]] && command -v sudo >/dev/null 2>&1; then
        exec sudo -E bash "${0}" "$@"
    fi
    die "$(L '请使用 root 权限运行（sudo bash install.sh）。' 'Please run as root (use sudo).')"
}

detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then PKG_MANAGER="dnf"
    elif command -v yum &>/dev/null; then PKG_MANAGER="yum"
    elif command -v apk &>/dev/null; then PKG_MANAGER="apk"
    else PKG_MANAGER=""; return 1; fi
}

install_packages() {
    local pkgs=("$@")
    ((${#pkgs[@]} > 0)) || return 0
    [[ -n "${PKG_MANAGER}" ]] || detect_pkg_manager || { echo "Cannot install dependencies. Please install manually: ${pkgs[*]}" >&2; return 1; }
    case "${PKG_MANAGER}" in
        apt) apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkgs[@]}" ;;
        yum) yum install -y -q "${pkgs[@]}" ;;
        dnf) dnf install -y -q "${pkgs[@]}" ;;
        apk) apk add --quiet "${pkgs[@]}" ;;
        *) echo "Cannot install dependencies. Please install manually: ${pkgs[*]}" >&2; return 1 ;;
    esac
}

install_missing_deps() {
    local missing=() cmd
    for cmd in curl jq python3 openssl; do
        command -v "${cmd}" &>/dev/null || missing+=("${cmd}")
    done
    if ! command -v ss &>/dev/null; then
        detect_pkg_manager >/dev/null 2>&1 || true
        case "${PKG_MANAGER}" in
            apt|apk) missing+=(iproute2) ;;
            yum|dnf) missing+=(iproute) ;;
        esac
    fi
    if [[ -z "${PKG_MANAGER}" ]]; then detect_pkg_manager >/dev/null 2>&1 || true; fi
    if [[ "${PKG_MANAGER}" == "apk" && ! -s /etc/ssl/certs/ca-certificates.crt ]]; then missing+=(ca-certificates); fi
    ((${#missing[@]} == 0)) && return 0
    install_packages "${missing[@]}"
}

check_dependencies() {
    local missing=() cmd
    for cmd in curl jq python3 openssl; do
        command -v "${cmd}" &>/dev/null || missing+=("${cmd}")
    done
    if ((${#missing[@]} > 0)) || ! command -v ss &>/dev/null || { command -v apk >/dev/null 2>&1 && [[ ! -s /etc/ssl/certs/ca-certificates.crt ]]; }; then
        ui_run "$(L "安装依赖: ${missing[*]:-iproute2}" "Installing dependencies: ${missing[*]:-iproute2}")" install_missing_deps \
            || die "$(L '依赖安装失败，请手动安装 curl jq python3 openssl。' 'Dependency installation failed; install curl jq python3 openssl manually.')"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Versions file, GitHub releases, binary installation
# ═══════════════════════════════════════════════════════════════════════════════

ver_get() {
    [[ -f "${VERSIONS_FILE}" ]] || return 0
    sed -n "s/^${1}=//p" "${VERSIONS_FILE}" | tail -n 1
}

ver_set() {
    local key="$1" value="$2" tmp
    mkdir -p "${CONFIG_DIR}"
    tmp=$(mktemp)
    [[ -f "${VERSIONS_FILE}" ]] && grep -v "^${key}=" "${VERSIONS_FILE}" >"${tmp}" || true
    printf '%s=%s\n' "${key}" "${value}" >>"${tmp}"
    mv "${tmp}" "${VERSIONS_FILE}"
    chmod 600 "${VERSIONS_FILE}"
}

gh_api() {
    curl -fsSL --connect-timeout 8 --max-time 25 -H 'Accept: application/vnd.github+json' \
        ${GITHUB_TOKEN:+-H "Authorization: Bearer ${GITHUB_TOKEN}"} "https://api.github.com/$1"
}

get_latest_tag() { # <repo>
    local repo="$1" tag="" url=""
    tag=$(gh_api "repos/${repo}/releases/latest" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null || true)
    if [[ -z "${tag}" ]]; then
        url=$(curl -fsSL --connect-timeout 8 -o /dev/null -w '%{url_effective}' "https://github.com/${repo}/releases/latest" 2>/dev/null || true)
        tag="${url##*/}"
        [[ "${tag}" == "latest" ]] && tag=""
    fi
    [[ -n "${tag}" && "${tag}" != "null" ]] || return 1
    printf '%s' "${tag}"
}

list_release_tags() { # <repo> [count] -> "tag|prerelease|date"
    gh_api "repos/${1}/releases?per_page=${2:-12}" | jq -r '.[] | "\(.tag_name)|\(.prerelease)|\(.published_at[0:10])"'
}

latest_github_asset_url() { # <repo> <regex> [tag]
    local repo="${1:-}" pattern="${2:-}" tag="${3:-}" path
    [[ -n "${repo}" && -n "${pattern}" ]] || return 1
    if [[ -n "${tag}" ]]; then path="releases/tags/${tag}"; else path="releases/latest"; fi
    local url
    url=$(gh_api "repos/${repo}/${path}" | jq -r --arg pattern "${pattern}" '.assets[] | select(.name | test($pattern)) | .browser_download_url' | head -n 1)
    [[ -n "${url}" && "${url}" != "null" ]] || return 1
    printf '%s' "${url}"
}

backup_binary() { # <name> <version-key>
    local name="$1" ver
    [[ -x "${INSTALL_DIR}/${name}" ]] || return 0
    ver=$(ver_get "$2")
    ver="${ver:-unknown}"
    mkdir -p "${BACKUP_DIR}"
    cp -p "${INSTALL_DIR}/${name}" "${BACKUP_DIR}/${name}@${ver}@$(date +%Y%m%d%H%M%S)"
    # Keep the three most recent backups per binary.
    local old
    while IFS= read -r old; do
        [[ -n "${old}" ]] && rm -f "${old}"
    done < <(ls -1t "${BACKUP_DIR}/${name}@"* 2>/dev/null | tail -n +4)
}

# Download, smoke-test and atomically install an archive containing <binary_name>.
# install_from_archive <url> <binary_name> <dest_name> <version-key> <tag>
install_from_archive() {
    local url="$1" bin_name="$2" dest="$3" vkey="$4" tag="$5" tmp bin rc
    tmp=$(mktemp -d)
    if ! curl -fsSL --connect-timeout 10 "${url}" -o "${tmp}/pkg.tgz"; then
        echo "download failed: ${url}" >&2
        rm -rf "${tmp}"
        return 1
    fi
    if ! tar -xzf "${tmp}/pkg.tgz" -C "${tmp}"; then
        echo "archive is corrupt: ${url}" >&2
        rm -rf "${tmp}"
        return 1
    fi
    bin=$(find "${tmp}" -type f -name "${bin_name}" | head -n 1)
    if [[ -z "${bin}" ]]; then
        echo "archive does not contain a '${bin_name}' binary" >&2
        rm -rf "${tmp}"
        return 1
    fi
    chmod 755 "${bin}"
    "${bin}" -h >/dev/null 2>&1 </dev/null
    rc=$?
    if ((rc == 126 || rc == 127)) && ! dev_mode; then
        echo "downloaded binary cannot run on this system (exit ${rc})" >&2
        rm -rf "${tmp}"
        return 1
    fi
    mkdir -p "${INSTALL_DIR}"
    backup_binary "${dest}" "${vkey}"
    cp "${bin}" "${INSTALL_DIR}/${dest}.new"
    chmod 755 "${INSTALL_DIR}/${dest}.new"
    mv -f "${INSTALL_DIR}/${dest}.new" "${INSTALL_DIR}/${dest}"
    ver_set "${vkey}" "${tag}"
    rm -rf "${tmp}"
}

install_sudoku_kernel() { # <tag>
    install_from_archive "https://github.com/${SUDOKU_REPO}/releases/download/${1}/sudoku-linux-${ARCH}.tar.gz" \
        sudoku sudoku SUDOKU_VERSION "$1"
}

install_sing_box_kernel() { # [tag]
    local tag="${1:-}" url
    [[ -n "${tag}" ]] || tag=$(get_latest_tag "${SING_BOX_REPO}") || { echo "cannot resolve latest sudoku-sing-box release" >&2; return 1; }
    url=$(latest_github_asset_url "${SING_BOX_REPO}" "^sing-box-.*-linux-${ARCH}\\.tar\\.gz\$" "${tag}") \
        || { echo "no linux-${ARCH} asset in ${SING_BOX_REPO} ${tag}" >&2; return 1; }
    install_from_archive "${url}" sing-box sudoku-sing-box SING_BOX_VERSION "${tag}"
}

ensure_wgcf_binary() {
    command -v wgcf >/dev/null 2>&1 && return 0
    local url temp_file
    url=$(latest_github_asset_url "ViRb3/wgcf" "^wgcf_.*_linux_${ARCH}\$") || { echo "Failed to find wgcf linux-${ARCH} release asset" >&2; return 1; }
    temp_file=$(mktemp)
    if ! curl -fsSL "${url}" -o "${temp_file}"; then
        rm -f "${temp_file}"
        echo "Failed to download wgcf from: ${url}" >&2
        return 1
    fi
    mv "${temp_file}" "${INSTALL_DIR}/wgcf"
    chmod 755 "${INSTALL_DIR}/wgcf"
    ver_set WGCF_INSTALLED 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# Install state, config context, services
# ═══════════════════════════════════════════════════════════════════════════════

service_file_exists() { # <name>
    [[ -f "${SYSTEMD_DIR}/${1}.service" || -f "${OPENRC_DIR}/${1}" || -f "/lib/systemd/system/${1}.service" || -f "/usr/lib/systemd/system/${1}.service" ]]
}

has_existing_install() {
    [[ -x "${INSTALL_DIR}/sudoku" || -f "${CONFIG_FILE}" ]] || service_file_exists "${SERVICE_NAME}" || service_file_exists "${SING_BOX_SERVICE_NAME}"
}

detect_mode() {
    if service_file_exists "${SING_BOX_SERVICE_NAME}" && [[ -f "${SING_BOX_CONFIG_FILE}" ]]; then
        WARP_ENABLED="true"
    else
        WARP_ENABLED="false"
    fi
}

svc_name() { if [[ "${WARP_ENABLED}" == "true" ]]; then printf '%s' "${SING_BOX_SERVICE_NAME}"; else printf '%s' "${SERVICE_NAME}"; fi; }
core_bin_name() { if [[ "${WARP_ENABLED}" == "true" ]]; then printf 'sudoku-sing-box'; else printf 'sudoku'; fi; }
have_systemctl() { command -v "${SYSTEMCTL}" >/dev/null 2>&1; }
svc_is_active() { have_systemctl && "${SYSTEMCTL}" is-active --quiet "${1:-$(svc_name)}" 2>/dev/null; }
svc_pid() {
    local pid
    pid=$("${SYSTEMCTL}" show -p MainPID --value "${1:-$(svc_name)}" 2>/dev/null || true)
    [[ "${pid}" =~ ^[0-9]+$ && "${pid}" != "0" ]] && printf '%s' "${pid}"
}

wait_for_port() { # <port> [attempts]
    local port="$1" attempts="${2:-10}" i
    for ((i = 0; i < attempts; i++)); do
        is_tcp_port_in_use "${port}" && return 0
        sleep 1
    done
    return 1
}

cfg_get() { jq -r "${1} // empty" "${CONFIG_FILE}" 2>/dev/null; }

load_existing_config_context() {
    [[ -f "${CONFIG_FILE}" ]] || return 1
    local v
    v=$(cfg_get .local_port); is_valid_port "${v}" && SUDOKU_PORT="${v}"
    v=$(cfg_get .key); [[ -n "${v}" ]] && MASTER_PUBLIC_KEY="${v}"
    v=$(cfg_get .custom_table); [[ -n "${v}" ]] && CUSTOM_TABLE="${v}"
    v=$(cfg_get .aead); [[ -n "${v}" ]] && AEAD_METHOD="${v}"
    v=$(cfg_get .ascii); [[ -n "${v}" ]] && ASCII_MODE="${v}"
    v=$(cfg_get .fallback_address); [[ -n "${v}" ]] && SUDOKU_FALLBACK="${v}"
    v=$(cfg_get .httpmask.disable); [[ -n "${v}" ]] && DISABLE_HTTP_MASK="${v}"
    v=$(cfg_get .httpmask.mode); [[ -n "${v}" ]] && HTTP_MASK_MODE="${v}"
    v=$(cfg_get .httpmask.tls); [[ -n "${v}" ]] && HTTP_MASK_TLS="${v}"
    v=$(cfg_get .httpmask.host); [[ -n "${v}" ]] && HTTP_MASK_HOST="${v}"
    v=$(cfg_get .httpmask.path_root); [[ -n "${v}" ]] && HTTP_MASK_PATH_ROOT="${v}"
    v=$(cfg_get .httpmask.multiplex); [[ -n "${v}" ]] && HTTP_MASK_MULTIPLEX="${v}"
    detect_mode
    load_export_state || true
    return 0
}

load_export_state() {
    [[ -f "${EXPORT_STATE_FILE}" ]] || return 1
    # shellcheck disable=SC1090
    source "${EXPORT_STATE_FILE}"
    if [[ -z "${SUDOKU_CLIENT_PORT_INPUT}" && -n "${EXPORTED_CLIENT_PORT:-}" ]]; then
        SUDOKU_CLIENT_PORT="${EXPORTED_CLIENT_PORT}"
    fi
    if [[ -z "${SERVER_IP:-}" && -n "${PUBLIC_HOST:-}" ]]; then
        SERVER_IP="${PUBLIC_HOST}"
    fi
    [[ -n "${EXPORTED_SUBSCRIPTION_NODE_NAME:-}" ]] && SUBSCRIPTION_NODE_NAME="${EXPORTED_SUBSCRIPTION_NODE_NAME}"
    [[ -n "${EXPORTED_SUBSCRIPTION_OUTPUT_FILE:-}" ]] && SUBSCRIPTION_OUTPUT_FILE="${EXPORTED_SUBSCRIPTION_OUTPUT_FILE}"
    return 0
}

persist_export_state() {
    mkdir -p "${CONFIG_DIR}"
    [[ -n "${SUBSCRIPTION_OUTPUT_FILE}" ]] || SUBSCRIPTION_OUTPUT_FILE="${CONFIG_DIR}/subscription.yaml"
    cat >"${EXPORT_STATE_FILE}" <<EOF
AVAILABLE_PRIVATE_KEY=$(printf '%q' "${AVAILABLE_PRIVATE_KEY}")
MASTER_PUBLIC_KEY=$(printf '%q' "${MASTER_PUBLIC_KEY}")
EXPORTED_CLIENT_PORT=$(printf '%q' "${SUDOKU_CLIENT_PORT}")
SHORT_LINK=$(printf '%q' "${SHORT_LINK}")
PUBLIC_HOST=$(printf '%q' "${SERVER_IP}")
EXPORTED_SUBSCRIPTION_NODE_NAME=$(printf '%q' "${SUBSCRIPTION_NODE_NAME}")
EXPORTED_SUBSCRIPTION_OUTPUT_FILE=$(printf '%q' "${SUBSCRIPTION_OUTPUT_FILE}")
EOF
    chmod 600 "${EXPORT_STATE_FILE}"
}

detect_public_ip() { # quiet; sets SERVER_IP
    [[ -n "${SERVER_IP:-}" ]] && return 0
    local ip="" api
    for api in https://api.ipify.org https://ifconfig.me https://icanhazip.com https://ipinfo.io/ip https://api.ip.sb/ip; do
        ip=$(curl -fsSL --connect-timeout 4 --max-time 8 "${api}" 2>/dev/null | tr -d '\n' || true)
        if [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ || "${ip}" =~ ^[0-9a-fA-F:]+$ ]]; then
            SERVER_IP="${ip}"
            return 0
        fi
    done
    return 1
}

# Make sure SERVER_IP is known for share links; ask the user if detection fails.
ensure_server_ip() {
    [[ -n "${SERVER_IP:-}" ]] && return 0
    if ! detect_public_ip; then
        warn "$(L '无法自动检测公网 IP。' 'Could not auto-detect the public IP.')"
        [[ "${UI_TTY}" == "1" ]] || return 1
        ui_ask "$(L '请输入服务器公网 IP 或域名:' 'Enter the server public IP or domain:')" "" is_alias || return 1
        SERVER_IP="${ASK_RESULT}"
    fi
    return 0
}

generate_keypair() {
    local out
    out=$("${INSTALL_DIR}/sudoku" -keygen 2>&1)
    AVAILABLE_PRIVATE_KEY=$(printf '%s\n' "$out" | sed -n 's/.*Available Private Key:[[:space:]]*\([0-9a-fA-F][0-9a-fA-F]*\).*/\1/p' | head -n 1)
    MASTER_PUBLIC_KEY=$(printf '%s\n' "$out" | sed -n 's/.*Master Public Key:[[:space:]]*\([0-9a-fA-F][0-9a-fA-F]*\).*/\1/p' | head -n 1)
    if [[ -z "${AVAILABLE_PRIVATE_KEY}" || -z "${MASTER_PUBLIC_KEY}" ]]; then
        printf '%s\n' "${out}" >&2
        return 1
    fi
}

# A fresh client private key bound to the same master public key.
generate_split_key() { # -> key on stdout
    local out key
    [[ -n "${AVAILABLE_PRIVATE_KEY}" ]] || return 1
    out=$("${INSTALL_DIR}/sudoku" -keygen -more "${AVAILABLE_PRIVATE_KEY}" 2>&1) || { printf '%s\n' "${out}" >&2; return 1; }
    key=$(printf '%s\n' "${out}" | sed -n 's/.*Split Private Key:[[:space:]]*\([0-9a-fA-F][0-9a-fA-F]*\).*/\1/p' | head -n 1)
    [[ -n "${key}" ]] || { printf '%s\n' "${out}" >&2; return 1; }
    printf '%s' "${key}"
}

generate_xpv_table() {
    local chars=(x x p p v v v v) i j tmp r
    for ((i = ${#chars[@]} - 1; i > 0; i--)); do
        r=$(random_uint32)
        j=$((r % (i + 1)))
        tmp="${chars[i]}"; chars[i]="${chars[j]}"; chars[j]="$tmp"
    done
    printf '%s' "${chars[@]}"
}

create_config() {
    mkdir -p "${CONFIG_DIR}"
    cat >"${CONFIG_FILE}" <<EOF
{
  "mode": "server",
  "transport": "tcp",
  "local_port": ${SUDOKU_PORT},
  "server_address": "",
  "fallback_address": "${SUDOKU_FALLBACK}",
  "key": "${MASTER_PUBLIC_KEY}",
  "aead": "${AEAD_METHOD}",
  "suspicious_action": "fallback",
  "ascii": "${ASCII_MODE}",
  "padding_min": 2,
  "padding_max": 7,
  "custom_table": "${CUSTOM_TABLE}",
  "enable_pure_downlink": false,
  "httpmask": {
    "disable": ${DISABLE_HTTP_MASK},
    "mode": "${HTTP_MASK_MODE}",
    "tls": ${HTTP_MASK_TLS},
    "host": "${HTTP_MASK_HOST}",
    "path_root": "${HTTP_MASK_PATH_ROOT}",
    "multiplex": "${HTTP_MASK_MULTIPLEX}"
  }
}
EOF
    chmod 600 "${CONFIG_FILE}"
    local out
    if ! out=$("${INSTALL_DIR}/sudoku" -c "${CONFIG_FILE}" -test 2>&1); then
        printf '%s\n' "${out}" >&2
        return 1
    fi
    api_auto_enable
}

migrate_legacy_httpmask_config_inplace() {
    local path="${1:-}" tmp
    [[ -f "${path}" ]] || return 1
    jq -e '(.httpmask? | type) == "object"' "${path}" >/dev/null 2>&1 && return 0
    jq -e 'has("disable_http_mask") or has("http_mask_mode") or has("http_mask_tls") or has("http_mask_host") or has("path_root") or has("http_mask_path_root") or has("http_mask_multiplex")' "${path}" >/dev/null 2>&1 || return 1
    tmp=$(mktemp)
    if ! jq '
        .httpmask = {
            "disable": (.disable_http_mask // false),
            "mode": ((.http_mask_mode // "legacy") | tostring | if . == "" then "legacy" else . end),
            "tls": (.http_mask_tls // false),
            "host": ((.http_mask_host // "") | tostring),
            "path_root": (((.path_root // .http_mask_path_root // "") | tostring)),
            "multiplex": ((.http_mask_multiplex // "off") | tostring | if . == "" then "off" else . end)
        }
        | del(.disable_http_mask, .http_mask_mode, .http_mask_tls, .http_mask_host, .path_root, .http_mask_path_root, .http_mask_multiplex)
    ' "${path}" >"${tmp}"; then
        rm -f "${tmp}"
        return 1
    fi
    chmod 600 "${tmp}"
    mv "${tmp}" "${path}"
}

configure_firewall() { # <port>
    local port="$1"
    if command -v ufw &>/dev/null; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            ufw allow "${port}/tcp" >/dev/null 2>&1 || true
        fi
    elif command -v firewall-cmd &>/dev/null; then
        if "${SYSTEMCTL}" is-active --quiet firewalld 2>/dev/null; then
            firewall-cmd --permanent --add-port="${port}/tcp" >/dev/null 2>&1 || true
            firewall-cmd --reload >/dev/null 2>&1 || true
        fi
    fi
    return 0
}

remove_firewall_rule() { # <port>
    local port="$1"
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw delete allow "${port}/tcp" >/dev/null 2>&1 || true
    elif command -v firewall-cmd &>/dev/null && "${SYSTEMCTL}" is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --permanent --remove-port="${port}/tcp" >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
    fi
    return 0
}

create_sudoku_service() {
    if init_is_openrc; then
        write_openrc_unit "${SERVICE_NAME}" "Sudoku Proxy Server" "${INSTALL_DIR}/sudoku" "-c ${CONFIG_FILE}"
        return
    fi
    cat >"${SYSTEMD_DIR}/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Sudoku Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/sudoku -c ${CONFIG_FILE}
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

create_sing_box_service() {
    if init_is_openrc; then
        write_openrc_unit "${SING_BOX_SERVICE_NAME}" "Sudoku sing-box server with WARP egress" "${INSTALL_DIR}/sudoku-sing-box" \
            "run -c ${SING_BOX_CONFIG_FILE} -D ${SING_BOX_CACHE_DIR}"
        return
    fi
    cat >"${SYSTEMD_DIR}/${SING_BOX_SERVICE_NAME}.service" <<EOF
[Unit]
Description=Sudoku sing-box server with WARP egress
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/sudoku-sing-box run -c ${SING_BOX_CONFIG_FILE} -D ${SING_BOX_CACHE_DIR}
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
}

# Install + (re)start the service that matches WARP_ENABLED.
create_service() {
    if [[ "${WARP_ENABLED}" == "true" ]]; then
        "${SYSTEMCTL}" disable "${SERVICE_NAME}" >/dev/null 2>&1 || true
        "${SYSTEMCTL}" stop "${SERVICE_NAME}" >/dev/null 2>&1 || true
        rm -f "$(unit_path "${SERVICE_NAME}")"
        create_sing_box_service
        selinux_restore
        "${SYSTEMCTL}" daemon-reload
        "${SYSTEMCTL}" enable "${SING_BOX_SERVICE_NAME}" >/dev/null 2>&1 || true
        "${SYSTEMCTL}" restart "${SING_BOX_SERVICE_NAME}" || return 1
    else
        "${SYSTEMCTL}" disable "${SING_BOX_SERVICE_NAME}" >/dev/null 2>&1 || true
        "${SYSTEMCTL}" stop "${SING_BOX_SERVICE_NAME}" >/dev/null 2>&1 || true
        rm -f "$(unit_path "${SING_BOX_SERVICE_NAME}")"
        create_sudoku_service
        selinux_restore
        "${SYSTEMCTL}" daemon-reload
        "${SYSTEMCTL}" enable "${SERVICE_NAME}" >/dev/null 2>&1 || true
        "${SYSTEMCTL}" restart "${SERVICE_NAME}" || return 1
    fi
}

config_fingerprint() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "${CONFIG_FILE}" 2>/dev/null | cut -d' ' -f1
    else
        shasum -a 256 "${CONFIG_FILE}" 2>/dev/null | cut -d' ' -f1
    fi
}

mark_applied() { config_fingerprint >"${APPLIED_FILE}" 2>/dev/null || true; }

config_dirty() {
    [[ -f "${APPLIED_FILE}" ]] || return 1
    [[ "$(<"${APPLIED_FILE}")" != "$(config_fingerprint)" ]]
}

svc_restart() {
    local port
    have_systemctl || return 1
    port=$(cfg_get .local_port)
    selinux_restore
    "${SYSTEMCTL}" daemon-reload >/dev/null 2>&1 || true
    "${SYSTEMCTL}" restart "$(svc_name)" || return 1
    if [[ -n "${port}" ]]; then
        wait_for_port "${port}" 12 || return 1
    fi
    mark_applied
}

# ═══════════════════════════════════════════════════════════════════════════════
# Cloudflare-style 500 fallback page (hidden default for suspicious traffic)
# ═══════════════════════════════════════════════════════════════════════════════

should_override_fallback_address() {
    [[ "${CF_FALLBACK_FORCE}" == "true" ]] && return 0
    [[ "${SUDOKU_FALLBACK}" == "${DEFAULT_SUDOKU_FALLBACK}" ]]
}

write_cf_fallback_server() {
    mkdir -p "${FALLBACK_LIB_DIR}"

    cat > "${FALLBACK_LIB_DIR}/server.py" << 'PY'
import argparse
import html
import json
import secrets
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


# This page is based on the MIT-licensed project:
# https://github.com/donlon/cloudflare-error-page
#
# We render a 1:1 Cloudflare-style error page without external runtime deps (no pip).

CF_MAIN_CSS = r""".container{width:100%}.bg-white{--bg-opacity:1;background-color:#fff;background-color:rgba(255,255,255,var(--bg-opacity))}.bg-center{background-position:50%}.bg-no-repeat{background-repeat:no-repeat}.border-gray-300{--border-opacity:1;border-color:#ebebeb;border-color:rgba(235,235,235,var(--border-opacity))}.rounded{border-radius:.25rem}.border-solid{border-style:solid}.border-0{border-width:0}.border{border-width:1px}.border-t{border-top-width:1px}.cursor-pointer{cursor:pointer}.block{display:block}.inline-block{display:inline-block}.table{display:table}.hidden{display:none}.float-left{float:left}.clearfix:after{content:"";display:table;clear:both}.font-mono{font-family:monaco,courier,monospace}.font-light{font-weight:300}.font-normal{font-weight:400}.font-semibold{font-weight:600}.h-12{height:3rem}.h-20{height:5rem}.text-13{font-size:13px}.text-15{font-size:15px}.text-60{font-size:60px}.text-2xl{font-size:1.5rem}.text-3xl{font-size:1.875rem}.leading-tight{line-height:1.25}.leading-normal{line-height:1.5}.leading-relaxed{line-height:1.625}.leading-1\.3{line-height:1.3}.my-8{margin-top:2rem;margin-bottom:2rem}.mx-auto{margin-left:auto;margin-right:auto}.mr-2{margin-right:.5rem}.mb-2{margin-bottom:.5rem}.mt-3{margin-top:.75rem}.mb-4{margin-bottom:1rem}.ml-4{margin-left:1rem}.mt-6{margin-top:1.5rem}.mb-6{margin-bottom:1.5rem}.mb-8{margin-bottom:2rem}.mb-10{margin-bottom:2.5rem}.ml-10{margin-left:2.5rem}.mb-15{margin-bottom:3.75rem}.-ml-6{margin-left:-1.5rem}.overflow-hidden{overflow:hidden}.p-0{padding:0}.py-2{padding-top:.5rem;padding-bottom:.5rem}.px-4{padding-left:1rem;padding-right:1rem}.py-8{padding-top:2rem;padding-bottom:2rem}.py-10{padding-top:2.5rem;padding-bottom:2.5rem}.py-15{padding-top:3.75rem;padding-bottom:3.75rem}.pr-6{padding-right:1.5rem}.pt-10{padding-top:2.5rem}.absolute{position:absolute}.relative{position:relative}.left-1\/2{left:50%}.-bottom-4{bottom:-1rem}.resize{resize:both}.text-center{text-align:center}.text-black-dark{--text-opacity:1;color:#404040;color:rgba(64,64,64,var(--text-opacity))}.text-gray-600{--text-opacity:1;color:#999;color:rgba(153,153,153,var(--text-opacity))}.text-red-error{--text-opacity:1;color:#bd2426;color:rgba(189,36,38,var(--text-opacity))}.text-green-success{--text-opacity:1;color:#9bca3e;color:rgba(155,202,62,var(--text-opacity))}.antialiased{-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale}.truncate{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.w-12{width:3rem}.w-240{width:60rem}.w-1\/2{width:50%}.w-1\/3{width:33.333333%}.w-full{width:100%}.transition{-webkit-transition-property:background-color,border-color,color,fill,stroke,opacity,box-shadow,-webkit-transform;transition-property:background-color,border-color,color,fill,stroke,opacity,box-shadow,-webkit-transform;transition-property:background-color,border-color,color,fill,stroke,opacity,box-shadow,transform;transition-property:background-color,border-color,color,fill,stroke,opacity,box-shadow,transform,-webkit-transform}body,html{--text-opacity:1;color:#404040;color:rgba(64,64,64,var(--text-opacity));-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale;font-family:system-ui,-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica Neue,Arial,Noto Sans,sans-serif,Apple Color Emoji,Segoe UI Emoji,Segoe UI Symbol,Noto Color Emoji;font-size:16px}*,body,html{margin:0;padding:0}*{box-sizing:border-box}a{--text-opacity:1;color:#2f7bbf;color:rgba(47,123,191,var(--text-opacity));text-decoration:none;-webkit-transition-property:all;transition-property:all;-webkit-transition-duration:.15s;transition-duration:.15s;-webkit-transition-timing-function:cubic-bezier(0,0,.2,1);transition-timing-function:cubic-bezier(0,0,.2,1)}a:hover{--text-opacity:1;color:#f68b1f;color:rgba(246,139,31,var(--text-opacity))}img{display:block;width:100%;height:auto}#what-happened-section p{font-size:15px;line-height:1.5}strong{font-weight:600}.bg-gradient-gray{background-image:-webkit-linear-gradient(top,#dedede,#ebebeb 3%,#ebebeb 97%,#dedede)}.cf-error-source:after{position:absolute;--bg-opacity:1;background-color:#fff;background-color:rgba(255,255,255,var(--bg-opacity));width:2.5rem;height:2.5rem;--transform-translate-x:0;--transform-translate-y:0;--transform-rotate:0;--transform-skew-x:0;--transform-skew-y:0;--transform-scale-x:1;--transform-scale-y:1;-webkit-transform:translateX(var(--transform-translate-x)) translateY(var(--transform-translate-y)) rotate(var(--transform-rotate)) skewX(var(--transform-skew-x)) skewY(var(--transform-skew-y)) scaleX(var(--transform-scale-x)) scaleY(var(--transform-scale-y));-ms-transform:translateX(var(--transform-translate-x)) translateY(var(--transform-translate-y)) rotate(var(--transform-rotate)) skewX(var(--transform-skew-x)) skewY(var(--transform-skew-y)) scaleX(var(--transform-scale-x)) scaleY(var(--transform-scale-y));transform:translateX(var(--transform-translate-x)) translateY(var(--transform-translate-y)) rotate(var(--transform-rotate)) skewX(var(--transform-skew-x)) skewY(var(--transform-skew-y)) scaleX(var(--transform-scale-x)) scaleY(var(--transform-scale-y));--transform-rotate:45deg;content:"";bottom:-1.75rem;left:50%;margin-left:-1.25rem;box-shadow:0 0 4px 4px #dedede}@media screen and (max-width:720px){.cf-error-source:after{display:none}}.cf-icon-browser{background-image:url(data:image/svg+xml;utf8,%3Csvg%20id%3D%22a%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%20viewBox%3D%220%200%20100%2080.7362%22%3E%3Cpath%20d%3D%22M89.8358.1636H10.1642C4.6398.1636.1614%2C4.6421.1614%2C10.1664v60.4033c0%2C5.5244%2C4.4784%2C10.0028%2C10.0028%2C10.0028h79.6716c5.5244%2C0%2C10.0027-4.4784%2C10.0027-10.0028V10.1664c0-5.5244-4.4784-10.0028-10.0027-10.0028ZM22.8323%2C9.6103c1.9618%2C0%2C3.5522%2C1.5903%2C3.5522%2C3.5521s-1.5904%2C3.5522-3.5522%2C3.5522-3.5521-1.5904-3.5521-3.5522%2C1.5903-3.5521%2C3.5521-3.5521ZM12.8936%2C9.6103c1.9618%2C0%2C3.5522%2C1.5903%2C3.5522%2C3.5521s-1.5904%2C3.5522-3.5522%2C3.5522-3.5521-1.5904-3.5521-3.5522%2C1.5903-3.5521%2C3.5521-3.5521ZM89.8293%2C70.137H9.7312V24.1983h80.0981v45.9387ZM89.8293%2C16.1619H29.8524v-5.999h59.977v5.999Z%22%20style%3D%22fill%3A%20%23999%3B%22/%3E%3C/svg%3E)}.cf-icon-cloud{background-image:url(data:image/svg+xml;utf8,%3Csvg%20id%3D%22a%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%20viewBox%3D%220%200%20152%2078.9141%22%3E%3Cpath%20d%3D%22M132.2996%2C77.9927v-.0261c10.5477-.2357%2C19.0305-8.8754%2C19.0305-19.52%2C0-10.7928-8.7161-19.5422-19.4678-19.5422-2.9027%2C0-5.6471.6553-8.1216%2C1.7987C123.3261%2C18.6624%2C105.3419.9198%2C83.202.9198c-17.8255%2C0-32.9539%2C11.5047-38.3939%2C27.4899-3.0292-2.2755-6.7818-3.6403-10.8622-3.6403-10.0098%2C0-18.1243%2C8.1145-18.1243%2C18.1243%2C0%2C1.7331.258%2C3.4033.7122%2C4.9905-.2899-.0168-.5769-.0442-.871-.0442-8.2805%2C0-14.993%2C6.7503-14.993%2C15.0772%2C0%2C8.2795%2C6.6381%2C14.994%2C14.8536%2C15.0701v.0054h.1069c.0109%2C0%2C.0215.0016.0325.0016s.0215-.0016.0325-.0016%22%20style%3D%22fill%3A%20%23999%3B%22/%3E%3C/svg%3E)}.cf-icon-server{background-image:url(data:image/svg+xml;utf8,%3Csvg%20id%3D%22a%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%20viewBox%3D%220%200%2095%2075%22%3E%3Cpath%20d%3D%22M94.0103%2C45.0775l-12.9885-38.4986c-1.2828-3.8024-4.8488-6.3624-8.8618-6.3619l-49.91.0065c-3.9995.0005-7.556%2C2.5446-8.8483%2C6.3295L1.0128%2C42.8363c-.3315.971-.501%2C1.9899-.5016%2C3.0159l-.0121%2C19.5737c-.0032%2C5.1667%2C4.1844%2C9.3569%2C9.3513%2C9.3569h75.2994c5.1646%2C0%2C9.3512-4.1866%2C9.3512-9.3512v-17.3649c0-1.0165-.1657-2.0262-.4907-2.9893ZM86.7988%2C65.3097c0%2C1.2909-1.0465%2C2.3374-2.3374%2C2.3374H9.9767c-1.2909%2C0-2.3374-1.0465-2.3374-2.3374v-18.1288c0-1.2909%2C1.0465-2.3374%2C2.3374-2.3374h74.4847c1.2909%2C0%2C2.3374%2C1.0465%2C2.3374%2C2.3374v18.1288Z%22%20style%3D%22fill%3A%20%23999%3B%22/%3E%3Ccircle%20cx%3D%2274.6349%22%20cy%3D%2256.1889%22%20r%3D%224.7318%22%20style%3D%22fill%3A%20%23999%3B%22/%3E%3Ccircle%20cx%3D%2259.1472%22%20cy%3D%2256.1889%22%20r%3D%224.7318%22%20style%3D%22fill%3A%20%23999%3B%22/%3E%3C/svg%3E)}.cf-icon-ok{background-image:url(data:image/svg+xml;utf8,%3Csvg%20id%3D%22a%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%20viewBox%3D%220%200%2048%2048%22%3E%3Ccircle%20cx%3D%2224%22%20cy%3D%2224%22%20r%3D%2223.4815%22%20style%3D%22fill%3A%20%239bca3e%3B%22/%3E%3Cpolyline%20points%3D%2217.453%2024.9841%2021.7183%2030.4504%2030.2076%2016.8537%22%20style%3D%22fill%3A%20none%3B%20stroke%3A%20%23fff%3B%20stroke-linecap%3A%20round%3B%20stroke-linejoin%3A%20round%3B%20stroke-width%3A%204px%3B%22/%3E%3C/svg%3E)}.cf-icon-error{background-image:url(data:image/svg+xml;utf8,%3Csvg%20id%3D%22a%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%20viewBox%3D%220%200%2047.9145%2047.9641%22%3E%3Ccircle%20cx%3D%2223.9572%22%20cy%3D%2223.982%22%20r%3D%2223.4815%22%20style%3D%22fill%3A%20%23bd2426%3B%22/%3E%3Cline%20x1%3D%2219.0487%22%20y1%3D%2219.0768%22%20x2%3D%2227.8154%22%20y2%3D%2228.8853%22%20style%3D%22fill%3A%20none%3B%20stroke%3A%20%23fff%3B%20stroke-linecap%3A%20round%3B%20stroke-linejoin%3A%20round%3B%20stroke-width%3A%203px%3B%22/%3E%3Cline%20x1%3D%2227.8154%22%20y1%3D%2219.0768%22%20x2%3D%2219.0487%22%20y2%3D%2228.8853%22%20style%3D%22fill%3A%20none%3B%20stroke%3A%20%23fff%3B%20stroke-linecap%3A%20round%3B%20stroke-linejoin%3A%20round%3B%20stroke-width%3A%203px%3B%22/%3E%3C/svg%3E)}#cf-wrapper .feedback-hidden{display:none}#cf-wrapper .feedback-success{min-height:33px;line-height:33px}#cf-wrapper .cf-button{color:#0051c3;font-size:13px;border-color:#0045a6;-webkit-transition-timing-function:ease;transition-timing-function:ease;-webkit-transition-duration:.2s;transition-duration:.2s;-webkit-transition-property:background-color,border-color,color;transition-property:background-color,border-color,color}#cf-wrapper .cf-button:hover{color:#fff;background-color:#003681}.cf-error-footer .hidden{display:none}.cf-error-footer .cf-footer-ip-reveal-btn{-webkit-appearance:button;-moz-appearance:button;appearance:button;text-decoration:none;background:none;color:inherit;border:none;padding:0;font:inherit;cursor:pointer;color:#0051c3;-webkit-transition:color .15s ease;transition:color .15s ease}.cf-error-footer .cf-footer-ip-reveal-btn:hover{color:#ee730a}.code-label{background-color:#d9d9d9;color:#313131;font-weight:500;border-radius:1.25rem;font-size:.75rem;line-height:4.5rem;padding:.25rem .5rem;height:4.5rem;white-space:nowrap;vertical-align:middle}@media (max-width:639px){.sm\:block{display:block}.sm\:hidden{display:none}.sm\:mb-1{margin-bottom:.25rem}.sm\:mb-2{margin-bottom:.5rem}.sm\:py-4{padding-top:1rem;padding-bottom:1rem}.sm\:px-8{padding-left:2rem;padding-right:2rem}.sm\:text-left{text-align:left}}@media (max-width:720px){.md\:border-gray-400{--border-opacity:1;border-color:#dedede;border-color:rgba(222,222,222,var(--border-opacity))}.md\:border-solid{border-style:solid}.md\:border-0{border-width:0}.md\:border-b{border-bottom-width:1px}.md\:block{display:block}.md\:inline-block{display:inline-block}.md\:hidden{display:none}.md\:float-none{float:none}.md\:text-3xl{font-size:1.875rem}.md\:m-0{margin:0}.md\:mt-0{margin-top:0}.md\:mb-2{margin-bottom:.5rem}.md\:p-0{padding:0}.md\:py-8{padding-top:2rem;padding-bottom:2rem}.md\:px-8{padding-left:2rem;padding-right:2rem}.md\:pr-0{padding-right:0}.md\:pb-10{padding-bottom:2.5rem}.md\:top-0{top:0}.md\:right-0{right:0}.md\:left-auto{left:auto}.md\:text-left{text-align:left}.md\:w-full{width:100%}}@media (max-width:1023px){.lg\:text-sm{font-size:.875rem}.lg\:text-2xl{font-size:1.5rem}.lg\:text-4xl{font-size:2.25rem}.lg\:leading-relaxed{line-height:1.625}.lg\:px-8{padding-left:2rem;padding-right:2rem}.lg\:pt-6{padding-top:1.5rem}.lg\:w-full{width:100%}}"""

DEFAULT_WHAT_HAPPENED = "<p>There is an internal server error on Cloudflare's network.</p>"
DEFAULT_WHAT_CAN_I_DO = "<p>Please try again in a few minutes.</p>"


def _now_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")


def _esc(x: object) -> str:
    return html.escape("" if x is None else str(x), quote=True)


def _as_dict(v: object) -> dict:
    return v if isinstance(v, dict) else {}


def _host_only(host: str) -> str:
    host = (host or "").strip()
    if not host:
        return host
    # Drop port for display (best effort).
    if host.startswith("["):
        # [::1]:443
        if "]:" in host:
            return host[1 : host.index("]:")]
        return host.strip("[]")
    if ":" in host:
        return host.split(":", 1)[0]
    return host


def _normalize_params(base: dict, *, ray_id: str, client_ip: str, host_header: str) -> dict:
    params = dict(base or {})

    more_info = _as_dict(params.get("more_information"))
    if "for_text" in more_info and "for" not in more_info:
        more_info = dict(more_info)
        more_info["for"] = more_info.get("for_text")
        params["more_information"] = more_info

    if not params.get("time"):
        params["time"] = _now_utc()
    if not params.get("ray_id"):
        params["ray_id"] = (ray_id or "").strip() or secrets.token_hex(8)
    if not params.get("client_ip"):
        params["client_ip"] = (client_ip or "").strip()

    # If host_status.location is empty, use request Host header.
    host_status = _as_dict(params.get("host_status"))
    if host_status.get("location") in ("", None):
        host_status = dict(host_status)
        host_status["location"] = _host_only(host_header)
        params["host_status"] = host_status

    return params


def _render_status_item(params: dict, item_id: str) -> str:
    if item_id == "browser":
        icon = "browser"
        default_location = "You"
        default_name = "Browser"
    elif item_id == "cloudflare":
        icon = "cloud"
        default_location = "San Francisco"
        default_name = "Cloudflare"
    else:
        icon = "server"
        default_location = "Website"
        default_name = "Host"

    item = dict(_as_dict(params.get(f"{item_id}_status")))
    status = (item.get("status") or "ok").strip()

    if item.get("status_text_color"):
        text_color = str(item.get("status_text_color"))
    elif status == "ok":
        text_color = "#9bca3e"  # text-green-success
    else:
        text_color = "#bd2426"  # text-red-error

    status_text = item.get("status_text")
    if not status_text:
        status_text = "Working" if status == "ok" else "Error"

    location = item.get("location") or default_location
    name = item.get("name") or default_name

    is_error_source = (params.get("error_source") or "") == item_id
    klass = (
        ("cf-error-source " if is_error_source else "")
        + "relative w-1/3 md:w-full py-15 md:p-0 md:py-8 md:text-left md:border-solid md:border-0 md:border-b md:border-gray-400 overflow-hidden float-left md:float-none text-center"
    )
    name_style = 'style="color: #2f7bbf;"' if name == "Cloudflare" else ""

    return (
        f'                    <div id="cf-{item_id}-status" class="{klass}">\n'
        f'                        <div class="relative mb-10 md:m-0">\n'
        f'                            <span class="cf-icon-{icon} block md:hidden h-20 bg-center bg-no-repeat"></span>\n'
        f'                            <span class="cf-icon-{_esc(status)} w-12 h-12 absolute left-1/2 md:left-auto md:right-0 md:top-0 -ml-6 -bottom-4"></span>\n'
        f"                        </div>\n"
        f'                        <span class="md:block w-full truncate">{_esc(location)}</span>\n'
        f'                        <h3 class="md:inline-block mt-3 md:mt-0 text-2xl text-gray-600 font-light leading-1.3" {name_style}>{_esc(name)}</h3>\n'
        f'                        <span class="leading-1.3 text-2xl" style="color: {html.escape(text_color, quote=True)}">{_esc(status_text)}</span>\n'
        f"                    </div>\n"
    )


def render_cloudflare_error_page(params: dict) -> bytes:
    error_code = params.get("error_code") or 500
    title = params.get("title") or "Internal server error"
    html_title = params.get("html_title") or f"{error_code}: {title}"

    more_info = _as_dict(params.get("more_information"))
    more_hidden = bool(more_info.get("hidden") or False) if isinstance(more_info, dict) else False
    more_link = more_info.get("link") or "https://www.cloudflare.com/"
    more_text = more_info.get("text") or "cloudflare.com"
    more_for = more_info.get("for") or more_info.get("for_text") or "more information"

    perf_sec_by = _as_dict(params.get("perf_sec_by"))
    perf_text = perf_sec_by.get("text") or "Cloudflare"
    perf_link = perf_sec_by.get("link") or "https://www.cloudflare.com/"

    creator_info = _as_dict(params.get("creator_info"))
    creator_hidden = creator_info.get("hidden", True)
    creator_text = creator_info.get("text") or ""
    creator_link = creator_info.get("link") or ""

    what_happened = params.get("what_happened") or DEFAULT_WHAT_HAPPENED
    what_can_i_do = params.get("what_can_i_do") or DEFAULT_WHAT_CAN_I_DO

    style = params.get("html_style") or CF_MAIN_CSS

    parts: list[str] = []
    parts.append("<!DOCTYPE html>")
    parts.append('<!--[if lt IE 7]> <html class="no-js ie6 oldie" lang="en-US"> <![endif]-->')
    parts.append('<!--[if IE 7]>    <html class="no-js ie7 oldie" lang="en-US"> <![endif]-->')
    parts.append('<!--[if IE 8]>    <html class="no-js ie8 oldie" lang="en-US"> <![endif]-->')
    parts.append('<!--[if gt IE 8]><!--> <html class="no-js" lang="en-US"> <!--<![endif]-->')
    parts.append("<head>")
    parts.append(f"<title>{_esc(html_title)}</title>")
    parts.append('<meta charset="UTF-8" />')
    parts.append('<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />')
    parts.append('<meta http-equiv="X-UA-Compatible" content="IE=Edge" />')
    parts.append('<meta name="robots" content="noindex, nofollow" />')
    parts.append('<meta name="viewport" content="width=device-width,initial-scale=1" />')
    parts.append("<style>")
    parts.append(str(style))
    parts.append("</style>")
    parts.append("</head>")
    parts.append("<body>")
    parts.append('<div id="cf-wrapper">')
    parts.append('    <div id="cf-error-details" class="p-0">')
    parts.append('        <header class="mx-auto pt-10 lg:pt-6 lg:px-8 w-240 lg:w-full mb-8">')
    parts.append('            <h1 class="inline-block sm:block sm:mb-2 font-light text-60 lg:text-4xl text-black-dark leading-tight mr-2">')
    parts.append(f'                <span class="inline-block">{_esc(title)}</span>')
    parts.append(f'                <span class="code-label">Error code {_esc(error_code)}</span>')
    parts.append("            </h1>")
    if not more_hidden:
        parts.append("            <div>")
        parts.append(
            f'                Visit <a href="{_esc(more_link)}" target="_blank" rel="noopener noreferrer">{_esc(more_text)}</a> for {_esc(more_for)}.'
        )
        parts.append("            </div>")
    parts.append(f'            <div class="mt-3">{_esc(params.get("time"))}</div>')
    parts.append("        </header>")
    parts.append('        <div class="my-8 bg-gradient-gray">')
    parts.append('          <div class="w-240 lg:w-full mx-auto">')
    parts.append('                <div class="clearfix md:px-8">')
    parts.append(_render_status_item(params, "browser").rstrip("\n"))
    parts.append(_render_status_item(params, "cloudflare").rstrip("\n"))
    parts.append(_render_status_item(params, "host").rstrip("\n"))
    parts.append("                </div>")
    parts.append("            </div>")
    parts.append("        </div>")
    parts.append("")
    parts.append('        <div class="w-240 lg:w-full mx-auto mb-8 lg:px-8">')
    parts.append('            <div class="clearfix">')
    parts.append('                <div class="w-1/2 md:w-full float-left pr-6 md:pb-10 md:pr-0 leading-relaxed">')
    parts.append('                    <h2 class="text-3xl font-normal leading-1.3 mb-4">What happened?</h2>')
    parts.append(f"                    {what_happened}")
    parts.append("                </div>")
    parts.append('                <div class="w-1/2 md:w-full float-left leading-relaxed">')
    parts.append('                    <h2 class="text-3xl font-normal leading-1.3 mb-4">What can I do?</h2>')
    parts.append(f"                    {what_can_i_do}")
    parts.append("                </div>")
    parts.append("            </div>")
    parts.append("        </div>")
    parts.append("")
    parts.append(
        '        <div class="cf-error-footer cf-wrapper w-240 lg:w-full py-10 sm:py-4 sm:px-8 mx-auto text-center sm:text-left border-solid border-0 border-t border-gray-300">'
    )
    parts.append('            <p class="text-13">')
    parts.append(
        f'                <span class="cf-footer-item sm:block sm:mb-1">Ray ID: <strong class="font-semibold">{_esc(params.get("ray_id"))}</strong></span>'
    )
    parts.append('                <span class="cf-footer-separator sm:hidden">&bull;</span>')
    parts.append('                <span id="cf-footer-item-ip" class="cf-footer-item hidden sm:block sm:mb-1">')
    parts.append("                    Your IP:")
    parts.append('                    <button type="button" id="cf-footer-ip-reveal" class="cf-footer-ip-reveal-btn">Click to reveal</button>')
    parts.append(f'                    <span class="hidden" id="cf-footer-ip">{_esc(params.get("client_ip") or "1.1.1.1")}</span>')
    parts.append('                    <span class="cf-footer-separator sm:hidden">&bull;</span>')
    parts.append("                </span>")
    parts.append(
        f'                <span class="cf-footer-item sm:block sm:mb-1"><span>Performance &amp; security by</span> <a rel="noopener noreferrer" href="{_esc(perf_link)}" id="brand_link" target="_blank">{_esc(perf_text)}</a></span>'
    )
    if not bool(creator_hidden):
        parts.append('                <span class="cf-footer-separator sm:hidden">&bull;</span>')
        parts.append(
            f'                <span class="cf-footer-item sm:block sm:mb-1">Created with <a href="{_esc(creator_link)}" target="_blank">{_esc(creator_text)}</a></span>'
        )
    parts.append("            </p>")
    parts.append("        </div><!-- /.error-footer -->")
    parts.append("    </div>")
    parts.append("</div>")
    parts.append(
        '<script>(function(){function d(){var b=a.getElementById("cf-footer-item-ip"),c=a.getElementById("cf-footer-ip-reveal");b&&"classList"in b&&(b.classList.remove("hidden"),c.addEventListener("click",function(){c.classList.add("hidden");a.getElementById("cf-footer-ip").classList.remove("hidden")}))}var a=document;document.addEventListener&&a.addEventListener("DOMContentLoaded",d)})();</script>'
    )
    parts.append("</body>")
    parts.append("</html>")

    return ("\n".join(parts) + "\n").encode("utf-8", errors="replace")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=10232)
    parser.add_argument("--params", required=True)
    args = parser.parse_args()

    base_params = {}
    try:
        with open(args.params, "r", encoding="utf-8") as f:
            base_params = json.load(f) or {}
    except Exception:
        base_params = {}

    class Handler(BaseHTTPRequestHandler):
        server_version = "cloudflare"
        sys_version = ""

        def _client_ip(self) -> str:
            xff = (self.headers.get("X-Forwarded-For") or "").strip()
            if xff:
                return xff.split(",")[0].strip()
            return (self.client_address[0] or "").strip()

        def _ray_id(self) -> str:
            v = (self.headers.get("Cf-Ray") or self.headers.get("CF-Ray") or "").strip()
            return v[:32]

        def _send_500(self) -> None:
            host_header = (self.headers.get("Host") or "").strip()
            params = _normalize_params(
                base_params,
                ray_id=self._ray_id(),
                client_ip=self._client_ip(),
                host_header=host_header,
            )
            body = render_cloudflare_error_page(params)
            self.send_response(500)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)

        def do_GET(self):  # noqa: N802
            self._send_500()

        def do_HEAD(self):  # noqa: N802
            self._send_500()

        def do_POST(self):  # noqa: N802
            self._send_500()

        def do_PUT(self):  # noqa: N802
            self._send_500()

        def do_PATCH(self):  # noqa: N802
            self._send_500()

        def do_DELETE(self):  # noqa: N802
            self._send_500()

        def do_OPTIONS(self):  # noqa: N802
            self._send_500()

        def log_message(self, format, *args):  # noqa: A003
            return

    class ReusableTCPServer(ThreadingHTTPServer):
        allow_reuse_address = True

    with ReusableTCPServer((args.bind, args.port), Handler) as httpd:
        httpd.daemon_threads = True
        httpd.serve_forever(poll_interval=0.5)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY

    if [[ ! -f "${FALLBACK_LIB_DIR}/params.json" ]]; then
        cat > "${FALLBACK_LIB_DIR}/params.json" << 'JSON'
{
  "title": "Internal server error",
  "error_code": 500,
  "browser_status": { "status": "ok" },
  "cloudflare_status": { "status": "error", "status_text": "Error" },
  "host_status": { "status": "ok", "location": "" },
  "error_source": "cloudflare",
  "what_happened": "<p>There is an internal server error on Cloudflare's network.</p>",
  "what_can_i_do": "<p>Please try again in a few minutes.</p>"
}
JSON
    fi
}

write_cf_fallback_service() {
    local bind="${1:-}" port="${2:-}" pybin
    pybin=$(command -v python3 2>/dev/null || true)
    [[ -n "${pybin}" ]] || return 1
    if init_is_openrc; then
        write_openrc_unit "${FALLBACK_SERVICE_NAME}" "Sudoku Cloudflare 500 Error Page Fallback" "${pybin}" \
            "${FALLBACK_LIB_DIR}/server.py --bind ${bind} --port ${port} --params ${FALLBACK_LIB_DIR}/params.json" "${FALLBACK_LIB_DIR}"
        return
    fi
    cat >"${SYSTEMD_DIR}/${FALLBACK_SERVICE_NAME}.service" <<EOF
[Unit]
Description=Sudoku Cloudflare 500 Error Page Fallback
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
WorkingDirectory=${FALLBACK_LIB_DIR}
Environment=PYTHONUNBUFFERED=1
ExecStart=${pybin} ${FALLBACK_LIB_DIR}/server.py --bind ${bind} --port ${port} --params ${FALLBACK_LIB_DIR}/params.json
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

start_cf_fallback_service() {
    local bind="${1:-}" port="${2:-}" url http_code
    have_systemctl || return 1
    [[ -f "${FALLBACK_LIB_DIR}/server.py" && -f "${FALLBACK_LIB_DIR}/params.json" ]] || return 1
    write_cf_fallback_service "${bind}" "${port}" || return 1
    selinux_restore
    "${SYSTEMCTL}" daemon-reload >/dev/null 2>&1 || true
    "${SYSTEMCTL}" stop "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
    "${SYSTEMCTL}" reset-failed "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
    "${SYSTEMCTL}" enable "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
    "${SYSTEMCTL}" restart "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || "${SYSTEMCTL}" start "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
    sleep 1
    "${SYSTEMCTL}" is-active --quiet "${FALLBACK_SERVICE_NAME}" || return 1
    url=$(build_http_url "${bind}" "${port}")
    http_code=$(curl -sS -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null || true)
    [[ "${http_code}" == "500" ]]
}

# Writes the effective fallback_address into $CF_RESULT_FILE (so it survives ui_run's subshell).
CF_RESULT_FILE=""
setup_cf_fallback() {
    [[ "${CF_FALLBACK_ENABLED}" == "true" ]] || return 0
    write_cf_fallback_server || { echo "failed to write CF fallback files" >&2; return 1; }

    local selected_port=""
    if start_cf_fallback_service "${CF_FALLBACK_BIND}" "${CF_FALLBACK_PORT}"; then
        selected_port="${CF_FALLBACK_PORT}"
    elif start_cf_fallback_service "${CF_FALLBACK_BIND}" "${CF_FALLBACK_PORT_FALLBACK}"; then
        selected_port="${CF_FALLBACK_PORT_FALLBACK}"
    fi

    if [[ -z "${selected_port}" ]]; then
        "${SYSTEMCTL}" stop "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
        "${SYSTEMCTL}" disable "${FALLBACK_SERVICE_NAME}" >/dev/null 2>&1 || true
        rm -f "$(unit_path "${FALLBACK_SERVICE_NAME}")"
        "${SYSTEMCTL}" daemon-reload >/dev/null 2>&1 || true
        echo "fallback page failed to start; using fallback_address=${SUDOKU_FALLBACK}" >&2
        return 1
    fi

    if should_override_fallback_address && [[ -n "${CF_RESULT_FILE}" ]]; then
        join_host_port "${CF_FALLBACK_BIND}" "${selected_port}" >"${CF_RESULT_FILE}"
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# WARP egress (sudoku-sing-box + wgcf)
# ═══════════════════════════════════════════════════════════════════════════════

ensure_warp_profile() {
    ensure_wgcf_binary || return 1
    mkdir -p "${SUDOKU_WARP_DIR}"
    chmod 700 "${SUDOKU_WARP_DIR}"
    if [[ -f "${SUDOKU_WARP_PROFILE}" ]] && grep -q '^PrivateKey[[:space:]]*=' "${SUDOKU_WARP_PROFILE}" && grep -q '^PublicKey[[:space:]]*=' "${SUDOKU_WARP_PROFILE}"; then
        return 0
    fi
    (
        cd "${SUDOKU_WARP_DIR}" || exit 1
        umask 077
        if [[ ! -f wgcf-account.toml ]]; then
            wgcf register --accept-tos || exit 1
        fi
        wgcf generate --profile "$(basename "${SUDOKU_WARP_PROFILE}")" || exit 1
    ) || return 1
    chmod 600 "${SUDOKU_WARP_DIR}/wgcf-account.toml" "${SUDOKU_WARP_PROFILE}" 2>/dev/null || true
}

write_sing_box_warp_config() {
    mkdir -p "${SING_BOX_CONFIG_DIR}" "${SING_BOX_CACHE_DIR}"
    chmod 700 "${SING_BOX_CACHE_DIR}"

    python3 - \
        "${SUDOKU_WARP_PROFILE}" \
        "${SING_BOX_CONFIG_FILE}" \
        "${SUDOKU_PORT}" \
        "${MASTER_PUBLIC_KEY}" \
        "${SUDOKU_FALLBACK}" \
        "${ASCII_MODE}" \
        "${CUSTOM_TABLE}" \
        "${DISABLE_HTTP_MASK}" \
        "${HTTP_MASK_MODE}" \
        "${HTTP_MASK_TLS}" \
        "${HTTP_MASK_HOST}" \
        "${HTTP_MASK_PATH_ROOT}" \
        "${HTTP_MASK_MULTIPLEX}" \
        "${AEAD_METHOD}" << 'PY'
import json
import sys
from pathlib import Path

profile_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
sudoku_port = int(sys.argv[3])
sudoku_key = sys.argv[4]
fallback_address = sys.argv[5]
ascii_mode = sys.argv[6]
custom_table = sys.argv[7]
httpmask_disable = sys.argv[8].lower() == "true"
httpmask_mode = sys.argv[9]
httpmask_tls = sys.argv[10].lower() == "true"
httpmask_host = sys.argv[11]
httpmask_path_root = sys.argv[12]
httpmask_multiplex = sys.argv[13]
aead_method = sys.argv[14]

sections = {}
section = None
for raw_line in profile_path.read_text().splitlines():
    line = raw_line.split("#", 1)[0].strip()
    if not line:
        continue
    if line.startswith("[") and line.endswith("]"):
        section = line[1:-1].strip()
        sections.setdefault(section, {})
        continue
    if "=" not in line or section is None:
        continue
    key, value = line.split("=", 1)
    sections.setdefault(section, {})[key.strip()] = value.strip()

interface = sections.get("Interface", {})
peer = sections.get("Peer", {})

def csv(value):
    return [item.strip() for item in value.split(",") if item.strip()]

private_key = interface.get("PrivateKey", "")
addresses = csv(interface.get("Address", ""))
public_key = peer.get("PublicKey", "")
allowed_ips = csv(peer.get("AllowedIPs", "0.0.0.0/0, ::/0"))
endpoint = peer.get("Endpoint", "engage.cloudflareclient.com:2408")
mtu = int(interface.get("MTU", "1280"))

if not private_key or not addresses or not public_key or not endpoint:
    raise SystemExit(f"invalid WARP profile: {profile_path}")

if endpoint.startswith("["):
    host, rest = endpoint[1:].split("]", 1)
    port = rest.lstrip(":")
else:
    host, port = endpoint.rsplit(":", 1)

peer_config = {
    "address": host,
    "port": int(port),
    "public_key": public_key,
    "allowed_ips": allowed_ips,
}

reserved = csv(peer.get("Reserved", ""))
if reserved:
    peer_config["reserved"] = [int(item) for item in reserved]

sudoku_inbound = {
    "type": "sudoku",
    "tag": "sudoku-in",
    "listen": "::",
    "listen_port": sudoku_port,
    "key": sudoku_key,
    "aead": aead_method,
    "ascii": ascii_mode,
    "padding_min": 2,
    "padding_max": 7,
    "enable_pure_downlink": False,
    "fallback_address": fallback_address,
    "suspicious_action": "fallback",
    "httpmask": {
        "disable": httpmask_disable,
        "mode": httpmask_mode,
        "tls": httpmask_tls,
        "host": httpmask_host,
        "path_root": httpmask_path_root,
        "multiplex": httpmask_multiplex,
    },
}
if custom_table:
    sudoku_inbound["custom_table"] = custom_table

config = {
    "log": {
        "level": "info",
        "timestamp": True,
    },
    "dns": {
        "servers": [
            {
                "type": "udp",
                "tag": "cloudflare",
                "server": "1.1.1.1",
                "server_port": 53,
            }
        ],
        "final": "cloudflare",
        "strategy": "prefer_ipv4",
    },
    "inbounds": [sudoku_inbound],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct",
        }
    ],
    "endpoints": [
        {
            "type": "wireguard",
            "tag": "wireguard",
            "system": False,
            "mtu": mtu,
            "address": addresses,
            "private_key": private_key,
            "peers": [peer_config],
        }
    ],
    "route": {
        "final": "wireguard",
        "auto_detect_interface": True,
        "default_domain_resolver": {
            "server": "cloudflare",
            "strategy": "prefer_ipv4",
        },
    },
}

output_path.write_text(json.dumps(config, indent=2) + "\n")
PY
    chmod 600 "${SING_BOX_CONFIG_FILE}"
    sync_singbox_users "${CONFIG_FILE}" "${SING_BOX_CONFIG_FILE}" || return 1
    "${INSTALL_DIR}/sudoku-sing-box" check -c "${SING_BOX_CONFIG_FILE}" 2>&1 || { echo "sudoku-sing-box WARP config validation failed: ${SING_BOX_CONFIG_FILE}" >&2; return 1; }
}

# Copy .users from a sudoku server config into the sudoku-in inbound of a sing-box config.
sync_singbox_users() { # <sudoku-config> <singbox-config-to-patch>
    local src="$1" dst="$2" tmp
    [[ -f "${src}" && -f "${dst}" ]] || return 0
    tmp=$(mktemp)
    if ! jq --slurpfile c "${src}" '
        ($c[0].users // []) as $u
        | .inbounds |= map(if .tag == "sudoku-in" then (if ($u | length) > 0 then .users = $u else del(.users) end) else . end)
    ' "${dst}" >"${tmp}"; then
        rm -f "${tmp}"
        return 1
    fi
    chmod 600 "${tmp}"
    mv "${tmp}" "${dst}"
}

remove_legacy_warp_tun_service() {
    "${SYSTEMCTL}" stop "sudoku-singbox-route" 2>/dev/null || true
    "${SYSTEMCTL}" disable "sudoku-singbox-route" 2>/dev/null || true
    if [[ -x "/usr/local/sbin/sudoku-singbox-route" ]]; then
        "/usr/local/sbin/sudoku-singbox-route" stop >/dev/null 2>&1 || true
    fi
    rm -f "${SYSTEMD_DIR}/sudoku-singbox-route.service" "/usr/local/sbin/sudoku-singbox-route"
}

cleanup_legacy_subscription_https() {
    have_systemctl || return 0
    "${SYSTEMCTL}" stop "${LEGACY_SUBSCRIPTION_SERVICE_NAME}" 2>/dev/null || true
    "${SYSTEMCTL}" disable "${LEGACY_SUBSCRIPTION_SERVICE_NAME}" 2>/dev/null || true
    "${SYSTEMCTL}" stop "${LEGACY_SUBSCRIPTION_ACME_TIMER_NAME}" 2>/dev/null || true
    "${SYSTEMCTL}" disable "${LEGACY_SUBSCRIPTION_ACME_TIMER_NAME}" 2>/dev/null || true
    rm -f "${SYSTEMD_DIR}/${LEGACY_SUBSCRIPTION_SERVICE_NAME}.service" \
        "${SYSTEMD_DIR}/${LEGACY_SUBSCRIPTION_ACME_TIMER_NAME}" \
        "${SYSTEMD_DIR}/sudoku-acme-renew.service"
    rm -rf "${LEGACY_SUBSCRIPTION_LIB_DIR}" "${LEGACY_SUBSCRIPTION_CERT_DIR}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Client exports (short link / Mihomo node YAML), optionally for a specific user key
# ═══════════════════════════════════════════════════════════════════════════════

make_short_link() { # <client-private-key> -> link on stdout
    local key="$1" tmp cfg out link server_address
    tmp=$(mktemp -d)
    cfg="${tmp}/client.json"
    server_address=$(join_host_port "${SERVER_IP}" "${SUDOKU_PORT}")
    cat >"${cfg}" <<EOF
{
  "mode": "client",
  "transport": "tcp",
  "local_port": ${SUDOKU_CLIENT_PORT},
  "server_address": "${server_address}",
  "key": "${key}",
  "aead": "${AEAD_METHOD}",
  "ascii": "${ASCII_MODE}",
  "padding_min": 5,
  "padding_max": 15,
  "custom_table": "${CUSTOM_TABLE}",
  "enable_pure_downlink": false,
  "httpmask": {
    "disable": ${CLIENT_DISABLE_HTTP_MASK},
    "mode": "${HTTP_MASK_MODE}",
    "tls": ${HTTP_MASK_TLS},
    "host": "${HTTP_MASK_HOST}",
    "path_root": "${HTTP_MASK_PATH_ROOT}",
    "multiplex": "${HTTP_MASK_MULTIPLEX}"
  },
  "rule_urls": ["global"]
}
EOF
    out=$("${INSTALL_DIR}/sudoku" -c "${cfg}" -export-link 2>&1 || true)
    link=$(printf '%s\n' "${out}" | grep -Eo 'sudoku://[^[:space:]]+' | tail -n 1)
    rm -rf "${tmp}"
    if [[ -z "${link}" ]]; then
        printf '%s\n' "${out}" >&2
        return 1
    fi
    printf '%s' "${link}"
}

write_default_subscription_template() {
    local output_file="${1:-}"
    mkdir -p "$(dirname "${output_file}")"
    cat > "${output_file}" << 'EOF'
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
ipv6: false
unified-delay: true

profile:
  store-selected: true

rule-providers:
  awavenue-ads:
    type: http
    behavior: classical
    format: yaml
    path: ./ruleset/awavenue-ads.yaml
    url: "https://gcore.jsdelivr.net/gh/TG-Twilight/AWAvenue-Ads-Rule@main/Filters/AWAvenue-Ads-Rule-Clash-Classical.yaml"
    interval: 86400
    proxy: DIRECT

  china-max-noip:
    type: http
    behavior: classical
    format: text
    path: ./ruleset/china-max-noip.list
    url: "https://fastly.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/ChinaMaxNoIP/ChinaMaxNoIP.list"
    interval: 86400
    proxy: DIRECT

  chn-ipv4:
    type: http
    behavior: ipcidr
    format: yaml
    path: ./ruleset/chn-ipv4.yaml
    url: "https://fastly.jsdelivr.net/gh/fernvenue/chn-cidr-list@master/ipv4.yaml"
    interval: 86400
    proxy: DIRECT

  chn-ipv6:
    type: http
    behavior: ipcidr
    format: yaml
    path: ./ruleset/chn-ipv6.yaml
    url: "https://fastly.jsdelivr.net/gh/fernvenue/chn-cidr-list@master/ipv6.yaml"
    interval: 86400
    proxy: DIRECT

rules:
  - RULE-SET,awavenue-ads,REJECT
  - RULE-SET,china-max-noip,DIRECT
  - RULE-SET,chn-ipv4,DIRECT
  - RULE-SET,chn-ipv6,DIRECT
  - MATCH,Proxy
EOF
}

fetch_subscription_template() {
    local output_dir="${1:-}"
    local default_template="${output_dir}/template.default.yaml"
    local remote_template="${output_dir}/template.remote.yaml"
    write_default_subscription_template "${default_template}"
    if [[ -n "${SUBSCRIPTION_TEMPLATE_URL}" ]]; then
        if curl -fsSL "${SUBSCRIPTION_TEMPLATE_URL}" -o "${remote_template}"; then
            printf '%s' "${remote_template}"
            return 0
        fi
        true
    fi
    printf '%s' "${default_template}"
}

render_node_yaml() {
    local node_name server_escaped key_escaped host_escaped path_root_escaped
    node_name=$(yaml_escape_double_quoted "${SUBSCRIPTION_NODE_NAME}")
    server_escaped=$(yaml_escape_double_quoted "${SERVER_IP}")
    key_escaped=$(yaml_escape_double_quoted "${AVAILABLE_PRIVATE_KEY}")
    host_escaped=$(yaml_escape_double_quoted "${HTTP_MASK_HOST}")
    path_root_escaped=$(yaml_escape_double_quoted "${HTTP_MASK_PATH_ROOT}")

    printf -- '- name: "%s"\n' "${node_name}"
    echo "  type: sudoku"
    printf '  server: "%s"\n' "${server_escaped}"
    printf '  port: %s\n' "${SUDOKU_PORT}"
    printf '  key: "%s"\n' "${key_escaped}"
    printf '  aead-method: %s\n' "${AEAD_METHOD}"
    echo "  padding-min: 2"
    echo "  padding-max: 7"
    printf '  table-type: %s\n' "${ASCII_MODE}"
    if [[ -n "${CUSTOM_TABLE:-}" ]]; then
        printf '  custom-table: %s\n' "${CUSTOM_TABLE}"
    fi
    echo "  httpmask:"
    printf '    disable: %s\n' "${CLIENT_DISABLE_HTTP_MASK}"
    printf '    mode: %s\n' "${HTTP_MASK_MODE}"
    printf '    tls: %s\n' "${HTTP_MASK_TLS}"
    printf '    host: "%s"\n' "${host_escaped}"
    printf '    multiplex: "%s"\n' "${HTTP_MASK_MULTIPLEX}"
    printf '    path-root: "%s"\n' "${path_root_escaped}"
    echo "  enable-pure-downlink: false"
}

generate_subscription_config() {

    local temp_dir template_file head_file tail_file
    temp_dir=$(mktemp -d)
    template_file=$(fetch_subscription_template "${temp_dir}")
    head_file="${temp_dir}/template.head"
    tail_file="${temp_dir}/template.tail"

    if ! awk '
        /^proxies:[[:space:]]*$/ { exit }
        /^proxy-groups:[[:space:]]*$/ { exit }
        /^rule-providers:[[:space:]]*$/ { exit }
        { print }
    ' "${template_file}" > "${head_file}"; then
        rm -rf "${temp_dir}"
        return_error "Failed to render subscription template header"
    fi

    if ! awk '
        /^rule-providers:[[:space:]]*$/ { found = 1 }
        found { print }
    ' "${template_file}" > "${tail_file}"; then
        rm -rf "${temp_dir}"
        return_error "Failed to render subscription template tail"
    fi

    if [[ ! -s "${tail_file}" ]]; then
        rm -rf "${temp_dir}"
        return_error "Subscription template is missing a rule-providers section"
    fi

    NODE_YAML=$(render_node_yaml)
    mkdir -p "$(dirname "${SUBSCRIPTION_OUTPUT_FILE}")"

    if ! {
        cat "${head_file}"
        echo ""
        echo "proxies:"
        printf '%s\n' "${NODE_YAML}" | sed 's/^/  /'
        echo ""
        echo "proxy-groups:"
        echo "  - name: Proxy"
        echo "    type: select"
        echo "    proxies:"
        printf '      - "%s"\n' "$(yaml_escape_double_quoted "${SUBSCRIPTION_NODE_NAME}")"
        echo ""
        cat "${tail_file}"
    } > "${SUBSCRIPTION_OUTPUT_FILE}"; then
        rm -rf "${temp_dir}"
        return_error "Failed to write subscription YAML"
    fi

    chmod 600 "${SUBSCRIPTION_OUTPUT_FILE}"
    rm -rf "${temp_dir}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# dash self-install / update
# ═══════════════════════════════════════════════════════════════════════════════

DASH_SELF="${BASH_SOURCE[0]:-$0}"

install_dash_self() {
    local tmp
    mkdir -p "${INSTALL_DIR}"
    tmp=$(mktemp)
    if [[ -f "${DASH_SELF}" ]] && grep -q 'SUDOKU-DASH-MARKER' "${DASH_SELF}" 2>/dev/null; then
        cp "${DASH_SELF}" "${tmp}"
    else
        curl -fsSL --connect-timeout 10 "${DASH_URL}" -o "${tmp}" || { rm -f "${tmp}"; echo "failed to download ${DASH_URL}" >&2; return 1; }
    fi
    if ! grep -q 'SUDOKU-DASH-MARKER' "${tmp}" || ! bash -n "${tmp}" 2>/dev/null; then
        rm -f "${tmp}"
        echo "downloaded dash script is invalid" >&2
        return 1
    fi
    install -m 755 "${tmp}" "${DASH_BIN}.new" && mv -f "${DASH_BIN}.new" "${DASH_BIN}"
    rm -f "${tmp}"
    # Never shadow Debian's /bin/dash: only add the short name when it is free.
    if ! command -v dash >/dev/null 2>&1; then
        ln -sf "${DASH_BIN}" "${INSTALL_DIR}/dash"
    fi
}

remote_dash_version() {
    curl -fsSL --connect-timeout 8 --max-time 15 "${DASH_URL}" 2>/dev/null | sed -n 's/^DASH_VERSION="\(.*\)"$/\1/p' | head -n 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# Installer wizard
# ═══════════════════════════════════════════════════════════════════════════════

CURRENT_PORT_FOR_VALIDATION=""
is_free_port() {
    is_valid_port "${1:-}" || return 1
    [[ "${1}" == "${CURRENT_PORT_FOR_VALIDATION}" ]] && return 0
    if is_tcp_port_in_use "${1}"; then
        err "$(L "端口 ${1} 已被占用。" "Port ${1} is already in use.")"
        return 1
    fi
    return 0
}

show_header() {
    ui_clear
    ui_logo
}

wizard_questions() {
    local suggested
    if [[ -z "${SUDOKU_PORT}" ]]; then
        suggested=$(pick_random_high_port)
        if [[ "${UI_TTY}" == "1" && "${ASSUME_YES}" != "1" ]]; then
            ui_title "$(L '服务端口' 'Server port')"
            dim "  $(L '直接回车使用随机端口，或输入 1-65535 的自定义端口。' 'Press Enter for a random port, or type your own (1-65535).')"
            printf '\n'
            ui_ask "$(L '端口' 'Port')" "${suggested}" is_free_port
            SUDOKU_PORT="${ASK_RESULT}"
        else
            SUDOKU_PORT="${suggested}"
        fi
    elif is_tcp_port_in_use "${SUDOKU_PORT}"; then
        die "$(L "端口 ${SUDOKU_PORT} 已被占用。" "Port ${SUDOKU_PORT} is already in use.")"
    fi

    if [[ -z "${SUDOKU_AEAD}" && "${UI_TTY}" == "1" && "${ASSUME_YES}" != "1" ]]; then
        ui_title "$(L '加密方式 (AEAD)' 'Encryption (AEAD)')"
        MENU_DEFAULT=0
        ui_menu \
            "chacha20-poly1305   $(L '（推荐，默认）' '(recommended, default)')" \
            "aes-128-gcm         $(L '（有 AES 硬件加速时更快）' '(faster with AES hardware)')" \
            "none                $(L '（不加密，不推荐）' '(no encryption, not recommended)')"
        case "${MENU_SEL}" in
            1) AEAD_METHOD="aes-128-gcm" ;;
            2) AEAD_METHOD="none" ;;
            *) AEAD_METHOD="chacha20-poly1305" ;;
        esac
    fi

    if [[ -z "${SUDOKU_ASCII}" && "${UI_TTY}" == "1" && "${ASSUME_YES}" != "1" ]]; then
        ui_title "$(L 'ASCII 模式' 'ASCII mode')"
        MENU_DEFAULT=0
        ui_menu \
            "up_ascii_down_entropy   $(L '（上行 ASCII / 下行低熵，默认）' '(uplink ASCII / downlink entropy, default)')" \
            "prefer_entropy          $(L '（双向低熵布局）' '(low-entropy both ways)')" \
            "prefer_ascii            $(L '（双向可打印 ASCII）' '(printable ASCII both ways)')" \
            "up_entropy_down_ascii   $(L '（上行低熵 / 下行 ASCII）' '(uplink entropy / downlink ASCII)')"
        case "${MENU_SEL}" in
            1) ASCII_MODE="prefer_entropy" ;;
            2) ASCII_MODE="prefer_ascii" ;;
            3) ASCII_MODE="up_entropy_down_ascii" ;;
            *) ASCII_MODE="up_ascii_down_entropy" ;;
        esac
    fi

    if [[ -z "${SUDOKU_WARP_PRESET}" && "${UI_TTY}" == "1" && "${ASSUME_YES}" != "1" ]]; then
        ui_title "$(L 'Cloudflare WARP 出口' 'Cloudflare WARP egress')"
        dim "  $(L '让代理流量经 Cloudflare WARP 出站：隐藏 VPS 出口 IP，并可解锁部分地区限制。' 'Send proxied traffic out through Cloudflare WARP: hides the VPS egress IP and can unlock geo-restricted sites.')"
        printf '\n'
        if ui_confirm "$(L '启用 WARP？' 'Enable WARP?')" n; then WARP_ENABLED="true"; else WARP_ENABLED="false"; fi
    fi
}

run_install() {
    detect_os
    detect_arch
    ensure_root "${ORIG_ARGS[@]}"
    have_systemctl || dev_mode || die "$(L '需要 systemd 或 OpenRC（找不到 systemctl / rc-service）。' 'systemd or OpenRC is required (no systemctl / rc-service found).')"
    normalize_settings

    show_header
    printf '  %s%s%s\n' "${C_BOLD}" "$(L '安装向导 —— 一路回车即可使用默认配置' 'Installer — just press Enter to accept the defaults')" "${C_RESET}"
    wizard_questions

    printf '\n'
    check_dependencies

    local tag="${SUDOKU_VERSION}"
    if [[ -z "${tag}" ]]; then
        tag=$(get_latest_tag "${SUDOKU_REPO}") || die "$(L '无法获取 Sudoku 最新版本（GitHub 不可达？）' 'Could not resolve the latest Sudoku release (GitHub unreachable?)')"
    fi
    ui_run "$(L "下载 Sudoku ${tag}" "Downloading Sudoku ${tag}")" install_sudoku_kernel "${tag}" || die "$(L '内核安装失败。' 'Kernel installation failed.')"

    generate_keypair || die "$(L '密钥生成失败。' 'Key generation failed.')"
    CUSTOM_TABLE=$(generate_xpv_table)

    if [[ "${CF_FALLBACK_ENABLED}" == "true" ]]; then
        CF_RESULT_FILE=$(mktemp)
        ui_run "$(L '部署伪装回落页' 'Deploying camouflage fallback page')" setup_cf_fallback || true
        if [[ -s "${CF_RESULT_FILE}" ]]; then SUDOKU_FALLBACK=$(<"${CF_RESULT_FILE}"); fi
        rm -f "${CF_RESULT_FILE}"
        CF_RESULT_FILE=""
    fi

    ui_run "$(L '生成服务端配置' 'Writing server config')" create_config || die "$(L '配置校验失败。' 'Config validation failed.')"

    if [[ "${WARP_ENABLED}" == "true" ]]; then
        remove_legacy_warp_tun_service
        ui_run "$(L '安装 sudoku-sing-box 内核' 'Installing sudoku-sing-box')" install_sing_box_kernel || die "$(L 'sudoku-sing-box 安装失败。' 'sudoku-sing-box installation failed.')"
        ui_run "$(L '注册 WARP 账户' 'Registering WARP account')" ensure_warp_profile || die "$(L 'WARP 注册失败。' 'WARP registration failed.')"
        ui_run "$(L '生成 WARP 出口配置' 'Writing WARP egress config')" write_sing_box_warp_config || die "$(L 'WARP 配置失败。' 'WARP config failed.')"
    fi

    if ! ui_run "$(L '启动服务' 'Starting service')" start_and_wait; then
        "${JOURNALCTL}" -u "$(svc_name)" -n 20 --no-pager 2>/dev/null | sed 's/^/      /' >&2 || true
        die "$(L '服务启动失败。' 'Service failed to start.')"
    fi
    configure_firewall "${SUDOKU_PORT}"

    info "$(L '检测公网地址…' 'Detecting public address…')"
    ensure_server_ip || die "$(L '缺少服务器地址，可设置 SERVER_IP 后重试。' 'No server address; set SERVER_IP and retry.')"
    SHORT_LINK=$(make_short_link "${AVAILABLE_PRIVATE_KEY}") || die "$(L '分享链接生成失败。' 'Failed to generate share link.')"
    generate_subscription_config >/dev/null 2>&1 || true
    persist_export_state
    mark_applied
    ver_set INSTALLED_AT "$(date +%s)"
    cleanup_legacy_subscription_https
    ui_run "$(L '安装管理面板 sudoku-dash' 'Installing sudoku-dash')" install_dash_self || record_nonfatal_issue "$(L 'dash 安装失败，可重新运行安装命令。' 'dash install failed; re-run the installer to retry.')"

    print_results
}

start_and_wait() {
    create_service || return 1
    wait_for_port "${SUDOKU_PORT}" 15
}

print_results() {
    local mode_label
    if [[ "${WARP_ENABLED}" == "true" ]]; then mode_label="WARP (sudoku-sing-box)"; else mode_label="$(L '直连' 'Direct')"; fi
    printf '\n'
    box_top "$(L 'Sudoku 已就绪' 'Sudoku is ready')"
    box_row "$(printf '%s%s%s %s' "${C_DIM}" "$(pad_right "$(L '服务器' 'Server')" 10)" "${C_RESET}" "$(join_host_port "${SERVER_IP}" "${SUDOKU_PORT}")")"
    box_row "$(printf '%s%s%s %s' "${C_DIM}" "$(pad_right "$(L '出口模式' 'Egress')" 10)" "${C_RESET}" "${mode_label}")"
    box_row "$(printf '%s%s%s %s' "${C_DIM}" "$(pad_right "$(L '内核版本' 'Kernel')" 10)" "${C_RESET}" "$(ver_get SUDOKU_VERSION)")"
    box_bottom
    printf '\n  %s%s%s\n\n' "${C_BOLD}" "$(L '客户端分享链接（复制到客户端导入）:' 'Client share link (import into your client):')" "${C_RESET}"
    printf '%s\n\n' "${SHORT_LINK}"
    printf '  %s%s%s\n' "${C_OK}" "$(L '管理用户 / 用量 / 带宽 / 版本，随时运行:' 'Manage users / usage / bandwidth / versions any time with:')" "${C_RESET}"
    printf '    %ssudo sudoku-dash%s\n' "${C_ACC}${C_BOLD}" "${C_RESET}"
    if ((${#NONFATAL_ISSUES[@]} > 0)); then
        printf '\n'
        warn "$(L '以下问题不影响使用:' 'Non-fatal issues:')"
        local issue
        for issue in "${NONFATAL_ISSUES[@]}"; do printf '    - %s\n' "${issue}" >&2; done
    fi
    printf '\n'
}

# ═══════════════════════════════════════════════════════════════════════════════
# Upgrade / rollback
# ═══════════════════════════════════════════════════════════════════════════════

latest_backup_file() { # <binary-name>
    ls -1t "${BACKUP_DIR}/${1}@"* 2>/dev/null | head -n 1
}

restore_backup() { # <binary-name> <version-key> [file]
    local name="$1" vkey="$2" file="${3:-}" ver
    [[ -n "${file}" ]] || file=$(latest_backup_file "${name}")
    [[ -n "${file}" && -f "${file}" ]] || return 1
    ver="${file##*/}"
    ver="${ver#"${name}"@}"
    ver="${ver%%@*}"
    cp -p "${file}" "${INSTALL_DIR}/${name}.new" && mv -f "${INSTALL_DIR}/${name}.new" "${INSTALL_DIR}/${name}" || return 1
    ver_set "${vkey}" "${ver}"
}

# upgrade_kernel <sudoku-tag> : download, migrate, restart; roll back automatically on failure.
upgrade_kernel() {
    local tag="$1" before
    before=$(ver_get SUDOKU_VERSION)
    ui_run "$(L "下载 Sudoku ${tag}" "Downloading Sudoku ${tag}")" install_sudoku_kernel "${tag}" || return 1
    migrate_legacy_httpmask_config_inplace "${CONFIG_FILE}" || true
    if [[ "${WARP_ENABLED}" == "true" ]]; then
        ui_run "$(L '更新 sudoku-sing-box' 'Updating sudoku-sing-box')" install_sing_box_kernel || warn "$(L 'sudoku-sing-box 更新失败，保留旧版本。' 'sudoku-sing-box update failed; keeping the old build.')"
        sync_singbox_users "${CONFIG_FILE}" "${SING_BOX_CONFIG_FILE}" || true
    fi
    local had_api
    had_api=$(cfg_get .external_controller)
    api_auto_enable
    if [[ -z "${had_api}" && -n "$(cfg_get .external_controller)" ]]; then
        info "$(L '已启用实时统计 API（仅 127.0.0.1）。' 'Enabled the live stats API (127.0.0.1 only).')"
    fi
    if ui_run "$(L '重启服务' 'Restarting service')" svc_restart; then
        return 0
    fi
    err "$(L '新版本启动失败，正在回滚…' 'New version failed to start; rolling back…')"
    if restore_backup sudoku SUDOKU_VERSION; then
        svc_restart >/dev/null 2>&1 && ok "$(L "已回滚到 ${before:-旧版本}" "Rolled back to ${before:-the previous build}")"
    fi
    return 1
}

cmd_upgrade() {
    detect_os; detect_arch; ensure_root "${ORIG_ARGS[@]}"
    has_existing_install || die "$(L '未检测到已安装的 Sudoku。' 'Sudoku is not installed.')"
    check_dependencies
    ctx_load
    local tag="${SUDOKU_VERSION}"
    [[ -n "${tag}" ]] || tag=$(get_latest_tag "${SUDOKU_REPO}") || die "$(L '无法获取最新版本。' 'Could not resolve the latest release.')"
    if [[ "$(ver_get SUDOKU_VERSION)" == "${tag}" ]]; then
        ok "$(L "已是最新版本 ${tag}" "Already on ${tag}")"
    else
        upgrade_kernel "${tag}" || die "$(L '升级失败。' 'Upgrade failed.')"
    fi
    ui_run "$(L '更新 sudoku-dash' 'Updating sudoku-dash')" install_dash_self || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# Uninstall
# ═══════════════════════════════════════════════════════════════════════════════

do_uninstall() { # <purge: 1|0>
    local purge="$1" port
    port=$(cfg_get .local_port)
    if have_systemctl; then
        local s
        for s in "${SERVICE_NAME}" "${SING_BOX_SERVICE_NAME}" "${FALLBACK_SERVICE_NAME}"; do
            "${SYSTEMCTL}" stop "${s}" >/dev/null 2>&1 || true
            "${SYSTEMCTL}" disable "${s}" >/dev/null 2>&1 || true
            rm -f "$(unit_path "${s}")" "${LOG_DIR}/${s}.log" "/etc/logrotate.d/${s}"
        done
        cleanup_legacy_subscription_https
        remove_legacy_warp_tun_service
        "${SYSTEMCTL}" daemon-reload >/dev/null 2>&1 || true
    fi
    [[ -n "${port}" ]] && remove_firewall_rule "${port}"
    rm -f "${INSTALL_DIR}/sudoku" "${INSTALL_DIR}/sudoku-sing-box"
    if [[ -n "$(ver_get WGCF_INSTALLED)" ]]; then rm -f "${INSTALL_DIR}/wgcf"; fi
    rm -rf "${FALLBACK_LIB_DIR}" "${SING_BOX_CACHE_DIR}"
    rm -f "${SING_BOX_CONFIG_FILE}"
    rmdir "${SING_BOX_CONFIG_DIR}" 2>/dev/null || true
    if [[ "${purge}" == "1" ]]; then
        rm -rf "${CONFIG_DIR}"
    else
        rm -rf "${BACKUP_DIR}"
    fi
    if [[ -L "${INSTALL_DIR}/dash" && "$(readlink "${INSTALL_DIR}/dash")" == "${DASH_BIN}" ]]; then
        rm -f "${INSTALL_DIR}/dash"
    fi
    rm -f "${DASH_BIN}"
}

cmd_uninstall() {
    detect_os; ensure_root "${ORIG_ARGS[@]}"
    has_existing_install || { info "$(L 'Sudoku 未安装，无需卸载。' 'Sudoku is not installed; nothing to remove.')"; return 0; }
    load_existing_config_context >/dev/null 2>&1 || true
    local purge=1
    if [[ "${UI_TTY}" == "1" && "${ASSUME_YES}" != "1" ]]; then
        printf '\n'
        ui_confirm "$(L '确认卸载 Sudoku？' 'Uninstall Sudoku?')" n || { info "$(L '已取消。' 'Cancelled.')"; return 0; }
        ui_confirm "$(L '同时删除配置与密钥（客户端将无法再连接）？' 'Also delete config and keys (clients will stop working)?')" y || purge=0
    fi
    ui_run "$(L '卸载 Sudoku' 'Removing Sudoku')" do_uninstall "${purge}" || return 1
    if [[ "${purge}" == "0" ]]; then
        info "$(L "配置已保留在 ${CONFIG_DIR}" "Config kept in ${CONFIG_DIR}")"
    fi
    ok "$(L '卸载完成。' 'Uninstall complete.')"
}

# ═══════════════════════════════════════════════════════════════════════════════
# dash: context, process stats
# ═══════════════════════════════════════════════════════════════════════════════

ctx_load() {
    load_existing_config_context || return 1
    USERS_CAP=""
    API_CAP=""
    return 0
}

CLK_TCK=$(getconf CLK_TCK 2>/dev/null || echo 100)
[[ "${CLK_TCK}" =~ ^[0-9]+$ ]] || CLK_TCK=100

proc_ticks() { # <pid> -> utime+stime ticks
    [[ -r "/proc/${1}/stat" ]] || return 1
    sed 's/^.*) //' "/proc/${1}/stat" | awk '{print $12 + $13}'
}
proc_rss() { awk '/^VmRSS:/ {print $2 * 1024}' "/proc/${1}/status" 2>/dev/null; }
proc_threads() { awk '/^Threads:/ {print $2}' "/proc/${1}/status" 2>/dev/null; }
proc_fds() { find "/proc/${1}/fd" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' '; }
proc_uptime() { # busybox ps has no etimes: derive from /proc
    local start up hz=100
    start=$(sed 's/^.*) //' "/proc/${1}/stat" 2>/dev/null | awk '{print $20}')
    up=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
    [[ "${start}" =~ ^[0-9]+$ && "${up}" =~ ^[0-9]+$ ]] || return 0
    command -v getconf >/dev/null 2>&1 && hz=$(getconf CLK_TCK 2>/dev/null || echo 100)
    echo $((up - start / hz))
}

conn_count() { # <port>
    ss -H -tn "( sport = :${1} )" 2>/dev/null | awk '$1 == "ESTAB" {n++} END {print n + 0}'
}

# cpu_sample <pid> <seconds> -> percent with one decimal ("3.2"), or empty
cpu_sample() {
    local t1 t2 d pct10
    t1=$(proc_ticks "$1") || return 1
    sleep "$2"
    t2=$(proc_ticks "$1") || return 1
    d=$((t2 - t1))
    pct10=$((d * 10000 / (CLK_TCK * ${3:-300})))
    printf '%d.%d' $((pct10 / 10)) $((pct10 % 10))
}

sys_load_line() {
    local load mem_total mem_avail
    [[ -r /proc/loadavg ]] || return 0
    load=$(awk '{print $1 " " $2 " " $3}' /proc/loadavg)
    mem_total=$(awk '/^MemTotal:/ {print $2 * 1024}' /proc/meminfo)
    mem_avail=$(awk '/^MemAvailable:/ {print $2 * 1024}' /proc/meminfo)
    printf '%s: %s · %s %s / %s' "$(L '负载' 'load')" "${load}" "$(L '内存' 'mem')" \
        "$(fmt_bytes $((mem_total - mem_avail)))" "$(fmt_bytes "${mem_total}")"
}

# ═══════════════════════════════════════════════════════════════════════════════
# User management (config.json `users` whitelist)
# ═══════════════════════════════════════════════════════════════════════════════

USERS_CAP=""

# sudoku_ver_ge_052 <tag>: does a "…sudoku.X.Y.Z…" tag include user control (≥0.5.2)?
sudoku_ver_ge_052() {
    local v
    v=$(printf '%s' "$1" | sed -n 's/.*sudoku\.\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
    [[ -n "${v}" ]] || return 1
    [[ "$(printf '%s\n0.5.2\n' "${v}" | sort -V | head -n 1)" == "0.5.2" ]]
}

users_capable() {
    if [[ -n "${USERS_CAP}" ]]; then [[ "${USERS_CAP}" == "yes" ]]; return $?; fi
    USERS_CAP="no"
    if [[ "${WARP_ENABLED}" == "true" ]]; then
        sudoku_ver_ge_052 "$(ver_get SING_BOX_VERSION)" && USERS_CAP="yes"
    elif [[ -x "${INSTALL_DIR}/sudoku" && -f "${CONFIG_FILE}" ]]; then
        # A kernel with user control rejects an invalid user key; older kernels ignore the field.
        local tmp out
        tmp=$(mktemp)
        if jq '.users = [{"key": "zz"}]' "${CONFIG_FILE}" >"${tmp}" 2>/dev/null; then
            out=$("${INSTALL_DIR}/sudoku" -c "${tmp}" -test 2>&1) || true
            if printf '%s' "${out}" | grep -q 'users\['; then USERS_CAP="yes"; fi
        fi
        rm -f "${tmp}"
    fi
    [[ "${USERS_CAP}" == "yes" ]]
}

# ── Live per-user stats from the kernel's REST API (external_controller, Sudoku ≥ 0.5.2 main) ──
API_CAP=""
API_BASE=""
API_SECRET=""
API_OK=0
API_COUNT=0
API_ACTIVE=0
API_UP=0
API_DOWN=0
API_USED_SUM=0
API_OFFERED=0
declare -a API_ROWS=()
declare -A API_BY_NAME=()
API_ROW=""
R_NAME="" R_BLOCKED="" R_EXCEEDED="" R_CONNS=0 R_UP=0 R_DOWN=0 R_UPT=0 R_DOWNT=0 R_USED=0 R_LIMIT=0

# Does the installed kernel know `external_controller`? Older ones ignore unknown keys; newer ones validate it.
controller_capable() {
    if [[ -n "${API_CAP}" ]]; then [[ "${API_CAP}" == "yes" ]]; return $?; fi
    API_CAP="no"
    if [[ "${WARP_ENABLED}" != "true" && -x "${INSTALL_DIR}/sudoku" && -f "${CONFIG_FILE}" ]]; then
        local tmp out
        tmp=$(mktemp)
        if jq '.external_controller = "zz"' "${CONFIG_FILE}" >"${tmp}" 2>/dev/null; then
            out=$("${INSTALL_DIR}/sudoku" -c "${tmp}" -test 2>&1) || true
            if printf '%s' "${out}" | grep -q 'external_controller'; then API_CAP="yes"; fi
        fi
        rm -f "${tmp}"
    fi
    [[ "${API_CAP}" == "yes" ]]
}

api_load() {
    local addr
    API_BASE=""; API_SECRET=""
    controller_capable || return 1
    addr=$(cfg_get .external_controller)
    [[ -n "${addr}" ]] || return 1
    API_SECRET=$(cfg_get .secret)
    case "${addr}" in
        :*) addr="127.0.0.1${addr}" ;;
        0.0.0.0:*) addr="127.0.0.1:${addr#0.0.0.0:}" ;;
        \[::\]:*) addr="[::1]:${addr#\[::\]:}" ;;
    esac
    API_BASE="http://${addr}"
}

api_get() { # <path>; the token goes through stdin so it never shows up in `ps`
    [[ -n "${API_BASE}" ]] || return 1
    if [[ -n "${API_SECRET}" ]]; then
        printf 'header = "Authorization: Bearer %s"\n' "${API_SECRET}" \
            | curl -fsS -K - --noproxy '*' --connect-timeout 1 --max-time 2 "${API_BASE}$1" 2>/dev/null
    else
        curl -fsS --noproxy '*' --connect-timeout 1 --max-time 2 "${API_BASE}$1" 2>/dev/null
    fi
}

api_fetch_users() {
    local json tag rest i=0
    API_OK=0; API_ROWS=(); API_BY_NAME=(); API_COUNT=0; API_ACTIVE=0; API_UP=0; API_DOWN=0; API_USED_SUM=0
    json=$(api_get /users) || return 1
    jq -e '.users | type == "array"' >/dev/null 2>&1 <<<"${json}" || return 1
    while IFS=$'\t' read -r tag rest; do
        case "${tag}" in
            H) IFS=$'\t' read -r API_COUNT API_ACTIVE API_UP API_DOWN <<<"${rest}" ;;
            U) API_ROWS+=("${rest}") ;;
        esac
    done < <(jq -r '"H\t\(.count)\t\(.active)\t\(.up)\t\(.down)",
        (.users[]? | "U\t\(.name)\t\([.blocked, .exceeded, .conns, .up, .down, .upTotal, .downTotal, .used, .limit] | map(tostring) | join("\t"))")' <<<"${json}" 2>/dev/null)
    [[ "${API_COUNT}" =~ ^[0-9]+$ ]] || return 1
    for ((i = 0; i < ${#API_ROWS[@]}; i++)); do
        IFS=$'\t' read -r R_NAME _ <<<"${API_ROWS[i]}"
        API_BY_NAME["${R_NAME}"]="${i}"
    done
    API_USED_SUM=$(jq -r '[.users[]?.used] | add // 0' <<<"${json}" 2>/dev/null || echo 0)
    API_OK=1
}

api_refresh() {
    API_OK=0
    api_load || return 1
    svc_is_active || return 1
    api_fetch_users
}

# api_row_for <config index> <alias>: load that user's live row into R_*; fails if the API has no matching entry.
api_row_for() {
    local idx=""
    API_ROW=""
    ((API_OK)) || return 1
    if [[ -n "$2" ]]; then
        [[ -n "${API_BY_NAME[$2]+x}" ]] && idx="${API_BY_NAME[$2]}"
    elif ! config_dirty && ((API_COUNT == $(users_count))); then
        idx="$1"
    fi
    [[ -n "${idx}" ]] || return 1
    API_ROW="${API_ROWS[idx]}"
    IFS=$'\t' read -r R_NAME R_BLOCKED R_EXCEEDED R_CONNS R_UP R_DOWN R_UPT R_DOWNT R_USED R_LIMIT <<<"${API_ROW}"
}

api_enable() { # loopback-only random port + random token
    local port="" secret lport
    lport=$(cfg_get .local_port)
    for _ in 1 2 3 4 5 6 7 8; do
        port=$(pick_random_high_port) || return 1
        [[ "${port}" != "${lport}" ]] && break
    done
    secret=$(openssl rand -hex 16 2>/dev/null) || return 1
    cfg_edit --arg a "127.0.0.1:${port}" --arg s "${secret}" '. + {external_controller: $a, secret: $s}' || return 1
    api_load || true
}

# Turn the API on when the kernel has it and the config does not (used after install / upgrade).
api_auto_enable() {
    API_CAP=""
    controller_capable || return 0
    [[ -z "$(cfg_get .external_controller)" ]] || return 0
    api_enable || true
}

api_offer_enable() { # once per dash session, from the Users screen
    ((API_OFFERED)) && return 0
    API_OFFERED=1
    controller_capable || return 0
    [[ -z "$(cfg_get .external_controller)" ]] || return 0
    printf '\n'
    info "$(L '内核支持实时统计 API：可按用户显示在线状态、实时速率和本月已用流量。' 'The kernel has a stats API: per-user online state, live rates and this month'\''s usage.')"
    ui_confirm "$(L '启用？（仅监听 127.0.0.1，随机端口与令牌；需重启服务）' 'Enable it? (127.0.0.1 only, random port and token; restarts the service)')" y || return 0
    if api_enable; then
        ui_run "$(L '重启服务' 'Restarting service')" svc_restart || warn "$(L '重启失败，请到主菜单重启。' 'Restart failed; restart from the main menu.')"
    else
        err "$(L '写入配置失败，已回滚。' 'Failed to write config; rolled back.')"
    fi
}

# Quota is in decimal GB (1e9), so usage is shown in decimal units to match.
fmt_dbytes() { # <bytes> -> "12.34 GB"
    local b="${1:-0}" unit=0 scaled
    local -a units=(B KB MB GB TB PB)
    scaled=$((b * 100))
    while ((scaled >= 100000 && unit < 5)); do
        scaled=$((scaled / 1000))
        unit=$((unit + 1))
    done
    if ((unit == 0)); then printf '%d B' "${b}"; return 0; fi
    printf '%d.%02d %s' $((scaled / 100)) $((scaled % 100)) "${units[unit]}"
}

fmt_dquota() { fmt_dbytes "$1" | sed 's/\.00 / /'; }

quota_pct() { # used limit -> 0..n
    ((${2:-0} > 0)) || { printf '0'; return 0; }
    printf '%d' $((${1:-0} * 100 / ${2}))
}

quota_bar() { # <pct> <width>
    local pct="${1:-0}" w="${2:-20}" f on off col="${C_OK}"
    ((pct > 100)) && pct=100
    f=$((pct * w / 100))
    if [[ "${UI_UTF8}" == "1" ]]; then on="█"; off="░"; else on="#"; off="-"; fi
    ((pct >= 80)) && col="${C_WARN}"
    ((pct >= 100)) && col="${C_ERR}"
    printf '%s%s%s%s%s' "${col}" "$(rep "${on}" "${f}")" "${C_DIM}" "$(rep "${off}" $((w - f)))" "${C_RESET}"
}

month_reset_date() { # first day of next month (server local time, when the monthly counters reset)
    local y m
    y=$(date +%Y); m=$((10#$(date +%m)))
    if ((m == 12)); then y=$((y + 1)); m=1; else m=$((m + 1)); fi
    printf '%04d-%02d-01' "${y}" "${m}"
}

rate_cell() { # <bytes/s>
    if ((${1:-0} > 0)); then fmt_rate "$1"; else printf '%s-%s' "${C_DIM}" "${C_RESET}"; fi
}

api_state_text() { # uses R_*
    if [[ "${R_BLOCKED}" == "true" ]]; then printf '%s%s%s' "${C_ERR}" "$(L '已封禁' 'blocked')" "${C_RESET}"
    elif [[ "${R_EXCEEDED}" == "true" ]]; then printf '%s%s%s' "${C_WARN}" "$(L '已超额' 'exceeded')" "${C_RESET}"
    elif ((R_CONNS > 0)); then printf '%s%s %s%s' "${C_OK}" "${G_DOT}" "$(L '在线' 'online')" "${C_RESET}"
    else printf '%s%s %s%s' "${C_DIM}" "${G_RING}" "$(L '空闲' 'idle')" "${C_RESET}"; fi
}

users_count() { jq -r '(.users // []) | length' "${CONFIG_FILE}" 2>/dev/null || echo 0; }
users_blocked_count() { jq -r '[(.users // [])[] | select(.blocked == true)] | length' "${CONFIG_FILE}" 2>/dev/null || echo 0; }
user_field() { jq -r --argjson i "$1" ".users[\$i]${2} // empty" "${CONFIG_FILE}" 2>/dev/null; }

cfg_edit() { # jq-args... : atomic edit of config.json, validated with `sudoku -test`, rolled back on failure
    local tmp bak out
    tmp=$(mktemp)
    bak="${CONFIG_FILE}.bak"
    if ! jq "$@" "${CONFIG_FILE}" >"${tmp}"; then
        rm -f "${tmp}"
        return 1
    fi
    cp -p "${CONFIG_FILE}" "${bak}"
    chmod 600 "${tmp}"
    mv "${tmp}" "${CONFIG_FILE}"
    if ! out=$("${INSTALL_DIR}/sudoku" -c "${CONFIG_FILE}" -test 2>&1); then
        printf '%s\n' "${out}" >&2
        cp -p "${bak}" "${CONFIG_FILE}"
        return 1
    fi
}

USERS_CLEANUP='| if ((.users // []) | length) == 0 then del(.users) else . end'

user_alias_exists() { jq -e --arg a "$1" '(.users // []) | map(.alias) | index($a) != null' "${CONFIG_FILE}" >/dev/null 2>&1; }
user_key_exists() { jq -e --arg k "${1,,}" '(.users // []) | map((.key // "") | ascii_downcase) | index($k) != null' "${CONFIG_FILE}" >/dev/null 2>&1; }
is_new_alias() {
    is_alias "$1" || return 1
    if user_alias_exists "$1"; then err "$(L '该用户名已存在。' 'That alias already exists.')"; return 1; fi
}
is_new_key() {
    is_optional_hex_key "$1" || return 1
    if [[ -n "$1" ]] && user_key_exists "$1"; then err "$(L '该密钥已被其他用户使用。' 'That key is already used by another user.')"; return 1; fi
}

# limits_json <down> <up> -> "null" or "[down,up]"
limits_json() {
    local d="${1:-0}" u="${2:-0}"
    [[ -n "${d}" ]] || d=0
    [[ -n "${u}" ]] || u=0
    if [[ "${d}" == 0 && "${u}" == 0 ]]; then printf 'null'; else printf '[%s,%s]' "${d}" "${u}"; fi
}

users_apply() {
    if [[ "${WARP_ENABLED}" == "true" ]]; then
        sync_singbox_users "${CONFIG_FILE}" "${SING_BOX_CONFIG_FILE}" || return 1
        "${INSTALL_DIR}/sudoku-sing-box" check -c "${SING_BOX_CONFIG_FILE}" || return 1
    fi
    svc_restart
}

users_apply_prompt() {
    if ui_confirm "$(L '立即应用？（会重启服务，现有连接将短暂中断）' 'Apply now? (restarts the service; live connections drop briefly)')" y; then
        if ui_run "$(L '应用配置并重启' 'Applying config and restarting')" users_apply; then return 0; fi
        warn "$(L '应用失败，配置已保存但服务可能仍在使用旧配置。' 'Apply failed; the config is saved but the service may still run the old one.')"
    else
        warn "$(L '已保存，稍后在主菜单重启生效。' 'Saved; restart from the main menu to take effect.')"
    fi
}

# First user turns the whitelist on, which locks out every key not listed: keep the default key working.
seed_default_user() {
    [[ "$(users_count)" == "0" ]] || return 0
    [[ -n "${AVAILABLE_PRIVATE_KEY}" ]] || return 0
    cfg_edit --arg k "${AVAILABLE_PRIVATE_KEY}" '.users = [{alias: "default", key: $k}]' || return 1
    info "$(L '已将安装时的默认密钥加入用户列表（alias: default），避免现有客户端被锁出。' 'Your install-time key was added as user "default" so existing clients keep working.')"
}

user_add() {
    local alias key down up data bw
    ui_clear; box_top "$(L '添加用户' 'Add user')"; box_row "$(L '每个用户拥有独立密钥，可单独限速 / 限流量 / 封禁。' 'Each user gets their own key with optional speed / data limits.')"; box_bottom
    printf '\n'
    ui_ask "$(L '用户名' 'Alias')" "" is_new_alias; alias="${ASK_RESULT}"
    ui_ask "$(L '客户端密钥（留空自动生成）' 'Client key (empty = generate)')" "" is_new_key; key="${ASK_RESULT}"
    ui_ask "$(L '下行限速 Mbps（0 = 不限）' 'Download limit Mbps (0 = unlimited)')" "0" is_nonneg_number; down="${ASK_RESULT}"
    ui_ask "$(L '上行限速 Mbps（0 = 不限）' 'Upload limit Mbps (0 = unlimited)')" "0" is_nonneg_number; up="${ASK_RESULT}"
    ui_ask "$(L '总流量上限 GB（0 = 不限）' 'Data quota GB (0 = unlimited)')" "0" is_nonneg_number; data="${ASK_RESULT}"
    if [[ -z "${key}" ]]; then
        key=$(generate_split_key) || { err "$(L '密钥生成失败。' 'Key generation failed.')"; return 1; }
    fi
    seed_default_user || { err "$(L '写入配置失败。' 'Failed to write config.')"; return 1; }
    bw=$(limits_json "${down}" "${up}")
    cfg_edit --arg alias "${alias}" --arg key "${key}" --argjson bw "${bw}" --argjson data "${data}" '
        .users = ((.users // []) + [
            {alias: $alias, key: $key}
            + (if $bw then {bandwidth: $bw} else {} end)
            + (if $data > 0 then {data: $data} else {} end)
        ])' || { err "$(L '配置校验失败，已回滚。' 'Config validation failed; rolled back.')"; return 1; }
    ok "$(L "已添加用户 ${alias}" "Added user ${alias}")"
    users_apply_prompt
    show_user_link "${key}" "${alias}"
}

user_edit_limits() { # <index>
    local i="$1" down up data bw cur_d cur_u cur_data
    cur_d=$(user_field "${i}" '.bandwidth[0]'); cur_u=$(user_field "${i}" '.bandwidth[1]'); cur_data=$(user_field "${i}" '.data')
    printf '\n'
    ui_ask "$(L '下行限速 Mbps（0 = 不限）' 'Download limit Mbps (0 = unlimited)')" "${cur_d:-0}" is_nonneg_number; down="${ASK_RESULT}"
    ui_ask "$(L '上行限速 Mbps（0 = 不限）' 'Upload limit Mbps (0 = unlimited)')" "${cur_u:-0}" is_nonneg_number; up="${ASK_RESULT}"
    ui_ask "$(L '总流量上限 GB（0 = 不限）' 'Data quota GB (0 = unlimited)')" "${cur_data:-0}" is_nonneg_number; data="${ASK_RESULT}"
    bw=$(limits_json "${down}" "${up}")
    cfg_edit --argjson i "${i}" --argjson bw "${bw}" --argjson data "${data}" "
        .users[\$i] |= (del(.bandwidth, .data)
            + (if \$bw then {bandwidth: \$bw} else {} end)
            + (if \$data > 0 then {data: \$data} else {} end))" || { err "$(L '配置校验失败，已回滚。' 'Config validation failed; rolled back.')"; return 1; }
    ok "$(L '限制已更新' 'Limits updated')"
    users_apply_prompt
}

user_toggle_block() { # <index>
    local i="$1"
    cfg_edit --argjson i "${i}" '.users[$i] |= (if .blocked == true then del(.blocked) else . + {blocked: true} end)' \
        || { err "$(L '配置校验失败，已回滚。' 'Config validation failed; rolled back.')"; return 1; }
    ok "$(L '状态已切换' 'State toggled')"
    users_apply_prompt
}

user_delete() { # <index>
    local i="$1" alias remaining
    alias=$(user_field "${i}" '.alias')
    remaining=$(($(users_count) - 1))
    if ((remaining == 0)); then
        warn "$(L '这是最后一个用户：删除后用户白名单将关闭，任何有效密钥都能连接。' 'This is the last user: removing it turns the whitelist off and any valid key can connect again.')"
    fi
    ui_confirm "$(L "确认删除用户 ${alias}？" "Delete user ${alias}?")" n || return 0
    cfg_edit --argjson i "${i}" "del(.users[\$i]) ${USERS_CLEANUP}" || { err "$(L '配置校验失败，已回滚。' 'Config validation failed; rolled back.')"; return 1; }
    ok "$(L "已删除 ${alias}" "Deleted ${alias}")"
    users_apply_prompt
}

# Per-user activity from the journal: session starts, last seen, quota/limit events. This is the
# only per-user signal on kernels without the stats API; with the API it still supplies "last seen".
declare -A ACT_N=() ACT_LAST=() ACT_Q=()
collect_activity() {
    ACT_N=(); ACT_LAST=(); ACT_Q=()
    have_systemctl || return 0
    local alias n last q
    while IFS=$'\t' read -r alias n last q; do
        [[ -n "${alias}" ]] || continue
        ACT_N["${alias}"]="${n}"; ACT_LAST["${alias}"]="${last}"; ACT_Q["${alias}"]="${q}"
    done < <("${JOURNALCTL}" -u "$(svc_name)" --since "24 hours ago" -o short-iso --no-pager 2>/dev/null | awk '
        {
            low = tolower($0)
            if (match($0, /\[User:[^]]*\]/)) {
                a = substr($0, RSTART + 6, RLENGTH - 7)
                if (low ~ /session start/) n[a]++
            } else if (match($0, /inbound Sudoku user [^ ]+ from/)) {
                a = substr($0, RSTART + 20, RLENGTH - 25)
                n[a]++
            } else next
            if (low ~ /quota|exceed|limit/) q[a] = 1
            last[a] = $1
            seen[a] = 1
        }
        END { for (a in seen) printf "%s\t%d\t%s\t%d\n", a, n[a], last[a], q[a] }')
}

fmt_limits() { # down up data
    local out=""
    if [[ "${1:-0}" != 0 || "${2:-0}" != 0 ]]; then out="${G_DN}${1:-0}/${G_UP}${2:-0}M"; else out="∞"; fi
    printf '%s' "${out}"
}

user_speed_text() { # down up
    if [[ "${1:-0}" == 0 && "${2:-0}" == 0 ]]; then
        L '不限速' 'unlimited'
    else
        printf '%s %s Mbps / %s %s Mbps' "${G_DN}" "${1:-0}" "${G_UP}" "${2:-0}"
    fi
}

users_table() {
    if ((API_OK)); then users_table_live; else users_table_static; fi
}

users_table_live() {
    local i=0 alias key down up data blocked hdr state dn upr used lim pct cell
    printf -v hdr '%s %s %s %s %s %s' "$(pad_right '#' 2)" "$(pad_right "$(L '用户' 'User')" 11)" "$(pad_right "$(L '状态' 'State')" 9)" \
        "$(pad_right "${G_DN} $(L '下载' 'Down')" 11)" "$(pad_right "${G_UP} $(L '上传' 'Up')" 11)" "$(L '本月已用 / 额度' 'Month used / quota')"
    box_top "$(L '用户' 'Users')"
    box_row "${C_DIM}${hdr}${C_RESET}"
    box_sep
    while IFS=$'\t' read -r alias key down up data blocked; do
        [[ "${alias}" == "-" ]] && alias=""
        if api_row_for "${i}" "${alias}"; then
            state=$(api_state_text); dn=$(rate_cell "${R_DOWN}"); upr=$(rate_cell "${R_UP}")
            used=$(fmt_dbytes "${R_USED}")
            if ((R_LIMIT > 0)); then
                pct=$(quota_pct "${R_USED}" "${R_LIMIT}")
                cell="${used} / $(fmt_dquota "${R_LIMIT}")"
                ((pct >= 100)) && cell="${C_ERR}${cell}${C_RESET}" || { ((pct >= 80)) && cell="${C_WARN}${cell}${C_RESET}"; }
            else
                cell="${used} ${C_DIM}/ ∞${C_RESET}"
            fi
        else
            if [[ "${blocked}" == "true" ]]; then state="${C_ERR}$(L '已封禁' 'blocked')${C_RESET}"; else state="${C_DIM}$(L '待重启' 'pending')${C_RESET}"; fi
            dn="${C_DIM}-${C_RESET}"; upr="${C_DIM}-${C_RESET}"
            cell="${C_DIM}-$([[ "${data}" != 0 ]] && printf ' / %sG' "${data}")${C_RESET}"
        fi
        box_row "$(pad_right "$((i + 1))" 2) $(pad_right "$(name=${alias:-${key:0:8}}; printf '%s' "${name:0:11}")" 11) $(pad_right "${state}" 9) $(pad_right "${dn}" 11) $(pad_right "${upr}" 11) ${cell}"
        i=$((i + 1))
    done < <(jq -r '(.users // [])[] | [(.alias // "-"), (.key // ""), (.bandwidth[0] // 0), (.bandwidth[1] // 0), (.data // 0), (.blocked // false)] | @tsv' "${CONFIG_FILE}")
    box_sep
    lim=$(printf '%s %s · %s %s · %s %s' "${API_ACTIVE}" "$(L '在线' 'online')" "${G_DN}$(fmt_rate "${API_DOWN}")" "${G_UP}$(fmt_rate "${API_UP}")" "$(L '全部用户本月' 'all users this month')" "$(fmt_dbytes "${API_USED_SUM}")")
    box_row "${C_DIM}${lim}${C_RESET}"
    box_bottom
}

users_table_static() {
    local i=0 alias key down up data blocked state lim quota sess hdr
    printf -v hdr '%s %s %s %s %s %s %s' "$(pad_right '#' 2)" "$(pad_right "$(L '用户' 'User')" 14)" "$(pad_right 'Key' 9)" \
        "$(pad_right "$(L '限速' 'Speed')" 12)" "$(pad_right "$(L '流量' 'Quota')" 7)" "$(pad_right "$(L '状态' 'State')" 8)" "$(if init_is_openrc; then L '会话' 'Sess'; else L '24h会话' '24h'; fi)"
    box_top "$(L '用户' 'Users')"
    box_row "${C_DIM}${hdr}${C_RESET}"
    box_sep
    while IFS=$'\t' read -r alias key down up data blocked; do
        [[ "${alias}" == "-" ]] && alias="${key:0:8}"
        if [[ "${blocked}" == "true" ]]; then state="${C_ERR}$(L '已封禁' 'blocked')${C_RESET}"; else state="${C_OK}$(L '正常' 'active')${C_RESET}"; fi
        lim=$(fmt_limits "${down}" "${up}")
        if [[ "${data}" != 0 ]]; then quota="${data}G"; else quota="∞"; fi
        sess="${ACT_N[${alias}]:-0}"
        [[ "${ACT_Q[${alias}]:-0}" == "1" ]] && sess="${sess}${C_WARN}!${C_RESET}"
        box_row "$(pad_right "$((i + 1))" 2) $(pad_right "${alias:0:14}" 14) $(pad_right "${key:0:8}" 9) $(pad_right "${lim}" 12) $(pad_right "${quota}" 7) $(pad_right "${state}" 8) ${sess}"
        i=$((i + 1))
    done < <(jq -r '(.users // [])[] | [(.alias // "-"), (.key // ""), (.bandwidth[0] // 0), (.bandwidth[1] // 0), (.data // 0), (.blocked // false)] | @tsv' "${CONFIG_FILE}")
    box_bottom
}

user_detail() { # <index>
    local i="$1" alias key blocked pct
    while :; do
        alias=$(user_field "${i}" '.alias'); key=$(user_field "${i}" '.key'); blocked=$(user_field "${i}" '.blocked')
        [[ -n "${key}" ]] || return 0
        api_refresh || true
        collect_activity
        ui_clear
        box_top "$(L "用户: ${alias:-${key:0:8}}" "User: ${alias:-${key:0:8}}")"
        kv "$(L '密钥' 'Key')" "${key:0:16}…"
        if api_row_for "${i}" "${alias}"; then
            kv "$(L '状态' 'State')" "$(api_state_text)$( ((R_CONNS > 0)) && printf '  %s%s %s%s' "${C_DIM}" "${R_CONNS}" "$(L '个连接' 'connections')" "${C_RESET}")"
            kv "$(L '实时速率' 'Live rate')" "${G_DN} $(fmt_rate "${R_DOWN}")   ${G_UP} $(fmt_rate "${R_UP}")"
            if ((R_LIMIT > 0)); then
                pct=$(quota_pct "${R_USED}" "${R_LIMIT}")
                kv "$(L '本月已用' 'Used this month')" "$(fmt_dbytes "${R_USED}") / $(fmt_dquota "${R_LIMIT}")  ${pct}%"
                kv "" "$(quota_bar "${pct}" 30)"
                if ((R_USED < R_LIMIT)); then
                    kv "$(L '本月剩余' 'Remaining')" "$(fmt_dbytes $((R_LIMIT - R_USED)))"
                else
                    kv "$(L '本月剩余' 'Remaining')" "${C_ERR}$(L '已用完，新连接会被拒绝' 'used up; new connections are refused')${C_RESET}"
                fi
                kv "$(L '额度重置' 'Resets on')" "$(month_reset_date) $(L '（服务器本地时间 0 点）' '(server local time, 00:00)')"
            else
                kv "$(L '本月已用' 'Used this month')" "$(fmt_dbytes "${R_USED}") ${C_DIM}($(L '无额度限制' 'no quota'))${C_RESET}"
                kv "$(L '统计重置' 'Counter resets')" "$(month_reset_date)"
            fi
            kv "$(L '本次运行累计' 'Since start')" "${G_DN} $(fmt_dbytes "${R_DOWNT}")   ${G_UP} $(fmt_dbytes "${R_UPT}")"
        else
            kv "$(L '状态' 'State')" "$([[ "${blocked}" == "true" ]] && L '已封禁' 'blocked' || L '正常' 'active')$( ((API_OK)) && printf '  %s%s%s' "${C_DIM}" "$(L '（实时数据待重启后出现）' '(live data appears after a restart)')" "${C_RESET}")"
            kv "$(L '流量上限' 'Quota')" "$(user_field "${i}" '.data' | sed 's/^$/∞/') GB"
        fi
        kv "$(L '限速' 'Speed')" "$(user_speed_text "$(user_field "${i}" '.bandwidth[0]')" "$(user_field "${i}" '.bandwidth[1]')")"
        if [[ -n "${ACT_LAST[${alias}]:-}" ]]; then
            kv "$(if init_is_openrc; then L '会话（日志）' 'Sessions (log)'; else L '24h 会话' 'Sessions 24h'; fi)" "${ACT_N[${alias}]:-0}"
            kv "$(L '最近活动' 'Last seen')" "${ACT_LAST[${alias}]}"
        fi
        box_bottom
        if ! ((API_OK)); then dim "  $(api_hint)"; fi
        printf '\n'
        ui_menu "$(L '刷新' 'Refresh')" "$(L '修改限速 / 流量' 'Edit limits / quota')" \
            "$([[ "${blocked}" == "true" ]] && L '解除封禁' 'Unblock' || L '封禁' 'Block')" \
            "$(L '分享链接' 'Share link')" "$(L '删除用户' 'Delete user')" "$(L '返回' 'Back')"
        case "${MENU_SEL}" in
            0) ;;
            1) user_edit_limits "${i}"; ui_pause ;;
            2) user_toggle_block "${i}"; ui_pause ;;
            3) show_user_link "${key}" "${alias}" ;;
            4) user_delete "${i}"; ui_pause; return 0 ;;
            *) return 0 ;;
        esac
    done
}

# Why per-user live numbers are missing right now.
api_hint() {
    if [[ "${WARP_ENABLED}" == "true" ]]; then
        L '提示: WARP 模式（sudoku-sing-box）没有统计 API，这里仅显示日志统计；切回直连模式可获得实时数据。' 'Note: WARP mode (sudoku-sing-box) has no stats API, so only log-derived counts are shown; switch to direct mode for live data.'
    elif ! controller_capable; then
        L '提示: 当前内核没有统计 API（需要带 external_controller 的 Sudoku，当前 release v0.5.1 尚不含）。' 'Note: this kernel has no stats API (needs a Sudoku build with external_controller; release v0.5.1 predates it).'
    elif [[ -z "$(cfg_get .external_controller)" ]]; then
        L '提示: 统计 API 未启用，进入「用户」页面可一键启用。' 'Note: the stats API is off; open the Users screen to enable it.'
    elif ! svc_is_active; then
        L '提示: 服务未运行，无法读取实时数据。' 'Note: the service is not running, so there is no live data.'
    else
        L '提示: 统计 API 暂无响应（刚启动 / 配置已改未重启？）。' 'Note: the stats API is not answering (just started, or config changed without a restart?).'
    fi
}

users_screen() {
    local n i
    if users_capable; then api_offer_enable; fi
    while :; do
        api_refresh || true
        collect_activity
        ui_clear
        if ! users_capable; then
            box_top "$(L '用户管理' 'User management')"
            box_row "$(L '当前内核不支持用户控制（Sudoku 需 ≥ 0.5.2）。' 'This kernel has no user control (needs Sudoku ≥ 0.5.2).')"
            box_row "$(L '升级到支持版本，或启用 WARP 模式（自带支持）后再来。' 'Upgrade to a supporting build, or enable WARP mode (bundled sudoku-sing-box).')"
            box_bottom
            ui_pause
            return 0
        fi
        n=$(users_count)
        if ((n > 0)); then
            users_table
        else
            box_top "$(L '用户' 'Users')"
            box_row "$(L '尚未创建用户：当前所有持有效密钥的客户端都可连接。' 'No users yet: any client with a valid key can connect.')"
            box_row "$(L '添加第一个用户后将启用白名单。' 'Adding the first user turns the whitelist on.')"
            box_bottom
        fi
        if config_dirty; then warn "$(L '有未应用的更改（重启服务生效）。' 'Unapplied changes (restart to take effect).')"; fi
        if ! ((API_OK)); then dim "  $(api_hint)"; fi
        printf '\n'
        if ((n > 0)); then
            ui_menu "$(L '添加用户' 'Add user')" "$(L '查看 / 管理用户' 'Open a user')" "$(L '刷新' 'Refresh')" "$(L '返回' 'Back')"
            case "${MENU_SEL}" in
                0) user_add; ui_pause ;;
                2) ;;
                1)
                    local -a items=()
                    for ((i = 0; i < n; i++)); do items+=("$((i + 1)). $(user_field "${i}" '.alias')"); done
                    items+=("$(L '返回' 'Back')")
                    ui_menu "${items[@]}"
                    if ((MENU_SEL >= 0 && MENU_SEL < n)); then user_detail "${MENU_SEL}"; fi
                    ;;
                *) return 0 ;;
            esac
        else
            ui_menu "$(L '添加用户' 'Add user')" "$(L '返回' 'Back')"
            case "${MENU_SEL}" in
                0) user_add; ui_pause ;;
                *) return 0 ;;
            esac
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# Share / connection info
# ═══════════════════════════════════════════════════════════════════════════════

render_node_yaml_for() { # <key> <name>
    local saved_key="${AVAILABLE_PRIVATE_KEY}" saved_name="${SUBSCRIPTION_NODE_NAME}"
    AVAILABLE_PRIVATE_KEY="$1"
    SUBSCRIPTION_NODE_NAME="$2"
    render_node_yaml
    AVAILABLE_PRIVATE_KEY="${saved_key}"
    SUBSCRIPTION_NODE_NAME="${saved_name}"
}

show_user_link() { # <key> <label>
    local key="$1" label="${2:-sudoku}" link
    if ! is_hex_key "${key}" || ((${#key} < 64)); then
        warn "$(L '该用户只保存了密钥哈希，无法生成分享链接。' 'This user only has a key hash stored; a share link cannot be built.')"
        ui_pause
        return 0
    fi
    ensure_server_ip || { err "$(L '缺少服务器地址。' 'Missing server address.')"; ui_pause; return 1; }
    link=$(make_short_link "${key}") || { err "$(L '分享链接生成失败。' 'Failed to generate share link.')"; ui_pause; return 1; }
    ui_clear
    box_top "$(L "分享: ${label}" "Share: ${label}")"
    kv "$(L '服务器' 'Server')" "$(join_host_port "${SERVER_IP}" "${SUDOKU_PORT}")"
    box_bottom
    printf '\n  %s%s%s\n\n%s\n\n' "${C_BOLD}" "$(L '分享链接:' 'Share link:')" "${C_RESET}" "${link}"
    if command -v qrencode >/dev/null 2>&1; then
        qrencode -t ANSIUTF8 -m 1 "${link}" 2>/dev/null || true
    fi
    if ui_confirm "$(L '显示 Mihomo 节点 YAML？' 'Show the Mihomo node YAML?')" n; then
        printf '\n'
        render_node_yaml_for "${key}" "${label}" | sed 's/^/  /'
    fi
    ui_pause
}

share_screen() {
    local n i
    n=$(users_count)
    if ((n == 0)); then
        [[ -n "${AVAILABLE_PRIVATE_KEY}" ]] || { err "$(L '找不到默认密钥（export-state.env）。' 'Default key not found (export-state.env).')"; ui_pause; return 1; }
        show_user_link "${AVAILABLE_PRIVATE_KEY}" "${SUBSCRIPTION_NODE_NAME}"
        return 0
    fi
    ui_clear
    box_top "$(L '选择要分享的用户' 'Choose a user to share')"
    box_bottom
    printf '\n'
    local -a items=()
    for ((i = 0; i < n; i++)); do items+=("$((i + 1)). $(user_field "${i}" '.alias')"); done
    items+=("$(L '返回' 'Back')")
    ui_menu "${items[@]}"
    if ((MENU_SEL >= 0 && MENU_SEL < n)); then
        show_user_link "$(user_field "${MENU_SEL}" '.key')" "$(user_field "${MENU_SEL}" '.alias')"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Overview
# ═══════════════════════════════════════════════════════════════════════════════

kv() { box_row "$(printf '%s%s%s %s' "${C_DIM}" "$(pad_right "$1" 15)" "${C_RESET}" "$2")"; }

render_overview() {
    local pid="" up="" state line port cpu="" rss="" conns n nb
    port=$(cfg_get .local_port)
    if svc_is_active; then
        pid=$(svc_pid || true)
        [[ -n "${pid}" ]] && up=$(proc_uptime "${pid}")
        line="${C_OK}${G_DOT} $(L '运行中' 'Running')${C_RESET}"
        [[ -n "${pid}" ]] && line+="  ${C_DIM}pid ${pid}${up:+ · $(fmt_duration "${up}")}${C_RESET}"
    else
        line="${C_ERR}${G_RING} $(L '已停止' 'Stopped')${C_RESET}"
    fi
    box_top "Sudoku dash v${DASH_VERSION}"
    kv "$(L '状态' 'Status')" "${line}"
    kv "$(L '出口模式' 'Egress')" "$([[ "${WARP_ENABLED}" == "true" ]] && echo 'WARP (sudoku-sing-box)' || L '直连' 'Direct')"
    kv "$(L '监听' 'Listen')" "$([[ -n "${SERVER_IP}" ]] && join_host_port "${SERVER_IP}" "${port}" || echo ":${port}")"
    kv "$(L '内核' 'Kernel')" "sudoku $(ver_get SUDOKU_VERSION | sed 's/^$/?/')$([[ "${WARP_ENABLED}" == "true" ]] && printf ' · sing-box %s' "$(ver_get SING_BOX_VERSION | sed 's/^$/?/')")"
    if [[ -n "${pid}" && -r "/proc/${pid}/stat" ]]; then
        cpu=$(cpu_sample "${pid}" 0.3 300 || true)
        rss=$(proc_rss "${pid}")
        conns=$(conn_count "${port}")
        kv "$(L '占用' 'Resources')" "CPU ${cpu:-?}% · $(L '内存' 'RAM') $(fmt_bytes "${rss:-0}") · $(L '连接' 'conns') ${conns:-0} · $(L '线程' 'thr') $(proc_threads "${pid}")"
    fi
    n=$(users_count); nb=$(users_blocked_count)
    api_refresh || true
    if ((n > 0)); then
        line="${n}"
        ((nb > 0)) && line+=" ($(L "${nb} 个已封禁" "${nb} blocked"))"
        if ((API_OK)); then
            line+=" · ${C_OK}${API_ACTIVE} $(L '在线' 'online')${C_RESET}"
        fi
        kv "$(L '用户' 'Users')" "${line}"
        if ((API_OK)); then
            kv "$(L '用户流量' 'User traffic')" "${G_DN} $(fmt_rate "${API_DOWN}")  ${G_UP} $(fmt_rate "${API_UP}") ${C_DIM}· $(L '本月' 'month') $(fmt_dbytes "${API_USED_SUM}")${C_RESET}"
        fi
    elif users_capable; then
        kv "$(L '用户' 'Users')" "$(L '未启用白名单（任意有效密钥可连接）' 'whitelist off (any valid key connects)')"
    else
        kv "$(L '用户' 'Users')" "$(L '单密钥（内核不支持用户控制）' 'single key (kernel has no user control)')"
    fi
    if controller_capable && [[ -z "$(cfg_get .external_controller)" ]]; then
        kv "$(L '实时统计' 'Live stats')" "${C_WARN}$(L '未启用 — 在「用户」页面可一键启用' 'off — enable it from the Users screen')${C_RESET}"
    fi
    line=$(sys_load_line)
    [[ -n "${line}" ]] && kv "$(L '系统' 'System')" "${line}"
    box_bottom
    if config_dirty; then warn "$(L '配置已修改但尚未重启生效。' 'Config changed but not yet applied (restart needed).')"; fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Live monitor (aggregate rx/tx on the listening port, via ss)
# ═══════════════════════════════════════════════════════════════════════════════

monitor_sample() { # <port> -> "peer tx rx" per established socket (server perspective)
    ss -H -tin "( sport = :${1} )" 2>/dev/null | awk '
        /^[A-Za-z]/ { peer = ($1 == "ESTAB") ? $5 : ""; next }
        {
            tx = ""; rx = ""
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^bytes_acked:/) { split($i, a, ":"); tx = a[2] }
                if ($i ~ /^bytes_received:/) { split($i, b, ":"); rx = b[2] }
            }
            if (peer != "") print peer, tx + 0, rx + 0
            peer = ""
        }'
}

spark() {
    local max=1 v out="" idx
    for v in "$@"; do ((v > max)) && max="${v}"; done
    for v in "$@"; do
        idx=$((v * 7 / max))
        out+="${SPARK[idx]}"
    done
    printf '%s' "${out}"
}

# Frame data comes in through MON_* globals.
monitor_frame() {
    local lbl_rx lbl_tx
    box_top "$(L '实时带宽' 'Live bandwidth') · $(svc_name)"
    box_row "$(printf '%s RX %s%-14s%s %s' "${C_OK}${G_DN}${C_RESET}" "${C_BOLD}" "$(fmt_rate "${MON_RATE_RX}")" "${C_RESET}" "${C_OK}$(spark "${MON_H_RX[@]}")${C_RESET}")"
    box_row "$(printf '%s TX %s%-14s%s %s' "${C_ACC}${G_UP}${C_RESET}" "${C_BOLD}" "$(fmt_rate "${MON_RATE_TX}")" "${C_RESET}" "${C_ACC}$(spark "${MON_H_TX[@]}")${C_RESET}")"
    box_row "${C_DIM}$(printf '%-14s %-14s' "$(fmt_mbps "${MON_RATE_RX}")" "$(fmt_mbps "${MON_RATE_TX}")")${C_RESET}"
    box_sep
    lbl_rx=$(fmt_bytes "${MON_TOT_RX}"); lbl_tx=$(fmt_bytes "${MON_TOT_TX}")
    kv "$(L '本次累计' 'Session total')" "RX ${lbl_rx} · TX ${lbl_tx}"
    kv "$(L '峰值' 'Peak')" "RX $(fmt_rate "${MON_PEAK_RX}") · TX $(fmt_rate "${MON_PEAK_TX}")"
    kv "$(L '占用' 'Process')" "CPU ${MON_CPU:-?}% · $(L '内存' 'RAM') $(fmt_bytes "${MON_RSS:-0}") · $(L '连接' 'conns') ${MON_CONNS} · FD ${MON_FDS:-?}"
    box_sep
    if [[ -n "${MON_TOP}" ]]; then
        local row_ip row_rx row_tx
        while read -r _ row_ip row_rx row_tx; do
            box_row "$(printf '%s %s %s' "$(pad_right "${row_ip}" 30)" "$(pad_right "${G_DN}$(fmt_rate "${row_rx}")" 17)" "${G_UP}$(fmt_rate "${row_tx}")")"
        done <<<"${MON_TOP}"
    else
        box_row "${C_DIM}$(L '暂无活动连接' 'No active connections')${C_RESET}"
    fi
    if ((API_OK && API_COUNT > 0)); then
        local u_name u_blk u_exc u_conns u_up u_down u_used u_limit shown=0 u_cell
        box_sep
        box_row "${C_DIM}$(pad_right "$(L '用户' 'User')" 13) $(pad_right "$(L '连接' 'Conn')" 4) $(pad_right "${G_DN} $(L '下载' 'Down')" 11) $(pad_right "${G_UP} $(L '上传' 'Up')" 11) $(L '本月' 'Month')${C_RESET}"
        while IFS=$'\t' read -r u_name u_blk u_exc u_conns u_up u_down _ _ u_used u_limit; do
            [[ -n "${u_name}" ]] || continue
            if ((shown >= 6)); then break; fi
            shown=$((shown + 1))
            u_cell=$(fmt_dbytes "${u_used}")
            ((u_limit > 0)) && u_cell+="/$(fmt_dquota "${u_limit}")"
            [[ "${u_blk}" == "true" ]] && u_cell+=" ${C_ERR}$(L '封禁' 'blocked')${C_RESET}"
            [[ "${u_exc}" == "true" ]] && u_cell+=" ${C_WARN}$(L '超额' 'over')${C_RESET}"
            box_row "$(pad_right "${u_name:0:12}" 13) $(pad_right "${u_conns}" 4) $(pad_right "$(rate_cell "${u_down}")" 11) $(pad_right "$(rate_cell "${u_up}")" 11) ${u_cell}"
        done < <(printf '%s\n' "${API_ROWS[@]}" | awk -F'\t' '{ print ($5 + $6) "\t" $0 }' | sort -t$'\t' -rn -k1,1 | cut -f2-)
        ((API_COUNT > shown)) && box_row "${C_DIM}… $(L "另有 $((API_COUNT - shown)) 个用户" "$((API_COUNT - shown)) more users")${C_RESET}"
    fi
    box_bottom
    printf '  %s%s%s\n' "${C_DIM}" "$(L 'RX = 客户端 → 服务器 · TX = 服务器 → 客户端 · q 返回' 'RX = clients → server · TX = server → clients · q to go back')" "${C_RESET}"
}

monitor_live() {
    if [[ "${UI_TTY}" != "1" ]]; then err "$(L '实时监控需要交互终端。' 'The live monitor needs an interactive terminal.')"; return 1; fi
    command -v ss >/dev/null 2>&1 || { err "$(L '需要 ss 命令（iproute2）。' 'The ss command (iproute2) is required.')"; ui_pause; return 1; }
    svc_is_active || { warn "$(L '服务未运行。' 'Service is not running.')"; ui_pause; return 0; }

    local port pid key peer tx rx d ip now_ms last_ms dt_ms t1 t2 first=1 frame line
    local rate_rx=0 rate_tx=0 drx dtx
    declare -A prev_tx=() prev_rx=() cur_tx=() cur_rx=() ip_rx=() ip_tx=()
    port=$(cfg_get .local_port)
    pid=$(svc_pid || true)
    api_load || true
    MON_H_RX=(); MON_H_TX=(); MON_TOT_RX=0; MON_TOT_TX=0; MON_PEAK_RX=0; MON_PEAK_TX=0
    MON_RATE_RX=0; MON_RATE_TX=0; MON_CPU=""; MON_RSS=0; MON_CONNS=0; MON_FDS=""; MON_TOP=""

    ui_clear
    ui_cursor_hide
    last_ms=$(date +%s%3N 2>/dev/null || echo 0)
    [[ "${last_ms}" =~ ^[0-9]+$ ]] || last_ms=0
    t1=$(proc_ticks "${pid}" 2>/dev/null || echo 0)
    while :; do
        now_ms=$(date +%s%3N 2>/dev/null || echo 0)
        [[ "${now_ms}" =~ ^[0-9]+$ ]] || now_ms=0
        dt_ms=$((now_ms - last_ms))
        ((dt_ms < 200)) && dt_ms=1000
        last_ms="${now_ms}"

        cur_tx=(); cur_rx=(); ip_rx=(); ip_tx=()
        drx=0; dtx=0
        while read -r peer tx rx; do
            [[ -n "${peer}" ]] || continue
            cur_tx["${peer}"]="${tx}"; cur_rx["${peer}"]="${rx}"
            if [[ -n "${prev_tx[${peer}]+x}" ]]; then
                d=$((tx - prev_tx[${peer}])); ((d < 0)) && d="${tx}"
                dtx=$((dtx + d)); ip="${peer%:*}"; ip_tx["${ip}"]=$((${ip_tx[${ip}]:-0} + d))
                d=$((rx - prev_rx[${peer}])); ((d < 0)) && d="${rx}"
                drx=$((drx + d)); ip_rx["${ip}"]=$((${ip_rx[${ip}]:-0} + d))
            elif ((first == 0)); then
                ip="${peer%:*}"
                dtx=$((dtx + tx)); ip_tx["${ip}"]=$((${ip_tx[${ip}]:-0} + tx))
                drx=$((drx + rx)); ip_rx["${ip}"]=$((${ip_rx[${ip}]:-0} + rx))
            fi
        done < <(monitor_sample "${port}")
        prev_tx=(); prev_rx=()
        for key in "${!cur_tx[@]}"; do prev_tx["${key}"]="${cur_tx[${key}]}"; prev_rx["${key}"]="${cur_rx[${key}]}"; done
        first=0

        rate_rx=$((drx * 1000 / dt_ms)); rate_tx=$((dtx * 1000 / dt_ms))
        MON_TOT_RX=$((MON_TOT_RX + drx)); MON_TOT_TX=$((MON_TOT_TX + dtx))
        ((rate_rx > MON_PEAK_RX)) && MON_PEAK_RX="${rate_rx}"
        ((rate_tx > MON_PEAK_TX)) && MON_PEAK_TX="${rate_tx}"
        MON_RATE_RX="${rate_rx}"; MON_RATE_TX="${rate_tx}"
        MON_H_RX+=("${rate_rx}"); MON_H_TX+=("${rate_tx}")
        if ((${#MON_H_RX[@]} > 36)); then MON_H_RX=("${MON_H_RX[@]: -36}"); MON_H_TX=("${MON_H_TX[@]: -36}"); fi
        MON_CONNS="${#cur_rx[@]}"

        MON_TOP=""
        for ip in "${!ip_rx[@]}"; do
            MON_TOP+="$((${ip_rx[${ip}]:-0} + ${ip_tx[${ip}]:-0})) ${ip} $((${ip_rx[${ip}]:-0} * 1000 / dt_ms)) $((${ip_tx[${ip}]:-0} * 1000 / dt_ms))"$'\n'
        done
        MON_TOP=$(printf '%s' "${MON_TOP}" | sort -rn | head -n 5)

        if [[ -n "${pid}" && -r "/proc/${pid}/stat" ]]; then
            t2=$(proc_ticks "${pid}" || echo "${t1}")
            MON_CPU=$(awk -v d=$((t2 - t1)) -v c="${CLK_TCK}" -v ms="${dt_ms}" 'BEGIN {printf "%.1f", d * 100000 / (c * ms)}')
            t1="${t2}"
            MON_RSS=$(proc_rss "${pid}"); MON_FDS=$(proc_fds "${pid}")
        fi

        if [[ -n "${API_BASE}" ]]; then api_fetch_users || true; fi
        frame=$(monitor_frame)
        printf '\033[H'
        while IFS= read -r line; do printf '%s\033[K\n' "${line}"; done <<<"${frame}"
        printf '\033[J'

        key=""
        IFS= read -rsn1 -t 1 key || true
        case "${key}" in q|Q|$'\033') break ;; esac
    done
    ui_cursor_show
}

# ═══════════════════════════════════════════════════════════════════════════════
# Versions
# ═══════════════════════════════════════════════════════════════════════════════

rollback_screen() {
    local -a files=() items=() ts
    local f name ver
    while IFS= read -r f; do files+=("${f}"); done < <(ls -1t "${BACKUP_DIR}/sudoku@"* 2>/dev/null)
    if ((${#files[@]} == 0)); then
        warn "$(L '没有可回滚的备份。' 'No backups to roll back to.')"
        ui_pause
        return 0
    fi
    for f in "${files[@]}"; do
        name="${f##*/}"; ver="${name#sudoku@}"; ver="${ver%%@*}"
        ts="${name##*@}"
        items+=("${ver}  ${C_DIM}${ts:0:4}-${ts:4:2}-${ts:6:2} ${ts:8:2}:${ts:10:2}${C_RESET}")
    done
    items+=("$(L '返回' 'Back')")
    ui_clear; box_top "$(L '回滚到备份版本' 'Roll back to a backup')"; box_bottom; printf '\n'
    ui_menu "${items[@]}"
    ((MENU_SEL >= 0 && MENU_SEL < ${#files[@]})) || return 0
    f="${files[MENU_SEL]}"
    ui_confirm "$(L '确认回滚？' 'Roll back?')" y || return 0
    if restore_backup sudoku SUDOKU_VERSION "${f}"; then
        ui_run "$(L '重启服务' 'Restarting service')" svc_restart || true
    else
        err "$(L '回滚失败。' 'Rollback failed.')"
    fi
    ui_pause
}

pick_version_screen() {
    local -a tags=() items=()
    local line tag pre date
    info "$(L '获取版本列表…' 'Fetching releases…')"
    while IFS='|' read -r tag pre date; do
        [[ -n "${tag}" ]] || continue
        tags+=("${tag}")
        items+=("${tag}  ${C_DIM}${date}$([[ "${pre}" == "true" ]] && echo ' · pre-release')${C_RESET}")
    done < <(list_release_tags "${SUDOKU_REPO}" 10 2>/dev/null)
    if ((${#tags[@]} == 0)); then
        err "$(L '无法获取版本列表。' 'Could not fetch the release list.')"
        ui_pause
        return 1
    fi
    items+=("$(L '返回' 'Back')")
    ui_clear; box_top "$(L '选择 Sudoku 版本' 'Pick a Sudoku version')"; box_bottom; printf '\n'
    ui_menu "${items[@]}"
    ((MENU_SEL >= 0 && MENU_SEL < ${#tags[@]})) || return 0
    tag="${tags[MENU_SEL]}"
    ui_confirm "$(L "切换到 ${tag}？（会重启服务）" "Switch to ${tag}? (restarts the service)")" y || return 0
    if upgrade_kernel "${tag}"; then USERS_CAP=""; fi
    ui_pause
}

versions_screen() {
    local cur latest dash_remote
    while :; do
        ui_clear
        info "$(L '检查更新…' 'Checking for updates…')"
        cur=$(ver_get SUDOKU_VERSION)
        latest=$(get_latest_tag "${SUDOKU_REPO}" || true)
        dash_remote=$(remote_dash_version || true)
        ui_clear
        box_top "$(L '版本管理' 'Versions')"
        kv "Sudoku" "${cur:-$(L '未知（由旧脚本安装）' 'unknown (installed by an older script)')}"
        kv "$(L '最新 release' 'Latest release')" "${latest:-$(L '获取失败' 'unavailable')}$([[ -n "${latest}" && "${latest}" != "${cur}" ]] && printf '  %s%s%s' "${C_WARN}" "$(L '← 可升级' '← update available')" "${C_RESET}")"
        if [[ "${WARP_ENABLED}" == "true" ]]; then kv "sing-box" "$(ver_get SING_BOX_VERSION)"; fi
        kv "$(L '用户控制' 'User control')" "$(users_capable && L '支持' 'supported' || L '当前内核不支持（需 ≥ 0.5.2）' 'not in this build (needs ≥ 0.5.2)')"
        kv "dash" "v${DASH_VERSION}$([[ -n "${dash_remote}" && "${dash_remote}" != "${DASH_VERSION}" ]] && printf '  %s→ v%s%s' "${C_WARN}" "${dash_remote}" "${C_RESET}")"
        box_bottom
        printf '\n'
        ui_menu "$(L '升级到最新 release' 'Upgrade to latest release')" "$(L '安装指定版本 / 预发布' 'Install a specific version / pre-release')" \
            "$(L '回滚到备份' 'Roll back to a backup')" "$(L '更新 dash 自身' 'Update dash itself')" "$(L '返回' 'Back')"
        case "${MENU_SEL}" in
            0)
                if [[ -z "${latest}" ]]; then err "$(L '无法获取最新版本。' 'Could not resolve latest release.')"
                elif [[ "${latest}" == "${cur}" ]]; then ok "$(L '已是最新版本。' 'Already up to date.')"
                else upgrade_kernel "${latest}" && USERS_CAP=""; fi
                ui_pause ;;
            1) pick_version_screen ;;
            2) rollback_screen ;;
            3)
                if [[ -z "${dash_remote}" ]]; then err "$(L '无法获取 dash 更新。' 'Could not fetch the dash update.')"
                elif [[ "${dash_remote}" == "${DASH_VERSION}" ]]; then ok "$(L 'dash 已是最新。' 'dash is up to date.')"
                elif ui_run "$(L '更新 dash' 'Updating dash')" install_dash_self; then
                    ok "$(L '已更新，重新启动…' 'Updated; restarting…')"; sleep 1
                    exec "${DASH_BIN}" dash
                fi
                ui_pause ;;
            *) return 0 ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# Service & settings
# ═══════════════════════════════════════════════════════════════════════════════

service_screen() {
    local svc
    while :; do
        svc=$(svc_name)
        ui_clear
        box_top "$(L '服务控制' 'Service')"
        kv "$(L '服务' 'Unit')" "${svc}"
        kv "$(L '状态' 'State')" "$(svc_is_active && L '运行中' 'running' || L '已停止' 'stopped')"
        box_bottom
        printf '\n'
        ui_menu "$(L '重启' 'Restart')" "$(svc_is_active && L '停止' 'Stop' || L '启动' 'Start')" "$(L '最近日志' 'Recent logs')" "$(L '跟随日志（Ctrl-C 退出）' 'Follow logs (Ctrl-C to exit)')" "$(L '返回' 'Back')"
        case "${MENU_SEL}" in
            0) ui_run "$(L '重启服务' 'Restarting')" svc_restart || true; ui_pause ;;
            1)
                if svc_is_active; then ui_run "$(L '停止服务' 'Stopping')" "${SYSTEMCTL}" stop "${svc}" || true
                else selinux_restore; ui_run "$(L '启动服务' 'Starting')" "${SYSTEMCTL}" start "${svc}" || true; fi
                ui_pause ;;
            2) printf '\n'; "${JOURNALCTL}" -u "${svc}" -n 40 --no-pager 2>&1 | cut -c1-150 || true; ui_pause ;;
            3)
                printf '\n'
                trap ':' INT
                "${JOURNALCTL}" -u "${svc}" -n 20 -f --no-pager 2>&1 | cut -c1-150 || true
                trap 'ui_cursor_show; printf "\n"; exit 130' INT
                ;;
            *) return 0 ;;
        esac
    done
}

change_port() {
    local old="${SUDOKU_PORT}" new
    CURRENT_PORT_FOR_VALIDATION="${old}"
    printf '\n'
    ui_ask "$(L '新端口' 'New port')" "${old}" is_free_port
    new="${ASK_RESULT}"
    [[ "${new}" != "${old}" ]] || return 0
    cfg_edit --argjson p "${new}" '.local_port = $p' || { err "$(L '配置校验失败。' 'Config validation failed.')"; return 1; }
    if [[ "${WARP_ENABLED}" == "true" ]]; then
        local tmp
        tmp=$(mktemp)
        jq --argjson p "${new}" '.inbounds |= map(if .tag == "sudoku-in" then .listen_port = $p else . end)' "${SING_BOX_CONFIG_FILE}" >"${tmp}" \
            && chmod 600 "${tmp}" && mv "${tmp}" "${SING_BOX_CONFIG_FILE}"
    fi
    remove_firewall_rule "${old}"
    configure_firewall "${new}"
    SUDOKU_PORT="${new}"
    ui_run "$(L '重启服务' 'Restarting')" svc_restart || { err "$(L '服务启动失败，请检查日志。' 'Service failed to start; check the logs.')"; return 1; }
    if [[ -n "${AVAILABLE_PRIVATE_KEY}" ]] && ensure_server_ip; then
        SHORT_LINK=$(make_short_link "${AVAILABLE_PRIVATE_KEY}" 2>/dev/null || true)
        persist_export_state
    fi
    warn "$(L '端口已变更：所有客户端需要使用新的分享链接。' 'Port changed: every client needs a fresh share link.')"
}

toggle_warp() {
    if [[ "${WARP_ENABLED}" == "true" ]]; then
        ui_confirm "$(L '关闭 WARP，改为直连出站？' 'Disable WARP and egress directly?')" y || return 0
        WARP_ENABLED="false"
        ui_run "$(L '切换为直连并重启' 'Switching to direct mode')" start_and_wait || { err "$(L '启动失败。' 'Failed to start.')"; WARP_ENABLED="true"; return 1; }
    else
        ui_confirm "$(L '启用 Cloudflare WARP 出口？' 'Enable Cloudflare WARP egress?')" y || return 0
        ui_run "$(L '安装 sudoku-sing-box 内核' 'Installing sudoku-sing-box')" install_sing_box_kernel || return 1
        ui_run "$(L '注册 WARP 账户' 'Registering WARP account')" ensure_warp_profile || return 1
        remove_legacy_warp_tun_service
        ui_run "$(L '生成 WARP 出口配置' 'Writing WARP egress config')" write_sing_box_warp_config || return 1
        WARP_ENABLED="true"
        ui_run "$(L '切换为 WARP 并重启' 'Switching to WARP mode')" start_and_wait || { err "$(L '启动失败。' 'Failed to start.')"; WARP_ENABLED="false"; create_service >/dev/null 2>&1; return 1; }
    fi
    mark_applied
    USERS_CAP=""
}

settings_screen() {
    while :; do
        ui_clear
        box_top "$(L '设置' 'Settings')"
        kv "$(L '端口' 'Port')" "${SUDOKU_PORT}"
        kv "WARP" "$([[ "${WARP_ENABLED}" == "true" ]] && L '已启用' 'enabled' || L '未启用' 'disabled')"
        kv "$(L '公网地址' 'Public host')" "${SERVER_IP:-$(L '自动检测' 'auto-detect')}"
        box_bottom
        printf '\n'
        ui_menu "$(L '修改端口' 'Change port')" "$([[ "${WARP_ENABLED}" == "true" ]] && L '关闭 WARP' 'Disable WARP' || L '启用 WARP' 'Enable WARP')" \
            "$(L '修改公网地址 / 域名' 'Change public host / domain')" "$(L '返回' 'Back')"
        case "${MENU_SEL}" in
            0) change_port; ui_pause ;;
            1) toggle_warp; ui_pause ;;
            2)
                printf '\n'
                ui_ask "$(L '服务器公网 IP 或域名' 'Server public IP or domain')" "${SERVER_IP}" is_alias
                SERVER_IP="${ASK_RESULT}"
                persist_export_state
                ok "$(L '已保存。' 'Saved.')"
                ui_pause ;;
            *) return 0 ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# Dash main loop, status, CLI
# ═══════════════════════════════════════════════════════════════════════════════

dash_main() {
    detect_os
    detect_arch
    ensure_root "${ORIG_ARGS[@]}"
    ctx_load || die "$(L '读取配置失败。' 'Failed to read the config.')"
    check_dependencies
    if [[ "${UI_TTY}" != "1" ]]; then cmd_status; return 0; fi

    local act
    while :; do
        ui_clear
        render_overview
        printf '\n'
        ui_menu "$(L '实时带宽 / 资源监控' 'Live bandwidth & resources')" "$(L '用户管理' 'Users')" "$(L '分享 / 连接信息' 'Share / connection info')" \
            "$(L '版本管理' 'Versions & updates')" "$(L '服务控制' 'Service control')" "$(L '设置（端口 / WARP）' 'Settings (port / WARP)')" \
            "$(L '卸载' 'Uninstall')" "$(L '退出' 'Quit')"
        act="${MENU_SEL}"
        case "${act}" in
            0) monitor_live ;;
            1) users_screen ;;
            2) share_screen ;;
            3) versions_screen ;;
            4) service_screen ;;
            5) settings_screen ;;
            6)
                cmd_uninstall
                if ! has_existing_install; then ui_pause; return 0; fi
                ui_pause ;;
            *) printf '\n'; return 0 ;;
        esac
    done
}

cmd_status() {
    ctx_load || { echo "not installed"; return 1; }
    local port pid
    port=$(cfg_get .local_port)
    printf 'service:  %s (%s)\n' "$(svc_name)" "$(svc_is_active && echo running || echo stopped)"
    printf 'mode:     %s\n' "$([[ "${WARP_ENABLED}" == "true" ]] && echo warp || echo direct)"
    printf 'port:     %s\n' "${port}"
    printf 'kernel:   %s\n' "$(ver_get SUDOKU_VERSION)"
    printf 'users:    %s\n' "$(users_count)"
    pid=$(svc_pid 2>/dev/null || true)
    if [[ -n "${pid}" ]]; then
        printf 'pid:      %s\n' "${pid}"
        [[ -r "/proc/${pid}/status" ]] && printf 'rss:      %s\n' "$(fmt_bytes "$(proc_rss "${pid}")")"
    fi
    return 0
}

usage() {
    cat <<EOF
sudoku-dash ${DASH_VERSION}

Usage: sudoku-dash [command]

  (none)        open the dash TUI (or run the installer when Sudoku is not installed)
  install       run the installer
  dash          open the dash TUI
  status        print a plain-text status summary
  --upgrade     upgrade Sudoku (and dash) to the latest release
  --uninstall   remove Sudoku
  --version     print the dash version
  --help        show this help

Environment variables are documented at the top of this script and in the README.
EOF
}

ORIG_ARGS=("$@")

main() {
    trap 'ui_cursor_show' EXIT
    trap 'ui_cursor_show; printf "\n"; exit 130' INT
    case "${1:-}" in
        -h|--help|help) usage ;;
        -v|--version|version) echo "sudoku-dash ${DASH_VERSION}" ;;
        status) detect_os; cmd_status ;;
        --upgrade|upgrade|update) cmd_upgrade ;;
        --uninstall|uninstall) cmd_uninstall ;;
        install)
            if has_existing_install; then dash_main; else run_install; fi ;;
        dash|"")
            if has_existing_install; then dash_main; else run_install; fi ;;
        *) usage >&2; exit 2 ;;
    esac
}

if [[ "${SUDOKU_DASH_SOURCE_ONLY:-}" != "1" ]]; then
    main "$@"
fi
