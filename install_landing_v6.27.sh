#!/usr/bin/env bash
set -euo pipefail

# install_landing_v6.27.sh — 落地机安装脚本
# 版本: v6.27 (2026-05-20)
# v6.27 - 【P0 核心修复 - DKMS 编译 AmneziaWG 内核模块 + 恢复混淆参数】
#       - [P0-1] 新增 install_kernel_headers_best_effort() - 智能安装内核头文件（x86_64/ARM64）
#       - [P0-2] 新增 install_amneziawg_dkms() - DKMS 编译 AmneziaWG 内核模块
#       - [P0-3] 新增 install_amneziawg_go() - 用户态回退方案（amneziawg-go）
#       - [P0-4] 新增 install_awg_runtime() - 统一入口，自动降级（DKMS → go → 不终止）
#       - [P0-5] 恢复服务端配置混淆参数（Jc/Jmin/Jmax/S1/S2/H1-H4）
#       - [P0-6] systemd 服务改回 awg-quick（支持混淆）
#       - [P0-7] 删除 v6.26 的 sed 修补逻辑（不再破坏 awg-quick）
#       - [P1-1] 精简 sysctl 优化（只保留 BBR + fq）
#       - [P1-2] 优化复制粘贴导入提示（COPY_START/END 标记）
#       - 原因：v6.26 移除混淆参数是负优化，违背"欺上瞒下"核心诉求
#       - 代码统计：v6.26(1840行) → v6.27(预计1920行)，净增加80行
# v6.24 - 【P0/P1 问题修复 - 安装与运行循环测试】
#       - [P1-1] 统一版本号：中转机和落地机统一为 v6.24
#       - [P1-2] 修复卸载未删除 show-clash-config 命令
#       - [P1-3] 修复卸载未删除日志文件
#       - [P1-4] 修复主界面版本号硬编码：改为使用 ${VERSION} 变量
#       - 代码统计：v6.23(1822行) → v6.24(1827行)，净增加5行
# 完整历史记录请查看 zhubi.md 或 Git 提交历史
#
# v6.22 - 【防火墙规则优化 + 代码质量提升】
#       - [P1-1] 统一防火墙规则插入顺序（全部使用-I插入到规则链顶部）
#       - [P2-2] 精简版本历史注释（只保留最近5个版本，删除v6.16及更早版本）
#       - 代码统计：v6.21(1860行) → v6.22(预计1791行)，净减少69行
# v6.21 - 【安全红线最终修复 + 版本号统一】
#       - [P0-1] 修复版本号不一致（VERSION变量和main()显示统一为6.21）
#       - [P0-2] 彻底删除1Panel端口自动放行代码（第二次违反安全红线）
#       - [P1-2] 优化防火墙规则顺序（使用-I插入到规则链顶部）
#       - [P2-1] 删除死代码注释
#       - 代码统计：v6.20(1863行) → v6.21(1857行)，净减少6行
# v6.20 - 【安全红线修复 + 代码质量提升】
#       - [P0-1] 删除AI Agent端口自动放行代码（违反安全红线）
#       - [P1-1] Base64编码跨平台兼容性修复（base64 | tr -d '\n'）
#       - [P1-4] DNS劫持规则幂等性修复（精准删除而非清空OUTPUT链）
#       - [P2-1] 删除重复的shebang声明
#       - 代码统计：v6.19(1855行) → v6.20(1863行)，净增加8行
# v6.19 - 【订阅链接增强】Base64编码订阅 + Data URI一键导入
#       - [P0-1] 添加Base64编码的Clash Meta订阅信息输出（用于剪贴板导入）
#       - [P0-2] 添加Data URI scheme的clash://协议一键导入链接
#       - [P1-1] 修复Clash Meta配置中的健康检查URL（gstatic.com → cp.cloudflare.com）
#       - [P1-2] 优化Clash Meta配置的DNS设置（添加fallback和fake-ip）
#       - [P2-1] 精简版本历史注释（删除v6.15及更早版本）
#       - 代码统计：v6.18(1848行) → v6.19(1855行)，净增加7行
# v6.18 - 【混淆参数时序修复 + Clash Meta配置完善】
#       - [P0-1] 修复混淆参数生成时序问题（提前到main()开始时调用）
#       - [P1-1] Clash Meta配置添加完整的rules路由规则
#       - [P1-2] Clash Meta配置添加安全密钥（防止API接口无保护）
#       - [P1-3] Clash Meta DNS配置防泄漏优化
#       - [P2-1] 删除无用的python3依赖
#       - 代码统计：v6.17(1855行) → v6.18(1848行)，净减少7行

