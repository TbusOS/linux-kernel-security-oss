# 06 · 二进制逆向 + 把逆向接进 Claude

**什么时候需要这一类**(前面 ①–⑤ 都在源码层,这一类专治二进制):
- 手上只有 `.ko` / 固件,没源码
- 有源码,但要证明**出厂那颗二进制**确实带某 bug(shipped 固件 ≠ 源码 HEAD)
- 漏洞分析要落到汇编级(寄存器分配、编译器优化导致的 bug)

> 举例:一个"错误路径漏 fput"的 bug,源码里 `fput` 逻辑看着"应该有",但编译器在错误路径复用了某个寄存器导致实际没调用——这种真相要到汇编才看得清。有源码也可能得逆向出厂 `.ko` 来证明客户手上那颗模块确实中招。

## 分两层:逆向后端 + 接 Claude 的 MCP 桥

**后端(真正反汇编/反编译的引擎)**:
| 工具 | 性质 | 对 AArch64 .ko | 备注 |
|---|---|---|---|
| **Ghidra** | 免费(NSA),反编译出接近 C 的伪码 | 强,ARM64 支持好 | 下 release,需 JDK 17+ |
| **radare2 / rizin** | 免费开源,CLI + Cutter GUI | 好,轻量 | `scripts/install-deps.sh --with-heavy` |
| IDA Pro | 商业,反编译最强 | 强 | 需授权 |
| objdump / nm / readelf | binutils,纯反汇编 | 只反汇编无伪码 | 一般已装 |

> 若目标 `.ko` 带完整 DWARF(not stripped),objdump 就能出带函数名的汇编;但要读伪码、追数据流,Ghidra 体验好很多。

**接 Claude 的 MCP 桥(让 Claude 直接驱动逆向后端)**——本库克隆的:
| 仓库 | 后端 | 说明 |
|---|---|---|
| **[LaurieWired/GhidraMCP](https://github.com/LaurieWired/GhidraMCP)** | Ghidra | 原版、最流行。把 Ghidra 反编译/改名/标注/搜漏洞暴露给 Claude,让 LLM 自主逆向 |
| **[radareorg/radare2-mcp](https://github.com/radareorg/radare2-mcp)** | radare2 | 官方出品,MIT。Claude Code/Desktop/Cursor 等都能接 |

**其他真实实现(未克隆,备选)**:
- [13bm/GhidraMCP](https://github.com/13bm/GhidraMCP) — socket 版,70 个逆向工具
- [bethington/ghidra-mcp](https://github.com/bethington/ghidra-mcp) — 200+ 工具,含 P-code 仿真、调试器联动
- [mrexodia/ida-pro-mcp](https://github.com/mrexodia/ida-pro-mcp) — IDA Pro 的 MCP(有 IDA 授权时用)

## 用逆向核对一个 ioctl bug 的流程(虚构 `foo.ko` 为例)

1. 装 Ghidra(下 release,解压即用,需 JDK)
2. Ghidra 导入 `foo.ko`(带 DWARF → 函数名/类型齐全),自动分析
3. 起 GhidraMCP 插件 + bridge,在 Claude Code/Desktop 配置里指向它
4. 让 Claude:
   - 定位 `foo_ioctl`,列出 cmd dispatcher 各 handler
   - 反编译某个 cmd handler,追 fd/fence/file 三个资源在正常路径 vs 错误路径的释放
   - 核对错误路径有没有 `fput` 调用
   - 举一反三:其他 cmd handler 同款检查

## 和 ⑤(源码审计)的分工

| | ⑤ 源码审计 | ⑥ 二进制逆向 |
|---|---|---|
| 输入 | `.c` 源码 | `.ko` / 固件 |
| 快 / 准 | 快,能看注释和意图 | 慢,但反映**真实出厂产物** |
| 抓编译器导致的 bug(如寄存器复用) | 看不出(源码层看不到寄存器分配) | **能**,汇编级可见 |
| 场景 | 日常审代码、找 + 修 | 证明 shipped 固件含 bug、无源码时 |

编译器优化导致的 bug 特殊在:根因在汇编,源码层看不到。所以 ⑤ 找可疑点、⑥ 汇编级坐实,两者配合最稳。
