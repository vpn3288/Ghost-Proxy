#!/usr/bin/env bash
set -euo pipefail

VERSION="6.80"
MODULE_NAME="amneziawg"
DEFAULT_REPO_URL="https://github.com/amnezia-vpn/amneziawg-linux-kernel-module.git"
# AmneziaWG upstream source refs pinned on 2026-05-20 for reproducible builds.
# DKMS module: amneziawg-linux-kernel-module@ac946a9 (verified 2026-05-20)
# Tools: amneziawg-tools@5d6179a (verified 2026-05-20)
DEFAULT_AWG_DKMS_REF="ac946a9df100a17d342b5982d1947deef1b51952"
DEFAULT_AWG_TOOLS_REF="5d6179a6d0842e98dfb349c28cf1bd8e4b9d1079"
DEFAULT_DKMS_VERSION="3.0.10-8+deb12u1"
DEFAULT_GCC_VERSION="12"

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
        echo "[INFO] ALLOW_CWD_VERSIONS=1, loading ./versions.conf" >&2
        # shellcheck disable=SC1091
        source ./versions.conf
    fi
}
load_versions_config

DKMS_VERSION="${DKMS_VERSION:-${DEFAULT_DKMS_VERSION}}"
GCC_VERSION="${GCC_VERSION:-${DEFAULT_GCC_VERSION}}"
AWG_DKMS_REF="${AWG_DKMS_REF:-${DEFAULT_AWG_DKMS_REF}}"
AWG_TOOLS_REF="${AWG_TOOLS_REF:-${DEFAULT_AWG_TOOLS_REF}}"
RECOMMENDED_OS_VERSION="${RECOMMENDED_OS_VERSION:-12}"
RECOMMENDED_OS_POINT="${RECOMMENDED_OS_POINT:-12.14}"
DEFAULT_TARBALL_URL="https://github.com/amnezia-vpn/amneziawg-linux-kernel-module/archive/${AWG_DKMS_REF}.tar.gz"
REPO_URL="${AWG_DKMS_REPO_URL:-${DEFAULT_REPO_URL}}"
if [[ "${GITEE_MIRROR:-0}" == "1" && -z "${AWG_DKMS_REPO_URL:-}" ]]; then
    REPO_URL="https://gitee.com/mirrors/amneziawg-linux-kernel-module.git"
fi
TARBALL_URL="${AWG_DKMS_TARBALL_URL:-}"
WORK_DIR=""
BUILD_SOURCE_DIR=""
BUILD_SWAP_FILE="/var/tmp/amneziawg-dkms-build.swap"
BUILD_SWAP_CREATED=0
ARCH_HEADER_PKG=""
STATE_DIR="/var/lib/amneziawg-dkms"
REF_STATE_FILE="${STATE_DIR}/ref"
TOOLS_STATE_DIR="/var/lib/amneziawg-tools"
TOOLS_REF_STATE_FILE="${TOOLS_STATE_DIR}/ref"

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
  SKIP_APT_UPDATE=1       跳过 apt-get update，直接使用现有 apt 缓存
  AWG_DKMS_REPO_URL=URL   覆盖 AmneziaWG DKMS 源码仓库
  AWG_DKMS_REF=REF        覆盖 DKMS 源码提交/tag/分支
  AWG_TOOLS_REF=REF       覆盖 amneziawg-tools 源码提交/tag/分支
  AWG_DKMS_TARBALL_URL=URL 覆盖 git 失败后的源码 tarball 回退地址
  DKMS_VERSION=VERSION    固定 apt dkms 包版本（可选）
  GCC_VERSION=VERSION     固定 gcc 主版本，例如 12（可选）
  KERNEL_HOLD=1           DKMS 成功后冻结当前架构的 linux-image/linux-headers 元包
  KEEP_BUILD_SWAP=1       保留低内存机器上创建的临时 swap
  GITEE_MIRROR=1          使用 Gitee 镜像仓库作为 DKMS 源码来源
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
    local os_id os_version_id os_pretty
    os_id=$(awk -F= '$1=="ID" {gsub(/"/, "", $2); print $2; exit}' /etc/os-release)
    os_version_id=$(awk -F= '$1=="VERSION_ID" {gsub(/"/, "", $2); print $2; exit}' /etc/os-release)
    os_pretty=$(awk -F= '$1=="PRETTY_NAME" {gsub(/"/, "", $2); print $2; exit}' /etc/os-release)
    if [[ "${os_id:-}" != "debian" || "${os_version_id:-}" != "${RECOMMENDED_OS_VERSION}" ]]; then
        warn "检测到 ${os_pretty:-unknown}，Ghost-Proxy DKMS 仅推荐 Debian ${RECOMMENDED_OS_VERSION}"
        warn "推荐基线：Debian ${RECOMMENDED_OS_POINT} Bookworm minimal，可显著降低 DKMS 排障成本"
        warn "官方 ISO: https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/"
        warn "网络安装: https://www.debian.org/distrib/netinst"
        warn "DD 会清空机器；仅限新机并确认救援能力后手动执行。统一入口："
        warn "bash dd_debian.sh --arch amd64|arm64"
    elif [[ -r /etc/debian_version ]]; then
        local debian_point
        debian_point=$(cat /etc/debian_version)
        if [[ "${debian_point}" != "${RECOMMENDED_OS_POINT}" ]]; then
            warn "当前 Debian ${debian_point}，推荐基线为 ${RECOMMENDED_OS_POINT}；如遇 DKMS 问题，建议 DD 到固定基线"
        fi
    fi
    [[ "${os_id:-}" == "debian" ]] || warn "当前系统不是 Debian，脚本仍将按 Debian 方式尝试安装"

    case "$(uname -m)" in
        x86_64) ARCH_HEADER_PKG="linux-headers-amd64" ;;
        aarch64|arm64) ARCH_HEADER_PKG="linux-headers-arm64" ;;
        *) die "不支持的架构：$(uname -m)，仅支持 x86_64 和 ARM64" ;;
    esac

    info "系统: ${os_pretty:-unknown}, 架构: $(uname -m), 内核: $(uname -r)"
}

