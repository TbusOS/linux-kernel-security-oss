# 02 · 配置加固检查

**目标**:不是查"有没有某个 CVE",而是查"内核**配置**留了哪些可被利用的软肋"。同一份内核源码,加固选项开不开,攻击面差很多。很多加固选项主流发行版默认不开,得自己开。

## kernel-hardening-checker

来源:[github.com/a13xp0p0v/kernel-hardening-checker](https://github.com/a13xp0p0v/kernel-hardening-checker)(原名 kconfig-hardened-check)· 本地:`repos/02-config-hardening/kernel-hardening-checker/`

**检查三个层面**:
- Kconfig 选项(编译期)
- 内核 cmdline 参数(启动期)
- sysctl 参数(运行期)

**支持架构**:X86_64 / X86_32 / **ARM64** / ARM / RISC-V —— vendor 板子多是 ARM64,支持。

**加固基线来源**:KSPP 推荐 · 内核维护者反馈 · grsecurity 砍攻击面禁用的选项 · CLIP OS 配置 · GrapheneOS 推荐 · SECURITY_LOCKDOWN_LSM · CIS Benchmark。

**能做**:
- 拿一份内核 config 对照加固基线,报哪些没开
- 生成可 merge 进现有 config 的 Kconfig 片段

**跑**:
```bash
pip install --user kernel-hardening-checker    # 或 scripts/install-deps.sh

# 对照你的 defconfig / 运行时 .config,指定 arm64
kernel-hardening-checker -c "$KERNEL/arch/arm64/configs/<your_defconfig>" -m verbose
# 或直接检查跑着的机器(若内核开了 CONFIG_IKCONFIG_PROC)
# kernel-hardening-checker -c /proc/config.gz
```
> 具体 defconfig 文件名在 `$KERNEL/arch/arm64/configs/` 下确认。注意:kernel-hardening-checker 要**完整 `.config`**,defconfig 不完整,先 `make <defconfig>` 生成 `.config` 再喂它。

**注意**(README 明写):改内核安全参数可能影响性能。加固是安全 vs 性能的取舍,嵌入式设备要按产品需求权衡,不是全开就好。

## 和其他类的关系

- 配置加固**不产出 CVE 编号**,产出的是"这些缓解措施没开 → 一旦有洞更容易被利用"。
- 和 ① 配合看:①说"有哪些洞",②说"洞被利用的难度被降到多低"。
- 作者还画了张 [Linux Kernel Defence Map](https://github.com/a13xp0p0v/linux-kernel-defence-map),把加固特性 ↔ 漏洞类别 ↔ 利用技术的关系图出来,值得对照理解为什么某个选项重要。
