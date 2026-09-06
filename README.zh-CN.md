# best-cc-statusline

[English](./README.md) | 简体中文

一个开箱即用的多行状态栏脚本，为 [Claude Code](https://claude.com/claude-code) 打造 —— 不依赖任何第三方工具，不发起任何网络请求，只用 `bash` + `jq`，读取 Claude Code 本身通过标准输入传给状态栏命令的官方 JSON。

```
📁 ~/projects/demo │ ⎇ feature/xxx ⇡1 ~2 │ 🔍 #42 │ Claude Sonnet 5 │ ⚙ high 🧠
▓▓░░░░░░░░ 23% (45.2k/200.0k tok)
↑45.2k │ ↓3.8k │ 🔥 缓存命中 87% │ 💰$0.457 │ ⏱️12m5s
5h 42% (06:12 重置) │ 7d 18% (09/10 05:12 重置)
```

## 展示内容

| 行 | 内容 |
| --- | --- |
| 1 | 📁 当前目录（`~` 缩写）· 在仓库内时显示 `⎇` 分支名、领先/落后远程的提交数（`⇡`/`⇣`）、脏工作区标记（`+暂存` `~修改` `?未跟踪`）· 打开的 PR/MR 状态徽标（✅ 已批准 / ❌ 需修改 / 🔍 待审核 / 📝 草稿）· 模型名称 · 推理强度徽标（`low`→`max`，按颜色区分）· 开启扩展思考时显示 🧠 |
| 2 | 上下文窗口占用情况，以 10 格进度条、百分比和已用/总量 token 数（`45.2k/200.0k`）展示 |
| 3 | ↑ 输入 token / ↓ 输出 token · 提示缓存命中率（🔥 命中 / ❄️ 未命中）· 本次会话花费 · 会话时长 |
| 4 | Claude.ai 订阅版的 5 小时与 7 天用量限制，附重置时间，按阈值分色（<70% 绿色，70-89% 黄色，≥90% 红色） |

当对应的 JSON 字段缺失时（例如不在 git 仓库中、API Key 计费没有用量限制数据、会话第一轮还没有上下文数据），每个字段都会优雅降级 —— 不会报错，也不会打印乱码。

## 依赖要求

- `bash`、`jq`（`brew install jq` / `apt install jq`）
- `git`（可选，仅用于分支信息；不在仓库内时会静默跳过）

## 安装

```bash
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/eric1hua/best-cc-statusline/main/statusline.sh
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

### 用 AI Agent 安装

想让 Agent 帮你搞定？把下面这段提示词粘贴给 Claude Code（或任何有 shell 权限的编程 Agent）：

```
帮我安装 Claude Code 的 best-cc-statusline 状态栏脚本：
1. 检查是否已安装 `jq`（`jq --version`）；如果没有，请安装（macOS 用 `brew install jq`，Debian/Ubuntu 用 `apt install jq`）。
2. 下载 https://raw.githubusercontent.com/eric1hua/best-cc-statusline/main/statusline.sh 到 ~/.claude/statusline.sh，并 `chmod +x` 赋予执行权限。
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

领先/落后远程提交数和脏工作区标记是脚本里仅有的本地 `git` 调用（`branch`、`rev-list --left-right --count`、`diff --numstat`、`ls-files --others`）——其余信息都直接来自标准输入。

## 自定义

脚本刻意保持扁平、易读 —— 每个编号小节负责拼出一行。删掉某个小节（连同最后 `printf` 里对应的那一行）即可去掉一行显示；照着现有写法（`jq -r '.field // empty'` + 优雅降级）复制一份即可新增一行。

## 许可证

MIT
