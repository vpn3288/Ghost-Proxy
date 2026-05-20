# Ghost-Proxy 审核记录

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
