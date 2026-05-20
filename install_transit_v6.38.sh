#!/usr/bin/env bash
set -euo pipefail

# install_transit_v6.38.sh — 中转机安装脚本
# 版本: v6.38 (2026-05-20)
# v6.38 - 同步稳定入口，保留 v6.37 中转健康检查和非交互安装修复。
# 完整历史记录请查看 zhubi.md 或 Git 提交历史。

# ==========================================
# 版本号
VERSION="6.38"
SCRIPT_NAME="install_transit_v${VERSION}.sh"
CONFIG_DIR="/etc/ghost-transit"
CONFIG_FILE="${CONFIG_DIR}/config.json"
LOG_FILE="/var/log/ghost-transit.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ==========================================
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
        warn "检测到 Debian ${version}，推荐使用 Debian 12"
    fi
}

# P1-2: 应用层代理检测（防止中转机误配代理导致流量泄漏）
check_no_proxy() {
    info "检查应用层代理配置..."
    
    # 检查环境变量
    if [[ -n "${http_proxy:-}" ]] || [[ -n "${https_proxy:-}" ]] || [[ -n "${HTTP_PROXY:-}" ]] || [[ -n "${HTTPS_PROXY:-}" ]]; then
        die "检测到应用层代理环境变量！中转机不应配置代理，请执行: unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY"
    fi
    
    # 检查常见代理配置文件
    if [[ -f /etc/environment ]] && grep -qiE '(http|https)_proxy' /etc/environment; then
        die "检测到 /etc/environment 中配置了代理，请删除后重试"
    fi
    
    success "应用层代理检查通过"
}

# v6.9 增强-1: 磁盘空间预检查
check_disk_space() {
    local required_mb=500
    local available_mb
    available_mb=$(df -m / | awk 'NR==2 {print $4}')
    
    if [[ ${available_mb} -lt ${required_mb} ]]; then
        die "磁盘空间不足！需要至少 ${required_mb}MB，当前可用 ${available_mb}MB"
    fi
    
    info "磁盘空间检查通过（可用: ${available_mb}MB）"
}

# v6.9 增强-3: 网络连通性检查
check_network() {
    info "检查网络连通性..."
    
    # 检查 DNS 解析
    if command -v getent >/dev/null 2>&1; then
        if ! getent ahosts ifconfig.me &>/dev/null && ! getent ahosts google.com &>/dev/null; then
            warn "DNS 解析失败，可能影响依赖包下载"
            return 1
        fi
    elif command -v host >/dev/null 2>&1; then
        if ! host -W 5 ifconfig.me &>/dev/null && ! host -W 5 google.com &>/dev/null; then
            warn "DNS 解析失败，可能影响依赖包下载"
            return 1
        fi
    else
        warn "缺少 getent/host，跳过 DNS 解析预检"
    fi
    
    success "网络连通性检查通过"
    return 0
}

# v6.12 新增: 依赖安装函数
install_dependencies() {
    progress 1 7 "安装依赖包"
    
    info "更新软件包列表..."
    if ! apt-get update -qq; then
        warn "apt-get update 失败，但继续尝试安装"
    fi
    
    local packages=(jq nftables netcat-openbsd)
    local missing_packages=()
    
    # 检查哪些包需要安装
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        success "所有依赖包已安装"
        return 0
    fi
    
    info "安装依赖包: ${missing_packages[*]}"
    if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing_packages[@]}" &>/dev/null; then
        success "依赖包安装完成"
    else
        die "依赖包安装失败，请检查网络连接和apt源配置"
    fi
}

check_kernel_version() {
    local kernel_version
    kernel_version=$(uname -r | cut -d. -f1-2)
    local major minor
    major=$(echo "${kernel_version}" | cut -d. -f1)
    minor=$(echo "${kernel_version}" | cut -d. -f2)
    
    if [[ ${major} -lt 4 ]] || [[ ${major} -eq 4 && ${minor} -lt 9 ]]; then
        warn "内核版本 ${kernel_version} 不支持 BBR（需要 4.9+）"
        return 1
    fi
    return 0
}

detect_ssh_port() {
    local port
    if command -v ss &>/dev/null; then
        port=$(ss -tlnp | grep sshd | awk '{print $4}' | grep -oE '[0-9]+$' | head -1 || true)
    fi
    if [[ -z "${port}" ]] && [[ -f /etc/ssh/sshd_config ]]; then
        port=$(grep -E '^Port ' /etc/ssh/sshd_config | awk '{print $2}' || true)
    fi
    echo "${port:-22}"
}

# v6.13 新增：备份文件清理函数（只保留最近3个备份）
cleanup_old_backups() {
    local file_pattern="$1"
    local keep_count=3
    
    # 查找所有备份文件，按时间戳排序，删除旧的
    ls -t ${file_pattern}.bak.* 2>/dev/null | tail -n +$((keep_count + 1)) | xargs -r rm -f
}

# ==========================================
# 初始化配置目录和配置文件
# ==========================================

init_config() {
    progress 1 6 "初始化配置目录"
    
    mkdir -p "${CONFIG_DIR}"
    chmod 700 "${CONFIG_DIR}"
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        warn "检测到已有配置文件，将备份"
        cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak.$(date +%s)"
        cleanup_old_backups "${CONFIG_FILE}"
    fi
    
    local ssh_port
    ssh_port=$(detect_ssh_port)
    
    cat > "${CONFIG_FILE}" <<EOF
{
  "version": "${VERSION}",
  "ssh_port": ${ssh_port},
  "landings": []
}
EOF
    
    chmod 600 "${CONFIG_FILE}"
    
    # v6.9 增强-2: 配置文件完整性检查
    if ! validate_config_file "${CONFIG_FILE}"; then
        die "配置文件生成失败，JSON 格式错误"
    fi
    
    success "配置文件已创建: ${CONFIG_FILE}"
}

# v6.9 增强-2: 配置文件完整性检查
validate_config_file() {
    local file="$1"
    
    if [[ ! -f "${file}" ]]; then
        error "配置文件不存在: ${file}"
        return 1
    fi
    
    if ! jq empty "${file}" 2>/dev/null; then
        error "配置文件 JSON 格式错误"
        return 1
    fi
    
    # 检查必需字段
    local required_fields=("version" "ssh_port" "landings")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".${field}" "${file}" &>/dev/null; then
            error "配置文件缺少必需字段: ${field}"
            return 1
        fi
    done
    
    return 0
}

