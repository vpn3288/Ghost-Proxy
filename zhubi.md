# Ghost-Proxy 审核记录

# v6.63 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.63.sh`、`install_transit_v6.63.sh`、`install_amneziawg_dkms_v6.63.sh`，并同步稳定入口到 v6.63。
- ✅ 实机审计修复：`clash-meta-import-block.txt` 和 `clash-meta-subscription.txt` 含客户端私钥与 SS 密码，权限由默认 `644` 收紧为 `600`；保留本地终端复制和文件读取导入方式，不新增 HTTP 订阅。
- ✅ 低暴露审计：中转机未发现 Nginx/Gost/Xray/Haproxy/sing-box/Caddy/Trojan/V2Ray 进程或包，80/443/8080/8443 未监听；验证 0 失败 0 警告。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.63.sh`、`install_transit_v6.63.sh`、`install_amneziawg_dkms_v6.63.sh`、`dd_debian.sh`、`verify_installation.sh` 均通过。
- ✅ v6.63 实机复测：x86/ARM 落地机重跑后 `clash-meta-config.yaml`、`clash-meta-subscription.txt`、`clash-meta-import-block.txt` 均为 `600`，Base64 可解码且混淆字段完整；密钥/密码/混淆参数不漂移。
- ✅ 中转机同步 v6.63 后双落地验证 0 失败 0 警告，`systemctl --failed` 为 0；中转 8389/8390 可达，落地直连 8389 仍不可达。
- ✅ 中转完全卸载/重装复测：执行 `install_transit.sh --uninstall` 完全卸载后 Ghost nft 表、配置目录、管理工具均删除，nftables 服务保持 active；随后从清理状态用 `LANDING_LIST` 重装 v6.63，双落地配置恢复。
- ✅ 中转重装后全链路复核：中转验证 0 失败 0 警告，x86/ARM 落地验证 0 失败 0 警告；中转 8389/8390 可达，落地直连 8389 仍不可达。
- ✅ 失败恢复复测：x86 落地机重跑 v6.63 时故意设置 `SS_BACKUP_PORT=22` 触发端口占用失败；脚本在临停旧服务后由退出 trap 自动恢复 `awg-landing/ss-main/ss-backup/landing-health-check`，验证 0 失败 0 警告。
- ✅ 失败恢复后复核：中转机与 ARM 落地机均保持 0 失败 0 警告，双落地配置未受影响。
- ✅ x86 落地完全卸载/重装复测：执行 `install_landing.sh --uninstall` 完全卸载后服务停止、配置目录删除；随后从清理状态重装 v6.63 成功，验证 0 失败 0 警告，导入文件权限保持 `600`。
- ✅ x86 重装后全链路复核：中转机与 ARM 落地机均保持 0 失败 0 警告；中转 8389/8390 可达，落地直连 8389 仍不可达。完全卸载会生成新的 x86 客户端密钥和 SS 密码，这是预期行为。
- ✅ 落地防火墙幂等复测：x86/ARM 落地机重跑 v6.63 前后 `ghost-proxy-landing` 规则数保持 6，AWG/SS accept/drop 各 1，`GHOST_IPV6_INPUT` 跳转保持 1；未发现规则堆叠。
- ✅ 防火墙幂等后复核：两台落地验证 0 失败 0 警告，导入文件权限仍为 `600`；中转验证 0 失败 0 警告，中转 8389/8390 可达，落地直连 8389 仍不可达。
- ✅ v6.63 顺序重启复测：x86 落地、ARM 落地、中转机依次重启后均自动恢复；三台验证 0 失败 0 警告，`systemctl --failed` 均 0。
- ✅ 重启后安全复核：两台落地机导入文件权限保持 `600`，中转 nftables 配置语法通过；中转 8389/8390 可达，落地直连 8389 仍不可达。

# v6.62 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.62.sh`、`install_transit_v6.62.sh`、`install_amneziawg_dkms_v6.62.sh`，并同步稳定入口到 v6.62。
- ✅ 实机修复：x86 落地机 ifupdown 存在 `iface ens5 inet6 dhcp` 时，禁用 IPv6 会导致 `networking.service` 重启失败；现自动备份并注释 ifupdown 的 IPv6 stanza，保留 IPv4/DNS/Docker/1Panel 配置。
- ✅ 同步中转机：默认禁用 IPv6 前也执行同样的 ifupdown IPv6 DHCP 清理，避免 DD 系统模板残留 DHCPv6 配置造成系统服务 failed。
- ✅ 实机验证：v6.61 基线三机验证均 0 失败；发现并修复上述 networking failed 问题后进入 v6.62 复测。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.62.sh`、`install_transit_v6.62.sh`、`install_amneziawg_dkms_v6.62.sh`、`dd_debian.sh`、`verify_installation.sh` 均通过。
- ✅ v6.62 实机复测：x86 落地、ARM 落地、中转机重跑安装均成功；三台 `verify_installation.sh` 均 0 失败 0 警告；`systemctl --failed` 均 0；x86 `networking.service` 重启后为 active。
- ✅ 暴露面复测：中转 8389/8390 可达，落地直连 8389 不可达；中转/落地 AWG UDP 随机探测均无响应；错误输入测试不会停止既有服务。
- ✅ 卸载复测：ARM 落地机执行完全卸载后服务停止、配置目录删除；随后从清理状态重装 v6.62 成功，验证 0 失败 0 警告，中转双落地配置保持可用。
- ✅ 重启复测：ARM 落地、x86 落地、中转机依次重启后均自动恢复；三台验证 0 失败 0 警告，`systemctl --failed` 均 0；中转 SS 映射可达，落地 SS 直连仍不可达。
- ✅ 长跑复测：中转机连续 5 轮 `reload-rules` + `reload` 后配置 hash 不变、NAT 规则 hash 稳定，双落地仍可用。
- ✅ 幂等复测：x86/ARM 落地机重跑 v6.62 后 AWG 密钥、SS 密码、Jc/Jmin/Jmax/S1/S2/H1-H4 指纹均保持不变，验证 0 失败 0 警告。
- ✅ 健康检查故障注入：ARM 落地机停掉 `ss-main`、`ss-backup`、`awg-landing` 后，用临时快进版健康检查模拟连续失败，均能自动恢复；正式脚本未改动，最终验证 0 失败 0 警告。
- ✅ 故障注入后复核：中转机双落地仍可达，`systemctl --failed` 均 0；中转 8389/8390 可达，落地直连 8389 仍不可达。
- ✅ 中转 nft 故障注入：删除 `ghost_proxy_filter`/`ghost_proxy_nat` 两张 Ghost 专属表后，执行 `ghost-transit-ctl reload-rules` 可恢复；恢复后 nat/filter 规则 hash 与删除前一致，验证 0 失败 0 警告。
- ✅ nft 恢复后暴露面复核：中转 8389/8390 可达，落地直连 8389 不可达；中转/落地 AWG UDP 随机探测均无响应。
- ✅ DKMS 模块自愈注入：x86 落地机停止 `awg-landing/ss-main` 后卸载 `amneziawg` 模块，重新启动 `awg-landing` 可由 prestart 自动加载模块并恢复 `awg0`；落地和中转验证均 0 失败 0 警告。
- ✅ DKMS 自愈后暴露面复核：中转 8389/8390 可达，落地直连 8389 仍不可达，双落地配置未漂移。

# v6.61 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.61.sh`、`install_transit_v6.61.sh`、`install_amneziawg_dkms_v6.61.sh`，并同步稳定入口到 v6.61。
- ✅ 修复 P0：落地机内核后端增加 `/usr/local/bin/awg-landing-prestart.sh`，启动前先 `modprobe amneziawg`；若当前内核缺少模块，则调用独立 DKMS 脚本补构建当前内核后再加载。
- ✅ 修复 P1：`install_amneziawg_dkms.sh` 读取 `/etc/os-release` 不再覆盖脚本 `VERSION`，DKMS 成功摘要的 `script_version` 恢复为脚本版本号。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.61.sh`、`install_transit_v6.61.sh`、`install_amneziawg_dkms_v6.61.sh`、`dd_debian.sh`、`verify_installation.sh` 均通过。

# v6.60 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.60.sh`、`install_transit_v6.60.sh`、`install_amneziawg_dkms_v6.60.sh`，并同步稳定入口到 v6.60。
- ✅ 修复 P0：落地机内核 DKMS 后端的 `awg-landing.service` 启动前显式 `modprobe amneziawg`，避免重启后模块未自动加载导致 `ip link add awg0 type amneziawg` 失败。
- ✅ 修复 P2：`/etc/landing-ghost/awg0.conf` 写入后设为 `600`，消除 `awg-quick` 的 world accessible 警告。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.60.sh`、`install_transit_v6.60.sh`、`install_amneziawg_dkms_v6.60.sh`、`dd_debian.sh`、`verify_installation.sh` 均通过。

# v6.59 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.59.sh`、`install_transit_v6.59.sh`、`install_amneziawg_dkms_v6.59.sh`，并同步稳定入口到 v6.59。
- ✅ 修复 P0：落地机重跑时 `AUTO_INSTALL` 参数错误不再先临停旧服务；`LANDING_INDEX` 和端口类变量提前做纯校验。
- ✅ 修复 P0：如果重跑已临停旧服务但后续安装失败，退出 trap 会尝试恢复 `awg-landing/ss-main/ss-backup/landing-health-check`，避免错误输入导致可用服务下线。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.59.sh`、`install_transit_v6.59.sh`、`install_amneziawg_dkms_v6.59.sh`、`dd_debian.sh`、`verify_installation.sh` 均通过。

# v6.58 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.58.sh`、`install_transit_v6.58.sh`、`install_amneziawg_dkms_v6.58.sh`，并同步稳定入口到 v6.58。
- ✅ 修复 P1：中转机在 `LANDING_LIST/LANDING_IP` 非交互安装且 SSH 分配 PTY 时，不再因 `-t 0` 误判交互而等待连通性测试确认。
- ✅ 调整连通性测试开关：默认跳过；如需安装末尾主动测试，显式设置 `RUN_CONNECTIVITY_TEST=1`。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.58.sh`、`install_transit_v6.58.sh`、`install_amneziawg_dkms_v6.58.sh`、`dd_debian.sh`、`verify_installation.sh` 均通过。

# v6.57 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.57.sh`、`install_transit_v6.57.sh`、`install_amneziawg_dkms_v6.57.sh`，并同步稳定入口到 v6.57。
- ✅ 修复 P1/P2：中转机健康检查安装摘要改为真实节奏“首次 60-180 秒，之后 5-10 分钟”，避免继续显示旧的 30-60 分钟。
- ✅ 修复 P2：`SKIP_CONNECTIVITY_TEST=1` 才跳过中转连通性测试；非交互模式默认执行一次落地机连通性测试，便于自动化安装发现云防火墙阻断。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.57.sh`、`install_transit_v6.57.sh`、`install_amneziawg_dkms_v6.57.sh`、`dd_debian.sh`、`verify_installation.sh` 均通过。

# v6.56 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.56.sh`、`install_transit_v6.56.sh`、`install_amneziawg_dkms_v6.56.sh`，并同步稳定入口到 v6.56。
- ✅ 修复 P0：中转机 `ghost-transit-ctl reload-rules` 不再使用当前 nft 不兼容的 `destroy table inet ...`；仅在 Ghost 表已存在时生成 `delete table`，初次安装可直接加载规则。
- ✅ 保持中转机纯 nftables 架构，不清空第三方 ruleset，不引入任何应用层代理。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.56.sh`、`install_transit_v6.56.sh`、`install_amneziawg_dkms_v6.56.sh`、`dd_debian.sh`、`verify_installation.sh` 均通过。

# v6.55 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.55.sh`、`install_transit_v6.55.sh`、`install_amneziawg_dkms_v6.55.sh`，并同步稳定入口到 v6.55。
- ✅ 修复 P1：`verify_installation.sh landing` 改查真实 `/etc/landing-ghost/awg0.conf`，逐项校验 `Jc/Jmin/Jmax/S1/S2/H1-H4`，避免把成功安装误报为混淆缺失。
- ✅ 修复 P1/P2：验证脚本补充 Mihomo YAML `amnezia-wg-option/allowed-ips/dialer-proxy` 检查，并明确端到端连通性为软检查。
- ✅ 修复 P0/P1：交互模式中转监听端口默认值增加溢出保护；非 x86_64/arm64 架构下载 DKMS 脚本时不再拼接空架构后缀 URL。
- ✅ 修复 P1：既有 `amneziawg-go/awg/awg-quick` 兜底增加 `awg genkey` 最小能力检测，并在 DKMS/ref 回退路径耗尽前输出明确警告；仍拒绝普通 WireGuard。
- ✅ 修复 P1/P2：`ip6tables` 插入 Ghost IPv6 链失败会记录警告；中转健康检查首轮延迟缩短到 60-180 秒，循环间隔缩短到 5-10 分钟。
- ✅ 修复 P1/P2：`dd_debian.sh` 不支持架构时给出显式 `--arch` 示例；提供 SHA256 环境变量时默认打印 `sha256sum -c` 校验命令，并说明 amd64/arm64 DD 目标版本差异。
- ⏳ 暂缓：`versions.conf` 预编译 URL/SHA256 继续留空，必须等 GitHub Release 真实产物发布并核对校验后再填写；不伪造校验值。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.55.sh`、`install_transit_v6.55.sh`、`install_amneziawg_dkms_v6.55.sh`、`dd_debian.sh`、`verify_installation.sh` 均通过。

# v6.54 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.54.sh`、`install_transit_v6.54.sh`、`install_amneziawg_dkms_v6.54.sh`，并同步稳定入口到 v6.54。
- ✅ 修复 P1：中转机安装在 Ghost 规则原子加载后显式启动 `nftables`；`verify_installation.sh` 不再把“服务 inactive 但 Ghost 表已加载”误判为硬失败，并补查 NAT 关键钩子。
- ✅ 修复 P1：家宽网卡自动探测排除 Docker/桥接/veth/WG 类接口，只接受带默认路由和网关的私网出站口；策略路由验证失败时不再写入 sing-box `bind_interface`。
- ✅ 修复 P1：落地机卸载清理 `ghost-proxy-landing` 规则改用 `awk` 只跳过匹配的 `-A` 规则行，保留 iptables-save 表结构；1Panel 端口检测移除 `grep -P` 依赖。
- ✅ 修复 P1：DKMS 和源码编译用户态回退均失败时，最终再检测既有 `amneziawg-go/awg/awg-quick`，可用则继续使用，仍拒绝普通 WireGuard 回退。
- ✅ 修复 P1/P2：中转健康检查增加 5-15 分钟初始随机延迟；virtio/hyperv/xen 等虚拟网卡默认关闭 flowtable；公网 IP 输出支持 `PUBLIC_IP/LANDING_PUBLIC_IP/TRANSIT_PUBLIC_IP` 覆盖。
- ✅ 修复 P1/P2：DKMS 脚本 `apt-get update` 失败后尝试使用现有缓存继续安装，并支持 `SKIP_APT_UPDATE=1`；低内存无 swap 时临时 swap 提升到 2G，极低可用内存时 `MAKEFLAGS=-j1`。
- ✅ 修复 P1：`dd_debian.sh --execute` 不再直接执行未校验远程清盘脚本，必须提供对应 SHA256 环境变量后才会下载、校验并执行。
- ✅ 增强验证：`verify_installation.sh landing` 增加 AWG 混淆字段、Base64 导入块和 SS 主轨本机 TCP 探测；客户端未连接的端到端 ping 不作为硬失败。
- ⚖️ 评判：不自动执行 `apt-mark hold` 锁内核，避免阻断安全更新；继续在安装摘要中给出明确 hold 命令，由用户按生产策略决定。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.54.sh`、`install_transit_v6.54.sh`、`install_amneziawg_dkms_v6.54.sh`、`dd_debian.sh`、`verify_installation.sh` 均通过。

# v6.53 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.53.sh`、`install_transit_v6.53.sh`、`install_amneziawg_dkms_v6.53.sh`，并同步稳定入口到 v6.53。
- ✅ 修复 P1：`AUTO_INSTALL=1` 时 `LANDING_INDEX` 不再静默默认 1，必须显式传入，避免多落地机无人值守部署端口撞车。
- ✅ 修复 P1：中转机重跑检测到既有 `landings` 且未传入 `LANDING_LIST/LANDING_IP` 时默认保留并跳过新增，只更新管理工具和 nftables 规则。
- ✅ 修复 P1：中转机依赖安装增加 3 次重试；`ghost-transit-ctl status` 增加 Ghost filter/nat 表、关键规则数和规则文件更新时间。
- ✅ 修复 P1：落地机依赖显式安装 `iproute2`；`SS_PASSWORD` 校验放宽到常见 JSON/YAML 安全标点；`install_amneziawg_go()` 结束恢复目录失败时只警告并切到 `/`。
- ✅ 修复 P1：落地健康检查加入 `AWG_STABLE_WINDOW` 稳定窗口，AWG 恢复后连续稳定才清零失败计数，窗口期抖动不立即触发下一轮重启。
- ✅ 修复 P1/P2：DKMS 低内存临时 swap 创建失败时明确警告，调用方继续回退 `amneziawg-go`；中转健康检查 NAT 异常日志打印 prerouting/postrouting 摘要。
- ✅ 新增 `dd_debian.sh`：只生成 Debian 12.14/ARM64 Debian 12 DD 命令，默认不执行；`--execute` 必须倒计时和二次确认。
- ✅ 新增 `verify_installation.sh`：支持 `landing/transit` 安装后验证；README 和安装完成提示补充验证命令。
- ✅ 新增 `.github/workflows/build-awg.yml`：用于构建 amd64/arm64 预编译用户态 `amneziawg-go` + `awg-tools` Release artifacts。
- ✅ 新增 `docs/alternative-solutions.md`：采纳预编译用户态和 DD 辅助；AWG-only 仅作为后续独立备用；继续驳回预编译 `.ko`、HTTP 订阅、中转应用层代理和标准 WireGuard 回退。
- ⚖️ 评判：`install_amneziawg_dkms.sh` 继续保持跨架构通用；落地机下载 DKMS 脚本时预留未来架构后缀回退，但本轮不制造不存在的架构分裂脚本。
- ⏳ 暂缓：`versions.conf` 仍不填写预编译 URL/SHA256；必须等 GitHub Releases 真实产物发布并核对校验后再填。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.53.sh`、`install_transit_v6.53.sh`、`install_amneziawg_dkms_v6.53.sh`、`dd_debian.sh`、`verify_installation.sh` 均通过。

# v6.52 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.52.sh`、`install_transit_v6.52.sh`、`install_amneziawg_dkms_v6.52.sh`，并同步稳定入口到 v6.52。
- ✅ 修复 P0：中转机 `init_config()` 重跑时只更新 `version/ssh_port`，不再清空既有 `landings`。
- ✅ 修复 P1：`versions.conf` 默认只读取脚本同目录；如需读取当前目录必须显式设置 `ALLOW_CWD_VERSIONS=1` 并打印提示。
- ✅ 修复 P1：`awg-tools` 增加 `/var/lib/amneziawg-tools/ref`，复用 `awg/awg-quick` 前校验 `AWG_TOOLS_REF`，不匹配则重装。
- ✅ 修复 P1：`sing-box 1.11.0` 增加 amd64/arm64 SHA256 固定校验，下载后校验失败即退出。
- ✅ 修复 P1/P2：落地健康检查优先用 `systemctl show` 检测 `amneziawg-go` 后端；完全卸载时对含密码配置先 `shred`；中转磁盘预检阈值降为 100MB 并修正备份 glob 引用。
- ❌ 驳回：不把预编译 `.ko` 放入项目；内核模块强绑定 kernel/vermagic，风险高于收益。备用方案继续走“预编译用户态 `amneziawg-go` + `awg-tools` + SHA256”路径。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.52.sh`、`install_transit_v6.52.sh`、`install_amneziawg_dkms_v6.52.sh` 均通过。

# v6.51 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.51.sh`、`install_transit_v6.51.sh`、`install_amneziawg_dkms_v6.51.sh`，并同步稳定入口到 v6.51。
- ✅ 修复 P0/P1：`install_amneziawg_go()` 内部失败改为 `warn + return 1`，不再用 `die` 直接中断调用方；最终仍拒绝回退到普通 WireGuard。
- ✅ 修复 P1：预编译 `amneziawg-go` / `awg-tools` 拆分安装，任一 URL 配置后必须提供 SHA256；缺失或校验失败即跳过预编译并回退源码编译。
- ✅ 修复 P1：用户态 AWG 写入 `/var/lib/amneziawg-go/ref`，复用既有 `awg/awg-quick/amneziawg-go` 前必须匹配 `AWG_TOOLS_REF:AWG_GO_REF`。
- ✅ 修复 P1：`APPEND_PUBLIC_DNS=1` 在 `AUTO_INSTALL=1` 或 `SKIP_DNS_WARNING=1` 时不再强制等待 5 秒。
- ✅ 修复 P1：落地健康检查运行时从 `awg-landing.service` 检测 `amneziawg-go` 后端，避免安装时写死 `AWG_BACKEND`。
- ✅ 修复 P1：落地卸载在无 `iptables` 环境下跳过防火墙清理，避免 `set -e` 直接退出。
- ✅ 修复 P0/P1：中转卸载删除已移除目录下 `health_check.sh` 的重复 `rm`；`/etc/nftables.conf` 只有确认为 Ghost 专属 loader 时才删除，否则只移除 Ghost include。
- ❌ 驳回：不采纳 `nft rename table` 原子交换建议；当前 `load_ghost_rules()` 已用同一 nft batch 预检并加载，rename table 兼容性和语义风险更高。
- ❌ 暂缓：AWG-only、DD helper、GitHub Actions 预编译发布属于备用方案建设，不进入本轮主线修复。
- ✅ 已执行 `bash -n`：稳定入口和 v6.51 三个快照均通过。

