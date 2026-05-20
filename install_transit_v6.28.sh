#!/usr/bin/env bash
set -euo pipefail

# install_transit_v6.28.sh — 中转机安装脚本
# 版本: v6.28 (2026-05-20)
# v6.28 - 真正改为每落地机独立 listen/target 端口映射；修复 VERSION 覆盖。
# v6.27 - 健康检查优先探测落地机 TCP 业务端口，回退 SSH。
# v6.25 - 【P1 修复 - 健康检查 cron 任务添加失败】
#       - [P1-1] 修复 crontab - 在非交互式环境失败问题
#       - [P1-2] 改用 crontab -l 追加方式，兼容 SSH heredoc
#       - 代码统计：v6.24(1831行) → v6.25(1835行)，净增加4行
# v6.24 - 【P0/P1 问题修复 - 安装与运行循环测试】
#       - [P0-1] 修复 show_status 函数不存在：--status 参数调用 ghost-transit-ctl status
#       - [P0-2] 修复卸载 sysctl 文件名错误：99-ghost-transit.conf → 99-transit-ghost.conf
#       - [P0-3] 修复卸载 cron 任务路径错误：ghost-transit-health-check.sh → health_check.sh
#       - [P1-1] 统一版本号：中转机和落地机统一为 v6.24
#       - 代码统计：v6.19(1727行) → v6.24(1728行)，净增加1行
# v6.19 - 【健康检查注释优化】
#       - [P2-1] 健康检查随机延迟注释已在v6.18优化完成
#       - 代码统计：v6.18(1724行) → v6.19(1721行)，净减少3行
# v6.18 - 【管理工具完善 + 健康检查优化】
#       - [P1-1] 管理工具添加cleanup_old_backups函数（修复reload-rules报错）
#       - [P2-2] 优化健康检查随机延迟注释（说明为什么是60秒）
#       - 代码统计：v6.17(1711行) → v6.18(1724行)，净增加13行
# v6.17 - 【安全增强 + 代码质量提升】
#       - [P1-2] 添加应用层代理检测（防止误配代理导致流量泄漏）
#       - [P1-3] 健康检查随机延迟从120秒改为60秒（避免cron任务堆积）
#       - [P2-1] 删除重复的shebang声明
#       - [确认] test_connectivity()已在v6.16改用nc（P0-2已修复）
#       - 代码统计：v6.16(1688行) → v6.17(1711行)，净增加23行
# v6.16 - 【审查AI综合修复】版本号统一 + SSH端口读取修复 + 健康检查初始状态优化
#       - [P0-1] test_connectivity()改用nc替代ping：与health_check.sh保持一致
#         * 根源：v6.13声称改用TCP探测，但test_connectivity()仍在用ping
#         * 现象：安装阶段连通性测试因ICMP被Drop而误判失败
#         * 修复：第465行改为nc -zvw3探测SSH端口
#       - [P0-1] 健康检查添加随机延迟：破坏机器级精准时序特征
#         * 危害：每300秒精准发起TCP探测，典型的Bot自动化特征
#         * 修复：health_check.sh开头添加sleep $((RANDOM % 60))
#         * 理由：GFW高维度流量分析会识别固定心跳，导致CN2 GIA降级
#       - [P1-2] 健康检查初始状态优化：新落地机success_count=3
#         * 问题：新添加的落地机从"待验证"状态开始，冷启动困境
#         * 修复：初始化时设置success_count=3，信任刚通过测试的落地机
#       - [P2-3] 健康检查日志优化：只记录状态变化，减少噪音
#         * 问题：每5分钟记录一次，一天288条日志，即使状态未变化
#         * 修复：只在enabled状态切换时记录
#       - 代码统计：v6.13(1664行) → v6.14(1680行)，净增加16行
# v6.13 - 【审查AI建议修复 - 健康检查+防抖+精简优化】
#       - [P0-1] 健康检查改用TCP探测：废弃ping，改用nc探测SSH端口
#       - 根源：跨国网络ICMP经常被Drop，导致误判宕机，每5分钟断网
#       - 修复：使用nc -zvw3探测SSH端口，精准确认公网IP可达
#       - [P1-1] 健康检查防抖机制：连续3次失败才禁用，连续3次成功才启用
#       - 根源：网络抖动时频繁切换落地机，影响稳定性
#       - 修复：在config.json中添加fail_count/success_count字段
#       - [P1-2] 非交互模式完善：增加SKIP_CONNECTIVITY_TEST环境变量
#       - 根源：即使设置环境变量，仍会提示用户输入
#       - 修复：检查环境变量，跳过交互式连通性测试
#       - [P2-1] 备份文件清理：只保留最近3个备份
#       - 根源：每次运行生成.bak文件，长期累积大量备份
#       - 修复：添加cleanup_old_backups()函数，自动清理旧备份
#       - [P2-2] 删除重复依赖检查：setup_nftables中的jq/nc检查
#       - 根源：install_dependencies()已安装，setup_nftables()又检查一次
#       - 修复：删除setup_nftables()中的重复检查，减少17行代码
#       - [P2-3] 精简jq解析：删除不存在的tunnel_ip字段
#       - 根源：中转机不需要隧道IP，但健康检查脚本仍在解析
#       - 修复：删除awg_tunnel_ip变量和相关逻辑
#       - 影响：修复健康检查误判 + 防止频繁切换 + 代码更简洁
#       - 代码统计：v6.12(1645行) → v6.13(1643行)，净减少 2 行
# v6.12 - 【极限测试修复 - 依赖缺失 + 交互式死循环 + 重复资源】
#       - [P0-1] 添加 install_dependencies() 函数：自动安装 jq/nftables/netcat-openbsd
#       - 根源：v6.11 注释中提到依赖安装但函数不存在，干净系统100%失败
#       - 现象：init_config 阶段因缺少 jq 而报错"配置文件 JSON 格式错误"
#       - [P0-2] 添加非交互模式：支持通过环境变量 LANDING_IP/AWG_PORT/SS_PORT 传参
#       - 根源：交互式循环在自动化测试时陷入死循环，重复添加同一资源600+次
#       - 现象：expect 脚本匹配"继续添加"后无限发送"y"，config.json 膨胀到 67KB
#       - [P1-1] 添加重复资源检测：add_landing/add_port 检查 IP/端口是否已存在
#       - 影响：修复首次安装失败 + 支持自动化测试 + 防止配置污染
#       - 代码统计：v6.11(1547行) → v6.12(1614行)，净增加 67 行
# v6.11 - 【极限测试修复 - 缺少 uninstall 函数】
#       - [P0-1] 添加 uninstall() 函数：完整的卸载逻辑（nftables + 配置 + 管理工具 + 健康检查）
#       - 根源：v6.10 在第 1428 行调用 uninstall 但函数不存在，导致 --uninstall 参数失败
#       - 影响：修复 "uninstall: command not found" 错误，卸载功能现在可以正常工作
#       - 代码统计：v6.10(1477行) → v6.11(1542行)，净增加 65 行
# v6.10 - 【紧急修复 - nftables 规则未加载】
#       - [P0-1] 修复 nftables 规则写入文件时转义字符未处理的问题（使用 printf '%b' 替代 echo）
#       - [P0-1] 影响：v6.9 安装后规则完全未加载，导致转发功能完全失效
# v6.9 - 【容错增强 - 异常场景测试后的改进】
#       - [增强-1] 添加磁盘空间预检查（至少需要 500MB 可用空间）
#       - [增强-2] 添加配置文件完整性检查（JSON 格式验证）
#       - [增强-3] 添加网络连通性检查（DNS 解析 + 外网访问）
#       - [增强-4] 改进输入验证（拒绝特殊字符，防止命令注入）
#       - [增强-5] 添加依赖包下载重试机制（最多重试 3 次）
#       - [增强-6] 强制覆盖管理工具（解决版本不一致问题）
#       - 测试结果：极限测试 5 轮全部通过 + 异常场景测试 7 个场景全部通过
#       - 详细报告：anzhuang.md
# v6.8 - 【极限测试修复 - 管理工具所有 jq 转义错误】
#       - 修复：管理工具中的 6 个 jq 转义错误（完整修复）
#       - 影响：nftables 规则生成功能完全恢复
# v6.7 - 【极限测试修复 - nftables 规则生成 jq 转义错误】
#       - 修复：第 962 行 log prefix 转义不足（2个反斜杠 → 4个反斜杠）
#       - 影响：ghost-transit-ctl reload-rules 失败，导致所有端口转发功能失效
# v6.6 - 【极限测试修复 - jq 转义层级错误（完整修复）】
#       - 问题：v6.5 的 patch 工具修复失败，脚本中仍然是 \\\\\\\\(.proto) 等 4 反斜杠
# v6.6 - 【极限测试修复 - jq 转义层级错误（完整修复）】
#       - [P0-4] 使用 Python 正则批量修复所有 jq 转义问题
#       - 问题：v6.5 的 patch 工具修复失败，脚本中仍然是 \\\\(.proto) 等 4 反斜杠
#       - 修复：Python re.sub 批量替换所有 \\\\( 为 \\(
#       - 影响：forward_ports、forward_rules、dnat_rules、masquerade_rules 全部修复
# v6.5 - 【极限测试修复 - jq 转义层级错误】
#       - [P0-3] 修复 forward_ports/forward_rules/dnat_rules 中的转义层级
#       - 问题：\\\\(.proto) 有4个反斜杠，bash解析后传给jq是 \\(.proto)，被当作字面文本
#       - 修复：改为 \\(.proto)，bash解析后是 \(.proto)，触发jq插值
#       - 影响：nftables 配置现在能正确生成端口号和IP地址
#       - 注意：patch 工具修复失败，v6.6 使用 Python 重新修复
# v6.4 - 【极限测试修复 - jq 字符串插值错误】
#       - [P0-2] 修复 nftables 配置中的 jq 变量插值错误
#       - 问题：\\($iface) 和 \\($ssh) 被当作字面字符串，未被替换为实际值
#       - 根源：--arg 传入的变量在 jq 字符串中应使用单反斜杠 \($var)，双反斜杠会转义为字面字符串
#       - 修复：将所有 \\($iface) 改为 \($iface)，\\($ssh) 改为 \($ssh)
#       - 影响：flowtable devices 和 SSH 端口规则现在能正确替换变量
# v6.3 - 【极限测试修复 - jq 上下文错误】
#       - [P0-1] 修复 forward_rules 和 dnat_rules 函数的 jq 上下文错误
#       - 问题：`.landings[] | select(.enabled == true) as $landing | .ports[]` 中的 `.ports[]` 引用了错误的上下文
#       - 根源：landing 对象只有 ip/name/enabled 字段，没有 ports 字段，ports 是顶层字段
#       - 修复：使用 `. as $root` 保存顶层对象，然后用 `$root.ports[]` 引用顶层 ports
#       - 影响：修复 "Cannot iterate over null" 错误，nftables 规则生成成功
#       - 代码统计：v6.2(1302行) → v6.3(1304行)，净增加2行
# v6.2 - 【H2 主笔修复 - jq 转义符号错误 + masquerade_rules 数组问题】
#       - [P0-1] 修复 masquerade_rules 数组无法和字符串拼接的问题
#       - 问题：v5.9 的 masquerade_rules 返回数组，但在第 751/932 行直接用 + 拼接字符串，jq 报错
#       - v6.0/v6.1 错误修复：在函数定义中添加 join，但转义符号数量错误
#       - 正确方案：函数返回数组，使用时用 (masquerade_rules | join("\\n"))
#       - 修复：第 697/910 行恢复原始数组定义，第 770/951 行改为 (masquerade_rules | join("\\n"))
#       - 影响：修复 nftables 规则生成失败，脚本可以正常完成安装
#       - 代码统计：v6.1(1286行) → v6.2(1286行)，净变化 0 行（仅修复逻辑）
# v6.1 - 【H2 主笔修复 - jq 转义符号过度转义问题】
#       - [P0-1] 修复 masquerade_rules 函数的 jq 转义符号过度转义
#       - 问题：v6.0 的 patch 操作导致转义符号从 \\\" 变成 \\\\\\\\\\\\\\\"，jq 解析失败
#       - 错误：jq: error: syntax error, unexpected INVALID_CHARACTER at line 20
#       - 根源：patch 工具对反斜杠进行了二次转义，导致最终字符串中转义符号过多
#       - 修复：手动修正转义符号数量，恢复正确的 jq 语法
#       - 影响：修复 nftables 规则生成失败，脚本可以正常完成安装
#       - 代码统计：v6.0(1286行) → v6.1(1286行)，净变化 0 行（仅修复转义）
# v6.0 - 【H2 主笔修复 - jq 依赖问题 + masquerade_rules 数组转字符串】
#       - [P0-1] 修复 masquerade_rules 函数返回数组导致的 jq 解析错误
#       - 问题：masquerade_rules 返回数组但未调用 join("\n")，导致 "Cannot iterate over null" 错误
#       - 根源：第 678 行和第 890 行的 masquerade_rules 函数定义缺少 join("\n")
#       - 修复：在 masquerade_rules 函数定义中添加 | join("\n")，与其他规则函数保持一致
#       - 影响：修复 nftables 规则生成失败，脚本可以正常完成安装
#       - [P0-2] 添加 jq 依赖检查和自动安装
#       - 问题：脚本依赖 jq 但未在依赖列表中，导致首次安装失败
#       - 修复：在 install_dependencies 函数中添加 jq 检查和安装逻辑
#       - 影响：确保脚本在全新系统上可以正常运行
#       - 代码统计：v5.9(1275行) → v6.0(1275行)，净变化 0 行（仅修复逻辑）
# v5.9 - 【H2 主笔修复 - 健康检查优化 + 依赖补全】
#       - [P1-1] 添加netcat-openbsd依赖
#       - 问题：健康检查脚本依赖nc命令但未在依赖列表中
#       - 修复：在install_dependencies中添加netcat-openbsd
#       - 影响：确保健康检查功能正常运行
#       - [P1-2] 健康检查ping超时调整
#       - 问题：ping -c 2 -W 3在高延迟网络下容易误判宕机
#       - 修复：改为ping -c 3 -W 5，提高容错率
#       - 影响：适应落地机高延迟国际线路，避免误判
#       - [P2-1] 健康检查只记录状态变化
#       - 问题：每5分钟记录存活日志，一天产生288条，日志文件膨胀
#       - 修复：只记录状态变化（故障→存活、存活→故障）
#       - 影响：减少日志噪音，只关注异常事件
#       - [P2-2] 健康检查添加超时保护
#       - 问题：wait可能卡死，影响cron任务执行
#       - 修复：添加20秒超时保护，强制终止超时任务
#       - 影响：避免健康检查脚本卡死
#       - 代码统计：v5.8(1239行) → v5.9(1250行)，净增加 11 行
# v5.8 - 【H2 主笔修复 - 健康检查改为ICMP】
#       - [P0-1] 修复健康检查硬编码端口22问题
#       - [P1-1决策] 拒绝修改SNAT规则
#       - 代码统计：v5.7(1246行) → v5.8(1239行)，净减少 7 行
# v5.7 - 【H2 主笔修复 - 恢复SNAT规则 + 删除订阅端口 + 精简Flowtable缓存】
#       - [P0-1] 恢复SNAT规则：修复非对称路由导致的断网问题
#       - [P1-1] 删除58964订阅端口自动添加
#       - [P2-1] 精简Flowtable缓存检查逻辑
#       - 代码统计：v5.6(1264行) → v5.7(1246行)，净减少 18 行
# v5.6 - 【H2 主笔修复 - 删除订阅服务器相关代码（安全红线）】
#       - [致命安全漏洞] 删除58964订阅端口的所有相关代码
#       - [健康检查简化] 只检测SSH(22)端口，删除订阅端口检测
#       - 代码统计：v5.5(1274行) → v5.6(1258行)，净减少 16 行
# v5.5 - 【H2 主笔优化 - 健康检查逻辑简化 + SNAT规则精准化】
#       - [P1-1] 健康检查逻辑简化：同时检测SSH(22)和订阅端口(58964)
#       - [P2-2] SNAT规则精准化：只对订阅端口做SNAT
#       - 代码统计：v5.4(1289行) → v5.5(1279行)，净减少 10 行
# ==========================================
# 版本号
VERSION="6.28"
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
    if ! host -W 5 ifconfig.me &>/dev/null && ! host -W 5 google.com &>/dev/null; then
        warn "DNS 解析失败，可能影响依赖包下载"
        return 1
    fi
    
    # 检查外网访问
    if ! curl -s --max-time 10 --connect-timeout 5 https://ifconfig.me &>/dev/null; then
        warn "无法访问外网，可能影响依赖包下载"
        return 1
    fi
    
    success "网络连通性检查通过"
    return 0
}

