# Ghost-Proxy

Ghost-Proxy 是一套 Debian 12 双机链式代理安装脚本：

- `install_transit.sh`：中转机，仅做 nftables L4 转发。
- `install_landing.sh`：落地机，部署 AmneziaWG + Shadowsocks-2022 双轨节点。
- `install_amneziawg_dkms.sh`：独立 DKMS 安装 AmneziaWG 内核模块，可单独调用，也可由落地机脚本自动调用。

当前稳定版本：`v6.86`

仓库保留稳定入口和最新审查版本快照。旧版本通过 Git 历史回溯，默认使用无版本后缀的稳定入口。

## 项目结构

```text
install_transit.sh              # 中转机稳定入口，当前同步到 v6.86
install_landing.sh              # 落地机稳定入口，当前同步到 v6.86
install_amneziawg_dkms.sh       # AmneziaWG DKMS 独立入口，当前同步到 v6.86
install_transit_v6.86.sh        # v6.86 中转机版本快照
install_landing_v6.86.sh        # v6.86 落地机版本快照
install_amneziawg_dkms_v6.86.sh # v6.86 DKMS 版本快照
dd_debian.sh                    # Debian 12.14 DD 辅助命令生成器，默认不执行
verify_installation.sh          # 安装后验证脚本
versions.conf                   # 依赖和上游源码 ref 固定配置
zhubi.md                        # 主笔修复记录
docs/alternative-solutions.md   # 备用方案评判
```

## 推荐系统基线

推荐使用 Debian 12 Bookworm minimal（当前稳定点版本 12.14）作为中转机和落地机基线。脚本不会自动 DD 或清盘，下面命令仅作为新机重装参考，执行前必须确认 VPS 商救援方式和 SSH 端口：

先获取上游 DD 脚本 SHA256，再使用仓库内辅助脚本执行。未设置 SHA256 时，`dd_debian.sh` 只打印下载和校验命令，不会执行清盘：

```bash
# x86_64 / amd64
curl -fsSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh | sha256sum
BIN456789_REINSTALL_SHA256='<上一步得到的sha256>' \
  bash dd_debian.sh --arch amd64 --port 22 --execute
```

ARM64：

```bash
curl -fsSL https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh | sha256sum
LEITBOGIORO_REINSTALL_SHA256='<上一步得到的sha256>' \
  bash dd_debian.sh --arch arm64 --port 22 --execute
```

也可以使用仓库内辅助脚本生成命令。默认只打印，不会执行清盘：

```bash
bash dd_debian.sh --arch amd64 --port 22
```

生产机器建议避免主动 `dist-upgrade` 或更换内核；如追求极稳，可在理解安全更新影响后按架构手动冻结内核元包：

```bash
# x86_64
apt-mark hold linux-image-amd64 linux-headers-amd64

# ARM64
apt-mark hold linux-image-arm64 linux-headers-arm64
```

也可以在单独运行 DKMS 脚本时显式选择自动冻结：

```bash
KERNEL_HOLD=1 bash install_amneziawg_dkms.sh
```

## 安装

中转机：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/install_transit.sh)
```

落地机：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/install_landing.sh)
```

单独安装 AmneziaWG DKMS：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/install_amneziawg_dkms.sh)
```

## Sub-Store / Mihomo

落地机安装完成后，入口分三类，不要混用：

1. Mihomo 直导：复制完整 Base64，一键导入完整 Profile。

```bash
cat /etc/landing-ghost/clash-meta-subscription.txt
```

2. Sub-Store 节点 Provider：推荐使用 provider-only 分离法。先在 ClashMeta/Mihomo 基础配置静态注入 `AWG-Tunnel`，再让 Sub-Store 只输出主轨/备轨。

```bash
cat /etc/landing-ghost/mihomo-static-awg-proxy.yaml
cat /etc/landing-ghost/substore-provider-only.yaml
cat /etc/landing-ghost/substore-import-guide.txt
```

ClashMeta 订阅侧引用 Sub-Store 输出链接时，建议隐藏底层隧道并只选择可见节点：

```yaml
proxy-providers:
  ghost:
    type: http
    url: "你的 Sub-Store 输出链接"
    path: ./providers/ghost.yaml
    exclude-filter: '^AWG-Tunnel$'

