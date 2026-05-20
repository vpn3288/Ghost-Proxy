#!/usr/bin/env bash
set -euo pipefail

VERSION="6.35"
MODULE_NAME="amneziawg"
REPO_URL="${AWG_DKMS_REPO_URL:-https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git}"
WORK_DIR=""
BUILD_SOURCE_DIR=""
BUILD_SWAP_FILE="/var/tmp/amneziawg-dkms-build.swap"
BUILD_SWAP_CREATED=0
ARCH_HEADER_PKG=""

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
info() { log "INFO: $*"; }
warn() { log "WARN: $*" >&2; }
die() { log "ERROR: $*" >&2; exit 1; }

print_help() {
    cat <<EOF
用法: bash install_amneziawg_dkms.sh [--help|-h]

环境变量:
  FORCE_REINSTALL=1       强制重新编译安装
  SKIP_PACKAGE_INSTALL=1  跳过 apt 依赖安装
  AWG_DKMS_REPO_URL=URL   覆盖 AmneziaWG DKMS 源码仓库
  KEEP_BUILD_SWAP=1       保留低内存机器上创建的临时 swap
EOF
}

cleanup() {
    if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then
        rm -rf "${WORK_DIR}"
    fi
    if [[ "${BUILD_SWAP_CREATED}" -eq 1 && "${KEEP_BUILD_SWAP:-0}" != "1" ]]; then
        warn "临时 swap 将由 systemd timer 在 1 小时后清理；如需保留请设置 KEEP_BUILD_SWAP=1"
        install_swap_cleanup_timer || true
    fi
}
trap cleanup EXIT

retry_cmd() {
    local desc="$1"
    shift
    local attempt
    for attempt in 1 2 3; do
        if "$@"; then
            return 0
        fi
        warn "${desc} 失败（尝试 ${attempt}/3），5 秒后重试..."
        sleep 5
    done
    return 1
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "请使用 root 运行"
}

detect_platform() {
    [[ -r /etc/os-release ]] || die "无法识别系统：缺少 /etc/os-release"
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == "debian" ]] || warn "当前系统不是 Debian，脚本仍将按 Debian 方式尝试安装"

    case "$(uname -m)" in
        x86_64) ARCH_HEADER_PKG="linux-headers-amd64" ;;
        aarch64|arm64) ARCH_HEADER_PKG="linux-headers-arm64" ;;
        *) die "不支持的架构：$(uname -m)，仅支持 x86_64 和 ARM64" ;;
    esac

    info "系统: ${PRETTY_NAME:-unknown}, 架构: $(uname -m), 内核: $(uname -r)"
}

install_packages() {
    if [[ "${SKIP_PACKAGE_INSTALL:-0}" == "1" ]]; then
        info "SKIP_PACKAGE_INSTALL=1，跳过 apt 依赖安装"
        [[ -e "/lib/modules/$(uname -r)/build" ]] \
            || die "当前运行内核缺少 build 目录，无法 DKMS 编译"
        return 0
    fi

    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a || die "dpkg 状态异常，请先修复 apt/dpkg"
    retry_cmd "apt-get update" apt-get update -qq || die "apt-get update 失败"
    apt-get install -y -qq ca-certificates curl git dkms build-essential kmod make gcc libc6-dev pkg-config libmnl-dev \
        || die "基础编译依赖安装失败"

    if apt-get install -y -qq "linux-headers-$(uname -r)" 2>/dev/null; then
        info "已安装当前内核头文件: linux-headers-$(uname -r)"
    else
        warn "当前内核头文件不可用，尝试安装架构通用头文件: ${ARCH_HEADER_PKG}"
        apt-get install -y -qq "${ARCH_HEADER_PKG}" \
            || die "内核头文件安装失败。请确认系统使用 Debian 12 官方内核，或先升级/重启到可安装 headers 的内核"
    fi

    [[ -e "/lib/modules/$(uname -r)/build" ]] \
        || die "当前运行内核缺少 build 目录。请先执行 apt upgrade 并重启到 Debian 官方内核后再运行本脚本"
}