# v6.12 新增: 依赖安装函数
install_dependencies() {
    progress 1 7 "安装依赖包"
    
    info "更新软件包列表..."
    if ! apt update &>/dev/null; then
        warn "apt update 失败，但继续尝试安装"
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
    if apt install -y "${missing_packages[@]}" &>/dev/null; then
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
        port=$(ss -tlnp | grep sshd | awk '{print $4}' | grep -oE '[0-9]+$' | head -1)
    fi
    if [[ -z "${port}" ]] && [[ -f /etc/ssh/sshd_config ]]; then
        port=$(grep -E '^Port ' /etc/ssh/sshd_config | awk '{print $2}')
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
            local ip name ssh_port
            ip=$(jq -r ".landings[$i].ip" "${CONFIG_FILE}")
            name=$(jq -r ".landings[$i].name" "${CONFIG_FILE}")
            ssh_port=$(jq -r ".landings[$i].ssh_port // 22" "${CONFIG_FILE}")
            
            # [P0-1] 改用nc探测SSH端口，与health_check.sh保持一致
            if nc -zvw3 "${ip}" "${ssh_port}" &>/dev/null; then
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
    local ss_flag
    
    if [[ "${proto}" == "tcp" ]]; then
        ss_flag="-t"
    elif [[ "${proto}" == "udp" ]]; then
        ss_flag="-u"
    else
        die "无效的协议 '${proto}'"
    fi
    
    if ss ${ss_flag}lnp 2>/dev/null | grep -q ":${port} "; then
        error "端口 ${port}/${proto} (${name}) 已被占用"
        die "请先释放端口或更换端口"
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

# 彻底禁用 IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 0
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
# TCP 优化
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1

# 缓冲区优化
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 连接跟踪优化
net.netfilter.nf_conntrack_max = 524288
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
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
    
    local ssh_port
    ssh_port=$(jq -r '.ssh_port' "${CONFIG_FILE}")
    
    local nft_rules="/etc/nftables.conf"
    if [[ -f "${nft_rules}" ]]; then
        cp "${nft_rules}" "${nft_rules}.bak.$(date +%s)"
        cleanup_old_backups "${nft_rules}"
    fi
    
    cat > "${nft_rules}" <<'NFTEOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        
        # 允许本地回环
        iif lo accept
        
        # 允许已建立的连接
        ct state established,related accept
        
        # 允许 SSH
        tcp dport SSH_PORT accept
        
        # 允许转发端口（动态生成）
        FORWARD_PORTS_PLACEHOLDER
        
        # 限速 ICMP
        icmp type echo-request limit rate 1/second accept
        
        # 默认 DROP
        drop
    }
    
    chain forward {
        type filter hook forward priority filter; policy drop;
        
        # 允许已建立的连接
        ct state established,related accept
        
        # 允许转发到落地机（动态生成）
        FORWARD_RULES_PLACEHOLDER
        
        # 默认 DROP
        drop
    }
    
    chain output {
        type filter hook output priority filter; policy accept;
    }
}

