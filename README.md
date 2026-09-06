# best-cc-statusline

A batteries-included, multi-line status line script for [Claude Code](https://claude.com/claude-code) — no third-party tools, no network calls, just `bash` + `jq` and the official stdin JSON that Claude Code already sends your status line command.

```
📁 ~/projects/demo │ feature/xxx │ Claude Sonnet 5 │ ⚙ high 🧠
▓▓░░░░░░░░ 23% (45.2k/200.0k tok)
↑45.2k │ ↓3.8k │ 🔥 缓存命中 87% │ 💰$0.457 │ ⏱️12m5s
5h 42% (06:12 重置) │ 7d 18% (09/10 05:12 重置)
```

## What it shows

| Line | Content |
| --- | --- |
| 1 | 📁 current directory (`~`-shortened) · git branch (if inside a repo) · model name · reasoning effort badge (`low`→`max`, color-coded) · 🧠 when extended thinking is on |
| 2 | Context window usage as a 10-block progress bar, percentage, and used/total tokens (`45.2k/200.0k`) |
| 3 | ↑ input tokens / ↓ output tokens · prompt-cache hit ratio (🔥 warm / ❄️ cold) · session cost · session duration |
| 4 | 5-hour and 7-day Claude.ai subscription rate-limit usage, with reset time, color-coded by threshold (<70% green, 70-89% yellow, ≥90% red) |

Every field degrades gracefully when the underlying JSON field is absent (e.g. no git repo, no rate-limit data for API-key billing, first turn of a session with no context data yet) — nothing ever errors or prints garbage.

## Requirements

- `bash`, `jq` (`brew install jq` / `apt install jq`)
- `git` (optional, only used for the branch segment; falls back silently outside a repo)

## Install

```bash
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/eric1hua/best-cc-statusline/main/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Then add to `~/.claude/settings.json` (see [`settings.example.json`](./settings.example.json)):

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/statusline.sh\"",
    "padding": 1
  }
}
```

Reload Claude Code (or start a new session) and the status line appears at the bottom.

## Data source

Everything comes from the JSON Claude Code pipes to the status line command on stdin — see the [official statusline docs](https://code.claude.com/docs/en/statusline) for the full field reference. In particular:

- `rate_limits.five_hour` / `rate_limits.seven_day` — only present for Claude.ai Pro/Max subscribers, and only after the session's first API response
- `prompt_cache.hit_ratio` / `prompt_cache.warm` — requires Claude Code v2.1.251+
- `effort.level` — only present when the active model supports the reasoning-effort parameter

## Customizing

The script is intentionally flat and readable — each numbered section builds one line. Delete a section (and its line from the final `printf`) to drop a row, or copy the pattern (`jq -r '.field // empty'` + graceful fallback) to add a new one.

## License

MIT