# v6.50 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.50.sh`、`install_transit_v6.50.sh`、`install_amneziawg_dkms_v6.50.sh`，并同步稳定入口到 v6.50。
- ✅ 修复 P0：`install_landing.sh` 内置 `DEFAULT_AWG_DKMS_REF` 并初始化 `AWG_DKMS_REF`，避免 `bash <(curl ...)` 且已有模块时在 `set -u` 下退出。
- ✅ 采纳 P1：AWG 新混淆参数收窄为 `JC=4-8`、默认 `JMIN=50`、`JMAX=200`、`S1/S2` 小范围递增；已有参数继续幂等复用，需轮换时用 `FORCE_ROTATE_OBFS=1`。
- ✅ 采纳 P1：落地机健康检查写入 `AWG_BACKEND`，仅内核后端尝试 `modprobe amneziawg`；AWG 重启退避默认上限降为 300 秒，可用 `AWG_MAX_COOLDOWN` 覆盖。
- ✅ 采纳 P1：`install_amneziawg_dkms.sh` 在 `GITEE_MIRROR=1` 时增加 Gitee tarball 回退，失败后再回退 GitHub tarball。
- ✅ 采纳 P1：DKMS 自愈 systemd `ExecStart` 改为调用 `/usr/local/bin/awg-dkms-health.sh`，脚本运行时读取 `/var/lib/amneziawg-dkms/ref`。
- ✅ 采纳 P1：`ghost-transit-ctl add-landing` 写入配置后自动执行 `reload-rules`，失败时提示手动命令。
- ✅ 采纳 P1/P2：中转机默认 `DISABLE_ON_ICMP_FAIL=0` 且落地机已启用时跳过 ICMP 探测，减少周期性检测流量；禁用落地机仍会探测以便恢复。
- ✅ 采纳 P1：删除 `APPEND_PUBLIC_DNS=1` 路径残留的 `chattr -i /etc/resolv.conf`。
- ✅ 采纳 P1：清理 v6.46-v6.48 历史快照，仓库保留稳定入口、v6.49 与 v6.50 快照。
- ✅ 已执行 `bash -n`：稳定入口、v6.50 快照及仓库内保留的全部 `.sh` 均通过。
- ⚖️ 评判：预编译用户态 `amneziawg-go`/`awg-tools` 方案采纳，但不把二进制直接塞入 git，也不填写不存在的 Release URL/SHA256；待真实 GitHub Release artifacts 发布后再填 `versions.conf`。
- ❌ 驳回：预编译 `.ko` 内核模块继续不采纳，因 vermagic 与内核 ABI 强绑定，跨 VPS 不可靠。
- ❌ 驳回：Hysteria2/REALITY/WebSocket/CDN 等第三轨不进入默认主线，避免增加应用层暴露面；备用方案如需做，应单独脚本且不影响中转机纯 nftables。