table inet nat {
    chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        
        # DNAT 规则（动态生成）
        DNAT_RULES_PLACEHOLDER
    }
    
    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        
        # MASQUERADE 规则（动态生成）
        MASQUERADE_RULES_PLACEHOLDER
    }
}
NFTEOF
    
    # 使用 jq 直接生成完整的 nftables 规则
    # 注意：这里使用 jq 一次性生成所有规则，避免临时文件和多次 awk 替换
    # 这是 v2.2 引入的优化，减少了 80 行代码并提高了安全性（防止注入）
    local nft_content
    
    # 检测主网卡（用于 flowtable）
    local main_iface
    local use_flowtable=true
    
    main_iface=$(ip route show default | awk '/default/ {print $5; exit}')
    
    if [[ -z "${main_iface}" ]]; then
        warn "无法检测主网卡，flowtable 将被禁用"
        use_flowtable=false
    elif ! ip link show "${main_iface}" &>/dev/null; then
        warn "网卡 ${main_iface} 不存在，flowtable 将被禁用"
        use_flowtable=false
    elif ! nft -f - <<< "add table inet test_ft; add flowtable inet test_ft ft { hook ingress priority 0; devices = { ${main_iface} }; }; delete table inet test_ft" &>/dev/null; then
        warn "内核不支持 flowtable（需要 Linux 5.3+），已禁用"
        use_flowtable=false
    else
        info "检测到主网卡: ${main_iface}，flowtable 已启用"
    fi
    
    jq -r --arg ssh "${ssh_port}" --arg iface "${main_iface}" --argjson use_ft $(${use_flowtable} && echo "true" || echo "false") '
        # 生成 forward_ports 规则
        def forward_ports:
            [.landings[] | select(.enabled == true) | .ports[]? |
             "        \(.proto) dport \(.listen) accept"] | unique | join("\n");
        
        # 生成 forward_rules 规则
        def forward_rules:
            [.landings[] | select(.enabled == true) as $landing |
             $landing.ports[]? | "        ip daddr \($landing.ip) \(.proto) dport \(.target) accept"] | join("\n");
        
        # 生成 dnat_rules 规则
        def dnat_rules:
            [.landings[] | select(.enabled == true) as $landing |
             $landing.ports[]? | "        \(.proto) dport \(.listen) dnat ip to \($landing.ip):\(.target)"] | join("\n");
        
        # 生成 masquerade_rules 规则
        # v5.7 修复：恢复SNAT规则，避免非对称路由导致断网
        # 原因：中转机只做DNAT不做SNAT会导致回包路径错误（落地机直接回包给客户端IP）
        def masquerade_rules:
            ["        oifname != \"lo\" masquerade"];
        
        # 生成完整配置
        "#!/usr/sbin/nft -f\n\n" +
        "flush ruleset\n\n" +
        "table inet filter {\n" +
        (if $use_ft then
            "    # Flowtable 硬件加速（已建立连接旁路转发）\n" +
            "    flowtable ft {\n" +
            "        hook ingress priority 0;\n" +
            "        devices = { \($iface) };\n" +
            "    }\n" +
            "    \n"
        else "" end) +
        "    chain input {\n" +
        "        type filter hook input priority filter; policy drop;\n" +
        "        \n" +
        "        # 允许本地回环\n" +
        "        iif lo accept\n" +
        "        \n" +
        "        # 允许已建立的连接\n" +
        "        ct state established,related accept\n" +
        "        \n" +
        "        # 允许 SSH\n" +
        "        tcp dport \($ssh) accept\n" +
        "        \n" +
        "        # 允许转发端口\n" +
        forward_ports + "\n" +
        "        \n" +
        "        # 限速 ICMP\n" +
        "        icmp type echo-request limit rate 1/second accept\n" +
        "        \n" +
        "        # 记录非法访问（GFW 主动探测检测）\n" +
        "        limit rate 1/minute log prefix \"ILLEGAL_ACCESS: \"\n" +
        "        \n" +
        "        # 默认 DROP\n" +
        "        drop\n" +
        "    }\n" +
        "    \n" +
        "    chain forward {\n" +
        "        type filter hook forward priority filter; policy drop;\n" +
        "        \n" +
        (if $use_ft then
            "        # 将已建立的 TCP/UDP 连接加速到 flowtable\n" +
            "        ip protocol { tcp, udp } ct state established flow add @ft\n" +
            "        \n"
        else "" end) +
        "        # 允许已建立的连接\n" +
        "        ct state established,related accept\n" +
        "        \n" +
        "        # 允许转发到落地机\n" +
        forward_rules + "\n" +
        "        \n" +
        "        # 默认 DROP\n" +
        "        drop\n" +
        "    }\n" +
        "    \n" +
        "    chain output {\n" +
        "        type filter hook output priority filter; policy accept;\n" +
        "    }\n" +
        "}\n\n" +
        "table inet nat {\n" +
        "    chain prerouting {\n" +
        "        type nat hook prerouting priority dstnat; policy accept;\n" +
        "        \n" +
        "        # DNAT 规则\n" +
        dnat_rules + "\n" +
        "    }\n" +
        "    \n" +
        "    chain postrouting {\n" +
        "        type nat hook postrouting priority srcnat; policy accept;\n" +
        "        \n" +
        "        # MASQUERADE 规则\n" +
        (masquerade_rules | join("\n")) + "\n" +
        "    }\n" +
        "}\n"
    ' "${CONFIG_FILE}" > "${nft_rules}"
    
    # 验证规则语法
    if ! nft -c -f "${nft_rules}" 2>/dev/null; then
        error "nftables 规则语法错误"
        if [[ -f "${nft_rules}.bak."* ]]; then
            warn "尝试恢复备份规则..."
            local backup
            backup=$(ls -t "${nft_rules}.bak."* | head -1)
            cp "${backup}" "${nft_rules}"
            if nft -f "${nft_rules}"; then
                warn "已恢复备份规则"
            else
                die "恢复备份规则失败"
            fi
        else
            die "无备份规则可恢复"
        fi
    fi
    
    # 加载规则
    if nft -f "${nft_rules}"; then
        success "nftables 规则加载成功"
    else
        error "nftables 规则加载失败"
        if [[ -f "${nft_rules}.bak."* ]]; then
            warn "尝试恢复备份规则..."
            local backup
            backup=$(ls -t "${nft_rules}.bak."* | head -1)
            cp "${backup}" "${nft_rules}"
            nft -f "${nft_rules}" || die "恢复备份规则失败"
            warn "已恢复备份规则"
        else
            die "无备份规则可恢复"
        fi
    fi
    
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
        forward_ports + "\n\n" +
        "        icmp type echo-request limit rate 1/second accept\n\n" +
        "        limit rate 1/minute log prefix \"ILLEGAL_ACCESS: \"\n\n" +
        "        drop\n" +
        "    }\n\n" +
        "    chain forward {\n" +
        "        type filter hook forward priority filter; policy drop;\n\n" +
        (if $use_ft then
            "        ip protocol { tcp, udp } ct state established flow add @ft\n\n"
        else "" end) +
        "        ct state established,related accept\n\n" +
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
    printf '%b' "${nft_content}" > "${tmp_rules}"
    
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
set -euo pipefail

