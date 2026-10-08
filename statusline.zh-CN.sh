#!/bin/bash
# Claude Code 状态栏 (多行版)
#
# 第1行: 📁路径 │ 🌿git分支+ahead/behind+脏区 │ PR状态 │ 模型 │ effort强度 │ 🧠思考模式
# 第2行: 上下文窗口进度条 + 用量% (已用/总量 token)
# 第3行: 上行(输入)token │ 下行(输出)token │ 缓存命中率 │ 费用 │ 耗时
# 第4行: 5小时用量窗口(%+重置时间) │ 7天用量窗口(%+重置时间)
#
# 会话数据来自 Claude Code 官方 stdin JSON, git 状态来自本地仓库, 无任何网络调用
# 兼容 macOS Bash 3.2, 仅需 bash + jq + git (重置时间使用系统 date)
# 字段参考: https://code.claude.com/docs/en/statusline

# 一次 jq 读取全部字段, 用 NUL 分隔保留空值、换行和反斜杠, 避免 tab 的 IFS 折叠空列
{
  IFS= read -r -d '' dir
  IFS= read -r -d '' model
  IFS= read -r -d '' pr_number
  IFS= read -r -d '' pr_state
  IFS= read -r -d '' effort
  IFS= read -r -d '' thinking
  IFS= read -r -d '' ctx_pct
  IFS= read -r -d '' ctx_used
  IFS= read -r -d '' ctx_size
  IFS= read -r -d '' in_tok
  IFS= read -r -d '' out_tok
  IFS= read -r -d '' hit_pct
  IFS= read -r -d '' cache_warm
  IFS= read -r -d '' cost
  IFS= read -r -d '' duration_ms
  IFS= read -r -d '' five_pct
  IFS= read -r -d '' five_reset
  IFS= read -r -d '' week_pct
  IFS= read -r -d '' week_reset
} < <(jq -j '
  .context_window as $ctx |
  ($ctx.context_window_size // 200000) as $size |
  [
    (.workspace.current_dir // .cwd // ""),
    (.model.display_name // "Claude"),
    (.pr.number // ""),
    (.pr.review_state // ""),
    (.effort.level // ""),
    (.thinking.enabled // false),
    ($ctx.used_percentage // ""),
    (if $ctx.current_usage != null then
       (($ctx.current_usage.input_tokens // 0) +
        ($ctx.current_usage.cache_creation_input_tokens // 0) +
        ($ctx.current_usage.cache_read_input_tokens // 0))
     else (($ctx.used_percentage // 0) * $size / 100) end | floor),
    ($size | floor),
    ($ctx.total_input_tokens // 0 | floor),
    ($ctx.total_output_tokens // 0 | floor),
    (if .prompt_cache.hit_ratio != null then
       (.prompt_cache.hit_ratio * 100 | round)
     else "" end),
    (.prompt_cache.warm // false),
    (.cost.total_cost_usd // 0),
    (.cost.total_duration_ms // 0 | floor),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.rate_limits.seven_day.used_percentage // ""),
    (.rate_limits.seven_day.resets_at // "")
  ] | .[] | tostring + "\u0000"
')

# ---------- 颜色 ----------
# $'...' (ANSI-C quoting) 让变量里存的是真正的 ESC 字节，字符串拼接时才能生效
# (普通单引号只是字面文本，只有直接写在 printf 格式串里才会被解释)
DIM=$'\033[2m'
CYAN=$'\033[36m'
BLUE=$'\033[34m'
MAGENTA=$'\033[35m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

# 数字转 k/m 简写, 保持状态栏紧凑
fmt_num() {
  local n=${1:-0} scale suffix tenths
  if [ "$n" -ge 1000000 ]; then scale=1000000; suffix=m
  elif [ "$n" -ge 1000 ]; then scale=1000; suffix=k
  else printf '%d' "$n"; return
  fi
  tenths=$(((n * 10 + scale / 2) / scale))
  printf '%d.%d%s' "$((tenths / 10))" "$((tenths % 10))" "$suffix"
}

# 用量百分比 -> 阈值配色 (<70 绿, 70-89 黄, >=90 红), 与官方 context bar 配色规则一致
color_for_pct() {
  local p=$1
  if [ "$p" -ge 90 ]; then echo "$RED"
  elif [ "$p" -ge 70 ]; then echo "$YELLOW"
  else echo "$GREEN"
  fi
}

# effort 强度 -> 配色, 强度从低到高: green -> cyan -> yellow -> magenta -> red
color_for_effort() {
  case "$1" in
    low) echo "$GREEN" ;;
    medium) echo "$CYAN" ;;
    high) echo "$YELLOW" ;;
    xhigh) echo "$MAGENTA" ;;
    max) echo "$RED" ;;
    *) echo "$DIM" ;;
  esac
}

# PR/MR review 状态 -> 图标 + 配色
icon_for_review_state() {
  case "$1" in
    approved) echo "✅" ;;
    changes_requested) echo "❌" ;;
    pending) echo "🔍" ;;
    draft) echo "📝" ;;
    *) echo "🔀" ;;
  esac
}
color_for_review_state() {
  case "$1" in
    approved) echo "$GREEN" ;;
    changes_requested) echo "$RED" ;;
    pending) echo "$YELLOW" ;;
    *) echo "$DIM" ;;
  esac
}

# resets_at 可能是 epoch 秒, 也可能是 ISO8601 字符串; 且 GNU date(Git Bash/Linux)
# 与 BSD date(macOS) 语法不同 —— 逐个 fallback, 全失败则静默输出空串
fmt_reset() {
  local v="$1" f="$2"
  case "$v" in
    ''|null) return ;;
    *[!0-9]*) date -d "$v" "$f" 2>/dev/null || date -j -f '%Y-%m-%dT%H:%M:%S' "${v%%[+Z]*}" "$f" 2>/dev/null ;;
    *) date -d "@$v" "$f" 2>/dev/null || date -r "$v" "$f" 2>/dev/null ;;
  esac
}

# ================= 第1行: 路径 │ git分支+状态 │ PR │ 模型 │ effort/思考模式 =================

# Windows: CC 传来的是 C:\Users\... 形式, 而 Git Bash $HOME 是 /c/Users/... , 前缀匹配不上
# cygpath 把两侧统一成 C:/Users/... 形式 (非 Windows 上 cygpath 不存在, 回退原值, 行为不变)
dir_display=$(cygpath -m "$dir" 2>/dev/null || printf "%s" "$dir")
# 替换串里直接写 ~ 会被 bash 做波浪号展开, 结果又变回 $HOME 全路径, 等于没缩写; 故存进变量
tilde="~"
win_home=$(cygpath -m "$HOME" 2>/dev/null)
[ -n "$win_home" ] && dir_display="${dir_display/#$win_home/$tilde}"
dir_display="${dir_display/#$HOME/$tilde}"

branch=""
git_seg=""
if [ -n "$dir" ] && git_status=$(git -C "$dir" status --porcelain=v2 --branch --untracked-files=normal 2>/dev/null); then
  # 一次读取分支、upstream 领先/落后及脏区; 路径部分无需解析 (git 会转义特殊字符)
  oid=""
  ahead=0
  behind=0
  staged=0
  modified=0
  untracked=0
  while IFS= read -r record; do
    case "$record" in
      '# branch.head '*) branch=${record#\# branch.head } ;;
      '# branch.oid '*) oid=${record#\# branch.oid } ;;
      '# branch.ab '*)
        ab=${record#\# branch.ab }
        ahead=${ab%% *}
        ahead=${ahead#+}
        behind=${ab##* }
        behind=${behind#-}
        ;;
      '1 '*|'2 '*)
        xy=${record:2:2}
        [ "${xy:0:1}" != '.' ] && staged=$((staged + 1))
        [ "${xy:1:1}" != '.' ] && modified=$((modified + 1))
        ;;
      'u '*) staged=$((staged + 1)); modified=$((modified + 1)) ;;
      '? '*) untracked=$((untracked + 1)) ;;
    esac
  done <<< "$git_status"
  # detached HEAD 没有分支名, 用短提交号代替
  [ "$branch" = '(detached)' ] && branch="@${oid:0:7}"

  # 领先/落后 upstream 的提交数 (无 upstream 时均为 0)
  ahead_behind_seg=""
  [ "$ahead" -gt 0 ] && ahead_behind_seg="${ahead_behind_seg}${GREEN}⇡${ahead}${RESET}"
  [ "$behind" -gt 0 ] && ahead_behind_seg="${ahead_behind_seg}${RED}⇣${behind}${RESET}"

  # 脏工作区指示器: 暂存/修改/未跟踪 条目数 (normal 模式将未跟踪目录合为一项)
  dirty_seg=""
  [ "$staged" -gt 0 ] && dirty_seg="${dirty_seg}${GREEN}+${staged}${RESET}"
  [ "$modified" -gt 0 ] && dirty_seg="${dirty_seg}${YELLOW}~${modified}${RESET}"
  [ "$untracked" -gt 0 ] && dirty_seg="${dirty_seg}${DIM}?${untracked}${RESET}"

  git_seg="${MAGENTA}⎇ ${branch}${RESET}"
  [ -n "$ahead_behind_seg" ] && git_seg="${git_seg} ${ahead_behind_seg}"
  [ -n "$dirty_seg" ] && git_seg="${git_seg} ${dirty_seg}"
fi

# PR/MR 状态 (来自官方 JSON, 无需额外调用; GitHub PR 或 GitLab MR 均适用)
pr_seg=""
if [ -n "$pr_number" ]; then
  pr_icon=$(icon_for_review_state "$pr_state")
  pr_color=$(color_for_review_state "$pr_state")
  pr_seg="${pr_color}${pr_icon} #${pr_number}${RESET}"
fi

line1="${CYAN}📁 ${dir_display}${RESET}"
[ -n "$git_seg" ] && line1="${line1} ${DIM}│${RESET} ${git_seg}"
[ -n "$pr_seg" ] && line1="${line1} ${DIM}│${RESET} ${pr_seg}"
line1="${line1} ${DIM}│${RESET} ${model}"

if [ -n "$effort" ] && [ "$effort" != "null" ]; then
  ec=$(color_for_effort "$effort")
  line1="${line1} ${DIM}│${RESET} ${ec}⚙ ${effort}${RESET}"
fi
[ "$thinking" = "true" ] && line1="${line1} 🧠"

# ================= 第2行: 上下文窗口进度条 =================

if [ -n "$ctx_pct" ] && [ "$ctx_pct" != "null" ]; then
  pct_int=$(printf '%.0f' "$ctx_pct")
  bar_color=$(color_for_pct "$pct_int")

  bar_width=10
  filled=$((pct_int * bar_width / 100))
  [ "$filled" -lt 0 ] && filled=0
  [ "$filled" -gt "$bar_width" ] && filled=$bar_width
  empty=$((bar_width - filled))
  bar=""
  [ "$filled" -gt 0 ] && printf -v fill "%${filled}s" && bar="${fill// /▓}"
  [ "$empty" -gt 0 ] && printf -v pad "%${empty}s" && bar="${bar}${pad// /░}"

  line2="${bar_color}${bar} ${pct_int}%${RESET} ${DIM}($(fmt_num "$ctx_used")/$(fmt_num "$ctx_size") tok)${RESET}"
else
  line2="${DIM}上下文: 等待首次响应...${RESET}"
fi

# ================= 第3行: 上行/下行 token │ 缓存命中率 │ 费用 │ 耗时 =================

duration_sec=$((duration_ms / 1000))
mins=$((duration_sec / 60))
secs=$((duration_sec % 60))
if [ "$mins" -ge 60 ]; then
  printf -v duration '%dh%02dm' "$((mins / 60))" "$((mins % 60))"
else
  duration="${mins}m${secs}s"
fi

line3="${BLUE}↑$(fmt_num "$in_tok")${RESET} ${DIM}│${RESET} ${BLUE}↓$(fmt_num "$out_tok")${RESET}"

if [ -n "$hit_pct" ]; then
  warm_icon="❄️"
  [ "$cache_warm" = "true" ] && warm_icon="🔥"
  line3="${line3} ${DIM}│${RESET} ${warm_icon} 缓存命中 ${hit_pct}%"
fi

cost_fmt=$(printf '$%.3f' "$cost")
line3="${line3} ${DIM}│${RESET} 💰${cost_fmt} ${DIM}│${RESET} ⏱️${duration}"

# ================= 第4行: 5小时 / 7天 用量窗口 =================

rate_parts=()

if [ -n "$five_pct" ]; then
  p=$(printf '%.0f' "$five_pct")
  c=$(color_for_pct "$p")
  seg="${c}5h ${p}%${RESET}"
  if [ -n "$five_reset" ] && [ "$five_reset" != "null" ]; then
    seg="${seg} ${DIM}($(fmt_reset "$five_reset" "+%H:%M") 重置)${RESET}"
  fi
  rate_parts+=("$seg")
fi

if [ -n "$week_pct" ]; then
  p=$(printf '%.0f' "$week_pct")
  c=$(color_for_pct "$p")
  seg="${c}7d ${p}%${RESET}"
  if [ -n "$week_reset" ] && [ "$week_reset" != "null" ]; then
    seg="${seg} ${DIM}($(fmt_reset "$week_reset" "+%m/%d %H:%M") 重置)${RESET}"
  fi
  rate_parts+=("$seg")
fi

if [ "${#rate_parts[@]}" -gt 0 ]; then
  line4="${rate_parts[0]}"
  [ "${#rate_parts[@]}" -gt 1 ] && line4="${line4} ${DIM}│${RESET} ${rate_parts[1]}"
else
  line4="${DIM}订阅用量: 暂无数据(需 Pro/Max 订阅 + 已发生对话)${RESET}"
fi

# ================= 输出 =================

printf '%s\n' "$line1" "$line2" "$line3" "$line4"
