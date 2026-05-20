# Ghost-Proxy 备用方案评判

当前默认方案仍是双轨：中转机纯 nftables，落地机 AmneziaWG + Shadowsocks-2022。

## 可以作为备用

| 方案 | 结论 | 原因 |
| --- | --- | --- |
| 预编译用户态 amneziawg-go + awg-tools | 采纳 | 不绑定内核 vermagic，适合 DKMS 失败后的快速回退。产物应放 GitHub Releases，并在 `versions.conf` 填 URL + SHA256。 |
| AWG-only 单轨 | 可后续单独脚本 | 更薄、更省资源，但没有 SS 备轨；适合作为实验备用，不替代默认双轨。 |
| DD 到 Debian 12.14 | 采纳为辅助脚本 | 标准化系统基线能降低 DKMS 失败率，但必须由用户显式确认，不能在安装脚本中自动清盘。 |

## 不建议并入默认

| 方案 | 结论 | 原因 |
| --- | --- | --- |
| 预编译 `.ko` 内核模块 | 驳回 | 内核模块强绑定 kernel ABI/vermagic，跨 VPS 不可靠，误用风险高。 |
| 中转机 Nginx/Gost/Xray/Haproxy/sing-box | 驳回 | 违背中转机只做 L4 转发的低暴露原则。 |
| HTTP 订阅或面板 | 驳回 | 增加 Web 暴露面，违背本项目导入方式红线。 |
| 标准 WireGuard 回退 | 驳回 | 无 AmneziaWG 混淆能力，不能作为最终回退。 |

结论：默认双轨方案不更换；备用建设优先补齐 Release 预编译用户态产物，其次再考虑独立 AWG-only 脚本。