# v6.49 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.49.sh`、`install_transit_v6.49.sh`、`install_amneziawg_dkms_v6.49.sh`，并同步稳定入口到 v6.49。
- ✅ 修复 P1：落地机 IPv6 防火墙不再设置 `OUTPUT DROP`；改为 `INPUT/OUTPUT` 默认 `ACCEPT`、`FORWARD DROP`，并用 `GHOST_IPV6_INPUT` 专属链阻断 IPv6 入站，降低 Docker/1Panel 冲突。
- ✅ 修复 P1：AWG 新装默认混淆参数改为 `JMIN=64`、`JMAX=256`，校验推荐范围为 `64 <= JMIN < JMAX <= 1024`；已有旧参数不静默轮换，仅提示，除非设置 `FORCE_ROTATE_OBFS=1`。
- ✅ 修复 P1：中转机 `load_ghost_rules()` 改为同一 nft 事务中 `destroy` Ghost 专属表并加载新规则，加载失败时不先删除旧规则；依赖补齐 `iproute2`、`iputils-ping`、`coreutils`、`util-linux`。
- ✅ 修复 P1/P2：`ensure_nft_main_conf()` 只维护 Ghost include，不再因旧 Ghost 标记重写整个 `/etc/nftables.conf`；健康检查遇到无效 `HEALTH_LOG_LEVEL` 会记录 WARN 并回退 `warn`。
- ✅ 小修：DKMS 输出新增 `ref_matched=true/false`；非 Debian 12 提示中补充 DD 命令；落地机卸载不再触碰 `/etc/resolv.conf` immutable 属性。
- ✅ 确认：`awg-landing.service` 已在 `AWG_BACKEND=go` 时注入 `WG_QUICK_USERSPACE_IMPLEMENTATION=amneziawg-go`，稳定入口无需重复修复。
- ❌ 暂缓：不在 `versions.conf` 填写预编译 URL/SHA256，直到 GitHub Releases 真实发布对应 artifacts；不加入预编译 `.ko`。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.49.sh`、`install_transit_v6.49.sh`、`install_amneziawg_dkms_v6.49.sh` 均通过。

# v6.48 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.48.sh`、`install_transit_v6.48.sh`、`install_amneziawg_dkms_v6.48.sh`，并同步稳定入口到 v6.48。
- ✅ 修复 P0：中转机 `ghost-transit-ctl reload-rules` 不再生成 `flush ruleset`，改用 `inet ghost_proxy_filter` / `inet ghost_proxy_nat` 专属表；加载前只删除 Ghost 表，`/etc/nftables.conf` 仅追加/维护 Ghost include，避免清空 Docker/1Panel/用户自建 nftables 规则。
- ✅ 修复 P1：中转健康检查启动后先执行首轮检查再进入 30-60 分钟随机睡眠；规则丢失检测改为检查 Ghost 专属表，恢复时不再 `restart nftables`。
- ✅ 修复 P1：落地机优先使用同目录 `install_amneziawg_dkms_v6.48.sh`，远程兜底也拉取同版本文件，避免稳定入口与 DKMS 脚本版本漂移；DKMS 自愈服务增加源码 ref 状态检测。
- ✅ 修复 P1：落地机卸载不再删除通用 lo/ESTABLISHED/SSH/Docker INPUT 规则，不再改默认策略；新防火墙规则加 `ghost-proxy-landing` 标记，卸载只清理 Ghost 标记和旧版端口残留。
- ✅ 稳定性小修：落地健康检查 AWG 重启指数退避上限从 300 秒提高到 3600 秒，减少长期故障时的重启噪音。
- ❌ 驳回：不把预编译 `.ko` 放入项目；内核模块强绑定内核版本和 vermagic，跨 VPS 不可靠。继续保留 DKMS -> 预编译/源码 `amneziawg-go` 混淆回退路线。
- ❌ 暂缓：不默认 `apt-mark hold` 冻结内核、不默认提高 conntrack；这两项会改变用户系统维护策略或增加全局 sysctl，本轮只保留为手动运维建议。
- ✅ 已执行 `bash -n`：`install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh`、`install_landing_v6.48.sh`、`install_transit_v6.48.sh`、`install_amneziawg_dkms_v6.48.sh` 均通过。

