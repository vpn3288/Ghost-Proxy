# Ghost-Proxy

Ghost-Proxy 是一套 Debian 12 双机链式代理安装脚本：

- `install_transit.sh`：中转机，仅做 nftables L4 转发。
- `install_landing.sh`：落地机，部署 AmneziaWG + Shadowsocks-2022 双轨节点。
- `install_amneziawg_dkms.sh`：独立 DKMS 安装 AmneziaWG 内核模块，可单独调用，也可由落地机脚本自动调用。

当前稳定版本：`v6.39`

仓库只保留稳定入口和最近审查版本：`v6.37`、`v6.38`、`v6.39`。更早版本已清理，避免误用旧脚本。

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

- 不提供 HTTP 订阅服务；落地机安装完成后直接输出 YAML 和 Base64 导入块。
- AmneziaWG DKMS 失败时，落地机脚本会回退到支持混淆的 `amneziawg-go`。
- 不回退到无混淆的标准 WireGuard。
- 中转机不安装应用层代理，只负责端口转发。
- 落地机和中转机均默认禁用 IPv6，减少泄漏风险。
- `zhubi.md` 记录每轮主笔修复摘要，供审查 AI 继续审查。
