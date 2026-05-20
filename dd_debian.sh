#!/usr/bin/env bash
set -euo pipefail

VERSION="6.54"

usage() {
    cat <<EOF
用法: bash dd_debian.sh --password <SSH密码> [--arch amd64|arm64] [--port SSH端口] [--execute]

说明:
  默认只打印推荐 DD 命令，不会清盘。
  加 --execute 后会二次确认并在 10 秒倒计时后执行；执行前必须提供对应脚本 SHA256。
  DD/网络重装会清空服务器，仅限新机或已确认救援能力的机器。
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

[[ -n "${SSH_PASSWORD}" ]] || { usage; die "必须提供 --password"; }
[[ "${SSH_PORT}" =~ ^[0-9]+$ && "${SSH_PORT}" -ge 1 && "${SSH_PORT}" -le 65535 ]] || die "SSH 端口无效: ${SSH_PORT}"
if [[ "${SSH_PASSWORD}" =~ [\'\"\`\$\\\;\&\|\<\>\(\)] ]]; then
    die "SSH 密码包含不适合嵌入 DD 命令的字符，请换用字母、数字和常见安全标点"
fi

case "${ARCH}" in
    x86_64|amd64)
        ARCH="amd64"
        SCRIPT_URL="https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
        SCRIPT_SHA256="${BIN456789_REINSTALL_SHA256:-}"
        SCRIPT_ARGS=(debian 12.14 --password "${SSH_PASSWORD}" --ssh-port "${SSH_PORT}")
        DD_CMD="curl -fsSLO ${SCRIPT_URL} && sha256sum reinstall.sh && bash reinstall.sh debian 12.14 --password '${SSH_PASSWORD}' --ssh-port '${SSH_PORT}'"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        SCRIPT_URL="https://raw.githubusercontent.com/leitbogioro/Tools/master/Reinstall/reinstall.sh"
        SCRIPT_SHA256="${LEITBOGIORO_REINSTALL_SHA256:-}"
        SCRIPT_ARGS=(Debian 12 --password "${SSH_PASSWORD}" --ssh-port "${SSH_PORT}")
        DD_CMD="curl -fsSL '${SCRIPT_URL}' -o reinstall.sh && sha256sum reinstall.sh && bash reinstall.sh Debian 12 --password '${SSH_PASSWORD}' --ssh-port '${SSH_PORT}'"
        ;;
    *)
        die "不支持的架构: ${ARCH}，请显式使用 --arch amd64 或 --arch arm64"
        ;;
esac

cat <<EOF
Ghost-Proxy DD 辅助脚本 v${VERSION}

推荐系统基线:
  Debian 12.14 Bookworm minimal

目标架构:
  ${ARCH}

建议在新的 SSH 会话中执行以下命令，避免当前会话断开后无法观察输出:

${DD_CMD}

DD 完成后验证:
  ssh -p ${SSH_PORT} root@<服务器IP>
  cat /etc/debian_version
  uname -r
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
