# repos · 第三方工具清单

全部由 `scripts/clone-tools.sh` 克隆(默认 `--depth 1` 浅克隆,省空间;要完整历史 `DEPTH=full`)。这些是**第三方开源工具,非本项目源码**,字节不进 git(见 `.gitignore`),换机器一键重拉。

| 类 | 目录 | 上游 | 一句话 | 语言/依赖 |
|---|---|---|---|---|
| ① | `01-known-cve-detection/cvehound` | evdenis/cvehound | 源码模式匹配查已知 CVE,**vendor 内核首选** | Python≥3.11 + coccinelle + grep -P |
| ① | `01-known-cve-detection/linux_kernel_cves` | nluedtke/linux_kernel_cves | CVE↔修复 commit 映射**数据库**(给下面当数据源) | JSON/文本数据 |
| ① | `01-known-cve-detection/kernel-cve-tool` | madisongh/kernel-cve-tool | 用 git 历史查 CVE 修复 commit 在不在分支 | 需内核 git + linux_kernel_cves |
| ② | `02-config-hardening/kernel-hardening-checker` | a13xp0p0v/kernel-hardening-checker | `.config`/cmdline/sysctl 对照 KSPP 加固基线(支持 ARM64) | Python |
| ③ | `03-new-vuln-discovery/KernelGPT` | ise-uiuc/KernelGPT | LLM 合成 syzkaller 规格挖新洞(ASPLOS'25,11 CVE) | Python + Clang14 + syzkaller(submodule 未 init) |
| ④ | `04-impact-rating/linux-kernel-exploitation` | xairy/linux-kernel-exploitation | 内核安全资料合集(判断影响用,非工具) | 文档 |
| ⑤ | `05-llm-code-audit/claude-code-security-review` | anthropics/claude-code-security-review | 官方 Claude 安全审查 GitHub Action(审 diff) | GH Action + Claude API |
| ⑤ | `05-llm-code-audit/trailofbits-skills` | trailofbits/skills | Trail of Bits 安全审计 skill(`c-review`/`variant-analysis`/`static-analysis`/`entry-point-analyzer`/`fp-check`/`dwarf-expert`) | Claude Code plugin |
| ⑥ | `06-binary-re/GhidraMCP` | LaurieWired/GhidraMCP | 把 Ghidra 逆向接进 Claude(原版) | Ghidra 插件 + Python bridge |
| ⑥ | `06-binary-re/radare2-mcp` | radareorg/radare2-mcp | 官方 radare2 的 MCP 桥 | radare2 + MCP |

⑥ 的 MCP 桥要配后端(Ghidra / radare2 本体,`scripts/install-deps.sh --with-heavy` 或手动装)。

## 上手顺序

对应根 `README.md` 第三节:

1. `01-known-cve-detection/cvehound` — 扫 `$KERNEL` 拿源码级 CVE 命中
2. `01-known-cve-detection/kernel-cve-tool` — 用 git 历史交叉验证(数据源指到同目录 `linux_kernel_cves`)
3. `02-config-hardening/kernel-hardening-checker` — 查 ARM64 加固缺口
4. `05-llm-code-audit/*` — Claude 过 ① 的结果、过滤假阳性
5. `03-new-vuln-discovery/KernelGPT` — 进阶,挖新洞(要另搭 syzkaller 环境)

各仓库详细用法见 `../docs/0N-*.md`。

## 维护

- 更新某仓库:`cd <dir> && git pull`(浅克隆也能 ff 更新)
- 补全历史:`git fetch --unshallow`
- KernelGPT 要真跑:`cd 03-new-vuln-discovery/KernelGPT && git submodule update --init --recursive`(会拉完整内核 + syzkaller,很大)
- 换机器用 `../scripts/clone-tools.sh` 一键重拉。
