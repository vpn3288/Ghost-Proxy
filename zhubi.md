# Ghost-Proxy 审核记录

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
