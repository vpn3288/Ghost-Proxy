#!/usr/bin/env bash
set -euo pipefail

VERSION="6.83"

usage() {
    cat <<EOF
用法: bash dd_debian.sh [--password <SSH密码>] [--arch amd64|arm64] [--port SSH端口] [--execute]

说明:
  默认只打印推荐 DD 命令，不会清盘。
  加 --execute 后会二次确认并在 10 秒倒计时后执行；执行前必须提供对应脚本 SHA256。
  DD/网络重装会清空服务器，仅限新机或已确认救援能力的机器。

环境变量（--execute 模式必需）:
  BIN456789_REINSTALL_SHA256=<sha256>    # amd64 使用
  LEITBOGIORO_REINSTALL_SHA256=<sha256>  # arm64 使用

获取当前上游脚本 SHA256:
  amd64: curl -fsSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh | sha256sum
  arm64: curl -fsSL https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh | sha256sum

安全执行示例:
  BIN456789_REINSTALL_SHA256=<sha256> bash dd_debian.sh --arch amd64 --execute
  LEITBOGIORO_REINSTALL_SHA256=<sha256> bash dd_debian.sh --arch arm64 --execute
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

SSH_PASSWORD=""
ARCH="$(uname -m)"
SSH_PORT="22"
EXECUTE=0
SCRIPT_URL=""
SCRIPT_SHA256=""
SCRIPT_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --password)
            SSH_PASSWORD="${2:-}"
            shift 2
            ;;
        --arch)
            ARCH="${2:-}"
            shift 2
            ;;
        --port)
            SSH_PORT="${2:-}"
            shift 2
            ;;
        --execute)
            EXECUTE=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            die "未知参数: $1"
            ;;
    esac
done

if [[ -z "${SSH_PASSWORD}" ]]; then
    if [[ "${EXECUTE}" == "1" && -t 0 ]]; then
        read -r -s -p "请输入 DD 后 root SSH 密码（不回显）: " SSH_PASSWORD
        echo
    elif [[ "${EXECUTE}" == "1" ]]; then
        usage
        die "--execute 模式必须提供 --password"
    else
        SSH_PASSWORD="<SSH密码>"
    fi
fi
[[ -n "${SSH_PASSWORD}" ]] || die "SSH 密码不能为空"
[[ "${SSH_PORT}" =~ ^[0-9]+$ && "${SSH_PORT}" -ge 1 && "${SSH_PORT}" -le 65535 ]] || die "SSH 端口无效: ${SSH_PORT}"
if [[ "${SSH_PASSWORD}" != "<SSH密码>" && "${SSH_PASSWORD}" =~ [\'\"\`\$\\\;\&\|\<\>\(\)] ]]; then
    die "SSH 密码包含不适合嵌入 DD 命令的字符，请换用字母、数字和常见安全标点"
fi

case "${ARCH}" in
    x86_64|amd64)
        ARCH="amd64"
        SCRIPT_URL="https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
        SCRIPT_SHA256="${BIN456789_REINSTALL_SHA256:-}"
        SCRIPT_ARGS=(debian 12 --password "${SSH_PASSWORD}" --ssh-port "${SSH_PORT}")
        DD_CMD="curl -fsSLO ${SCRIPT_URL} && sha256sum reinstall.sh"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        SCRIPT_URL="https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh"
        SCRIPT_SHA256="${LEITBOGIORO_REINSTALL_SHA256:-}"
        SCRIPT_ARGS=(-Debian 12 -pwd "${SSH_PASSWORD}" -port "${SSH_PORT}")
        DD_CMD="curl -fsSL '${SCRIPT_URL}' -o InstallNET.sh && sha256sum InstallNET.sh"
        ;;
    *)
        echo "当前架构: ${ARCH}" >&2
        echo "支持的架构: amd64 (x86_64), arm64 (aarch64)" >&2
        echo "请使用 --arch 参数显式指定，例如:" >&2
        echo "  bash dd_debian.sh --arch amd64" >&2
        die "不支持的架构: ${ARCH}"
        ;;
esac

if [[ -n "${SCRIPT_SHA256}" ]]; then
    case "${ARCH}" in
        amd64)
            DD_CMD="curl -fsSLO ${SCRIPT_URL} && printf '%s  %s\n' '${SCRIPT_SHA256}' reinstall.sh | sha256sum -c - && bash reinstall.sh debian 12 --password '${SSH_PASSWORD}' --ssh-port '${SSH_PORT}'"
            ;;
        arm64)
            DD_CMD="curl -fsSL '${SCRIPT_URL}' -o InstallNET.sh && printf '%s  %s\n' '${SCRIPT_SHA256}' InstallNET.sh | sha256sum -c - && bash InstallNET.sh -Debian 12 -pwd '${SSH_PASSWORD}' -port '${SSH_PORT}'"
            ;;
    esac
fi

cat <<EOF
Ghost-Proxy DD 辅助脚本 v${VERSION}

推荐系统基线:
  Debian 12.14 Bookworm minimal
  DD 参数统一使用 Debian 12；DD 后用 cat /etc/debian_version 确认小版本，必要时 apt update && apt full-upgrade。

目标架构:
  ${ARCH}

建议在新的 SSH 会话中执行以下命令，避免当前会话断开后无法观察输出:

${DD_CMD}

$(if [[ -z "${SCRIPT_SHA256}" ]]; then cat <<'NOSHA'
当前未设置对应 SHA256 环境变量，上面的命令只下载并显示校验值，不会直接执行清盘脚本。
确认 SHA256 后再按 usage 示例设置环境变量并追加 --execute。
NOSHA
fi)

DD 完成后验证:
  ssh -p ${SSH_PORT} root@<服务器IP>
  cat /etc/debian_version
  uname -r
  apt-get update
  apt-get install -y linux-headers-\$(uname -r) dkms gcc-12

说明:
  若 cat /etc/debian_version 不是 12.14，先不要继续安装落地机。
  请确认 apt 源可用并补齐 headers/dkms/gcc-12 后，再运行 Ghost-Proxy 脚本。
EOF

if [[ "${EXECUTE}" != "1" ]]; then
    exit 0
fi

echo ""
echo "危险操作确认: 即将执行 DD/网络重装，服务器磁盘会被清空。"
for second in $(seq 10 -1 1); do
    echo "  ${second} 秒后可确认，按 Ctrl-C 取消..."
    sleep 1
done

read -r -p "请输入 DD-DEBIAN 继续执行: " confirm
[[ "${confirm}" == "DD-DEBIAN" ]] || die "确认文本不匹配，已取消"

[[ -n "${SCRIPT_SHA256}" ]] || die "为避免执行未校验的清盘脚本，--execute 需要设置 ${ARCH} 对应 SHA256 环境变量：BIN456789_REINSTALL_SHA256 或 LEITBOGIORO_REINSTALL_SHA256"

tmp_script="$(mktemp)"
trap 'rm -f "${tmp_script}"' EXIT
curl -fsSL "${SCRIPT_URL}" -o "${tmp_script}"
printf '%s  %s\n' "${SCRIPT_SHA256}" "${tmp_script}" | sha256sum -c -
bash "${tmp_script}" "${SCRIPT_ARGS[@]}"
