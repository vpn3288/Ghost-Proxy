#!/usr/bin/env bash
set -euo pipefail

# install_landing_v6.87.sh — 落地机安装脚本
# 版本: v6.87 (2026-05-21)
# v6.87 - 加强 Sub-Store 导入说明，并用临时链切换降低防火墙重建窗口。
# 完整历史记录请查看 zhubi.md 或 Git 提交历史。

# ==========================================
# 全局变量
# ==========================================
VERSION="6.87"
AWG_BACKEND=""  # 记录 AWG 后端类型：kernel/go/none
SERVICES_STOPPED_FOR_REINSTALL=0
DEFAULT_DKMS_VERSION="3.0.10-8+deb12u1"
DEFAULT_GCC_VERSION="12"
DEFAULT_GOLANG_VERSION="2:1.19~1"
DEFAULT_GO_TOOLCHAIN_VERSION="1.24.4"
DEFAULT_GO_TOOLCHAIN_SHA256_AMD64="77e5da33bb72aeaef1ba4418b6fe511bc4d041873cbf82e5aa6318740df98717"
DEFAULT_GO_TOOLCHAIN_SHA256_ARM64="d5501ee5aca0f258d5fe9bfaed401958445014495dc115f202d43d5210b45241"
DEFAULT_PKG_CONFIG_VERSION="1.8.1-1"
DEFAULT_LIBMNL_DEV_VERSION="1.0.4-3"
DEFAULT_SINGBOX_VERSION="1.11.0"
DEFAULT_SINGBOX_SHA256_AMD64="eff0237951bfbd2381be36f114e419f10d3ed57dbf929f680e4cc9f57e319d64"
DEFAULT_SINGBOX_SHA256_ARM64="8fc21f46ddf2d7022c34d5e3e2298a3b4064b6e1f85dce5cc23cb9c6015dafc4"
DEFAULT_AWG_DKMS_REF="ac946a9df100a17d342b5982d1947deef1b51952"
DEFAULT_AWG_TOOLS_REF="5d6179a6d0842e98dfb349c28cf1bd8e4b9d1079"
DEFAULT_AWG_GO_REF="f4f4c999267437c3eb909e8d0e5278fb4596d9a7"
DEFAULT_PREBUILT_AWG_GO_URL_x86_64="https://github.com/vpn3288/Ghost-Proxy/releases/download/v6.85/amneziawg-go-linux-amd64"
DEFAULT_PREBUILT_AWG_GO_SHA256_x86_64="67a63a77c84d962cd7c08e21d43f88c36662be108c9de35ed33307d81736ab50"
DEFAULT_PREBUILT_AWG_TOOLS_URL_x86_64="https://github.com/vpn3288/Ghost-Proxy/releases/download/v6.85/amneziawg-tools-linux-amd64.tar.gz"
DEFAULT_PREBUILT_AWG_TOOLS_SHA256_x86_64="6648a91daf25b5e4fc12c80c06a020ca1359db9adb35fcd1da284d14bb4af3a4"
DEFAULT_PREBUILT_AWG_GO_URL_arm64="https://github.com/vpn3288/Ghost-Proxy/releases/download/v6.85/amneziawg-go-linux-arm64"
DEFAULT_PREBUILT_AWG_GO_SHA256_arm64="aaf0eef4ce3f68972add71de9f604eddb5da3eaaaf598a5980fc0378bf473ea3"
DEFAULT_PREBUILT_AWG_TOOLS_URL_arm64="https://github.com/vpn3288/Ghost-Proxy/releases/download/v6.85/amneziawg-tools-linux-arm64.tar.gz"
DEFAULT_PREBUILT_AWG_TOOLS_SHA256_arm64="064dda828b9209f75f342637df7b538a3f5ca99671a985103ec9f91165757a6a"

load_versions_config() {
    local script_dir config
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P || pwd)"
    config="${script_dir}/versions.conf"
    if [[ -f "${config}" ]]; then
        # shellcheck disable=SC1090
        source "${config}"
        return 0
    fi
    if [[ "${ALLOW_CWD_VERSIONS:-0}" == "1" && -f ./versions.conf ]]; then
        echo "[信息] ALLOW_CWD_VERSIONS=1，读取当前目录 ./versions.conf" >&2
        # shellcheck disable=SC1091
        source ./versions.conf
    fi
}
load_versions_config

DKMS_VERSION="${DKMS_VERSION:-${DEFAULT_DKMS_VERSION}}"
GCC_VERSION="${GCC_VERSION:-${DEFAULT_GCC_VERSION}}"
GOLANG_VERSION="${GOLANG_VERSION:-${DEFAULT_GOLANG_VERSION}}"
GO_TOOLCHAIN_VERSION="${GO_TOOLCHAIN_VERSION:-${DEFAULT_GO_TOOLCHAIN_VERSION}}"
GO_TOOLCHAIN_SHA256_AMD64="${GO_TOOLCHAIN_SHA256_AMD64:-${DEFAULT_GO_TOOLCHAIN_SHA256_AMD64}}"
GO_TOOLCHAIN_SHA256_ARM64="${GO_TOOLCHAIN_SHA256_ARM64:-${DEFAULT_GO_TOOLCHAIN_SHA256_ARM64}}"
PKG_CONFIG_VERSION="${PKG_CONFIG_VERSION:-${DEFAULT_PKG_CONFIG_VERSION}}"
LIBMNL_DEV_VERSION="${LIBMNL_DEV_VERSION:-${DEFAULT_LIBMNL_DEV_VERSION}}"
SINGBOX_VERSION="${SINGBOX_VERSION:-${DEFAULT_SINGBOX_VERSION}}"
SINGBOX_SHA256_AMD64="${SINGBOX_SHA256_AMD64:-${DEFAULT_SINGBOX_SHA256_AMD64}}"
SINGBOX_SHA256_ARM64="${SINGBOX_SHA256_ARM64:-${DEFAULT_SINGBOX_SHA256_ARM64}}"
AWG_DKMS_REF="${AWG_DKMS_REF:-${DEFAULT_AWG_DKMS_REF}}"
AWG_TOOLS_REF="${AWG_TOOLS_REF:-${DEFAULT_AWG_TOOLS_REF}}"
AWG_GO_REF="${AWG_GO_REF:-${DEFAULT_AWG_GO_REF}}"
PREBUILT_AWG_GO_URL_x86_64="${PREBUILT_AWG_GO_URL_x86_64:-${DEFAULT_PREBUILT_AWG_GO_URL_x86_64}}"
PREBUILT_AWG_GO_SHA256_x86_64="${PREBUILT_AWG_GO_SHA256_x86_64:-${DEFAULT_PREBUILT_AWG_GO_SHA256_x86_64}}"
PREBUILT_AWG_TOOLS_URL_x86_64="${PREBUILT_AWG_TOOLS_URL_x86_64:-${DEFAULT_PREBUILT_AWG_TOOLS_URL_x86_64}}"
PREBUILT_AWG_TOOLS_SHA256_x86_64="${PREBUILT_AWG_TOOLS_SHA256_x86_64:-${DEFAULT_PREBUILT_AWG_TOOLS_SHA256_x86_64}}"
PREBUILT_AWG_GO_URL_arm64="${PREBUILT_AWG_GO_URL_arm64:-${DEFAULT_PREBUILT_AWG_GO_URL_arm64}}"
PREBUILT_AWG_GO_SHA256_arm64="${PREBUILT_AWG_GO_SHA256_arm64:-${DEFAULT_PREBUILT_AWG_GO_SHA256_arm64}}"
PREBUILT_AWG_TOOLS_URL_arm64="${PREBUILT_AWG_TOOLS_URL_arm64:-${DEFAULT_PREBUILT_AWG_TOOLS_URL_arm64}}"
PREBUILT_AWG_TOOLS_SHA256_arm64="${PREBUILT_AWG_TOOLS_SHA256_arm64:-${DEFAULT_PREBUILT_AWG_TOOLS_SHA256_arm64}}"
RECOMMENDED_OS_VERSION="${RECOMMENDED_OS_VERSION:-12}"
RECOMMENDED_OS_POINT="${RECOMMENDED_OS_POINT:-12.14}"
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 全局变量
TRANSIT_IP="${TRANSIT_IP:-}"
AWG_SERVER_PUBLIC=""
AWG_CLIENT_PRIVATE=""
AWG_CLIENT_PUBLIC=""
AWG_PORT="${AWG_PORT:-51820}"
LANDING_INDEX="${LANDING_INDEX:-}"
TRANSIT_AWG_LISTEN_PORT="${TRANSIT_AWG_LISTEN_PORT:-}"
SS_MAIN_PORT=8388
SS_BACKUP_PORT="${SS_BACKUP_PORT:-8389}"
TRANSIT_SS_LISTEN_PORT="${TRANSIT_SS_LISTEN_PORT:-}"
SS_PASSWORD=""
CONFIG_DIR="/etc/landing-ghost"
LOG_FILE="/var/log/landing-ghost.log"
HOME_IP=""
# 链式代理默认 MTU（中转机+落地机双层封装，保守值避免分片）
OPTIMAL_MTU=1360

# 混淆参数
JC="" JMIN="" JMAX="" S1="" S2="" H1="" H2="" H3="" H4=""

# ==========================================
# 卸载功能
# ==========================================

uninstall() {
    echo -e "${YELLOW}开始卸载落地机组件...${NC}"
    echo ""
    echo "卸载选项："
    echo "  [1] 完全卸载（停止服务 + 清理防火墙 + 删除配置）"
    echo "  [2] 仅停止服务（保留防火墙和配置）"
    echo ""
    read -p "请选择 (1/2): " choice
    
    # 停止并禁用所有服务
    systemctl stop awg-landing ss-main ss-backup landing-health-check ghost-landing-firewall 2>/dev/null || true
    systemctl disable awg-landing ss-main ss-backup landing-health-check ghost-landing-firewall 2>/dev/null || true
    
    # 删除 systemd 服务文件
    rm -f /etc/systemd/system/awg-landing.service
    rm -f /etc/systemd/system/ss-main.service
    rm -f /etc/systemd/system/ss-backup.service
    rm -f /etc/systemd/system/landing-health-check.service
    rm -f /etc/systemd/system/ghost-landing-firewall.service
    rm -f /usr/local/bin/landing-health-check.sh
    rm -f /usr/local/bin/awg-landing-monitor.sh
    rm -f /usr/local/bin/ghost-landing-firewall-apply.sh
    systemctl daemon-reload
    echo -e "${GREEN}服务已停止并禁用${NC}"
    
    if [[ "${choice}" == "1" ]]; then
        # 完全卸载
        echo -e "${YELLOW}正在删除 Ghost-Proxy 专属防火墙规则...${NC}"
        if command -v iptables >/dev/null 2>&1; then
            # 兼容清理旧版残留链，不破坏 1Panel/Docker
            for chain in $(iptables -L -n | grep "^Chain PORTSCAN_" | awk '{print $2}'); do
                local port=${chain#PORTSCAN_}
                iptables -D INPUT -p tcp --dport "${port}" -j "${chain}" 2>/dev/null || true
                iptables -F "${chain}" 2>/dev/null || true
                iptables -X "${chain}" 2>/dev/null || true
            done
            for chain in $(iptables -L -n | grep -E "^Chain (ghost|landing)" | awk '{print $2}'); do
                iptables -F "${chain}" 2>/dev/null || true
                iptables -X "${chain}" 2>/dev/null || true
            done

            if command -v iptables-save >/dev/null 2>&1 && command -v iptables-restore >/dev/null 2>&1; then
                iptables-save | awk '/^-A/ && /ghost-proxy-landing/ {next} {print}' | iptables-restore 2>/dev/null || true
            fi
            while iptables -D INPUT -j GHOST_LANDING_INPUT 2>/dev/null; do :; done
            iptables -F GHOST_LANDING_INPUT 2>/dev/null || true
            iptables -X GHOST_LANDING_INPUT 2>/dev/null || true

            local ports_json="" transit_ip="" meta_awg_port="" meta_ss_backup_port=""
            if command -v jq >/dev/null 2>&1 && [[ -f "${CONFIG_DIR}/metadata.json" ]]; then
                ports_json=$(jq -r '[.awg_port, .ss_backup_port, .transit_awg_listen_port, .transit_ss_listen_port] | map(select(.!=null)) | unique[]' "${CONFIG_DIR}/metadata.json" 2>/dev/null || true)
                transit_ip=$(jq -r '.transit_ip // ""' "${CONFIG_DIR}/metadata.json" 2>/dev/null || true)
                meta_awg_port=$(jq -r '.awg_port // ""' "${CONFIG_DIR}/metadata.json" 2>/dev/null || true)
                meta_ss_backup_port=$(jq -r '.ss_backup_port // ""' "${CONFIG_DIR}/metadata.json" 2>/dev/null || true)
            fi

            if [[ -n "${transit_ip}" ]]; then
                [[ -n "${meta_awg_port}" ]] && while iptables -D INPUT -s "${transit_ip}" -p udp --dport "${meta_awg_port}" -j ACCEPT 2>/dev/null; do :; done
                [[ -n "${meta_ss_backup_port}" ]] && while iptables -D INPUT -s "${transit_ip}" -p tcp --dport "${meta_ss_backup_port}" -j ACCEPT 2>/dev/null; do :; done
                while iptables -D INPUT -s "${transit_ip}" -p icmp --icmp-type echo-request -j ACCEPT 2>/dev/null; do :; done
            fi
            for port in ${ports_json}; do
                while iptables -D INPUT -p udp --dport "${port}" -j DROP 2>/dev/null; do :; done
                while iptables -D INPUT -p tcp --dport "${port}" -j DROP 2>/dev/null; do :; done
            done

            netfilter-persistent save 2>/dev/null || true
            echo -e "${GREEN}Ghost-Proxy 防火墙规则已删除（保留通用 INPUT、SSH、Docker/1Panel 规则和默认策略）${NC}"
        else
            warn "iptables 不存在，跳过落地机防火墙清理"
        fi
        
        # 清理策略路由
        ip rule del table 100 2>/dev/null || true
        ip route flush table 100 2>/dev/null || true
        sed -i '/100 home_ip/d' /etc/iproute2/rt_tables 2>/dev/null || true
        rm -f /etc/network/if-up.d/home-ip-routing
        systemctl stop home-ip-routing.service 2>/dev/null || true
        systemctl disable home-ip-routing.service 2>/dev/null || true
        rm -f /etc/systemd/system/home-ip-routing.service
        rm -f /usr/local/bin/home-ip-routing-apply.sh
        echo -e "${GREEN}策略路由已清理${NC}"
        
        # 清理 cron 任务
        crontab -l 2>/dev/null | grep -v "rotate_obfuscation.sh" | crontab - 2>/dev/null || true
        echo -e "${GREEN}旧版计划任务已清理${NC}"

        if dkms status -m amneziawg 2>/dev/null | grep -q amneziawg; then
            echo -e "${YELLOW}正在卸载 AmneziaWG DKMS 模块...${NC}"
            dkms remove -m amneziawg --all 2>/dev/null || true
        fi
        if lsmod | grep -q '^amneziawg'; then
            modprobe -r amneziawg 2>/dev/null || true
        fi
        systemctl stop ghost-awg-dkms-check.service ghost-awg-dkms-check.timer cleanup-awg-swap.timer 2>/dev/null || true
        systemctl disable ghost-awg-dkms-check.service ghost-awg-dkms-check.timer cleanup-awg-swap.timer 2>/dev/null || true
        rm -f /etc/systemd/system/ghost-awg-dkms-check.service
        rm -f /etc/systemd/system/ghost-awg-dkms-check.timer
        rm -f /etc/systemd/system/cleanup-awg-swap.service
        rm -f /etc/systemd/system/cleanup-awg-swap.timer
        rm -f /etc/kernel/postinst.d/amneziawg-dkms
        systemctl daemon-reload 2>/dev/null || true
        echo -e "${GREEN}AmneziaWG DKMS 残留已清理${NC}"
        
        if command -v shred >/dev/null 2>&1 && [[ -d "${CONFIG_DIR}" ]]; then
            find "${CONFIG_DIR}" -maxdepth 1 -type f \
                \( -name 'clash-meta-config.yaml' -o -name 'clash-meta-subscription.txt' -o -name 'clash-meta-import-block.txt' -o -name 'mihomo-profile.yaml' -o -name 'substore-copy.txt' -o -name 'substore-import-guide.txt' -o -name 'mihomo-static-awg-proxy.yaml' -o -name 'mihomo-static-awg-proxy.js' -o -name 'ghost-static-proxies.js' -o -name 'substore-awg-for-mihomo.yaml' -o -name 'substore-awg-for-mihomo-base64.txt' -o -name 'substore-awg-for-mihomo-jsonlines.txt' -o -name 'substore-provider-only.yaml' -o -name 'substore-mihomo-full.yaml' -o -name 'substore-mihomo-full-base64.txt' -o -name 'clash-meta-proxies.yaml' -o -name 'clash-meta-substore-nodes.txt' -o -name 'client-config.txt' -o -name 'ss-backup-uri.txt' -o -name 'ss-backup-uri-base64.txt' -o -name 'ss-main.json' -o -name 'ss-backup.json' -o -name 'metadata.json' \) \
                -exec shred -u -n 1 -z {} \; 2>/dev/null || true
        fi
        rm -rf "${CONFIG_DIR}"
        echo -e "${GREEN}配置文件已删除${NC}"
        
        rm -f /etc/sysctl.d/99-landing-ghost.conf
        rm -f /etc/sysctl.d/99-landing-ghost-prelim.conf
        rm -f /usr/local/bin/show-clash-config
        rm -f /usr/local/bin/show-ghost-nodes
        rm -f /etc/logrotate.d/landing-ghost
        rm -f /var/log/landing-ghost.log
        sysctl -p 2>/dev/null || true
        echo -e "${GREEN}系统参数已恢复${NC}"
    else
        # 仅停止服务
        echo -e "${CYAN}防火墙规则保留${NC}"
        echo -e "${CYAN}配置文件保留在 ${CONFIG_DIR}${NC}"
        echo -e "${CYAN}系统参数保留${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}卸载完成${NC}"
    exit 0
}

if [[ "${1:-}" == "--uninstall" ]]; then
    uninstall
fi

landing_installed() {
    [[ -f "${CONFIG_DIR}/metadata.json" ]] || return 1
    [[ -f "${CONFIG_DIR}/awg0.conf" ]] || return 1
    return 0
}

load_existing_metadata_defaults() {
    [[ -f "${CONFIG_DIR}/metadata.json" ]] || return 0
    command -v jq >/dev/null 2>&1 || return 0

    local value
    value=$(jq -r '.transit_ip // ""' "${CONFIG_DIR}/metadata.json" 2>/dev/null || true)
    [[ -n "${value}" && -z "${TRANSIT_IP:-}" ]] && TRANSIT_IP="${value}"

    value=$(jq -r '.awg_port // ""' "${CONFIG_DIR}/metadata.json" 2>/dev/null || true)
    [[ "${value}" =~ ^[0-9]+$ && "${AWG_PORT:-51820}" == "51820" ]] && AWG_PORT="${value}"

    value=$(jq -r '.ss_backup_port // ""' "${CONFIG_DIR}/metadata.json" 2>/dev/null || true)
    [[ "${value}" =~ ^[0-9]+$ && "${SS_BACKUP_PORT:-8389}" == "8389" ]] && SS_BACKUP_PORT="${value}"

    value=$(jq -r '.transit_awg_listen_port // ""' "${CONFIG_DIR}/metadata.json" 2>/dev/null || true)
    [[ "${value}" =~ ^[0-9]+$ && -z "${TRANSIT_AWG_LISTEN_PORT:-}" ]] && TRANSIT_AWG_LISTEN_PORT="${value}"

    value=$(jq -r '.transit_ss_listen_port // ""' "${CONFIG_DIR}/metadata.json" 2>/dev/null || true)
    [[ "${value}" =~ ^[0-9]+$ && -z "${TRANSIT_SS_LISTEN_PORT:-}" ]] && TRANSIT_SS_LISTEN_PORT="${value}"
}

show_generated_nodes() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  已生成节点 / 配置文件${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [[ -f "${CONFIG_DIR}/metadata.json" ]]; then
        echo -e "${YELLOW}当前端口信息:${NC}"
        if command -v jq >/dev/null 2>&1; then
            jq -r '
              "  中转机 IP: \(.transit_ip // "")",
              "  落地 AWG 目标端口: \(.awg_port // "")",
              "  中转 AWG 监听端口: \(.transit_awg_listen_port // "")",
              "  落地 SS 备轨端口: \(.ss_backup_port // "")",
              "  中转 SS 监听端口: \(.transit_ss_listen_port // "")"
            ' "${CONFIG_DIR}/metadata.json" 2>/dev/null || cat "${CONFIG_DIR}/metadata.json"
        else
            cat "${CONFIG_DIR}/metadata.json"
        fi
        echo ""
    fi

    echo -e "${GREEN}常用入口:${NC}"
    echo ""
    echo -e "${RED}Mihomo 直导：Base64 一键导入完整 Clash Meta / Mihomo 配置：${NC}"
    echo "cat ${CONFIG_DIR}/clash-meta-subscription.txt"
    echo ""
    echo -e "${BLUE}Sub-Store Provider 推荐入口（只含主轨/备轨，配合静态 AWG 基础配置）：${NC}"
    echo "cat ${CONFIG_DIR}/substore-provider-only.yaml"
    echo ""
    echo -e "${BLUE}Sub-Store / ClashMeta 导入指南：${NC}"
    echo "cat ${CONFIG_DIR}/substore-import-guide.txt"
    echo ""
    echo -e "${YELLOW}完整 Profile、自洽 Provider 等高级入口默认不展示，避免导入错误文件。需要时运行:${NC}"
    echo "show-ghost-nodes --advanced"
}

generated_nodes_exist() {
    [[ -s "${CONFIG_DIR}/mihomo-profile.yaml" ]] \
        || [[ -s "${CONFIG_DIR}/clash-meta-subscription.txt" ]] \
        || [[ -s "${CONFIG_DIR}/clash-meta-import-block.txt" ]] \
        || [[ -s "${CONFIG_DIR}/substore-copy.txt" ]] \
        || [[ -s "${CONFIG_DIR}/mihomo-static-awg-proxy.yaml" ]] \
        || [[ -s "${CONFIG_DIR}/mihomo-static-awg-proxy.js" ]] \
        || [[ -s "${CONFIG_DIR}/ghost-static-proxies.js" ]] \
        || [[ -s "${CONFIG_DIR}/substore-awg-for-mihomo.yaml" ]] \
        || [[ -s "${CONFIG_DIR}/substore-awg-for-mihomo-base64.txt" ]] \
        || [[ -s "${CONFIG_DIR}/substore-awg-for-mihomo-jsonlines.txt" ]] \
        || [[ -s "${CONFIG_DIR}/substore-provider-only.yaml" ]] \
        || [[ -s "${CONFIG_DIR}/substore-import-guide.txt" ]] \
        || [[ -s "${CONFIG_DIR}/substore-mihomo-full.yaml" ]] \
        || [[ -s "${CONFIG_DIR}/substore-mihomo-full-base64.txt" ]] \
        || [[ -s "${CONFIG_DIR}/clash-meta-config.yaml" ]] \
        || [[ -s "${CONFIG_DIR}/ss-backup-uri-base64.txt" ]]
}

confirm_overwrite_nodes() {
    [[ "${AUTO_INSTALL:-0}" == "1" ]] && return 0
    [[ -t 0 ]] || return 0
    generated_nodes_exist || return 0

    echo ""
    echo -e "${YELLOW}检测到本机已经生成过客户端节点。${NC}"
    echo "继续会覆盖旧的 Sub-Store YAML/JSON、Mihomo Profile 和 SS URI。"
    echo "如果只是中转端口填错，建议在菜单选择“修正中转端口并重新生成节点（不重装服务）”。"
    read -p "确认覆盖旧节点并继续? (y/N): " confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        die "已取消覆盖旧节点"
    fi
}

delete_generated_nodes() {
    echo -e "${YELLOW}将删除本机生成的客户端节点文件，不停止服务、不清理防火墙。${NC}"
    read -p "确认删除节点文件? (y/N): " confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        echo "已取消"
        exit 0
    fi

    rm -f \
        "${CONFIG_DIR}/clash-meta-config.yaml" \
        "${CONFIG_DIR}/clash-meta-subscription.txt" \
        "${CONFIG_DIR}/clash-meta-import-block.txt" \
        "${CONFIG_DIR}/mihomo-profile.yaml" \
        "${CONFIG_DIR}/substore-copy.txt" \
        "${CONFIG_DIR}/mihomo-static-awg-proxy.yaml" \
        "${CONFIG_DIR}/mihomo-static-awg-proxy.js" \
        "${CONFIG_DIR}/ghost-static-proxies.js" \
        "${CONFIG_DIR}/substore-awg-for-mihomo.yaml" \
        "${CONFIG_DIR}/substore-awg-for-mihomo-base64.txt" \
        "${CONFIG_DIR}/substore-awg-for-mihomo-jsonlines.txt" \
        "${CONFIG_DIR}/substore-provider-only.yaml" \
        "${CONFIG_DIR}/substore-import-guide.txt" \
        "${CONFIG_DIR}/substore-mihomo-full.yaml" \
        "${CONFIG_DIR}/substore-mihomo-full-base64.txt" \
        "${CONFIG_DIR}/clash-meta-proxies.yaml" \
        "${CONFIG_DIR}/clash-meta-substore-nodes.txt" \
        "${CONFIG_DIR}/ss-backup-uri.txt" \
        "${CONFIG_DIR}/ss-backup-uri-base64.txt" \
        "${CONFIG_DIR}/client-config.txt" \
        /usr/local/bin/show-clash-config \
        /usr/local/bin/show-ghost-nodes
    echo -e "${GREEN}节点文件已删除；如需重新生成，请再次运行脚本选择“添加/更新节点”。${NC}"
    exit 0
}

regenerate_nodes_only() {
    if [[ ! -f "${CONFIG_DIR}/.awg_keys" || ! -f "${CONFIG_DIR}/.ss_password" || ! -f "${CONFIG_DIR}/.awg_obfs_params" ]]; then
        die "缺少密钥/密码/混淆参数，不能只重建节点；请选择完整添加/更新节点"
    fi

    load_existing_metadata_defaults
    # shellcheck disable=SC1090
    source "${CONFIG_DIR}/.awg_keys"
    SS_PASSWORD=$(cat "${CONFIG_DIR}/.ss_password")
    validate_ss_password "${SS_PASSWORD}"
    # shellcheck disable=SC1090
    source "${CONFIG_DIR}/.awg_obfs_params"
    valid_obfuscation_params || die "已有 AWG 混淆参数无效，不能只重建节点"
    confirm_overwrite_nodes

    if [[ -z "${TRANSIT_IP:-}" ]]; then
        while true; do
            read -p "中转机 IP: " TRANSIT_IP
            validate_ip "${TRANSIT_IP}" && break
            warn "IP 地址格式错误，请重新输入"
        done
    fi

    echo ""
    echo -e "${YELLOW}请填写中转机实际端口。多落地机时必须与中转机 ghost-transit-ctl 显示一致。${NC}"
    TRANSIT_AWG_LISTEN_PORT=$(read_port_loop "中转机 AWG 监听端口" "${TRANSIT_AWG_LISTEN_PORT:-$(default_transit_port "${AWG_PORT}")}")
    TRANSIT_SS_LISTEN_PORT=$(read_port_loop "中转机 SS 备轨监听端口" "${TRANSIT_SS_LISTEN_PORT:-$(default_transit_port "${SS_BACKUP_PORT}")}")

    mkdir -p "${CONFIG_DIR}"
    cat > "${CONFIG_DIR}/metadata.json" <<EOF
{
  "transit_ip": "${TRANSIT_IP}",
  "awg_port": ${AWG_PORT},
  "transit_awg_listen_port": ${TRANSIT_AWG_LISTEN_PORT},
  "ss_main_port": ${SS_MAIN_PORT},
  "ss_backup_port": ${SS_BACKUP_PORT},
  "transit_ss_listen_port": ${TRANSIT_SS_LISTEN_PORT}
}
EOF
    chmod 644 "${CONFIG_DIR}/metadata.json"

    generate_clash_meta_yaml
    print_client_config
    exit 0
}

show_landing_menu() {
    while true; do
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}${BOLD}  检测到已安装 Ghost-Proxy 落地机 v${VERSION}${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  [1] 添加/更新节点（重新生成落地机服务与客户端节点）"
        echo "  [2] 显示已生成导入配置 / Base64"
        echo "  [3] 删除已生成节点文件（不卸载服务）"
        echo "  [4] 修正中转端口并重新生成节点（不重装服务）"
        echo "  [5] 卸载落地机"
        echo "  [6] 退出"
        echo ""
        read -p "请选择 (1/2/3/4/5/6): " choice
        case "${choice}" in
            1) return 0 ;;
            2) show_generated_nodes; exit 0 ;;
            3) delete_generated_nodes ;;
            4) regenerate_nodes_only ;;
            5) uninstall ;;
            6) exit 0 ;;
            *) warn "无效选择，请重新输入" ;;
        esac
    done
}

