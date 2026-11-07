---
name: patching-claude-desktop-zh
description: Use when Claude Desktop on macOS shows English again after an official auto-update, or when the user asks to (re)install/remove the Chinese localization patch (汉化). Also applies to "Claude 变英文了" / "恢复汉化" / "卸载汉化".
---

# Claude Desktop 汉化补丁（macOS）

社区补丁 javaht/claude-desktop-zh-cn 的安装/还原流程。补丁会替换并 ad-hoc 重签
`/Applications/Claude.app`，而**你的会话就运行在这个 app 里**——这是本 skill 全部规则的原因。

## 核心事实（违反任何一条都会造成事故）

1. **绝不在自己的 Bash 工具或 Terminal 面板里前台跑 install/restore。**
   补丁会 `quit` Claude Desktop → app 退出 → 你的 shell 和会话连带被杀 → 补丁死在半途，
   `/Applications` 可能处于"既无补丁也无备份"的最坏状态。必须通过 `run.sh`
   （launchd 脱离 app 进程树）执行。
2. **launch 成功后立刻向用户发告别消息并结束回合。** 之后到补丁跑完前不要再执行任何
   命令——app 随时会退出，任何"等日志/盯进程"的操作都会把自己会话陪葬。
3. **不要用 `install-mac.command`**：它有交互式 `read`（无 tty 会挂死）和不必要的 `sudo`
   卡口（本环境 `/Applications` 归 admin 组可写，无需 sudo）。直接走 `run.sh`。
4. **界面回英文不一定是补丁没了。** 先用 `run.sh status` 区分：
   - app 签名是官方版（非 adhoc）→ 被自动更新覆盖 → 需要 `install`。
   - 已 ad-hoc 签名但界面英文 → 多半只是 config locale 被 app 覆写回 en-US。
     **优先让用户在 app 内 Settings → Language 改回中文**（磁盘直改会被运行中的 app
     回写覆盖；顺序必须是 退出 app→改文件→启动，而退出 app 又会杀你自己的会话）。
5. 自动更新装新版后补丁被覆盖属预期；重跑 `install` 即可恢复（每次都会先拉最新词表）。

## 用法

```bash
bash ~/.claude/skills/patching-claude-desktop-zh/run.sh <action> [lang]
```

| action | 作用 | lang 默认 |
| --- | --- | --- |
| `status` | 只读诊断：app 版本/签名/备份/locale | — |
| `update` | 只拉最新补丁仓库（不装） | — |
| `install` | 拉最新 → 备份现 app → 打补丁 → 重开 | `zh-CN`（可 zh-TW/zh-HK） |
| `restore` | 从最近备份还原官方版 → 重开 | — |

`install`/`restore` 会先 `git fetch --depth 1 + reset` 更新到补丁仓库最新版（词表跟随上游）；
仓库有未提交的本地词表改动时会拒绝，需用户先处理或设 `CLAUDE_ZH_FORCE_UPDATE=1`。
内置 pidfile 单实例守卫（并发第二次会被拒绝）、GitHub 访问自动跟随系统代理。
日志在 `~/Tools/claude-desktop-zh-cn/install.log`（重开会话后查看确认 `exit=0`）。

## 执行 install/restore 的标准流程

1. `run.sh status` 确认场景（见核心事实 4）。
2. 向用户预告：约 8-10 分钟后 Claude 自动退出并以目标语言重开，本会话会中断、历史不丢。
3. `run.sh install` （或 `restore`），确认输出"已启动 (pid …)"。
4. **立即发告别消息，结束回合。** 重开后新会话用 `run.sh status` + 查看 install.log 验证。

## 已版本适配说明

按 app 4.23118.0 / 补丁 1.4.23 实测全流程通过（dry-run + 真实 install/restore）。
斜杠菜单 gloss 在该版找不到锚点会 WARNING 并跳过，属良性，无需处理。