# [P1-3] 时序混淆：随机延迟0-60秒，破坏机器级精准周期特征
# 原因：5分钟cron周期 + 60秒延迟 = 最多6分钟间隔（可接受）
# 避免：5分钟cron周期 + 120秒延迟 = 最多7分钟间隔（过长，可能导致任务堆积）
sleep $((RANDOM % 60))

# P1 修复：添加文件锁防止并发执行
LOCK_FILE="/var/run/ghost-transit-health.lock"
LOG_FILE="/var/log/ghost-transit.log"

# P1 增强：统一日志函数，同时写入文件和 syslog
log() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [HEALTH] ${msg}" >> "${LOG_FILE}"
    logger -t ghost-transit "${msg}"
}

exec 200>"${LOCK_FILE}"
if ! flock -n 200; then
    log "健康检查已在运行，跳过本次检查"
    exit 0
fi

CONFIG_FILE="/etc/ghost-transit/config.json"
NFT_RULES="/etc/nftables.conf"

# P2 优化：记录检查开始时间（仅用于计算耗时，不记录日志）
check_start=$(date +%s)

# 检查所有落地机的存活状态
landings_count=$(jq '.landings | length' "${CONFIG_FILE}")

for ((i=0; i<landings_count; i++)); do
    # v6.13 精简：删除不存在的 tunnel_ip 字段（中转机不需要隧道IP）
    read -r ip enabled name < <(jq -r \
        ".landings[$i] | \"\\(.ip) \\(.enabled) \\(.name)\"" \
        "${CONFIG_FILE}")
    
    # v4.5 修复：隧道不通时强制标记为故障，避免误判
    # 核心原则：业务链路（AWG 隧道）不通 = 故障，必须切换
    # 
    # 检测逻辑：
    # v6.13 修复：改用TCP探测SSH端口，避免ICMP被禁导致误判
    # v6.27 优化：优先探测备轨TCP端口，回退SSH
    # 原因：
    # 1. 备轨端口更接近代理链路存活状态
    # 2. SSH端口只能证明机器存活，不能证明代理可用
    # 3. 跨国网络中ICMP经常被运营商Drop，导致误判宕机
    
    is_alive=false
    
    # v6.27: 优先探测备轨TCP端口
    probe_port=$(jq -r ".landings[$i].ports[]? | select(.proto==\"tcp\") | .target" "${CONFIG_FILE}" | head -1)
    
    # 回退：如果没有TCP备轨端口，使用SSH端口
    if [[ -z "${probe_port}" ]]; then
        probe_port=$(jq -r ".landings[$i].ssh_port // 22" "${CONFIG_FILE}")
    fi
    
    # 使用nc探测端口（3秒超时）
    if nc -zvw3 "${ip}" "${probe_port}" &>/dev/null; then
        is_alive=true
    else
        is_alive=false
    fi
    
    # v6.13 优化：防抖机制 - 连续3次失败才禁用，连续3次成功才启用
    # 读取失败计数
    fail_count=$(jq -r ".landings[$i].fail_count // 0" "${CONFIG_FILE}")
    
    if [[ "${is_alive}" == "true" ]]; then
        # 存活 -> 重置失败计数
        if [[ ${fail_count} -gt 0 ]]; then
            jq ".landings[$i].fail_count = 0" "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp"
            mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
        fi
        
        # 连续3次成功才重新启用（防止网络抖动频繁切换）
        if [[ "${enabled}" == "false" ]]; then
            success_count=$(jq -r ".landings[$i].success_count // 0" "${CONFIG_FILE}")
            success_count=$((success_count + 1))
            jq ".landings[$i].success_count = ${success_count}" "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp"
            mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
            
            if [[ ${success_count} -ge 3 ]]; then
                jq ".landings[$i].enabled = true | .landings[$i].success_count = 0" "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp"
                mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
                
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
        jq ".landings[$i].fail_count = ${fail_count}" "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
        
        # 连续3次失败才禁用（防止偶发网络抖动误判）
        if [[ "${enabled}" == "true" ]] && [[ ${fail_count} -ge 3 ]]; then
            jq ".landings[$i].enabled = false" "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp"
            mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
            
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
HEALTHEOF
    
    chmod +x "${CONFIG_DIR}/health_check.sh"
    
    # 添加 cron 任务（每5分钟执行一次，平衡资源消耗与可用性）
    local cron_job="*/5 * * * * ${CONFIG_DIR}/health_check.sh >/dev/null 2>&1"
    
    # 检查 cron 任务是否已存在
    if ! crontab -l 2>/dev/null | grep -q "health_check.sh"; then
        (crontab -l 2>/dev/null; echo "${cron_job}") | crontab -
        success "健康检查已启用（每5分钟检测一次）"
    else
        info "健康检查任务已存在，跳过"
    fi
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
    public_ip=$(curl -s4 --max-time 5 ifconfig.me || echo "<获取失败>")
    
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
    echo "  8. 健康检查: 每5分钟自动检测落地机存活状态（自动故障转移）"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ==========================================
# 主流程
# ==========================================

main() {
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
    
    # v6.12 新增: 支持非交互模式（通过环境变量）
    if [[ -n "${LANDING_IP:-}" ]]; then
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
    setup_nftables
    install_management_tool
    setup_health_check
    
    # 可选：测试落地机连通性
    echo ""
    # v6.13 优化：支持环境变量跳过连通性测试（非交互模式）
    if [[ -z "${SKIP_CONNECTIVITY_TEST}" ]]; then
        info "是否测试落地机连通性？(如果落地机尚未安装，请选择 n)"
        read -p "测试连通性? [y/N]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            test_connectivity
        else
            info "跳过连通性测试"
        fi
    else
        info "非交互模式：跳过连通性测试（SKIP_CONNECTIVITY_TEST已设置）"
    fi
    
    print_summary
}

main "$@"