# 工具函数
# ==========================================

log() {
    local level="$1"
    shift
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [${level}] $*" | tee -a "${LOG_FILE}"
}

info() { echo -e "${CYAN}[信息]${NC} $1"; log "INFO" "$1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; log "SUCCESS" "$1"; }
warn() { echo -e "${YELLOW}[警告]${NC} $1"; log "WARN" "$1"; }
error() { echo -e "${RED}[✗]${NC} $1"; log "ERROR" "$1"; }
die() { error "$1"; exit 1; }

progress() {
    local current=$1
    local total=$2
    local desc="$3"
    echo -e "${CYAN}[${current}/${total}]${NC} ${desc}..."
}

cleanup_old_backups() {
    local file_pattern="$1"
    local keep_count=3

    find "$(dirname "${file_pattern}")" -maxdepth 1 -type f -name "$(basename "${file_pattern}").bak.*" \
        -printf '%T@ %p\0' 2>/dev/null \
        | sort -zrn \
        | tail -z -n +$((keep_count + 1)) \
        | cut -z -d' ' -f2- \
        | xargs -0 -r rm -f
}

# ==========================================
# 环境检测
# ==========================================

check_root() {
    if [[ ${EUID} -ne 0 ]]; then
        die "必须使用 root 用户运行此脚本"
    fi
}

print_dd_baseline_hint() {
    local dd_arch
    case "$(uname -m)" in
        x86_64|amd64) dd_arch="amd64" ;;
        aarch64|arm64) dd_arch="arm64" ;;
        *) dd_arch="amd64|arm64" ;;
    esac
    warn "推荐先 DD 到 Debian ${RECOMMENDED_OS_POINT} Bookworm minimal 再安装（新机会清盘）"
    echo "  bash <(curl -fsSL https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/dd_debian.sh) --arch ${dd_arch}"
    echo "  安全执行前先按 dd_debian.sh 提示设置对应 SHA256，再追加 --execute"
}

check_os() {
    if [[ ! -f /etc/debian_version ]]; then
        die "仅支持 Debian ${RECOMMENDED_OS_VERSION} 系统。推荐使用 DD 安装 Debian ${RECOMMENDED_OS_POINT} Bookworm minimal"
    fi
    
    local version point_version
    version=$(cat /etc/debian_version | cut -d. -f1)
    point_version=$(cat /etc/debian_version)
    if [[ "${version}" != "${RECOMMENDED_OS_VERSION}" ]]; then
        error "检测到 Debian ${version}，Ghost-Proxy 仅支持 Debian ${RECOMMENDED_OS_VERSION}"
        warn "推荐基线：Debian ${RECOMMENDED_OS_POINT} Bookworm minimal"
        warn "官方 ISO: https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/"
        warn "网络安装: https://www.debian.org/distrib/netinst"
        warn "DD/网络重装会清空机器，请只在新机并确认救援能力后执行"
        print_dd_baseline_hint
        read -p "是否继续在非推荐系统上安装? (yes/NO): " confirm
        [[ "${confirm}" == "yes" ]] || die "已取消安装"
        warn "继续在 Debian ${version} 上安装，DKMS 失败风险极高"
    elif [[ "${point_version}" != "${RECOMMENDED_OS_POINT}" ]]; then
        warn "当前 Debian ${point_version}，推荐基线为 ${RECOMMENDED_OS_POINT}"
        print_dd_baseline_hint
    fi
}

check_1panel_conflict() {
    local conflicts=()
    
    for port in 80 443 8888; do
        if port_in_use tcp "${port}"; then
            local process
            process=$(ss -H -tlnp "sport = :${port}" 2>/dev/null | awk -F 'users:\\(\\("' 'NF > 1 {split($2,a,"\""); print a[1]; exit}' || true)
            if [[ -n "${process}" ]]; then
                conflicts+=("端口 ${port} 被 ${process} 占用")
            fi
        fi
    done
    
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        info "检测到以下端口占用 (这是正常的,不会冲突):"
        for conflict in "${conflicts[@]}"; do
            echo "  - ${conflict}"
        done
        echo ""
        info "本脚本使用高位端口 (${SS_MAIN_PORT}, ${SS_BACKUP_PORT}),不会冲突"
    fi
}

# ==========================================
# 端口配置
# ==========================================

validate_port() {
    local port="$1"
    [[ "${port}" =~ ^[0-9]+$ ]] && [[ ${port} -ge 1 ]] && [[ ${port} -le 65535 ]]
}

port_in_use() {
    local proto="$1" port="$2"
    if [[ "${proto}" == "tcp" ]]; then
        ss -H -tln "sport = :${port}" 2>/dev/null | grep -q .
    elif [[ "${proto}" == "udp" ]]; then
        ss -H -uln "sport = :${port}" 2>/dev/null | grep -q .
    else
        die "无效的协议 '${proto}'"
    fi
}

stop_own_services_for_reinstall() {
    local service has_existing=0
    [[ -f "${CONFIG_DIR}/metadata.json" ]] && has_existing=1

    for service in awg-landing.service ss-main.service ss-backup.service landing-health-check.service; do
        if systemctl is-active --quiet "${service}" 2>/dev/null || systemctl is-enabled --quiet "${service}" 2>/dev/null; then
            has_existing=1
            break
        fi
    done

    if [[ "${has_existing}" -eq 0 ]]; then
        return 0
    fi

    info "检测到已有落地机配置，临时停止本项目服务以避免重跑时自占端口"
    systemctl stop landing-health-check.service landing-health-check \
        ss-main.service ss-main ss-backup.service ss-backup \
        awg-landing.service awg-landing 2>/dev/null || true
    SERVICES_STOPPED_FOR_REINSTALL=1
}

restore_stopped_services_on_failure() {
    local exit_code=$?
    if [[ "${exit_code}" -ne 0 && "${SERVICES_STOPPED_FOR_REINSTALL:-0}" == "1" ]]; then
        warn "安装失败，尝试恢复重跑前已存在的服务"
        systemctl start awg-landing.service ss-main.service ss-backup.service landing-health-check.service 2>/dev/null || true
    fi
    exit "${exit_code}"
}

validate_auto_install_inputs() {
    if [[ "${AUTO_INSTALL:-0}" != "1" ]]; then
        return 0
    fi
    [[ -n "${LANDING_INDEX:-}" ]] || die "AUTO_INSTALL=1 需设置 LANDING_INDEX（从 1 开始）"
    [[ "${LANDING_INDEX}" =~ ^[0-9]+$ ]] || die "LANDING_INDEX 必须为正整数，当前: ${LANDING_INDEX}"
    [[ "${LANDING_INDEX}" -ge 1 ]] || die "LANDING_INDEX 必须 >= 1，当前: ${LANDING_INDEX}"
    local var
    for var in AWG_PORT SS_BACKUP_PORT TRANSIT_AWG_LISTEN_PORT TRANSIT_SS_LISTEN_PORT; do
        if [[ -n "${!var:-}" ]]; then
            validate_port "${!var}" || die "${var} 无效"
        fi
    done
}

retry_command() {
    local max_attempts="$1" sleep_time="$2"
    shift 2
    local attempt
    for attempt in $(seq 1 "${max_attempts}"); do
        if "$@"; then
            return 0
        fi
        [[ ${attempt} -lt ${max_attempts} ]] && sleep "${sleep_time}"
    done
    return 1
}

git_clone_ref() {
    local repo_url="$1" dest_dir="$2" ref="$3"
    git clone --depth 1 --config http.lowSpeedLimit=1000 --config http.lowSpeedTime=60 \
        "${repo_url}" "${dest_dir}" &>/dev/null \
        && git -C "${dest_dir}" fetch --depth 1 origin "${ref}" &>/dev/null \
        && git -C "${dest_dir}" checkout -q FETCH_HEAD
}

read_port_loop() {
    local prompt="$1"
    local default="$2"
    local value
    while true; do
        read -p "${prompt} (默认 ${default}): " value
        value="${value:-$default}"
        if validate_port "${value}"; then
            echo "${value}"
            return 0
        fi
        echo -e "${RED}端口无效，请输入 1-65535${NC}" >&2
    done
}

default_transit_port() {
    local base="$1"
    if (( base <= 55535 )); then
        echo $((base + 10000))
    elif (( base > 10000 )); then
        echo $((base - 10000))
    else
        echo "${base}"
    fi
}

configure_ports() {
    info "配置端口..."
    load_existing_metadata_defaults
    
    # v6.14: 支持非交互模式
    if [[ "${AUTO_INSTALL:-0}" == "1" ]]; then
        [[ -n "${LANDING_INDEX:-}" ]] || die "AUTO_INSTALL=1 需设置 LANDING_INDEX（从 1 开始）"
        [[ "${LANDING_INDEX}" =~ ^[0-9]+$ ]] || die "LANDING_INDEX 必须为正整数，当前: ${LANDING_INDEX}"
        [[ "${LANDING_INDEX}" -ge 1 ]] || die "LANDING_INDEX 必须 >= 1，当前: ${LANDING_INDEX}"
        SS_BACKUP_PORT=${SS_BACKUP_PORT:-8389}
        AWG_PORT=${AWG_PORT:-51820}
        TRANSIT_AWG_LISTEN_PORT=${TRANSIT_AWG_LISTEN_PORT:-$((51820 + LANDING_INDEX - 1))}
        TRANSIT_SS_LISTEN_PORT=${TRANSIT_SS_LISTEN_PORT:-$((8389 + LANDING_INDEX - 1))}

        local missing_vars=()
        [[ -z "${TRANSIT_IP:-}" ]] && missing_vars+=("TRANSIT_IP")
        if [[ ${#missing_vars[@]} -gt 0 ]]; then
            die "AUTO_INSTALL=1 时必须设置以下环境变量: ${missing_vars[*]}"
        fi
        validate_port "${AWG_PORT}" || die "AWG_PORT 无效"
        validate_port "${SS_BACKUP_PORT}" || die "SS_BACKUP_PORT 无效"
        validate_port "${TRANSIT_AWG_LISTEN_PORT}" || die "TRANSIT_AWG_LISTEN_PORT 无效"
        validate_port "${TRANSIT_SS_LISTEN_PORT}" || die "TRANSIT_SS_LISTEN_PORT 无效"
        if port_in_use udp "${AWG_PORT}"; then
            die "AWG UDP 端口 ${AWG_PORT} 已被占用，请更换 AWG_PORT"
        fi
        if port_in_use tcp "${SS_BACKUP_PORT}" || port_in_use udp "${SS_BACKUP_PORT}"; then
            die "SS 备轨端口 ${SS_BACKUP_PORT} 已被占用，请更换 SS_BACKUP_PORT"
        fi
        info "非交互模式: LANDING_INDEX=${LANDING_INDEX}，中转默认端口已自动错开"
        success "端口配置完成: 落地AWG=${AWG_PORT}, 中转AWG=${TRANSIT_AWG_LISTEN_PORT}, 落地备轨=${SS_BACKUP_PORT}, 中转备轨=${TRANSIT_SS_LISTEN_PORT}"
        return 0
    fi
    
    # AWG端口（从中转机配对信息获取，不需要用户输入）
    # SS_MAIN_PORT 固定为8388（监听在AWG隧道内部）
    # SS_BACKUP_PORT 需要用户配置或随机生成
    
    echo ""
    echo -e "${YELLOW}配置备轨端口（直连中转机）:${NC}"
    echo "  [1] 使用默认端口 8389"
    echo "  [2] 随机生成端口 (10000-60000)"
    echo "  [3] 自定义端口"
    echo ""
    read -p "请选择 (1/2/3, 默认1): " port_choice
    port_choice=${port_choice:-1}
    
    case "${port_choice}" in
        1)
            SS_BACKUP_PORT=8389
            info "使用默认端口: ${SS_BACKUP_PORT}"
            ;;
        2)
            SS_BACKUP_PORT=$((RANDOM % 50001 + 10000))
            info "随机生成端口: ${SS_BACKUP_PORT}"
            ;;
        3)
            while true; do
                read -p "请输入端口 (1024-65535): " custom_port
                if [[ "${custom_port}" =~ ^[0-9]+$ ]] && [[ ${custom_port} -ge 1024 ]] && [[ ${custom_port} -le 65535 ]]; then
                    SS_BACKUP_PORT=${custom_port}
                    info "使用自定义端口: ${SS_BACKUP_PORT}"
                    break
                else
                    error "端口无效，请输入 1024-65535 之间的数字"
                fi
            done
            ;;
        *)
            warn "无效选择，使用默认端口 8389"
            SS_BACKUP_PORT=8389
            ;;
    esac
    
    # 检查端口是否被占用
    while port_in_use udp "${AWG_PORT}"; do
        warn "AWG UDP 端口 ${AWG_PORT} 已被占用"
        AWG_PORT=$(read_port_loop "落地机 AWG 目标端口" "${AWG_PORT}")
    done

    local port_retry=0
    local max_retries=10
    while port_in_use tcp "${SS_BACKUP_PORT}" || port_in_use udp "${SS_BACKUP_PORT}"; do
        if [[ ${port_retry} -ge ${max_retries} ]]; then
            die "端口冲突检测失败（已重试${max_retries}次），请手动释放端口或指定可用端口"
        fi
        warn "端口 ${SS_BACKUP_PORT} 已被占用"
        if [[ ${port_retry} -ge 3 ]]; then
            warn "多次端口冲突，自动使用随机端口"
            SS_BACKUP_PORT=$((RANDOM % 50001 + 10000))
            port_retry=$((port_retry + 1))
            continue
        fi
        read -p "是否重新选择端口? (y/N): " retry
        if [[ "${retry}" == "y" || "${retry}" == "Y" ]]; then
            SS_BACKUP_PORT=$(read_port_loop "落地机 SS 备轨端口" "${SS_BACKUP_PORT}")
            port_retry=$((port_retry + 1))
            continue
        fi
        die "端口 ${SS_BACKUP_PORT} 已被占用，安装已停止；请重新运行并选择可用端口"
    done
    
    TRANSIT_AWG_LISTEN_PORT=${TRANSIT_AWG_LISTEN_PORT:-$(default_transit_port "${AWG_PORT}")}
    TRANSIT_SS_LISTEN_PORT=${TRANSIT_SS_LISTEN_PORT:-$(default_transit_port "${SS_BACKUP_PORT}")}

    echo ""
    echo -e "${YELLOW}配置中转机对外监听端口（多落地机时每台必须不同）:${NC}"
    TRANSIT_AWG_LISTEN_PORT=$(read_port_loop "中转机 AWG 监听端口" "${TRANSIT_AWG_LISTEN_PORT}")
    TRANSIT_SS_LISTEN_PORT=$(read_port_loop "中转机 SS 备轨监听端口" "${TRANSIT_SS_LISTEN_PORT}")

    success "端口配置完成: 落地AWG=${AWG_PORT}, 中转AWG=${TRANSIT_AWG_LISTEN_PORT}, 落地备轨=${SS_BACKUP_PORT}, 中转备轨=${TRANSIT_SS_LISTEN_PORT}"
}