check_kernel_compatibility() {
    local kernel_version kernel_major kernel_minor
    kernel_version=$(uname -r)
    kernel_major=$(printf '%s\n' "${kernel_version}" | cut -d. -f1)
    kernel_minor=$(printf '%s\n' "${kernel_version}" | cut -d. -f2)
    kernel_major=${kernel_major%%[^0-9]*}
    kernel_minor=${kernel_minor%%[^0-9]*}

    if [[ "${kernel_version}" =~ [Uu][Ee][Kk] ]]; then
        warn "检测到 Oracle UEK 内核 (${kernel_version})，外置 DKMS 模块常见失败；调用方应回退 amneziawg-go"
        return 1
    fi

    if [[ -n "${kernel_major}" && -n "${kernel_minor}" ]] \
        && { [[ "${kernel_major}" -lt 5 ]] || [[ "${kernel_major}" -eq 5 && "${kernel_minor}" -lt 10 ]]; }; then
        warn "内核版本 ${kernel_version} 过旧（推荐 5.10+），DKMS 风险较高；调用方应回退 amneziawg-go"
        return 1
    fi

    return 0
}

check_kernel_symbols() {
    local required_symbols=("udp_tunnel_xmit_skb" "ip_tunnel_encap_setup")
    local missing=0

    [[ -r /proc/kallsyms ]] || {
        warn "无法读取 /proc/kallsyms，跳过内核符号预检"
        return 0
    }

    for sym in "${required_symbols[@]}"; do
        if ! grep -qw "${sym}" /proc/kallsyms 2>/dev/null; then
            warn "内核缺少符号 ${sym}，DKMS 可能失败，调用方可回退到用户态后端"
            missing=1
        fi
    done

    [[ "${missing}" -eq 0 ]]
}

