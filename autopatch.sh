#!/bin/bash
# Claude Desktop 汉化「自动重打」：被官方自动更新覆盖后，自动重新打补丁。
# 由 LaunchAgent 调用（登录时一次 + 每 30 分钟一次）。
# 只读检测 -> 命中才调用 run.sh install；run.sh 自己会脱离 app 进程树并立刻返回。
set -uo pipefail

# 优先用与自身同目录的 run.sh（安装到 Application Support 的自包含副本走这条路）；
# 否则回退到 skill 目录。软链到 ~/Documents 时 launchd 会被 TCC 拒绝，必须用副本。
SELF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -n "$SELF_DIR" ] && [ -x "$SELF_DIR/run.sh" ]; then
  RUN="$SELF_DIR/run.sh"
else
  SKILL_DIR="${CLAUDE_ZH_SKILL_DIR:-$HOME/.claude/skills/patching-claude-desktop-zh}"
  RUN="$SKILL_DIR/run.sh"
fi
REPO_DIR="${CLAUDE_ZH_REPO:-$HOME/Tools/claude-desktop-zh-cn}"
STATE_DIR="${CLAUDE_ZH_AUTOPATCH_STATE:-$HOME/Library/Application Support/claude-zh-autopatch}"
STATE="$STATE_DIR/last-attempt"
LOG="$STATE_DIR/autopatch.log"
BACKOFF_SECONDS="${CLAUDE_ZH_AUTOPATCH_BACKOFF:-3600}"   # 一轮失败后一小时再试

mkdir -p "$STATE_DIR"
log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
readver() { /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/Claude.app/Contents/Info.plist 2>/dev/null || echo '?'; }

# 1) 平台与依赖
[ "$(uname -s)" = "Darwin" ] || { log "非 macOS，退出"; exit 0; }
[ -x "$RUN" ] || { log "找不到可执行的 run.sh：$RUN"; exit 1; }
command -v codesign >/dev/null 2>&1 || { log "缺少 codesign，退出"; exit 0; }
[ -d /Applications/Claude.app ] || { log "未找到 Claude.app，跳过"; exit 0; }

# 2) 已有补丁进程在跑（用户手动触发或上一轮未结束）就跳过
if [ -f "$REPO_DIR/.patch.pid" ] && kill -0 "$(cat "$REPO_DIR/.patch.pid")" 2>/dev/null; then
  log "已有补丁进程在运行，跳过"; exit 0
fi

# 3) 稳定性复查：Squirrel 的 ShipIt 是常驻进程，不能用 pgrep 判断；
#    改为「签名读得到 + 版本 3 秒内不变」，避免在 bundle 正被替换时插手。
sig="$(codesign -dv /Applications/Claude.app 2>&1)" || { log "codesign 读取失败（可能正在被替换），跳过"; exit 0; }
ver1="$(readver)"; sleep 3; ver2="$(readver)"
if [ "$ver1" != "$ver2" ]; then log "版本不稳定（$ver1 -> $ver2），疑似正在更新，跳过"; exit 0; fi

# 4) 核心判定：签名已是 adhoc = 补丁还在，无需动作
case "$sig" in
  *Signature=adhoc*) log "已是汉化版（$ver2），跳过"; exit 0 ;;
esac

# 5) app 可写性（沙箱/权限不足就跳过）
PROBE="/Applications/.claude-zh-autopatch-write-test.$$"
if ! touch "$PROBE" 2>/dev/null; then log "/Applications 不可写，跳过"; exit 0; fi
rm -f "$PROBE"

# 6) 失败退避：避免网络/磁盘问题导致每 30 分钟反复重试
if [ -f "$STATE" ]; then
  last="$(cat "$STATE" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  case "$last" in ''|*[!0-9]*) last=0 ;; esac
  if [ "$((now - last))" -lt "$BACKOFF_SECONDS" ]; then
    log "距上次尝试不足 ${BACKOFF_SECONDS}s，跳过"; exit 0
  fi
fi

# 7) 命中：记录时间、通知用户、交给 run.sh（它会 launchctl 脱离并立即返回）
date +%s > "$STATE"
log "检测到官方版（$ver2），开始自动重打"
[ "${CLAUDE_ZH_AUTOPATCH_NO_NOTIFY:-0}" = "1" ] || osascript -e 'display notification "检测到 Claude Desktop 已更新，正在自动重新汉化，约 8-10 分钟后自动重开。" with title "汉化补丁"' >/dev/null 2>&1 || true

"$RUN" install >> "$LOG" 2>&1
rc=$?
[ $rc -eq 0 ] || log "run.sh install 返回 $rc（详见 $REPO_DIR/install.log）"
exit 0
