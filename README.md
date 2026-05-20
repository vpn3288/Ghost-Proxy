# Ghost-Proxy

Ghost-Proxy 是一套 Debian 12 双机链式代理安装脚本：

- `install_transit.sh`：中转机，仅做 nftables L4 转发。
- `install_landing.sh`：落地机，部署 AmneziaWG + Shadowsocks-2022 双轨节点。
- `install_amneziawg_dkms.sh`：独立 DKMS 安装 AmneziaWG 内核模块，可单独调用，也可由落地机脚本自动调用。

当前稳定版本：`v6.44`

仓库保留稳定入口和最近审查版本：`v6.37`、`v6.38`、`v6.39`、`v6.40`、`v6.41`、`v6.42`、`v6.43`、`v6.44`。更早版本已清理，避免误用旧脚本。

## 推荐系统基线

推荐使用 Debian 12 Bookworm minimal（当前稳定点版本 12.14）作为中转机和落地机基线。脚本不会自动 DD 或清盘，下面命令仅作为新机重装参考，执行前必须确认 VPS 商救援方式和 SSH 端口：

```bash
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
bash reinstall.sh debian 12 --ssh-port 22
```

x86_64 备用 DD 脚本示例（MoeClub）：

```bash
wget --no-check-certificate -O InstallNET.sh https://github.com/MoeClub/Note/raw/master/InstallNET.sh
bash InstallNET.sh -debian 12 -v 64 -p "自定义密码" -port 22
```

ARM64 备用 DD 脚本示例（leitbogioro）：

```bash
wget --no-check-certificate -qO InstallNET.sh https://raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh
bash InstallNET.sh -debian 12
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

- 不提供 HTTP 订阅服务；落地机安装完成后默认只输出 Base64 导入块，完整 YAML 保存在本机文件。
- AmneziaWG DKMS 失败时，落地机脚本会回退到支持混淆的 `amneziawg-go`。
- 不回退到无混淆的标准 WireGuard。
- 中转机不安装应用层代理，只负责端口转发。
- 落地机和中转机均默认禁用 IPv6，减少泄漏风险。
- `zhubi.md` 记录每轮主笔修复摘要，供审查 AI 继续审查。