# v6.47 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.47.sh`、`install_transit_v6.47.sh`、`install_amneziawg_dkms_v6.47.sh`，并同步稳定入口到 v6.47。
- ✅ 修复 P1：中转机完全卸载不再 `nft flush ruleset`，也不停止/禁用 `nftables` 服务；仅删除本脚本维护的 `inet filter` / `inet nat` 表，`/etc/nftables.conf` 只在带 Ghost-Proxy 标记时删除；`ghost-transit-ctl reload` 增加 `nft -c` 预检，管理工具补齐 `warn()`。
- ✅ 修复 P1：DKMS 自愈 service 改为运行时计算 `uname -r`，避免内核升级后仍检查安装时旧内核 headers。
- ✅ 修复 P1：落地机重跑自占端口检测改为同时检查 `metadata.json` 与本项目 systemd 服务状态；混淆参数生成移动到用户输入完成之后，减少中断残留。
- ✅ 修复 P1/P2：落地机健康检查启动后先检查一次再进入 10-30 分钟随机间隔；`ss-main/ss-backup` 配置改用 `jq` 单函数生成，保留家宽网卡绑定、主轨 AWG 内监听和备轨 TCP 限制。
- ✅ 采纳稳定性增强：`versions.conf` 新增可选预编译 `amneziawg-go` / `awg-tools` URL 与 SHA256 字段；落地机用户态回退优先尝试已发布的 amd64/arm64 预编译包，失败再源码编译。
- ✅ README 更新当前稳定版本、Debian 12.14 DD 示例和预编译工具链配置说明。
- ❌ 驳回：不把预编译 `.ko` 内核模块塞进仓库；`.ko` 强绑定内核版本，仍坚持 DKMS 本机编译，失败后回退支持混淆的 `amneziawg-go`。
- ❌ 暂缓：AWG-only、Docker 化、Hysteria2/REALITY 第三轨不并入 v6.47；它们会扩大测试面或改变默认暴露面，本轮只做备用工具链兜底。

# v6.46 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.46.sh`、`install_transit_v6.46.sh`、`install_amneziawg_dkms_v6.46.sh`，并同步稳定入口到 v6.46。
- ✅ 修复 P1：落地机校验既有 `sing-box` 版本，不匹配 `SINGBOX_VERSION` 时重装固定版本；写入 `ss-main/ss-backup` 后先执行 `sing-box check` 再启动服务。
- ✅ 修复 P1：`SS_PASSWORD` 限制为 base64/URL-safe 字符，复用密码文件时也校验，避免用户传入引号、反斜杠或换行写坏 JSON/YAML。
- ✅ 修复 P1：家宽策略路由新增 `/usr/local/bin/home-ip-routing-apply.sh` 与 `home-ip-routing.service`，兼容 systemd-networkd 重启后重放规则，不改写 `.network` 文件。
- ✅ 修复 P1：落地机健康检查只在首次失败、达到阈值和恢复时记录，降低长期日志噪音；`AUTO_DETECT_MTU=1` 改为 3 次探测取中位数。
- ✅ 修复 P1：DKMS 独立脚本增加 UEK/过旧内核预检，写入 `/var/lib/amneziawg-dkms/ref` 记录当前固定 ref；ref 不匹配时强制重编译，落地机复用既有模块前也会检查该状态。
- ✅ 修复 P1：DKMS 自愈服务在无完整当前内核头文件时直接跳过，避免新内核无 headers 时反复无效编译。
- ✅ 修复 P1/P2：中转机 `reload-rules` 增加 `config.json` JSON/必需字段/数组预检，删除废弃 `ask_ports()`；健康检查仅在存在启用端口时要求 `masquerade/dnat`。
- ⚠️ 评判：`flock` 的内核锁会随进程退出释放，`kill -9` 后仅残留锁文件不会永久阻塞；本轮只增加超时锁提示，不采纳“直接 rm 被持有锁文件”，避免并发加载 nftables。
- ❌ 驳回：Hysteria2 第三轨和 DD 封装脚本仍不并入默认方案；前者扩大协议栈和暴露面，后者清盘风险过高。AWG-only 仅作为备用方案候选，暂不改变默认双轨。

# v6.45 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.45.sh`、`install_transit_v6.45.sh`、`install_amneziawg_dkms_v6.45.sh`，并同步稳定入口到 v6.45。
- ✅ 修复 P0：落地机重跑检测到既有 `metadata.json` 时先临停 `awg-landing/ss-main/ss-backup/landing-health-check`，避免被本项目旧服务自占端口卡死。
- ✅ 修复 P1：`amneziawg-go` 回退幂等检查同时要求 `awg`、`awg-quick`、`amneziawg-go`，避免半安装状态误报成功。
- ✅ 修复 P1：DKMS 固定版本不可用时回退安装仓库默认 `dkms`；仍保持 DKMS 独立脚本失败后由落地机回退 `amneziawg-go`。
- ✅ 修复 P1：落地机 SSH 端口优先读取 `sshd_config`，再回退 `ss` 检测；`show-clash-config` 改为 `exec cat`；中转配置名称改用 `LANDING_NAME` 或日期标签。
- ✅ 采纳稳定性增强：`SS_PASSWORD` 长度校验，自动生成密码做字符类型检查；`AUTO_DETECT_MTU=1` 时等待 `awg0` 就绪后再探测。
- ✅ 修复 P1：中转机 SNAT 从全局 `oifname != "lo" masquerade` 收窄为仅对启用落地机的目标 IP/端口 masquerade。
- ✅ README 补充 v6.45、`versions.conf` 使用方式、ARM64 leitbogioro 示例参数；DKMS/落地脚本补充官方 ISO/网络安装链接。
- ❌ 驳回：新增官方 DD 封装脚本本轮不采纳。DD 会清盘，误用风险高，现阶段只在 README 和脚本提示中给可复制参考。
- ❌ 暂缓：AWG-only、主备互换、安装后完整验证脚本不并入 v6.45，避免扩大默认行为和测试面；可作为独立备用方案评估。

# v6.44 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.44.sh`、`install_transit_v6.44.sh`、`install_amneziawg_dkms_v6.44.sh`，并同步稳定入口到 v6.44。
- ✅ 采纳 P1：AWG 新混淆参数改为推荐范围生成，`JC=4-12`、`JMIN=8`、`JMAX=80`、`S1/S2>0` 且避开冲突，`H1-H4` 保持正整数且唯一；旧版不安全参数会重写。
- ✅ 采纳 P1：MTU 默认保持保守值 1360，不再对本机隧道地址做伪智能探测；仅 `AUTO_DETECT_MTU=1` 时对中转公网 IP 探测，并限制结果在 1280-1420。
- ✅ 采纳 P1：落地机备轨健康检查改为 `ss` 监听检测；交互端口冲突检测同时检查 TCP/UDP；安装完成提示改为无序号列表。
- ✅ 采纳 P1：DKMS 增加 `build/Makefile` 完整性检查；固定 GCC 安装失败但系统已有 `gcc` 时继续尝试，避免镜像版本差异误伤。
- ✅ 采纳 P1/P2：中转机健康检查验证关键 NAT hook、DNAT 与 masquerade 规则；`ghost-transit-ctl add-landing` 增加重复 IP 拦截、临时文件校验和 `chmod 600`。
- ✅ README 补充 v6.44、DD 来源和 x86_64/ARM64 区分。
- ❌ 驳回：Hysteria2 作为默认或自动备轨暂不采用；它会在中转机引入应用层代理，不符合当前低暴露红线。可作为独立备用方案另行设计，不并入默认脚本。
- ❌ 暂缓：`SS-only` / `AWG-only` 档位本轮不加，避免扩大测试面；当前优先稳定 DKMS -> amneziawg-go 主方案。

