#!/usr/bin/env bash
# 一键克隆本库全部第三方工具到 repos/ 下对应类目录。
# repos/ 的字节不进 git(见 .gitignore),靠本脚本可复现地重建工具树。
# 用法:  bash scripts/clone-tools.sh           # 浅克隆(默认,省空间)
#         DEPTH=full bash scripts/clone-tools.sh # 完整历史
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PYTHONNOUSERSITE=1
export GIT_TERMINAL_PROMPT=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPOS="$ROOT/repos"

DEPTH_ARG="--depth 1"
[ "${DEPTH:-shallow}" = "full" ] && DEPTH_ARG=""

# 格式:  <类目录>|<目标名>|<git url>
TOOLS="
01-known-cve-detection|cvehound|https://github.com/evdenis/cvehound.git
01-known-cve-detection|linux_kernel_cves|https://github.com/nluedtke/linux_kernel_cves.git
01-known-cve-detection|kernel-cve-tool|https://github.com/madisongh/kernel-cve-tool.git
02-config-hardening|kernel-hardening-checker|https://github.com/a13xp0p0v/kernel-hardening-checker.git
03-new-vuln-discovery|KernelGPT|https://github.com/ise-uiuc/KernelGPT.git
04-impact-rating|linux-kernel-exploitation|https://github.com/xairy/linux-kernel-exploitation.git
05-llm-code-audit|claude-code-security-review|https://github.com/anthropics/claude-code-security-review.git
05-llm-code-audit|trailofbits-skills|https://github.com/trailofbits/skills.git
06-binary-re|GhidraMCP|https://github.com/LaurieWired/GhidraMCP.git
06-binary-re|radare2-mcp|https://github.com/radareorg/radare2-mcp.git
"

echo "克隆到: $REPOS  (DEPTH=${DEPTH:-shallow})"
echo "$TOOLS" | while IFS='|' read -r cat name url; do
  [ -z "${cat:-}" ] && continue
  dst="$REPOS/$cat/$name"
  mkdir -p "$REPOS/$cat"
  if [ -d "$dst/.git" ]; then
    echo "SKIP  $cat/$name (已存在)"
    continue
  fi
  echo ">>>   $cat/$name  <-  $url"
  if git clone $DEPTH_ARG -q "$url" "$dst"; then
    echo "OK    $cat/$name  ($(du -sh "$dst" 2>/dev/null | cut -f1))"
  else
    echo "FAIL  $url"
  fi
done

echo "完成。KernelGPT 要真跑还需: cd repos/03-new-vuln-discovery/KernelGPT && git submodule update --init --recursive"