add_landing() {
    local ip="$1"
    local name="$2"
    local ssh_port="${3:-22}"
    local awg_listen="${4:-51820}"
    local awg_target="${5:-51820}"
    local ss_listen="${6:-8389}"
    local ss_target="${7:-8389}"

    validate_ip "${ip}" || {
        error "落地机 IP 无效: ${ip}"
        return 1
    }
    validate_port "${ssh_port}" || { error "SSH 端口无效: ${ssh_port}"; return 1; }
    validate_port "${awg_listen}" || { error "AWG 监听端口无效: ${awg_listen}"; return 1; }
    validate_port "${awg_target}" || { error "AWG 目标端口无效: ${awg_target}"; return 1; }
    validate_port "${ss_listen}" || { error "SS 监听端口无效: ${ss_listen}"; return 1; }
    validate_port "${ss_target}" || { error "SS 目标端口无效: ${ss_target}"; return 1; }
    check_port_conflict "${awg_listen}" "udp" "AWG中转监听 (LANDING_LIST)"
    check_port_conflict "${ss_listen}" "tcp" "SS中转监听 (LANDING_LIST)"
    
    # v6.12 新增: 检查IP是否已存在
    if jq -e ".landings[] | select(.ip == \"$ip\")" "${CONFIG_FILE}" &>/dev/null; then
        warn "落地机 $ip 已存在，跳过添加"
        return 0
    fi
    if jq -e --argjson awg "$awg_listen" --argjson ss "$ss_listen" \
       '[.landings[].ports[]? | select(.listen == $awg or .listen == $ss)] | length > 0' \
       "${CONFIG_FILE}" &>/dev/null; then
        error "监听端口 ${awg_listen} 或 ${ss_listen} 已被其他落地机使用"
        return 1
    fi
    
    # 使用 jq 添加落地机（带错误检查）
    local tmp_file="${CONFIG_FILE}.tmp.$$"
    if ! jq --arg ip "$ip" --arg name "$name" --argjson ssh_port "$ssh_port" \
       --argjson awg_listen "$awg_listen" --argjson awg_target "$awg_target" \
       --argjson ss_listen "$ss_listen" --argjson ss_target "$ss_target" \
       '.landings += [{
          "ip": $ip,
          "name": $name,
          "enabled": true,
          "fail_count": 0,
          "success_count": 3,
          "ssh_port": $ssh_port,
          "ports": [
            {"listen": $awg_listen, "target": $awg_target, "proto": "udp", "desc": "AmneziaWG主轨"},
            {"listen": $ss_listen, "target": $ss_target, "proto": "tcp", "desc": "SS备轨"}
          ]
       }]' \
       "${CONFIG_FILE}" > "${tmp_file}" 2>/dev/null; then
        error "jq 添加落地机失败"
        rm -f "${tmp_file}"
        return 1
    fi
    
    # 验证生成的 JSON 格式
    if ! jq empty "${tmp_file}" 2>/dev/null; then
        error "生成的配置文件格式错误"
        rm -f "${tmp_file}"
        return 1
    fi
    
    mv "${tmp_file}" "${CONFIG_FILE}"
    
    success "已添加落地机: ${name} (${ip})，监听 ${awg_listen}/udp→${awg_target}, ${ss_listen}/tcp→${ss_target}"
}


add_port() {
    warn "v6.28 起端口必须配置在具体落地机下，请使用 add_landing 或 ghost-transit-ctl add-landing"
    return 1
}


# ==========================================
# 连通性测试
# ==========================================

test_connectivity() {
    info "测试落地机连通性（并行测试）..."
    local landings_count
    landings_count=$(jq '.landings | length' "${CONFIG_FILE}")
    
    if [[ ${landings_count} -eq 0 ]]; then
        warn "没有配置落地机，跳过连通性测试"
        return 0
    fi
    
    local success_count=0
    local fail_count=0
    local temp_dir="/tmp/ghost-transit-test-$$"
    mkdir -p "${temp_dir}"
    
    # 并行测试所有落地机
    for ((i=0; i<landings_count; i++)); do
        (
            local ip name ssh_port tcp_ports port is_alive
            ip=$(jq -r ".landings[$i].ip" "${CONFIG_FILE}")
            name=$(jq -r ".landings[$i].name" "${CONFIG_FILE}")
            ssh_port=$(jq -r ".landings[$i].ssh_port // 22" "${CONFIG_FILE}")
            tcp_ports=$(jq -r ".landings[$i].ports[]? | select(.proto==\"tcp\") | .target" "${CONFIG_FILE}")
            is_alive=false

            if [[ -n "${tcp_ports}" ]]; then
                while IFS= read -r port; do
                    [[ -z "${port}" ]] && continue
                    if nc -zvw3 "${ip}" "${port}" &>/dev/null; then
                        is_alive=true
                        break
                    fi
                done <<< "${tcp_ports}"
            fi

            if [[ "${is_alive}" != "true" ]] && nc -zvw3 "${ip}" "${ssh_port}" &>/dev/null; then
                is_alive=true
            fi

            if [[ "${is_alive}" == "true" ]]; then
                echo "SUCCESS:${name}:${ip}" > "${temp_dir}/${i}.result"
            else
                echo "FAIL:${name}:${ip}" > "${temp_dir}/${i}.result"
            fi
        ) &
    done
    
    # v5.9 优化：添加超时保护，避免健康检查卡死
    # 等待所有后台任务完成，但最多等待20秒
    local wait_start=$(date +%s)
    local timeout=20
    
    while jobs -r | grep -q .; do
        local elapsed=$(($(date +%s) - wait_start))
        if [[ $elapsed -ge $timeout ]]; then
            warn "健康检查超时（${timeout}秒），强制终止剩余任务"
            # 终止所有后台任务
            jobs -p | xargs -r kill -9 2>/dev/null || true
            break
        fi
        sleep 1
    done
    
    # 确保所有后台任务已清理
    wait 2>/dev/null || true
    
    # 收集结果
    for ((i=0; i<landings_count; i++)); do
        if [[ -f "${temp_dir}/${i}.result" ]]; then
            local result
            result=$(cat "${temp_dir}/${i}.result")
            local status name ip
            IFS=':' read -r status name ip <<< "${result}"
            
            if [[ "${status}" == "SUCCESS" ]]; then
                success "${name} (${ip}) 连通正常"
                success_count=$((success_count + 1))
            else
                warn "${name} (${ip}) 无法连接（SSH端口可能未开放或网络不稳定）"
                fail_count=$((fail_count + 1))
            fi
        fi
    done
    
    # 清理临时文件
    rm -rf "${temp_dir}"
    
    echo ""
    if [[ ${fail_count} -eq 0 ]]; then
        success "所有落地机连通性测试通过 (${success_count}/${landings_count})"
    else
        warn "部分落地机无法连接 (成功: ${success_count}, 失败: ${fail_count})"
        warn "这可能是正常的（SSH端口未开放或网络不稳定）"
    fi
}

