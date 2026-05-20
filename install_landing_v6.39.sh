#!/usr/bin/env bash
set -euo pipefail

# install_landing_v6.39.sh — 落地机安装脚本
# 版本: v6.39 (2026-05-20)
# v6.39 - 修复 AWG 混淆导入字段、健康检查防抖、卸载端口清理和启动前防火墙顺序。
# 完整历史记录请查看 zhubi.md 或 Git 提交历史。

# ==========================================
# 全局变量
# ==========================================
VERSION="6.39"
AWG_BACKEND=""  # 记录 AWG 后端类型：kernel/go/none
RED='\033[0;31m'
GREEN='\033[0;32m'
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
    systemctl stop awg-landing ss-main ss-backup landing-health-check 2>/dev/null || true
    systemctl disable awg-landing ss-main ss-backup landing-health-check 2>/dev/null || true
    
    # 删除 systemd 服务文件
    rm -f /etc/systemd/system/awg-landing.service
    rm -f /etc/systemd/system/ss-main.service
    rm -f /etc/systemd/system/ss-backup.service
    rm -f /etc/systemd/system/landing-health-check.service
    rm -f /usr/local/bin/landing-health-check.sh
    rm -f /usr/local/bin/awg-landing-monitor.sh
    systemctl daemon-reload
    echo -e "${GREEN}服务已停止并禁用${NC}"
    
    if [[ "${choice}" == "1" ]]; then
        # 完全卸载
        chattr -i /etc/resolv.conf 2>/dev/null || true
        
        # 兼容清理旧版残留链，不破坏 1Panel/Docker
        for chain in $(iptables -L -n | grep "^Chain PORTSCAN_" | awk '{print $2}'); do
            local port=${chain#PORTSCAN_}
            iptables -D INPUT -p tcp --dport ${port} -j ${chain} 2>/dev/null || true
            iptables -F ${chain} 2>/dev/null || true
            iptables -X ${chain} 2>/dev/null || true
        done
        
        echo -e "${YELLOW}正在精准删除防火墙规则...${NC}"
        
        # 删除基础规则
        while iptables -D INPUT -i lo -j ACCEPT 2>/dev/null; do :; done
        while iptables -D INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null; do :; done
        while iptables -D INPUT -i docker0 -j ACCEPT 2>/dev/null; do :; done
        while iptables -D INPUT -i br-+ -j ACCEPT 2>/dev/null; do :; done
        while iptables -D INPUT -i awg0 -j ACCEPT 2>/dev/null; do :; done
        
        # 删除 SSH 保护规则
        while iptables -D INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null; do :; done
        while iptables -D INPUT -p tcp --dport 65022 -j ACCEPT 2>/dev/null; do :; done
        
        # 删除中转机相关规则（按 metadata 里的真实端口清理）
        local ports_json=""
        if command -v jq >/dev/null 2>&1 && [[ -f "${CONFIG_DIR}/metadata.json" ]]; then
            ports_json=$(jq -r '[.awg_port, .ss_backup_port, .transit_awg_listen_port, .transit_ss_listen_port] | map(select(.!=null)) | unique[]' "${CONFIG_DIR}/metadata.json" 2>/dev/null || true)
        fi
        [[ -n "${ports_json}" ]] || ports_json="51820 8389"
        for port in ${ports_json}; do
            for proto in tcp udp; do
                while true; do
                    local line_num
                    line_num=$(iptables -L INPUT -n --line-numbers 2>/dev/null | grep "${proto} dpt:${port}" | tail -1 | awk '{print $1}')
                    [[ -z "${line_num}" ]] && break
                    iptables -D INPUT "${line_num}" 2>/dev/null || break
                done
            done
        done
        
        # 删除 ICMP 规则
        while true; do
            local line_num=$(iptables -L INPUT -n --line-numbers | grep "icmptype 8" | tail -1 | awk '{print $1}')
            [[ -z "${line_num}" ]] && break
            iptables -D INPUT "${line_num}" 2>/dev/null || break
        done
        
        # 删除 DNS 劫持规则
        iptables -t nat -D OUTPUT -p udp --dport 53 -j DNAT --to-destination 1.1.1.1:53 2>/dev/null || true
        iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNAT --to-destination 1.1.1.1:53 2>/dev/null || true
        
        # 恢复默认策略（不执行 iptables -F，保留 1Panel/Docker 规则）
        iptables -P INPUT ACCEPT
        ip6tables -P INPUT ACCEPT 2>/dev/null || true
        ip6tables -P FORWARD ACCEPT 2>/dev/null || true
        ip6tables -P OUTPUT ACCEPT 2>/dev/null || true
        
        netfilter-persistent save 2>/dev/null || true
        echo -e "${GREEN}防火墙规则已精准删除（保留 1Panel/Docker 规则）${NC}"
        
        # 清理策略路由
        ip rule del table 100 2>/dev/null || true
        ip route flush table 100 2>/dev/null || true
        sed -i '/100 home_ip/d' /etc/iproute2/rt_tables 2>/dev/null || true
        rm -f /etc/network/if-up.d/home-ip-routing
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
        systemctl stop ghost-awg-dkms-check.service cleanup-awg-swap.timer 2>/dev/null || true
        systemctl disable ghost-awg-dkms-check.service cleanup-awg-swap.timer 2>/dev/null || true
        rm -f /etc/systemd/system/ghost-awg-dkms-check.service
        rm -f /etc/systemd/system/cleanup-awg-swap.service
        rm -f /etc/systemd/system/cleanup-awg-swap.timer
        rm -f /etc/kernel/postinst.d/amneziawg-dkms
        systemctl daemon-reload 2>/dev/null || true
        echo -e "${GREEN}AmneziaWG DKMS 残留已清理${NC}"
        
        rm -rf "${CONFIG_DIR}"
        echo -e "${GREEN}配置文件已删除${NC}"
        
        rm -f /etc/sysctl.d/99-landing-ghost.conf
        rm -f /etc/sysctl.d/99-landing-ghost-prelim.conf
        rm -f /usr/local/bin/show-clash-config
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

check_os() {
    if [[ ! -f /etc/debian_version ]]; then
        die "仅支持 Debian 12 系统"
    fi
    
    local version
    version=$(cat /etc/debian_version | cut -d. -f1)
    if [[ "${version}" != "12" ]]; then
        warn "检测到 Debian ${version},推荐使用 Debian 12"
        read -p "是否继续? (y/N): " confirm
        [[ "${confirm}" != "y" ]] && exit 0
    fi
}

check_1panel_conflict() {
    local conflicts=()
    
    for port in 80 443 8888; do
        if port_in_use tcp "${port}"; then
            local process
            process=$(ss -H -tlnp "sport = :${port}" 2>/dev/null | grep -oP 'users:\(\("\K[^"]+' | head -1 || true)
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

configure_ports() {
    info "配置端口..."
    
    # v6.14: 支持非交互模式
    if [[ "${AUTO_INSTALL:-0}" == "1" ]]; then
        local missing_vars=()
        [[ -z "${TRANSIT_IP:-}" ]] && missing_vars+=("TRANSIT_IP")
        [[ -z "${TRANSIT_AWG_LISTEN_PORT:-}" ]] && missing_vars+=("TRANSIT_AWG_LISTEN_PORT")
        [[ -z "${TRANSIT_SS_LISTEN_PORT:-}" ]] && missing_vars+=("TRANSIT_SS_LISTEN_PORT")
        if [[ ${#missing_vars[@]} -gt 0 ]]; then
            die "AUTO_INSTALL=1 时必须设置以下环境变量: ${missing_vars[*]}"
        fi
        SS_BACKUP_PORT=${SS_BACKUP_PORT:-8389}
        AWG_PORT=${AWG_PORT:-51820}
        validate_port "${AWG_PORT}" || die "AWG_PORT 无效"
        validate_port "${SS_BACKUP_PORT}" || die "SS_BACKUP_PORT 无效"
        validate_port "${TRANSIT_AWG_LISTEN_PORT}" || die "TRANSIT_AWG_LISTEN_PORT 无效"
        validate_port "${TRANSIT_SS_LISTEN_PORT}" || die "TRANSIT_SS_LISTEN_PORT 无效"
        if port_in_use udp "${AWG_PORT}"; then
            die "AWG UDP 端口 ${AWG_PORT} 已被占用，请更换 AWG_PORT"
        fi
        if port_in_use tcp "${SS_BACKUP_PORT}"; then
            die "SS TCP 端口 ${SS_BACKUP_PORT} 已被占用，请更换 SS_BACKUP_PORT"
        fi
        info "非交互模式: 使用默认备轨端口 ${SS_BACKUP_PORT}"
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
    while port_in_use tcp "${SS_BACKUP_PORT}"; do
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
    
    TRANSIT_AWG_LISTEN_PORT=${TRANSIT_AWG_LISTEN_PORT:-$AWG_PORT}
    TRANSIT_SS_LISTEN_PORT=${TRANSIT_SS_LISTEN_PORT:-$SS_BACKUP_PORT}

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
    
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$')
    local home_interface=""
    
    for iface in ${interfaces}; do
        local ip_addr=$(ip -4 addr show "${iface}" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        
        if [[ -n "${ip_addr}" ]]; then
            # 检测私有IP段（家宽IP）
            if [[ "${ip_addr}" =~ ^10\. ]] || [[ "${ip_addr}" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "${ip_addr}" =~ ^192\.168\. ]] || [[ "${ip_addr}" =~ ^100\.(6[4-9]|7[0-9]|8[0-9]|9[0-9]|10[0-9]|11[0-9]|12[0-7])\. ]]; then
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
    
    # 持久化配置（写入启动脚本）
    cat > /etc/network/if-up.d/home-ip-routing <<EOF
#!/bin/bash
# 家宽IP策略路由持久化脚本
LOG_FILE="/var/log/landing-ghost.log"

log() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') [ROUTE] \$*" >> "\${LOG_FILE}"
}

if [[ "\$IFACE" == "${home_iface}" ]]; then
    if ip rule add from ${home_ip} table 100 priority 100 2>/dev/null; then
        log "策略路由规则已添加: from ${home_ip} table 100"
    fi
    
    if ip route add default via ${gateway} dev ${home_iface} table 100 2>/dev/null; then
        log "策略路由表已配置: default via ${gateway} dev ${home_iface}"
    fi
    
    # 验证策略路由是否生效
    if ! ip rule show | grep -q "from ${home_ip} lookup 100"; then
        log "✗ 策略路由规则验证失败"
    fi
    
    if ! ip route show table 100 | grep -q "default via ${gateway}"; then
        log "✗ 策略路由表验证失败"
    fi
    
    log "策略路由持久化完成: ${home_ip} -> ${home_iface} -> ${gateway}"
fi
EOF
    chmod +x /etc/network/if-up.d/home-ip-routing
    
    return 0
}

# ==========================================
# 用户输入
# ==========================================
ask_transit_info() {
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
        read -p "中转机公网 IP: " TRANSIT_IP
        if validate_ip "${TRANSIT_IP}"; then
            break
        else
            warn "IP 格式错误，请重新输入"
        fi
    done
    
    # 输入 AWG 端口
    while true; do
        read -p "AmneziaWG 端口 (默认 51820): " AWG_PORT
        AWG_PORT=${AWG_PORT:-51820}
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


# 【新增】密码复用机制
generate_password() {
    local password_file="${CONFIG_DIR}/.ss_password"
    
    # [P0-2] 优先使用环境变量传入的密码（支持多落地机统一密码）
    if [[ -n "${SS_PASSWORD:-}" ]]; then
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
        info "复用已有密码（幂等性保护）"
        log "INFO" "从 ${password_file} 读取已有密码"
        return 0
    fi
    
    # 生成新密码
    if command -v openssl &>/dev/null; then
        SS_PASSWORD=$(openssl rand -base64 32 | tr -d '\n\r')
    else
        SS_PASSWORD=$(head -c 32 /dev/urandom | base64 | tr -d '\n\r')
    fi
    
    if [[ ${#SS_PASSWORD} -lt 16 ]]; then
        die "密码生成失败"
    fi
    
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
        curl wget git build-essential jq \
        iptables iptables-persistent \
        openssl netcat-openbsd iputils-tracepath || die "依赖安装失败（3次尝试）"

    if [[ ! -s /usr/local/bin/install_amneziawg_dkms.sh ]] \
        || { [[ -f /usr/local/bin/install_amneziawg_dkms.sh ]] \
            && ! grep -q "VERSION=\"${VERSION}\"" /usr/local/bin/install_amneziawg_dkms.sh 2>/dev/null; }; then
        if curl -fsSL --connect-timeout 10 --retry 3 \
            "https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/install_amneziawg_dkms.sh" \
            -o /usr/local/bin/install_amneziawg_dkms.sh 2>/dev/null; then
            chmod +x /usr/local/bin/install_amneziawg_dkms.sh
            cp /usr/local/bin/install_amneziawg_dkms.sh /root/install_amneziawg_dkms.sh 2>/dev/null || true
        else
            warn "DKMS 脚本下载失败，将继续使用本地脚本或 amneziawg-go 回退"
        fi
    fi
    
    success "依赖安装完成"
}

# ==========================================
# DNS 和 IPv6 预防性锁定
# ==========================================

lockdown_dns_ipv6() {
    progress 3 11 "禁用 IPv6（防泄漏）"
    
    # 禁用 IPv6（sysctl层）
    cat > /etc/sysctl.d/99-landing-ghost-prelim.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    
    sysctl -p /etc/sysctl.d/99-landing-ghost-prelim.conf &>/dev/null
    log "INFO" "IPv6 已禁用（sysctl层）"
    
    # 验证 IPv6 是否真正禁用（v4.9 修复：使用排除法，更精准）
    local ipv6_global_count=$(ip -6 addr show 2>/dev/null | grep "inet6" | grep -v "::1/128" | grep -v "fe80:" | wc -l)
    local ipv6_link_count=$(ip -6 addr show 2>/dev/null | grep "inet6 fe80:" | wc -l)
    
    if [[ ${ipv6_global_count} -gt 0 ]]; then
        warn "检测到全局 IPv6 地址，可能存在泄漏风险"
        log "WARN" "IPv6 泄漏风险：$(ip -6 addr show 2>/dev/null | grep 'inet6' | grep -v '::1/128' | grep -v 'fe80:')"
    elif [[ ${ipv6_link_count} -gt 0 ]]; then
        info "检测到链路本地 IPv6 地址（fe80::），这是正常的，不会泄漏"
        log "INFO" "IPv6 链路本地地址存在（正常）"
    else
        success "IPv6 已完全禁用（验证通过）"
        log "INFO" "IPv6 禁用验证通过"
    fi
    
    # 强制阻断 IPv6 出站流量（ip6tables层）
    if command -v ip6tables &>/dev/null; then
        ip6tables -P INPUT DROP 2>/dev/null || true
        ip6tables -P FORWARD DROP 2>/dev/null || true
        ip6tables -P OUTPUT DROP 2>/dev/null || true
        # 允许本地回环
        ip6tables -A INPUT -i lo -j ACCEPT 2>/dev/null || true
        ip6tables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true
        
        # 保存规则
        if command -v netfilter-persistent &>/dev/null; then
            netfilter-persistent save &>/dev/null || true
        fi
        success "IPv6 出站流量已彻底阻断（ip6tables层）"
        log "INFO" "ip6tables DROP 策略已应用"
    else
        warn "ip6tables 未安装，跳过防火墙层 IPv6 阻断"
    fi
    
    if [[ "${LOCK_DNS:-0}" == "1" ]]; then
        if systemctl is-active --quiet systemd-resolved; then
            info "检测到 systemd-resolved 运行，停止并禁用..."
            systemctl stop systemd-resolved
            systemctl disable systemd-resolved
            rm -f /etc/resolv.conf
            log "INFO" "systemd-resolved 已停止"
        fi

        info "LOCK_DNS=1，锁定 DNS 配置..."
        chattr -i /etc/resolv.conf 2>/dev/null || true
        cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
        if chattr +i /etc/resolv.conf 2>/dev/null; then
            success "DNS 配置已锁定（resolv.conf层）"
            log "INFO" "DNS 已锁定为 Cloudflare"
        else
            warn "无法锁定 resolv.conf，DNS 可能被系统覆盖"
            log "WARN" "chattr +i 失败，DNS 锁定不完整"
        fi
    else
        info "DNS 锁定默认关闭；如确需锁定，运行前设置 LOCK_DNS=1"
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
            "${script_dir}/install_amneziawg_dkms.sh" \
            "${script_dir}/install_amneziawg_dkms_v${VERSION}.sh" \
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
            "https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/install_amneziawg_dkms.sh" \
            -o "${script}"; then
            warn "DKMS 脚本下载失败，将尝试 amneziawg-go 用户态后端"
            return 1
        fi
    fi

    chmod +x "${script}" 2>/dev/null || true
    
    info "调用独立 DKMS 脚本安装 AmneziaWG 内核模块: ${script}"
    if ! "${script}"; then
        warn "独立 DKMS 脚本执行失败"
        return 1
    fi
    
    modprobe amneziawg 2>/dev/null
}

# 用户态回退方案（amneziawg-go）
install_amneziawg_go() {
    info "安装 AmneziaWG 用户态版本（amneziawg-go）"
    
    if command -v awg &>/dev/null && command -v amneziawg-go &>/dev/null; then
        info "AmneziaWG 工具和用户态后端已安装"
        return 0
    fi

    if ! command -v go &>/dev/null; then
        info "golang-go 未安装，按需安装（用于 amneziawg-go 用户态回退）"
        retry_command 3 5 env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq golang-go || die "golang-go 安装失败"
    fi
    retry_command 3 5 env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq pkg-config libmnl-dev || die "amneziawg-tools 编译依赖安装失败"
    
    local tmp_dir
    tmp_dir=$(mktemp -d) || die "创建临时目录失败"
    cd "${tmp_dir}" || die "进入临时目录失败"
    
    # 克隆并安装 awg/awg-quick 工具，最多重试3次
    local clone_success=0
    for attempt in 1 2 3; do
        rm -rf amneziawg-tools
        info "克隆 amneziawg-tools（尝试 $attempt/3）..."
        if git clone --depth 1 --config http.lowSpeedLimit=1000 --config http.lowSpeedTime=60 \
            https://github.com/amnezia-vpn/amneziawg-tools.git &>/dev/null; then
            clone_success=1
            break
        fi
        [ $attempt -lt 3 ] && sleep 2
    done
    [ $clone_success -eq 0 ] && die "克隆 amneziawg-tools 失败（3次尝试）"
    
    cd amneziawg-tools/src || die "进入源码目录失败"
    
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
    [ $build_success -eq 0 ] && die "编译 AmneziaWG 失败（3次尝试）"
    
    make install &>/dev/null || die "安装 AmneziaWG 失败"

    cd "${tmp_dir}" || die "进入临时目录失败"
    clone_success=0
    for attempt in 1 2 3; do
        rm -rf amneziawg-go
        info "克隆 amneziawg-go（尝试 $attempt/3）..."
        if git clone --depth 1 --config http.lowSpeedLimit=1000 --config http.lowSpeedTime=60 \
            https://github.com/amnezia-vpn/amneziawg-go.git &>/dev/null; then
            clone_success=1
            break
        fi
        [ $attempt -lt 3 ] && sleep 2
    done
    [ $clone_success -eq 0 ] && die "克隆 amneziawg-go 失败（3次尝试）"

    cd amneziawg-go || die "进入 amneziawg-go 源码目录失败"
    make &>/dev/null || die "编译 amneziawg-go 失败"
    make install &>/dev/null || die "安装 amneziawg-go 失败"
    
    cd /
    rm -rf "${tmp_dir}"
    
    success "AmneziaWG 用户态工具和后端安装完成"
    return 0
}

# 统一 AWG 运行时安装入口（自动降级）
install_awg_runtime() {
    # 优先尝试 DKMS 内核模块
    if modprobe amneziawg 2>/dev/null; then
        if ! command -v awg >/dev/null 2>&1 || ! command -v awg-quick >/dev/null 2>&1; then
            warn "检测到 AmneziaWG 内核模块，但缺少 awg/awg-quick，调用 DKMS 脚本补装工具"
            if ! install_amneziawg_dkms_standalone; then
                install_amneziawg_go || die "补装 awg/awg-quick 失败"
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
    if install_amneziawg_go; then
        AWG_BACKEND="go"
        success "使用 amneziawg-go 用户态版本（支持混淆）"
        return 0
    fi
    
    die "DKMS 和 amneziawg-go 均失败，拒绝回退到无混淆的标准 WireGuard"
}

detect_tunnel_mtu() {
    local pmtu old_mtu="${OPTIMAL_MTU}"
    if ! command -v tracepath >/dev/null 2>&1; then
        return 0
    fi

    pmtu=$(tracepath -n 10.8.0.1 2>/dev/null | awk '/pmtu/ {print $2}' | tail -1 || true)
    if [[ -n "${pmtu}" && "${pmtu}" =~ ^[0-9]+$ && ${pmtu} -gt 1200 ]]; then
        OPTIMAL_MTU=$((pmtu - 80))
        (( OPTIMAL_MTU < 1200 )) && OPTIMAL_MTU=1200
        (( OPTIMAL_MTU > 1500 )) && OPTIMAL_MTU=1360
        info "隧道内 PMTU: ${pmtu}，AWG MTU: ${OPTIMAL_MTU}"
        if [[ "${OPTIMAL_MTU}" != "${old_mtu}" && -f "${CONFIG_DIR}/awg0.conf" ]]; then
            sed -i "s/^MTU = .*/MTU = ${OPTIMAL_MTU}/" "${CONFIG_DIR}/awg0.conf"
            systemctl restart awg-landing.service || die "应用隧道 MTU 后重启 AWG 失败"
        fi
    else
        warn "MTU 探测失败（tracepath 可能被防火墙阻断），使用默认值 ${OPTIMAL_MTU}"
        log "WARN" "MTU 探测失败，使用默认值 ${OPTIMAL_MTU}"
    fi
}

install_shadowsocks() {
    progress 5 11 "安装 Shadowsocks-2022 (sing-box)"
    
    if command -v sing-box &>/dev/null; then
        info "sing-box 已安装,跳过"
        return 0
    fi
    
    # 修复：官方脚本可能超时，改用GitHub Release直接下载
    local ARCH=$(uname -m)
    local SINGBOX_VERSION="${SINGBOX_VERSION:-1.11.0}"
    local DOWNLOAD_URL=""
    
    case "${ARCH}" in
        x86_64)
            DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-amd64.tar.gz"
            ;;
        aarch64|arm64)
            DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-arm64.tar.gz"
            ;;
        *)
            die "不支持的架构: ${ARCH}"
            ;;
    esac
    
    info "下载 sing-box ${SINGBOX_VERSION} (${ARCH})..."
    cd /tmp
    curl -fsSL --connect-timeout 10 --retry 3 "${DOWNLOAD_URL}" -o sing-box.tar.gz || die "下载 sing-box 失败"
    tar -xzf sing-box.tar.gz || die "解压 sing-box 失败"
    
    local EXTRACT_DIR=$(tar -tzf sing-box.tar.gz | head -1 | cut -f1 -d"/")
    cp "${EXTRACT_DIR}/sing-box" /usr/local/bin/ || die "安装 sing-box 失败"
    chmod +x /usr/local/bin/sing-box
    
    rm -rf sing-box.tar.gz "${EXTRACT_DIR}"
    
    success "Shadowsocks-2022 安装完成"
}



# ==========================================
# 配置
# ==========================================

# v6.16 新增：独立的混淆参数生成函数（在main()开始时调用，避免竞态条件）
rand_u32() {
    local n
    while true; do
        n=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
        if [[ "${n}" =~ ^[0-9]+$ && "${n}" -gt 0 ]]; then
            echo "${n}"
            return 0
        fi
    done
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
        if ! [[ "${H1}" =~ ^[0-9]+$ && "${H2}" =~ ^[0-9]+$ && "${H3}" =~ ^[0-9]+$ && "${H4}" =~ ^[0-9]+$ ]]; then
            warn "检测到旧版十六进制 H1-H4 参数，已改为 Mihomo/AWG 更兼容的十进制 uint32"
            H1=$(rand_u32)
            H2=$(rand_u32)
            H3=$(rand_u32)
            H4=$(rand_u32)
            write_obfuscation_params "${params_file}"
        fi
        info "复用已有混淆参数（幂等性保护）"
    else
        JC=$((RANDOM % 128))
        JMIN=$((50 + RANDOM % 50))
        JMAX=$((JMIN + 50 + RANDOM % 50))
        S1=$((RANDOM % 256))
        S2=$((RANDOM % 256))
        H1=$(rand_u32)
        H2=$(rand_u32)
        H3=$(rand_u32)
        H4=$(rand_u32)
        
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
        setup_home_ip_routing "${home_iface}" "${HOME_IP}"
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
    
    log "INFO" "生成 Shadowsocks 主轨配置"
    # v6.0: 主轨也需要绑定家宽网卡（修复家宽IP侧漏）
    if [[ -n "${home_iface}" ]]; then
        info "主轨将绑定家宽IP网卡: ${home_iface}"
        log "INFO" "ss-main 绑定网卡 ${home_iface}"
        cat > "${CONFIG_DIR}/ss-main.json" <<EOF
{
  "log": {
    "level": "warn",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "shadowsocks",
      "tag": "ss-main",
      "listen": "10.8.0.1",
      "listen_port": ${SS_MAIN_PORT},
      "method": "2022-blake3-aes-256-gcm",
      "password": "${SS_PASSWORD}",
      "multiplex": {
        "enabled": true,
        "padding": true
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct",
      "bind_interface": "${home_iface}"
    }
  ]
}
EOF
    else
        cat > "${CONFIG_DIR}/ss-main.json" <<EOF
{
  "log": {
    "level": "warn",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "shadowsocks",
      "tag": "ss-main",
      "listen": "10.8.0.1",
      "listen_port": ${SS_MAIN_PORT},
      "method": "2022-blake3-aes-256-gcm",
      "password": "${SS_PASSWORD}",
      "multiplex": {
        "enabled": true,
        "padding": true
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
    fi
    
    log "INFO" "生成 Shadowsocks 备轨配置"
    if [[ -n "${home_iface}" ]]; then
        info "备轨将绑定家宽IP网卡: ${home_iface}"
        log "INFO" "ss-backup 绑定网卡 ${home_iface}"
        cat > "${CONFIG_DIR}/ss-backup.json" <<EOF
{
  "log": {
    "level": "warn",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "shadowsocks",
      "tag": "ss-backup",
      "listen": "0.0.0.0",
      "listen_port": ${SS_BACKUP_PORT},
      "method": "2022-blake3-aes-256-gcm",
      "password": "${SS_PASSWORD}",
      "multiplex": {
        "enabled": true,
        "padding": true
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct",
      "bind_interface": "${home_iface}"
    }
  ]
}
EOF
    else
        cat > "${CONFIG_DIR}/ss-backup.json" <<EOF
{
  "log": {
    "level": "warn",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "shadowsocks",
      "tag": "ss-backup",
      "listen": "0.0.0.0",
      "listen_port": ${SS_BACKUP_PORT},
      "method": "2022-blake3-aes-256-gcm",
      "password": "${SS_PASSWORD}",
      "multiplex": {
        "enabled": true,
        "padding": true
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
    fi
    
    success "Shadowsocks-2022 配置完成"
}


setup_systemd() {
    progress 9 11 "配置 systemd 服务"

    local awg_quick_bin
    awg_quick_bin="$(command -v awg-quick || true)"
    [[ -n "${awg_quick_bin}" ]] || die "未找到 awg-quick"
    local awg_env_line=""
    if [[ "${AWG_BACKEND}" == "go" ]]; then
        awg_env_line="Environment=WG_QUICK_USERSPACE_IMPLEMENTATION=amneziawg-go"
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

    cat > /etc/systemd/system/awg-landing.service <<EOF
[Unit]
Description=AmneziaWG Landing Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
${awg_env_line}
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
    logger -t landing-health "\$1" 2>/dev/null || true
}

AWG_FAIL_COUNT=0
SS_MAIN_FAIL_COUNT=0
SS_BACKUP_FAIL_COUNT=0
MAX_FAIL_COUNT=3

while true; do
    sleep \$((240 + RANDOM % 120))

    if ! ip addr show awg0 2>/dev/null | grep -q "10.8.0.1"; then
        AWG_FAIL_COUNT=\$((AWG_FAIL_COUNT + 1))
        log_health "AWG隧道异常 (失败计数: \${AWG_FAIL_COUNT}/\${MAX_FAIL_COUNT})"

        if [ "\${AWG_FAIL_COUNT}" -ge "\${MAX_FAIL_COUNT}" ]; then
            log_health "AWG连续失败\${MAX_FAIL_COUNT}次，执行重启"
            if ! lsmod | grep -q '^amneziawg'; then
                log_health "AWG内核模块缺失，尝试加载"
                modprobe amneziawg 2>/dev/null || log_health "modprobe amneziawg 失败"
            fi
            if systemctl restart awg-landing.service 2>/dev/null; then
                sleep 10
                if ip addr show awg0 2>/dev/null | grep -q "10.8.0.1"; then
                    log_health "AWG重启成功"
                    AWG_FAIL_COUNT=0
                else
                    log_health "AWG重启后仍异常，等待下次检查"
                fi
            else
                log_health "awg-landing重启失败"
            fi
        fi
    else
        AWG_FAIL_COUNT=0
    fi

    if command -v nc >/dev/null 2>&1; then
        if ! nc -zw3 10.8.0.1 ${SS_MAIN_PORT} >/dev/null 2>&1; then
            SS_MAIN_FAIL_COUNT=\$((SS_MAIN_FAIL_COUNT + 1))
            log_health "SS主轨端口异常 (失败计数: \${SS_MAIN_FAIL_COUNT}/\${MAX_FAIL_COUNT})"
            if [ "\${SS_MAIN_FAIL_COUNT}" -ge "\${MAX_FAIL_COUNT}" ]; then
                log_health "SS主轨连续失败\${MAX_FAIL_COUNT}次，执行重启"
                systemctl restart ss-main.service 2>/dev/null || log_health "ss-main重启失败"
                SS_MAIN_FAIL_COUNT=0
                sleep 5
            fi
        else
            SS_MAIN_FAIL_COUNT=0
        fi
    else
        log_health "nc命令不存在，跳过主轨端口检测"
    fi

    if command -v nc >/dev/null 2>&1; then
        if ! nc -zw3 127.0.0.1 ${SS_BACKUP_PORT} >/dev/null 2>&1; then
            SS_BACKUP_FAIL_COUNT=\$((SS_BACKUP_FAIL_COUNT + 1))
            log_health "SS备轨端口异常 (失败计数: \${SS_BACKUP_FAIL_COUNT}/\${MAX_FAIL_COUNT})"
            if [ "\${SS_BACKUP_FAIL_COUNT}" -ge "\${MAX_FAIL_COUNT}" ]; then
                log_health "SS备轨连续失败\${MAX_FAIL_COUNT}次，执行重启"
                systemctl restart ss-backup.service 2>/dev/null || log_health "ss-backup重启失败"
                SS_BACKUP_FAIL_COUNT=0
                sleep 5
            fi
        else
            SS_BACKUP_FAIL_COUNT=0
        fi
    else
        log_health "nc命令不存在，跳过备轨端口检测"
    fi
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

# DNS 配置（防泄漏）
dns:
  enable: true
  ipv6: false
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 1.1.1.1
    - 8.8.8.8
  fallback:
    - https://1.1.1.1/dns-query
    - https://8.8.8.8/dns-query

proxies:
  # 底层隧道：AmneziaWG（连接到中转机）
  - name: "AWG-Tunnel"
    type: wireguard
    server: ${TRANSIT_IP}
    port: ${TRANSIT_AWG_LISTEN_PORT}
    ip: 10.8.0.2  # 用户设备在AWG隧道内的虚拟IP（连接目标是中转机公网IP）
    private-key: ${AWG_CLIENT_PRIVATE}
    public-key: ${AWG_SERVER_PUBLIC}
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
    udp: true
    udp-over-tcp: false  # 禁用UDP over TCP，保持原生UDP性能

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
    
    # v6.28: 只生成 Base64 订阅信息；不再生成 clash:// 超长链接
    info "生成 Clash Meta 订阅信息..."
    
    # 生成Base64编码的订阅信息（用于剪贴板导入）
    # P1-1 修复：跨平台兼容性（macOS/BSD不支持-w参数）
    local base64_subscription
    base64_subscription=$(cat "${CONFIG_DIR}/clash-meta-config.yaml" | base64 | tr -d '\n')
    echo "${base64_subscription}" > "${CONFIG_DIR}/clash-meta-subscription.txt"

    success "Base64订阅信息已生成: ${CONFIG_DIR}/clash-meta-subscription.txt"
    
    # v6.27: 生成复制粘贴友好的导入块
    printf '%s\n' "${base64_subscription}" > "${CONFIG_DIR}/clash-meta-import-block.txt"
    success "复制粘贴导入块已生成: ${CONFIG_DIR}/clash-meta-import-block.txt"
}

setup_firewall() {
    progress 8 11 "配置防火墙"
    
    local ssh_port
    ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | grep -oE '[0-9]+$' | head -1 || true)
    ssh_port=${ssh_port:-22}
    
    iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || iptables -I INPUT -i lo -j ACCEPT
    iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    iptables -C INPUT -p tcp --dport ${ssh_port} -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport ${ssh_port} -j ACCEPT
    
    while iptables -D INPUT -s "${TRANSIT_IP}" -p udp --dport "${AWG_PORT}" -j ACCEPT 2>/dev/null; do :; done
    while iptables -D INPUT -s "${TRANSIT_IP}" -p icmp --icmp-type echo-request -j ACCEPT 2>/dev/null; do :; done
    while iptables -D INPUT -s "${TRANSIT_IP}" -p tcp --dport "${SS_BACKUP_PORT}" -j ACCEPT 2>/dev/null; do :; done
    while iptables -D INPUT -p udp --dport "${AWG_PORT}" -j DROP 2>/dev/null; do :; done
    while iptables -D INPUT -p tcp --dport "${SS_BACKUP_PORT}" -j DROP 2>/dev/null; do :; done

    iptables -A INPUT -s "${TRANSIT_IP}" -p udp --dport "${AWG_PORT}" -j ACCEPT
    iptables -A INPUT -s "${TRANSIT_IP}" -p icmp --icmp-type echo-request -j ACCEPT
    iptables -A INPUT -s "${TRANSIT_IP}" -p tcp --dport "${SS_BACKUP_PORT}" -j ACCEPT
    iptables -A INPUT -p udp --dport "${AWG_PORT}" -j DROP
    iptables -A INPUT -p tcp --dport "${SS_BACKUP_PORT}" -j DROP
    
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
    
    local public_ip
    public_ip=$(curl -fsS4 --max-time 5 https://ifconfig.me/ip || echo "<获取失败>")
    
    clear
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
    echo "  3. 建议使用 Clash Meta 配置自动切换"
    echo "  4. 本机 IP: ${public_ip}"
    echo ""
    echo -e "${YELLOW}🔧 中转机配置:${NC}"
    echo "  落地机公网 IP: ${public_ip}"
    echo "  中转 AWG 监听端口: ${TRANSIT_AWG_LISTEN_PORT} -> 落地 ${AWG_PORT}"
    echo "  中转 SS 监听端口: ${TRANSIT_SS_LISTEN_PORT} -> 落地 ${SS_BACKUP_PORT}"
    echo ""
    echo -e "${YELLOW}🔒 安全增强功能:${NC}"
    echo "  5. IPv6 已防泄漏（sysctl + ip6tables）"
    echo "  6. 密码已保存，重新运行脚本不会改变"
    if [[ "${LOCK_DNS:-0}" == "1" ]]; then
        echo "  7. DNS 已锁定（resolv.conf + chattr）"
    fi
    
    if [[ -n "${HOME_IP}" ]]; then
        echo "  12. 家宽IP策略路由已配置: ${HOME_IP}"
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
ghost-transit-ctl add-landing "${public_ip}" "落地机-$(date +%Y%m%d)" --awg-listen ${TRANSIT_AWG_LISTEN_PORT} --awg-target ${AWG_PORT} --ss-listen ${TRANSIT_SS_LISTEN_PORT} --ss-target ${SS_BACKUP_PORT}
ghost-transit-ctl reload-rules
EOF
    
    info "配置已保存到: ${CONFIG_DIR}/client-config.txt"
    info "中转机配置已保存到: ${CONFIG_DIR}/transit-peer-config.txt"
    
    # v6.16 新增：创建快捷命令方便用户重新查看配置
    cat > /usr/local/bin/show-clash-config <<'EOF'
#!/usr/bin/env bash
/bin/cat /etc/landing-ghost/clash-meta-config.yaml
EOF
    chmod +x /usr/local/bin/show-clash-config
    success "已创建快捷命令: show-clash-config"
    
    # v5.7: 优化终端 YAML 输出，增强可读性和多种获取方式
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  📱 Clash Meta 配置（请复制以下内容）${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}使用方法：${NC}"
    echo "  1. 复制下方完整的 YAML 配置"
    echo "  2. 打开 Clash Meta → 配置 → 新建配置"
    echo "  3. 选择「从剪贴板导入」"
    echo "  4. 粘贴配置并保存"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}↓↓↓↓ 请从此处开始复制 ↓↓↓↓${NC}"
    echo ""
    cat "${CONFIG_DIR}/clash-meta-config.yaml"
    echo ""
    echo -e "${RED}↑↑↑↑ 请复制到此处结束 ↑↑↑↑${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -e "${GREEN}💡 备用导入方式：Base64 字符串${NC}"
    echo ""
    echo -e "${CYAN}使用方法：${NC}"
    echo "  1. 复制下方完整 Base64 字符串"
    echo "  2. 打开 Clash Meta / Mihomo 客户端"
    echo "  3. 从剪贴板导入配置并启用"
    echo ""

    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}Base64订阅信息（可复制粘贴导入）${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${RED}↓↓↓↓ Base64 从此处开始复制 ↓↓↓↓${NC}"
    cat "${CONFIG_DIR}/clash-meta-import-block.txt"
    echo ""
    echo -e "${RED}↑↑↑↑ Base64 复制到此处结束 ↑↑↑↑${NC}"
    echo ""
    echo -e "${GREEN}💡 如终端显示不完整，请直接读取文件：${NC}"
    echo "cat ${CONFIG_DIR}/clash-meta-import-block.txt"
    echo ""
    echo -e "${RED}⚠️  安全提示：${NC}"
    echo "  - 配置包含敏感信息（密钥、密码），请勿分享给他人"
    echo "  - 混淆参数为静态配置，重装前不会改变（无需重新复制配置）"
    echo "  - 配置文件已保存到: ${CONFIG_DIR}/clash-meta-config.yaml"
    echo ""
    
    # v6.28: 中转机使用每落地机独立 listen_port
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}${BOLD}📋 中转机配置指引${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}请在中转机上执行这一条命令：${NC}"
    echo ""
    echo "ghost-transit-ctl add-landing \"${public_ip}\" \"落地机-$(hostname)\" --awg-listen ${TRANSIT_AWG_LISTEN_PORT} --awg-target ${AWG_PORT} --ss-listen ${TRANSIT_SS_LISTEN_PORT} --ss-target ${SS_BACKUP_PORT}"
    echo "ghost-transit-ctl reload-rules"
    echo ""
}

# ==========================================
# 主流程
# ==========================================

main() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  落地机安装脚本 v${VERSION}${NC}"
    echo -e "${CYAN}  架构: AmneziaWG → SS-2022 (高性能双轨)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    check_root
    check_os
    check_1panel_conflict
    install_dependencies
    generate_obfuscation_params
    
    ask_transit_info
    configure_ports
    
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
