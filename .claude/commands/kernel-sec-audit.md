---
description: Layer 2 · 用 trailofbits skills 对一棵内核源码/驱动做 LLM 安全审计,产出人读发现追加到报告
---

# /kernel-sec-audit <内核源码或驱动子目录>

对给定的内核源码(或某个驱动子目录)做**语义级安全审计**,补 `bin/ksec`(Layer 1 确定性静态)之外的一层。用 `repos/05-llm-code-audit/trailofbits-skills` 的 skill 做审计,产出人读的发现。

## 前置

- 已 `bash scripts/clone-tools.sh` 拉到 `repos/05-llm-code-audit/trailofbits-skills`。
- 目标是**你自己拥有或有授权**的内核 / 驱动源码。

## 流程

1. **划范围** — 用 `entry-point-analyzer` 枚举目标的 ioctl / syscall / 驱动入口,列出要审的 handler 清单。
2. **逐个审** — 用 `c-review` 对每个 handler 审内存安全:
   - 每条返回路径(尤其错误路径)上分配的资源(fd / file / 内存 / 锁)是否都释放或转移
   - UAF / double-free / 越界 / 整数溢出 / race
3. **举一反三** — 对确认或高度可疑的一个 bug,用 `variant-analysis` 以它为模板扫同一子系统的其它入口有没有同款。
4. **机械补漏** — 用 `static-analysis`(semgrep/codeql)对模式化的问题全量扫,补 LLM 遗漏。
5. **验真假** — 每个疑点用 `fp-check` 配最小 PoC 判真假,过滤误报。
6. **输出** — 每条发现给:位置(`file:line`)、类型、触发条件、影响、修复建议、置信度。追加到 `out/report.md` 的"Layer 2 · LLM 审计"小节。

## 纪律

- LLM 会自信地编。每条发现都标**置信度**,高置信的也要回源码 + 尽量实测(Layer 3 harness)坐实。
- 只报**能落到 `file:line` 的具体问题**,不写"这里可能不安全"这种空话。
- 找到的目标是**修复**:每条发现配可操作的 fix 方向。
