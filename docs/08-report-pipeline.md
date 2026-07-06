# 08 · 报告流水线:三层怎么并成一份报告

`bin/ksec` 把三层检测的结果并进 `out/` 下一份报告。三层由浅入深,各自独立可跑:

```
L1 静态(确定性)   ksec scan   → out/results/*.json ─┐
L2 LLM 审计(可选)  /kernel-sec-audit → 追加发现     ├─→ ksec report → out/report.md / .html
L3 动态(自家设备)  ksec dynamic slabmon → slabmon.json ┘
```

## L1 · 静态(无需 LLM)

```bash
export KERNEL=/path/to/your/kernel
bin/ksec scan --kernel "$KERNEL" --config "$KERNEL/.config"   # cvehound + 加固 + (可选)kernel-cve-tool
bin/ksec report --html
```
缺依赖的扫描器会标 `skipped`(不是"没问题",是没跑),按 reason 补齐再跑。

## L2 · LLM 审计(需 Claude Code)

在本仓库目录起 Claude Code:
```
/kernel-sec-audit <内核源码或驱动子目录>
```
它编排 trailofbits 的 `c-review` / `variant-analysis` / `entry-point-analyzer`,产出人读的审计发现。定义见 `.claude/commands/kernel-sec-audit.md`。

## L3 · 动态(自家设备)

```bash
# 前置检查
bin/ksec dynamic check
# 跑 slab 泄漏监控(配 harness 探针)
bin/ksec dynamic slabmon --adb <SERIAL> --cmd '/data/local/tmp/probe' --total 40000 --step 2000
```
结果 `slabmon.json` 会被 `ksec report` 并进报告。更强的自动化(kmemleak / syzkaller)见 `harness/README.md` + `docs/03`。

## 边界

- L1 是确定性事实,L2 是 LLM 提示(要回源码验证),L3 是设备上的实测行为。
- 报告里三者分开呈现,别把 L2 的"疑似"当成 L1 的"确认"。