install_packages() {
    if [[ "${SKIP_PACKAGE_INSTALL:-0}" == "1" ]]; then
        info "SKIP_PACKAGE_INSTALL=1，跳过 apt 依赖安装"
        if [[ ! -e "/lib/modules/$(uname -r)/build" ]]; then
            warn "当前运行内核缺少 build 目录，DKMS 将失败，调用方可回退"
            return 1
        fi
        if [[ ! -f "/lib/modules/$(uname -r)/build/Makefile" ]]; then
            warn "当前运行内核 build 目录不完整（缺少 Makefile），DKMS 将失败，调用方可回退"
            return 1
        fi
        return 0
    fi

    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a || die "dpkg 状态异常，请先修复 apt/dpkg"
    if [[ "${SKIP_APT_UPDATE:-0}" == "1" ]]; then
        warn "SKIP_APT_UPDATE=1，跳过 apt-get update，直接使用现有 apt 缓存"
    elif ! retry_cmd "apt-get update" apt-get update -qq; then
        warn "apt-get update 失败，将继续尝试使用现有 apt 缓存安装依赖"
    fi

    local base_packages=(ca-certificates curl git build-essential kmod make libc6-dev pkg-config libmnl-dev)
    retry_cmd "安装基础编译依赖" apt-get install -y -qq "${base_packages[@]}" \
        || die "基础编译依赖安装失败"

    if [[ -n "${DKMS_VERSION:-}" ]]; then
        info "使用固定 DKMS 版本: ${DKMS_VERSION}"
        retry_cmd "安装固定 DKMS" apt-get install -y -qq "dkms=${DKMS_VERSION}" || {
            warn "固定 DKMS ${DKMS_VERSION} 不可用，回退安装仓库默认 dkms"
            retry_cmd "安装仓库默认 DKMS" apt-get install -y -qq dkms || die "dkms 安装失败"
        }
    else
        retry_cmd "安装 DKMS" apt-get install -y -qq dkms || die "dkms 安装失败"
    fi

    if [[ -n "${GCC_VERSION:-}" ]]; then
        info "使用固定 GCC 主版本: ${GCC_VERSION}"
        if retry_cmd "安装固定 GCC" apt-get install -y -qq "gcc-${GCC_VERSION}"; then
            update-alternatives --install /usr/bin/gcc gcc "/usr/bin/gcc-${GCC_VERSION}" 100 >/dev/null 2>&1 || true
        elif command -v gcc >/dev/null 2>&1; then
            warn "固定 gcc-${GCC_VERSION} 安装失败，继续使用系统已有 gcc: $(gcc -dumpversion 2>/dev/null || echo unknown)"
        else
            die "固定 gcc-${GCC_VERSION} 安装失败，且系统没有可用 gcc"
        fi
    else
        retry_cmd "安装 GCC" apt-get install -y -qq gcc || {
            command -v gcc >/dev/null 2>&1 || die "gcc 安装失败，且系统没有可用 gcc"
            warn "gcc 包安装失败，继续使用系统已有 gcc: $(gcc -dumpversion 2>/dev/null || echo unknown)"
        }
    fi

    if retry_cmd "安装当前内核头文件" apt-get install -y -qq "linux-headers-$(uname -r)"; then
        info "已安装当前内核头文件: linux-headers-$(uname -r)"
    else
        warn "当前内核头文件不可用，尝试安装架构通用头文件: ${ARCH_HEADER_PKG}"
        if ! retry_cmd "安装架构通用头文件" apt-get install -y -qq "${ARCH_HEADER_PKG}"; then
            warn "内核头文件安装失败，DKMS 将失败，调用方可回退"
            return 1
        fi
    fi

    if [[ ! -e "/lib/modules/$(uname -r)/build" ]]; then
        warn "内核头文件不匹配 $(uname -r)，DKMS 将失败，调用方可回退"
        return 1
    fi
    if [[ ! -f "/lib/modules/$(uname -r)/build/Makefile" ]]; then
        warn "内核 build 目录存在但不完整（缺少 Makefile），DKMS 将失败，调用方可回退"
        return 1
    fi
}