# ==========================================
# 输入验证
# ==========================================

validate_ip() {
    local ip="$1"
    if [[ ! "${ip}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    
    local IFS='.'
    local -a octets=(${ip})
    for octet in "${octets[@]}"; do
        if [[ ${octet} -gt 255 ]]; then
            return 1
        fi
    done
    return 0
}

detect_home_ip_interface() {
    echo "检测家宽 IP 网卡..." >&2

    if [[ -n "${HOME_IFACE:-}" && -n "${HOME_IP:-}" ]]; then
        ip -4 addr show "${HOME_IFACE}" 2>/dev/null | grep -Fq "${HOME_IP}" || die "HOME_IP 不在 HOME_IFACE 上"
        echo "使用手动指定家宽 IP: ${HOME_IP} (网卡: ${HOME_IFACE})" >&2
        echo "${HOME_IFACE}"
        return 0
    fi
    
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | cut -d@ -f1 | grep -v '^lo$')
    local home_interface=""
    
    for iface in ${interfaces}; do
        case "${iface}" in
            docker*|br-*|veth*|virbr*|podman*|cni*|flannel*|zt*|tailscale*|wg*|awg*)
                continue
                ;;
        esac

        local ip_addr default_route gateway
        ip_addr=$(ip -o -4 addr show dev "${iface}" scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')
        
        if [[ -n "${ip_addr}" ]]; then
            # 检测私有IP段（家宽IP）
            if [[ "${ip_addr}" =~ ^10\. ]] || [[ "${ip_addr}" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "${ip_addr}" =~ ^192\.168\. ]] || [[ "${ip_addr}" =~ ^100\.(6[4-9]|7[0-9]|8[0-9]|9[0-9]|10[0-9]|11[0-9]|12[0-7])\. ]]; then
                default_route=$(ip -4 route show default dev "${iface}" 2>/dev/null | head -1)
                gateway=$(awk '/^default / {for (i=1;i<=NF;i++) if ($i=="via") {print $(i+1); exit}}' <<< "${default_route}")
                if [[ -z "${default_route}" || -z "${gateway}" ]]; then
                    warn "跳过 ${iface}: 私网地址 ${ip_addr} 不是带网关的默认出站接口"
                    continue
                fi
                home_interface="${iface}"
                HOME_IP="${ip_addr}"
                echo "检测到家宽 IP: ${HOME_IP} (网卡: ${home_interface})" >&2
                echo "${home_interface}"  # 输出网卡名称到stdout
                return 0
            fi
        fi
    done
    
    echo "未检测到家宽 IP，将使用默认出站接口" >&2
    return 1
}

setup_home_ip_routing() {
    local home_iface="$1"
    local home_ip="$2"
    
    if [[ -z "${home_iface}" ]] || [[ -z "${home_ip}" ]]; then
        return 1
    fi
    
    info "配置家宽IP策略路由..."
    
    # 获取网关
    local gateway=$(ip route show dev "${home_iface}" | grep default | awk '{print $3}' | head -1)
    
    if [[ -z "${gateway}" ]]; then
        warn "无法获取家宽网卡 ${home_iface} 的网关，跳过策略路由"
        return 1
    fi
    
    # 创建独立路由表（table 100）
    if ! grep -q "100 home_ip" /etc/iproute2/rt_tables 2>/dev/null; then
        echo "100 home_ip" >> /etc/iproute2/rt_tables
    fi
    
    # 清理旧规则
    ip rule del from "${home_ip}" table 100 2>/dev/null || true
    ip route flush table 100 2>/dev/null || true
    
    # 添加策略路由规则
    ip rule add from "${home_ip}" table 100 priority 100
    ip route add default via "${gateway}" dev "${home_iface}" table 100
    
    # 立即验证策略路由是否生效
    if ! ip rule show | grep -q "from ${home_ip} lookup 100"; then
        error "✗ 策略路由规则验证失败"
        return 1
    fi
    
    if ! ip route show table 100 | grep -q "default via ${gateway}"; then
        error "✗ 策略路由表验证失败"
        return 1
    fi
    
    # 增强验证：测试流量是否真正走家宽网卡
    if command -v ip &>/dev/null; then
        local test_route=$(ip route get 8.8.8.8 from ${home_ip} 2>/dev/null || echo "")
        if ! echo "${test_route}" | grep -q "${home_iface}"; then
            warn "策略路由规则存在但流量路由可能不正确"
            log "WARN" "策略路由流量测试: ${test_route}"
        fi
    fi
    
    success "家宽IP策略路由已配置: ${home_ip} -> ${home_iface} -> ${gateway}"
    log "INFO" "策略路由: table 100, from ${home_ip} via ${gateway} dev ${home_iface}"
    
    # 持久化配置：ifupdown 和 systemd-networkd 均通过同一脚本重放策略路由。
    cat > /usr/local/bin/home-ip-routing-apply.sh <<EOF
#!/bin/bash
# 家宽IP策略路由持久化脚本
set -u
LOG_FILE="/var/log/landing-ghost.log"

log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') [ROUTE] \$*" >> "\${LOG_FILE}"
}

if ! ip link show "${home_iface}" >/dev/null 2>&1; then
    log "家宽网卡不存在，跳过: ${home_iface}"
    exit 0
fi

ip rule del from ${home_ip} table 100 priority 100 2>/dev/null || true
ip route flush table 100 2>/dev/null || true

if ip rule add from ${home_ip} table 100 priority 100 2>/dev/null; then
    log "策略路由规则已添加: from ${home_ip} table 100"
fi

if ip route add default via ${gateway} dev ${home_iface} table 100 2>/dev/null; then
    log "策略路由表已配置: default via ${gateway} dev ${home_iface}"
fi

if ! ip rule show | grep -q "from ${home_ip} lookup 100"; then
    log "策略路由规则验证失败"
fi

if ! ip route show table 100 | grep -q "default via ${gateway}"; then
    log "策略路由表验证失败"
fi

log "策略路由持久化完成: ${home_ip} -> ${home_iface} -> ${gateway}"
EOF
    chmod +x /usr/local/bin/home-ip-routing-apply.sh

    cat > /etc/network/if-up.d/home-ip-routing <<'EOF'
#!/bin/bash
[ "${IFACE:-}" = "__HOME_IFACE__" ] || exit 0
exec /usr/local/bin/home-ip-routing-apply.sh
EOF
    sed -i "s/__HOME_IFACE__/${home_iface}/g" /etc/network/if-up.d/home-ip-routing
    chmod +x /etc/network/if-up.d/home-ip-routing

    cat > /etc/systemd/system/home-ip-routing.service <<EOF
[Unit]
Description=Landing Ghost Home IP Policy Routing
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/home-ip-routing-apply.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable home-ip-routing.service >/dev/null 2>&1 || true
    
    return 0
}

