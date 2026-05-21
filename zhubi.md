# Ghost-Proxy 主笔记录

## 当前版本

- 版本：v6.91 (2026-05-22)
- 稳定入口：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`
- 当前快照：`install_landing_v6.91.sh`、`install_transit_v6.91.sh`、`install_amneziawg_dkms_v6.91.sh`
- 历史记录：`docs/history.md`

## v6.91 清理记录

- 清理仓库旧版本脚本：删除 v6.78-v6.90 的版本快照，只保留当前 v6.91 快照；旧版本通过 Git 历史追溯。
- 精简 `zhubi.md`：只保留当前版本、关键红线和最近修复摘要；长历史归档到 `docs/history.md`。
- README 同步 v6.91 项目结构，避免审查时把旧快照误认为当前交付面。

## 最近关键修复

- v6.90：`verify_installation.sh landing` 支持 `SUBSTORE_URL`，可拉取 Sub-Store 输出并临时组合 Mihomo 配置做端到端校验。
- v6.90：`clash-meta-substore-base.yaml` 使用醒目占位符 `REPLACE-WITH-YOUR-SUBSTORE-OUTPUT-LINK`，明确 Ghost-Proxy VPS 不提供 HTTP 订阅。
- v6.90：默认导入入口收敛为 Mihomo 直导与 Sub-Store 指南；Provider/Base64/自洽 Provider 放到 `show-ghost-nodes --advanced`。
- v6.90：Sub-Store provider-only 保持主轨/备轨分离；备轨显式 `udp-over-tcp: true`；`substore-copy.txt` 为纯 provider-only YAML。
- v6.90：预编译 AWG 用户态资产增加 manifest/ref 校验，避免旧 Release 资产与当前源码 ref 错配。

## 不得破坏的红线

- 不回退普通 WireGuard；DKMS 不可用时只能回退支持混淆的 `amneziawg-go`。
- `install_amneziawg_dkms.sh` 必须保持独立，不塞回落地机或中转机脚本。
- 中转机只做 nftables L4 转发，不安装 Nginx/Gost/Xray/Haproxy/sing-box 等应用层中转。
- 不在 Ghost-Proxy VPS 上提供 HTTP 订阅服务；只输出本地文件/Base64/复制粘贴内容。
- 默认禁用 IPv6，同时不得破坏 Docker、1Panel、证书申请和系统 DNS。
- 保留 AmneziaWG 混淆参数 `Jc/Jmin/Jmax/S1/S2/H1-H4`、Base64 完整 Profile 备用入口、多落地机能力和幂等性。

## 验证记录

- v6.91 已执行 `bash -n`：稳定入口、v6.91 快照、`verify_installation.sh`、`dd_debian.sh` 均通过；`git diff --check` 通过。
