# 07 · 端到端示例:一个 ioctl 错误路径内存泄漏(虚构 `/dev/foo`)

> 本页所有名字、地址、数值都是**虚构**的,用来把本库六类工具串成一次完整流程。真实项目把 `foo` 换成你的驱动即可。

## 场景(虚构)

某 vendor 驱动 `foo.ko` 提供字符设备 `/dev/foo`,其 `foo_ioctl()` 的 `FOO_IOC_SUBMIT` 命令在**错误路径漏 `fput()`**:`copy_to_user` 失败时,本该释放的 `struct file*` 没释放,`sync_file_create()` 拿到的 file refcount 永不归还。每次失败调用泄漏约几百字节内核 slab,普通 shell 即可触发,**无上限**。

- 最坏影响:持续增长可致 OOM(拒绝服务)。综合定 **中危**。
- **目标:定位并修复(错误路径补 `fput()`)**。这是防御性工作,不是拿它做什么。

## 漏洞性质 → 决定工具选择

| 性质 | 推论 |
|---|---|
| **不是公开 CVE**(自研驱动里新找的 bug) | ① 的 cvehound / kernel-cve-tool / linux_kernel_cves **查不到** ❌ |
| **"错误路径漏释放"代码逻辑 bug + 有源码** | ⑤ LLM 源码审计 + 静态规则是**主场** ⭕ |
| **要动态证明 + 系统化找同类** | ③ syzkaller + kmemleak(+ KernelGPT 生成 ioctl 描述)⭕ |
| **出厂是 .ko 二进制** | ⑥ 逆向核对 shipped 二进制确含此 bug ⭕ |

**核心提醒**:别指望 ① 的 CVE 扫描器"检测"到这种洞——它们只认公开 CVE 库。这个 bug 靠**源码审计 + 静态规则 + 动态 fuzz** 找。

## 测试方案(5 阶段)

**Phase 1 · 静态确认 + 举一反三(有源码,主场)**
- `entry-point-analyzer`:枚举 `foo_ioctl` 全部 cmd 入口 → 审计清单
- `c-review`:逐个 handler 审"每条返回路径上分配的资源(fd/fence/file)是否都释放/转移"
- `variant-analysis`:以出问题的 cmd 的"错误路径漏 fput"为模板,找兄弟 handler 同款
- `static-analysis`(semgrep/codeql)+ 自写规则:机械扫全驱动"分配后某条返回路径未释放"
- `fp-check`:每个疑点出 PoC 判真假

**Phase 2 · 动态复现(证明真泄漏)**
- 改 `harness/ioctl_leak_probe.c`:`DEV_PATH=/dev/foo`、`IOCTL_CMD=<你的 cmd>`、入参走 `copy_to_user` 失败分支
- 交叉编译 → adb 推目标机 → `bin/ksec dynamic slabmon` 监控 `/proc/meminfo` 的 Slab(线性增长 = 泄漏)
- 若能重编内核:开 `CONFIG_DEBUG_KMEMLEAK`,直接拿 kmemleak 报告点名泄漏点

**Phase 3 · 系统化扩展(自动找同类)**
- KernelGPT 生成 `foo` ioctl 的 syzkaller 规格 → syzkaller + kmemleak/KASAN 自动 fuzz 全部 cmd,抓这一类泄漏(不止一个 cmd)

**Phase 4 · 修复验证**
- 按分析给错误路径加 `fput(file)`
- `claude-code-security-review` / 差分审 diff,确认补丁完整覆盖(别只补一个 cmd)
- 探针 / syzkaller 重跑,Slab 平了 = 修复生效

**Phase 5 · 影响定级(纸面,给修复排期)**
- 对照 `04-impact-rating` 资料合集,纸面判断最坏影响(OOM 拒绝服务;是否可能辅助堆布局)→ 支撑"中危 vs 高危"定级。不实跑利用,只为定优先级

## 工具映射速查

| 工具 | 类 | 对这种 bug | 怎么用 |
|---|---|---|---|
| trailofbits `c-review` | ⑤ | ⭕⭕ 核心 | 审 handler,确认错误路径漏 fput |
| trailofbits `variant-analysis` | ⑤ | ⭕⭕ 核心 | 举一反三扫同款漏释放 |
| trailofbits `static-analysis` | ⑤ | ⭕⭕ | CodeQL/Semgrep 查"分配后某返回路径未释放" |
| `entry-point-analyzer` / `fp-check` | ⑤ | ⭕ | 划审计范围 / 疑点验真假 |
| claude-code-security-review | ⑤ | ⭕ | 审修复 diff,确认 fput 补对 |
| KernelGPT | ③ | ⭕⭕ 核心 | 生成 ioctl 的 syzkaller 描述 |
| harness(本库) | L3 | ⭕⭕ 核心 | 定向复现 + slab 监控 |
| GhidraMCP / radare2-mcp | ⑥ | ⭕ | 逆向 shipped `.ko` 复核错误路径无 `fput` |
| cvehound / kernel-cve-tool | ① | ❌ | 只查公开 CVE,这种查不到 |
