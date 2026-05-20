#!/usr/bin/env bash
set -euo pipefail

failures=0
warnings=0

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; warnings=$((warnings + 1)); }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "缺少命令: $1"
}

check_service() {
    local service="$1"
    if systemctl is-active --quiet "${service}" 2>/dev/null; then
        ok "${service} 运行中"
    else
        fail "${service} 未运行"
    fi
}

verify_landing() {
    echo "=== Ghost-Proxy 落地机验证 ==="
    require_cmd systemctl
    require_cmd ip
    require_cmd ss
    require_cmd jq

    [[ -d /etc/landing-ghost ]] || fail "缺少 /etc/landing-ghost"
    [[ -f /etc/landing-ghost/metadata.json ]] || warn "缺少 metadata.json，将使用默认端口判断"

    check_service awg-landing.service
    check_service ss-main.service
    check_service ss-backup.service
    check_service landing-health-check.service

    if ip addr show awg0 2>/dev/null | grep -q "10.8.0.1"; then
        ok "AWG 隧道地址存在: 10.8.0.1"
    else
        fail "AWG 隧道地址缺失: 10.8.0.1"
    fi

    if systemctl show awg-landing.service -p Environment 2>/dev/null | grep -q "amneziawg-go"; then
        ok "AWG 后端: amneziawg-go"
    elif lsmod 2>/dev/null | grep -q "^amneziawg"; then
        ok "AWG 后端: DKMS 内核模块"
    else
        warn "无法确认 AWG 后端，继续检查服务状态"
    fi

    local ss_main_port ss_backup_port
    ss_main_port="$(jq -r '.ss_main_port // 8388' /etc/landing-ghost/metadata.json 2>/dev/null || echo 8388)"
    ss_backup_port="$(jq -r '.ss_backup_port // 8389' /etc/landing-ghost/metadata.json 2>/dev/null || echo 8389)"

    if ss -H -tln "sport = :${ss_main_port}" 2>/dev/null | grep -q .; then
        ok "SS 主轨监听 TCP ${ss_main_port}"
    else
        fail "SS 主轨未监听 TCP ${ss_main_port}"
    fi

    if ss -H -tln "sport = :${ss_backup_port}" 2>/dev/null | grep -q .; then
        ok "SS 备轨监听 TCP ${ss_backup_port}"
    else
        fail "SS 备轨未监听 TCP ${ss_backup_port}"
    fi
}

tcp_probe() {
    local ip="$1" port="$2"
    timeout 3 bash -c ":</dev/tcp/${ip}/${port}" >/dev/null 2>&1
}

verify_transit() {
    echo "=== Ghost-Proxy 中转机验证 ==="
    require_cmd systemctl
    require_cmd nft
    require_cmd jq

    [[ -f /etc/ghost-transit/config.json ]] || fail "缺少 /etc/ghost-transit/config.json"

    if systemctl is-active --quiet nftables 2>/dev/null; then
        ok "nftables 服务运行中"
    else
        fail "nftables 服务未运行"
    fi

    if nft list table inet ghost_proxy_filter >/dev/null 2>&1; then
        ok "nftables filter 表存在"
    else
        fail "nftables filter 表缺失"
    fi

    if nft list table inet ghost_proxy_nat >/dev/null 2>&1; then
        ok "nftables nat 表存在"
    else
        fail "nftables nat 表缺失"
    fi

    local landings_count reachable=0 enabled_count=0
    landings_count="$(jq '.landings | length' /etc/ghost-transit/config.json 2>/dev/null || echo 0)"
    if [[ ! "${landings_count}" =~ ^[0-9]+$ || "${landings_count}" -eq 0 ]]; then
        fail "配置中没有落地机"
        return
    fi

    local i ip name enabled ssh_port
    for ((i=0; i<landings_count; i++)); do
        ip="$(jq -r ".landings[$i].ip // empty" /etc/ghost-transit/config.json)"
        name="$(jq -r ".landings[$i].name // \"landing-${i}\"" /etc/ghost-transit/config.json)"
        enabled="$(jq -r ".landings[$i].enabled // false" /etc/ghost-transit/config.json)"
        ssh_port="$(jq -r ".landings[$i].ssh_port // 22" /etc/ghost-transit/config.json)"
        [[ "${enabled}" == "true" ]] && enabled_count=$((enabled_count + 1))
        if [[ -n "${ip}" ]] && { ping -c 1 -W 2 "${ip}" >/dev/null 2>&1 || tcp_probe "${ip}" "${ssh_port}"; }; then
            ok "落地机可达: ${name} (${ip})"
            reachable=$((reachable + 1))
        else
            warn "落地机暂不可达: ${name} (${ip:-无IP})"
        fi
    done

    if [[ "${enabled_count}" -gt 0 && "${reachable}" -eq 0 ]]; then
        fail "所有启用落地机均不可达"
    else
        ok "落地机连通性: ${reachable}/${landings_count}"
    fi
}

case "${1:-}" in
    landing)
        verify_landing
        ;;
    transit)
        verify_transit
        ;;
    *)
        echo "用法: bash verify_installation.sh [landing|transit]"
        exit 1
        ;;
esac

echo ""
if [[ "${failures}" -gt 0 ]]; then
    echo "验证失败: ${failures} 个失败，${warnings} 个警告"
    exit 1
fi

echo "验证通过: ${warnings} 个警告"