# ==========================================
# 用户输入
# ==========================================
ask_transit_info() {
    load_existing_metadata_defaults

    # v6.14: 支持非交互模式
    if [[ "${AUTO_INSTALL:-0}" == "1" && -z "${TRANSIT_IP:-}" ]]; then
        die "AUTO_INSTALL=1 时必须设置 TRANSIT_IP"
    fi

    if [[ -n "${TRANSIT_IP:-}" ]] && [[ "${AUTO_INSTALL:-0}" == "1" ]]; then
        info "检测到非交互模式，使用环境变量配置"
        
        # 验证IP格式
        if ! validate_ip "${TRANSIT_IP}"; then
            error "环境变量 TRANSIT_IP 格式错误: ${TRANSIT_IP}"
            exit 1
        fi
        
        # 设置AWG端口（默认51820）
        AWG_PORT=${AWG_PORT:-51820}
        if ! [[ "${AWG_PORT}" =~ ^[0-9]+$ ]] || [[ "${AWG_PORT}" -lt 1 ]] || [[ "${AWG_PORT}" -gt 65535 ]]; then
            error "环境变量 AWG_PORT 必须是 1-65535 之间的数字"
            exit 1
        fi
        
        success "非交互模式配置完成"
        info "  中转机 IP: ${TRANSIT_IP}"
        info "  落地 AWG 目标端口: ${AWG_PORT}"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  请输入中转机信息${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 输入中转机 IP
    while true; do
        local input_transit_ip=""
        if [[ -n "${TRANSIT_IP:-}" ]]; then
            read -p "中转机公网 IP (默认 ${TRANSIT_IP}): " input_transit_ip
            TRANSIT_IP="${input_transit_ip:-${TRANSIT_IP}}"
        else
            read -p "中转机公网 IP: " TRANSIT_IP
        fi
        if validate_ip "${TRANSIT_IP}"; then
            break
        else
            warn "IP 格式错误，请重新输入"
        fi
    done
    
    # 输入 AWG 端口
    while true; do
        local input_awg_port=""
        read -p "落地机 AmneziaWG 目标端口 (默认 ${AWG_PORT:-51820}): " input_awg_port
        AWG_PORT=${input_awg_port:-${AWG_PORT:-51820}}
        if [[ "${AWG_PORT}" =~ ^[0-9]+$ ]] && [[ "${AWG_PORT}" -ge 1 ]] && [[ "${AWG_PORT}" -le 65535 ]]; then
            break
        else
            warn "端口必须是 1-65535 之间的数字"
        fi
    done
    
    success "中转机信息已确认"
    info "  中转机 IP: ${TRANSIT_IP}"
    info "  落地 AWG 目标端口: ${AWG_PORT}"
    echo ""
}


validate_ss_password() {
    local password="$1"
    if [[ ${#password} -lt 16 ]]; then
        die "SS_PASSWORD 长度不足 16 字符"
    fi
    if [[ ! "${password}" =~ ^[A-Za-z0-9+/=_\.\:@\$\%\^\&\*\!\?\#\~,-]+$ ]]; then
        die "SS_PASSWORD 包含不安全字符，请使用 base64/URL-safe 字符及常见 JSON/YAML 安全标点"
    fi
}

# 【新增】密码复用机制
generate_password() {
    local password_file="${CONFIG_DIR}/.ss_password"
    
    # [P0-2] 优先使用环境变量传入的密码（支持多落地机统一密码）
    if [[ -n "${SS_PASSWORD:-}" ]]; then
        validate_ss_password "${SS_PASSWORD}"
        info "使用环境变量提供的密码"
        mkdir -p "${CONFIG_DIR}"
        echo "${SS_PASSWORD}" > "${password_file}"
        chmod 600 "${password_file}"
        log "INFO" "密码已从环境变量设置"
        return 0
    fi
    
    # 如果已有密码文件，复用
    if [[ -f "${password_file}" ]]; then
        SS_PASSWORD=$(cat "${password_file}")
        validate_ss_password "${SS_PASSWORD}"
        info "复用已有密码（幂等性保护）"
        log "INFO" "从 ${password_file} 读取已有密码"
        return 0
    fi
    
    # 生成新密码，校验字符类型，避免极端熵源异常生成低质量密码
    local attempt char_types
    for attempt in 1 2 3 4 5; do
        if command -v openssl &>/dev/null; then
            SS_PASSWORD=$(openssl rand -base64 32 | tr -d '\n\r')
        else
            SS_PASSWORD=$(head -c 32 /dev/urandom | base64 | tr -d '\n\r')
        fi

        char_types=0
        [[ "${SS_PASSWORD}" =~ [a-z] ]] && char_types=$((char_types + 1))
        [[ "${SS_PASSWORD}" =~ [A-Z] ]] && char_types=$((char_types + 1))
        [[ "${SS_PASSWORD}" =~ [0-9] ]] && char_types=$((char_types + 1))
        [[ "${SS_PASSWORD}" =~ [+/=] ]] && char_types=$((char_types + 1))

        if [[ ${#SS_PASSWORD} -ge 16 && ${char_types} -ge 3 ]]; then
            break
        fi
        SS_PASSWORD=""
    done

    if [[ ${#SS_PASSWORD} -lt 16 ]]; then
        die "密码生成失败（5 次尝试）"
    fi
    validate_ss_password "${SS_PASSWORD}"
    
    # 保存密码
    mkdir -p "${CONFIG_DIR}"
    echo "${SS_PASSWORD}" > "${password_file}"
    chmod 600 "${password_file}"
    log "INFO" "新密码已保存到 ${password_file}"
    success "生成新密码"
}

# ==========================================
# 依赖安装
# ==========================================

install_dependencies() {
    progress 1 11 "更新系统软件包"
    retry_command 3 5 apt-get update -qq || die "apt-get update 失败（3次尝试）"
    
    progress 2 11 "安装基础依赖"
    retry_command 3 5 env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        curl wget git build-essential jq iproute2 \
        iptables iptables-persistent \
        openssl netcat-openbsd iputils-tracepath || die "依赖安装失败（3次尝试）"

    local script_dir dkms_source="" remote_name downloaded_dkms=0
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P || pwd)"
    for path in "${script_dir}/install_amneziawg_dkms_v${VERSION}.sh" "${script_dir}/install_amneziawg_dkms.sh"; do
        if [[ -f "${path}" ]]; then
            dkms_source="${path}"
            break
        fi
    done
    if [[ -n "${dkms_source}" ]]; then
        install -m 0755 "${dkms_source}" /usr/local/bin/install_amneziawg_dkms.sh
        cp /usr/local/bin/install_amneziawg_dkms.sh /root/install_amneziawg_dkms.sh 2>/dev/null || true
    else
        local remote_names=(
            "install_amneziawg_dkms_v${VERSION}.sh"
            "install_amneziawg_dkms.sh"
        )
        for remote_name in "${remote_names[@]}"; do
            if curl -fsSL --connect-timeout 10 --retry 3 \
                "https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/${remote_name}" \
                -o /usr/local/bin/install_amneziawg_dkms.sh 2>/dev/null; then
                chmod +x /usr/local/bin/install_amneziawg_dkms.sh
                cp /usr/local/bin/install_amneziawg_dkms.sh /root/install_amneziawg_dkms.sh 2>/dev/null || true
                downloaded_dkms=1
                break
            fi
        done
        [[ "${downloaded_dkms}" -eq 1 ]] || warn "DKMS 脚本下载失败，将继续使用 amneziawg-go 回退"
    fi
    
    success "依赖安装完成"
}

# ==========================================
# DNS 和 IPv6 预防性锁定
# ==========================================

disable_ifupdown_ipv6_stanzas() {
    local files=()
    [[ -f /etc/network/interfaces ]] && files+=("/etc/network/interfaces")
    if [[ -d /etc/network/interfaces.d ]]; then
        while IFS= read -r file; do
            [[ -f "${file}" ]] && files+=("${file}")
        done < <(find /etc/network/interfaces.d -maxdepth 1 -type f 2>/dev/null | sort)
    fi

    [[ ${#files[@]} -gt 0 ]] || return 0

    local file tmp changed=0
    for file in "${files[@]}"; do
        grep -Eq '^[[:space:]]*iface[[:space:]]+[^[:space:]]+[[:space:]]+inet6[[:space:]]' "${file}" 2>/dev/null || continue
        tmp="$(mktemp)"
        awk '
            /^[[:space:]]*iface[[:space:]]+[^[:space:]]+[[:space:]]+inet6[[:space:]]/ {
                print "# ghost-proxy-ipv6-disabled: " $0
                in_ipv6=1
                changed=1
                next
            }
            in_ipv6 && /^[[:space:]]+/ && $0 !~ /^[[:space:]]*#/ {
                print "# ghost-proxy-ipv6-disabled: " $0
                changed=1
                next
            }
            {
                if ($0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:space:]]+/) {
                    in_ipv6=0
                }
                print
            }
            END { exit changed ? 10 : 0 }
        ' "${file}" > "${tmp}" || {
            local rc=$?
            if [[ "${rc}" -ne 10 ]]; then
                rm -f "${tmp}"
                warn "处理 ifupdown IPv6 配置失败: ${file}"
                continue
            fi
        }
        cp -a "${file}" "${file}.ghost-ipv6.bak.$(date +%s)"
        cat "${tmp}" > "${file}"
        rm -f "${tmp}"
        changed=1
        log "INFO" "已注释 ifupdown IPv6 配置: ${file}"
    done

    if [[ "${changed}" -eq 1 ]]; then
        success "已禁用 ifupdown IPv6 DHCP 配置，避免 networking.service 重启失败"
    fi
}

lockdown_dns_ipv6() {
    progress 3 11 "禁用 IPv6（防泄漏）"

    disable_ifupdown_ipv6_stanzas
    
    # 禁用 IPv6（sysctl层）
    cat > /etc/sysctl.d/99-landing-ghost-prelim.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    
    sysctl -p /etc/sysctl.d/99-landing-ghost-prelim.conf &>/dev/null
    log "INFO" "IPv6 已禁用（sysctl层）"
    
    success "IPv6 已完全禁用（sysctl）"
    log "INFO" "IPv6 sysctl 禁用已应用"
    
    # 阻断 IPv6 入站和转发，OUTPUT 保持 ACCEPT 以避免影响 Docker/1Panel 内部链路
    if command -v ip6tables &>/dev/null; then
        ip6tables -P INPUT ACCEPT 2>/dev/null || true
        ip6tables -P FORWARD DROP 2>/dev/null || true
        ip6tables -P OUTPUT ACCEPT 2>/dev/null || true
        ip6tables -N GHOST_IPV6_INPUT 2>/dev/null || true
        ip6tables -F GHOST_IPV6_INPUT 2>/dev/null || true
        ip6tables -A GHOST_IPV6_INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
        ip6tables -A GHOST_IPV6_INPUT -i lo -j ACCEPT 2>/dev/null || true
        ip6tables -A GHOST_IPV6_INPUT -j DROP 2>/dev/null || true
        if ! ip6tables -C INPUT -j GHOST_IPV6_INPUT 2>/dev/null; then
            ip6tables -I INPUT 1 -j GHOST_IPV6_INPUT 2>/dev/null || warn "ip6tables 插入 GHOST_IPV6_INPUT 链失败"
        fi
        
        # 保存规则
        if command -v netfilter-persistent &>/dev/null; then
            netfilter-persistent save &>/dev/null || true
        fi
        success "IPv6 入站和转发已阻断，OUTPUT 保持兼容（ip6tables层）"
        log "INFO" "ip6tables IPv6 INPUT chain and FORWARD policy applied, OUTPUT kept ACCEPT"
    else
        warn "ip6tables 未安装，跳过防火墙层 IPv6 阻断"
    fi
    
    if [[ "${APPEND_PUBLIC_DNS:-${LOCK_DNS:-0}}" == "1" ]]; then
        if [[ "${LOCK_DNS:-0}" == "1" && -z "${APPEND_PUBLIC_DNS:-}" ]]; then
            warn "LOCK_DNS 已改为兼容别名；实际行为是追加公共 DNS，不锁定 /etc/resolv.conf"
        fi
        warn "APPEND_PUBLIC_DNS=1 不停止 systemd-resolved，也不锁定 /etc/resolv.conf，避免破坏 1Panel 证书申请和 Docker DNS"
        if [[ "${AUTO_INSTALL:-0}" != "1" && "${SKIP_DNS_WARNING:-0}" != "1" ]]; then
            warn "如确需取消，请在 5 秒内按 Ctrl+C；默认仅追加公共 DNS"
            sleep 5
        else
            info "非交互/跳过确认模式，直接追加公共 DNS（无等待）"
        fi
        if command -v resolvectl &>/dev/null; then
            if resolvectl dns global 1.1.1.1 8.8.8.8 && resolvectl domain global "."; then
                success "DNS 已通过 systemd-resolved 配置公共解析服务器"
                log "INFO" "APPEND_PUBLIC_DNS=1 已通过 resolvectl 配置公共 DNS"
            else
                warn "resolvectl 配置失败，未直接写入 /etc/resolv.conf；请手动检查 systemd-resolved"
                log "WARN" "resolvectl 配置公共 DNS 失败"
            fi
        elif [[ -L /etc/resolv.conf ]]; then
            warn "/etc/resolv.conf 是符号链接，直接追加会被系统解析服务覆盖，已跳过写入"
            warn "建议手动执行: resolvectl dns global 1.1.1.1 8.8.8.8"
            log "WARN" "/etc/resolv.conf 是符号链接，跳过 APPEND_PUBLIC_DNS 追加"
        else
            touch /etc/resolv.conf
            grep -q '^nameserver 1\.1\.1\.1$' /etc/resolv.conf 2>/dev/null || echo "nameserver 1.1.1.1" >> /etc/resolv.conf
            grep -q '^nameserver 8\.8\.8\.8$' /etc/resolv.conf 2>/dev/null || echo "nameserver 8.8.8.8" >> /etc/resolv.conf
            success "DNS 已追加公共解析服务器，未锁定系统解析服务"
            log "INFO" "APPEND_PUBLIC_DNS=1 已追加公共 DNS"
        fi
    else
        info "DNS 修改默认关闭；如需追加公共 DNS，运行前设置 APPEND_PUBLIC_DNS=1"
    fi

    success "IPv6 防泄漏完成（sysctl + ip6tables）"
}

install_amneziawg() {
    progress 4 11 "安装 AmneziaWG（DKMS 内核模块优先）"
    
    # 检测架构
    local arch=$(uname -m)
    case "${arch}" in
        x86_64) info "检测到 x86_64 架构" ;;
        aarch64|arm64) info "检测到 ARM64 架构（甲骨文云）" ;;
        *) warn "未知架构: ${arch}，尝试继续安装" ;;
    esac
    
    # 调用统一安装入口
    install_awg_runtime
    
    success "AmneziaWG 安装完成（后端: ${AWG_BACKEND}）"
}

# 智能安装内核头文件（支持 x86_64 和 ARM64）
install_amneziawg_dkms_standalone() {
    local script="${AWG_DKMS_SCRIPT:-}"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [[ -z "${script}" ]]; then
        for path in \
            "${script_dir}/install_amneziawg_dkms_v${VERSION}.sh" \
            "${script_dir}/install_amneziawg_dkms.sh" \
            /usr/local/bin/install_amneziawg_dkms.sh \
            /root/install_amneziawg_dkms.sh \
            /tmp/install_amneziawg_dkms.sh; do
            if [[ -f "${path}" ]]; then
                script="${path}"
                break
            fi
        done
    fi

    if [[ -z "${script}" || ! -f "${script}" ]]; then
        warn "未找到 DKMS 脚本，尝试从 GitHub 下载..."
        script="/tmp/install_amneziawg_dkms.sh"
        if ! curl -fsSL --connect-timeout 10 --retry 3 \
            "https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/install_amneziawg_dkms_v${VERSION}.sh" \
            -o "${script}"; then
            warn "DKMS 脚本下载失败，将尝试 amneziawg-go 用户态后端"
            return 1
        fi
    fi

    chmod +x "${script}" 2>/dev/null || true
    
    info "调用独立 DKMS 脚本安装 AmneziaWG 内核模块: ${script}"
    if ! AWG_DKMS_REF="${AWG_DKMS_REF:-}" AWG_TOOLS_REF="${AWG_TOOLS_REF:-}" \
        DKMS_VERSION="${DKMS_VERSION:-}" GCC_VERSION="${GCC_VERSION:-}" "${script}"; then
        warn "独立 DKMS 脚本执行失败"
        return 1
    fi
    
    modprobe amneziawg 2>/dev/null
}

verify_sha256_required() {
    local file="$1" expected="$2"
    [[ -n "${expected}" ]] || return 1
    printf '%s  %s\n' "${expected}" "${file}" | sha256sum -c - >/dev/null 2>&1
}

write_awg_tools_ref_state() {
    mkdir -p /var/lib/amneziawg-tools
    printf '%s\n' "${AWG_TOOLS_REF}" > /var/lib/amneziawg-tools/ref
}

awg_tools_ref_matches() {
    local state_file="/var/lib/amneziawg-tools/ref"
    [[ -f "${state_file}" ]] || return 1
    [[ "$(cat "${state_file}" 2>/dev/null || true)" == "${AWG_TOOLS_REF}" ]]
}

write_awg_go_ref_state() {
    mkdir -p /var/lib/amneziawg-go
    printf '%s:%s\n' "${AWG_TOOLS_REF}" "${AWG_GO_REF}" > /var/lib/amneziawg-go/ref
    write_awg_tools_ref_state
}

awg_go_ref_matches() {
    local state_file="/var/lib/amneziawg-go/ref"
    [[ -f "${state_file}" ]] || return 1
    [[ "$(cat "${state_file}" 2>/dev/null || true)" == "${AWG_TOOLS_REF}:${AWG_GO_REF}" ]] || return 1
    awg_tools_ref_matches
}

install_prebuilt_amneziawg_go() {
    local arch arch_key go_url go_sha tools_url tools_sha tmp_dir awg_bin awg_quick_bin
    local installed_go=0 installed_tools=0
    arch="$(uname -m)"
    case "${arch}" in
        x86_64|amd64) arch_key="x86_64" ;;
        aarch64|arm64) arch_key="arm64" ;;
        *) return 1 ;;
    esac

    case "${arch_key}" in
        x86_64)
            go_url="${PREBUILT_AWG_GO_URL_x86_64}"
            go_sha="${PREBUILT_AWG_GO_SHA256_x86_64}"
            tools_url="${PREBUILT_AWG_TOOLS_URL_x86_64}"
            tools_sha="${PREBUILT_AWG_TOOLS_SHA256_x86_64}"
            ;;
        arm64)
            go_url="${PREBUILT_AWG_GO_URL_arm64}"
            go_sha="${PREBUILT_AWG_GO_SHA256_arm64}"
            tools_url="${PREBUILT_AWG_TOOLS_URL_arm64}"
            tools_sha="${PREBUILT_AWG_TOOLS_SHA256_arm64}"
            ;;
    esac

    [[ -n "${go_url}" || -n "${tools_url}" ]] || return 1
    tmp_dir=$(mktemp -d) || return 1

    info "尝试安装预编译 AmneziaWG 用户态工具链 (${arch_key})"
    if [[ -n "${go_url}" ]]; then
        if [[ -z "${go_sha}" ]]; then
            warn "预编译 amneziawg-go URL 已配置但 SHA256 为空，跳过该二进制"
        elif curl -fsSL --connect-timeout 10 --retry 3 "${go_url}" -o "${tmp_dir}/amneziawg-go" \
            && verify_sha256_required "${tmp_dir}/amneziawg-go" "${go_sha}" \
            && install -m 0755 "${tmp_dir}/amneziawg-go" /usr/local/bin/amneziawg-go; then
            installed_go=1
        else
            warn "预编译 amneziawg-go 下载、校验或安装失败，继续尝试其他路径"
        fi
    fi

    if [[ -n "${tools_url}" ]]; then
        if [[ -z "${tools_sha}" ]]; then
            warn "预编译 awg-tools URL 已配置但 SHA256 为空，跳过该工具包"
        elif curl -fsSL --connect-timeout 10 --retry 3 "${tools_url}" -o "${tmp_dir}/awg-tools.tar.gz" \
            && verify_sha256_required "${tmp_dir}/awg-tools.tar.gz" "${tools_sha}"; then
            mkdir -p "${tmp_dir}/tools"
            if tar -xzf "${tmp_dir}/awg-tools.tar.gz" -C "${tmp_dir}/tools"; then
                awg_bin=$(find "${tmp_dir}/tools" -type f -name awg | head -n 1)
                awg_quick_bin=$(find "${tmp_dir}/tools" -type f -name awg-quick | head -n 1)
                if [[ -n "${awg_bin}" && -n "${awg_quick_bin}" ]] \
                    && install -m 0755 "${awg_bin}" /usr/local/bin/awg \
                    && install -m 0755 "${awg_quick_bin}" /usr/local/bin/awg-quick; then
                    installed_tools=1
                else
                    warn "预编译 awg-tools 包缺少 awg/awg-quick 或安装失败"
                fi
            else
                warn "预编译 awg-tools 解压失败"
            fi
        else
            warn "预编译 awg-tools 下载或 SHA256 校验失败，继续尝试源码编译"
        fi
    fi
    rm -rf "${tmp_dir}"
    [[ "${installed_tools}" -eq 1 ]] && write_awg_tools_ref_state

    if command -v awg >/dev/null 2>&1 && command -v awg-quick >/dev/null 2>&1 && command -v amneziawg-go >/dev/null 2>&1 \
        && { [[ "${installed_go}" -eq 1 ]] || awg_go_ref_matches; } \
        && { [[ "${installed_tools}" -eq 1 ]] || awg_tools_ref_matches; }; then
        write_awg_go_ref_state
        return 0
    fi
    if [[ "${installed_go}" -eq 1 || "${installed_tools}" -eq 1 ]]; then
        warn "预编译工具链仅部分安装或缺少匹配 ref 状态，继续由源码编译补齐"
    fi
    return 1
}

go_version_at_least() {
    local have required first
    command -v go >/dev/null 2>&1 || return 1
    have="$(go env GOVERSION 2>/dev/null || true)"
    [[ -n "${have}" ]] || have="$(go version 2>/dev/null | awk '{print $3}' || true)"
    have="${have#go}"
    required="${GO_TOOLCHAIN_VERSION}"
    [[ -n "${have}" && -n "${required}" ]] || return 1
    first="$(printf '%s\n%s\n' "${required}" "${have}" | sort -V | head -n 1)"
    [[ "${first}" == "${required}" ]]
}

install_fixed_go_toolchain() {
    local arch archive sha tmp_dir go_root
    [[ -n "${GO_TOOLCHAIN_VERSION:-}" ]] || return 1

    case "$(uname -m)" in
        x86_64|amd64)
            arch="amd64"
            sha="${GO_TOOLCHAIN_SHA256_AMD64:-}"
            ;;
        aarch64|arm64)
            arch="arm64"
            sha="${GO_TOOLCHAIN_SHA256_ARM64:-}"
            ;;
        *)
            warn "当前架构不支持自动安装固定 Go 工具链: $(uname -m)"
            return 1
            ;;
    esac
    [[ -n "${sha}" ]] || { warn "Go ${GO_TOOLCHAIN_VERSION} ${arch} SHA256 为空，拒绝下载"; return 1; }

    go_root="/opt/ghost-go/go${GO_TOOLCHAIN_VERSION}"
    if [[ -x "${go_root}/bin/go" ]]; then
        export PATH="${go_root}/bin:${PATH}"
        go_version_at_least && return 0
    fi

    info "安装固定 Go 工具链 ${GO_TOOLCHAIN_VERSION} (${arch})，用于 amneziawg-go 源码编译"
    retry_command 3 5 env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl tar || {
        warn "安装 Go 工具链下载依赖失败"
        return 1
    }
    tmp_dir=$(mktemp -d) || return 1
    archive="${tmp_dir}/go${GO_TOOLCHAIN_VERSION}.linux-${arch}.tar.gz"
    if ! curl -fsSL --connect-timeout 10 --retry 3 "https://go.dev/dl/go${GO_TOOLCHAIN_VERSION}.linux-${arch}.tar.gz" -o "${archive}"; then
        warn "下载 Go ${GO_TOOLCHAIN_VERSION} 失败"
        rm -rf "${tmp_dir}"
        return 1
    fi
    if ! printf '%s  %s\n' "${sha}" "${archive}" | sha256sum -c - >/dev/null 2>&1; then
        warn "Go ${GO_TOOLCHAIN_VERSION} SHA256 校验失败"
        rm -rf "${tmp_dir}"
        return 1
    fi

    mkdir -p /opt/ghost-go
    rm -rf "${go_root}.tmp"
    mkdir -p "${go_root}.tmp"
    if ! tar -C "${go_root}.tmp" --strip-components=1 -xzf "${archive}"; then
        warn "解压 Go ${GO_TOOLCHAIN_VERSION} 失败"
        rm -rf "${tmp_dir}" "${go_root}.tmp"
        return 1
    fi
    rm -rf "${go_root}"
    mv "${go_root}.tmp" "${go_root}"
    rm -rf "${tmp_dir}"
    export PATH="${go_root}/bin:${PATH}"
    go_version_at_least
}

ensure_go_for_amneziawg_go() {
    if go_version_at_least; then
        return 0
    fi
    install_fixed_go_toolchain || {
        warn "Go 工具链版本不足，amneziawg-go 源码编译需要 Go ${GO_TOOLCHAIN_VERSION}+"
        return 1
    }
}

# 用户态回退方案（amneziawg-go）
install_amneziawg_go() {
    info "安装 AmneziaWG 用户态版本（amneziawg-go）"
    
    if command -v awg &>/dev/null && command -v awg-quick &>/dev/null && command -v amneziawg-go &>/dev/null && awg_go_ref_matches; then
        info "AmneziaWG 工具和用户态后端已安装"
        return 0
    elif command -v awg &>/dev/null && command -v awg-quick &>/dev/null && command -v amneziawg-go &>/dev/null; then
        warn "检测到既有 amneziawg-go 工具链，但 ref 状态未匹配当前固定版本，重新安装"
    fi

    if install_prebuilt_amneziawg_go; then
        success "预编译 AmneziaWG 用户态工具链安装完成"
        return 0
    fi
    info "未使用预编译工具链，继续源码编译 amneziawg-go 回退方案"

    ensure_go_for_amneziawg_go || return 1
    local build_deps=()
    if [[ -n "${PKG_CONFIG_VERSION:-}" ]]; then
        build_deps+=("pkg-config=${PKG_CONFIG_VERSION}")
    else
        build_deps+=(pkg-config)
    fi
    if [[ -n "${LIBMNL_DEV_VERSION:-}" ]]; then
        build_deps+=("libmnl-dev=${LIBMNL_DEV_VERSION}")
    else
        build_deps+=(libmnl-dev)
    fi
    retry_command 3 5 env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${build_deps[@]}" || {
        warn "固定 amneziawg-tools 编译依赖不可用，回退仓库默认版本"
        retry_command 3 5 env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq pkg-config libmnl-dev || { warn "amneziawg-tools 编译依赖安装失败"; return 1; }
    }
    
    local tmp_dir start_dir
    start_dir="$(pwd -P 2>/dev/null || printf '/')"
    tmp_dir=$(mktemp -d) || { warn "创建临时目录失败"; return 1; }
    cd "${tmp_dir}" || { warn "进入临时目录失败"; rm -rf "${tmp_dir}"; return 1; }
    
    # 克隆并安装 awg/awg-quick 工具，最多重试3次
    local clone_success=0 attempt
    for attempt in 1 2 3; do
        rm -rf amneziawg-tools
        info "克隆 amneziawg-tools ${AWG_TOOLS_REF}（尝试 $attempt/3）..."
        if git_clone_ref https://github.com/amnezia-vpn/amneziawg-tools.git amneziawg-tools "${AWG_TOOLS_REF}"; then
            clone_success=1
            break
        fi
        [ $attempt -lt 3 ] && sleep 2
    done
    [ $clone_success -eq 0 ] && { warn "克隆 amneziawg-tools 失败（3次尝试）"; cd / 2>/dev/null || true; rm -rf "${tmp_dir}"; return 1; }
    
    cd amneziawg-tools/src || { warn "进入源码目录失败"; cd / 2>/dev/null || true; rm -rf "${tmp_dir}"; return 1; }
    
    # 编译，最多重试3次
    local build_success=0
    for attempt in 1 2 3; do
        info "编译 AmneziaWG（尝试 $attempt/3）..."
        if make &>/dev/null; then
            build_success=1
            break
        fi
        [ $attempt -lt 3 ] && sleep 2
    done
    [ $build_success -eq 0 ] && { warn "编译 AmneziaWG 失败（3次尝试）"; cd / 2>/dev/null || true; rm -rf "${tmp_dir}"; return 1; }
    
    make install &>/dev/null || { warn "安装 AmneziaWG 失败"; cd / 2>/dev/null || true; rm -rf "${tmp_dir}"; return 1; }

    cd "${tmp_dir}" || { warn "进入临时目录失败"; cd / 2>/dev/null || true; rm -rf "${tmp_dir}"; return 1; }
    clone_success=0
    for attempt in 1 2 3; do
        rm -rf amneziawg-go
        info "克隆 amneziawg-go ${AWG_GO_REF}（尝试 $attempt/3）..."
        if git_clone_ref https://github.com/amnezia-vpn/amneziawg-go.git amneziawg-go "${AWG_GO_REF}"; then
            clone_success=1
            break
        fi
        [ $attempt -lt 3 ] && sleep 2
    done
    [ $clone_success -eq 0 ] && { warn "克隆 amneziawg-go 失败（3次尝试）"; cd / 2>/dev/null || true; rm -rf "${tmp_dir}"; return 1; }

    cd amneziawg-go || { warn "进入 amneziawg-go 源码目录失败"; cd / 2>/dev/null || true; rm -rf "${tmp_dir}"; return 1; }
    make &>/dev/null || { warn "编译 amneziawg-go 失败"; cd / 2>/dev/null || true; rm -rf "${tmp_dir}"; return 1; }
    make install &>/dev/null || { warn "安装 amneziawg-go 失败"; cd / 2>/dev/null || true; rm -rf "${tmp_dir}"; return 1; }
    
    if [[ -d "${start_dir}" ]] && ! cd "${start_dir}" 2>/dev/null; then
        warn "无法恢复原始目录 ${start_dir}，已切换到 /"
        cd / 2>/dev/null || true
    elif [[ ! -d "${start_dir}" ]]; then
        warn "原始目录 ${start_dir} 已不存在，已切换到 /"
        cd / 2>/dev/null || true
    fi
    rm -rf "${tmp_dir}"
    write_awg_go_ref_state
    
    success "AmneziaWG 用户态工具和后端安装完成"
    return 0
}

use_existing_amneziawg_go_runtime() {
    if command -v amneziawg-go >/dev/null 2>&1 \
        && command -v awg >/dev/null 2>&1 \
        && command -v awg-quick >/dev/null 2>&1; then
        if ! awg genkey >/dev/null 2>&1; then
            warn "既有 awg 无法执行 genkey，拒绝使用该用户态后端"
            return 1
        fi
        awg-quick --version >/dev/null 2>&1 || warn "既有 awg-quick 版本不可确认"
        amneziawg-go --version >/dev/null 2>&1 || warn "既有 amneziawg-go 版本不可确认"
        warn "DKMS 和新编译均失败，但检测到已有 amneziawg-go/awg/awg-quick 具备最小能力，继续使用既有用户态后端"
        AWG_BACKEND="go"
        return 0
    fi
    return 1
}

awg_dkms_ref_matches() {
    local state_file="/var/lib/amneziawg-dkms/ref"
    [[ -f "${state_file}" ]] || return 1
    [[ "$(cat "${state_file}" 2>/dev/null || true)" == "${AWG_DKMS_REF}" ]]
}

