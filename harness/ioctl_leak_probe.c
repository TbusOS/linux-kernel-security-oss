/*
 * ioctl_leak_probe — 通用 ioctl 内核内存泄漏回归探针(Layer 3 · 防御性检测)。
 *
 * 目的:确认某驱动的某条 ioctl 路径是否**漏释放**(错误路径没 fput/kfree),
 * 并在修复后回归验证。做法:把该 ioctl 反复调用 N 次,配 slabmon.sh 观察
 * 内核 slab 是否**无上限线性增长**——增长 = 有泄漏,平 = 无泄漏/已修好。
 * 这是一个泄漏检测/回归工具,不做任何利用。
 *
 * 用法:  ./probe <iterations>
 * 交叉编译(arm64 目标):
 *   aarch64-linux-gnu-gcc -O2 -static ioctl_leak_probe.c -o probe
 *   adb push probe /data/local/tmp/ ; adb shell chmod 755 /data/local/tmp/probe
 *
 * ↓↓↓ 按被测驱动改这三处(下面是虚构示例值)↓↓↓
 *   DEV_PATH   目标设备节点(示例: /dev/foo)
 *   IOCTL_CMD  ioctl 命令号(示例占位: 0x00000000,改成你要测的那个 cmd)
 *   arg 结构   按该 ioctl 的入参填
 */
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>

#define DEV_PATH   "/dev/foo"             /* TODO: 改成目标设备节点 */
#define IOCTL_CMD  0x00000000u            /* TODO: 改成目标 ioctl 号 */

int main(int argc, char **argv)
{
    long iters = (argc > 1) ? atol(argv[1]) : 2000;

    int fd = open(DEV_PATH, O_RDWR);
    if (fd < 0) { perror("open " DEV_PATH); return 1; }

    /*
     * 要暴露"错误路径漏释放",就得让 ioctl 走进那条错误分支。
     * 常见做法:给 ioctl 传一个不可写的地址,内核里的 copy_to_user 会失败,
     * 从而进入"错误返回"那一支——正是可能漏 fput/kfree 的地方。
     * 用只读 mmap 页做参数缓冲。按实际 ioctl 入参调整。
     */
    void *ro = mmap(NULL, 4096, PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (ro == MAP_FAILED) { perror("mmap"); close(fd); return 1; }

    long ok = 0, err = 0;
    for (long i = 0; i < iters; i++) {
        int r = ioctl(fd, IOCTL_CMD, ro);   /* 期望失败并走错误路径 */
        if (r < 0) err++; else ok++;
    }
    fprintf(stderr, "done: iters=%ld ok=%ld err=%ld\n", iters, ok, err);
    munmap(ro, 4096);
    close(fd);
    return 0;
}
