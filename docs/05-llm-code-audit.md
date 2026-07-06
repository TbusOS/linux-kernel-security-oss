# 05 · LLM 审代码 / 补丁(辅助手段)

**定位**:这不是独立一类活,是给 ①③ 打辅助。用 Claude 语义读 C 代码或 diff,找隐患、过滤 ① 的假阳性、解释 CVE。对内核**不是主检测器**——纯 LLM 读整棵内核源码找洞误报高、上下文塞不下。用对地方(审 diff、后处理)才有价值。

## claude-code-security-review(官方,审 diff)

来源:[github.com/anthropics/claude-code-security-review](https://github.com/anthropics/claude-code-security-review) · 本地:`repos/05-llm-code-audit/claude-code-security-review/`

Anthropic 官方的 AI 安全审查 **GitHub Action**,用 Claude 对代码改动做语义安全分析。

**特点**(README):
- Diff 感知:PR 场景只分析改动的文件(正好适合审内核补丁)
- 语言无关:任何语言,包括内核 C
- 假阳性过滤:内置降噪
- 超越模式匹配:理解代码语义

**用法**:挂进 `.github/workflows/security.yml`,`uses: anthropics/claude-code-security-review@main`,给 `claude-api-key`。默认 `comment-pr: true` 自动在 PR 留言。可配 `exclude-directories` / `claude-model` / 超时 / 自定义假阳性过滤指令。

**注意**(README 明写):**未针对 prompt injection 加固,只审可信 PR**。仓库设置里开"外部贡献者需审批"。

**内核仓的用法**:内核仓多半不在 GitHub CI,那就**本地化用**——每次改内核(冲突修复、backport、加驱动)的 diff,喂给 Claude 按这套 skill 的思路审内存安全/越界/UAF/锁问题。不一定非走 GitHub Action。

## trailofbits/skills(内存安全向)

来源:[github.com/trailofbits/skills](https://github.com/trailofbits/skills) · 本地:`repos/05-llm-code-audit/trailofbits-skills/`

Trail of Bits(顶级安全公司)的 Claude Code skill 集,做安全研究 / 漏洞检测 / 审计工作流。含 **memory safety / 并发安全** 相关 skill——正是内核 C 代码的高发漏洞类型(UAF、double-free、race、越界)。常用的:`c-review`(逐函数审 C)/ `variant-analysis`(以一个已知 bug 为模板举一反三找同款)/ `static-analysis`(semgrep/codeql)/ `entry-point-analyzer`(枚举入口划审计范围)/ `fp-check`(疑点配 PoC 验真假)/ `dwarf-expert`(源码 ↔ 带 DWARF 二进制对齐)。

> 进 `repos/05-llm-code-audit/trailofbits-skills/` 看它具体收了哪些 skill、怎么装,再挑跟内核 C 相关的用。

## 在流程里怎么摆

- **过滤 ① 假阳性**:cvehound 报命中、kernel-cve-tool 说已 patch → 让 Claude 读那段源码 + vendor 的 backport commit,判断到底修没修。
- **审 backport diff**:vendor backport 上游 fix 时,让 Claude 核对"backport 是否完整覆盖了原始 fix"(漏行/改错很常见)。
- **举一反三**:以一个确认的 bug 为模板,用 `variant-analysis` 扫同一驱动其它入口有没有同款(如"某条错误路径漏 fput/kfree")。
- **解释 + 定优先级**:每条真命中,让 Claude 说清成因、触发条件、在你 config 下够不够得着。

**边界**:LLM 会自信地编。审出来的每个"隐患"都要回源码 + 实测验证,别直接采信。
