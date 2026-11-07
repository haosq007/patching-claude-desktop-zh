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

## 前提

- macOS，`/Applications` 归 admin 组可写（无需 sudo）
- `git` + `python3`
- 访问 GitHub（脚本会自动读取系统代理设置）

## 注意

补丁重签了 app，官方自动更新会把它覆盖掉——界面回到英文属预期，重跑 `install` 即可。
界面回英文也可能是别的原因，先 `status` 判断，别急着重装。
详情见 [SKILL.md](SKILL.md)。

已按 Claude Desktop 4.23118.0 / 补丁 1.4.23 实测通过。

## License

MIT