ensure_build_swap() {
    local mem_kb swap_kb available_mb
    mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
    swap_kb=$(awk '/SwapTotal:/ {print $2}' /proc/meminfo)

    if (( mem_kb >= 1500000 || swap_kb > 0 )); then
        return 0
    fi

    warn "检测到内存低于 1.5G 且无 swap，临时创建 2G swap 用于 DKMS 编译"
    available_mb=$(df -m /var/tmp | awk 'NR==2 {print $4}')
    if (( available_mb < 2500 )); then
        warn "/var/tmp 可用空间不足（${available_mb}MB），无法创建临时 swap"
        warn "DKMS 编译可能 OOM；落地机调用方应回退 amneziawg-go，或手动增加 swap 后重试"
        return 0
    fi

    if [[ -e "${BUILD_SWAP_FILE}" ]]; then
        rm -f "${BUILD_SWAP_FILE}"
    fi

    if command -v fallocate >/dev/null 2>&1; then
        fallocate -l 2G "${BUILD_SWAP_FILE}" || dd if=/dev/zero of="${BUILD_SWAP_FILE}" bs=1M count=2048 status=none || {
            warn "临时 swap 文件创建失败，DKMS 编译可能 OOM"
            rm -f "${BUILD_SWAP_FILE}"
            return 0
        }
    elif ! dd if=/dev/zero of="${BUILD_SWAP_FILE}" bs=1M count=2048 status=none; then
        warn "临时 swap 文件创建失败，DKMS 编译可能 OOM"
        rm -f "${BUILD_SWAP_FILE}"
        return 0
    fi
    chmod 600 "${BUILD_SWAP_FILE}" || {
        warn "临时 swap 权限设置失败，跳过 swap"
        rm -f "${BUILD_SWAP_FILE}"
        return 0
    }
    if ! mkswap "${BUILD_SWAP_FILE}" >/dev/null || ! swapon "${BUILD_SWAP_FILE}"; then
        warn "临时 swap 启用失败，DKMS 编译可能 OOM；调用方可回退 amneziawg-go"
        rm -f "${BUILD_SWAP_FILE}"
        return 0
    fi
    BUILD_SWAP_CREATED=1
}

