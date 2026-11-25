# Claude Desktop 汉化 skill（macOS）

一个 [Claude Code / Claude Agent skill](https://docs.claude.com/en/docs/claude-code/skills)，
用于安装、恢复和卸载 [javaht/claude-desktop-zh-cn](https://github.com/javaht/claude-desktop-zh-cn)
这套 Claude Desktop 中文界面补丁。

## 为什么需要它

汉化补丁会**退出并替换 `/Applications/Claude.app`**，而让 Claude 跑补丁的这个会话，
本身就在同一个 app 里。直接执行 install/restore，会话会连同补丁一起被杀在半路，
`/Applications` 有可能停在"既无补丁也无备份"的状态。

本 skill 的全部规则都是为了绕开这一点：补丁通过 `launchctl asuser` + `nohup`
脱离 app 进程树执行，agent 发出启动确认后立刻结束回合，把剩下的交给系统。

## 安装 skill

```bash
git clone https://github.com/haosq007/patching-claude-desktop-zh.git \
  ~/.claude/skills/patching-claude-desktop-zh
```

之后对 Claude 说「帮我把 Claude Desktop 恢复汉化」即可触发。

## 直接用脚本

不装 skill 也能单独用：

```bash
bash run.sh status    # 只读诊断：app 版本 / 签名 / 备份 / locale
bash run.sh update    # 只拉最新补丁仓库，不安装
bash run.sh install   # 备份现 app → 打补丁 → 重开（默认 zh-CN）
bash run.sh install zh-TW   # 改用繁中（可 zh-CN / zh-TW / zh-HK）
bash run.sh restore   # 从最近备份还原官方版
```

`install` / `restore` 会让 Claude Desktop 在约 20 秒后退出、约 8-10 分钟后自动重开。

## 自动重打（可选，推荐常开）

被官方自动更新覆盖后，让系统自己把汉化补回来，不用每次手动重跑：

```bash
bash install-autopatch.sh install    # 安装：登录时检查一次 + 之后每 30 分钟一次
bash install-autopatch.sh status     # 查看是否在跑、最近日志
bash install-autopatch.sh uninstall  # 卸载
```

它只做三件事：读签名 → 判定是官方版才调用 `run.sh install` → 打完自动重开。细节：

- 已是汉化版时直接跳过，不产生任何动作
- 一轮失败退避 1 小时，避免网络问题导致每 30 分钟反复重试
- 先做「版本 3 秒内不变」的稳定性复查，不会在 Squirrel 替换 bundle 的中途插手
- 触发时发一条系统通知，之后约 8-10 分钟自动完成并重开
- 日志：`~/Library/Application Support/claude-zh-autopatch/autopatch.log`

> 为什么不用 Claude 插件 hook 做这件事：补丁会退出 Claude Desktop，会把触发它的会话一起杀掉。
> LaunchAgent 独立于 app 与终端，才是正确的位置。

## 前提

- **本机 macOS**，且运行会话的 Bash **未沙箱**
  （云端/网页版会话、sandbox 模式、Linux/WSL/远程 SSH 均不可用）
- `/Applications` 归 admin 组可写（无需 sudo）
- `git` + `python3`
- 访问 GitHub（脚本会自动读取系统代理设置）

`run.sh` 启动时会自动预检以上环境；不满足会报错退出，并给出在 Mac「终端」里手动执行的指引。
若你是在云端会话或开启沙箱的会话里触发本 skill，请改在 Terminal.app 中手动运行。

## 注意

补丁重签了 app，官方自动更新会把它覆盖掉——界面回到英文属预期，重跑 `install` 即可。
界面回英文也可能是别的原因，先 `status` 判断，别急着重装。
详情见 [SKILL.md](SKILL.md)。

已按 Claude Desktop 4.23118.0 / 补丁 1.4.23 实测通过。

## License

MIT
