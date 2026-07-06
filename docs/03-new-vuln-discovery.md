# 03 · 新漏洞挖掘(LLM + fuzzing)

**目标**:找**还没人发现**的洞——将来的 CVE。这是研究级工作,成本远高于 ①②。实产真 CVE 的路子不是"让 LLM 读源码报洞"(误报高、塞不下上下文),而是 **LLM 生成/精化 fuzzer 输入,交给 syzkaller 实跑触发**。

## KernelGPT(本类核心)

来源:[github.com/ise-uiuc/KernelGPT](https://github.com/ise-uiuc/KernelGPT) · 论文 [arXiv:2401.00563](https://arxiv.org/abs/2401.00563)(ASPLOS 2025)· 本地:`repos/03-new-vuln-discovery/KernelGPT/`

**做什么**:用 LLM 从内核源码分析里**自动推断并精化 Syzkaller 规格(syscall 描述)**,喂给 syzkaller 去 fuzz。默认 syzkaller 覆盖不到的 syscall,靠 LLM 生成描述后就能测到。

**战绩(README 自述)**:
- 在 Linux 内核发现 **24 个新 bug**
- 其中 **11 个拿到 CVE 编号**(12 个已修)
- 多条 KernelGPT 生成的规格已被合并进官方 Syzkaller 仓库

**工作方式**:
- 自动规格推断:LLM 读内核源码 → 生成 Syzkaller 规格
- 迭代精化:用验证反馈自动修错、改进生成的规格

**依赖(重)**:
- Python ≥ 3.8
- git submodules(会拉论文用的特定 Linux 版本 + syzkaller 到 `linux/` `syzkaller/`)
- build 工具:`make` / gcc / `bear`
- **Clang 14**(分析工具要求)
- **一套能跑的 Syzkaller**,target 是 Linux 内核(按官方 setup 搭)
- 一份本地 Linux 内核源码

> clone-tools.sh 用了 `--depth 1` 且没 init submodule,所以 `linux/` `syzkaller/` 是空的。真要跑得 `git submodule update --init --recursive`(会拉一个完整内核,很大)+ 按 README 搭 syzkaller。

**跑起来的门槛**:要能编译一个带 KCOV / KASAN 的内核镜像,在 QEMU/VM 里被 syzkaller 持续 fuzz。这套环境本身就是个工程,不是 pip install 就完事。

## 同方向的其他工作(仓库需自行确认,不臆造链接)

搜索里出现、但**未逐个验证过真实仓库地址**的相关研究,列名字供你顺藤摸:
- **SyzAgent** — LLM 实时引导 syzkaller 的变异/生成
- **SyzGPT** — fuzzing + LLM
- **KNighter** — 用 LLM **合成静态分析 checker**(Clang Static Analyzer 风格)找内核 bug 模式;这条是"LLM 配静态 checker",跟 KernelGPT 的"LLM 配 fuzzer"互补
- **Live-kBench** — 持续从 Syzbot 抓新内核 bug 做评测的自演进 benchmark

## 收藏级研究索引

[huhusmang/Awesome-LLMs-for-Vulnerability-Detection](https://github.com/huhusmang/Awesome-LLMs-for-Vulnerability-Detection) — LLM 做漏洞检测的最全研究索引,持续更新,含 function-level / repo-level / agentic / 数据集 / benchmark。挖内核方向论文从这儿找。

## 现实预期

- 这条路能出真 CVE,但**投入产出比对工程团队通常不划算**——除非你就是做内核安全研究。
- 落地建议:先把 ①②(已知 CVE + 加固)吃干净,ROI 高得多。③ 作为进阶方向储备。