install_swap_cleanup_timer() {
    cat > /etc/systemd/system/cleanup-awg-swap.service <<EOF
[Unit]
Description=Cleanup AmneziaWG DKMS Build Swap

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'swapoff ${BUILD_SWAP_FILE} 2>/dev/null || true; rm -f ${BUILD_SWAP_FILE}'
EOF

    cat > /etc/systemd/system/cleanup-awg-swap.timer <<'EOF'
[Unit]
Description=Cleanup AmneziaWG DKMS Build Swap Timer

[Timer]
OnBootSec=1h
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

ref_state_matches() {
    [[ -f "${REF_STATE_FILE}" ]] || return 1
    [[ "$(cat "${REF_STATE_FILE}" 2>/dev/null || true)" == "${AWG_DKMS_REF}" ]]
}

write_ref_state() {
    mkdir -p "${STATE_DIR}"
    printf '%s\n' "${AWG_DKMS_REF}" > "${REF_STATE_FILE}"
    chmod 600 "${REF_STATE_FILE}" 2>/dev/null || true
}

tools_ref_state_matches() {
    [[ -f "${TOOLS_REF_STATE_FILE}" ]] || return 1
    [[ "$(cat "${TOOLS_REF_STATE_FILE}" 2>/dev/null || true)" == "${AWG_TOOLS_REF}" ]]
}

write_tools_ref_state() {
    mkdir -p "${TOOLS_STATE_DIR}"
    printf '%s\n' "${AWG_TOOLS_REF}" > "${TOOLS_REF_STATE_FILE}"
    chmod 600 "${TOOLS_REF_STATE_FILE}" 2>/dev/null || true
}

clone_source() {
    WORK_DIR=$(mktemp -d)
    info "下载 AmneziaWG 内核模块源码: ${AWG_DKMS_REF}"
    local attempt tarball_url archive extracted gitee_tarball
    for attempt in 1 2 3; do
        rm -rf "${WORK_DIR}/src"
        if git clone --depth 1 --config http.lowSpeedLimit=1000 --config http.lowSpeedTime=60 \
            "${REPO_URL}" "${WORK_DIR}/src" >/dev/null 2>&1 \
            && git -C "${WORK_DIR}/src" fetch --depth 1 origin "${AWG_DKMS_REF}" >/dev/null 2>&1 \
            && git -C "${WORK_DIR}/src" checkout -q FETCH_HEAD; then
            return 0
        fi
        warn "git clone 失败（尝试 ${attempt}/3），5 秒后重试..."
        sleep 5
    done

    tarball_url="${TARBALL_URL}"
    if [[ -z "${tarball_url}" && ( "${REPO_URL}" == "${DEFAULT_REPO_URL}" || "${GITEE_MIRROR:-0}" == "1" ) ]]; then
        tarball_url="${DEFAULT_TARBALL_URL}"
    fi
    if [[ -n "${tarball_url}" ]]; then
        warn "git clone 不可用，改用源码 tarball 回退下载"
        archive="${WORK_DIR}/src.tar.gz"
        if [[ "${GITEE_MIRROR:-0}" == "1" && -z "${AWG_DKMS_TARBALL_URL:-}" ]]; then
            gitee_tarball="https://gitee.com/mirrors/amneziawg-linux-kernel-module/repository/archive/${AWG_DKMS_REF}.tar.gz"
            for attempt in 1 2; do
                if curl -fsSL --connect-timeout 10 --retry 2 "${gitee_tarball}" -o "${archive}" \
                    && mkdir -p "${WORK_DIR}/tar" \
                    && tar -xzf "${archive}" -C "${WORK_DIR}/tar"; then
                    extracted=$(find "${WORK_DIR}/tar" -mindepth 1 -maxdepth 1 -type d | head -1 || true)
                    if [[ -n "${extracted}" && -d "${extracted}" ]]; then
                        rm -rf "${WORK_DIR}/src"
                        mv "${extracted}" "${WORK_DIR}/src"
                        return 0
                    fi
                fi
                rm -rf "${WORK_DIR}/tar" "${archive}"
                warn "Gitee tarball 下载失败（尝试 ${attempt}/2）"
                [[ ${attempt} -lt 2 ]] && sleep 3
            done
            warn "Gitee tarball 失败，回退 GitHub tarball"
        fi
        for attempt in 1 2 3; do
            if curl -fsSL --connect-timeout 10 --retry 3 "${tarball_url}" -o "${archive}" \
                && mkdir -p "${WORK_DIR}/tar" \
                && tar -xzf "${archive}" -C "${WORK_DIR}/tar"; then
                extracted=$(find "${WORK_DIR}/tar" -mindepth 1 -maxdepth 1 -type d | head -1 || true)
                if [[ -n "${extracted}" && -d "${extracted}" ]]; then
                    rm -rf "${WORK_DIR}/src"
                    mv "${extracted}" "${WORK_DIR}/src"
                    return 0
                fi
            fi
            rm -rf "${WORK_DIR}/tar" "${archive}"
            warn "tarball 下载失败（尝试 ${attempt}/3），5 秒后重试..."
            sleep 5
        done
    fi
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
    local make_log="/var/lib/dkms/${package_name}/${package_version}/build/make.log"

    dkms add -m "${package_name}" -v "${package_version}" || {
        warn "DKMS add 失败：请检查源码目录和 dkms.conf"
        return 1
    }
    dkms build -m "${package_name}" -v "${package_version}" || {
        warn "DKMS build 失败：可能是内核头文件不匹配、工具链缺失或低内存 OOM"
        warn "当前内核: $(uname -r)"
        warn "详细日志: ${make_log}"
        [[ -f "${make_log}" ]] && tail -20 "${make_log}" >&2 || true
        return 1
    }
    dkms install -m "${package_name}" -v "${package_version}" || {
        warn "DKMS install 失败"
        return 1
    }
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
        if ref_state_matches; then
            info "AmneziaWG 内核模块已就绪，ref 匹配，跳过重复编译"
            return 0
        fi
        warn "已加载模块缺少当前 ref 状态记录，强制按 ${AWG_DKMS_REF} 重新安装"
        FORCE_REINSTALL=1
    fi

    clone_source
    select_build_source_dir
    ensure_build_swap
    local available_mem_mb
    available_mem_mb=$(awk '/MemAvailable:/ {print int($2/1024); found=1} END {if (!found) print 0}' /proc/meminfo 2>/dev/null || echo 0)
    if (( available_mem_mb > 0 && available_mem_mb < 512 )); then
        export MAKEFLAGS="${MAKEFLAGS:-} -j1"
        warn "可用内存低于 512MB，设置 MAKEFLAGS=-j1 降低 DKMS OOM 风险"
    fi

    if ! install_with_make_target; then
        install_with_dkms_direct
    fi

    depmod -a
    modprobe "${MODULE_NAME}" || die "DKMS 安装完成但 modprobe ${MODULE_NAME} 失败"
    lsmod | grep -q "^${MODULE_NAME}" || die "modprobe 返回成功但 ${MODULE_NAME} 未出现在 lsmod 中"
    modinfo "${MODULE_NAME}" >/dev/null || die "无法读取 ${MODULE_NAME} 模块信息"
    write_ref_state
}

ensure_module_autoload() {
    touch /etc/modules
    if ! grep -qx "${MODULE_NAME}" /etc/modules; then
        echo "${MODULE_NAME}" >> /etc/modules
        info "已添加 ${MODULE_NAME} 到 /etc/modules，重启后自动加载"
    fi
}

ensure_awg_quick() {
    if command -v awg >/dev/null 2>&1 && command -v awg-quick >/dev/null 2>&1 && tools_ref_state_matches; then
        awg-quick --version >/dev/null 2>&1 || warn "awg-quick 存在但版本输出异常，请留意工具兼容性"
        return 0
    fi

    if command -v awg >/dev/null 2>&1 && command -v awg-quick >/dev/null 2>&1; then
        warn "awg/awg-quick 已存在，但 AWG_TOOLS_REF 状态未匹配当前固定版本，重新安装 amneziawg-tools"
    else
        info "未找到 awg/awg-quick，开始编译安装 amneziawg-tools"
    fi

    local tmp_dir attempt clone_ok=0
    tmp_dir=$(mktemp -d) || die "创建临时目录失败"

    for attempt in 1 2 3; do
        rm -rf "${tmp_dir}/tools"
        if git clone --depth 1 \
            --config http.lowSpeedLimit=1000 \
            --config http.lowSpeedTime=60 \
            https://github.com/amnezia-vpn/amneziawg-tools.git "${tmp_dir}/tools" \
            && git -C "${tmp_dir}/tools" fetch --depth 1 origin "${AWG_TOOLS_REF}" >/dev/null 2>&1 \
            && git -C "${tmp_dir}/tools" checkout -q FETCH_HEAD; then
            clone_ok=1
            break
        fi
        warn "下载 amneziawg-tools 失败（尝试 ${attempt}/3），5 秒后重试..."
        sleep 5
    done

    if [[ "${clone_ok}" -ne 1 ]]; then
        rm -rf "${tmp_dir}"
        die "下载 amneziawg-tools 失败"
    fi

    make -C "${tmp_dir}/tools/src" || { rm -rf "${tmp_dir}"; die "编译 amneziawg-tools 失败"; }
    make -C "${tmp_dir}/tools/src" install || { rm -rf "${tmp_dir}"; die "安装 amneziawg-tools 失败"; }
    rm -rf "${tmp_dir}"

    command -v awg >/dev/null 2>&1 || die "awg 安装后仍不可用"
    command -v awg-quick >/dev/null 2>&1 || die "awg-quick 安装后仍不可用"
    write_tools_ref_state
}

ensure_health_service() {
    if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
        install -m 0755 "${BASH_SOURCE[0]}" /usr/local/bin/install_amneziawg_dkms.sh 2>/dev/null || true
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 10 --retry 3 \
            "https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/install_amneziawg_dkms_v${VERSION}.sh" \
            -o /usr/local/bin/install_amneziawg_dkms.sh 2>/dev/null && chmod +x /usr/local/bin/install_amneziawg_dkms.sh || true
    fi
    cat > /usr/local/bin/awg-dkms-health.sh <<'EOF'
#!/usr/bin/env bash
set -u

module_name="${MODULE_NAME:-amneziawg}"
ref_state="/var/lib/amneziawg-dkms/ref"
ref="$(cat "${ref_state}" 2>/dev/null || true)"
kver="$(uname -r)"

if modprobe "${module_name}" 2>/dev/null && [[ -n "${ref}" ]] && grep -qx "${ref}" "${ref_state}" 2>/dev/null; then
    exit 0
fi

if [[ ! -f "/lib/modules/${kver}/build/Makefile" ]]; then
    echo "SKIP: no complete kernel headers for ${kver}" >&2
    exit 0
fi

if [[ ! -x /usr/local/bin/install_amneziawg_dkms.sh ]]; then
    echo "SKIP: /usr/local/bin/install_amneziawg_dkms.sh is missing" >&2
    exit 0
fi

for i in 1 2 3; do
    FORCE_REINSTALL=1 AWG_DKMS_REF="${ref:-${AWG_DKMS_REF:-}}" AWG_TOOLS_REF="${AWG_TOOLS_REF:-}" \
        /usr/local/bin/install_amneziawg_dkms.sh && exit 0
    sleep 30
done

echo "AWG DKMS 恢复失败，将在下次 kernel 更新后重试" >&2
exit 1
EOF
    chmod +x /usr/local/bin/awg-dkms-health.sh

    cat > /etc/systemd/system/ghost-awg-dkms-check.service <<EOF
[Unit]
Description=AmneziaWG DKMS Module Health Check
After=network.target

[Service]
Type=oneshot
Environment=DKMS_VERSION=${DKMS_VERSION}
Environment=GCC_VERSION=${GCC_VERSION}
Environment=AWG_DKMS_REF=${AWG_DKMS_REF}
Environment=AWG_TOOLS_REF=${AWG_TOOLS_REF}
ExecStart=/usr/local/bin/awg-dkms-health.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload || true
    systemctl enable ghost-awg-dkms-check.service >/dev/null 2>&1 || true

    mkdir -p /etc/kernel/postinst.d
    cat > /etc/kernel/postinst.d/amneziawg-dkms <<'EOF'
#!/bin/bash
KERNEL_VERSION="$1"
logger -t amneziawg-dkms "检测到内核升级: ${KERNEL_VERSION}" 2>/dev/null || true
systemctl restart ghost-awg-dkms-check.service >/dev/null 2>&1 || true
EOF
    chmod +x /etc/kernel/postinst.d/amneziawg-dkms
}

freeze_kernel_meta_packages() {
    [[ "${KERNEL_HOLD:-0}" == "1" ]] || return 0

    local arch pkg
    local pkgs=()
    local installed=()

    arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
    case "${arch}" in
        amd64|x86_64) pkgs=(linux-image-amd64 linux-headers-amd64) ;;
        arm64|aarch64) pkgs=(linux-image-arm64 linux-headers-arm64) ;;
        *)
            warn "KERNEL_HOLD=1 但架构 ${arch} 未内置冻结元包名，请手动确认 linux-image/linux-headers 元包"
            return 0
            ;;
    esac

    for pkg in "${pkgs[@]}"; do
        if dpkg -s "${pkg}" >/dev/null 2>&1; then
            installed+=("${pkg}")
        else
            warn "内核冻结跳过未安装元包: ${pkg}"
        fi
    done

    if [[ "${#installed[@]}" -eq 0 ]]; then
        warn "KERNEL_HOLD=1 但未找到可冻结的内核元包"
        return 0
    fi

    if apt-mark hold "${installed[@]}" >/dev/null; then
        info "已冻结内核元包: ${installed[*]}"
    else
        warn "apt-mark hold 执行失败，请手动检查: ${installed[*]}"
    fi
}