# 统一 AWG 运行时安装入口（自动降级）
install_awg_runtime() {
    # 优先尝试 DKMS 内核模块
    if modprobe amneziawg 2>/dev/null; then
        if ! awg_dkms_ref_matches; then
            warn "检测到 AmneziaWG 内核模块，但 ref 状态未匹配当前固定版本，调用 DKMS 脚本重装"
            if install_amneziawg_dkms_standalone; then
                AWG_BACKEND="kernel"
                success "AmneziaWG 内核模块已按固定 ref 更新"
                return 0
            fi
            warn "固定 ref DKMS 重装失败，将回退 amneziawg-go"
            if ! install_amneziawg_go && ! use_existing_amneziawg_go_runtime; then
                warn "DKMS ref 重装失败且 amneziawg-go 新编译/既有检测均失败"
                die "DKMS ref 重装失败且 amneziawg-go 安装失败，拒绝回退到无混淆的标准 WireGuard"
            fi
            AWG_BACKEND="go"
            success "使用 amneziawg-go 用户态版本（支持混淆）"
            return 0
        fi
        if ! command -v awg >/dev/null 2>&1 || ! command -v awg-quick >/dev/null 2>&1 || ! awg_tools_ref_matches; then
            warn "检测到 AmneziaWG 内核模块，但 awg-tools 缺失或 ref 未匹配当前固定版本，调用 DKMS 脚本补装工具"
            if ! install_amneziawg_dkms_standalone; then
                if ! install_amneziawg_go && ! use_existing_amneziawg_go_runtime; then
                    die "补装 awg/awg-quick 失败"
                fi
                AWG_BACKEND="go"
                success "使用 amneziawg-go 用户态版本（支持混淆）"
                return 0
            fi
        fi
        AWG_BACKEND="kernel"
        success "使用已有 AmneziaWG 内核模块"
        return 0
    fi
    
    if install_amneziawg_dkms_standalone; then
        AWG_BACKEND="kernel"
        success "使用独立 DKMS 脚本安装的 AmneziaWG 内核模块"
        return 0
    fi
    
    # 回退到用户态版本
    warn "DKMS 编译失败，自动回退到 amneziawg-go 用户态版本"
    if install_amneziawg_go || use_existing_amneziawg_go_runtime; then
        AWG_BACKEND="go"
        success "使用 amneziawg-go 用户态版本（支持混淆）"
        return 0
    fi
    
    die "DKMS 和 amneziawg-go 均失败，拒绝回退到无混淆的标准 WireGuard"
}

detect_tunnel_mtu() {
    local pmtu candidate old_mtu="${OPTIMAL_MTU}"
    if [[ "${AUTO_DETECT_MTU:-0}" != "1" ]]; then
        info "保持保守 MTU ${OPTIMAL_MTU}；如需探测可设置 AUTO_DETECT_MTU=1"
        return 0
    fi

    if ! command -v tracepath >/dev/null 2>&1; then
        warn "tracepath 未安装，使用默认 MTU ${OPTIMAL_MTU}"
        return 0
    fi

    if systemctl is-active awg-landing.service >/dev/null 2>&1; then
        local retry
        for retry in {1..10}; do
            if ip addr show awg0 2>/dev/null | grep -q "10.8.0.1"; then
                break
            fi
            sleep 1
        done
        if [[ "${retry}" -eq 10 ]] && ! ip addr show awg0 2>/dev/null | grep -q "10.8.0.1"; then
            warn "AWG 隧道未就绪，跳过 MTU 探测"
            log "WARN" "AWG 隧道未就绪，跳过 MTU 探测"
            return 0
        fi
    fi

    local pmtu_samples=() attempt sorted
    for attempt in 1 2 3; do
        pmtu=$(timeout 10 tracepath -n "${TRANSIT_IP}" 2>/dev/null | awk '/pmtu/ {print $2}' | tail -1 || true)
        if [[ -n "${pmtu}" && "${pmtu}" =~ ^[0-9]+$ && ${pmtu} -ge 1200 ]]; then
            pmtu_samples+=("${pmtu}")
        fi
        [[ "${attempt}" -lt 3 ]] && sleep 2
    done

    if [[ ${#pmtu_samples[@]} -gt 0 ]]; then
        sorted=$(printf '%s\n' "${pmtu_samples[@]}" | sort -n)
        pmtu=$(sed -n "$(( (${#pmtu_samples[@]} + 1) / 2 ))p" <<< "${sorted}")
    fi

    if [[ -z "${pmtu}" || ! "${pmtu}" =~ ^[0-9]+$ || ${pmtu} -lt 1200 ]]; then
        warn "MTU 探测失败（3次尝试，tracepath 可能被防火墙阻断），使用默认值 ${OPTIMAL_MTU}"
        log "WARN" "MTU 探测失败，使用默认值 ${OPTIMAL_MTU}"
        return 0
    fi

    candidate=$((pmtu - 120))
    if (( candidate < 1280 || candidate > 1420 )); then
        warn "MTU 探测结果 ${candidate} 超出安全范围，保持默认值 ${OPTIMAL_MTU}"
        log "WARN" "MTU 探测结果超出安全范围，保持默认值 ${OPTIMAL_MTU}"
        return 0
    fi

    OPTIMAL_MTU="${candidate}"
    info "隧道内 PMTU: ${pmtu}，AWG MTU: ${OPTIMAL_MTU}"
    if [[ "${OPTIMAL_MTU}" != "${old_mtu}" && -f "${CONFIG_DIR}/awg0.conf" ]]; then
        local delta=$((OPTIMAL_MTU - old_mtu))
        delta=${delta#-}
        if [[ "${delta}" -le 50 ]]; then
            info "MTU 变化 ${old_mtu}->${OPTIMAL_MTU} 未超过阈值，保持当前配置"
            OPTIMAL_MTU="${old_mtu}"
            return 0
        fi
        local backup_conf="${CONFIG_DIR}/awg0.conf.mtu_backup.$$"
        if ! cp "${CONFIG_DIR}/awg0.conf" "${backup_conf}"; then
            warn "无法备份 AWG 配置，跳过 MTU 调整"
            OPTIMAL_MTU="${old_mtu}"
            return 0
        fi
        if ! sed -i "s/^MTU = .*/MTU = ${OPTIMAL_MTU}/" "${CONFIG_DIR}/awg0.conf"; then
            warn "写入 MTU 失败，回退到旧 MTU: ${old_mtu}"
            mv "${backup_conf}" "${CONFIG_DIR}/awg0.conf" 2>/dev/null || true
            OPTIMAL_MTU="${old_mtu}"
            return 0
        fi
        if systemctl restart awg-landing.service 2>/dev/null; then
            sleep 3
            if ip addr show awg0 2>/dev/null | grep -q "10.8.0.1"; then
                rm -f "${backup_conf}"
                success "MTU 已调整为 ${OPTIMAL_MTU}"
            else
                warn "MTU 调整后隧道异常，回退到旧 MTU: ${old_mtu}"
                mv "${backup_conf}" "${CONFIG_DIR}/awg0.conf" 2>/dev/null || true
                systemctl restart awg-landing.service 2>/dev/null || true
                OPTIMAL_MTU="${old_mtu}"
            fi
        else
            warn "应用隧道 MTU 后重启 AWG 失败，回退到旧 MTU: ${old_mtu}"
            mv "${backup_conf}" "${CONFIG_DIR}/awg0.conf" 2>/dev/null || true
            OPTIMAL_MTU="${old_mtu}"
        fi
    fi
}

install_shadowsocks() {
    progress 5 11 "安装 Shadowsocks-2022 (sing-box)"
    
    if command -v sing-box &>/dev/null; then
        local sing_box_bin
        sing_box_bin=$(command -v sing-box)
        local installed_ver
        installed_ver=$("${sing_box_bin}" version 2>/dev/null | awk 'NR==1 {print $3}')
        if [[ "${installed_ver}" == "${SINGBOX_VERSION}" ]]; then
            if [[ ! -x /usr/local/bin/sing-box ]]; then
                install -m 0755 "${sing_box_bin}" /usr/local/bin/sing-box || die "固定 sing-box 到 /usr/local/bin 失败"
            fi
            info "sing-box ${installed_ver} 已安装，版本匹配"
            return 0
        fi
        warn "sing-box 版本不匹配（当前: ${installed_ver:-unknown}, 需要: ${SINGBOX_VERSION}），重新安装固定版本"
        rm -f /usr/local/bin/sing-box
    fi
    
    # 修复：官方脚本可能超时，改用GitHub Release直接下载
    local ARCH
    ARCH=$(uname -m)
    local DOWNLOAD_URL="" SINGBOX_SHA256=""
    
    case "${ARCH}" in
        x86_64)
            DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-amd64.tar.gz"
            SINGBOX_SHA256="${SINGBOX_SHA256_AMD64}"
            ;;
        aarch64|arm64)
            DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-arm64.tar.gz"
            SINGBOX_SHA256="${SINGBOX_SHA256_ARM64}"
            ;;
        *)
            die "不支持的架构: ${ARCH}"
            ;;
    esac
    [[ -n "${SINGBOX_SHA256}" ]] || die "sing-box ${SINGBOX_VERSION} (${ARCH}) 缺少 SHA256 固定值，拒绝安装"
    
    info "下载 sing-box ${SINGBOX_VERSION} (${ARCH})..."
    cd /tmp
    curl -fsSL --connect-timeout 10 --retry 3 "${DOWNLOAD_URL}" -o sing-box.tar.gz || die "下载 sing-box 失败"
    verify_sha256_required sing-box.tar.gz "${SINGBOX_SHA256}" || die "sing-box SHA256 校验失败"
    tar -xzf sing-box.tar.gz || die "解压 sing-box 失败"
    
    local EXTRACT_DIR=$(tar -tzf sing-box.tar.gz | head -1 | cut -f1 -d"/")
    cp "${EXTRACT_DIR}/sing-box" /usr/local/bin/ || die "安装 sing-box 失败"
    chmod +x /usr/local/bin/sing-box
    
    rm -rf sing-box.tar.gz "${EXTRACT_DIR}"
    
    success "Shadowsocks-2022 安装完成"
}

check_singbox_configs() {
    local config
    for config in "${CONFIG_DIR}/ss-main.json" "${CONFIG_DIR}/ss-backup.json"; do
        if ! /usr/local/bin/sing-box check -c "${config}" >/dev/null 2>&1; then
            die "sing-box 配置检查失败: ${config}"
        fi
    done
    success "sing-box 配置检查通过"
}



# ==========================================
# 配置
# ==========================================

rand_u32() {
    local n retries=0 fallback
    while (( retries < 100 )); do
        n=$(od -An -N4 -tu4 /dev/urandom 2>/dev/null | tr -d ' ' || true)
        if [[ "${n}" =~ ^[0-9]+$ && "${n}" -gt 0 ]]; then
            echo "${n}"
            return 0
        fi
        retries=$((retries + 1))
    done
    fallback=$(( ((RANDOM << 17) ^ (RANDOM << 2) ^ SECONDS ^ $$) & 2147483647 ))
    (( fallback > 0 )) || fallback=1
    echo "${fallback}"
}

rand_h() {
    local n
    n=$(rand_u32)
    echo $((5 + (n % 2147483643)))
}

generate_new_obfs_values() {
    JC=$((4 + RANDOM % 5))
    JMIN="${AWG_JMIN:-50}"
    JMAX="${AWG_JMAX:-200}"
    [[ "${JMIN}" =~ ^[0-9]+$ && "${JMAX}" =~ ^[0-9]+$ ]] || die "AWG_JMIN/AWG_JMAX 必须是数字"
    (( JMIN >= 50 && JMAX <= 1024 && JMAX > JMIN )) || die "AWG_JMIN/AWG_JMAX 范围无效，应满足 50 <= JMIN < JMAX <= 1024"
    S1=$((1 + RANDOM % 100))
    while true; do
        S2=$((S1 + 1 + RANDOM % 100))
        [[ $((S1 + 56)) -ne "${S2}" ]] && break
    done
    while true; do
        H1=$(rand_h)
        H2=$(rand_h)
        H3=$(rand_h)
        H4=$(rand_h)
        [[ "${H1}" != "${H2}" && "${H1}" != "${H3}" && "${H1}" != "${H4}" && "${H2}" != "${H3}" && "${H2}" != "${H4}" && "${H3}" != "${H4}" ]] && break
    done
}

valid_obfuscation_params() {
    local value
    for value in "${JC:-}" "${JMIN:-}" "${JMAX:-}" "${S1:-}" "${S2:-}" "${H1:-}" "${H2:-}" "${H3:-}" "${H4:-}"; do
        [[ "${value}" =~ ^[0-9]+$ ]] || return 1
    done
    (( JC >= 1 && JC <= 128 )) || return 1
    (( JMIN >= 1 && JMAX > JMIN )) || return 1
    (( S1 > 0 && S2 > 0 )) || return 1
    (( S1 + 56 != S2 )) || return 1
    (( H1 >= 5 && H2 >= 5 && H3 >= 5 && H4 >= 5 )) || return 1
    [[ "${H1}" != "${H2}" && "${H1}" != "${H3}" && "${H1}" != "${H4}" && "${H2}" != "${H3}" && "${H2}" != "${H4}" && "${H3}" != "${H4}" ]] || return 1
    return 0
}

recommended_obfuscation_params() {
    [[ "${JMIN:-}" =~ ^[0-9]+$ && "${JMAX:-}" =~ ^[0-9]+$ ]] || return 1
    (( JMIN >= 50 && JMAX <= 200 && JMAX > JMIN )) || return 1
}

write_obfuscation_params() {
    local params_file="$1"
    mkdir -p "${CONFIG_DIR}"
    cat > "${params_file}" <<EOF
JC=${JC}
JMIN=${JMIN}
JMAX=${JMAX}
S1=${S1}
S2=${S2}
H1=${H1}
H2=${H2}
H3=${H3}
H4=${H4}
EOF
    chmod 600 "${params_file}"
}

generate_obfuscation_params() {
    local params_file="${CONFIG_DIR}/.awg_obfs_params"
    
    if [[ -f "${params_file}" ]]; then
        source "${params_file}"
        if ! valid_obfuscation_params; then
            warn "检测到旧版或不安全 AWG 混淆参数，已按推荐范围重新生成"
            generate_new_obfs_values
            write_obfuscation_params "${params_file}"
        elif [[ "${FORCE_ROTATE_OBFS:-0}" == "1" ]]; then
            warn "FORCE_ROTATE_OBFS=1，已重新生成 AWG 混淆参数"
            generate_new_obfs_values
            write_obfuscation_params "${params_file}"
        elif ! recommended_obfuscation_params; then
            warn "已有 AWG Jmin/Jmax 不在 50-200 链式代理推荐范围；为保持客户端兼容不自动轮换，如需重置请设置 FORCE_ROTATE_OBFS=1"
        fi
        info "复用已有混淆参数（幂等性保护）"
    else
        generate_new_obfs_values
        write_obfuscation_params "${params_file}"
        info "生成新的混淆参数"
    fi
    
    # 导出为全局变量，确保所有函数都能访问
    export JC JMIN JMAX S1 S2 H1 H2 H3 H4
    log "INFO" "混淆参数已加载: JC=${JC}, JMIN=${JMIN}, JMAX=${JMAX}"
}

configure_amneziawg() {
    progress 6 11 "配置 AmneziaWG Server"
    
    mkdir -p "${CONFIG_DIR}"
    
    # 幂等性保护: 备份已有配置
    if [[ -f "${CONFIG_DIR}/awg0.conf" ]]; then
        local backup_file="${CONFIG_DIR}/awg0.conf.bak.$(date +%s)"
        cp "${CONFIG_DIR}/awg0.conf" "${backup_file}"
        cleanup_old_backups "${CONFIG_DIR}/awg0.conf"
        warn "检测到已有配置，已备份到: ${backup_file}"
    fi
    
    # v6.10 新增：AWG密钥幂等性保护
    local keys_file="${CONFIG_DIR}/.awg_keys"
    if [[ -f "${keys_file}" ]]; then
        source "${keys_file}"
        info "复用已有 AWG 密钥（幂等性保护）"
    else
        # v5.3: 落地机作为 Server，生成 Server 密钥对
        AWG_SERVER_PRIVATE=$(awg genkey)
        AWG_SERVER_PUBLIC=$(echo "${AWG_SERVER_PRIVATE}" | awg pubkey)
        log "INFO" "生成 AmneziaWG Server 密钥对"
        
        # v6.0: 同时生成客户端密钥对（用于用户本地设备 Clash Meta）
        AWG_CLIENT_PRIVATE=$(awg genkey)
        AWG_CLIENT_PUBLIC=$(echo "${AWG_CLIENT_PRIVATE}" | awg pubkey)
        log "INFO" "生成 AmneziaWG Client 密钥对（用户本地设备使用）"
        
        echo "AWG_SERVER_PRIVATE=${AWG_SERVER_PRIVATE}" > "${keys_file}"
        echo "AWG_SERVER_PUBLIC=${AWG_SERVER_PUBLIC}" >> "${keys_file}"
        echo "AWG_CLIENT_PRIVATE=${AWG_CLIENT_PRIVATE}" >> "${keys_file}"
        echo "AWG_CLIENT_PUBLIC=${AWG_CLIENT_PUBLIC}" >> "${keys_file}"
        chmod 600 "${keys_file}"
    fi
    log "INFO" "生成 AmneziaWG Server 配置"
    cat > "${CONFIG_DIR}/awg0.conf" <<EOF
[Interface]
PrivateKey = ${AWG_SERVER_PRIVATE}
Address = 10.8.0.1/24
MTU = ${OPTIMAL_MTU}
ListenPort = ${AWG_PORT}
Table = off
Jc = ${JC}
Jmin = ${JMIN}
Jmax = ${JMAX}
S1 = ${S1}
S2 = ${S2}
H1 = ${H1}
H2 = ${H2}
H3 = ${H3}
H4 = ${H4}

[Peer]
PublicKey = ${AWG_CLIENT_PUBLIC}
AllowedIPs = 10.8.0.2/32
EOF
    chmod 600 "${CONFIG_DIR}/awg0.conf"
    
    success "AmneziaWG Server 配置完成"
    
    # 保存元数据供其他脚本使用
    cat > "${CONFIG_DIR}/metadata.json" <<EOF
{
  "transit_ip": "${TRANSIT_IP}",
  "awg_port": ${AWG_PORT},
  "transit_awg_listen_port": ${TRANSIT_AWG_LISTEN_PORT},
  "ss_main_port": ${SS_MAIN_PORT},
  "ss_backup_port": ${SS_BACKUP_PORT},
  "transit_ss_listen_port": ${TRANSIT_SS_LISTEN_PORT}
}
EOF
    log "INFO" "元数据已保存到 ${CONFIG_DIR}/metadata.json"
    
    info "落地机配置完成，中转机将通过nftables DNAT转发流量到此落地机"
}

configure_shadowsocks() {
    progress 7 11 "配置 Shadowsocks-2022"
    
    generate_password
    
    # v5.9: 主轨监听 10.8.0.1（AWG 网关），通过 systemd 依赖解决启动顺序
    info "SS 主轨将监听 10.8.0.1:${SS_MAIN_PORT}（仅 AWG 隧道内可访问）"
    log "INFO" "ss-main 监听 10.8.0.1:${SS_MAIN_PORT}"
    
    # 检测家宽IP网卡并配置策略路由
    local home_iface
    home_iface=$(detect_home_ip_interface || true)
    
    if [[ -n "${home_iface}" ]] && [[ -n "${HOME_IP}" ]]; then
        if ! setup_home_ip_routing "${home_iface}" "${HOME_IP}"; then
            warn "家宽策略路由验证失败，跳过 sing-box bind_interface，避免误绑 Docker/1Panel 网卡"
            log "WARN" "家宽策略路由失败，已禁用 bind_interface: iface=${home_iface}, ip=${HOME_IP}"
            home_iface=""
            HOME_IP=""
        fi
    fi
    
    # 幂等性保护: 备份已有配置
    if [[ -f "${CONFIG_DIR}/ss-main.json" ]]; then
        local backup_file="${CONFIG_DIR}/ss-main.json.bak.$(date +%s)"
        cp "${CONFIG_DIR}/ss-main.json" "${backup_file}"
        cleanup_old_backups "${CONFIG_DIR}/ss-main.json"
        warn "检测到已有 ss-main 配置，已备份"
    fi
    
    if [[ -f "${CONFIG_DIR}/ss-backup.json" ]]; then
        local backup_file="${CONFIG_DIR}/ss-backup.json.bak.$(date +%s)"
        cp "${CONFIG_DIR}/ss-backup.json" "${backup_file}"
        cleanup_old_backups "${CONFIG_DIR}/ss-backup.json"
        warn "检测到已有 ss-backup 配置，已备份"
    fi
    
    write_singbox_ss_config() {
        local file="$1" tag="$2" listen="$3" port="$4" network="$5" bind_iface="$6"
        local tmp_file="${file}.tmp.$$"
        jq -n \
            --arg tag "${tag}" \
            --arg listen "${listen}" \
            --arg password "${SS_PASSWORD}" \
            --arg network "${network}" \
            --arg bind_iface "${bind_iface}" \
            --argjson port "${port}" '
            {
              log: {
                level: "warn",
                timestamp: true
              },
              inbounds: [
                ({
                  type: "shadowsocks",
                  tag: $tag,
                  listen: $listen,
                  listen_port: $port,
                  method: "2022-blake3-aes-256-gcm",
                  password: $password,
                  multiplex: {
                    enabled: true,
                    padding: true,
                    brutal: {
                      enabled: false
                    }
                  }
                } + (if $network == "" then {} else {network: $network} end))
              ],
              outbounds: [
                ({
                  type: "direct",
                  tag: "direct"
                } + (if $bind_iface == "" then {} else {bind_interface: $bind_iface} end))
              ]
            }' > "${tmp_file}" || die "生成 ${file} 失败"
        mv -f "${tmp_file}" "${file}" || die "写入 ${file} 失败"
    }

    if [[ -n "${home_iface}" ]]; then
        info "主轨/备轨将绑定家宽IP网卡: ${home_iface}"
        log "INFO" "ss-main/ss-backup 绑定网卡 ${home_iface}"
    fi

    log "INFO" "生成 Shadowsocks 主轨配置"
    write_singbox_ss_config "${CONFIG_DIR}/ss-main.json" "ss-main" "10.8.0.1" "${SS_MAIN_PORT}" "" "${home_iface}"
    
    log "INFO" "生成 Shadowsocks 备轨配置"
    write_singbox_ss_config "${CONFIG_DIR}/ss-backup.json" "ss-backup" "0.0.0.0" "${SS_BACKUP_PORT}" "tcp" "${home_iface}"
    
    success "Shadowsocks-2022 配置完成"
    check_singbox_configs
}


setup_systemd() {
    progress 9 11 "配置 systemd 服务"

    local awg_quick_bin
    awg_quick_bin="$(command -v awg-quick || true)"
    [[ -n "${awg_quick_bin}" ]] || die "未找到 awg-quick"
    local awg_env_line=""
    local awg_modprobe_line=""
    if [[ "${AWG_BACKEND}" == "go" ]]; then
        awg_env_line="Environment=WG_QUICK_USERSPACE_IMPLEMENTATION=amneziawg-go"
    else
        local modprobe_bin
        modprobe_bin="$(command -v modprobe || true)"
        [[ -n "${modprobe_bin}" ]] || die "内核后端需要 modprobe，但未找到 modprobe"
        awg_modprobe_line="ExecStartPre=/usr/local/bin/awg-landing-prestart.sh"
    fi

    cat > /usr/local/bin/awg-landing-monitor.sh <<'MONEOF'
#!/usr/bin/env bash
set -u

retries=0
while [ "${retries}" -lt 120 ] && ! ip addr show awg0 2>/dev/null | grep -q "10.8.0.1"; do
    sleep 2
    retries=$((retries + 1))
done

if [ "${retries}" -ge 120 ]; then
    echo "隧道建立超时" >&2
    exit 1
fi

while ip addr show awg0 2>/dev/null | grep -q "10.8.0.1"; do
    sleep 5
done

echo "隧道意外断开" >&2
exit 1
MONEOF
    chmod +x /usr/local/bin/awg-landing-monitor.sh

    if [[ "${AWG_BACKEND}" != "go" ]]; then
        cat > /usr/local/bin/awg-landing-prestart.sh <<EOF
#!/usr/bin/env bash
set -u

if "${modprobe_bin}" amneziawg 2>/dev/null; then
    exit 0
fi

logger -t awg-landing "amneziawg module missing for current kernel, attempting DKMS self-heal" 2>/dev/null || true
if [[ -x /usr/local/bin/install_amneziawg_dkms.sh ]]; then
    SKIP_APT_UPDATE=1 DKMS_VERSION="${DKMS_VERSION:-}" GCC_VERSION="${GCC_VERSION:-}" /usr/local/bin/install_amneziawg_dkms.sh >/var/log/amneziawg-dkms-prestart.log 2>&1 || true
fi

exec "${modprobe_bin}" amneziawg
EOF
        chmod +x /usr/local/bin/awg-landing-prestart.sh
    else
        rm -f /usr/local/bin/awg-landing-prestart.sh
    fi

    cat > /etc/systemd/system/awg-landing.service <<EOF
[Unit]
Description=AmneziaWG Landing Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
${awg_env_line}
${awg_modprobe_line}
ExecStartPre=-${awg_quick_bin} down /etc/landing-ghost/awg0.conf
ExecStartPre=${awg_quick_bin} up /etc/landing-ghost/awg0.conf
ExecStart=/usr/local/bin/awg-landing-monitor.sh
ExecStop=-${awg_quick_bin} down /etc/landing-ghost/awg0.conf
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    cat > /etc/systemd/system/ss-main.service <<EOF
[Unit]
Description=Shadowsocks-2022 Main Track
After=awg-landing.service
Requires=awg-landing.service

[Service]
Type=simple
ExecStart=/usr/local/bin/sing-box run -c /etc/landing-ghost/ss-main.json
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    cat > /etc/systemd/system/ss-backup.service <<EOF
[Unit]
Description=Shadowsocks-2022 Backup Track
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/sing-box run -c /etc/landing-ghost/ss-backup.json
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload || die "systemd daemon-reload 失败"
    
    
    systemctl enable awg-landing.service &>/dev/null || die "启用 AWG 服务失败"
    systemctl start awg-landing.service || die "启动 AWG 服务失败"
    log "INFO" "AmneziaWG 客户端服务已启动"
    
    # 等待隧道建立并验证 IP
    info "等待 AmneziaWG 隧道建立..."
    local tunnel_ready=false
    for i in {1..15}; do
        if ip addr show awg0 2>/dev/null | grep -q "10.8.0.1"; then
            success "隧道已建立 (10.8.0.1)"
            log "INFO" "AmneziaWG 隧道验证成功"
            tunnel_ready=true
            break
        fi
        if [[ $i -eq 15 ]]; then
            error "AmneziaWG 隧道建立失败"
            error "请检查:"
            error "  1. 中转机是否已添加此落地机的 Peer 配置"
            error "  2. 中转机防火墙是否开放 UDP ${AWG_PORT}"
            error "  3. 查看日志: journalctl -u awg-landing.service"
            log "ERROR" "隧道建立超时"
            die "隧道建立超时，安装终止"
        fi
        sleep 1
    done

    if [[ "${tunnel_ready}" == "true" ]]; then
        sleep 5
        detect_tunnel_mtu
    fi
    
    systemctl enable ss-main.service &>/dev/null || die "启用 SS 主轨服务失败"
    systemctl start ss-main.service || die "启动 SS 主轨服务失败"
    log "INFO" "Shadowsocks 主轨服务已启动"
    
    systemctl enable ss-backup.service &>/dev/null || die "启用 SS 备轨服务失败"
    systemctl start ss-backup.service || die "启动 SS 备轨服务失败"
    log "INFO" "Shadowsocks 备轨服务已启动"
    
    # 配置日志轮转
    info "配置日志轮转..."
    cat > /etc/logrotate.d/landing-ghost <<EOF
${LOG_FILE} {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
EOF
    log "INFO" "日志轮转配置完成"
    
    cat > /usr/local/bin/landing-health-check.sh <<EOF
#!/usr/bin/env bash
set -u

log_health() {
    local level="\${1:-warn}"
    shift || true
    case "\${HEALTH_LOG_LEVEL:-warn}:\${level}" in
        error:warn|error:info|warn:info) return 0 ;;
    esac
    logger -t landing-health "\${level}: \$*" 2>/dev/null || true
}

AWG_FAIL_COUNT=0
AWG_STABLE_SECONDS=0
AWG_IN_RECOVERY=0
SS_MAIN_FAIL_COUNT=0
SS_BACKUP_FAIL_COUNT=0
MAX_FAIL_COUNT=3
AWG_COOLDOWN=10
AWG_MAX_COOLDOWN="\${AWG_MAX_COOLDOWN:-300}"
case "\${AWG_MAX_COOLDOWN}" in
    ''|*[!0-9]*) AWG_MAX_COOLDOWN=300 ;;
esac
AWG_STABLE_WINDOW="\${AWG_STABLE_WINDOW:-300}"
case "\${AWG_STABLE_WINDOW}" in
    ''|*[!0-9]*) AWG_STABLE_WINDOW=300 ;;
