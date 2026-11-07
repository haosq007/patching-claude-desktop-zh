#!/bin/bash
# claude-desktop-zh skill 配套脚本：先拉最新补丁仓库，再以脱离 app 的方式执行。
# 用法: run.sh install|restore|update|status [zh-CN|zh-TW|zh-HK]
set -euo pipefail

REPO_DIR="${CLAUDE_ZH_REPO:-$HOME/Tools/claude-desktop-zh-cn}"
REMOTE="https://github.com/javaht/claude-desktop-zh-cn.git"
PYTHON="/usr/bin/python3"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"
LOG="$REPO_DIR/install.log"
GRACE="${CLAUDE_ZH_GRACE:-20}"   # 秒：留给 agent 发出告别消息，到点后补丁会退出 Claude

ACTION="${1:-install}"
LANG_CODE="${2:-zh-CN}"
case "$LANG_CODE" in zh-CN|zh-TW|zh-HK) ;; *) echo "无效语言: $LANG_CODE (应为 zh-CN / zh-TW / zh-HK)" >&2; exit 1 ;; esac

# bash 不读 .zshenv：从 macOS 系统代理配置取 http(s) 代理，GitHub 访问需要
if [ -z "${HTTPS_PROXY:-}" ] && command -v scutil >/dev/null 2>&1; then
  _ph="$(scutil --proxy | awk '$1=="HTTPSProxy"{h=$3} $1=="HTTPSPort"{p=$3} $1=="HTTPSEnable"&&$3==1{en=1} END{if(en&&h&&p)print h":"p}')"
  [ -n "$_ph" ] && export http_proxy="http://$_ph" https_proxy="http://$_ph" HTTP_PROXY="http://$_ph" HTTPS_PROXY="http://$_ph"
  unset _ph
fi

ensure_repo() {
  if [ ! -d "$REPO_DIR/.git" ]; then
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone --depth 1 "$REMOTE" "$REPO_DIR"
  fi
}

update_repo() {
  local br
  br="$(cd "$REPO_DIR" && git rev-parse --abbrev-ref HEAD)"
  # 保护用户自己改过的词表/脚本：已跟踪文件有本地改动就拒绝硬重置
  if [ -n "$(cd "$REPO_DIR" && git status --porcelain --untracked-files=no)" ]; then
    echo "补丁仓库有未提交的本地修改，拒绝更新以免丢失。请先自行处理（git stash / commit），或设 CLAUDE_ZH_FORCE_UPDATE=1 强制覆盖。" >&2
    [ "${CLAUDE_ZH_FORCE_UPDATE:-0}" = "1" ] || exit 1
    echo "CLAUDE_ZH_FORCE_UPDATE=1，继续强制更新……" >&2
  fi
  local before
  before="$(python3 -c "import json;print(json.load(open('$REPO_DIR/resources/release.json'))['release'])" 2>/dev/null || echo '?')"
  (cd "$REPO_DIR" && git fetch --depth 1 origin "$br" && git reset --hard FETCH_HEAD --quiet)
  local after
  after="$(python3 -c "import json;print(json.load(open('$REPO_DIR/resources/release.json'))['release'])" 2>/dev/null || echo '?')"
  echo "补丁仓库版本: $before -> $after"
}

status() {
  echo "=== Claude.app ==="
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/Claude.app/Contents/Info.plist 2>/dev/null || echo "未安装"
  codesign -dv /Applications/Claude.app 2>&1 | grep -qE 'Signature=adhoc|TeamIdentifier=not set' \
    && echo "已汉化（ad-hoc 签名）" || echo "官方版（未汉化或被更新覆盖）"
  echo "=== 备份 ==="
  ls -d /Applications/Claude.backup-before-zh-* 2>/dev/null || echo "(无备份)"
  echo "=== locale ==="
  for f in "$HOME/Library/Application Support/Claude/config.json" "$HOME/Library/Application Support/Claude-3p/config.json"; do
    [ -f "$f" ] && echo "$(basename "$(dirname "$f")"): $(grep -o '"locale": *"[^"]*"' "$f" | head -1 || echo '(未设置)')"
  done
  echo "=== 补丁仓库 ==="
  [ -d "$REPO_DIR" ] && echo "$REPO_DIR @ $(python3 -c "import json;print(json.load(open('$REPO_DIR/resources/release.json'))['release'])" 2>/dev/null || echo unversioned)" || echo "(未 clone)"
}

case "$ACTION" in
  status) status; exit 0 ;;
  update) ensure_repo; update_repo; exit 0 ;;
esac

# install / restore：先更新，再脱离 Claude.app 进程树执行（否则退出 app 会连带杀掉本进程）
# 注意：测试桩仓库务必设 CLAUDE_ZH_SKIP_UPDATE=1，否则 update 会把 GitHub 真实代码拉下来覆盖桩
ensure_repo
[ "${CLAUDE_ZH_SKIP_UPDATE:-0}" = "1" ] || update_repo
case "$ACTION" in
  install) PYARGS=(--lang "$LANG_CODE" --launch) ;;
  restore) PYARGS=(--restore --launch) ;;
  *) echo "未知动作: $ACTION" >&2; exit 1 ;;
esac

# 单实例守卫：已有补丁在跑就拒绝并发
PIDFILE="$REPO_DIR/.patch.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "已有补丁进程在运行 (pid $(cat "$PIDFILE"))。等它结束，或先删除 ${PIDFILE}。" >&2
  exit 1
fi

echo "开始 ${ACTION} (语言 ${LANG_CODE})：补丁将在约 ${GRACE}s 后退出 Claude Desktop，本会话随之中断；完成后 app 自动重开。"
echo "日志: $LOG"
launchctl asuser "$(id -u)" /bin/bash -c "
  nohup /bin/bash -c '
    cd \"$REPO_DIR\" || exit 1
    echo \$\$ > \"$PIDFILE\"
    { echo \"==== $ACTION $LANG_CODE \$(date)\"; sleep $GRACE
      \"$PYTHON\" scripts/patch_claude_zh_cn.py --user-home \"$HOME\" ${PYARGS[*]} 2>&1
      echo \"exit=\$? \$(date)\"; rm -f \"$PIDFILE\"; } >> \"$LOG\" 2>&1
  ' >/dev/null 2>&1 & disown
"
sleep 1.5
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "已启动 (pid $(cat "$PIDFILE")，已脱离 app 进程树)。下一步：立刻向用户告别并结束回合，勿再执行其他操作。"
else
  echo "启动失败，请检查 $LOG"
fi
