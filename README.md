# Ghost-Proxy

Ghost-Proxy 是一套 Debian 12 双机链式代理安装脚本：

- `install_transit.sh`：中转机，仅做 nftables L4 转发。
- `install_landing.sh`：落地机，部署 AmneziaWG + Shadowsocks-2022 双轨节点。
- `install_amneziawg_dkms.sh`：独立 DKMS 安装 AmneziaWG 内核模块，可单独调用，也可由落地机脚本自动调用。

当前稳定版本：`v6.72`

仓库保留稳定入口和最新审查版本快照。旧版本通过 Git 历史回溯，默认使用无版本后缀的稳定入口。

## 项目结构

```text
install_transit.sh              # 中转机稳定入口，当前同步到 v6.72
install_landing.sh              # 落地机稳定入口，当前同步到 v6.72
install_amneziawg_dkms.sh       # AmneziaWG DKMS 独立入口，当前同步到 v6.72
install_transit_v6.72.sh        # v6.72 中转机版本快照
install_landing_v6.72.sh        # v6.72 落地机版本快照
install_amneziawg_dkms_v6.72.sh # v6.72 DKMS 版本快照
dd_debian.sh                    # Debian 12.14 DD 辅助命令生成器，默认不执行
verify_installation.sh          # 安装后验证脚本
versions.conf                   # 依赖和上游源码 ref 固定配置
zhubi.md                        # 主笔修复记录
docs/alternative-solutions.md   # 备用方案评判
```

## 推荐系统基线

推荐使用 Debian 12 Bookworm minimal（当前稳定点版本 12.14）作为中转机和落地机基线。脚本不会自动 DD 或清盘，下面命令仅作为新机重装参考，执行前必须确认 VPS 商救援方式和 SSH 端口：

```bash
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
bash reinstall.sh debian 12.14 --ssh-port 22
```

x86_64 备用 DD 脚本示例（MoeClub）：

```bash
bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/MoeClub/Note/master/InstallNET.sh') \
  -d 12 -v 64 -a -p 'your-ssh-password'
```

ARM64 备用 DD 脚本示例（leitbogioro）：

```bash
bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/leitbogioro/Tools/master/Reinstall/reinstall.sh') \
  Debian 12
```

也可以使用仓库内辅助脚本生成命令。默认只打印，不会执行清盘：

```bash
bash dd_debian.sh --password 'your-ssh-password' --arch amd64 --port 22
```

生产机器建议避免主动 `dist-upgrade` 或更换内核；如追求极稳，可在理解安全更新影响后按架构手动冻结内核元包：

```bash
# x86_64
apt-mark hold linux-image-amd64 linux-headers-amd64

# ARM64
apt-mark hold linux-image-arm64 linux-headers-arm64
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

## 版本固定（可选）

`versions.conf` 用于固定 DKMS、GCC、sing-box 和 AmneziaWG 源码 ref。通过 `bash <(curl ...)` 运行时只能使用脚本内置默认值；如需自定义固定版本，请把脚本和 `versions.conf` 下载到同一目录后运行：

```bash
curl -O https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/install_landing.sh
curl -O https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/install_amneziawg_dkms.sh
curl -O https://raw.githubusercontent.com/vpn3288/Ghost-Proxy/main/versions.conf
bash install_landing.sh
```

可固定字段：`DKMS_VERSION`、`GCC_VERSION`、`SINGBOX_VERSION`、`AWG_DKMS_REF`、`AWG_TOOLS_REF`、`AWG_GO_REF`。留空表示使用系统仓库或上游默认版本。

可选预编译用户态兜底字段：`PREBUILT_AWG_GO_URL_x86_64`、`PREBUILT_AWG_GO_SHA256_x86_64`、`PREBUILT_AWG_TOOLS_URL_x86_64`、`PREBUILT_AWG_TOOLS_SHA256_x86_64`、`PREBUILT_AWG_GO_URL_arm64`、`PREBUILT_AWG_GO_SHA256_arm64`、`PREBUILT_AWG_TOOLS_URL_arm64`、`PREBUILT_AWG_TOOLS_SHA256_arm64`。未发布 Release 资产前保持留空，脚本会自动回退源码编译。

仓库包含 `.github/workflows/build-awg.yml`，可手动触发或在 tag 发布时构建 amd64/arm64 用户态产物。Release 产物真实发布并核对 SHA256 后，再填入 `versions.conf`。

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

- 不提供 HTTP 订阅服务；落地机安装完成后直接打印 Sub-Store Clash Proxies YAML 和逐行 JSON。
- AmneziaWG DKMS 失败时，落地机脚本会回退到支持混淆的 `amneziawg-go`。
- 不回退到无混淆的标准 WireGuard。
- 中转机不安装应用层代理，只负责端口转发。
- 落地机和中转机均默认禁用 IPv6，减少泄漏风险。
- `zhubi.md` 记录每轮主笔修复摘要，供审查 AI 继续审查。