esac
LAST_LOOP_TS="\$(date +%s)"
INITIAL_DELAY="\${LANDING_HEALTH_INITIAL_DELAY:-300}"
case "\${INITIAL_DELAY}" in
    ''|*[!0-9]*) INITIAL_DELAY=300 ;;
esac
if [ "\${INITIAL_DELAY}" -lt 300 ]; then
    INITIAL_DELAY=300
fi

detect_awg_backend() {
    if systemctl show awg-landing.service -p Environment 2>/dev/null | grep -qF 'amneziawg-go'; then
        printf '%s\n' go
    elif grep -Eq "WG_QUICK_USERSPACE_IMPLEMENTATION=[\"']?amneziawg-go" /etc/systemd/system/awg-landing.service 2>/dev/null; then
        printf '%s\n' go
    else
        printf '%s\n' kernel
    fi
}

log_health info "健康检查初始延迟 \${INITIAL_DELAY}s 后开始"
sleep "\${INITIAL_DELAY}"

while true; do
    NOW_TS="\$(date +%s)"
    LOOP_ELAPSED=\$((NOW_TS - LAST_LOOP_TS))
    [ "\${LOOP_ELAPSED}" -lt 1 ] && LOOP_ELAPSED=1
    LAST_LOOP_TS="\${NOW_TS}"
    AWG_BACKEND="\$(detect_awg_backend)"
    if ! ip addr show awg0 2>/dev/null | grep -q "10.8.0.1"; then
        AWG_STABLE_SECONDS=0
        if [ "\${AWG_IN_RECOVERY}" -eq 1 ]; then
            log_health warn "AWG稳定窗口内再次异常，重置稳定计时"
            AWG_FAIL_COUNT=1
            AWG_IN_RECOVERY=0
        else
            AWG_FAIL_COUNT=\$((AWG_FAIL_COUNT + 1))
        fi
        if [ "\${AWG_FAIL_COUNT}" -eq 1 ] || [ "\${AWG_FAIL_COUNT}" -ge "\${MAX_FAIL_COUNT}" ]; then
            log_health warn "AWG隧道异常 (失败计数: \${AWG_FAIL_COUNT}/\${MAX_FAIL_COUNT})"
        fi

        if [ "\${AWG_FAIL_COUNT}" -ge "\${MAX_FAIL_COUNT}" ]; then
            log_health warn "AWG连续失败\${MAX_FAIL_COUNT}次，执行重启"
            if [ "\${AWG_BACKEND}" = "kernel" ] && ! lsmod | grep -q '^amneziawg'; then
                log_health warn "AWG内核模块缺失，尝试加载"
                modprobe amneziawg 2>/dev/null || log_health error "modprobe amneziawg 失败"
            fi
            if systemctl restart awg-landing.service 2>/dev/null; then
                sleep "\${AWG_COOLDOWN}"
                if ip addr show awg0 2>/dev/null | grep -q "10.8.0.1"; then
                    log_health warn "AWG重启成功"
                    AWG_FAIL_COUNT=1
                    AWG_STABLE_SECONDS=0
                    AWG_IN_RECOVERY=1
                    AWG_COOLDOWN=10
                else
                    log_health warn "AWG重启后仍异常，冷却时间增加到 \${AWG_COOLDOWN}s"
                    AWG_COOLDOWN=\$((AWG_COOLDOWN * 2))
                    [ "\${AWG_COOLDOWN}" -gt "\${AWG_MAX_COOLDOWN}" ] && AWG_COOLDOWN="\${AWG_MAX_COOLDOWN}"
                fi
            else
                log_health error "awg-landing重启失败"
            fi
        fi
    else
        if [ "\${AWG_FAIL_COUNT}" -gt 0 ]; then
            AWG_STABLE_SECONDS=\$((AWG_STABLE_SECONDS + LOOP_ELAPSED))
            if [ "\${AWG_STABLE_SECONDS}" -ge "\${AWG_STABLE_WINDOW}" ]; then
                log_health info "AWG隧道已连续稳定 \${AWG_STABLE_SECONDS}s，清零失败计数"
                AWG_FAIL_COUNT=0
                AWG_STABLE_SECONDS=0
                AWG_IN_RECOVERY=0
            else
                log_health info "AWG隧道已恢复，等待稳定窗口 \${AWG_STABLE_SECONDS}/\${AWG_STABLE_WINDOW}s"
            fi
        else
            AWG_STABLE_SECONDS=0
            AWG_IN_RECOVERY=0
        fi
        AWG_COOLDOWN=10
    fi

    if command -v nc >/dev/null 2>&1; then
        if ! nc -zw3 10.8.0.1 ${SS_MAIN_PORT} >/dev/null 2>&1; then
            SS_MAIN_FAIL_COUNT=\$((SS_MAIN_FAIL_COUNT + 1))
            if [ "\${SS_MAIN_FAIL_COUNT}" -eq 1 ] || [ "\${SS_MAIN_FAIL_COUNT}" -ge "\${MAX_FAIL_COUNT}" ]; then
                log_health warn "SS主轨端口异常 (失败计数: \${SS_MAIN_FAIL_COUNT}/\${MAX_FAIL_COUNT})"
            fi
            if [ "\${SS_MAIN_FAIL_COUNT}" -ge "\${MAX_FAIL_COUNT}" ]; then
                log_health warn "SS主轨连续失败\${MAX_FAIL_COUNT}次，执行重启"
                systemctl restart ss-main.service 2>/dev/null || log_health error "ss-main重启失败"
                SS_MAIN_FAIL_COUNT=0
                sleep 5
            fi
        else
            if [ "\${SS_MAIN_FAIL_COUNT}" -gt 0 ]; then
                log_health info "SS主轨端口已恢复"
            fi
            SS_MAIN_FAIL_COUNT=0
        fi
    else
        log_health warn "nc命令不存在，跳过主轨端口检测"
    fi

    if command -v ss >/dev/null 2>&1; then
        if ! ss -H -tln "sport = :${SS_BACKUP_PORT}" 2>/dev/null | grep -q .; then
            SS_BACKUP_FAIL_COUNT=\$((SS_BACKUP_FAIL_COUNT + 1))
            if [ "\${SS_BACKUP_FAIL_COUNT}" -eq 1 ] || [ "\${SS_BACKUP_FAIL_COUNT}" -ge "\${MAX_FAIL_COUNT}" ]; then
                log_health warn "SS备轨监听异常 (失败计数: \${SS_BACKUP_FAIL_COUNT}/\${MAX_FAIL_COUNT})"
            fi
            if [ "\${SS_BACKUP_FAIL_COUNT}" -ge "\${MAX_FAIL_COUNT}" ]; then
                log_health warn "SS备轨连续失败\${MAX_FAIL_COUNT}次，执行重启"
                systemctl restart ss-backup.service 2>/dev/null || log_health error "ss-backup重启失败"
                SS_BACKUP_FAIL_COUNT=0
                sleep 5
            fi
        else
            if [ "\${SS_BACKUP_FAIL_COUNT}" -gt 0 ]; then
                log_health info "SS备轨监听已恢复"
            fi
            SS_BACKUP_FAIL_COUNT=0
        fi
    else
        log_health warn "ss命令不存在，跳过备轨监听检测"
    fi

    sleep \$((600 + RANDOM % 1200))
done
EOF
    chmod +x /usr/local/bin/landing-health-check.sh
    crontab -l 2>/dev/null | grep -v "landing-health-check.sh" | crontab - 2>/dev/null || true

    cat > /etc/systemd/system/landing-health-check.service <<EOF
[Unit]
Description=Landing Ghost Health Check
After=network-online.target awg-landing.service ss-main.service ss-backup.service
Wants=network-online.target

[Service]
Type=simple
Environment="HEALTH_LOG_LEVEL=${HEALTH_LOG_LEVEL:-warn}"
Environment="AWG_MAX_COOLDOWN=${AWG_MAX_COOLDOWN:-300}"
Environment="AWG_STABLE_WINDOW=${AWG_STABLE_WINDOW:-300}"
Environment="LANDING_HEALTH_INITIAL_DELAY=${LANDING_HEALTH_INITIAL_DELAY:-300}"
ExecStart=/usr/local/bin/landing-health-check.sh
Restart=always
RestartSec=20s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload || die "systemd daemon-reload 失败"
    systemctl enable landing-health-check.service &>/dev/null || die "启用健康检查服务失败"
    systemctl restart landing-health-check.service || die "启动健康检查服务失败"

    success "systemd 服务配置完成"
}