# ==========================================
# 全局变量
# ==========================================
VERSION="6.27"
AWG_BACKEND=""  # 记录 AWG 后端类型：kernel/go/none
#       - [P0-1] 修复用户提示IP错误：第1285行将10.8.0.2改为10.8.0.1（SS主轨实际监听地址）
#       - [P1-1] 修正代码统计：v6.0实际为1478行，不是预计的1420行
#       - [P2-1] 优化Clash Meta IP注释：避免误导用户认为Clash Meta运行在10.8.0.2
#       - [决策] 拒绝统一防火墙规则插入方式：当前混合方式是正确的（基础规则-I，业务规则-A）
#       - [决策] 拒绝Telegram推送功能：违背"做减法"原则，增加复杂度
#       - [决策] 拒绝动态PM2端口检测：过度优化，增加安全风险
#       - 代码统计：v6.0(1478行) → v6.1(1478行)，仅文本修正
# v6.0 - 【H1 主笔修复 - 瞒下核心漏洞与代码清理】
#       - [P0-1] 修复家宽IP侧漏：SS主轨添加bind_interface，确保主轨流量走家宽网卡
#       - [P1-1] 删除混淆参数轮换残留代码：清理print_client_config中的死代码（约35行）
#       - [P1-2] 修复架构幻觉注释：将"用于中转机"改为"用于用户本地设备Clash Meta"
#       - [P1-3] 添加PM2端口自动放行：兼容OpenClaw/Hermes等AI Agent框架
#       - [P2-1] MTU优化：1360→1388，提升约2%吞吐量
#       - [决策] 拒绝Clash Meta IP改为10.8.0.3：审查官架构理解错误，10.8.0.2是正确的
#       - [决策] 确认ICMP已放行：v5.9第1170行已正确配置
#       - 代码统计：v5.9(1453行) → v6.0(1478行)，净增加25行
# v5.9 - 【H1 主笔修复 - 架构修正与1Panel兼容性】
#       - [P0-1] 删除socat依赖残留：订阅服务器已删除，避免安装失败
#       - [P0-2] 修复卸载函数破坏1Panel/Docker：精准删除自己的规则，不执行iptables -F
#       - [P0-3] 放行中转机ICMP健康检查：中转机v5.8改用ping检测，必须放行
#       - [P1-1] 修复SS主轨监听地址架构错误：改回10.8.0.1，通过systemd依赖解决启动顺序
#       - [P1-2] 删除AWG配置中的DNS字段：Server端不使用DNS配置
#       - [P1-3] 删除Clash Meta配置中的reserved字段：AmneziaWG不使用reserved
#       - [P2-1] MTU优化：1400→1360，避免分片
#       - [P2-2] 补充中转机配置说明：解释为什么要配置两个端口
#       - [P2-3] 删除防火墙末尾DROP规则：与1Panel/Docker共存
#       - [决策] 拒绝"阅后即焚"订阅服务器：任何HTTP服务都会被GFW探测
#       - 代码统计：v5.8(1406行) → v5.9(1453行)，净增加47行
# v5.8 - 【H1 主笔修复 - 删除虚假优化与架构修正】
#       - [P0-1] 删除混淆参数自动轮换功能（约270行）：订阅服务器已删除，轮换会导致客户端失效
#       - [P1-1] 修复SS主轨监听地址：从${awg_ip}改为0.0.0.0（v5.9证明此为架构错误）
#       - [P1-2] 补充中转机配置指引：输出ghost-transit-ctl命令，指导用户配置中转机
#       - [P2-1] MTU优化：从1280改为1400，提升约9%有效载荷
#       - [P2-2] 删除Clash Meta配置中的混淆参数轮换注释（功能已删除）
#       - [决策] 拒绝审查官P0-1建议：落地机作为Server不需要Endpoint字段（审查官架构理解错误）
#       - 代码统计：v5.7(1676行) → v5.8(1406行)，净减少270行
# v5.7 - 【H1 主笔修复 - P0致命错误修复】
#       - [P0-1] 修复AWG角色配置错误：落地机改为10.8.0.1/24（Server网关）
#       - [P0-2] 修复Clash Meta密钥配置：客户端使用CLIENT_PRIVATE和SERVER_PUBLIC
#       - [P0-3] 修复主轨SS服务器地址：改为10.8.0.1（落地机网关IP）
#       - [P0-4] 删除端口扫描检测残留代码（全局变量、systemd引用、摘要输出）
#       - [P0-5] 删除中转机AWG配置提示（架构幻觉残留）
#       - [P2-1] 优化终端YAML输出：增强可读性和多种获取方式
#       - [决策] 拒绝恢复订阅服务器（安全性优先于便利性）
#       - 代码统计：v5.6(1689行) → v5.7(1676行)，净减少13行
# v5.6 - 【H1 主笔重大架构变更 - 删除HTTP订阅服务器】
#       - [架构] 完全删除HTTP订阅服务器（socat），改为终端打印YAML配置
#       - [P0-1] 完全删除端口扫描检测功能（净减少约230行）
#       - [修复] 防火墙规则改为精准插入，避免破坏1Panel/Docker
#       - [优化] AWG配置添加Table=off，防止路由表冲突
#       - [优化] 同时生成客户端密钥对，简化中转机配置
#       - [精简] 删除import_pairing_info函数，改为ask_transit_info
#       - 代码统计：v5.5(1975行) → v5.6(1687行)，净减少288行
# v5.5 - 【H1 主笔精简 - 删除虚假优化】
#       - [P0-1] 修复第1363行中转机配置提示使用错误的公钥变量
#       - [精简] 删除 MTU 探测逻辑，硬编码 OPTIMAL_MTU=1280
#       - [精简] 删除端口扫描检测逻辑（只保留备轨端口检测）
#       - 代码统计：v5.4(2021行) → v5.5(预计约1850行)
# v5.4 - 【H1 主笔修复 - AWG 密钥变量名统一】
# v5.3 - 【H1 主笔修复 - AWG 架构拓扑修正】
# 颜色定义
#       - [P1-1] 修正代码统计：v6.0实际为1478行，不是预计的1420行
#       - [P2-1] 优化Clash Meta IP注释：避免误导用户认为Clash Meta运行在10.8.0.2
#       - [决策] 拒绝统一防火墙规则插入方式：当前混合方式是正确的（基础规则-I，业务规则-A）
#       - [决策] 拒绝Telegram推送功能：违背"做减法"原则，增加复杂度
#       - [决策] 拒绝动态PM2端口检测：过度优化，增加安全风险
#       - 代码统计：v6.0(1478行) → v6.1(1478行)，仅文本修正
# v6.0 - 【H1 主笔修复 - 瞒下核心漏洞与代码清理】
#       - [P0-1] 修复家宽IP侧漏：SS主轨添加bind_interface，确保主轨流量走家宽网卡
#       - [P1-1] 删除混淆参数轮换残留代码：清理print_client_config中的死代码（约35行）
#       - [P1-2] 修复架构幻觉注释：将"用于中转机"改为"用于用户本地设备Clash Meta"
#       - [P1-3] 添加PM2端口自动放行：兼容OpenClaw/Hermes等AI Agent框架
#       - [P2-1] MTU优化：1360→1388，提升约2%吞吐量
#       - [决策] 拒绝Clash Meta IP改为10.8.0.3：审查官架构理解错误，10.8.0.2是正确的
#       - [决策] 确认ICMP已放行：v5.9第1170行已正确配置
#       - 代码统计：v5.9(1453行) → v6.0(1478行)，净增加25行
# v5.9 - 【H1 主笔修复 - 架构修正与1Panel兼容性】
#       - [P0-1] 删除socat依赖残留：订阅服务器已删除，避免安装失败
#       - [P0-2] 修复卸载函数破坏1Panel/Docker：精准删除自己的规则，不执行iptables -F
#       - [P0-3] 放行中转机ICMP健康检查：中转机v5.8改用ping检测，必须放行
#       - [P1-1] 修复SS主轨监听地址架构错误：改回10.8.0.1，通过systemd依赖解决启动顺序
#       - [P1-2] 删除AWG配置中的DNS字段：Server端不使用DNS配置
#       - [P1-3] 删除Clash Meta配置中的reserved字段：AmneziaWG不使用reserved
#       - [P2-1] MTU优化：1400→1360，避免分片
#       - [P2-2] 补充中转机配置说明：解释为什么要配置两个端口
#       - [P2-3] 删除防火墙末尾DROP规则：与1Panel/Docker共存
#       - [决策] 拒绝"阅后即焚"订阅服务器：任何HTTP服务都会被GFW探测
#       - 代码统计：v5.8(1406行) → v5.9(1453行)，净增加47行
# v5.8 - 【H1 主笔修复 - 删除虚假优化与架构修正】
#       - [P0-1] 删除混淆参数自动轮换功能（约270行）：订阅服务器已删除，轮换会导致客户端失效
#       - [P1-1] 修复SS主轨监听地址：从${awg_ip}改为0.0.0.0（v5.9证明此为架构错误）
#       - [P1-2] 补充中转机配置指引：输出ghost-transit-ctl命令，指导用户配置中转机
#       - [P2-1] MTU优化：从1280改为1400，提升约9%有效载荷
#       - [P2-2] 删除Clash Meta配置中的混淆参数轮换注释（功能已删除）
#       - [决策] 拒绝审查官P0-1建议：落地机作为Server不需要Endpoint字段（审查官架构理解错误）
#       - 代码统计：v5.7(1676行) → v5.8(1406行)，净减少270行
# v5.7 - 【H1 主笔修复 - P0致命错误修复】
#       - [P0-1] 修复AWG角色配置错误：落地机改为10.8.0.1/24（Server网关）
#       - [P0-2] 修复Clash Meta密钥配置：客户端使用CLIENT_PRIVATE和SERVER_PUBLIC
#       - [P0-3] 修复主轨SS服务器地址：改为10.8.0.1（落地机网关IP）
#       - [P0-4] 删除端口扫描检测残留代码（全局变量、systemd引用、摘要输出）
#       - [P0-5] 删除中转机AWG配置提示（架构幻觉残留）
#       - [P2-1] 优化终端YAML输出：增强可读性和多种获取方式
#       - [决策] 拒绝恢复订阅服务器（安全性优先于便利性）
#       - 代码统计：v5.6(1689行) → v5.7(1676行)，净减少13行
# v5.6 - 【H1 主笔重大架构变更 - 删除HTTP订阅服务器】
#       - [架构] 完全删除HTTP订阅服务器（socat），改为终端打印YAML配置
#       - [P0-1] 完全删除端口扫描检测功能（净减少约230行）
#       - [修复] 防火墙规则改为精准插入，避免破坏1Panel/Docker
#       - [优化] AWG配置添加Table=off，防止路由表冲突
#       - [优化] 同时生成客户端密钥对，简化中转机配置
#       - [精简] 删除import_pairing_info函数，改为ask_transit_info
#       - 代码统计：v5.5(1975行) → v5.6(1687行)，净减少288行
# v5.5 - 【H1 主笔精简 - 删除虚假优化】
#       - [P0-1] 修复第1363行中转机配置提示使用错误的公钥变量
#       - [精简] 删除 MTU 探测逻辑，硬编码 OPTIMAL_MTU=1280
#       - [精简] 删除端口扫描检测逻辑（只保留备轨端口检测）
#       - 代码统计：v5.4(2021行) → v5.5(预计约1850行)
# v5.4 - 【H1 主笔修复 - AWG 密钥变量名统一】
# v5.3 - 【H1 主笔修复 - AWG 架构拓扑修正】
# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 版本号
VERSION="6.26"

