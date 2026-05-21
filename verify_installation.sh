#!/usr/bin/env bash
set -euo pipefail

# 验证说明:
# - 服务状态、端口监听、配置文件为硬性检查（fail）
# - 端到端连通性为软性检查（warn），客户端未连接时可忽略

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

    local awg_conf="/etc/landing-ghost/awg0.conf"
    if [[ -f "${awg_conf}" ]]; then
        local obfs_ok=1 key
        for key in Jc Jmin Jmax S1 S2 H1 H2 H3 H4; do
            if ! grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "${awg_conf}"; then
                fail "AWG 混淆参数缺失: ${key}"
                obfs_ok=0
            fi
        done
        [[ "${obfs_ok}" -eq 0 ]] || ok "AWG 混淆参数完整"
    else
        fail "AWG 配置文件缺失: ${awg_conf}"
    fi

    if [[ -s /etc/landing-ghost/mihomo-static-awg-proxy.yaml ]]; then
        local static_awg_ok=1
        for yaml_key in AWG-Tunnel wireguard amnezia-wg-option allowed-ips hidden; do
            if ! grep -Fq "${yaml_key}" /etc/landing-ghost/mihomo-static-awg-proxy.yaml; then
                fail "Mihomo 静态 AWG 隧道缺少: ${yaml_key}"
                static_awg_ok=0
            fi
        done
        [[ "${static_awg_ok}" -eq 0 ]] || ok "Mihomo 静态 AWG 隧道完整"
    else
        fail "Mihomo 静态 AWG 隧道缺失: /etc/landing-ghost/mihomo-static-awg-proxy.yaml"
    fi

    if [[ -s /etc/landing-ghost/mihomo-static-awg-proxy.js ]]; then
        local static_awg_js_ok=1
        for json_key in AWG-Tunnel wireguard amnezia-wg-option allowed-ips hidden; do
            if ! grep -Fq "${json_key}" /etc/landing-ghost/mihomo-static-awg-proxy.js; then
                fail "GHOST_STATIC_PROXIES JS 对象缺少: ${json_key}"
                static_awg_js_ok=0
            fi
        done
        if ! jq -e '.name == "AWG-Tunnel" and .type == "wireguard" and .hidden == true and ."amnezia-wg-option"' \
            /etc/landing-ghost/mihomo-static-awg-proxy.js >/dev/null; then
            fail "GHOST_STATIC_PROXIES JS 对象格式异常"
            static_awg_js_ok=0
        fi
        [[ "${static_awg_js_ok}" -eq 0 ]] || ok "GHOST_STATIC_PROXIES JS 对象完整"
    else
        fail "GHOST_STATIC_PROXIES JS 对象缺失: /etc/landing-ghost/mihomo-static-awg-proxy.js"
    fi

    if [[ -s /etc/landing-ghost/ghost-static-proxies.js ]] \
        && grep -Fq 'const GHOST_STATIC_PROXIES = [' /etc/landing-ghost/ghost-static-proxies.js \
        && grep -Fq '"name": "AWG-Tunnel"' /etc/landing-ghost/ghost-static-proxies.js \
        && grep -Fq '];' /etc/landing-ghost/ghost-static-proxies.js; then
        ok "GHOST_STATIC_PROXIES JS 常量完整"
    else
        fail "GHOST_STATIC_PROXIES JS 常量缺失或格式异常: /etc/landing-ghost/ghost-static-proxies.js"
    fi

    if [[ -s /etc/landing-ghost/substore-awg-for-mihomo.yaml ]]; then
        local substore_yaml_ok=1
        for yaml_key in 'name: "AWG-Tunnel"' 'type: wireguard' 'hidden: true' 'amnezia-wg-option:' 'allowed-ips:' 主轨-UDP极速 备轨-TCP稳定 'dialer-proxy: "AWG-Tunnel"'; do
            if ! grep -Fq "${yaml_key}" /etc/landing-ghost/substore-awg-for-mihomo.yaml; then
                fail "Sub-Store 自洽 Provider YAML 缺少: ${yaml_key}"
                substore_yaml_ok=0
            fi
        done
        [[ "${substore_yaml_ok}" -eq 0 ]] || ok "Sub-Store 自洽 Provider YAML 完整"
    else
        fail "Sub-Store YAML 缺失: /etc/landing-ghost/substore-awg-for-mihomo.yaml"
    fi

    if [[ -s /etc/landing-ghost/substore-awg-for-mihomo-base64.txt ]]; then
        local substore_b64_decoded substore_b64_ok=1
        substore_b64_decoded=$(mktemp)
        if base64 -d /etc/landing-ghost/substore-awg-for-mihomo-base64.txt > "${substore_b64_decoded}" 2>/dev/null; then
            for yaml_key in AWG-Tunnel amnezia-wg-option dialer-proxy 主轨-UDP极速 备轨-TCP稳定; do
                if ! grep -Fq "${yaml_key}" "${substore_b64_decoded}"; then
                    fail "Sub-Store Provider Base64 解码后缺少: ${yaml_key}"
                    substore_b64_ok=0
                fi
            done
            [[ "${substore_b64_ok}" -eq 0 ]] || ok "Sub-Store Provider Base64 可解码且关键字段完整"
        else
            fail "Sub-Store Provider Base64 解码失败"
        fi
        rm -f "${substore_b64_decoded}"
    else
        fail "Sub-Store Provider Base64 缺失: /etc/landing-ghost/substore-awg-for-mihomo-base64.txt"
    fi

    if [[ -s /etc/landing-ghost/substore-provider-only.yaml ]]; then
        local provider_only_ok=1
        for yaml_key in 主轨-UDP极速 备轨-TCP稳定 'dialer-proxy: "AWG-Tunnel"'; do
            if ! grep -Fq "${yaml_key}" /etc/landing-ghost/substore-provider-only.yaml; then
                fail "Sub-Store provider-only YAML 缺少: ${yaml_key}"
                provider_only_ok=0
            fi
        done
        if grep -Fq 'name: "AWG-Tunnel"' /etc/landing-ghost/substore-provider-only.yaml; then
            fail "Sub-Store provider-only YAML 不应包含 AWG-Tunnel 节点"
            provider_only_ok=0
        fi
        [[ "${provider_only_ok}" -eq 0 ]] || ok "Sub-Store provider-only YAML 完整"
    else
        fail "Sub-Store provider-only YAML 缺失: /etc/landing-ghost/substore-provider-only.yaml"
    fi

    if [[ -s /etc/landing-ghost/substore-mihomo-full.yaml ]]; then
        local substore_full_ok=1
        for yaml_key in AWG-Tunnel amnezia-wg-option dialer-proxy proxy-groups rules 主轨-UDP极速 备轨-TCP稳定; do
            if ! grep -Fq "${yaml_key}" /etc/landing-ghost/substore-mihomo-full.yaml; then
                fail "Sub-Store 完整 Mihomo 模板缺少: ${yaml_key}"
                substore_full_ok=0
            fi
        done
        if awk '/^proxy-groups:/,/^rules:/' /etc/landing-ghost/substore-mihomo-full.yaml | grep -Fq 'AWG-Tunnel'; then
            fail "Sub-Store 完整 Mihomo 模板策略组不应直接展示 AWG-Tunnel"
            substore_full_ok=0
        fi
        if command -v mihomo >/dev/null 2>&1; then
            if mihomo -t -f /etc/landing-ghost/substore-mihomo-full.yaml >/dev/null 2>&1; then
                ok "mihomo 可解析 Sub-Store 完整 Mihomo 模板"
            else
                fail "mihomo 无法解析 Sub-Store 完整 Mihomo 模板"
                substore_full_ok=0
            fi
        fi
        [[ "${substore_full_ok}" -eq 0 ]] || ok "Sub-Store 完整 Mihomo 模板完整"
    else
        fail "Sub-Store 完整 Mihomo 模板缺失: /etc/landing-ghost/substore-mihomo-full.yaml"
    fi

    if [[ -s /etc/landing-ghost/substore-awg-for-mihomo-jsonlines.txt ]]; then
        local import_key import_ok=1
        for import_key in AWG-Tunnel 主轨-UDP极速 备轨-TCP稳定; do
            if ! grep -Fq "\"name\":\"${import_key}\"" /etc/landing-ghost/substore-awg-for-mihomo-jsonlines.txt; then
                fail "Sub-Store 逐行 JSON 缺少: ${import_key}"
                import_ok=0
            fi
        done
        if ! while IFS= read -r line; do [[ -z "${line}" ]] || jq -e '.name and .type' >/dev/null <<< "${line}"; done < /etc/landing-ghost/substore-awg-for-mihomo-jsonlines.txt; then
            fail "Sub-Store 逐行 JSON 格式异常"
            import_ok=0
        fi
        if ! jq -e -s 'any(.[]; .name == "AWG-Tunnel" and .type == "wireguard" and .hidden == true and ."amnezia-wg-option")
            and any(.[]; .name == "主轨-UDP极速" and ."dialer-proxy" == "AWG-Tunnel")
            and any(.[]; .name == "备轨-TCP稳定")' \
            /etc/landing-ghost/substore-awg-for-mihomo-jsonlines.txt >/dev/null; then
            fail "Sub-Store 逐行 JSON 自洽引用异常"
            import_ok=0
        fi
        [[ "${import_ok}" -eq 0 ]] || ok "Sub-Store 逐行 JSON 完整"
    else
        fail "Sub-Store 逐行 JSON 缺失: /etc/landing-ghost/substore-awg-for-mihomo-jsonlines.txt"
    fi

    if [[ -s /etc/landing-ghost/substore-copy.txt ]] \
        && grep -Fq "===== SUBSTORE_SELF_CONTAINED_YAML_START =====" /etc/landing-ghost/substore-copy.txt \
        && grep -Fq "===== SUBSTORE_SELF_CONTAINED_YAML_END =====" /etc/landing-ghost/substore-copy.txt \
        && grep -Fq "===== SUBSTORE_MIHOMO_FULL_START =====" /etc/landing-ghost/substore-copy.txt \
        && grep -Fq "===== SUBSTORE_MIHOMO_FULL_END =====" /etc/landing-ghost/substore-copy.txt \
        && grep -Fq "===== SUBSTORE_PROVIDER_ONLY_START =====" /etc/landing-ghost/substore-copy.txt \
        && grep -Fq "===== SUBSTORE_PROVIDER_ONLY_END =====" /etc/landing-ghost/substore-copy.txt; then
        ok "Sub-Store 复制文件分割标志完整"
    else
        fail "Sub-Store 复制文件缺失或分割标志不完整"
    fi

    if [[ -s /etc/landing-ghost/ss-backup-uri.txt ]] && grep -Eq '^ss://.+@.+:[0-9]+#Ghost-Backup-TCP$' /etc/landing-ghost/ss-backup-uri.txt; then
        ok "备轨 SS URI 节点存在"
    else
        warn "备轨 SS URI 节点缺失或格式异常"
    fi

    if [[ -s /etc/landing-ghost/ss-backup-uri-base64.txt ]] \
        && base64 -d /etc/landing-ghost/ss-backup-uri-base64.txt 2>/dev/null | grep -Eq '^ss://.+@.+:[0-9]+#Ghost-Backup-TCP$'; then
        ok "备轨 SS URI Base64 可解码"
    else
        warn "备轨 SS URI Base64 缺失或格式异常"
    fi

    if [[ -s /etc/landing-ghost/clash-meta-config.yaml ]]; then
        local yaml_key yaml_ok=1
        for yaml_key in amnezia-wg-option allowed-ips dialer-proxy; do
            if ! grep -Eq "^[[:space:]]*${yaml_key}[[:space:]]*:" /etc/landing-ghost/clash-meta-config.yaml; then
                fail "Mihomo YAML 字段缺失: ${yaml_key}"
                yaml_ok=0
            fi
        done
        [[ "${yaml_ok}" -eq 0 ]] || ok "Mihomo YAML 关键字段完整"
    else
        fail "Mihomo YAML 配置缺失: /etc/landing-ghost/clash-meta-config.yaml"
    fi

    if [[ -s /etc/landing-ghost/clash-meta-subscription.txt ]]; then
        local decoded decoded_ok=1
        decoded=$(mktemp)
        if base64 -d /etc/landing-ghost/clash-meta-subscription.txt > "${decoded}" 2>/dev/null; then
            for yaml_key in AWG-Tunnel amnezia-wg-option dialer-proxy 主轨-UDP极速 备轨-TCP稳定; do
                if ! grep -Fq "${yaml_key}" "${decoded}"; then
                    fail "完整 YAML Base64 解码后缺少: ${yaml_key}"
                    decoded_ok=0
                fi
            done
            [[ "${decoded_ok}" -eq 0 ]] || ok "完整 YAML Base64 可解码且关键字段完整"
        else
            fail "完整 YAML Base64 解码失败: /etc/landing-ghost/clash-meta-subscription.txt"
        fi
        rm -f "${decoded}"
    else
        fail "完整 YAML Base64 缺失: /etc/landing-ghost/clash-meta-subscription.txt"
    fi

    if [[ -s /etc/landing-ghost/clash-meta-import-block.txt ]]; then
        local profile_decoded profile_decoded_ok=1
        profile_decoded=$(mktemp)
        if base64 -d /etc/landing-ghost/clash-meta-import-block.txt > "${profile_decoded}" 2>/dev/null; then
            for yaml_key in AWG-Tunnel amnezia-wg-option dialer-proxy 主轨-UDP极速 备轨-TCP稳定; do
                if ! grep -Fq "${yaml_key}" "${profile_decoded}"; then
                    fail "Mihomo Profile Base64 解码后缺少: ${yaml_key}"
                    profile_decoded_ok=0
                fi
            done
            [[ "${profile_decoded_ok}" -eq 0 ]] || ok "Mihomo Profile Base64 可解码且关键字段完整"
        else
            fail "Mihomo Profile Base64 解码失败: /etc/landing-ghost/clash-meta-import-block.txt"
        fi
        rm -f "${profile_decoded}"
    else
        fail "Mihomo Profile Base64 缺失: /etc/landing-ghost/clash-meta-import-block.txt"
    fi

    if [[ -s /etc/landing-ghost/mihomo-profile.yaml ]]; then
        local profile_ok=1
        for yaml_key in amnezia-wg-option allowed-ips dialer-proxy; do
            if ! grep -Eq "^[[:space:]]*${yaml_key}[[:space:]]*:" /etc/landing-ghost/mihomo-profile.yaml; then
                fail "Mihomo Profile 缺少字段: ${yaml_key}"
                profile_ok=0
            fi
        done
        [[ "${profile_ok}" -eq 0 ]] || ok "Mihomo Profile 关键字段完整"
    else
        fail "Mihomo Profile 缺失: /etc/landing-ghost/mihomo-profile.yaml"
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

    if timeout 3 bash -c ":</dev/tcp/10.8.0.1/${ss_main_port}" >/dev/null 2>&1; then
        ok "SS 主轨在 AWG 网关地址可建立本机 TCP 连接"
    else
        warn "SS 主轨本机 TCP 探测未通过；如客户端未连接，请结合服务日志排查"
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

    local ghost_tables_ok=1
    if nft list table inet ghost_proxy_filter >/dev/null 2>&1; then
        ok "nftables filter 表存在"
    else
        fail "nftables filter 表缺失"
        ghost_tables_ok=0
    fi

    if nft list table inet ghost_proxy_nat >/dev/null 2>&1; then
        ok "nftables nat 表存在"
    else
        fail "nftables nat 表缺失"
        ghost_tables_ok=0
    fi

    if systemctl is-active --quiet nftables 2>/dev/null; then
        ok "nftables 服务运行中"
    elif [[ "${ghost_tables_ok}" -eq 1 ]]; then
        warn "nftables 服务未处于 active，但 Ghost 表已加载；建议执行 systemctl enable --now nftables"
    else
        fail "nftables 服务未运行且 Ghost 表缺失"
    fi

    local nat_rules
    nat_rules="$(nft list table inet ghost_proxy_nat 2>/dev/null || true)"
    if grep -q "type nat hook prerouting" <<< "${nat_rules}" && grep -q "type nat hook postrouting" <<< "${nat_rules}"; then
        ok "nftables NAT 钩子存在"
    else
        fail "nftables NAT 关键钩子缺失"
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