generate_clash_meta_yaml() {
    info "生成 Clash Meta YAML 配置..."
    
    cat > "${CONFIG_DIR}/clash-meta-config.yaml" <<YAML
# ==========================================
# Clash Meta 配置 - 落地机双轨配置
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# ==========================================
# 说明：
# 1. 主轨：通过 AmneziaWG 隧道连接落地机 SS 服务（UDP 高速）
# 2. 备轨：直连中转机 SS 端口（TCP 稳定）
# 3. 必须使用支持 AWG 混淆字段的 Mihomo(原 Clash Meta) 客户端导入
# 4. 建议 Mihomo >= v1.18.0；普通 Clash / ClashX / Shadowrocket 不支持 amnezia-wg-option
# 5. 验证方法：在 Mihomo 日志中搜索 amnezia-wg，确认混淆字段已启用

# Clash Meta 基础配置
port: 7890
socks-port: 7891
mixed-port: 7892
allow-lan: false
bind-address: '*'
mode: rule
log-level: info
ipv6: false
external-controller: 127.0.0.1:9090
external-ui: folder
secret: '$(openssl rand -hex 16)'

proxies:
  # 底层隧道：AmneziaWG（连接到中转机）
  - name: "AWG-Tunnel"
    type: wireguard
    server: ${TRANSIT_IP}
    port: ${TRANSIT_AWG_LISTEN_PORT}
    ip: 10.8.0.2  # 用户设备在AWG隧道内的虚拟IP（连接目标是中转机公网IP）
    private-key: ${AWG_CLIENT_PRIVATE}
    public-key: ${AWG_SERVER_PUBLIC}
    hidden: true
    udp: true
    mtu: ${OPTIMAL_MTU}
    allowed-ips: ['10.8.0.0/24']
    # AmneziaWG 混淆参数（静态配置，重装前不会改变）
    amnezia-wg-option:
      jc: ${JC}
      jmin: ${JMIN}
      jmax: ${JMAX}
      s1: ${S1}
      s2: ${S2}
      h1: ${H1}
      h2: ${H2}
      h3: ${H3}
      h4: ${H4}

  # 主轨：Shadowsocks-2022 UDP极速（通过AWG隧道访问落地机）
  - name: "主轨-UDP极速"
    type: ss
    server: 10.8.0.1
    port: ${SS_MAIN_PORT}  # SS Main
    cipher: 2022-blake3-aes-256-gcm
    password: "${SS_PASSWORD}"
    udp: true
    udp-over-tcp: false  # 禁用UDP over TCP，保持原生UDP性能
    # 关键：通过AWG隧道拨号
    dialer-proxy: "AWG-Tunnel"

  # 备轨：Shadowsocks-2022 TCP备用（直连中转机）
  - name: "备轨-TCP稳定"
    type: ss
    server: ${TRANSIT_IP}
    port: ${TRANSIT_SS_LISTEN_PORT}  # Transit SS Backup listen
    cipher: 2022-blake3-aes-256-gcm
    password: "${SS_PASSWORD}"
    udp: false
    udp-over-tcp: false  # 备轨固定 TCP-only，避免公网 UDP 暴露

proxy-groups:
  # 自动切换策略组（健康检查）
  - name: "自动切换"
    type: fallback
    proxies:
      - "主轨-UDP极速"
      - "备轨-TCP稳定"
    url: 'https://cp.cloudflare.com/generate_204'
    interval: 300
    tolerance: 50

  # 手动选择策略组
  - name: "手动选择"
    type: select
    proxies:
      - "自动切换"
      - "主轨-UDP极速"
      - "备轨-TCP稳定"
      - DIRECT

rules:
  # 局域网直连
  - DOMAIN-SUFFIX,local,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  # 默认走自动切换（链式代理）
  - MATCH,自动切换
YAML
    
    chmod 600 "${CONFIG_DIR}/clash-meta-config.yaml"
    success "Clash Meta 配置已生成: ${CONFIG_DIR}/clash-meta-config.yaml"

    info "生成客户端导入专用 Mihomo Profile..."
    cat > "${CONFIG_DIR}/mihomo-profile.yaml" <<YAML
proxies:
  - name: "AWG-Tunnel"
    type: wireguard
    server: ${TRANSIT_IP}
    port: ${TRANSIT_AWG_LISTEN_PORT}
    ip: 10.8.0.2
    private-key: ${AWG_CLIENT_PRIVATE}
    public-key: ${AWG_SERVER_PUBLIC}
    hidden: true
    udp: true
    mtu: ${OPTIMAL_MTU}
    allowed-ips: ['10.8.0.0/24']
    amnezia-wg-option:
      jc: ${JC}
      jmin: ${JMIN}
      jmax: ${JMAX}
      s1: ${S1}
      s2: ${S2}
      h1: ${H1}
      h2: ${H2}
      h3: ${H3}
      h4: ${H4}

  - name: "主轨-UDP极速"
    type: ss
    server: 10.8.0.1
    port: ${SS_MAIN_PORT}
    cipher: 2022-blake3-aes-256-gcm
    password: "${SS_PASSWORD}"
    udp: true
    udp-over-tcp: false
    dialer-proxy: "AWG-Tunnel"

  - name: "备轨-TCP稳定"
    type: ss
    server: ${TRANSIT_IP}
    port: ${TRANSIT_SS_LISTEN_PORT}
    cipher: 2022-blake3-aes-256-gcm
    password: "${SS_PASSWORD}"
    udp: false
    udp-over-tcp: false

proxy-groups:
  - name: "自动切换"
    type: fallback
    proxies:
      - "主轨-UDP极速"
      - "备轨-TCP稳定"
    url: 'https://cp.cloudflare.com/generate_204'
    interval: 300
    tolerance: 50

  - name: "手动选择"
    type: select
    proxies:
      - "自动切换"
      - "主轨-UDP极速"
      - "备轨-TCP稳定"
      - DIRECT

rules:
  - DOMAIN-SUFFIX,local,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - MATCH,自动切换
YAML
    chmod 600 "${CONFIG_DIR}/mihomo-profile.yaml"
    success "客户端导入专用 Mihomo Profile 已生成: ${CONFIG_DIR}/mihomo-profile.yaml"

    info "生成 Mihomo 静态 AWG 隧道..."
    cat > "${CONFIG_DIR}/mihomo-static-awg-proxy.yaml" <<YAML
proxies:
  - name: "AWG-Tunnel"
    type: wireguard
    server: ${TRANSIT_IP}
    port: ${TRANSIT_AWG_LISTEN_PORT}
    ip: 10.8.0.2
    private-key: ${AWG_CLIENT_PRIVATE}
    public-key: ${AWG_SERVER_PUBLIC}
    hidden: true
    udp: true
    mtu: ${OPTIMAL_MTU}
    allowed-ips: ['10.8.0.0/24']
    amnezia-wg-option:
      jc: ${JC}
      jmin: ${JMIN}
      jmax: ${JMAX}
      s1: ${S1}
      s2: ${S2}
      h1: ${H1}
      h2: ${H2}
      h3: ${H3}
      h4: ${H4}
YAML
    chmod 600 "${CONFIG_DIR}/mihomo-static-awg-proxy.yaml"
    success "Mihomo 静态 AWG 隧道已生成: ${CONFIG_DIR}/mihomo-static-awg-proxy.yaml"

    info "生成 GHOST_STATIC_PROXIES 可粘贴 JS 对象..."
    jq -n \
        --arg name "AWG-Tunnel" \
        --arg server "${TRANSIT_IP}" \
        --arg ip "10.8.0.2" \
        --arg private_key "${AWG_CLIENT_PRIVATE}" \
        --arg public_key "${AWG_SERVER_PUBLIC}" \
        --argjson port "${TRANSIT_AWG_LISTEN_PORT}" \
        --argjson mtu "${OPTIMAL_MTU}" \
        --argjson jc "${JC}" \
        --argjson jmin "${JMIN}" \
        --argjson jmax "${JMAX}" \
        --argjson s1 "${S1}" \
        --argjson s2 "${S2}" \
        --argjson h1 "${H1}" \
        --argjson h2 "${H2}" \
        --argjson h3 "${H3}" \
        --argjson h4 "${H4}" \
        '{
            name: $name,
            type: "wireguard",
            server: $server,
            port: $port,
            ip: $ip,
            "private-key": $private_key,
            "public-key": $public_key,
            hidden: true,
            udp: true,
            mtu: $mtu,
            "allowed-ips": ["10.8.0.0/24"],
            "amnezia-wg-option": {
                jc: $jc,
                jmin: $jmin,
                jmax: $jmax,
                s1: $s1,
                s2: $s2,
                h1: $h1,
                h2: $h2,
                h3: $h3,
                h4: $h4
            }
        }' > "${CONFIG_DIR}/mihomo-static-awg-proxy.js"
    chmod 600 "${CONFIG_DIR}/mihomo-static-awg-proxy.js"
    success "GHOST_STATIC_PROXIES JS 对象已生成: ${CONFIG_DIR}/mihomo-static-awg-proxy.js"

    {
        echo "const GHOST_STATIC_PROXIES = ["
        sed 's/^/  /' "${CONFIG_DIR}/mihomo-static-awg-proxy.js"
        echo "];"
    } > "${CONFIG_DIR}/ghost-static-proxies.js"
    chmod 600 "${CONFIG_DIR}/ghost-static-proxies.js"
    success "GHOST_STATIC_PROXIES JS 常量已生成: ${CONFIG_DIR}/ghost-static-proxies.js"

    info "生成 Sub-Store 自洽节点 Provider YAML..."
    cat > "${CONFIG_DIR}/substore-awg-for-mihomo.yaml" <<YAML
proxies:
  - name: "AWG-Tunnel"
    type: wireguard
    server: ${TRANSIT_IP}
    port: ${TRANSIT_AWG_LISTEN_PORT}
    ip: 10.8.0.2
    private-key: ${AWG_CLIENT_PRIVATE}
    public-key: ${AWG_SERVER_PUBLIC}
    hidden: true
    udp: true
    mtu: ${OPTIMAL_MTU}
    allowed-ips: ['10.8.0.0/24']
    amnezia-wg-option:
      jc: ${JC}
      jmin: ${JMIN}
      jmax: ${JMAX}
      s1: ${S1}
      s2: ${S2}
      h1: ${H1}
      h2: ${H2}
      h3: ${H3}
      h4: ${H4}

  - name: "主轨-UDP极速"
    type: ss
    server: 10.8.0.1
    port: ${SS_MAIN_PORT}
    cipher: 2022-blake3-aes-256-gcm
    password: "${SS_PASSWORD}"
    udp: true
    udp-over-tcp: false
    dialer-proxy: "AWG-Tunnel"

  - name: "备轨-TCP稳定"
    type: ss
    server: ${TRANSIT_IP}
    port: ${TRANSIT_SS_LISTEN_PORT}
    cipher: 2022-blake3-aes-256-gcm
    password: "${SS_PASSWORD}"
    udp: false
    udp-over-tcp: false
YAML
    chmod 600 "${CONFIG_DIR}/substore-awg-for-mihomo.yaml"
    cp "${CONFIG_DIR}/substore-awg-for-mihomo.yaml" "${CONFIG_DIR}/clash-meta-proxies.yaml"
    chmod 600 "${CONFIG_DIR}/clash-meta-proxies.yaml"
    base64 -w0 "${CONFIG_DIR}/substore-awg-for-mihomo.yaml" > "${CONFIG_DIR}/substore-awg-for-mihomo-base64.txt"
    chmod 600 "${CONFIG_DIR}/substore-awg-for-mihomo-base64.txt"
    success "Sub-Store 自洽 Provider 已生成: ${CONFIG_DIR}/substore-awg-for-mihomo.yaml"

    local substore_self_b64_decoded
    substore_self_b64_decoded=$(mktemp)
    if ! grep -Fq 'name: "AWG-Tunnel"' "${CONFIG_DIR}/substore-awg-for-mihomo.yaml"; then
        warn "substore-awg-for-mihomo.yaml 缺少 AWG-Tunnel 节点，自洽 Provider 不完整"
    fi
    if ! grep -Fq 'dialer-proxy: "AWG-Tunnel"' "${CONFIG_DIR}/substore-awg-for-mihomo.yaml"; then
        warn "substore-awg-for-mihomo.yaml 缺少 dialer-proxy 引用，主轨可能不会走 AWG"
    fi
    if base64 -d "${CONFIG_DIR}/substore-awg-for-mihomo-base64.txt" > "${substore_self_b64_decoded}" 2>/dev/null; then
        for substore_key in 'AWG-Tunnel' 'amnezia-wg-option' 'dialer-proxy: "AWG-Tunnel"' '主轨-UDP极速' '备轨-TCP稳定'; do
            if ! grep -Fq "${substore_key}" "${substore_self_b64_decoded}"; then
                warn "substore-awg-for-mihomo-base64.txt 解码后缺少关键字段: ${substore_key}"
            fi
        done
    else
        warn "substore-awg-for-mihomo-base64.txt 解码失败"
    fi
    rm -f "${substore_self_b64_decoded}"

    info "生成 Sub-Store provider-only YAML（仅给已静态注入 AWG-Tunnel 的基础配置使用）..."
    cat > "${CONFIG_DIR}/substore-provider-only.yaml" <<YAML
proxies:
  - name: "主轨-UDP极速"
    type: ss
    server: 10.8.0.1
    port: ${SS_MAIN_PORT}
    cipher: 2022-blake3-aes-256-gcm
    password: "${SS_PASSWORD}"
    udp: true
    udp-over-tcp: false
    dialer-proxy: "AWG-Tunnel"

  - name: "备轨-TCP稳定"
    type: ss
    server: ${TRANSIT_IP}
    port: ${TRANSIT_SS_LISTEN_PORT}
    cipher: 2022-blake3-aes-256-gcm
    password: "${SS_PASSWORD}"
    udp: false
    udp-over-tcp: false
YAML
    chmod 600 "${CONFIG_DIR}/substore-provider-only.yaml"
    success "Sub-Store provider-only YAML 已生成: ${CONFIG_DIR}/substore-provider-only.yaml"

    info "生成 Sub-Store 完整 Mihomo 模板..."
    cp "${CONFIG_DIR}/mihomo-profile.yaml" "${CONFIG_DIR}/substore-mihomo-full.yaml"
    base64 -w0 "${CONFIG_DIR}/substore-mihomo-full.yaml" > "${CONFIG_DIR}/substore-mihomo-full-base64.txt"
    chmod 600 "${CONFIG_DIR}/substore-mihomo-full.yaml" "${CONFIG_DIR}/substore-mihomo-full-base64.txt"
    if awk '/^proxy-groups:/,/^rules:/' "${CONFIG_DIR}/substore-mihomo-full.yaml" | grep -Fq 'AWG-Tunnel'; then
        warn "substore-mihomo-full.yaml 的策略组包含 AWG-Tunnel，节点列表可能污染"
    fi
    success "Sub-Store 完整 Mihomo 模板已生成: ${CONFIG_DIR}/substore-mihomo-full.yaml"

    info "生成 Sub-Store 逐行 JSON..."
    {
        jq -nc \
            --arg name "AWG-Tunnel" \
            --arg server "${TRANSIT_IP}" \
            --arg ip "10.8.0.2" \
            --arg private_key "${AWG_CLIENT_PRIVATE}" \
            --arg public_key "${AWG_SERVER_PUBLIC}" \
            --argjson port "${TRANSIT_AWG_LISTEN_PORT}" \
            --argjson mtu "${OPTIMAL_MTU}" \
            --argjson jc "${JC}" \
            --argjson jmin "${JMIN}" \
            --argjson jmax "${JMAX}" \
            --argjson s1 "${S1}" \
            --argjson s2 "${S2}" \
            --argjson h1 "${H1}" \
            --argjson h2 "${H2}" \
            --argjson h3 "${H3}" \
            --argjson h4 "${H4}" \
            '{
                name: $name,
                type: "wireguard",
                server: $server,
                port: $port,
                ip: $ip,
                "private-key": $private_key,
                "public-key": $public_key,
                hidden: true,
                udp: true,
                mtu: $mtu,
                "allowed-ips": ["10.8.0.0/24"],
                "amnezia-wg-option": {
                    jc: $jc,
                    jmin: $jmin,
                    jmax: $jmax,
                    s1: $s1,
                    s2: $s2,
                    h1: $h1,
                    h2: $h2,
                    h3: $h3,
                    h4: $h4
                }
            }'
        jq -nc \
            --arg name "主轨-UDP极速" \
            --arg password "${SS_PASSWORD}" \
            --argjson port "${SS_MAIN_PORT}" \
            '{
                name: $name,
                type: "ss",
                server: "10.8.0.1",
                port: $port,
                cipher: "2022-blake3-aes-256-gcm",
                password: $password,
                udp: true,
                "udp-over-tcp": false,
                "dialer-proxy": "AWG-Tunnel"
            }'
        jq -nc \
            --arg name "备轨-TCP稳定" \
            --arg server "${TRANSIT_IP}" \
            --arg password "${SS_PASSWORD}" \
            --argjson port "${TRANSIT_SS_LISTEN_PORT}" \
            '{
                name: $name,
                type: "ss",
                server: $server,
                port: $port,
                cipher: "2022-blake3-aes-256-gcm",
                password: $password,
                udp: false,
                "udp-over-tcp": false
            }'
    } > "${CONFIG_DIR}/substore-awg-for-mihomo-jsonlines.txt"
    chmod 600 "${CONFIG_DIR}/substore-awg-for-mihomo-jsonlines.txt"
    cp "${CONFIG_DIR}/substore-awg-for-mihomo-jsonlines.txt" "${CONFIG_DIR}/clash-meta-substore-nodes.txt"
    chmod 600 "${CONFIG_DIR}/clash-meta-substore-nodes.txt"
    success "Sub-Store 逐行 JSON 已生成: ${CONFIG_DIR}/substore-awg-for-mihomo-jsonlines.txt"

    info "生成本地 Base64 一键导入文件..."
    base64 -w0 "${CONFIG_DIR}/clash-meta-config.yaml" > "${CONFIG_DIR}/clash-meta-subscription.txt"
    base64 -w0 "${CONFIG_DIR}/mihomo-profile.yaml" > "${CONFIG_DIR}/clash-meta-import-block.txt"
    chmod 600 "${CONFIG_DIR}/clash-meta-subscription.txt" "${CONFIG_DIR}/clash-meta-import-block.txt"
    success "完整 Clash Meta Base64 已生成: ${CONFIG_DIR}/clash-meta-subscription.txt"
    success "Mihomo Profile Base64 已生成: ${CONFIG_DIR}/clash-meta-import-block.txt"

    {
        echo "# Sub-Store 自洽 Provider：包含隐藏 AWG-Tunnel + 主轨 + 备轨，可作为 Clash Proxies YAML Provider。"
        echo "# ===== SUBSTORE_SELF_CONTAINED_YAML_START ====="
        cat "${CONFIG_DIR}/substore-awg-for-mihomo.yaml"
        echo "# ===== SUBSTORE_SELF_CONTAINED_YAML_END ====="
        echo
        echo "# Sub-Store 完整 Mihomo 模板：包含代理、策略组和规则，可用于完整订阅模板。"
        echo "# ===== SUBSTORE_MIHOMO_FULL_START ====="
        cat "${CONFIG_DIR}/substore-mihomo-full.yaml"
        echo "# ===== SUBSTORE_MIHOMO_FULL_END ====="
        echo
        echo "# provider-only：仅给已经通过 GHOST_STATIC_PROXIES 静态注入 AWG-Tunnel 的基础配置使用。"
        echo "# ===== SUBSTORE_PROVIDER_ONLY_START ====="
        cat "${CONFIG_DIR}/substore-provider-only.yaml"
        echo "# ===== SUBSTORE_PROVIDER_ONLY_END ====="
    } > "${CONFIG_DIR}/substore-copy.txt"
    chmod 600 "${CONFIG_DIR}/substore-copy.txt"
    success "Sub-Store 复制文件已生成: ${CONFIG_DIR}/substore-copy.txt"

    cat > "${CONFIG_DIR}/substore-import-guide.txt" <<GUIDE
Ghost-Proxy Sub-Store / ClashMeta 导入指南

一、Mihomo 直导（最简单）
  cat ${CONFIG_DIR}/clash-meta-subscription.txt
  复制 Base64 到支持 Base64 配置导入的客户端。该入口是完整 Profile，不经过 Sub-Store。

二、Sub-Store 推荐 Provider（最稳）
  1. 在 ClashMeta/Mihomo 基础配置中静态加入 AWG-Tunnel:
     cat ${CONFIG_DIR}/mihomo-static-awg-proxy.yaml
  2. Sub-Store 只导入主轨/备轨 Provider:
     cat ${CONFIG_DIR}/substore-provider-only.yaml
     Sub-Store 输出格式必须保持 Clash，不要转成 Surge/Stash/Sing-box，否则 dialer-proxy 可能被丢弃。
  3. ClashMeta 订阅侧引用 Sub-Store 输出链接时，建议这样写:

proxy-providers:
  ghost:
    type: http
    url: "你的 Sub-Store 输出链接"
    path: ./providers/ghost.yaml
    exclude-filter: '^AWG-Tunnel$'
    health-check:
      enable: true
      url: https://cp.cloudflare.com/generate_204
      interval: 300

proxy-groups:
  - name: 自动切换
    type: fallback
    use: [ghost]
    filter: '^(主轨-UDP极速|备轨-TCP稳定)$'
    exclude-filter: '^AWG-Tunnel$'
    url: https://cp.cloudflare.com/generate_204
    interval: 300

三、自洽 Provider（兼容性取决于 Sub-Store/客户端）
  cat ${CONFIG_DIR}/substore-awg-for-mihomo.yaml
  该文件包含 hidden AWG-Tunnel、主轨、备轨，只适合作为 Clash Proxies Provider。
  若 Sub-Store 丢弃 hidden 或 dialer-proxy，主轨会断链或 AWG-Tunnel 会显示到节点列表；此时改用第二种 provider-only 分离法。

四、不要混用
  ${CONFIG_DIR}/substore-mihomo-full.yaml 是完整 Mihomo Profile，不是节点 Provider。
  它适合直接导入 Mihomo 或作为完整模板，不要当作 Sub-Store 节点 Provider。
  Base64、Provider YAML、完整 Profile 不要混进同一个订阅入口。
GUIDE
    chmod 600 "${CONFIG_DIR}/substore-import-guide.txt"
    success "Sub-Store / ClashMeta 导入指南已生成: ${CONFIG_DIR}/substore-import-guide.txt"

    local ss_userinfo ss_uri
    ss_userinfo=$(printf '%s:%s' "2022-blake3-aes-256-gcm" "${SS_PASSWORD}" | base64 | tr -d '\n')
    ss_uri="ss://${ss_userinfo}@${TRANSIT_IP}:${TRANSIT_SS_LISTEN_PORT}#Ghost-Backup-TCP"
    printf '%s\n' "${ss_uri}" > "${CONFIG_DIR}/ss-backup-uri.txt"
    base64 -w0 "${CONFIG_DIR}/ss-backup-uri.txt" > "${CONFIG_DIR}/ss-backup-uri-base64.txt"
    chmod 600 "${CONFIG_DIR}/ss-backup-uri.txt" "${CONFIG_DIR}/ss-backup-uri-base64.txt"
    success "兼容 SS 备轨 URI 已生成: ${CONFIG_DIR}/ss-backup-uri.txt"
    success "兼容 SS 备轨 URI Base64 已生成: ${CONFIG_DIR}/ss-backup-uri-base64.txt"
}

