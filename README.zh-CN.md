# best-cc-statusline

[English](./README.md) | 简体中文

一个开箱即用的多行状态栏脚本，为 [Claude Code](https://claude.com/claude-code) 打造 —— 不依赖第三方工具或网络请求，使用 `bash`、`jq`、`git`，并读取 Claude Code 通过标准输入传给状态栏命令的官方 JSON。

```
📁 ~/projects/demo │ ⎇ feature/xxx ⇡1 ~2 │ 🔍 #42 │ Claude Sonnet 5 │ ⚙ high 🧠
▓▓░░░░░░░░ 23% (45.2k/200.0k tok)
↑45.2k │ ↓3.8k │ 🔥 缓存命中 87% │ 💰$0.457 │ ⏱️12m5s
5h 42% (06:12 重置) │ 7d 18% (09/10 05:12 重置)
```

## 展示内容

| 行 | 内容 |
| --- | --- |
| 1 | 📁 当前目录（`~` 缩写）· 在仓库内时显示 `⎇` 分支名（分离 HEAD 时显示 `@` 和短提交哈希）、领先/落后远程的提交数（`⇡`/`⇣`）、脏工作区标记（`+暂存` `~修改` `?未跟踪`）· 打开的 PR/MR 状态徽标（✅ 已批准 / ❌ 需修改 / 🔍 待审核 / 📝 草稿）· 模型名称 · 推理强度徽标（`low`→`max`，按颜色区分）· 开启扩展思考时显示 🧠 |
| 2 | 当前上下文占用情况，以 10 格进度条、百分比和已用/总量 token 数（`45.2k/200.0k`）展示；已用量为输入及缓存创建/读取输入 token 之和，缺少这些数据时回退为百分比 × 上下文窗口大小 |
| 3 | ↑ 输入 token（`total_input_tokens`）/ ↓ 输出 token · 提示缓存命中率（🔥 命中 / ❄️ 未命中）· 本次会话花费 · 会话时长（达到 60 分钟后显示为 `HhMMm`） |
| 4 | Claude.ai 订阅版的 5 小时与 7 天用量限制，附重置时间，按阈值分色（<70% 绿色，70-89% 黄色，≥90% 红色） |

当对应的 JSON 字段缺失时（例如不在 git 仓库中、API Key 计费没有用量限制数据、会话第一轮还没有上下文数据），每个字段都会优雅降级 —— 不会报错，也不会打印乱码。

## 依赖要求

- `bash` 3.2+、`jq`（`brew install jq` / `apt install jq` / `winget install jqlang.jq`）
- `git`（可选，仅用于分支信息；不在仓库内时会静默跳过）
- `date` 用于格式化用量限制重置时间（同时支持 GNU 与 BSD/macOS 的 `date`）
- Windows 上的 `bash` 来自 Git Bash（随 Git for Windows 一起安装）——见 [Windows（Git Bash）](#windowsgit-bash)

## 安装

脚本提供两种语言版本，任选其一，两者安装到同一路径：

| 版本 | 文件 | 标签与注释 |
|---|---|---|
| 简体中文 | `statusline.zh-CN.sh` | 简体中文 |
| English | `statusline.sh` | 英文 |

```bash
# 简体中文版
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/eric1hua/best-cc-statusline/main/statusline.zh-CN.sh
# 或英文版
# curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/eric1hua/best-cc-statusline/main/statusline.sh
chmod +x ~/.claude/statusline.sh
```

然后在 `~/.claude/settings.json` 中添加以下配置（参考 [`settings.example.json`](./settings.example.json)）：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/statusline.sh\"",
    "padding": 1
  }
}
```

重新加载 Claude Code（或开启新会话），状态栏就会出现在底部。

### Windows（Git Bash）

脚本在 Windows 上通过 Git Bash 可以正常运行，但有两步和 macOS/Linux 不同。

**1. 安装 `jq`** —— Git for Windows 并不自带：

```powershell
winget install --id jqlang.jq
```

装完重启 Claude Code，让它读到更新后的 `PATH`。

**2. `statusLine` 要写 Git Bash 的绝对路径** —— 不要直接写 `bash`：

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"C:\\Program Files\\Git\\bin\\bash.exe\" \"C:/Users/<你的用户名>/.claude/statusline.sh\"",
    "padding": 1
  }
}
```

