# best-cc-statusline

English | [简体中文](./README.zh-CN.md)

A batteries-included, multi-line status line script for [Claude Code](https://claude.com/claude-code) — no third-party tools or network calls; it uses `bash`, `jq`, `git`, and the official stdin JSON that Claude Code already sends your status line command.

```
📁 ~/projects/demo │ ⎇ feature/xxx ⇡1 ~2 │ 🔍 #42 │ Claude Sonnet 5 │ ⚙ high 🧠
▓▓░░░░░░░░ 23% (45.2k/200.0k tok)
↑45.2k │ ↓3.8k │ 🔥 cache hit 87% │ 💰$0.457 │ ⏱️12m5s
5h 42% (resets 06:12) │ 7d 18% (resets 09/10 05:12)
```

## What it shows

| Line | Content |
| --- | --- |
| 1 | 📁 current directory (`~`-shortened) · `⎇` git branch (or `@` plus the short commit hash for detached HEAD), ahead/behind upstream (`⇡`/`⇣`), and a dirty-tree indicator (`+staged` `~modified` `?untracked`) when inside a repo · open PR/MR status badge (✅ approved / ❌ changes requested / 🔍 pending / 📝 draft) · model name · reasoning effort badge (`low`→`max`, color-coded) · 🧠 when extended thinking is on |
| 2 | Current context usage as a 10-block progress bar, percentage, and used/total tokens (`45.2k/200.0k`); used tokens are the sum of input and cache-creation/cache-read input tokens, with percentage × context-window size as a fallback |
| 3 | ↑ input tokens (`total_input_tokens`) / ↓ output tokens · prompt-cache hit ratio (🔥 warm / ❄️ cold) · session cost · session duration (shown as `HhMMm` at 60 minutes or longer) |
| 4 | 5-hour and 7-day Claude.ai subscription rate-limit usage, with reset time, color-coded by threshold (<70% green, 70-89% yellow, ≥90% red) |

Every field degrades gracefully when the underlying JSON field is absent (e.g. no git repo, no rate-limit data for API-key billing, first turn of a session with no context data yet) — nothing ever errors or prints garbage.

## Requirements

- `bash` 3.2+, `jq` (`brew install jq` / `apt install jq` / `winget install jqlang.jq`)
- `git` (optional, only used for the branch segment; falls back silently outside a repo)
- `date` is used to format rate-limit reset times (GNU and BSD/macOS `date` are both supported)
- On Windows, `bash` comes from Git Bash (bundled with Git for Windows) — see [Windows (Git Bash)](#windows-git-bash)

## Install

The script comes in two languages. Pick one; both install to the same path:

| Version | File | Labels & comments |
|---|---|---|
| English | `statusline.sh` | English |
| Simplified Chinese | `statusline.zh-CN.sh` | 简体中文 |

```bash
# English
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/eric1hua/best-cc-statusline/main/statusline.sh
# or Simplified Chinese
# curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/eric1hua/best-cc-statusline/main/statusline.zh-CN.sh
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

### Windows (Git Bash)

The script runs fine on Windows through Git Bash, but two steps differ from macOS/Linux.

**1. Install `jq`** — Git for Windows does not bundle it:

```powershell
winget install --id jqlang.jq
```

Then restart Claude Code so it picks up the updated `PATH`.

**2. Point `statusLine` at Git Bash by absolute path** — do *not* use a bare `bash`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"C:\\Program Files\\Git\\bin\\bash.exe\" \"C:/Users/<you>/.claude/statusline.sh\"",
    "padding": 1
  }
}
```

> On a default Windows `PATH`, a bare `bash` resolves to `C:\Windows\System32\bash.exe` — the **WSL launcher**, not Git Bash. WSL cannot read drive-letter paths such as `C:\Users\...` and has its own environment, so the status line silently fails. Always spell out the Git Bash path.

Download the script with:

```powershell
curl.exe -o "$env:USERPROFILE\.claude\statusline.sh" https://raw.githubusercontent.com/eric1hua/best-cc-statusline/main/statusline.sh
```

For the icons (`⎇ ▓ ⇡ 🔥`) to render correctly, use a modern terminal such as Windows Terminal; the legacy console host does not handle them well.

### Install via AI agent

Prefer to have an agent do it? Paste this prompt into Claude Code (or any coding agent with shell access):

```
Install best-cc-statusline for Claude Code:
1. Check `jq` is installed (`jq --version`); if missing, install it (`brew install jq` on macOS, `apt install jq` on Debian/Ubuntu, `winget install jqlang.jq` on Windows).
2. Download https://raw.githubusercontent.com/eric1hua/best-cc-statusline/main/statusline.sh (English; use statusline.zh-CN.sh instead for Simplified Chinese) to ~/.claude/statusline.sh and `chmod +x` it.
3. Merge a "statusLine" key into ~/.claude/settings.json (create the file if absent, preserve any existing keys):
   {"type": "command", "command": "bash \"$HOME/.claude/statusline.sh\"", "padding": 1}
4. Tell me to reload Claude Code / start a new session to see it take effect.
```

## Data source

Everything comes from the JSON Claude Code pipes to the status line command on stdin — see the [official statusline docs](https://code.claude.com/docs/en/statusline) for the full field reference. In particular:

- `rate_limits.five_hour` / `rate_limits.seven_day` — only present for Claude.ai Pro/Max subscribers, and only after the session's first API response
- `prompt_cache.hit_ratio` / `prompt_cache.warm` — requires Claude Code v2.1.251+
- `effort.level` — only present when the active model supports the reasoning-effort parameter
- `pr.number` / `pr.review_state` — mirrors the footer's PR badge; present for both GitHub PRs and GitLab merge requests, absent once merged or closed

The script reads the stdin JSON in one `jq` invocation. It makes one local `git status --porcelain=v2 --branch --untracked-files=normal` call for branch and working-tree state; untracked directories are counted as one entry. Ahead/behind counts are derived from that status output. Outside a repository, git details are omitted.

## Customizing

The script is intentionally flat and readable — each numbered section builds one line. Delete a section (and its line from the final `printf`) to drop a row. The JSON is parsed once near the top into named values; to change a displayed field, update the corresponding extraction there and its use in the relevant line. Line 2 computes current context usage from `current_usage` with a percentage-and-size fallback; line 3 displays the JSON `total_input_tokens` value.

## Contributors

- [eric1hua](https://github.com/eric1hua) — creator & maintainer

## License

MIT
