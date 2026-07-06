#!/usr/bin/env bash
# slabmon — 动态内核内存泄漏监控(Layer 3)。
# 方法:分块跑一个 workload,每块后读 /proc/meminfo 的 Slab,算 Δ/次 → 泄漏率。
# 通用化的"跑 N 次 ioctl 看 slab 线性增长"那套。
#
# 用法(在目标机本地,或通过 adb 打到设备):
#   slabmon.sh --cmd './probe' --total 40000 --step 2000 [--adb SERIAL] [--json out.json]
#   --cmd    每块要跑的命令,会被调用为  <cmd> <step>  (workload 自己跑 step 次)
#   --total  总迭代次数    --step 采样步长
#   --adb    有值则所有命令走  adb -s SERIAL shell  打到设备;无则本地跑
#   --json   结果写 JSON(给 ksec report 用)
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

CMD="" ; TOTAL=40000 ; STEP=2000 ; ADB="" ; JSON=""
while [ $# -gt 0 ]; do
  case "$1" in
    --cmd) CMD="$2"; shift 2;;
    --total) TOTAL="$2"; shift 2;;
    --step) STEP="$2"; shift 2;;
    --adb) ADB="$2"; shift 2;;
    --json) JSON="$2"; shift 2;;
    *) echo "未知参数: $1" >&2; exit 2;;
  esac
done
[ -n "$CMD" ] || { echo "缺 --cmd" >&2; exit 2; }

# 命令包装:本地 or adb
SH() { if [ -n "$ADB" ]; then adb -s "$ADB" shell "$@"; else sh -c "$@"; fi; }
slab_kb() { SH "grep '^Slab:' /proc/meminfo" | awk '{print $2}'; }

base=$(slab_kb)
echo "baseline Slab = ${base} kB ; total=${TOTAL} step=${STEP} ; ${ADB:+adb=$ADB}"
printf "%-10s %-12s %-12s %-12s\n" "iter" "Slab(kB)" "Δ/step(kB)" "B/call"

prev=$base ; rows="" ; last_rate=0
i=$STEP
while [ "$i" -le "$TOTAL" ]; do
  SH "$CMD $STEP" >/dev/null 2>&1 || true
  cur=$(slab_kb)
  dkb=$(( cur - prev ))
  bcall=$(awk -v d="$dkb" -v s="$STEP" 'BEGIN{printf "%.0f", d*1024.0/s}')
  printf "%-10s %-12s %-12s %-12s\n" "$i" "$cur" "$dkb" "$bcall"
  rows="${rows}{\"iter\":$i,\"slab_kb\":$cur,\"delta_kb\":$dkb,\"b_per_call\":$bcall},"
  prev=$cur ; last_rate=$bcall ; i=$(( i + STEP ))
done

total_kb=$(( prev - base ))
verdict="疑似泄漏"
[ "$total_kb" -le 0 ] && verdict="未见增长(此 workload 无明显泄漏)"
echo "总增长 ${total_kb} kB;末段约 ${last_rate} B/call;判定:${verdict}"

if [ -n "$JSON" ]; then
  cat > "$JSON" <<EOF
{
  "tool": "slabmon",
  "status": "ok",
  "kind": "动态·slab 泄漏监控",
  "findings": ["总增长 ${total_kb} kB / ${TOTAL} 次","末段泄漏率 ~${last_rate} B/call","判定: ${verdict}"],
  "cmd": "${CMD}", "total": ${TOTAL}, "step": ${STEP},
  "baseline_kb": ${base}, "final_kb": ${prev}, "growth_kb": ${total_kb},
  "series": [${rows%,}]
}
EOF
  echo "JSON: $JSON"
fi