# ==========================================
# 交互式配置
# ==========================================

# v6.9 增强-4: 改进输入验证（防止命令注入）
validate_ip() {
    local ip="$1"
    
    # 检查是否包含特殊字符
    if [[ "${ip}" =~ [\;\$\`\&\|\<\>\(\)\{\}\[\]\\] ]]; then
        error "IP 地址包含非法字符"
        return 1
    fi
    
    # 检查 IP 格式
    if [[ ! "${ip}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    
    # 检查每个八位组的范围
    local IFS='.'
    local -a octets=(${ip})
    for octet in "${octets[@]}"; do
        if [[ ${octet} -gt 255 ]]; then
            return 1
        fi
    done
    return 0
}

validate_port() {
    local port="$1"
    if [[ ! "${port}" =~ ^[0-9]+$ ]] || [[ ${port} -lt 1 ]] || [[ ${port} -gt 65535 ]]; then
        return 1
    fi
    return 0
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

# v6.9 增强-5: 依赖包下载重试机制
install_package_with_retry() {
    local package="$1"
    local max_attempts=3
    local attempt=1
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        info "安装 ${package}（尝试 ${attempt}/${max_attempts}）..."
        
        if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${package}" 2>/dev/null; then
            success "${package} 安装成功"
            return 0
        fi
        
        warn "${package} 安装失败，${attempt} 秒后重试..."
        sleep ${attempt}
        attempt=$((attempt + 1))
    done
    
    error "${package} 安装失败（已重试 ${max_attempts} 次）"
    return 1
}

check_port_conflict() {
    local port="$1"
    local proto="$2"
    local name="$3"

    [[ "${proto}" == "tcp" || "${proto}" == "udp" ]] || die "无效的协议 '${proto}'"

    if port_in_use "${proto}" "${port}"; then
        die "端口 ${port}/${proto} (${name}) 已被占用，请先释放端口或更换端口"
    fi
}

ask_landings() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  配置落地机${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local count=0
    while true; do
        echo ""
        if [[ ${count} -eq 0 ]]; then
            echo -e "${YELLOW}请添加至少 1 个落地机${NC}"
        else
            echo -e "${GREEN}已添加 ${count} 个落地机${NC}"
        fi
        
        read -p "$(echo -e ${CYAN}"继续添加落地机? (y/n): "${NC})" choice
        if [[ "${choice}" != "y" ]] && [[ "${choice}" != "Y" ]]; then
            if [[ ${count} -eq 0 ]]; then
                warn "至少需要添加 1 个落地机"
                continue
            fi
            break
        fi
        
        while true; do
            read -p "$(echo -e ${CYAN}"落地机 IP 地址: "${NC})" ip
            if validate_ip "${ip}"; then
                break
            else
                warn "IP 地址格式错误，请重新输入"
            fi
        done
        
        read -p "$(echo -e ${CYAN}"落地机名称 (可选，回车跳过): "${NC})" name
        if [[ -z "${name}" ]]; then
            name="landing-$((count + 1))"
        fi
        
        read -p "$(echo -e ${CYAN}"落地机 SSH 端口 (默认 22): "${NC})" ssh_port
        ssh_port=${ssh_port:-22}
        if ! validate_port "${ssh_port}"; then
            warn "SSH 端口无效，使用默认 22"
            ssh_port=22
        fi
        
        local awg_listen awg_target ss_listen ss_target
        awg_listen=$((51820 + count))
        ss_listen=$((8389 + count))
        awg_target=51820
        ss_target=8389
        
        read -p "$(echo -e ${CYAN}"AWG 中转监听端口 (默认 ${awg_listen}): "${NC})" input_port
        awg_listen=${input_port:-${awg_listen}}
        while ! validate_port "${awg_listen}"; do
            warn "端口号无效，请重新输入"
            read -p "$(echo -e ${CYAN}"AWG 中转监听端口: "${NC})" awg_listen
        done
        check_port_conflict "${awg_listen}" "udp" "AWG中转监听"
        
        read -p "$(echo -e ${CYAN}"AWG 落地目标端口 (默认 ${awg_target}): "${NC})" input_port
        awg_target=${input_port:-${awg_target}}
        while ! validate_port "${awg_target}"; do
            warn "端口号无效，请重新输入"
            read -p "$(echo -e ${CYAN}"AWG 落地目标端口: "${NC})" awg_target
        done
        
        read -p "$(echo -e ${CYAN}"SS 中转监听端口 (默认 ${ss_listen}): "${NC})" input_port
        ss_listen=${input_port:-${ss_listen}}
        while ! validate_port "${ss_listen}"; do
            warn "端口号无效，请重新输入"
            read -p "$(echo -e ${CYAN}"SS 中转监听端口: "${NC})" ss_listen
        done
        check_port_conflict "${ss_listen}" "tcp" "SS中转监听"
        
        read -p "$(echo -e ${CYAN}"SS 落地目标端口 (默认 ${ss_target}): "${NC})" input_port
        ss_target=${input_port:-${ss_target}}
        while ! validate_port "${ss_target}"; do
            warn "端口号无效，请重新输入"
            read -p "$(echo -e ${CYAN}"SS 落地目标端口: "${NC})" ss_target
        done
        
        add_landing "${ip}" "${name}" "${ssh_port}" "${awg_listen}" "${awg_target}" "${ss_listen}" "${ss_target}"
        count=$((count + 1))
    done
    
    success "落地机配置完成，共 ${count} 个"
}

ask_ports() {
    warn "v6.28 起不再使用全局端口配置，端口已在添加每台落地机时配置"
}

print_help() {
    cat <<EOF
用法: bash ${SCRIPT_NAME} [--status|--uninstall|--help]

环境变量:
  LANDING_IP      单落地机 IP
  LANDING_LIST    多落地机列表: IP:名称:AWG监听:SS监听:SSH端口:AWG目标:SS目标;...
                  示例: 1.2.3.4:美西落地机:51821:8391:22:51820:8389;5.6.7.8:日本落地机:51822:8392:22:51820:8389
                  简写: 1.2.3.4:美西落地机;5.6.7.8:日本落地机（端口自动使用默认递增值）
  SKIP_CONNECTIVITY_TEST=1  跳过安装末尾连通性测试
EOF
}

# ==========================================
# 系统优化
# ==========================================

optimize_system() {
    progress 2 6 "优化系统参数"
    
    if [[ -f /etc/sysctl.d/99-transit-ghost.conf ]]; then
        warn "检测到已有配置，将覆盖"
        cp /etc/sysctl.d/99-transit-ghost.conf /etc/sysctl.d/99-transit-ghost.conf.bak.$(date +%s)
        cleanup_old_backups "/etc/sysctl.d/99-transit-ghost.conf"
    fi
    
    local enable_bbr=1
    if ! check_kernel_version; then
        enable_bbr=0
        warn "将使用默认拥塞控制算法（cubic）"
    fi
    
    cat > /etc/sysctl.d/99-transit-ghost.conf <<EOF
# IP 转发（必需）
net.ipv4.ip_forward = 1

net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.all.forwarding = 0
net.ipv6.conf.default.forwarding = 0

EOF
    
    if [[ ${enable_bbr} -eq 1 ]]; then
        cat >> /etc/sysctl.d/99-transit-ghost.conf <<EOF
# BBR 拥塞控制（CN2 GIA 优化）
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

EOF
    fi
    
cat >> /etc/sysctl.d/99-transit-ghost.conf <<EOF
net.ipv4.tcp_slow_start_after_idle = 0
EOF
    
    if sysctl -p /etc/sysctl.d/99-transit-ghost.conf &>/dev/null; then
        log "INFO" "系统参数已应用"
    else
        warn "部分系统参数应用失败，检查关键参数..."
    fi
    
    local ip_forward
    ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
    if [[ "${ip_forward}" != "1" ]]; then
        die "IP 转发未启用，请手动执行: sysctl -w net.ipv4.ip_forward=1"
    fi
    success "IP 转发已启用"
    
    if [[ ${enable_bbr} -eq 1 ]]; then
        local current_cc
        current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
        if [[ "${current_cc}" == "bbr" ]]; then
            success "BBR 拥塞控制已启用"
        else
            warn "BBR 启用失败，当前算法: ${current_cc}"
        fi
    fi
    
    success "系统优化完成"
}

# ==========================================
# 日志轮转
# ==========================================

setup_logrotate() {
    progress 3 6 "配置日志轮转"
    
    cat > /etc/logrotate.d/ghost-transit <<EOF
${LOG_FILE} {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
    sharedscripts
}
EOF
    
    success "日志轮转配置完成"
}

# ==========================================
# nftables 防火墙
# ==========================================

setup_nftables() {
    progress 4 6 "配置 nftables 防火墙"

    systemctl enable nftables &>/dev/null || die "启用 nftables 服务失败"

    /usr/local/bin/ghost-transit-ctl reload-rules || die "生成并加载 nftables 规则失败"
    systemctl restart nftables || die "重启 nftables 服务失败"

    success "nftables 防火墙配置完成"
}

# ==========================================
# 管理工具
# ==========================================

install_management_tool() {
    progress 5 6 "安装管理工具"
    
    # v6.9 增强-6: 强制覆盖管理工具（解决版本不一致问题）
    if [[ -f /usr/local/bin/ghost-transit-ctl ]]; then
        info "检测到旧版本管理工具，强制更新..."
        rm -f /usr/local/bin/ghost-transit-ctl
    fi
    
    cat > /usr/local/bin/ghost-transit-ctl <<'CTLEOF'
#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/ghost-transit/config.json"
NFT_RULES="/etc/nftables.conf"

# P1-1: 添加备份清理函数（管理工具需要独立定义）
cleanup_old_backups() {
    local file_pattern="$1"
    local keep_count=3
    ls -t ${file_pattern}.bak.* 2>/dev/null | tail -n +$((keep_count + 1)) | xargs -r rm -f
}

cmd_status() {
    echo "=== Ghost Transit 状态 ==="
    echo ""
    echo "[配置文件]"
    echo "  路径: ${CONFIG_FILE}"
    echo "  版本: $(jq -r '.version' ${CONFIG_FILE})"
    echo ""
    echo "[落地机]"
    jq -r '.landings[] |
      "  \(.name): \(.ip) [\(if .enabled then "启用" else "禁用" end)]",
      (.ports[]? | "    - \(.listen)/\(.proto) -> \(.target) (\(.desc))")' ${CONFIG_FILE}
    echo ""
    echo "[系统参数]"
    echo "  IP 转发: $(sysctl -n net.ipv4.ip_forward)"
    echo "  BBR 状态: $(sysctl -n net.ipv4.tcp_congestion_control)"
    echo ""
    echo "[nftables 状态]"
    systemctl is-active nftables || echo "  ❌ nftables 未运行"
}

cmd_reload() {
    echo "重新加载 nftables 规则..."
    nft -f "${NFT_RULES}" && echo "✓ 重新加载成功" || echo "✗ 重新加载失败"
}

cmd_reload_rules() {
    # P0 修复：添加文件锁防止并发执行
    local lock_file="/var/run/ghost-transit-reload.lock"
    exec 201>"${lock_file}"
    if ! flock -n 201; then
        echo "规则重载已在进行中，跳过"
        return 0
    fi
    
    echo "重新生成并加载 nftables 规则..."
    
    # 备份当前规则
    if [[ -f "${NFT_RULES}" ]]; then
        cp "${NFT_RULES}" "${NFT_RULES}.bak.$(date +%s)"
        cleanup_old_backups "${NFT_RULES}"
    fi
    
    # v5.7 精简：直接检测网络接口，删除冗余的缓存逻辑
    # 原因：Debian 12 (Linux 6.1+) 绝对支持 Flowtable，无需复杂的缓存检测
    local main_iface
    main_iface=$(ip route show default | awk '/default/ {print $5; exit}')
    
    local use_flowtable=true
    if [[ -z "${main_iface}" ]]; then
        use_flowtable=false
    elif ! ip link show "${main_iface}" &>/dev/null; then
        use_flowtable=false
    fi
    
    # 获取 SSH 端口
    local ssh_port
    ssh_port=$(jq -r '.ssh_port' "${CONFIG_FILE}")
    
    # 使用 jq 生成完整的 nftables 规则（P0 修复：添加错误检测）
    local nft_content
    local tmp_rules="${NFT_RULES}.tmp.$$"
    
    if ! nft_content=$(jq -r --arg ssh "${ssh_port}" --arg iface "${main_iface}" --argjson use_ft $(${use_flowtable} && echo "true" || echo "false") '
        def forward_ports:
            [.landings[] | select(.enabled == true) | .ports[]? |
             "        \(.proto) dport \(.listen) accept"] | unique | join("\n");
        
        def forward_rules:
            [.landings[] | select(.enabled == true) as $landing |
             $landing.ports[]? | "        ip daddr \($landing.ip) \(.proto) dport \(.target) accept"] | join("\n");
        
        def dnat_rules:
            [.landings[] | select(.enabled == true) as $landing |
             $landing.ports[]? | "        \(.proto) dport \(.listen) dnat ip to \($landing.ip):\(.target)"] | join("\n");
        
        # 生成 masquerade_rules 规则
        # v5.7 修复：恢复SNAT规则，避免非对称路由导致断网
        # 原因：中转机只做DNAT不做SNAT会导致回包路径错误（落地机直接回包给客户端IP）
        def masquerade_rules:
            ["        oifname != \"lo\" masquerade"] | join("\n");
        
        "#!/usr/sbin/nft -f\n\n" +
        "flush ruleset\n\n" +
        "table inet filter {\n" +
        (if $use_ft then
            "    flowtable ft {\n" +
            "        hook ingress priority 0;\n" +
            "        devices = { \($iface) };\n" +
            "    }\n\n"
        else "" end) +
        "    chain input {\n" +
        "        type filter hook input priority filter; policy drop;\n\n" +
        "        iif lo accept\n\n" +
        "        ct state established,related accept\n\n" +
        "        tcp dport \($ssh) accept\n\n" +
        "        icmp type echo-request limit rate 1/second accept\n\n" +
        "        drop\n" +
        "    }\n\n" +
        "    chain forward {\n" +
        "        type filter hook forward priority filter; policy drop;\n\n" +
        (if $use_ft then
            "        ip protocol { tcp, udp } ct state established flow add @ft\n\n"
        else "" end) +
        "        ct state established,related accept\n\n" +
        "        icmp type echo-request accept\n\n" +
        forward_rules + "\n\n" +
        "        drop\n" +
        "    }\n\n" +
        "    chain output {\n" +
        "        type filter hook output priority filter; policy accept;\n" +
        "    }\n" +
        "}\n\n" +
        "table inet nat {\n" +
        "    chain prerouting {\n" +
        "        type nat hook prerouting priority dstnat; policy accept;\n\n" +
        dnat_rules + "\n" +
        "    }\n\n" +
        "    chain postrouting {\n" +
        "        type nat hook postrouting priority srcnat; policy accept;\n\n" +
        masquerade_rules + "\n" +
        "    }\n" +
        "}\n"
    ' "${CONFIG_FILE}" 2>&1); then
        echo "✗ jq 生成规则失败: ${nft_content}"
        rm -f "${tmp_rules}"
        return 1
    fi
    
    # 检查生成的内容是否为空
    if [[ -z "${nft_content}" ]]; then
        echo "✗ 生成的规则为空，config.json 可能已损坏"
        rm -f "${tmp_rules}"
        return 1
    fi
    
    # 写入临时文件（P0 修复：使用临时文件，使用 printf 正确处理转义字符）
    printf '%s' "${nft_content}" > "${tmp_rules}"
    
    # 验证规则语法（P0 修复：验证后再替换）
    if ! nft -c -f "${tmp_rules}" 2>/dev/null; then
        echo "✗ 生成的规则语法错误"
        rm -f "${tmp_rules}"
        return 1
    fi
    
    # 原子替换规则文件（P0 修复：原子操作）
    mv "${tmp_rules}" "${NFT_RULES}"
    
    # 加载新规则
    if nft -f "${NFT_RULES}"; then
        echo "✓ 规则重新生成并加载成功"
        return 0
    else
        echo "✗ 规则加载失败"
        return 1
    fi
}

port_in_use() {
    local proto="$1" port="$2"
    if [[ "${proto}" == "tcp" ]]; then
        ss -H -tln "sport = :${port}" 2>/dev/null | grep -q .
    else
        ss -H -uln "sport = :${port}" 2>/dev/null | grep -q .
    fi
}

cmd_add_landing() {
    local ip="${1:-}"
    shift || true
    local name="landing-$(date +%s)"
    local ssh_port="22"
    if [[ $# -gt 0 && "${1:-}" != --* ]]; then
        name="$1"
        shift
    fi
    if [[ $# -gt 0 && "${1:-}" != --* ]]; then
        ssh_port="$1"
        shift
    fi
    local awg_listen=51820
    local awg_target=51820
    local ss_listen=8389
    local ss_target=8389
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --awg-listen) awg_listen="${2:-}"; shift 2 ;;
            --awg-target) awg_target="${2:-}"; shift 2 ;;
            --ss-listen) ss_listen="${2:-}"; shift 2 ;;
            --ss-target) ss_target="${2:-}"; shift 2 ;;
            *) echo "✗ 未知参数: $1"; exit 1 ;;
        esac
    done
    
    # 验证 IP 地址
    if ! [[ "${ip}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "✗ 无效的 IP 地址: ${ip}"
        exit 1
    fi
    
    for port in "$ssh_port" "$awg_listen" "$awg_target" "$ss_listen" "$ss_target"; do
        if ! [[ "${port}" =~ ^[0-9]+$ ]] || [[ ${port} -lt 1 ]] || [[ ${port} -gt 65535 ]]; then
            echo "✗ 无效的端口号: ${port}"
            exit 1
        fi
    done
    
    if jq -e --argjson awg "$awg_listen" --argjson ss "$ss_listen" \
       '[.landings[].ports[]? | select(.listen == $awg or .listen == $ss)] | length > 0' \
       "${CONFIG_FILE}" >/dev/null; then
        echo "✗ 监听端口 ${awg_listen} 或 ${ss_listen} 已被使用"
        exit 1
    fi

    if port_in_use udp "${awg_listen}"; then
        echo "✗ UDP 监听端口 ${awg_listen} 已被系统占用"
        exit 1
    fi
    if port_in_use tcp "${ss_listen}"; then
        echo "✗ TCP 监听端口 ${ss_listen} 已被系统占用"
        exit 1
    fi
    
    jq --arg ip "$ip" --arg name "$name" --argjson ssh_port "$ssh_port" \
       --argjson awg_listen "$awg_listen" --argjson awg_target "$awg_target" \
       --argjson ss_listen "$ss_listen" --argjson ss_target "$ss_target" \
       '.landings += [{
          "ip": $ip,
          "name": $name,
          "enabled": true,
          "fail_count": 0,
          "success_count": 3,
          "ssh_port": $ssh_port,
          "ports": [
            {"listen": $awg_listen, "target": $awg_target, "proto": "udp", "desc": "AmneziaWG主轨"},
            {"listen": $ss_listen, "target": $ss_target, "proto": "tcp", "desc": "SS备轨"}
          ]
       }]' \
       "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
    
    echo "✓ 已添加落地机: ${name} (${ip}:${ssh_port})"
    echo "  - ${awg_listen}/udp -> ${ip}:${awg_target}"
    echo "  - ${ss_listen}/tcp -> ${ip}:${ss_target}"
    echo "⚠️  请运行 'ghost-transit-ctl reload-rules' 重新生成规则"
}

cmd_add_port() {
    echo "✗ v6.28 已改为每个落地机独立端口映射，请使用 add-landing 的 --awg-listen/--ss-listen 参数"
    exit 1
}

cmd_help() {
    cat <<EOF
Ghost Transit 管理工具

用法:
  ghost-transit-ctl <命令> [参数]

命令:
  status                    显示当前状态
  reload                    重新加载 nftables 规则（不重新生成）
  reload-rules              重新生成并加载 nftables 规则（健康检查使用）
  add-landing <IP> [名称] [SSH端口] [--awg-listen P] [--awg-target P] [--ss-listen P] [--ss-target P]
  add-port                  已废弃：端口必须跟随落地机配置
  help                      显示此帮助信息

示例:
  ghost-transit-ctl status
  ghost-transit-ctl add-landing 1.2.3.4 "美西落地机" --awg-listen 51821 --awg-target 51820 --ss-listen 8391 --ss-target 8389
  ghost-transit-ctl reload-rules
EOF
}

case "${1:-help}" in
    status) cmd_status ;;
    reload) cmd_reload ;;
    reload-rules) cmd_reload_rules ;;
    add-landing) shift; cmd_add_landing "$@" ;;
    add-port) cmd_add_port "${2:-}" "${3:-}" "${4:-}" ;;
    help|--help|-h) cmd_help ;;
    *) echo "未知命令: $1"; cmd_help; exit 1 ;;
esac
CTLEOF
    
    chmod +x /usr/local/bin/ghost-transit-ctl
    success "管理工具已安装: ghost-transit-ctl"
}

# ==========================================
# 健康检查
# ==========================================

setup_health_check() {
    info "安装落地机健康检查脚本..."
    
    # v6.27: 验证 nc 命令存在性
    if ! command -v nc &>/dev/null; then
        error "nc 命令不存在，健康检查无法运行"
        die "请先安装 netcat-openbsd: apt-get install -y netcat-openbsd"
    fi
    
    cat > "${CONFIG_DIR}/health_check.sh" <<'HEALTHEOF'
#!/usr/bin/env bash
set -u

LOCK_FILE="/var/run/ghost-transit-health.lock"
LOG_FILE="/var/log/ghost-transit.log"
CONFIG_FILE="/etc/ghost-transit/config.json"

log() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [HEALTH] ${msg}" >> "${LOG_FILE}" 2>/dev/null || true
    logger -t ghost-transit "${msg}" 2>/dev/null || true
}

update_config() {
    local expr="$1"
    local tmp="${CONFIG_FILE}.tmp.$$"
    if jq "${expr}" "${CONFIG_FILE}" > "${tmp}" 2>/dev/null; then
        mv "${tmp}" "${CONFIG_FILE}" 2>/dev/null || {
            rm -f "${tmp}" 2>/dev/null || true
            log "ERROR: 写入配置失败"
            return 1
        }
        return 0
    fi
    rm -f "${tmp}" 2>/dev/null || true
    log "ERROR: 更新配置失败，跳过本轮状态写入"
    return 1
}

exec 200>"${LOCK_FILE}"
if ! flock -n 200; then
    log "健康检查已在运行，跳过本次检查"
    exit 0
fi

while true; do
sleep $((900 + RANDOM % 300))

if [[ ! -s "${CONFIG_FILE}" ]]; then
    log "ERROR: 配置文件不存在或为空，跳过本轮健康检查"
    continue
fi

if ! jq -e '.landings | type == "array"' "${CONFIG_FILE}" >/dev/null 2>&1; then
    log "ERROR: 配置文件 JSON 异常，跳过本轮健康检查"
    continue
fi

if ! systemctl is-active --quiet nftables; then
    log "ERROR: nftables 服务已停止，尝试重启"
    systemctl restart nftables 2>/dev/null || log "ERROR: nftables 重启失败"
fi

# 检查所有落地机的存活状态
landings_count=$(jq '.landings | length' "${CONFIG_FILE}" 2>/dev/null) || {
    log "ERROR: 读取落地机数量失败，跳过本轮健康检查"
    continue
}
if [[ ! "${landings_count}" =~ ^[0-9]+$ ]]; then
    log "ERROR: 落地机数量异常，跳过本轮健康检查"
    continue
fi

for ((i=0; i<landings_count; i++)); do
    landing_line=$(jq -r ".landings[$i] | [.ip // \"\", ((.enabled // false) | tostring), .name // \"landing-${i}\"] | @tsv" "${CONFIG_FILE}" 2>/dev/null) || {
        log "ERROR: 读取第 ${i} 个落地机失败，跳过"
        continue
    }
    IFS=$'\t' read -r ip enabled name <<< "${landing_line}"
    if [[ -z "${ip}" ]]; then
        log "ERROR: 第 ${i} 个落地机 IP 为空，跳过"
        continue
    fi
    
    is_alive=false

    ssh_port=$(jq -r ".landings[$i].ssh_port // 22" "${CONFIG_FILE}" 2>/dev/null) || ssh_port=22
    [[ "${ssh_port}" =~ ^[0-9]+$ ]] || ssh_port=22
    tcp_ports=$(jq -r ".landings[$i].ports[]? | select(.proto==\"tcp\") | .target" "${CONFIG_FILE}" 2>/dev/null) || tcp_ports=""

    if [[ -n "${tcp_ports}" ]]; then
        while IFS= read -r port; do
            [[ -z "${port}" ]] && continue
            if nc -zvw3 "${ip}" "${port}" >/dev/null 2>&1; then
                is_alive=true
                break
            fi
        done <<< "${tcp_ports}"
    fi

    if [[ "${is_alive}" != "true" ]] && nc -zvw3 "${ip}" "${ssh_port}" >/dev/null 2>&1; then
        is_alive=true
    fi
    
    # v6.13 优化：防抖机制 - 连续3次失败才禁用，连续3次成功才启用
    # 读取失败计数
    fail_count=$(jq -r ".landings[$i].fail_count // 0" "${CONFIG_FILE}" 2>/dev/null) || fail_count=0
    [[ "${fail_count}" =~ ^[0-9]+$ ]] || fail_count=0
    
    if [[ "${is_alive}" == "true" ]]; then
        # 存活 -> 重置失败计数
        if [[ ${fail_count} -gt 0 ]]; then
            update_config ".landings[$i].fail_count = 0" || continue
        fi
        
        # 连续3次成功才重新启用（防止网络抖动频繁切换）
        if [[ "${enabled}" == "false" ]]; then
            success_count=$(jq -r ".landings[$i].success_count // 0" "${CONFIG_FILE}" 2>/dev/null) || success_count=0
            [[ "${success_count}" =~ ^[0-9]+$ ]] || success_count=0
            success_count=$((success_count + 1))
            update_config ".landings[$i].success_count = ${success_count}" || continue
            
            if [[ ${success_count} -ge 3 ]]; then
                update_config ".landings[$i].enabled = true | .landings[$i].success_count = 0" || continue
                
                # 重新生成并加载 nftables 规则
                if ! /usr/local/bin/ghost-transit-ctl reload-rules; then
                    log "ERROR: 规则重新生成失败，落地机 ${name} (${ip}) 恢复状态未生效"
                else
                    # [P2-3] 只在状态变化时记录日志
                    log "落地机 ${name} (${ip}) 连续3次检测成功，已重新启用"
                fi
            fi
        fi
    else
        # 宕机 -> 增加失败计数
        fail_count=$((fail_count + 1))
        update_config ".landings[$i].fail_count = ${fail_count}" || continue
        
        # 连续3次失败才禁用（防止偶发网络抖动误判）
        if [[ "${enabled}" == "true" ]] && [[ ${fail_count} -ge 3 ]]; then
            update_config ".landings[$i].enabled = false" || continue
            
            # 重新生成并加载 nftables 规则
            if ! /usr/local/bin/ghost-transit-ctl reload-rules; then
                log "ERROR: 规则重新生成失败，落地机 ${name} (${ip}) 禁用状态未生效"
            else
                # [P2-3] 只在状态变化时记录日志
                log "落地机 ${name} (${ip}) 连续3次检测失败，已禁用"
            fi
        fi
    fi
done

# [P2-3] 删除冗余的检查完成日志，减少噪音
done
HEALTHEOF
    
    chmod +x "${CONFIG_DIR}/health_check.sh"
    
    crontab -l 2>/dev/null | grep -v "health_check.sh" | crontab - 2>/dev/null || true

    cat > /etc/systemd/system/ghost-transit-health.service <<EOF
[Unit]
Description=Ghost Transit Health Check
After=network-online.target nftables.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=${CONFIG_DIR}/health_check.sh
Restart=always
RestartSec=20s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload || die "systemd daemon-reload 失败"
    systemctl enable ghost-transit-health.service >/dev/null 2>&1 || die "启用健康检查服务失败"
    systemctl restart ghost-transit-health.service || die "启动健康检查服务失败"
    success "健康检查已启用（随机 15-20 分钟自循环）"
}

# ==========================================
# 卸载功能
# ==========================================

uninstall() {
    echo -e "${YELLOW}开始卸载中转机组件...${NC}"
    echo ""
    echo "卸载选项："
    echo "  [1] 完全卸载（停止服务 + 清理防火墙 + 删除配置）"
    echo "  [2] 仅停止服务（保留防火墙和配置）"
    echo ""
    read -p "请选择 (1/2): " choice
    
    # 停止健康检查 cron 任务
    crontab -l 2>/dev/null | grep -v "health_check.sh" | crontab - 2>/dev/null || true
    systemctl stop ghost-transit-health.service 2>/dev/null || true
    systemctl disable ghost-transit-health.service 2>/dev/null || true
    rm -f /etc/systemd/system/ghost-transit-health.service
    systemctl daemon-reload 2>/dev/null || true
    echo -e "${GREEN}健康检查任务已停止${NC}"
    
    if [[ "${choice}" == "1" ]]; then
        # 完全卸载
        echo -e "${YELLOW}正在清理 nftables 规则...${NC}"
        
        # 停止并禁用 nftables
        systemctl stop nftables 2>/dev/null || true
        systemctl disable nftables 2>/dev/null || true
        
        # 清空 nftables 规则
        nft flush ruleset 2>/dev/null || true
        
        # 删除 nftables 配置文件
        rm -f /etc/nftables.conf
        
        echo -e "${GREEN}nftables 规则已清理${NC}"
        
        # 删除配置文件
        rm -rf "${CONFIG_DIR}"
        echo -e "${GREEN}配置文件已删除${NC}"
        
        # 删除管理工具
        rm -f /usr/local/bin/ghost-transit-ctl
        echo -e "${GREEN}管理工具已删除${NC}"
        
        # 删除健康检查脚本
        rm -f /usr/local/bin/ghost-transit-health-check.sh
        rm -f ${CONFIG_DIR}/health_check.sh
        echo -e "${GREEN}健康检查脚本已删除${NC}"
        
        # 删除日志轮转配置
        rm -f /etc/logrotate.d/ghost-transit
        echo -e "${GREEN}日志轮转配置已删除${NC}"
        
        # 恢复系统参数
        rm -f /etc/sysctl.d/99-transit-ghost.conf
        sysctl -p 2>/dev/null || true
        echo -e "${GREEN}系统参数已恢复${NC}"
    else
        # 仅停止服务
        echo -e "${CYAN}nftables 规则保留${NC}"
        echo -e "${CYAN}配置文件保留在 ${CONFIG_DIR}${NC}"
        echo -e "${CYAN}系统参数保留${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}卸载完成${NC}"
    exit 0
}

# ==========================================
# 输出摘要
# ==========================================

print_summary() {
    progress 6 6 "生成配置摘要"
    
    local public_ip
    public_ip=$(curl -fsS4 --max-time 5 https://ifconfig.me/ip || echo "<获取失败>")
    
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  中转机安装完成! (v${VERSION})${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}📋 配置摘要:${NC}"
    echo ""
    echo "  中转机公网 IP: ${public_ip}"
    echo ""
    echo "  落地机列表:"
    jq -r '.landings[] |
      "    - \(.name): \(.ip)",
      (.ports[]? | "      \(.listen)/\(.proto) -> \(.target) (\(.desc))")' "${CONFIG_FILE}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠️  重要提示:${NC}"
    echo ""
    echo "  1. 配置文件: ${CONFIG_FILE}"
    echo "  2. 管理工具: ghost-transit-ctl"
    echo "  3. 查看状态: ghost-transit-ctl status"
    echo "  4. 添加落地机: ghost-transit-ctl add-landing <IP> [名称] --awg-listen <端口> --ss-listen <端口>"
    echo "  5. 重新生成规则: ghost-transit-ctl reload-rules"
    echo "  6. 重新加载现有规则: ghost-transit-ctl reload"
    echo "  7. 日志文件: ${LOG_FILE}"
    echo "  8. 健康检查: 每15-20分钟自动检测落地机存活状态（自动故障转移）"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ==========================================
# 主流程
# ==========================================

main() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        print_help
        exit 0
    fi

    check_root

    # 处理状态查询
    if [[ "${1:-}" == "--status" ]]; then
        if [[ -f /usr/local/bin/ghost-transit-ctl ]]; then
            /usr/local/bin/ghost-transit-ctl status
        else
            echo "错误: 管理工具未安装，请先运行安装脚本"
            exit 1
        fi
        exit 0
    fi

    # 处理卸载请求
    if [[ "${1:-}" == "--uninstall" ]]; then
        uninstall
        exit 0
    fi

    check_os
    check_no_proxy  # P1-2: 检查应用层代理配置
    
    # v6.12 新增: 安装依赖包
    install_dependencies
    
    # v6.9 增强: 添加预检查
    check_disk_space
    check_network || warn "网络检查失败，但继续安装"
    
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  中转机安装脚本 v${VERSION}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    info "脚本版本: v${VERSION}"
    log "INFO" "开始安装中转机 v${VERSION}"
    echo ""
    echo -e "${YELLOW}架构说明:${NC}"
    echo "  - 纯内核级转发（nftables DNAT + MASQUERADE + flowtable 加速）"
    echo "  - 支持多落地机配置"
    echo "  - 动态端口管理"
    echo ""
    
    init_config
    
    # v6.31: 支持多落地机非交互导入
    if [[ -n "${LANDING_LIST:-}" ]]; then
        info "检测到 LANDING_LIST，使用多落地机非交互配置"
        local item idx ip name awg_port ss_port ssh_port awg_target ss_target
        idx=1
        IFS=';' read -ra landing_items <<< "${LANDING_LIST}"
        for item in "${landing_items[@]}"; do
            [[ -z "${item}" ]] && continue
            IFS=':' read -r ip name awg_port ss_port ssh_port awg_target ss_target <<< "${item}"
            [[ -n "${ip:-}" ]] && validate_ip "${ip}" || die "LANDING_LIST 中 IP 无效: ${item}"
            name="${name:-landing-${idx}}"
            awg_port="${awg_port:-$((51820 + idx - 1))}"
            ss_port="${ss_port:-$((8389 + idx - 1))}"
            ssh_port="${ssh_port:-22}"
            awg_target="${awg_target:-51820}"
            ss_target="${ss_target:-8389}"
            validate_port "${awg_port}" || die "LANDING_LIST 中 AWG 监听端口无效: ${item}"
            validate_port "${ss_port}" || die "LANDING_LIST 中 SS 监听端口无效: ${item}"
            validate_port "${ssh_port}" || die "LANDING_LIST 中 SSH 端口无效: ${item}"
            validate_port "${awg_target}" || die "LANDING_LIST 中 AWG 目标端口无效: ${item}"
            validate_port "${ss_target}" || die "LANDING_LIST 中 SS 目标端口无效: ${item}"
            add_landing "${ip}" "${name}" "${ssh_port}" "${awg_port}" "${awg_target}" "${ss_port}" "${ss_target}"
            idx=$((idx + 1))
        done
        success "LANDING_LIST 配置完成"
    elif [[ -n "${LANDING_IP:-}" ]]; then
        info "检测到非交互模式，使用环境变量配置"
        
        # 添加落地机
        local landing_name="${LANDING_NAME:-landing-1}"
        # 添加落地机和该落地机自己的端口映射
        local awg_port="${AWG_PORT:-51820}"
        local ss_port="${SS_PORT:-8389}"
        local awg_target="${AWG_TARGET_PORT:-51820}"
        local ss_target="${SS_TARGET_PORT:-8389}"
        
        add_landing "${LANDING_IP}" "${landing_name}" "${LANDING_SSH_PORT:-22}" "${awg_port}" "${awg_target}" "${ss_port}" "${ss_target}"
        
        success "非交互模式配置完成"
    else
        # 交互模式
        ask_landings
    fi
    
    echo ""
    optimize_system
    setup_logrotate
    install_management_tool
    setup_nftables
    setup_health_check
    
    # 可选：测试落地机连通性
    echo ""
    # v6.13 优化：支持环境变量跳过连通性测试（非交互模式）
    if [[ -z "${SKIP_CONNECTIVITY_TEST:-}" && -t 0 ]]; then
        info "是否测试落地机连通性？(如果落地机尚未安装，请选择 n)"
        read -p "测试连通性? [y/N]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            test_connectivity
        else
            info "跳过连通性测试"
        fi
    else
        info "非交互模式或 SKIP_CONNECTIVITY_TEST 已设置：跳过连通性测试"
    fi
    
    print_summary
}

main "$@"
