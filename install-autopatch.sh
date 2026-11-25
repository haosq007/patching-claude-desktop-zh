#!/bin/bash
# 安装 / 卸载 / 查看「汉化自动重打」LaunchAgent
set -euo pipefail

SKILL_DIR="${CLAUDE_ZH_SKILL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LABEL="com.haosq.claude-zh-autopatch"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
STATE_DIR="$HOME/Library/Application Support/claude-zh-autopatch"
UID_N="$(id -u)"

do_install() {
  [ "$(uname -s)" = "Darwin" ] || { echo "仅支持 macOS" >&2; exit 1; }
  [ -x "$SKILL_DIR/autopatch.sh" ] || { echo "缺少 autopatch.sh：$SKILL_DIR" >&2; exit 1; }

  mkdir -p "$HOME/Library/LaunchAgents" "$STATE_DIR"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SKILL_DIR/autopatch.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>1800</integer>
    <key>StandardOutPath</key>
    <string>$STATE_DIR/launchd.out</string>
    <key>StandardErrorPath</key>
    <string>$STATE_DIR/launchd.err</string>
</dict>
</plist>
EOF
  launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$UID_N" "$PLIST"
  launchctl enable "gui/$UID_N/$LABEL" 2>/dev/null || true
  launchctl kickstart -k "gui/$UID_N/$LABEL" 2>/dev/null || true
  echo "✅ 已安装自动重打：登录时检查一次，之后每 30 分钟检查一次"
  echo "   日志: $STATE_DIR/autopatch.log"
  echo "   卸载: bash $SKILL_DIR/install-autopatch.sh uninstall"
}

do_uninstall() {
  launchctl bootout "gui/$UID_N/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "✅ 已卸载自动重打（$LABEL）"
}

do_status() {
  if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
    echo "自动重打: 已加载（$LABEL）"
    launchctl print "gui/$UID_N/$LABEL" 2>/dev/null | grep -E "state =|last exit code|runs =|program =" | head -5
  else
    echo "自动重打: 未加载"
  fi
  echo "--- 最近日志 ---"
  tail -5 "$STATE_DIR/autopatch.log" 2>/dev/null || echo "（暂无日志）"
}

case "${1:-install}" in
  install) do_install ;;
  uninstall|remove) do_uninstall ;;
  status) do_status ;;
  *) echo "用法: $0 [install|uninstall|status]" >&2; exit 1 ;;
esac