> 在 Windows 默认 `PATH` 下，直接写 `bash` 会解析到 `C:\Windows\System32\bash.exe`——那是 **WSL 的启动器**，不是 Git Bash。WSL 读不到 `C:\Users\...` 这类盘符路径，环境也完全独立，结果就是状态栏毫无反应且不报错。所以务必写全 Git Bash 的路径。

下载脚本：

```powershell
curl.exe -o "$env:USERPROFILE\.claude\statusline.sh" https://raw.githubusercontent.com/eric1hua/best-cc-statusline/main/statusline.sh
```

另外，图标（`⎇ ▓ ⇡ 🔥`）需要现代终端才能正常显示，建议用 Windows Terminal，传统的控制台窗口渲染效果不佳。

### 用 AI Agent 安装

想让 Agent 帮你搞定？把下面这段提示词粘贴给 Claude Code（或任何有 shell 权限的编程 Agent）：

```
帮我安装 Claude Code 的 best-cc-statusline 状态栏脚本：
1. 检查是否已安装 `jq`（`jq --version`）；如果没有，请安装（macOS 用 `brew install jq`，Debian/Ubuntu 用 `apt install jq`，Windows 用 `winget install jqlang.jq`）。
2. 下载 https://raw.githubusercontent.com/eric1hua/best-cc-statusline/main/statusline.zh-CN.sh（简体中文版；英文版用 statusline.sh）到 ~/.claude/statusline.sh，并 `chmod +x` 赋予执行权限。
3. 将以下 "statusLine" 配置合并进 ~/.claude/settings.json（文件不存在则创建，已有配置请保留）：
   {"type": "command", "command": "bash \"$HOME/.claude/statusline.sh\"", "padding": 1}
4. 完成后提醒我重新加载 Claude Code 或开启新会话以生效。
```

## 数据来源

所有数据都来自 Claude Code 通过标准输入传给状态栏命令的 JSON —— 完整字段说明见[官方状态栏文档](https://code.claude.com/docs/en/statusline)。需要注意：

- `rate_limits.five_hour` / `rate_limits.seven_day` —— 仅 Claude.ai Pro/Max 订阅用户可见，且需要会话已收到第一次 API 响应
- `prompt_cache.hit_ratio` / `prompt_cache.warm` —— 需要 Claude Code v2.1.251 及以上版本
- `effort.level` —— 仅当前使用的模型支持推理强度参数时才会出现
- `pr.number` / `pr.review_state` —— 与底部 footer 的 PR 徽标一致，GitHub PR 和 GitLab MR 都支持，合并或关闭后自动消失

脚本只用一次 `jq` 调用读取标准输入 JSON。它会执行一次本地 `git status --porcelain=v2 --branch --untracked-files=normal`，读取分支和工作区状态；未跟踪目录按一个条目计数，领先/落后数量也从该状态结果计算。不在仓库内时会省略 git 信息。

## 自定义

脚本刻意保持扁平、易读 —— 每个编号小节负责拼出一行。删掉某个小节（连同最后 `printf` 里对应的那一行）即可去掉一行。脚本在顶部一次性解析 JSON 并提取命名值；修改显示字段时，请调整对应的提取逻辑及其所在行。第 2 行通过 `current_usage` 计算当前上下文用量，缺少数据时回退为百分比 × 上下文窗口大小；第 3 行显示 JSON 中的 `total_input_tokens` 值。

## 贡献者

- [eric1hua](https://github.com/eric1hua) —— 创建者 & 维护者

## 许可证

MIT