ensure_build_swap() {
    local mem_kb swap_kb available_mb
    mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
    swap_kb=$(awk '/SwapTotal:/ {print $2}' /proc/meminfo)

    if (( mem_kb >= 1500000 || swap_kb > 0 )); then
        return 0
    fi

    warn "检测到内存低于 1.5G 且无 swap，临时创建 1G swap 用于 DKMS 编译"
    available_mb=$(df -m /var/tmp | awk 'NR==2 {print $4}')
    if (( available_mb < 1500 )); then
        warn "/var/tmp 可用空间不足（${available_mb}MB），跳过临时 swap"
        return 0
    fi

    if [[ -e "${BUILD_SWAP_FILE}" ]]; then
        rm -f "${BUILD_SWAP_FILE}"
    fi

    if command -v fallocate >/dev/null 2>&1; then
        fallocate -l 1G "${BUILD_SWAP_FILE}" || dd if=/dev/zero of="${BUILD_SWAP_FILE}" bs=1M count=1024 status=none
    else
        dd if=/dev/zero of="${BUILD_SWAP_FILE}" bs=1M count=1024 status=none
    fi
    chmod 600 "${BUILD_SWAP_FILE}"
    mkswap "${BUILD_SWAP_FILE}" >/dev/null
    swapon "${BUILD_SWAP_FILE}"
    BUILD_SWAP_CREATED=1
}

install_swap_cleanup_timer() {
    cat > /etc/systemd/system/cleanup-awg-swap.service <<EOF
[Unit]
Description=Cleanup AmneziaWG DKMS Build Swap

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'swapoff /var/tmp/amneziawg-dkms-build.swap 2>/dev/null || true; rm -f /var/tmp/amneziawg-dkms-build.swap'
EOF

    cat > /etc/systemd/system/cleanup-awg-swap.timer <<'EOF'
[Unit]
Description=Cleanup AmneziaWG DKMS Build Swap Timer

[Timer]
OnActiveSec=1h
AccuracySec=1min
Unit=cleanup-awg-swap.service

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload || return 1
    systemctl enable --now cleanup-awg-swap.timer >/dev/null 2>&1 || return 1
}

module_ready() {
    modprobe "${MODULE_NAME}" 2>/dev/null \
        && lsmod | grep -q "^${MODULE_NAME}" \
        && modinfo "${MODULE_NAME}" >/dev/null 2>&1
}

clone_source() {
    WORK_DIR=$(mktemp -d)
    info "下载 AmneziaWG 内核模块源码"
    local attempt
    for attempt in 1 2 3; do
        if git clone --depth 1 --config http.lowSpeedLimit=1000 --config http.lowSpeedTime=60 \
            "${REPO_URL}" "${WORK_DIR}/src" >/dev/null 2>&1; then
            return 0
        fi
        warn "git clone 失败（尝试 ${attempt}/3），5 秒后重试..."
        sleep 5
    done
    die "源码下载失败（3 次尝试均失败）: ${REPO_URL}"
}

select_build_source_dir() {
    if [[ -f "${WORK_DIR}/src/dkms.conf" ]]; then
        BUILD_SOURCE_DIR="${WORK_DIR}/src"
    elif [[ -f "${WORK_DIR}/src/src/dkms.conf" ]]; then
        BUILD_SOURCE_DIR="${WORK_DIR}/src/src"
    else
        die "源码中未找到 dkms.conf，无法 DKMS 安装"
    fi
    info "DKMS 源码目录: ${BUILD_SOURCE_DIR}"
}

read_dkms_metadata() {
    local package_name package_version
    cd "${BUILD_SOURCE_DIR}"
    package_name=$(awk -F= '/^[[:space:]]*PACKAGE_NAME[[:space:]]*=/ {gsub(/[ "]/, "", $2); print $2; exit}' dkms.conf)
    package_version=$(awk -F= '/^[[:space:]]*PACKAGE_VERSION[[:space:]]*=/ {gsub(/[ "]/, "", $2); print $2; exit}' dkms.conf)
    package_name=${package_name:-${MODULE_NAME}}
    package_version=${package_version:-$(git rev-parse --short HEAD)}
    printf '%s %s\n' "${package_name}" "${package_version}"
}

remove_existing_dkms() {
    local package_name="$1"
    local package_version="$2"

    if dkms status -m "${package_name}" -v "${package_version}" 2>/dev/null | grep -q "${package_name}"; then
        dkms remove -m "${package_name}" -v "${package_version}" --all || true
    fi
}

build_and_install_dkms() {
    local package_name="$1"
    local package_version="$2"

    dkms add -m "${package_name}" -v "${package_version}"
    dkms build -m "${package_name}" -v "${package_version}"
    dkms install -m "${package_name}" -v "${package_version}"
}

install_with_make_target() {
    local package_name package_version
    read -r package_name package_version < <(read_dkms_metadata)

    cd "${BUILD_SOURCE_DIR}"
    if make -n dkms-install >/dev/null 2>&1; then
        info "使用上游 make dkms-install 准备 DKMS 源码"
        remove_existing_dkms "${package_name}" "${package_version}"
        make dkms-install
        build_and_install_dkms "${package_name}" "${package_version}"
        return 0
    fi
    return 1
}