install_landing_firewall_apply_service() {
    cat > /usr/local/bin/ghost-landing-firewall-apply.sh <<'EOF'
#!/usr/bin/env bash
set -u

CONFIG_FILE="/etc/landing-ghost/metadata.json"

command -v iptables >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0
[[ -s "${CONFIG_FILE}" ]] || exit 0

TRANSIT_IP="$(jq -r '.transit_ip // ""' "${CONFIG_FILE}" 2>/dev/null || true)"
AWG_PORT="$(jq -r '.awg_port // ""' "${CONFIG_FILE}" 2>/dev/null || true)"
SS_BACKUP_PORT="$(jq -r '.ss_backup_port // ""' "${CONFIG_FILE}" 2>/dev/null || true)"

[[ -n "${TRANSIT_IP}" && "${AWG_PORT}" =~ ^[0-9]+$ && "${SS_BACKUP_PORT}" =~ ^[0-9]+$ ]] || exit 0

tmp_chain="GHOST_LANDING_INPUT_NEW"
while iptables -D INPUT -j "${tmp_chain}" 2>/dev/null; do :; done
iptables -F "${tmp_chain}" 2>/dev/null || true
iptables -X "${tmp_chain}" 2>/dev/null || true
iptables -N "${tmp_chain}" 2>/dev/null || exit 0
iptables -A "${tmp_chain}" -s "${TRANSIT_IP}" -p udp --dport "${AWG_PORT}" -m comment --comment ghost-proxy-landing -j ACCEPT 2>/dev/null || true
iptables -A "${tmp_chain}" -s "${TRANSIT_IP}" -p icmp --icmp-type echo-request -m comment --comment ghost-proxy-landing -j ACCEPT 2>/dev/null || true
iptables -A "${tmp_chain}" -s "${TRANSIT_IP}" -p tcp --dport "${SS_BACKUP_PORT}" -m comment --comment ghost-proxy-landing -j ACCEPT 2>/dev/null || true
iptables -A "${tmp_chain}" -p udp --dport "${AWG_PORT}" -m comment --comment ghost-proxy-landing -j DROP 2>/dev/null || true
iptables -A "${tmp_chain}" -p tcp --dport "${SS_BACKUP_PORT}" -m comment --comment ghost-proxy-landing -j DROP 2>/dev/null || true
iptables -A "${tmp_chain}" -p udp --dport "${SS_BACKUP_PORT}" -m comment --comment ghost-proxy-landing -j DROP 2>/dev/null || true
iptables -A "${tmp_chain}" -j RETURN 2>/dev/null || true
iptables -I INPUT 1 -j "${tmp_chain}" 2>/dev/null || exit 0
while iptables -D INPUT -j GHOST_LANDING_INPUT 2>/dev/null; do :; done
iptables -F GHOST_LANDING_INPUT 2>/dev/null || true
iptables -X GHOST_LANDING_INPUT 2>/dev/null || true
iptables -E "${tmp_chain}" GHOST_LANDING_INPUT 2>/dev/null || exit 0

netfilter-persistent save >/dev/null 2>&1 || true
EOF
    chmod +x /usr/local/bin/ghost-landing-firewall-apply.sh

    cat > /etc/systemd/system/ghost-landing-firewall.service <<'EOF'
[Unit]
Description=Ghost-Proxy Landing Firewall Rules
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ghost-landing-firewall-apply.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable ghost-landing-firewall.service >/dev/null 2>&1 || warn "启用落地防火墙重插服务失败"
    systemctl restart ghost-landing-firewall.service >/dev/null 2>&1 || warn "启动落地防火墙重插服务失败"
}

setup_firewall() {
    progress 8 11 "配置防火墙"
    
    local ssh_port=""
    if [[ -f /etc/ssh/sshd_config ]]; then
        ssh_port=$(awk '$1 == "Port" && $2 ~ /^[0-9]+$/ {print $2; exit}' /etc/ssh/sshd_config 2>/dev/null || true)
    fi
    if [[ -z "${ssh_port}" ]]; then
        ssh_port=$(ss -H -tlnp 2>/dev/null | awk '/sshd/ {print $4; exit}' | grep -oE '[0-9]+$' || true)
    fi
    ssh_port=${ssh_port:-22}
    
    iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || iptables -I INPUT -i lo -j ACCEPT
    iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    iptables -C INPUT -p tcp --dport ${ssh_port} -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport ${ssh_port} -j ACCEPT
    
    while iptables -D INPUT -s "${TRANSIT_IP}" -p udp --dport "${AWG_PORT}" -m comment --comment ghost-proxy-landing -j ACCEPT 2>/dev/null; do :; done
    while iptables -D INPUT -s "${TRANSIT_IP}" -p icmp --icmp-type echo-request -m comment --comment ghost-proxy-landing -j ACCEPT 2>/dev/null; do :; done
    while iptables -D INPUT -s "${TRANSIT_IP}" -p tcp --dport "${SS_BACKUP_PORT}" -m comment --comment ghost-proxy-landing -j ACCEPT 2>/dev/null; do :; done
    while iptables -D INPUT -p udp --dport "${AWG_PORT}" -m comment --comment ghost-proxy-landing -j DROP 2>/dev/null; do :; done
    while iptables -D INPUT -p tcp --dport "${SS_BACKUP_PORT}" -m comment --comment ghost-proxy-landing -j DROP 2>/dev/null; do :; done
    while iptables -D INPUT -p udp --dport "${SS_BACKUP_PORT}" -m comment --comment ghost-proxy-landing -j DROP 2>/dev/null; do :; done
    while iptables -D INPUT -s "${TRANSIT_IP}" -p udp --dport "${AWG_PORT}" -j ACCEPT 2>/dev/null; do :; done
    while iptables -D INPUT -s "${TRANSIT_IP}" -p icmp --icmp-type echo-request -j ACCEPT 2>/dev/null; do :; done
    while iptables -D INPUT -s "${TRANSIT_IP}" -p tcp --dport "${SS_BACKUP_PORT}" -j ACCEPT 2>/dev/null; do :; done
    while iptables -D INPUT -p udp --dport "${AWG_PORT}" -j DROP 2>/dev/null; do :; done
    while iptables -D INPUT -p tcp --dport "${SS_BACKUP_PORT}" -j DROP 2>/dev/null; do :; done
    while iptables -D INPUT -p udp --dport "${SS_BACKUP_PORT}" -j DROP 2>/dev/null; do :; done

    local tmp_chain="GHOST_LANDING_INPUT_NEW"
    while iptables -D INPUT -j "${tmp_chain}" 2>/dev/null; do :; done
    iptables -F "${tmp_chain}" 2>/dev/null || true
    iptables -X "${tmp_chain}" 2>/dev/null || true
    iptables -N "${tmp_chain}"
    iptables -A "${tmp_chain}" -s "${TRANSIT_IP}" -p udp --dport "${AWG_PORT}" -m comment --comment ghost-proxy-landing -j ACCEPT
    iptables -A "${tmp_chain}" -s "${TRANSIT_IP}" -p icmp --icmp-type echo-request -m comment --comment ghost-proxy-landing -j ACCEPT
    iptables -A "${tmp_chain}" -s "${TRANSIT_IP}" -p tcp --dport "${SS_BACKUP_PORT}" -m comment --comment ghost-proxy-landing -j ACCEPT
    iptables -A "${tmp_chain}" -p udp --dport "${AWG_PORT}" -m comment --comment ghost-proxy-landing -j DROP
    iptables -A "${tmp_chain}" -p tcp --dport "${SS_BACKUP_PORT}" -m comment --comment ghost-proxy-landing -j DROP
    iptables -A "${tmp_chain}" -p udp --dport "${SS_BACKUP_PORT}" -m comment --comment ghost-proxy-landing -j DROP
    iptables -A "${tmp_chain}" -j RETURN
    iptables -I INPUT 1 -j "${tmp_chain}"
    while iptables -D INPUT -j GHOST_LANDING_INPUT 2>/dev/null; do :; done
    iptables -F GHOST_LANDING_INPUT 2>/dev/null || true
    iptables -X GHOST_LANDING_INPUT 2>/dev/null || true
    iptables -E "${tmp_chain}" GHOST_LANDING_INPUT
    
    # ==========================================
    # 【安全红线】内网业务端口隔离
    # ==========================================
    # 1Panel (8888) 和 AI Agent (3000/5000/8000/8080) 端口
    # 必须且只能绑定在 AWG 内网 IP (10.8.0.1) 或 Docker 内网
    # 绝不允许在公网防火墙上放行这些端口
    # 如需访问，请使用 SSH 隧道: ssh -L 8888:10.8.0.1:8888 root@落地机IP
    
    # v5.9: Docker 共存规则（不添加末尾 DROP，与 1Panel/Docker 共存）
    iptables -C INPUT -i docker0 -j ACCEPT 2>/dev/null || iptables -A INPUT -i docker0 -j ACCEPT
    iptables -C INPUT -i br-+ -j ACCEPT 2>/dev/null || iptables -A INPUT -i br-+ -j ACCEPT
    iptables -C INPUT -i awg0 -j ACCEPT 2>/dev/null || iptables -A INPUT -i awg0 -j ACCEPT
    netfilter-persistent save &>/dev/null || die "保存防火墙规则失败"
    install_landing_firewall_apply_service
    
    success "防火墙配置完成"
}

optimize_system() {
    progress 10 11 "优化系统参数"
    
    # v6.27: 精简 sysctl 优化，只保留 BBR + fq（核心优化）
    cat > /etc/sysctl.d/99-landing-ghost.conf <<EOF
# BBR 拥塞控制算法（核心优化）
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF
    
    sysctl -p /etc/sysctl.d/99-landing-ghost.conf &>/dev/null
    log "INFO" "系统参数已应用（BBR + fq）"
    
    success "系统优化完成"
}

print_client_config() {
    progress 11 11 "生成客户端配置"
    
    local public_ip landing_label
    public_ip="${LANDING_PUBLIC_IP:-${PUBLIC_IP:-}}"
    if [[ -z "${public_ip}" ]]; then
        public_ip=$(curl -fsS4 --max-time 5 https://ifconfig.me/ip || true)
    fi
    if [[ -z "${public_ip}" ]]; then
        public_ip="<请手动填写落地机公网IP>"
        warn "无法自动获取落地机公网 IP；可设置 LANDING_PUBLIC_IP 或 PUBLIC_IP 后重跑，或手动替换中转机命令中的占位符"
    fi
    landing_label="${LANDING_NAME:-落地机-$(date +%Y%m%d)}"
    
    [[ -t 1 ]] && clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  落地机安装完成!${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}📱 客户端配置信息:${NC}"
    echo ""
    echo -e "${CYAN}【主轨 - 推荐】UDP 高速通道${NC}"
    echo "  服务器: ${TRANSIT_IP}"
    echo "  端口: ${TRANSIT_AWG_LISTEN_PORT}"
    echo "  密码: ${SS_PASSWORD}"
    echo "  加密: 2022-blake3-aes-256-gcm"
    echo "  备注: 需要先连接 AmneziaWG,然后代理指向 10.8.0.1:${SS_MAIN_PORT}"
    echo ""
    echo -e "${CYAN}【备轨】TCP 稳定通道${NC}"
    echo "  服务器: ${TRANSIT_IP}"
    echo "  端口: ${TRANSIT_SS_LISTEN_PORT}"
    echo "  密码: ${SS_PASSWORD}"
    echo "  加密: 2022-blake3-aes-256-gcm"
    echo "  备注: 直连,无需 AmneziaWG"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠️  重要提示:${NC}"
    echo "  1. 主轨速度快但需要 AmneziaWG 客户端"
    echo "  2. 备轨稳定但速度略慢"
    echo "  3. 必须使用 Mihomo(原 Clash Meta) v1.18.0+，旧 Clash 可能不识别 AmneziaWG 混淆字段"
    echo "  4. 建议 Mihomo 直导使用完整 Base64；Sub-Store 节点订阅使用 provider-only 分离法"
    echo "  5. 本机 IP: ${public_ip}"
    echo ""
    echo -e "${YELLOW}🔧 中转机配置:${NC}"
    echo "  落地机公网 IP: ${public_ip}"
    echo "  中转 AWG 监听端口: ${TRANSIT_AWG_LISTEN_PORT} -> 落地 ${AWG_PORT}"
    echo "  中转 SS 监听端口: ${TRANSIT_SS_LISTEN_PORT} -> 落地 ${SS_BACKUP_PORT}"
    echo ""
    echo -e "${YELLOW}🔒 安全增强功能:${NC}"
    echo "  - IPv6 已防泄漏（sysctl + ip6tables）"
    echo "  - 密码已保存，重新运行脚本不会改变"
    if [[ "${APPEND_PUBLIC_DNS:-${LOCK_DNS:-0}}" == "1" ]]; then
        echo "  - DNS 已追加公共解析服务器（未锁定 resolv.conf）"
    fi
    
    if [[ -n "${HOME_IP}" ]]; then
        echo "  - 家宽IP策略路由已配置: ${HOME_IP}"
    fi
    local kernel_meta_pkg=""
    case "$(dpkg --print-architecture 2>/dev/null || true)" in
        amd64) kernel_meta_pkg="amd64" ;;
        arm64) kernel_meta_pkg="arm64" ;;
    esac
    if [[ -n "${kernel_meta_pkg}" ]]; then
        echo "  - 内核冻结建议: apt-mark hold linux-image-${kernel_meta_pkg} linux-headers-${kernel_meta_pkg}"
    fi
    echo ""
    echo -e "${GREEN}✓ 服务状态:${NC}"
    systemctl status awg-landing.service --no-pager | head -3
    systemctl status ss-main.service --no-pager | head -3
    systemctl status ss-backup.service --no-pager | head -3
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    cat > "${CONFIG_DIR}/client-config.txt" <<EOF
主轨配置:
服务器: ${TRANSIT_IP}
端口: ${TRANSIT_AWG_LISTEN_PORT}
密码: ${SS_PASSWORD}
加密: 2022-blake3-aes-256-gcm

备轨配置:
服务器: ${TRANSIT_IP}
端口: ${TRANSIT_SS_LISTEN_PORT}
密码: ${SS_PASSWORD}
加密: 2022-blake3-aes-256-gcm
EOF
    
    # v5.3: 生成中转机配置文件
    cat > "${CONFIG_DIR}/transit-peer-config.txt" <<EOF
# 中转机端口转发配置（请在中转机执行）

落地机公网 IP: ${public_ip}
中转 AWG 监听端口: ${TRANSIT_AWG_LISTEN_PORT}
落地 AWG 目标端口: ${AWG_PORT}
中转 SS 监听端口: ${TRANSIT_SS_LISTEN_PORT}
落地 SS 目标端口: ${SS_BACKUP_PORT}

命令示例:
ghost-transit-ctl add-landing "${public_ip}" "${landing_label}" --awg-listen ${TRANSIT_AWG_LISTEN_PORT} --awg-target ${AWG_PORT} --ss-listen ${TRANSIT_SS_LISTEN_PORT} --ss-target ${SS_BACKUP_PORT}
ghost-transit-ctl reload-rules
EOF
    
    info "配置已保存到: ${CONFIG_DIR}/client-config.txt"
    info "中转机配置已保存到: ${CONFIG_DIR}/transit-peer-config.txt"
    
    # v6.16 新增：创建快捷命令方便用户重新查看配置
cat > /usr/local/bin/show-clash-config <<'EOF'
#!/usr/bin/env bash
exec cat /etc/landing-ghost/clash-meta-config.yaml
EOF
    chmod +x /usr/local/bin/show-clash-config
    success "已创建快捷命令: show-clash-config"

cat > /usr/local/bin/show-ghost-nodes <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'
if [[ "${1:-}" == "--advanced" ]]; then
    echo "高级/调试入口（确认用途后再复制，避免把 Profile 当 Provider）："
    echo
    echo -e "${BLUE}Base64 一键导入 Mihomo Profile（备用）：${NC}"
    echo "cat /etc/landing-ghost/clash-meta-import-block.txt"
    echo
    echo -e "${BLUE}直接导入 Clash Meta / Mihomo 的完整双轨配置：${NC}"
    echo "cat /etc/landing-ghost/clash-meta-config.yaml"
    echo
    echo -e "${BLUE}Sub-Store 自洽 Provider（含 hidden AWG-Tunnel）：${NC}"
    echo "cat /etc/landing-ghost/substore-awg-for-mihomo.yaml"
    echo
    echo -e "${BLUE}Sub-Store Provider 推荐入口（仅主轨/备轨，配合静态 AWG 基础配置）：${NC}"
    echo "cat /etc/landing-ghost/substore-provider-only.yaml"
    echo
    echo -e "${BLUE}完整 Mihomo Profile（不要当节点 Provider）：${NC}"
    echo "cat /etc/landing-ghost/substore-mihomo-full.yaml"
    echo
    echo -e "${BLUE}静态 AWG JS 常量：${NC}"
    echo "cat /etc/landing-ghost/ghost-static-proxies.js"
    echo
    echo "如节点列表出现 AWG-Tunnel，请升级 Sub-Store/ClashMeta，或设置 exclude-filter: AWG-Tunnel。"
    exit 0
fi

echo "常用入口："
echo
echo -e "${RED}Mihomo 直导：Base64 一键导入完整 Clash Meta / Mihomo 配置：${NC}"
echo "cat /etc/landing-ghost/clash-meta-subscription.txt"
echo
echo -e "${BLUE}Sub-Store Provider 推荐入口（只含主轨/备轨，配合静态 AWG 基础配置）：${NC}"
echo "cat /etc/landing-ghost/substore-provider-only.yaml"
echo
echo -e "${BLUE}Sub-Store / ClashMeta 导入指南：${NC}"
echo "cat /etc/landing-ghost/substore-import-guide.txt"
echo
echo -e "${YELLOW}高级/调试入口默认隐藏，需要时运行：${NC}"
echo "show-ghost-nodes --advanced"
echo
EOF
    chmod +x /usr/local/bin/show-ghost-nodes
    success "已创建快捷命令: show-ghost-nodes"
    
    echo ""
    echo "推荐导入方式（复制执行即可从头到尾显示）："
    echo ""
    echo -e "${RED}Mihomo 直导：Base64 一键导入完整 Clash Meta / Mihomo 配置：${NC}"
    echo "cat ${CONFIG_DIR}/clash-meta-subscription.txt"
    echo ""
    echo -e "${BLUE}Sub-Store Provider 推荐入口（只含主轨/备轨，配合静态 AWG 基础配置）：${NC}"
    echo "cat ${CONFIG_DIR}/substore-provider-only.yaml"
    echo ""
    echo -e "${BLUE}Sub-Store / ClashMeta 导入指南：${NC}"
    echo "cat ${CONFIG_DIR}/substore-import-guide.txt"
    echo ""
    echo -e "${YELLOW}高级/调试入口默认隐藏，需要时运行：${NC}"
    echo "show-ghost-nodes --advanced"
    echo ""
    echo -e "${RED}⚠️  安全提示：${NC}"
    echo "  - 配置包含敏感信息（密钥、密码），请勿分享给他人"
    echo "  - 混淆参数为静态配置，重装前不会改变（无需重新复制配置）"
    echo "  - Mihomo 直导优先复制 ${CONFIG_DIR}/clash-meta-subscription.txt 的 Base64 内容"
    echo "  - Sub-Store 节点 Provider 推荐 ${CONFIG_DIR}/substore-provider-only.yaml，并按 ${CONFIG_DIR}/substore-import-guide.txt 静态注入 AWG-Tunnel"
    echo "  - ${CONFIG_DIR}/substore-mihomo-full.yaml 是完整 Profile，不要当节点 Provider"
    echo "  - 自洽 Provider/完整 Profile/静态 AWG 入口请用 show-ghost-nodes --advanced 查看"
    echo "  - 如节点列表出现 AWG-Tunnel，请升级 Sub-Store/ClashMeta，或设置 exclude-filter: AWG-Tunnel"
    echo "  - 安装后验证: curl -fsSL https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/verify_installation.sh | bash -s landing"
    echo ""
    
    # v6.28: 中转机使用每落地机独立 listen_port
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}${BOLD}📋 中转机配置指引${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}请在中转机上执行这一条命令：${NC}"
    echo ""
    echo "ghost-transit-ctl add-landing \"${public_ip}\" \"${landing_label}\" --awg-listen ${TRANSIT_AWG_LISTEN_PORT} --awg-target ${AWG_PORT} --ss-listen ${TRANSIT_SS_LISTEN_PORT} --ss-target ${SS_BACKUP_PORT}"
    echo "ghost-transit-ctl reload-rules"
    echo ""
    echo "如果中转机提示端口或 IP 冲突："
    echo "  - AWG 监听冲突：回到本脚本菜单选择“修正中转端口”，修改中转 AWG 监听端口"
    echo "  - SS 监听冲突：回到本脚本菜单选择“修正中转端口”，修改中转 SS 监听端口"
    echo "  - 落地机 IP 已存在：不要重复添加；先在中转机运行 ghost-transit-ctl status 确认当前映射"
    echo ""
}

# ==========================================
# 主流程
# ==========================================

main() {
    trap restore_stopped_services_on_failure EXIT
    [[ -t 1 ]] && clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  落地机安装脚本 v${VERSION}${NC}"
    echo -e "${CYAN}  架构: AmneziaWG → SS-2022 (高性能双轨)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    check_root
    check_os

    if [[ "${1:-}" == "--regenerate-nodes" ]]; then
        regenerate_nodes_only
    fi

    if [[ "${AUTO_INSTALL:-0}" != "1" && $# -eq 0 && -t 0 ]] && landing_installed; then
        show_landing_menu
        confirm_overwrite_nodes
    fi

    check_1panel_conflict
    install_dependencies
    
    ask_transit_info
    validate_auto_install_inputs
    stop_own_services_for_reinstall
    configure_ports
    generate_obfuscation_params
    
    echo ""
    lockdown_dns_ipv6
    install_amneziawg
    install_shadowsocks
    configure_amneziawg
    configure_shadowsocks
    setup_firewall
    setup_systemd
    generate_clash_meta_yaml
    optimize_system
    print_client_config
}

main "$@"