# v6.43 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.43.sh`、`install_transit_v6.43.sh`、`install_amneziawg_dkms_v6.43.sh`，并同步稳定入口到 v6.43。
- ✅ 修复 P0：`ss-backup.json` 显式 `"network": "tcp"`，客户端备轨 `udp: false`，防火墙额外 DROP `SS_BACKUP_PORT/udp`，避免备轨公网 UDP 暴露。
- ✅ 修复 P0：`APPEND_PUBLIC_DNS=1` 优先使用 `resolvectl dns/domain global`；`/etc/resolv.conf` 为符号链接且无 `resolvectl` 时只告警不写入，避免破坏 systemd-resolved。
- ✅ 修复 P0/P1：落地机每次尝试刷新 DKMS 独立脚本，不再依赖脆弱的版本字符串 grep；关键默认版本 `DKMS_VERSION/GCC_VERSION/SINGBOX_VERSION` 内置到脚本，`bash <(curl ...)` 也生效。
- ✅ 修复 P1：`LANDING_INDEX` 非交互校验拆分为缺失、非数字、小于 1 三类明确错误。
- ✅ 修复 P1：落地健康检查增加 AWG 重启指数退避，systemd service 默认 `HEALTH_LOG_LEVEL=warn`。
- ✅ 修复 P1：中转机连通性测试移除 `tail --pid` 等待，改为 `kill -0` 超时轮询并清理子进程。
- ✅ 修复 P1：DKMS 自愈 service 继承 `DKMS_VERSION/GCC_VERSION`；冻结内核提示按 x86_64/ARM64 输出。
- ✅ 采纳 P2：MTU 探测增加 `timeout`、临时备份名带 PID、重启后验证 awg0；ip6tables lo 规则改为 `-C` 后再追加；中转管理工具 IP 校验补 octet 范围。
- ❌ 驳回：新增“已知兼容内核白名单”暂不采用，避免误伤可编译的新内核；当前 DKMS 失败后由落地机回退 `amneziawg-go` 更稳。
- ❌ 驳回：备轨改 Hysteria2 / 双 AWG 不作为默认方案，增加协议栈和暴露面，不符合当前极简双轨目标。

# v6.42 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.42.sh`、`install_transit_v6.42.sh`、`install_amneziawg_dkms_v6.42.sh`，并同步稳定入口到 v6.42。
- ✅ DKMS、`amneziawg-tools`、`amneziawg-go` 默认固定到 2026-05-20 可见上游提交；保留 `AWG_DKMS_REF`、`AWG_TOOLS_REF`、`AWG_GO_REF` 覆盖。
- ✅ 新增 `versions.conf`，集中记录 Debian 12.14 基线、DKMS/GCC/sing-box 版本和 AWG 上游源码 ref；脚本同目录运行时会自动读取。
- ✅ DKMS 独立脚本支持 `DKMS_VERSION`、`GCC_VERSION` 可选固定 apt 依赖版本，并补充 Debian 12 Bookworm minimal / DD 基线提示。
- ✅ 落地机 MTU 写回前备份 `awg0.conf`，`sed` 或服务重启失败时恢复旧配置并回退 `OPTIMAL_MTU`。
- ✅ 中转机连通性测试和健康检查 ICMP 增加 `timeout`，并支持 `HEALTH_LOG_LEVEL=error|warn|info` 降低长期日志噪音。
- ✅ README 补充推荐 DD 基线、内核升级风险和手动 `apt-mark hold` 提示；不自动 DD、不默认冻结内核。

# v6.41 版本 (2026-05-20)

- ✅ 新增 `install_landing_v6.41.sh`、`install_transit_v6.41.sh`、`install_amneziawg_dkms_v6.41.sh`，并同步稳定入口到 v6.41。
- ✅ 落地机非交互模式新增 `LANDING_INDEX`，默认中转端口按落地序号错开：AWG `51820+n-1`、SS `8389+n-1`，避免单中转多落地端口冲突。
- ✅ 中转机连通性测试和健康检查彻底移除 `nc` TCP 探测，仅使用宽松 ICMP；健康检查改为 30-60 分钟随机循环，默认只记录 ICMP 失败，不自动摘除落地机，只有 `DISABLE_ON_ICMP_FAIL=1` 时连续 5 次失败才禁用。
- ✅ DKMS 内核符号预检改为软告警，默认继续尝试 DKMS 编译；如需严格阻断可设置 `STRICT_KERNEL_SYMBOL_CHECK=1`。
- ✅ 落地机 MTU 探测仅在变化超过 50 时重启 AWG，重启失败自动回退旧 MTU，不再中断安装。
- ✅ 客户端 Clash Meta YAML 删除本地 `0.0.0.0:53` DNS 监听块，避免与 systemd-resolved 等本机 DNS 服务冲突；Base64 一键导入保留。
- ✅ `LOCK_DNS` 改为兼容别名，推荐使用 `APPEND_PUBLIC_DNS=1` 表达真实行为：只追加公共 DNS，不锁定 `/etc/resolv.conf`。
- ✅ 删除落地机 Docker IPv6 放行规则；IPv6 仍按要求通过 sysctl + ip6tables 默认禁用。SS Brutal 继续显式关闭，优先保证链式代理客户端兼容性和流量形态稳定。

# v6.40 版本 (2026-05-20)

### 主笔 AI 本轮修复

- ✅ 新增 `install_landing_v6.40.sh`、`install_transit_v6.40.sh`、`install_amneziawg_dkms_v6.40.sh`，并同步稳定入口到 v6.40。
- ✅ 落地机 `LOCK_DNS=1` 不再停止 `systemd-resolved`、不删除或锁定 `/etc/resolv.conf`，改为 5 秒警告后追加公共 DNS，避免破坏 1Panel 证书申请和 Docker DNS。
- ✅ 落地机 IPv6 禁用验证精简为 `sysctl + ip6tables` 结果输出；保留 IPv6 全局禁用和 ip6tables DROP。
- ✅ 落地机 SS JSON 显式写入 `multiplex.brutal.enabled=false`；防火墙补充 Docker `ip6tables` 兼容规则。
- ✅ 落地机非交互模式只要求 `TRANSIT_IP`，未设置中转监听端口时自动使用 `AWG_PORT / SS_BACKUP_PORT`；增加 `HOME_IFACE + HOME_IP` 手动家宽网卡指定。
- ✅ 落地机健康检查节奏改为 10-30 分钟随机；安装完成默认只打印 Base64 一键导入块，完整 YAML 保存在文件，需 `PRINT_FULL_YAML=1` 才打印。
- ✅ 落地机卸载移除硬编码端口回退，并继续扫描旧版 `PORTSCAN_*` 链及 `ghost/landing` 残留链，减少自定义端口残留。
- ✅ 中转机 `init_config()` 默认复用既有多落地机配置，仅 `RESET_CONFIG=1` 时清空，避免重跑脚本丢失 `landings[]`。
- ✅ 中转机交互端口冲突时改为循环重输，不再直接中断安装。
- ✅ 中转机健康检查取消 `nc` TCP 端口探测，改为 20-40 分钟随机 ICMP 存活判断，并继续验证 nftables 表丢失自愈；保持中转机纯 nftables，不安装应用层代理或 AWG 客户端。
- ✅ DKMS 独立脚本 `install_packages` 失败明确 `exit 1` 交给落地机回退，并新增内核符号预检告警退出，避免伪装成模块安装成功。
- ✅ 保持不恢复标准 WireGuard、不恢复 HTTP 订阅、不在中转机安装应用层代理、不删除 Base64 导入、不删除 AmneziaWG DKMS 与 `amneziawg-go` 回退。

# v6.39 仓库维护 (2026-05-20)

### 主笔 AI 本轮维护

- ✅ 清理 v6.37 以前的历史版本脚本，保留稳定入口和 `v6.37 / v6.38 / v6.39`，降低用户误下载旧脚本的概率。
- ✅ 更新 `README.md`：补充项目结构、当前稳定版本、三类安装命令、卸载命令和关键安全边界说明。
- ✅ 本轮不改动脚本逻辑、不增加新功能、不改变 v6.39 安装行为。

# v6.39 版本 (2026-05-20)

### 主笔 AI 本轮修复

