#!/usr/bin/env bash
set -euo pipefail

VERSION="6.27"
MODULE_NAME="amneziawg"
REPO_URL="${AWG_DKMS_REPO_URL:-https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git}"
WORK_DIR=""
BUILD_SWAP_FILE="/var/tmp/amneziawg-dkms-build.swap"
BUILD_SWAP_CREATED=0
ARCH_HEADER_PKG=""

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
info() { log "INFO: $*"; }
warn() { log "WARN: $*" >&2; }
die() { log "ERROR: $*" >&2; exit 1; }

cleanup() {
    if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then
        rm -rf "${WORK_DIR}"
    fi
    if [[ "${BUILD_SWAP_CREATED}" -eq 1 && "${KEEP_BUILD_SWAP:-0}" != "1" ]]; then
        swapoff "${BUILD_SWAP_FILE}" 2>/dev/null || true
        rm -f "${BUILD_SWAP_FILE}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

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
    apt-get update -qq || die "apt-get update 失败"
    apt-get install -y -qq ca-certificates curl git dkms build-essential kmod make gcc libc6-dev \
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
    local mem_kb swap_kb
    mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
    swap_kb=$(awk '/SwapTotal:/ {print $2}' /proc/meminfo)

    if (( mem_kb >= 1500000 || swap_kb > 0 )); then
        return 0
    fi

    warn "检测到内存低于 1.5G 且无 swap，临时创建 1G swap 用于 DKMS 编译"
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

module_ready() {
    modprobe "${MODULE_NAME}" 2>/dev/null && modinfo "${MODULE_NAME}" >/dev/null 2>&1
}

clone_source() {
    WORK_DIR=$(mktemp -d)
    info "下载 AmneziaWG 内核模块源码"
    git clone --depth 1 "${REPO_URL}" "${WORK_DIR}/src" >/dev/null 2>&1 \
        || die "源码下载失败：${REPO_URL}"
}

install_with_make_target() {
    cd "${WORK_DIR}/src"
    if make -n dkms-install >/dev/null 2>&1; then
        info "使用上游 make dkms-install 安装"
        make dkms-install
        return 0
    fi
    return 1
}

install_with_dkms_direct() {
    cd "${WORK_DIR}/src"
    [[ -f dkms.conf ]] || die "源码缺少 dkms.conf，无法 DKMS 安装"

    local package_name package_version source_dir
    package_name=$(awk -F= '/^[[:space:]]*PACKAGE_NAME[[:space:]]*=/ {gsub(/[ "]/, "", $2); print $2; exit}' dkms.conf)
    package_version=$(awk -F= '/^[[:space:]]*PACKAGE_VERSION[[:space:]]*=/ {gsub(/[ "]/, "", $2); print $2; exit}' dkms.conf)
    package_name=${package_name:-${MODULE_NAME}}
    package_version=${package_version:-$(git rev-parse --short HEAD)}
    source_dir="/usr/src/${package_name}-${package_version}"

    info "使用 DKMS 直接安装: ${package_name}/${package_version}"
    rm -rf "${source_dir}"
    mkdir -p "${source_dir}"
    cp -a . "${source_dir}/"

    if dkms status -m "${package_name}" -v "${package_version}" 2>/dev/null | grep -q "${package_name}"; then
        dkms remove -m "${package_name}" -v "${package_version}" --all || true
    fi

    dkms add -m "${package_name}" -v "${package_version}"
    dkms build -m "${package_name}" -v "${package_version}"
    dkms install -m "${package_name}" -v "${package_version}"
}

install_module() {
    if [[ "${FORCE_REINSTALL:-0}" != "1" ]] && module_ready; then
        info "AmneziaWG 内核模块已可加载，跳过重复编译"
        return 0
    fi

    clone_source
    ensure_build_swap

    if ! install_with_make_target; then
        install_with_dkms_direct
    fi

    depmod -a
    modprobe "${MODULE_NAME}" || die "DKMS 安装完成但 modprobe ${MODULE_NAME} 失败"
    modinfo "${MODULE_NAME}" >/dev/null || die "无法读取 ${MODULE_NAME} 模块信息"
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
    require_root
    detect_platform
    install_packages
    install_module
    print_result
}

main "$@"
