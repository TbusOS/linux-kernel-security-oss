#!/usr/bin/env bash
# install-deps — 一键装 linux-kernel-security 的系统依赖。
#
# 装什么:
#   系统包(需 sudo):coccinelle(cvehound 依赖) / ripgrep / gcc-aarch64 交叉编译器 / git / python3 / adb
#   pip 包(用户级,无 sudo):cvehound / kernel-hardening-checker / semgrep
#   可选重家伙(--with-heavy):radare2 / Ghidra(下 release)/ 提示 syzkaller
#
# 用法:
#   bash scripts/install-deps.sh              # 装核心依赖(系统包会用 sudo,先问你)
#   bash scripts/install-deps.sh --dry-run    # 只打印要装什么,不动系统
#   bash scripts/install-deps.sh --with-heavy # 连逆向/fuzz 的重依赖一起
#   bash scripts/install-deps.sh --no-sudo    # 跳过所有要 sudo 的系统包,只装 pip 部分
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
export PYTHONNOUSERSITE=1

DRY=0 ; HEAVY=0 ; NOSUDO=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1;;
    --with-heavy) HEAVY=1;;
    --no-sudo) NOSUDO=1;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "未知参数: $a(见 --help)" >&2; exit 2;;
  esac
done

say()  { printf '\033[1;34m[deps]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---- 探测发行版包管理器 ----
PM="" ; INSTALL=""
if   have apt-get; then PM=apt;    INSTALL="apt-get install -y"
elif have dnf;     then PM=dnf;    INSTALL="dnf install -y"
elif have yum;     then PM=yum;    INSTALL="yum install -y"
elif have pacman;  then PM=pacman; INSTALL="pacman -S --noconfirm"
elif have zypper;  then PM=zypper; INSTALL="zypper install -y"
else warn "认不出包管理器(非 apt/dnf/yum/pacman/zypper)。系统包请照文档手动装。"; fi
say "包管理器: ${PM:-未知}"

# 系统包名按发行版映射(coccinelle 提供 spatch;交叉编译器名各发行版不同)
pkgs_for() {
  case "$PM" in
    apt)    echo "coccinelle ripgrep gcc-aarch64-linux-gnu git python3 python3-pip android-tools-adb grep";;
    dnf|yum) echo "coccinelle ripgrep gcc-aarch64-linux-gnu git python3 python3-pip android-tools grep";;
    pacman) echo "coccinelle ripgrep aarch64-linux-gnu-gcc git python python-pip android-tools grep";;
    zypper) echo "coccinelle ripgrep cross-aarch64-gcc git python3 python3-pip android-tools grep";;
    *)      echo "";;
  esac
}

run_sys() {  # run_sys <描述> <命令...>
  local desc="$1"; shift
  if [ "$DRY" = 1 ]; then echo "  DRY  $*"; return 0; fi
  if [ "$NOSUDO" = 1 ]; then warn "跳过(--no-sudo): $desc"; return 0; fi
  if [ "$(id -u)" -ne 0 ]; then
    say "$desc(用 sudo):sudo $*"
    sudo "$@"
  else
    "$@"
  fi
}

# ---- 1. 系统包 ----
SYSPKGS="$(pkgs_for)"
if [ -n "$SYSPKGS" ]; then
  say "1) 系统包: $SYSPKGS"
  # shellcheck disable=SC2086
  run_sys "装系统依赖" $INSTALL $SYSPKGS || warn "部分系统包没装上,按上面报错手动补。"
else
  warn "1) 跳过系统包(未知发行版)。手动装: coccinelle(spatch) / ripgrep / aarch64 交叉编译器 / git / python3+pip / adb"
fi

# ---- 2. pip 工具(用户级,不需 sudo)----
say "2) pip 工具(用户级):cvehound / kernel-hardening-checker / semgrep"
PIP="python3 -m pip install --user"
for p in cvehound kernel-hardening-checker semgrep; do
  if [ "$DRY" = 1 ]; then echo "  DRY  $PIP $p"; continue; fi
  # shellcheck disable=SC2086
  $PIP "$p" && say "  OK  $p" || warn "  FAIL $p(可能需要更新 pip / python≥3.11)"
done

# ---- 3. 可选:逆向 / fuzz 重依赖 ----
if [ "$HEAVY" = 1 ]; then
  say "3) 重依赖(--with-heavy)"
  case "$PM" in
    apt)    run_sys "装 radare2" $INSTALL radare2 || warn "radare2 建议从源码装最新版: https://github.com/radareorg/radare2";;
    pacman) run_sys "装 radare2" $INSTALL radare2 || true;;
    *)      warn "radare2 请按 https://github.com/radareorg/radare2 装";;
  esac
  cat <<'EOF'
  Ghidra(逆向后端,可选):无包管理器分发,手动下 release ——
    https://github.com/NationalSecurityAgency/ghidra/releases
    解压即用,需 JDK 17+(apt install openjdk-17-jdk / dnf install java-17-openjdk)。
  syzkaller(③ 新洞挖掘,重):需 Go 工具链 + 能跑带 KCOV/KASAN 的内核镜像 ——
    https://github.com/google/syzkaller  (见 docs/03)
EOF
else
  say "3) 跳过重依赖(要装 Ghidra/radare2/syzkaller 加 --with-heavy)"
fi

# ---- 4. 自检 ----
say "4) 自检(缺的按提示补):"
check() { if have "$1"; then printf '  \033[32m✓\033[0m %-26s\n' "$1"; else printf '  \033[31m✗\033[0m %-26s → %s\n' "$1" "$2"; fi; }
check spatch                 "coccinelle 未装(cvehound 依赖)"
check cvehound               "pip install --user cvehound"
check kernel-hardening-checker "pip install --user kernel-hardening-checker"
check semgrep                "pip install --user semgrep(⑤ 自定义规则扫)"
check rg                     "ripgrep(变体分析/搜索快)"
check aarch64-linux-gnu-gcc  "交叉编译 harness 探针(gcc-aarch64-linux-gnu)"
check adb                    "打到 Android 目标机(android-tools-adb)"
check git                    "git"
[ "$HEAVY" = 1 ] && { check radare2 "逆向后端(可选)"; check ghidra "手动下 release(可选)"; }

echo
say "完成。下一步:bash scripts/clone-tools.sh  然后  bin/ksec scan --kernel \$KERNEL"
[ "$DRY" = 1 ] && warn "这是 --dry-run,什么都没真装。"