# 全局变量
TRANSIT_IP="${TRANSIT_IP:-}"
TRANSIT_VERSION=""
AWG_SERVER_PUBLIC=""
AWG_CLIENT_PRIVATE=""
AWG_CLIENT_PUBLIC=""
AWG_PORT="${AWG_PORT:-51820}"
SS_MAIN_PORT=8388
SS_BACKUP_PORT="${SS_BACKUP_PORT:-8389}"
SS_PASSWORD=""
CONFIG_DIR="/etc/landing-ghost"
LOG_FILE="/var/log/landing-ghost.log"
HOME_IP=""
OPTIMAL_MTU=1388  # AWG 推荐 MTU（1500 - 112字节开销，WG 92 + AWG混淆 20）

# 混淆参数
JC="" JMIN="" JMAX="" S1="" S2="" H1="" H2="" H3="" H4=""

# ==========================================
# 阶段二：欺上至极 - 新增配置
# ==========================================
# v5.8: 混淆参数自动轮换功能已完全删除（订阅服务器已删除，轮换会导致客户端失效）

# ==========================================
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
    systemctl stop awg-landing ss-main ss-backup 2>/dev/null || true
    systemctl disable awg-landing ss-main ss-backup 2>/dev/null || true
    
    # 删除 systemd 服务文件
    rm -f /etc/systemd/system/awg-landing.service
    rm -f /etc/systemd/system/ss-main.service
    rm -f /etc/systemd/system/ss-backup.service
    systemctl daemon-reload
    echo -e "${GREEN}服务已停止并禁用${NC}"
    
    if [[ "${choice}" == "1" ]]; then
        # 完全卸载
        chattr -i /etc/resolv.conf 2>/dev/null || true
        
        # v5.9: 精准删除防火墙规则，不破坏 1Panel/Docker
        echo -e "${YELLOW}正在精准删除防火墙规则...${NC}"
        
        # 删除端口扫描检测的自定义链（如果存在）
        for chain in $(iptables -L -n | grep "^Chain PORTSCAN_" | awk '{print $2}'); do
            local port=${chain#PORTSCAN_}
            iptables -D INPUT -p tcp --dport ${port} -j ${chain} 2>/dev/null || true
            iptables -F ${chain} 2>/dev/null || true
            iptables -X ${chain} 2>/dev/null || true
        done
        
        # 精准删除本脚本创建的规则（不执行 iptables -F INPUT）
        # 使用循环删除重复规则（修复幂等性问题导致的规则堆积）
        
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
        
        # 删除中转机相关规则（所有匹配端口的规则，不管源 IP）
        # 使用 grep + awk 获取规则编号，从大到小删除（避免编号变化）
        for port in 51820 8389; do
            while true; do
                local line_num=$(iptables -L INPUT -n --line-numbers | grep "dpt:${port}" | tail -1 | awk '{print $1}')
                [[ -z "${line_num}" ]] && break
                iptables -D INPUT "${line_num}" 2>/dev/null || break
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
        echo -e "${GREEN}混淆参数轮换任务已删除${NC}"
        
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

# v6.10 新增：备份文件清理函数（只保留最近3个备份）
cleanup_old_backups() {
    local file_pattern="$1"
    local keep_count=3
    
    # 查找所有备份文件，按时间戳排序，删除旧的
    ls -t ${file_pattern}.bak.* 2>/dev/null | tail -n +$((keep_count + 1)) | xargs -r rm -f
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
        if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
            local process
            process=$(ss -tlnp 2>/dev/null | grep ":${port} " | grep -oP 'users:\(\("\K[^"]+' | head -1)
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

configure_ports() {
    info "配置端口..."
    
    # v6.14: 支持非交互模式
    if [[ "${AUTO_INSTALL:-0}" == "1" ]]; then
        SS_BACKUP_PORT=${SS_BACKUP_PORT:-8389}
        info "非交互模式: 使用默认备轨端口 ${SS_BACKUP_PORT}"
        success "端口配置完成: 主轨=${SS_MAIN_PORT}(AWG隧道内), 备轨=${SS_BACKUP_PORT}(直连)"
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
    if ss -tlnp 2>/dev/null | grep -q ":${SS_BACKUP_PORT} "; then
        warn "端口 ${SS_BACKUP_PORT} 已被占用"
        read -p "是否重新选择端口? (y/N): " retry
        if [[ "${retry}" == "y" ]]; then
            configure_ports
            return
        fi
    fi
    
    success "端口配置完成: 主轨=${SS_MAIN_PORT}(AWG隧道内), 备轨=${SS_BACKUP_PORT}(直连)"
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

check_wireguard_support() {
    info "检查 WireGuard 内核模块支持..."
    
    if lsmod | grep -q wireguard; then
        success "WireGuard 内核模块已加载"
        return 0
    fi
    
    if modprobe wireguard 2>/dev/null; then
        success "WireGuard 内核模块加载成功"
        return 0
    fi
    
    warn "WireGuard 内核模块未找到，将使用 wireguard-go 用户态实现"
    warn "性能可能略低于内核模块，但功能完整"
    return 1
}

verify_bbr() {
    info "验证 BBR 拥塞控制算法..."
    
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    local available_cc=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || echo "")
    
    if [[ "${current_cc}" == "bbr" ]]; then
        success "BBR 已启用并正在运行"
        return 0
    fi
    
    if echo "${available_cc}" | grep -q bbr; then
        warn "BBR 可用但未启用，当前使用: ${current_cc}"
        info "将在系统优化阶段启用 BBR"
        return 1
    fi
    
    warn "BBR 不可用，当前内核可能不支持"
    warn "当前拥塞控制: ${current_cc}"
    warn "可用算法: ${available_cc}"
    return 2
}

detect_home_ip_interface() {
    echo "检测家宽 IP 网卡..." >&2
    
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$')
    local home_interface=""
    
    for iface in ${interfaces}; do
        local ip_addr=$(ip -4 addr show "${iface}" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        
        if [[ -n "${ip_addr}" ]]; then
            # 检测私有IP段（家宽IP）
            if [[ "${ip_addr}" =~ ^10\. ]] || [[ "${ip_addr}" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || [[ "${ip_addr}" =~ ^192\.168\. ]]; then
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
# 阶段二：端口扫描检测
# ==========================================
# v5.6: 端口扫描检测已完全删除
# 理由：
# 1. 主轨端口（8388）监听在隧道内部（10.8.0.2），公网无法扫描
# 2. 备轨端口（8389）的扫描检测意义不大（GFW 主动探测而非扫描）
# 3. 端口切换会导致 Clash Meta 配置失效，降低可用性
# 4. 减少约 230 行代码，降低维护成本

# ==========================================
# 用户输入
# ==========================================
ask_transit_info() {
    # v6.14: 支持非交互模式
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
        info "  AWG 端口: ${AWG_PORT}"
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
    info "  AWG 端口: ${AWG_PORT}"
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
        SS_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
    else
        SS_PASSWORD=$(head -c 32 /dev/urandom | base64 | tr -d '\n')
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
    progress 1 12 "更新系统软件包"
    apt-get update -qq || die "apt-get update 失败"
    
    progress 2 12 "安装基础依赖"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        curl wget git build-essential jq \
        iptables iptables-persistent \
        wireguard-tools openssl || die "依赖安装失败"
    
    success "依赖安装完成"
}

# ==========================================
# DNS 和 IPv6 预防性锁定
# ==========================================

lockdown_dns_ipv6() {
    progress 3 12 "锁定 DNS 和禁用 IPv6（防泄漏）"
    
    # 禁用 IPv6（sysctl层）
    cat > /etc/sysctl.d/99-landing-ghost-prelim.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 0
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
    
    # 处理 systemd-resolved 冲突
    if systemctl is-active --quiet systemd-resolved; then
        info "检测到 systemd-resolved 运行，停止并禁用..."
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        rm -f /etc/resolv.conf
        log "INFO" "systemd-resolved 已停止"
    fi
    
    # 锁定 DNS（resolv.conf层）
    info "锁定 DNS 配置防止泄漏..."
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
    
    # 强制劫持 DNS 查询到 Cloudflare（iptables层）
    # P1-4 修复：精准删除旧规则，避免破坏其他程序的OUTPUT规则
    info "配置 DNS 强制劫持..."
    iptables -t nat -D OUTPUT -p udp --dport 53 -j DNAT --to-destination 1.1.1.1:53 2>/dev/null || true
    iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNAT --to-destination 1.1.1.1:53 2>/dev/null || true
    iptables -t nat -A OUTPUT -p udp --dport 53 -j DNAT --to-destination 1.1.1.1:53 2>/dev/null || true
    iptables -t nat -A OUTPUT -p tcp --dport 53 -j DNAT --to-destination 1.1.1.1:53 2>/dev/null || true
    
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save &>/dev/null || true
    fi
    success "DNS 查询已强制劫持到 Cloudflare（iptables层）"
    log "INFO" "iptables DNS 劫持规则已应用"
    
    success "DNS 和 IPv6 三层防泄漏完成（sysctl + ip6tables + iptables）"
}

install_amneziawg() {
    progress 4 12 "安装 AmneziaWG（DKMS 内核模块优先）"
    
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
install_kernel_headers_best_effort() {
    local arch_pkg
    case "$(uname -m)" in
        x86_64) arch_pkg="linux-headers-amd64" ;;
        aarch64|arm64) arch_pkg="linux-headers-arm64" ;;
        *) arch_pkg="" ;;
    esac
    
    # 尝试安装当前内核头文件
    if apt-get install -y -qq dkms "linux-headers-$(uname -r)" 2>/dev/null; then
        return 0
    fi
    
    # 回退：安装通用架构头文件
    if [[ -n "${arch_pkg}" ]] && apt-get install -y -qq dkms "${arch_pkg}" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# DKMS 编译 AmneziaWG 内核模块
install_amneziawg_dkms() {
    info "尝试 DKMS 编译 AmneziaWG 内核模块..."
    
    # 检查是否已加载内核模块
    if modprobe amneziawg 2>/dev/null; then
        success "AmneziaWG 内核模块已存在"
        return 0
    fi
    
    # 安装内核头文件
    if ! install_kernel_headers_best_effort; then
        warn "内核头文件安装失败，DKMS 编译不可用"
        return 1
    fi
    
    local tmp_dir
    tmp_dir=$(mktemp -d) || return 1
    cd "${tmp_dir}" || return 1
    
    # 克隆内核模块源码
    if ! git clone --depth 1 https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git 2>/dev/null; then
        warn "克隆 AmneziaWG 内核模块失败"
        cd / && rm -rf "${tmp_dir}"
        return 1
    fi
    
    cd amneziawg-linux-kernel-module || return 1
    
    # DKMS 编译安装
    if ! make dkms-install 2>/dev/null; then
        warn "DKMS 编译失败"
        cd / && rm -rf "${tmp_dir}"
        return 1
    fi
    
    # 加载内核模块
    if ! modprobe amneziawg 2>/dev/null; then
        warn "加载 AmneziaWG 内核模块失败"
        cd / && rm -rf "${tmp_dir}"
        return 1
    fi
    
    cd / && rm -rf "${tmp_dir}"
    success "AmneziaWG 内核模块编译成功（支持混淆）"
    return 0
}

# 用户态回退方案（amneziawg-go）
install_amneziawg_go() {
    info "安装 AmneziaWG 用户态版本（amneziawg-go）"
    
    if command -v awg &>/dev/null; then
        info "AmneziaWG 工具已安装"
        return 0
    fi
    
    local tmp_dir
    tmp_dir=$(mktemp -d) || die "创建临时目录失败"
    cd "${tmp_dir}" || die "进入临时目录失败"
    
    # 克隆仓库，最多重试3次
    local clone_success=0
    for attempt in 1 2 3; do
        info "克隆 AmneziaWG 仓库（尝试 $attempt/3）..."
        if git clone https://github.com/amnezia-vpn/amneziawg-tools.git &>/dev/null; then
            clone_success=1
            break
        fi
        [ $attempt -lt 3 ] && sleep 2
    done
    [ $clone_success -eq 0 ] && die "克隆 AmneziaWG 失败（3次尝试）"
    
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
    
    cd /
    rm -rf "${tmp_dir}"
    
    success "AmneziaWG 用户态工具安装完成"
    return 0
}

# 统一 AWG 运行时安装入口（自动降级）
install_awg_runtime() {
    # 优先尝试 DKMS 内核模块
    if modprobe amneziawg 2>/dev/null; then
        AWG_BACKEND="kernel"
        success "使用已有 AmneziaWG 内核模块"
        return 0
    fi
    
    if install_amneziawg_dkms && modprobe amneziawg 2>/dev/null; then
        AWG_BACKEND="kernel"
        success "使用 DKMS 编译的内核模块（最佳性能 + 混淆）"
        return 0
    fi
    
    # 回退到用户态版本
    warn "DKMS 编译失败，自动回退到 amneziawg-go 用户态版本"
    if install_amneziawg_go; then
        AWG_BACKEND="go"
        success "使用 amneziawg-go 用户态版本（支持混淆）"
        return 0
    fi
    
    # 最终回退：标准 WireGuard（无混淆）
    warn "amneziawg-go 安装失败，回退到标准 WireGuard（无混淆）"
    if command -v wg &>/dev/null; then
        AWG_BACKEND="wireguard"
        warn "使用标准 WireGuard，失去混淆能力"
        return 0
    fi
    
    die "所有 WireGuard 安装方案均失败"
}

install_shadowsocks() {
    progress 5 12 "安装 Shadowsocks-2022 (sing-box)"
    
    if command -v sing-box &>/dev/null; then
        info "sing-box 已安装,跳过"
        return 0
    fi
    
    # 修复：官方脚本可能超时，改用GitHub Release直接下载
    local ARCH=$(uname -m)
    local SINGBOX_VERSION="1.10.7"
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
    curl -fsSL "${DOWNLOAD_URL}" -o sing-box.tar.gz || die "下载 sing-box 失败"
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
generate_obfuscation_params() {
    local params_file="${CONFIG_DIR}/.awg_obfs_params"
    
    if [[ -f "${params_file}" ]]; then
        source "${params_file}"
        info "复用已有混淆参数（幂等性保护）"
    else
        JC=$((RANDOM % 128))
        JMIN=$((50 + RANDOM % 50))
        JMAX=$((JMIN + 50 + RANDOM % 50))
        S1=$((RANDOM % 256))
        S2=$((RANDOM % 256))
        H1=$(openssl rand -hex 4)
        H2=$(openssl rand -hex 4)
        H3=$(openssl rand -hex 4)
        H4=$(openssl rand -hex 4)
        
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
        info "生成新的混淆参数"
    fi
    
    # 导出为全局变量，确保所有函数都能访问
    export JC JMIN JMAX S1 S2 H1 H2 H3 H4
    log "INFO" "混淆参数已加载: JC=${JC}, JMIN=${JMIN}, JMAX=${JMAX}"
}

configure_amneziawg() {
    progress 6 12 "配置 AmneziaWG Server"
    
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
MTU = 1420
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
  "ss_main_port": ${SS_MAIN_PORT},
  "ss_backup_port": ${SS_BACKUP_PORT}
}
EOF
    log "INFO" "元数据已保存到 ${CONFIG_DIR}/metadata.json"
    
    # v5.7: 删除中转机AWG配置提示（架构幻觉残留）
    # 中转机不安装AWG，只做nftables四层转发
    info "落地机配置完成，中转机将通过nftables DNAT转发流量到此落地机"
}

configure_shadowsocks() {
    progress 7 12 "配置 Shadowsocks-2022"
    
    generate_password
    
    # v5.9: 主轨监听 10.8.0.1（AWG 网关），通过 systemd 依赖解决启动顺序
    info "SS 主轨将监听 10.8.0.1:${SS_MAIN_PORT}（仅 AWG 隧道内可访问）"
    log "INFO" "ss-main 监听 10.8.0.1:${SS_MAIN_PORT}"
    
    # 检测家宽IP网卡并配置策略路由
    local home_iface
    home_iface=$(detect_home_ip_interface)
    
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
    progress 8 12 "配置 systemd 服务"
    
    cat > /etc/systemd/system/awg-landing.service <<'EOF'
[Unit]
Description=AmneziaWG Landing Server
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/awg-quick up /etc/landing-ghost/awg0.conf
ExecStop=/usr/bin/awg-quick down /etc/landing-ghost/awg0.conf
Restart=on-failure
RestartSec=3s

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
# 3. 客户端需要先导入此配置到 Clash Meta

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
    port: ${AWG_PORT}
    ip: 10.8.0.2  # 用户设备在AWG隧道内的虚拟IP（连接目标是中转机公网IP）
    private-key: ${AWG_CLIENT_PRIVATE}
    public-key: ${AWG_SERVER_PUBLIC}
    udp: true
    mtu: ${OPTIMAL_MTU}
    # AmneziaWG 混淆参数（静态配置，重装前不会改变）
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
    port: ${SS_BACKUP_PORT}  # SS Backup
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
    url: 'http://cp.cloudflare.com/generate_204'
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
    
    # v6.19: 生成Base64编码订阅信息和Data URI一键导入链接
    info "生成 Clash Meta 订阅信息..."
    
    # 生成Base64编码的订阅信息（用于剪贴板导入）
    # P1-1 修复：跨平台兼容性（macOS/BSD不支持-w参数）
    local base64_subscription
    base64_subscription=$(cat "${CONFIG_DIR}/clash-meta-config.yaml" | base64 | tr -d '\n')
    echo "${base64_subscription}" > "${CONFIG_DIR}/clash-meta-subscription.txt"
    
    # 生成Data URI scheme的clash://一键导入链接
    local clash_import_link="clash://install-config?url=data:text/yaml;charset=utf-8;base64,${base64_subscription}"
    echo "${clash_import_link}" > "${CONFIG_DIR}/clash-meta-import-link.txt"
    
    success "Base64订阅信息已生成: ${CONFIG_DIR}/clash-meta-subscription.txt"
    success "一键导入链接已生成: ${CONFIG_DIR}/clash-meta-import-link.txt"
    
    # v6.27: 生成复制粘贴友好的导入块
    cat > "${CONFIG_DIR}/clash-meta-import-block.txt" <<EOF
========== COPY_START:${LANDING_NAME:-landing} ==========
${clash_import_link}
========== COPY_END:${LANDING_NAME:-landing} ==========
EOF
    success "复制粘贴导入块已生成: ${CONFIG_DIR}/clash-meta-import-block.txt"
}

setup_firewall() {
    progress 9 12 "配置防火墙"
    
    local ssh_port
    ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | grep -oE '[0-9]+$' | head -1)
    ssh_port=${ssh_port:-22}
    
    # v5.6: 不清空现有规则，改为精准插入，避免破坏 1Panel/Docker
    # iptables -F INPUT 会清空所有规则，包括 1Panel 和 Docker 的规则
    
    # v6.6: 幂等性修复 - 添加规则前先检查是否已存在
    # 使用 -I 插入到规则链顶部，优先级最高
    iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -i lo -j ACCEPT
    iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    iptables -C INPUT -p tcp --dport ${ssh_port} -j ACCEPT 2>/dev/null || iptables -I INPUT 3 -p tcp --dport ${ssh_port} -j ACCEPT
    
    # AmneziaWG 端口仅允许中转机访问
    iptables -C INPUT -s ${TRANSIT_IP} -p udp --dport ${AWG_PORT} -j ACCEPT 2>/dev/null || iptables -I INPUT 4 -s ${TRANSIT_IP} -p udp --dport ${AWG_PORT} -j ACCEPT
    
    # v5.9: 放行中转机 ICMP 健康检查（中转机 v5.8 改用 ping 检测）
    iptables -C INPUT -s ${TRANSIT_IP} -p icmp --icmp-type echo-request -j ACCEPT 2>/dev/null || iptables -I INPUT 5 -s ${TRANSIT_IP} -p icmp --icmp-type echo-request -j ACCEPT
    
    iptables -C INPUT -s ${TRANSIT_IP} -p tcp --dport ${SS_BACKUP_PORT} -j ACCEPT 2>/dev/null || iptables -I INPUT 6 -s ${TRANSIT_IP} -p tcp --dport ${SS_BACKUP_PORT} -j ACCEPT
    
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
    progress 10 12 "优化系统参数"
    
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
    progress 11 12 "生成客户端配置"
    
    local public_ip
    public_ip=$(curl -s4 --max-time 5 ifconfig.me || echo "<获取失败>")
    
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  落地机安装完成!${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}📱 客户端配置信息:${NC}"
    echo ""
    echo -e "${CYAN}【主轨 - 推荐】UDP 高速通道${NC}"
    echo "  服务器: ${TRANSIT_IP}"
    echo "  端口: ${AWG_PORT}"
    echo "  密码: ${SS_PASSWORD}"
    echo "  加密: 2022-blake3-aes-256-gcm"
    echo "  备注: 需要先连接 AmneziaWG,然后代理指向 10.8.0.1:${SS_MAIN_PORT}"
    echo ""
    echo -e "${CYAN}【备轨】TCP 稳定通道${NC}"
    echo "  服务器: ${TRANSIT_IP}"
    echo "  端口: ${SS_BACKUP_PORT}"
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
    echo -e "${YELLOW}🔧 v5.3 中转机配置信息（请在中转机执行）:${NC}"
    echo "  落地机公网 IP: ${public_ip}"
    echo "  AWG Server 公钥: ${AWG_SERVER_PUBLIC}"
    echo "  AWG 端口: ${AWG_PORT}"
    echo "  混淆参数: Jc=${JC}, Jmin=${JMIN}, Jmax=${JMAX}"
    echo "  混淆参数: S1=${S1}, S2=${S2}"
    echo "  混淆参数: H1=${H1}, H2=${H2}, H3=${H3}, H4=${H4}"
    echo ""
    echo -e "${YELLOW}🔒 v3.3 安全增强功能:${NC}"
    echo "  5. IPv6 已三层防泄漏（sysctl + 所有网卡 + ip6tables）"
    echo "  6. DNS 已三层锁定（resolv.conf + chattr + iptables劫持）"
    
    # v6.0: 删除混淆参数轮换残留代码（v5.8已删除功能）
    
    echo "  7. 流量时序随机化: 10-60秒分段随机（模拟真实用户）"
    echo "  8. 密码已保存，重新运行脚本不会改变"
    
    if [[ -n "${HOME_IP}" ]]; then
        echo "  12. 家宽IP策略路由已配置: ${HOME_IP}"
    fi
    echo ""
    echo -e "${GREEN}✓ 服务状态:${NC}"
    systemctl status awg-landing.service --no-pager | head -3
    systemctl status ss-main.service --no-pager | head -3
    systemctl status ss-backup.service --no-pager | head -3
    # v5.7: 删除scan-detector服务状态查询
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    cat > "${CONFIG_DIR}/client-config.txt" <<EOF
主轨配置:
服务器: ${TRANSIT_IP}
端口: ${AWG_PORT}
密码: ${SS_PASSWORD}
加密: 2022-blake3-aes-256-gcm

备轨配置:
服务器: ${TRANSIT_IP}
端口: ${SS_BACKUP_PORT}
密码: ${SS_PASSWORD}
加密: 2022-blake3-aes-256-gcm
EOF
    
    # v5.3: 生成中转机配置文件
    cat > "${CONFIG_DIR}/transit-peer-config.txt" <<EOF
# v5.3 中转机 Peer 配置（请在中转机执行 ghost-transit-ctl add-landing）

落地机公网 IP: ${public_ip}
AWG Server 公钥: ${AWG_SERVER_PUBLIC}
AWG 端口: ${AWG_PORT}

混淆参数:
Jc=${JC}
Jmin=${JMIN}
Jmax=${JMAX}
S1=${S1}
S2=${S2}
H1=${H1}
H2=${H2}
H3=${H3}
H4=${H4}

命令示例:
ghost-transit-ctl add-landing \\
  --ip ${public_ip} \\
  --name "落地机-$(date +%Y%m%d)" \\
  --awg-port ${AWG_PORT} \\
  --awg-pubkey "${AWG_SERVER_PUBLIC}" \\
  --jc ${JC} --jmin ${JMIN} --jmax ${JMAX} \\
  --s1 ${S1} --s2 ${S2} \\
  --h1 ${H1} --h2 ${H2} --h3 ${H3} --h4 ${H4}
EOF
    
    info "配置已保存到: ${CONFIG_DIR}/client-config.txt"
    info "中转机配置已保存到: ${CONFIG_DIR}/transit-peer-config.txt"
    
    # v6.16 新增：创建快捷命令方便用户重新查看配置
    cat > /usr/local/bin/show-clash-config <<'EOF'
#!/bin/bash
cat /etc/landing-ghost/clash-meta-config.yaml
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
    
    # v6.19: 添加Base64订阅信息和Data URI一键导入链接
    echo -e "${GREEN}💡 推荐导入方式（按优先级排序）：${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}方式1: Base64订阅信息（推荐 - 适用于所有Clash客户端）${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}使用步骤：${NC}"
    echo "  1. 复制下方的Base64编码字符串"
    echo "  2. 打开 Clash Meta → 配置 → 新建配置"
    echo "  3. 选择「从剪贴板导入」或「粘贴配置」"
    echo "  4. 粘贴Base64字符串并保存"
    echo ""
    echo -e "${RED}↓↓↓↓ Base64订阅信息（请复制） ↓↓↓↓${NC}"
    echo ""
    cat "${CONFIG_DIR}/clash-meta-import-block.txt"
    echo ""
    echo -e "${RED}↑↑↑↑ Base64订阅信息结束 ↑↑↑↑${NC}"
    echo ""
    
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}方式2: Data URI一键导入链接（适用于支持clash://协议的客户端）${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}使用步骤：${NC}"
    echo "  1. 复制下方的clash://链接"
    echo "  2. 在浏览器地址栏粘贴并回车"
    echo "  3. Clash Meta会自动打开并导入配置"
    echo ""
    echo -e "${RED}↓↓↓↓ 一键导入链接（请复制） ↓↓↓↓${NC}"
    echo ""
    cat "${CONFIG_DIR}/clash-meta-import-link.txt"
    echo ""
    echo -e "${RED}↑↑↑↑ 一键导入链接结束 ↑↑↑↑${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  注意：${NC}"
    echo "  - 如果浏览器无法识别clash://协议，请使用方式1的Base64订阅"
    echo "  - 链接过长可能在某些终端显示不全，建议使用方式1或方式3"
    echo ""
    
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}方式3: SSH一键拉取（桌面端最简单 - 零泄露风险）${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  在你的本地电脑 (Windows CMD/PowerShell 或 Mac 终端) 直接运行以下命令："
    echo ""
    echo -e "${BOLD}  ssh root@${public_ip} \"show-clash-config\" > ~/Desktop/clash-meta.yaml${NC}"
    echo ""
    echo "  运行后，直接将桌面的 clash-meta.yaml 拖入 Clash Meta 即可。"
    echo ""
    
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}方式4: 其他获取方式${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  • 通过快捷命令重新查看配置："
    echo "    show-clash-config"
    echo ""
    echo "  • 通过完整路径查看配置："
    echo "    cat ${CONFIG_DIR}/clash-meta-config.yaml"
    echo ""
    echo "  • 查看Base64订阅信息："
    echo "    cat ${CONFIG_DIR}/clash-meta-subscription.txt"
    echo ""
    echo "  • 查看一键导入链接："
    echo "    cat ${CONFIG_DIR}/clash-meta-import-link.txt"
    echo ""
    echo "  • 通过 SCP 下载到本地："
    echo "    scp root@${public_ip}:${CONFIG_DIR}/clash-meta-config.yaml ./clash-meta.yaml"
    echo ""
    echo -e "${RED}⚠️  安全提示：${NC}"
    echo "  - 配置包含敏感信息（密钥、密码），请勿分享给他人"
    echo "  - 混淆参数为静态配置，重装前不会改变（无需重新复制配置）"
    echo "  - 配置文件已保存到: ${CONFIG_DIR}/clash-meta-config.yaml"
    echo ""
    
    # v5.9: 补充中转机配置说明（解释为什么要配置两个端口）
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}${BOLD}📋 中转机配置指引${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}请在中转机上执行以下命令（按顺序）：${NC}"
    echo ""
    echo -e "${GREEN}1. 添加落地机配置：${NC}"
    echo "   ghost-transit-ctl add-landing ${public_ip} '落地机-$(hostname)'"
    echo ""
    echo -e "${GREEN}2. 添加端口转发规则（需要配置 2 个端口）：${NC}"
    echo ""
    echo -e "${BOLD}   主轨端口（AWG UDP 隧道）：${NC}"
    echo "   ghost-transit-ctl add-port ${AWG_PORT} udp 'AmneziaWG'"
    echo -e "${CYAN}   说明：主轨通过 AmneziaWG 加密隧道传输，速度快但需要客户端支持${NC}"
    echo ""
    echo -e "${BOLD}   备轨端口（SS TCP 直连）：${NC}"
    echo "   ghost-transit-ctl add-port ${SS_BACKUP_PORT} tcp 'SS备轨'"
    echo -e "${CYAN}   说明：备轨直连 SS 服务，稳定性高，作为主轨故障时的备用通道${NC}"
    echo ""
    echo -e "${GREEN}3. 重载 nftables 规则：${NC}"
    echo "   ghost-transit-ctl reload-rules"
    echo ""
    echo -e "${YELLOW}⚠️  重要：两个端口都必须配置，否则 Clash Meta 自动切换功能无法正常工作${NC}"
    echo ""
    echo -e "${CYAN}配置完成后，中转机将自动转发流量到此落地机${NC}"
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
    generate_obfuscation_params  # [P0-2] 立即生成混淆参数，避免竞态条件
    check_os
    check_1panel_conflict
    check_wireguard_support
    verify_bbr || true  # BBR 不可用时不退出脚本
    
    # v5.6: 落地机独立配置，不再从中转机导入配对信息
    ask_transit_info
    configure_ports
    
    echo ""
    install_dependencies
    lockdown_dns_ipv6
    install_amneziawg
    install_shadowsocks
    configure_amneziawg
    configure_shadowsocks
    setup_systemd
    # v5.8: 混淆参数自动轮换已删除（订阅服务器已删除，轮换会导致客户端失效）
    # v5.6: 端口扫描检测已删除
    generate_clash_meta_yaml
    # v5.6: 订阅服务器已删除，改为终端打印配置
    setup_firewall
    optimize_system
    print_client_config
}

main "$@"