install_with_dkms_direct() {
    local package_name package_version source_dir
    read -r package_name package_version < <(read_dkms_metadata)
    source_dir="/usr/src/${package_name}-${package_version}"

    info "使用 DKMS 直接安装: ${package_name}/${package_version}"
    remove_existing_dkms "${package_name}" "${package_version}"
    rm -rf "${source_dir}"
    mkdir -p "${source_dir}"
    cp -a "${BUILD_SOURCE_DIR}/." "${source_dir}/"

    build_and_install_dkms "${package_name}" "${package_version}"
}

install_module() {
    if [[ "${FORCE_REINSTALL:-0}" != "1" ]] && module_ready; then
        info "AmneziaWG 内核模块已就绪，跳过重复编译"
        return 0
    fi

    clone_source
    select_build_source_dir
    ensure_build_swap

    if ! install_with_make_target; then
        install_with_dkms_direct
    fi

    depmod -a
    modprobe "${MODULE_NAME}" || die "DKMS 安装完成但 modprobe ${MODULE_NAME} 失败"
    lsmod | grep -q "^${MODULE_NAME}" || die "modprobe 返回成功但 ${MODULE_NAME} 未出现在 lsmod 中"
    modinfo "${MODULE_NAME}" >/dev/null || die "无法读取 ${MODULE_NAME} 模块信息"
}

ensure_module_autoload() {
    touch /etc/modules
    if ! grep -qx "${MODULE_NAME}" /etc/modules; then
        echo "${MODULE_NAME}" >> /etc/modules
        info "已添加 ${MODULE_NAME} 到 /etc/modules，重启后自动加载"
    fi
}

ensure_awg_quick() {
    if command -v awg >/dev/null 2>&1 && command -v awg-quick >/dev/null 2>&1; then
        awg-quick --version >/dev/null 2>&1 || warn "awg-quick 存在但版本输出异常，请留意工具兼容性"
        return 0
    fi

    info "未找到 awg/awg-quick，开始编译安装 amneziawg-tools"
    local tmp_dir
    tmp_dir=$(mktemp -d) || die "创建临时目录失败"

    if ! retry_cmd "下载 amneziawg-tools" git clone --depth 1 \
        --config http.lowSpeedLimit=1000 \
        --config http.lowSpeedTime=60 \
        https://github.com/amnezia-vpn/amneziawg-tools.git "${tmp_dir}/tools"; then
        rm -rf "${tmp_dir}"
        die "下载 amneziawg-tools 失败"
    fi

    make -C "${tmp_dir}/tools/src" || { rm -rf "${tmp_dir}"; die "编译 amneziawg-tools 失败"; }
    make -C "${tmp_dir}/tools/src" install || { rm -rf "${tmp_dir}"; die "安装 amneziawg-tools 失败"; }
    rm -rf "${tmp_dir}"

    command -v awg >/dev/null 2>&1 || die "awg 安装后仍不可用"
    command -v awg-quick >/dev/null 2>&1 || die "awg-quick 安装后仍不可用"
}

ensure_health_service() {
    if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
        install -m 0755 "${BASH_SOURCE[0]}" /usr/local/bin/install_amneziawg_dkms.sh 2>/dev/null || true
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 10 --retry 3 \
            https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/install_amneziawg_dkms.sh \
            -o /usr/local/bin/install_amneziawg_dkms.sh 2>/dev/null && chmod +x /usr/local/bin/install_amneziawg_dkms.sh || true
    fi
    cat > /etc/systemd/system/ghost-awg-dkms-check.service <<EOF
[Unit]
Description=AmneziaWG DKMS Module Health Check
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'modprobe ${MODULE_NAME} 2>/dev/null || FORCE_REINSTALL=1 /usr/local/bin/install_amneziawg_dkms.sh'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload || true
    systemctl enable ghost-awg-dkms-check.service >/dev/null 2>&1 || true
}

print_result() {
    echo ""
    echo "========== AMNEZIAWG_DKMS_OK =========="
    echo "script_version=${VERSION}"
    echo "module=${MODULE_NAME}"
    echo "kernel=$(uname -r)"
    echo "arch=$(uname -m)"
    modinfo "${MODULE_NAME}" | awk -F: '/^(filename|version|vermagic):/ {gsub(/^[ \t]+/, "", $2); print $1"="$2}'
    echo "======================================="
}

main() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        print_help
        exit 0
    fi

    require_root
    detect_platform
    install_packages
    install_module
    ensure_module_autoload
    ensure_awg_quick
    ensure_health_service
    print_result
}

main "$@"
