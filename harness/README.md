# harness · 动态检测(Layer 3)

静态扫不出的东西(真实泄漏率、运行时行为)靠这里。核心是"跑 N 次 ioctl 看 slab 是否线性增长"来确认某驱动的错误路径漏没漏释放,并回归验证修复。

## 文件

| 文件 | 作用 |
|---|---|
| `ioctl_leak_probe.c` | 通用 ioctl 泄漏回归探针。改 3 处(设备节点 / ioctl 号 / 入参)即用 |
| `slabmon.sh` | 分块跑 workload,每块读 `/proc/meminfo` Slab,算 Δ/次 → 泄漏率。本地或走 adb |

## 完整流程(以一个虚构 `/dev/foo` 驱动为例)

```bash
# 1. 按目标改 ioctl_leak_probe.c:DEV_PATH(/dev/foo)/ IOCTL_CMD / 入参
# 2. 交叉编译成 arm64 静态二进制
aarch64-linux-gnu-gcc -O2 -static harness/ioctl_leak_probe.c -o /tmp/probe
# 3. 推到目标机
adb -s <SERIAL> push /tmp/probe /data/local/tmp/probe
adb -s <SERIAL> shell chmod 755 /data/local/tmp/probe

# 4. 跑 slab 监控(每块 2000 次,共 40000 次;走 adb)
bin/ksec dynamic slabmon --adb <SERIAL> \
    --cmd '/data/local/tmp/probe' --total 40000 --step 2000
# 结果写 out/results/slabmon.json,ksec report 会并进报告

# 5. 出报告
bin/ksec report --html
```

预期:若有泄漏,Slab 随迭代**线性增长、无上限**。修复(错误路径补 `fput`/`kfree`)后重跑,Slab 应平。

## 直接用 slabmon.sh(不经 ksec)

```bash
bash harness/slabmon.sh --cmd './probe' --total 40000 --step 2000 --json out.json      # 本地目标
bash harness/slabmon.sh --adb <SERIAL> --cmd '/data/local/tmp/probe' --total 40000      # adb
```

## 更强的自动化:kmemleak / syzkaller

- **kmemleak**(点名泄漏点,不用自己推):目标内核开 `CONFIG_DEBUG_KMEMLEAK`,跑完 workload 后
  ```bash
  adb shell 'echo scan > /sys/kernel/debug/kmemleak; cat /sys/kernel/debug/kmemleak'
  ```
  直接打印未释放对象的分配栈。
- **syzkaller + KASAN/kmemleak**(自动扫这一类,不止单个 cmd):见 `../docs/03-new-vuln-discovery.md` + `../docs/08-report-pipeline.md`。KernelGPT 生成目标驱动的 ioctl 描述喂给它。

## 授权

动态复现 = 在活的目标上实跑。**只对自己的设备 / 授权靶场**操作。
