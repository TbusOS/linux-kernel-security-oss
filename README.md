# linux-kernel-security-oss · 内核安全检测工具库

> 📖 **文档站(anthropic 风格,双语):https://doc.tbusos.com/linux-kernel-security-oss/**
> [设计目的与总览](https://doc.tbusos.com/linux-kernel-security-oss/) · [使用指南](https://doc.tbusos.com/linux-kernel-security-oss/usage.html) · [设计与架构](https://doc.tbusos.com/linux-kernel-security-oss/architecture.html)

给 Linux 内核(尤其 **vendor / Android arm64 内核**)做**安全漏洞检测 + 配置加固 + 代码审计**的一套开源工具编排。目标:**clone 下来就知道怎么测、要哪些工具、怎么一键装依赖**。

- 面向:做内核移植 / vendor SDK 维护 / 嵌入式安全的工程师。
- 只对**你自己拥有或有书面授权**的内核和设备使用。
- 全部工具是开源件,本库负责**分类 + 编排 + 一键上手**,不重造轮子。

---

## 一、先分清六件事(选工具前必读)

"检测内核安全漏洞"其实是**手段完全不同的几件事**,混在一起是选错工具的头号原因。

| # | 活动 | 回答的问题 | 手段 | 文档 |
|---|---|---|---|---|
| ① | **已知 CVE 检测** | 我内核里有没有**已公开**的 CVE 没修? | 静态查源码 / git | [`docs/01`](docs/01-known-cve-detection.md) |
| ② | **配置加固检查** | 我内核配置够不够硬? | 查 `.config` / cmdline / sysctl | [`docs/02`](docs/02-config-hardening.md) |
| ③ | **新漏洞挖掘** | 有没有**还没人发现**的洞? | LLM 生成规格 + fuzzing | [`docs/03`](docs/03-new-vuln-discovery.md) |
| ④ | **影响评级**(参考类) | 查到的洞**实际影响多大、要不要先修**? | 漏洞类别知识 + 资料合集 | [`docs/04`](docs/04-impact-rating.md) |
| ⑤ | **LLM 审代码 / 补丁** | 这段 C / diff 有没有安全问题? | Claude 语义读源码,辅助 ①③ | [`docs/05`](docs/05-llm-code-audit.md) |
| ⑥ | **二进制逆向** | 只有 `.ko` / 固件,或要证明出厂二进制含 bug | 反编译 + 接 LLM | [`docs/06`](docs/06-binary-re.md) |

> **本库定位是防御性检测。** ④ 是参考类——只做纸面影响评级(给已检出的洞定优先级),**不放攻击工具本体、不写利用链、不实跑**。完整的一次端到端示例走一个虚构 `/dev/foo` 驱动:[`docs/07`](docs/07-worked-example.md)。

---

## 二、Quickstart

```bash
git clone <本仓库> linux-kernel-security-oss
cd linux-kernel-security-oss

# 1. 一键装系统依赖(coccinelle / 交叉编译器 / python 工具等)
bash scripts/install-deps.sh          # 加 --dry-run 只看要装什么;--with-heavy 连 Ghidra/radare2 一起

# 2. 拉齐第三方开源工具到 repos/
bash scripts/clone-tools.sh

# 3. 指向你自己的内核源码,跑静态检查出报告
export KERNEL=/path/to/your/kernel        # 一棵 vendor arm64 内核源码
bin/ksec scan --kernel "$KERNEL"
bin/ksec report --html                    # 报告写到 out/report.md / out/report.html
```

三层检测,由浅入深:

| 层 | 是什么 | 入口 |
|---|---|---|
| **L1 静态(确定性)** | cvehound / kernel-cve-tool / kernel-hardening-checker,无需 LLM | `bin/ksec scan` |
| **L2 代码审计(LLM 辅助)** | trailofbits skills + claude-code-security-review 语义审 C/diff | `bin/ksec audit`(需 Claude Code) |
| **L3 动态复现(自家设备)** | ioctl 泄漏回归探针 + slab 监控,确认 bug 真存在、修复后真消失 | `bin/ksec dynamic` · [`harness/`](harness/) |

---

## 三、在你自己的内核上从哪开始

只要内核**有 git 历史 + 基于某个 stable 标签**(多数 vendor arm64 内核符合),两条已知-CVE 检测路都能跑,建议都跑:

1. **① 已知 CVE 检测(核心,两工具互补)**
   - **cvehound**:源码模式匹配,不依赖版本号。抓 vendor **backport 了修复却没 bump SUBLEVEL** 的情况,以及自带驱动缺的修复。
   - **kernel-cve-tool**:利用 git 历史,查哪些 CVE 修复 commit **已 cherry-pick 进你的分支**。要求分支从 stable 标签派生。
   - 不用 Vuls/Trivy 的原因:按包版本号匹配,**看不到 vendor 自己 backport 了什么**,vendor 内核上误判高。
2. **② 配置加固**:拿 defconfig / 运行时 `.config` 跑 kernel-hardening-checker(支持 arm64),看哪些加固选项没开。
3. **⑤ LLM 后处理**:每条命中让 Claude 判断 vendor 是否已 backport(过滤假阳性)、解释成因、判断在设备上够不够得着。
4. 想主动挖新洞 → **③** KernelGPT + syzkaller(要带 KASAN 的内核 + fuzzing 环境,重)。

---

## 四、工具清单(scripts/clone-tools.sh 会拉这些)

| 类 | 仓库 | 用途 |
|---|---|---|
| ① | [evdenis/cvehound](https://github.com/evdenis/cvehound) | 源码模式匹配查已知 CVE,**vendor 内核首选** |
| ① | [nluedtke/linux_kernel_cves](https://github.com/nluedtke/linux_kernel_cves) | CVE ↔ 修复 commit 映射数据库 |
| ① | [madisongh/kernel-cve-tool](https://github.com/madisongh/kernel-cve-tool) | 用 git 历史 review 下游内核 CVE 补丁状态 |
| ② | [a13xp0p0v/kernel-hardening-checker](https://github.com/a13xp0p0v/kernel-hardening-checker) | `.config` 对照 KSPP 加固基线 |
| ③ | [ise-uiuc/KernelGPT](https://github.com/ise-uiuc/KernelGPT) | LLM 合成 syscall 规格增强 syzkaller(ASPLOS 2025) |
| ④ | [xairy/linux-kernel-exploitation](https://github.com/xairy/linux-kernel-exploitation) | 内核安全资料合集(判断影响用,非工具) |
| ⑤ | [anthropics/claude-code-security-review](https://github.com/anthropics/claude-code-security-review) | 官方 Claude 安全审查 GitHub Action(审 diff) |
| ⑤ | [trailofbits/skills](https://github.com/trailofbits/skills) | Trail of Bits 的 Claude Code 安全审计 skill 集 |
| ⑥ | [LaurieWired/GhidraMCP](https://github.com/LaurieWired/GhidraMCP) | 把 Ghidra 逆向接进 Claude |
| ⑥ | [radareorg/radare2-mcp](https://github.com/radareorg/radare2-mcp) | 官方 radare2 的 MCP 桥 |

`repos/` 下第三方克隆的字节**不进 git**(见 `.gitignore`),靠 `scripts/clone-tools.sh` 可复现地重建。

---

## 五、LLM 在这里的真实定位

**已知 CVE 检测(①)LLM 不是主角**——cvehound 这类确定性工具才是。LLM 的价值在辅助:

- 后处理:逐条判断 vendor 有没有 backport 修复,过滤假阳性;
- 解释:某 CVE 的成因、影响、在目标设备上够不够得着;
- 挖新洞(③):生成 syscall 描述、理解调用语义,把脏活交给 fuzzer。

别指望"让 Claude 读整棵内核源码帮我找洞"——误报高、上下文塞不下。实产 CVE 的做法都是 **LLM 配 fuzzer / 静态 checker / CodeQL**。

---

## 六、合规

- ①②⑤⑥ 是检测 / 审计 / 逆向,对**自己的**代码和固件跑,无授权风险。
- ③④ 涉及漏洞挖掘和影响验证,**只能对你自己拥有或有书面授权的目标**(自研板子、自有靶场、授权甲方)操作。
- 本库不含任何具体厂商 / 机型 / 未披露漏洞的信息;所有示例(`/dev/foo` 等)均为虚构。

## 许可

MIT(见 [`LICENSE`](LICENSE))。