- ✅ 新增 `install_landing_v6.39.sh`、`install_transit_v6.39.sh`、`install_amneziawg_dkms_v6.39.sh`，并同步稳定入口到 v6.39。
- ✅ DKMS 独立脚本在当前/架构内核头安装后仍不匹配时改为 `warn + return 1`，让落地机脚本明确回退到 `amneziawg-go`，避免甲骨文 ARM UEK 场景被误读为全局安装崩溃。
- ✅ DKMS 新增 `/etc/kernel/postinst.d/amneziawg-dkms`，内核升级后自动触发 `ghost-awg-dkms-check.service` 自愈重编译验证。
- ✅ 落地机 Clash Meta/Mihomo 导入配置修复：AWG 混淆字段移动到 `amnezia-wg-option`，补齐 `allowed-ips`，H1-H4 改为十进制 uint32；旧 hex 参数会自动重写为十进制。
- ✅ 落地机步骤计数统一为 11/11；交互安装补查 AWG UDP 端口占用；非交互模式补齐 `TRANSIT_IP / TRANSIT_AWG_LISTEN_PORT / TRANSIT_SS_LISTEN_PORT` 完整性提示。
- ✅ 落地机启动顺序改为先写防火墙再启动服务，避免 `ss-backup` 安装瞬间公网暴露；`awg-landing.service` 保活逻辑抽到 `/usr/local/bin/awg-landing-monitor.sh`。
- ✅ 落地机健康检查加入 AWG/SS 连续失败计数、冷却和重启后验证；AWG 重启前尝试 `modprobe amneziawg`，内核模块缺失时日志更清晰。
- ✅ 落地机完全卸载按 `metadata.json` 实际端口清理防火墙，并清理 AmneziaWG DKMS 模块、DKMS 自愈服务、swap 清理 timer 和 kernel postinst hook。
- ✅ 中转机 `ghost-transit-ctl reload-rules` 改为临时规则先语法验证并实际加载成功后才替换 `/etc/nftables.conf`，失败时保留旧规则文件。
- ✅ 中转机健康检查增加 nftables 规则表验证，规则丢失时自动 `reload-rules` 或重启 nftables；删除未调用的 `install_package_with_retry()`、顶层 `add_port()` 和 jq 死代码 `def forward_ports`。
- ✅ 保持不恢复标准 WireGuard、不恢复 HTTP 订阅、不在中转机安装应用层代理、不删除 IPv6 禁用、不删除 DKMS 独立脚本和 `amneziawg-go` 混淆回退。

# v6.38 版本 (2026-05-20)

### 主笔 AI 本轮修复

- ✅ 新增 `install_landing_v6.38.sh`、`install_transit_v6.38.sh`、`install_amneziawg_dkms_v6.38.sh`，并同步稳定入口到 v6.38。
- ✅ 自动审查发现 DKMS `git clone` 失败可能留下半截目录，导致后续重试被残留目录卡死；已在每次重试前清理目标目录。
- ✅ DKMS 独立脚本新增源码 tarball 回退下载：默认仓库 `git clone` 失败后改用 GitHub master tarball，可用 `AWG_DKMS_TARBALL_URL` 覆盖。
- ✅ DKMS 基础编译依赖、当前内核头文件、架构通用头文件安装全部接入重试，降低 apt 临时失败导致安装中断的概率。
- ✅ DKMS 补装 `amneziawg-tools` 时清理失败残留目录，避免工具补装重试被半截源码目录卡住。
- ✅ 落地机 `landing-health-check.sh` 去掉 `set -e`，统一 `log_health` 容错，避免单次 `nc/systemctl/logger` 异常导致健康检查服务反复重启。
- ✅ 落地机 `amneziawg-go` 回退路径的 `golang-go/pkg-config/libmnl-dev` 安装接入重试；`amneziawg-tools` 和 `amneziawg-go` 克隆前清理残留目录。
- ✅ 落地机 `sing-box` 下载增加连接超时和重试；中转机逻辑不扩展功能，仅同步版本入口。
- ✅ 落地机客户端 YAML 提示改为必须使用支持 AWG 混淆字段的 Mihomo/Clash Meta，避免误导用户导入不支持混淆的客户端。
- ✅ 保持不恢复标准 WireGuard 回退、不恢复 HTTP 订阅、不在中转机加入应用层代理、不删除 DKMS 独立脚本、不删除 IPv6 禁用。

# v6.37 版本 (2026-05-20)

### 主笔 AI 本轮修复

- ✅ 新增 `install_landing_v6.37.sh`、`install_transit_v6.37.sh`、`install_amneziawg_dkms_v6.37.sh`，并同步稳定入口到 v6.37。
- ✅ 落地机恢复同目录当前版本 DKMS 脚本搜索；已有内核模块但缺少 `awg/awg-quick` 时改为调用独立 DKMS 脚本补装工具，保留 `amneziawg-go` 混淆回退。
- ✅ 落地机 Base64 导入块改为安装完成时直接打印，`show-clash-config` 恢复 `/bin/cat`，不恢复 HTTP 订阅。
- ✅ 落地机端口占用检测改为 `ss sport` 精确检测；中转机专属 AWG/SS/ICMP 防火墙规则改为先删旧规则再追加，避免重复堆积并保持公网兜底 DROP。
- ✅ 落地机 `awg-landing.service` 保活循环去掉无意义 PPID 判断；MTU 探测失败时明确告警并继续使用默认值。
- ✅ 中转机健康检查脚本去掉 `set -e`，为 `jq/nc/systemctl` 增加容错，避免临时故障导致守护进程 crash loop。
- ✅ 中转机非交互安装末尾仅在 TTY 下询问连通性测试，避免 `curl | bash` 或环境变量部署被 `read` 阻塞。
- ✅ 中转机端口占用检测和 `ghost-transit-ctl add-landing` 统一改为 `ss sport` 精确检测；健康检查提示同步为 15-20 分钟。
- ✅ DKMS 健康检查 service 在 `modprobe` 失败后最多重试 3 次强制重装，失败后明确退出等待下次触发，避免无限重试噪音。
- ✅ 精简落地机已废弃功能的残留说明；继续保持不恢复标准 WireGuard 回退、不恢复 HTTP 订阅、不在中转机加入应用层代理、不删除 IPv6 禁用。

# v6.36 版本 (2026-05-20)

### 主笔 AI 本轮修复

- ✅ 新增 `install_landing_v6.36.sh`、`install_transit_v6.36.sh`、`install_amneziawg_dkms_v6.36.sh`，并同步稳定入口 `install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh` 到 v6.36。
- ✅ 落地机稳定入口文件头同步到 v6.36；删除未使用的 `verify_bbr()` 预检和调用，BBR 仍在系统优化阶段配置。
- ✅ 落地机 DKMS 独立脚本搜索路径只保留稳定入口、`/usr/local/bin`、`/root`、`/tmp`，不再堆叠旧版本路径。
- ✅ 落地机基础依赖移除 `pkg-config libmnl-dev`，仅在 `amneziawg-tools` 编译路径按需安装；`amneziawg-go` 混淆回退保留。
- ✅ 落地机密码生成兼容删除 `\n\r`；`show-clash-config` 改用 `cat`；隧道建立后 MTU 探测等待由 2 秒延长到 5 秒。
- ✅ 落地机继续保留 AWG/SS 端口仅允许中转机访问后的公网兜底 DROP，不改 Docker/1Panel 兼容策略。
- ✅ 中转机稳定入口文件头同步到 v6.36；`ghost-transit-ctl add-landing` 增加运行时 UDP/TCP 端口占用检测，避免后期追加落地机踩到系统服务端口。
- ✅ 中转机健康检查间隔由 10-15 分钟调整为 15-20 分钟，降低长期无人值守日志和 CPU 噪音。
- ✅ DKMS 独立脚本 swap 清理 service 改用 `${BUILD_SWAP_FILE}` 展开写入，避免路径维护不一致。
- ✅ 保持不恢复标准 WireGuard 回退、不恢复 HTTP 订阅、不删除独立 DKMS 脚本、不删除 `amneziawg-go` 回退、不删除 IPv6 禁用。

# v6.35 版本 (2026-05-20)

### 主笔 AI 本轮修复

- ✅ 新增 `install_landing_v6.35.sh`、`install_transit_v6.35.sh`、`install_amneziawg_dkms_v6.35.sh`，并同步稳定入口 `install_landing.sh`、`install_transit.sh`、`install_amneziawg_dkms.sh` 到 v6.35。
- ✅ 落地机非交互模式补齐 `AWG_PORT` UDP 占用检测，`SS_BACKUP_PORT` 改为 TCP 精确检测；交互模式端口占用时用户拒绝重选则明确停止安装，不再带错继续。
- ✅ 落地机防火墙在允许中转机访问 AWG/SS 后追加公网兜底 DROP，不改变全局默认策略，不破坏 Docker/1Panel，但真正锁死代理端口只给中转机。
- ✅ 落地机 DKMS 稳定入口改为 `/usr/local/bin/install_amneziawg_dkms.sh` 优先，下载失败只告警并继续本地脚本或 `amneziawg-go` 混淆回退。
- ✅ 落地机 `awg-landing.service` 保活循环改为 5 秒检查并感知父进程退出；隧道确认成功后等待 2 秒再做 MTU 探测，避免刚建链路时过早探测。
- ✅ 删除落地机未调用的 `detect_optimal_mtu()` 死代码，保留更可靠的隧道内 MTU 探测。
- ✅ 落地机终端 Base64 输出精简为读取命令，完整 Base64 仍保存在 `${CONFIG_DIR}/clash-meta-import-block.txt`，复制粘贴导入能力不变。
- ✅ 中转机 `check_port_conflict()` 按 TCP/UDP 分别检测，避免 UDP 占用误报 TCP 或 TCP 占用误报 UDP。
- ✅ 中转机安装连通性测试与健康检查改为遍历每台落地机全部 TCP 目标端口，任一代理端口可达即判定存活，再回退 SSH。
- ✅ 中转机 nftables input 链非法访问默认纯 drop，减少长期无人值守日志噪音；forward 链补充 ICMP echo-request 转发，便于排障。
- ✅ 中转机健康检查间隔改为 10-15 分钟，降低长期运行日志与 CPU 噪音。
- ✅ DKMS 独立脚本 swap 清理 service 使用固定路径 `/var/tmp/amneziawg-dkms-build.swap`，避免 systemd 中变量为空。
- ✅ 保持不恢复标准 WireGuard 回退、不删除 AWG DKMS 独立脚本、不删除 `amneziawg-go` 回退、不删除 IPv6 禁用、不在中转机加入应用层代理。