proxy-groups:
  - name: 自动切换
    type: fallback
    use: [ghost]
    filter: '^(主轨-UDP极速|备轨-TCP稳定)$'
```

3. 自洽 Provider：只在确认 Sub-Store/客户端保留 `hidden` 和 `dialer-proxy` 字段时使用。

```bash
cat /etc/landing-ghost/substore-awg-for-mihomo.yaml
```

`substore-mihomo-full.yaml` 是完整 Mihomo Profile，可用于直导或完整模板，不要当作 Sub-Store 节点 Provider。

## 版本固定（可选）

`versions.conf` 用于固定 DKMS、GCC、sing-box 和 AmneziaWG 源码 ref。通过 `bash <(curl ...)` 运行时只能使用脚本内置默认值；如需自定义固定版本，请把脚本和 `versions.conf` 下载到同一目录后运行：

```bash
curl -O https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/install_landing.sh
curl -O https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/install_amneziawg_dkms.sh
curl -O https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/versions.conf
bash install_landing.sh
```

可固定字段：`DKMS_VERSION`、`GCC_VERSION`、`GOLANG_VERSION`、`GO_TOOLCHAIN_VERSION`、`GO_TOOLCHAIN_SHA256_AMD64`、`GO_TOOLCHAIN_SHA256_ARM64`、`PKG_CONFIG_VERSION`、`LIBMNL_DEV_VERSION`、`SINGBOX_VERSION`、`AWG_DKMS_REF`、`AWG_TOOLS_REF`、`AWG_GO_REF`。留空表示使用系统仓库或上游默认版本。

预编译用户态兜底字段：`PREBUILT_AWG_GO_URL_x86_64`、`PREBUILT_AWG_GO_SHA256_x86_64`、`PREBUILT_AWG_TOOLS_URL_x86_64`、`PREBUILT_AWG_TOOLS_SHA256_x86_64`、`PREBUILT_AWG_GO_URL_arm64`、`PREBUILT_AWG_GO_SHA256_arm64`、`PREBUILT_AWG_TOOLS_URL_arm64`、`PREBUILT_AWG_TOOLS_SHA256_arm64`。当前默认使用 v6.85 Release 产物；下载或校验失败时，脚本会自动回退源码编译。

仓库包含 `.github/workflows/build-awg.yml`，可手动触发或在 tag 发布时构建 amd64/arm64 用户态产物。更新预编译产物时，必须先发布 Release，再把真实 SHA256 回填到 `versions.conf` 和稳定入口脚本。

## 安装后验证

落地机：

```bash
curl -fsSL https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/verify_installation.sh | bash -s landing
```

中转机：

```bash
curl -fsSL https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/verify_installation.sh | bash -s transit
```

## 卸载

中转机：

```bash
bash install_transit.sh --uninstall
```

落地机：

```bash
bash install_landing.sh --uninstall
```

## 关键说明

- 不提供 HTTP 订阅服务；落地机安装完成后只打印一条 `cat /etc/landing-ghost/clash-meta-config.yaml` 命令，用于完整显示可直接导入 Mihomo/Clash Meta 的双轨配置。
- 其他 YAML/JSON/JS 文件仅保留给调试和历史兼容，不作为用户导入入口。
- AmneziaWG DKMS 失败时，落地机脚本会回退到支持混淆的 `amneziawg-go`。
- 不回退到无混淆的标准 WireGuard。
- 中转机不安装应用层代理，只负责端口转发。
- 落地机和中转机均默认禁用 IPv6，减少泄漏风险。
- `zhubi.md` 记录每轮主笔修复摘要，供审查 AI 继续审查。