print_result() {
    echo ""
    echo "========== AMNEZIAWG_DKMS_OK =========="
    echo "script_version=${VERSION}"
    echo "module=${MODULE_NAME}"
    echo "kernel=$(uname -r)"
    echo "arch=$(uname -m)"
    echo "awg_dkms_ref=${AWG_DKMS_REF}"
    echo "awg_tools_ref=${AWG_TOOLS_REF}"
    if grep -qx "${AWG_DKMS_REF}" "${REF_STATE_FILE}" 2>/dev/null; then
        echo "ref_matched=true"
    else
        echo "ref_matched=false"
    fi
    modinfo "${MODULE_NAME}" | awk -F: '/^(filename|version|vermagic):/ {gsub(/^[ \t]+/, "", $2); print $1"="$2}'
    echo "======================================="
    echo "稳定建议：生产机器不要主动 dist-upgrade 或更换内核；如需冻结内核元包，可手动执行："
    case "$(uname -m)" in
        x86_64|amd64) echo "  apt-mark hold linux-image-amd64 linux-headers-amd64" ;;
        aarch64|arm64) echo "  apt-mark hold linux-image-arm64 linux-headers-arm64" ;;
        *) echo "  apt-mark hold linux-image-$(dpkg --print-architecture) linux-headers-$(dpkg --print-architecture)" ;;
    esac
}

main() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        print_help
        exit 0
    fi

    require_root
    detect_platform
    check_kernel_compatibility || exit 1
    install_packages || { warn "头文件安装失败，调用方将回退"; exit 1; }
    check_kernel_symbols || {
        warn "内核符号预检失败，继续尝试 DKMS 编译；失败后由落地机回退 amneziawg-go"
        [[ "${STRICT_KERNEL_SYMBOL_CHECK:-0}" == "1" ]] && exit 1
        true
    }
    install_module
    ensure_module_autoload
    ensure_awg_quick
    ensure_health_service
    freeze_kernel_meta_packages
    print_result
}

main "$@"