# v6.34 版本 (2026-05-20)

### 主笔 AI 本轮修复

- ✅ 新增 `install_landing_v6.34.sh`、`install_transit_v6.34.sh`、`install_amneziawg_dkms_v6.34.sh`，并同步稳定入口 `install_amneziawg_dkms.sh` 到 v6.34。
- ✅ DKMS 独立脚本修复 swap 清理 service 变量展开；模块已就绪时不因缺少 `awg/awg-quick` 重编内核，只进入工具补装流程；pipe 安装时健康服务优先下载稳定入口。
- ✅ 落地机基础依赖移除无条件 `golang-go`，仅在 `amneziawg-go` 回退时按需安装；已有内核模块但工具缺失时只编译 `amneziawg-tools`。
- ✅ 落地机 DKMS 搜索顺序改为稳定入口优先；非交互安装补充 `SS_BACKUP_PORT` 占用检测；交互端口重选增加 10 次上限。
- ✅ 落地机 MTU 探测改为隧道建立后检测 `10.8.0.1`，并写回 `awg0.conf` 后重启 AWG；记录 v6.33 的 1360 默认值用于链式代理保守开销。
- ✅ 落地机健康检查在 `nc` 缺失时跳过端口检测并写入日志；`show-clash-config` 使用 `#!/usr/bin/env bash` 与 `/bin/cat`。
- ✅ 中转机网络检查兼容缺少 `getent` 的极简系统；安装连通性测试优先探测落地机真实 TCP 代理目标端口，再回退 SSH。
- ✅ 中转机 `reload-rules` 写规则改为 `printf '%s'`，避免转义内容被二次解释；公网 IP 查询改为 HTTPS。
- ✅ 保持不恢复标准 WireGuard 回退、不恢复 HTTP 订阅服务、不删除 amneziawg-go 回退、不删除 IPv6 禁用。
- ✅ 已执行 `bash -n`：`install_landing_v6.34.sh`、`install_transit_v6.34.sh`、`install_amneziawg_dkms_v6.34.sh`、`install_amneziawg_dkms.sh` 均通过。

# v6.33 版本 (2026-05-20)

### 主笔 AI 本轮修复

- ✅ 新增 `install_landing_v6.33.sh`、`install_transit_v6.33.sh`、`install_amneziawg_dkms_v6.33.sh`，并同步稳定入口 `install_amneziawg_dkms.sh` 到 v6.33。
- ✅ DKMS 独立脚本修复幂等判断：只有 `amneziawg` 内核模块和 `awg/awg-quick` 都存在才跳过编译，避免工具缺失导致落地服务启动失败。
- ✅ 落地机修复已有模块但缺少工具的自愈路径；`awg-landing.service` 启动前先容错 down，用户态回退时显式设置 `WG_QUICK_USERSPACE_IMPLEMENTATION=amneziawg-go`。
- ✅ 落地机非交互安装要求显式传入 `TRANSIT_AWG_LISTEN_PORT` 与 `TRANSIT_SS_LISTEN_PORT`，防止单中转多落地机默认端口撞车；交互端口重选去掉递归。
- ✅ 落地机依赖安装增加 apt 重试，提前安装 `golang-go`，并按脚本版本强制刷新 `/root/install_amneziawg_dkms.sh`；卸载补删健康检查脚本。
- ✅ 中转机 `check_network()` 改用 `getent ahosts`，依赖安装统一 `apt-get`；`add_landing()` 内补齐端口占用检测，覆盖 `LANDING_LIST` 非交互路径。
- ✅ 中转机 nftables input 链删除 DNAT 转发端口 accept，只保留 SSH、本机回环、已建立连接和 ICMP 限速，降低中转机暴露面。
- ✅ 保持不恢复标准 WireGuard 回退、不恢复 HTTP 订阅服务、不删除 amneziawg-go 回退、不删除 IPv6 禁用。
- ✅ 已执行 `bash -n`：`install_landing_v6.33.sh`、`install_transit_v6.33.sh`、`install_amneziawg_dkms_v6.33.sh`、`install_amneziawg_dkms.sh` 均通过。

# v6.32 版本 (2026-05-20)

### 主笔 AI 本轮修复

- ✅ 新增 `install_landing_v6.32.sh`、`install_transit_v6.32.sh`、`install_amneziawg_dkms_v6.32.sh`，并同步稳定入口 `install_amneziawg_dkms.sh` 到 v6.32。
- ✅ 修复落地机 `awg-landing.service`：改为 `ExecStartPre=awg-quick up` + 前台存活监视，超时和意外断开明确退出，避免 v6.31 的异常重启状态。
- ✅ 修复落地机健康检查：主轨端口使用安装时展开的固定值，`systemctl restart` 增加失败保护，避免健康检查服务因单次重启失败退出。
- ✅ 精简落地机基础依赖：删除 `wireguard-tools` 和无条件 `golang-go`；`golang-go` 仅在 DKMS 失败并回退 `amneziawg-go` 时按需安装。
- ✅ DNS 锁死改为可选：默认只禁用 IPv6（sysctl + ip6tables），只有显式 `LOCK_DNS=1` 才写入并锁定 `/etc/resolv.conf`，降低与 Docker、1Panel、证书申请和系统更新冲突。
- ✅ DKMS 脚本补齐 `pkg-config`、`libmnl-dev` 依赖和 `--help/-h` 用法输出，适配干净 Debian 12 上编译 `amneziawg-tools`。
- ✅ 落地机加固：MTU 探测增加上限保护；SS 备轨端口占用检测改为 TCP+UDP；家宽检测补充 `100.64.0.0/10` CGNAT；Clash 健康检查 URL 改为 HTTPS；删除虚假“流量时序随机化”提示。
- ✅ 中转机加固：`add_landing()` 内部补齐 IP 和端口校验；端口占用检测统一检查 TCP+UDP；`LANDING_LIST` 帮助增加完整示例和简写示例。
- ✅ 已执行 `bash -n`：`install_landing_v6.32.sh`、`install_transit_v6.32.sh`、`install_amneziawg_dkms_v6.32.sh`、`install_amneziawg_dkms.sh` 均通过。

## v6.31 版本 (2026-05-20)

### 主笔 AI 本轮修复

- ✅ 新增 `install_amneziawg_dkms_v6.31.sh`，并同步稳定入口 `install_amneziawg_dkms.sh`：DKMS 成功后必须确认 `awg/awg-quick`，缺失时编译安装 `amneziawg-tools`，不再用 `wireguard-tools` 冒充。
- ✅ 新增 `install_landing_v6.31.sh`：`awg-landing.service` 使用 `command -v awg-quick` 的真实路径，启动等待 `10.8.0.1` 就绪后再进入保活循环，避免 systemd crash loop。
- ✅ 落地机健康检查改为 systemd 自循环，随机 4-6 分钟间隔；主轨检查使用 `${SS_MAIN_PORT}`，不再硬编码 `8388`。
- ✅ 落地机交互式中转监听端口改为输错可重输；防火墙插入规则不再使用固定编号，降低与 Docker/1Panel 规则冲突风险。
- ✅ 落地机与中转机均将 `net.ipv6.conf.lo.disable_ipv6` 改为 `1`，满足完全禁用 IPv6 的要求。
- ✅ 新增 `install_transit_v6.31.sh`：中转健康检查优先探测备轨 TCP 代理端口，只有没有代理端口时才回退 SSH；检查节拍改为 systemd 随机 4-6 分钟自循环。
- ✅ 中转机 sysctl 精简为 IP 转发、IPv6 禁用、fq/BBR、`tcp_slow_start_after_idle=0`；删除 TFO、大 TCP buffer 与激进 conntrack 参数。
- ✅ 中转机补齐 `--help`，新增 `LANDING_LIST` 多落地机非交互导入；非法访问 nft 日志改为 `level warn`。
- ✅ 客户端 YAML 明确提示 AWG 混淆字段仅 Mihomo(原 Clash Meta) 支持，避免用户误以为所有 Clash 客户端都有混淆。
- ✅ 已执行 `bash -n`：`install_landing_v6.31.sh`、`install_transit_v6.31.sh`、`install_amneziawg_dkms_v6.31.sh`、`install_amneziawg_dkms.sh` 均通过。

## v6.30 版本 (2026-05-20)

