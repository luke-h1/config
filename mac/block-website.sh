#!/bin/bash
#
# Block or unblock websites using /etc/hosts on macOS.
# Usage: sudo ./block-website.sh block example.com
#        sudo ./block-website.sh unblock example.com
#

set -e

HOSTS_FILE="/etc/hosts"
BLOCK_IP="127.0.0.1"

usage() {
    echo "Usage: sudo $0 block <domain> [domain2 ...]"
    echo "       sudo $0 unblock <domain> [domain2 ...]"
    echo "       sudo $0 list"
    echo ""
    echo "Examples:"
    echo "  sudo $0 block facebook.com www.facebook.com"
    echo "  sudo $0 unblock facebook.com"
    echo "  sudo $0 list"
    exit 1
}

# Must run as root on macOS to modify /etc/hosts
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run with sudo (root) to modify $HOSTS_FILE"
        usage
    fi
}

# Flush DNS cache on macOS so changes take effect immediately
flush_dns() {
    echo "Flushing DNS cache..."
    dscacheutil -flushcache 2>/dev/null || true
    killall -HUP mDNSResponder 2>/dev/null || true
    echo "DNS cache flushed."
}

block_domain() {
    local domain="$1"
    # Normalize: strip protocol and path, lowercase
    domain=$(echo "$domain" | sed -e 's|^https\?://||' -e 's|/.*||' -e 's|^www\.||' | tr '[:upper:]' '[:lower:]')
    [[ -z "$domain" ]] && return
    local domain_esc="${domain//./\\.}"

    if grep -qE "^[[:space:]]*127\.0\.0\.1[[:space:]]+${domain_esc}([[:space:]]|$)" "$HOSTS_FILE" 2>/dev/null; then
        echo "  $domain is already blocked."
    else
        echo "${BLOCK_IP}	${domain}" >> "$HOSTS_FILE"
        echo "  Blocked: $domain"
    fi
}

unblock_domain() {
    local domain="$1"
    domain=$(echo "$domain" | sed -e 's|^https\?://||' -e 's|/.*||' -e 's|^www\.||' | tr '[:upper:]' '[:lower:]')
    [[ -z "$domain" ]] && return
    local domain_esc="${domain//./\\.}"

    if [[ -f "$HOSTS_FILE" ]]; then
        # Remove line that is exactly "127.0.0.1 domain" (we add one domain per line)
        if grep -qE "^[[:space:]]*127\.0\.0\.1[[:space:]]+${domain_esc}[[:space:]]*$" "$HOSTS_FILE" 2>/dev/null; then
            sed -i '' -E "/^[[:space:]]*127\.0\.0\.1[[:space:]]+${domain_esc}[[:space:]]*$/d" "$HOSTS_FILE"
            echo "  Unblocked: $domain"
        else
            echo "  $domain was not blocked."
        fi
    fi
}

list_blocked() {
    echo "Blocked domains in $HOSTS_FILE:"
    grep -E "^[[:space:]]*127\.0\.0\.1[[:space:]]+" "$HOSTS_FILE" 2>/dev/null | sed 's/^[[:space:]]*//' || echo "  (none)"
}

# --- main ---
[[ $# -lt 1 ]] && usage

check_root

case "$1" in
    block)
        shift
        [[ $# -lt 1 ]] && usage
        for domain in "$@"; do
            block_domain "$domain"
        done
        flush_dns
        ;;
    unblock)
        shift
        [[ $# -lt 1 ]] && usage
        for domain in "$@"; do
            unblock_domain "$domain"
        done
        flush_dns
        ;;
    list)
        list_blocked
        ;;
    *)
        usage
        ;;
esac