### 主笔 AI 本轮修复

- ✅ 新增 `install_landing_v6.30.sh`：删除标准 WireGuard 最终回退；DKMS 失败后只允许真实 `amneziawg-go` 用户态后端，保留 `awg/awg-quick` 工具。
- ✅ 落地机 DKMS 脚本不再硬编码 `/root`：按环境变量、脚本同目录、`/root`、`/usr/local/bin`、`/tmp` 搜索，找不到再从 GitHub 下载。
- ✅ 落地机将 `TRANSIT_AWG_LISTEN_PORT` / `TRANSIT_SS_LISTEN_PORT` 与本机目标端口分离，客户端 YAML 使用中转监听端口，适配单中转多落地机复制粘贴导入。
- ✅ 落地机 Base64 导入文件改为纯 Base64，不再把 `COPY_START/END` 标记写入文件；删除旧 v5.3 Peer 公钥提示，避免误导。
- ✅ 落地机安装依赖后再生成混淆参数；服务端 MTU 使用自动探测值；`awg-landing.service` 加持续监控循环，并新增轻量健康检查。
- ✅ 新增 `install_transit_v6.30.sh`：安装阶段复用 `ghost-transit-ctl reload-rules` 原子生成 nftables 规则，删除重复生成逻辑。
- ✅ 中转机健康检查改为两级检测（SSH 存活 + 备轨代理端口可达），并检查/重启 nftables；cron 日志写入 `/var/log/ghost-transit-health.log`。
- ✅ 中转机 sysctl 调整：`tcp_fastopen=1`、`tcp_mtu_probing=0`；非法访问 nft 日志降为 `level info`。
- ✅ 新增 `install_amneziawg_dkms_v6.30.sh`，并同步稳定入口 `install_amneziawg_dkms.sh`：`apt-get update` 和 `git clone` 增加重试/低速保护，增加 `dpkg --configure -a`、磁盘空间检查、`lsmod` 验证、`awg-quick` 检查、systemd swap 清理 timer 与 DKMS 启动健康服务。
- ✅ 已执行 `bash -n`：`install_landing_v6.30.sh`、`install_transit_v6.30.sh`、`install_amneziawg_dkms_v6.30.sh`、`install_amneziawg_dkms.sh` 均通过。

## v6.29 / v6.28 版本 (2026-05-20)

### 主笔 AI 本轮修复

- ✅ 新增 `install_landing_v6.28.sh`：修复重复 `VERSION` 覆盖，实际运行版本统一为 v6.28。
- ✅ 落地机删除内置 DKMS 编译逻辑，改为薄调用独立脚本 `/root/install_amneziawg_dkms.sh`（可用 `AWG_DKMS_SCRIPT` 覆盖）。
- ✅ 落地机保留 `awg-quick` 与 Jc/Jmin/Jmax/S1/S2/H1-H4 混淆参数，删除过长导入说明，只保留终端 YAML 与 Base64 字符串。
- ✅ 落地机输出中转机新命令：`ghost-transit-ctl add-landing <IP> <名称> --awg-listen ... --awg-target ... --ss-listen ... --ss-target ...`。
- ✅ 新增 `install_transit_v6.28.sh`：配置结构改为每个落地机独立 `ports[]`，DNAT 使用 `listen -> target`，解决单中转多落地机同端口冲突。
- ✅ 中转机健康检查读取 `.landings[$i].ports[]?.target` 的 TCP 目标端口，回退 SSH；管理工具 `add-port` 标记为废弃。
- ✅ 新增 `install_amneziawg_dkms_v6.29.sh` 与稳定入口 `install_amneziawg_dkms.sh`：添加 `/etc/modules` 自动加载；低内存临时 swap 改为 1 小时后清理。
- ✅ 已执行 `bash -n`：`install_landing_v6.28.sh`、`install_transit_v6.28.sh`、`install_amneziawg_dkms_v6.29.sh`、`install_amneziawg_dkms.sh` 均通过。

## v6.28 版本 (2026-05-20)

### 主笔 AI 独立 DKMS 脚本修复

- ✅ 新增 `install_amneziawg_dkms_v6.28.sh`，保留 v6.27 历史版本，不覆盖旧文件。
- ✅ 通过 WSL Ubuntu 的 `bash -n` 和 `shellcheck` 检查。
- ✅ 验证上游 `amneziawg-linux-kernel-module` 真实结构，确认 `dkms.conf` 与 `Makefile` 位于 `src/`。
- ✅ 自动选择 DKMS 源码目录，兼容仓库根目录或 `src/` 目录放置 `dkms.conf` 的结构。
- ✅ 修复 DKMS 流程：`make dkms-install` 后继续执行 `dkms add/build/install`，确保真正编译并安装内核模块。

## v6.27 版本 (2026-05-20)

### 审查 AI 意见
**审查依据版本：** v6.26

**P0 级问题（致命错误）：**
1. **落地机 v6.26 架构错误** - 移除 AmneziaWG 混淆参数导致功能退化
   - v6.26 声称"移除 AmneziaWG 混淆参数，使用标准 WireGuard"，这是严重的架构倒退
   - 违背核心诉求"欺上"：移除混淆参数后，流量特征退化为标准 WireGuard，GFW 可以轻易识别
   - 自相矛盾：脚本仍在生成混淆参数并写入 Clash Meta 配置，但实际 AWG 配置完全不使用
   - 虚假承诺：用户看到配置中有混淆参数，但实际流量没有任何混淆

2. **落地机 systemd 服务使用错误的命令**
   - 当前使用 `wg-quick`，应该使用 `awg-quick`
   - 标准 wg-quick 不识别 AmneziaWG 混淆参数

3. **单中转多落地机目前只是"故障切换"，不是"多个可导入节点"**
   - 当前 ports 是全局端口，同一个中转机端口不能同时明确代表多个落地机
   - 需要改成"每个落地机独立端口映射"

**P1 级问题（严重但不致命）：**
1. 健康检查只测 SSH，不等于代理可用
2. 落地机 sysctl 仍有"优化大全"倾向，可以精简

### 主笔 AI 修复方案

**落地机脚本 (install_landing_v6.27.sh)：**
- ✅ 新增 `install_kernel_headers_best_effort()` - 智能安装内核头文件（x86_64/ARM64）
- ✅ 新增 `install_amneziawg_dkms()` - DKMS 编译 AmneziaWG 内核模块
- ✅ 新增 `install_amneziawg_go()` - 用户态回退方案（amneziawg-go）
- ✅ 新增 `install_awg_runtime()` - 统一入口，自动降级（DKMS → go → wireguard）
- ✅ 恢复服务端配置混淆参数（Jc/Jmin/Jmax/S1/S2/H1-H4）
- ✅ systemd 服务改回 `awg-quick`（支持混淆）
- ✅ 删除 v6.26 的 sed 修补逻辑（不再破坏 awg-quick）
- ✅ 精简 sysctl 优化（只保留 BBR + fq）
- ✅ 优化复制粘贴导入提示（COPY_START/END 标记）
- **代码统计：** v6.26(1840行) → v6.27(1971行)，净增加 131 行

**中转机脚本 (install_transit_v6.27.sh)：**
- ✅ 健康检查优先探测备轨 TCP 端口，回退 SSH
- ✅ 验证 nc 命令存在性（健康检查依赖）
- **代码统计：** v6.26(1746行) → v6.27(1762行)，净增加 16 行

**核心修复：**
v6.26 移除混淆参数是负优化，违背"欺上瞒下"核心诉求。v6.27 通过 DKMS 编译真正的 AmneziaWG 内核模块，恢复混淆能力。优雅降级：DKMS 失败 → amneziawg-go 用户态 → 标准 WireGuard（最后手段）。

### 主笔 AI 独立 DKMS 脚本补充

- ✅ 新增独立脚本 `install_amneziawg_dkms_v6.27.sh`，不集成到中转机或落地机脚本。
- ✅ 支持 Debian 12 x86_64 与 ARM64，适配 1核1G x86 VPS 和甲骨文 ARM VPS。
- ✅ 安装 DKMS、编译工具和内核 headers；当前 headers 不可用时回退架构通用 headers。
- ✅ 低内存且无 swap 时临时创建 1G swap，降低 DKMS 编译 OOM 风险，默认编译后清理。
- ✅ 编译安装后执行 `modprobe amneziawg` 与 `modinfo amneziawg` 验证。
- ✅ 保持独立调用方式，供后续安装脚本在需要时显式调用。
- ✅ 增加 `.gitattributes`，强制 `.sh` 使用 LF，避免 Debian 运行时出现 CRLF 解析错误。
- ✅ 适配上游真实结构：自动进入 `src/` 目录，并在 `make dkms-install` 后继续执行 `dkms add/build/install`。

---

## v6.26 版本 (2026-05-12)

### 主笔 AI 修复
- 统一中转机和落地机版本号为 v6.26
- 保持与落地机版本一致

---

## v6.25 版本 (2026-05-12)

### 主笔 AI 修复
- 移除 AmneziaWG 混淆参数（**已在 v6.27 回滚**）
- 使用标准 WireGuard 协议（**已在 v6.27 回滚**）
