#!/bin/bash
# Claude Code 状态栏 (多行版)
#
# 第1行: 📁路径 │ 🌿git分支+ahead/behind+脏区 │ PR状态 │ 模型 │ effort强度 │ 🧠思考模式
# 第2行: 上下文窗口进度条 + 用量% (已用/总量 token)
# 第3行: 上行(输入)token │ 下行(输出)token │ 缓存命中率 │ 费用 │ 耗时
# 第4行: 5小时用量窗口(%+重置时间) │ 7天用量窗口(%+重置时间)
#
# 数据全部来自 Claude Code 官方 stdin JSON, 无任何网络调用/第三方依赖(仅 jq)
# 字段参考: https://code.claude.com/docs/en/statusline

input=$(cat)

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
  awk -v n="${1:-0}" 'BEGIN{
    if (n >= 1000000) printf "%.1fm", n/1000000;
    else if (n >= 1000) printf "%.1fk", n/1000;
    else printf "%d", n;
  }'
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

# ================= 第1行: 路径 │ git分支+状态 │ PR │ 模型 │ effort/思考模式 =================

dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir_display="${dir/#$HOME/~}"

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')

branch=""
git_seg=""
if [ -n "$dir" ] && git -C "$dir" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$dir" branch --show-current 2>/dev/null)

  # 领先/落后 upstream 的提交数 (无 upstream 时静默跳过)
  ahead_behind=$(git -C "$dir" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
  ahead_behind_seg=""
  if [ -n "$ahead_behind" ]; then
    behind=$(echo "$ahead_behind" | awk '{print $1}')
    ahead=$(echo "$ahead_behind" | awk '{print $2}')
    [ "$ahead" -gt 0 ] 2>/dev/null && ahead_behind_seg="${ahead_behind_seg}${GREEN}⇡${ahead}${RESET}"
    [ "$behind" -gt 0 ] 2>/dev/null && ahead_behind_seg="${ahead_behind_seg}${RED}⇣${behind}${RESET}"
  fi

  # 脏工作区指示器: 暂存/修改/未跟踪 文件数
  staged=$(git -C "$dir" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
  modified=$(git -C "$dir" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
  untracked=$(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  dirty_seg=""
  [ "$staged" -gt 0 ] && dirty_seg="${dirty_seg}${GREEN}+${staged}${RESET}"
  [ "$modified" -gt 0 ] && dirty_seg="${dirty_seg}${YELLOW}~${modified}${RESET}"
  [ "$untracked" -gt 0 ] && dirty_seg="${dirty_seg}${DIM}?${untracked}${RESET}"

  git_seg="${MAGENTA}⎇ ${branch}${RESET}"
  [ -n "$ahead_behind_seg" ] && git_seg="${git_seg} ${ahead_behind_seg}"
  [ -n "$dirty_seg" ] && git_seg="${git_seg} ${dirty_seg}"
fi

# PR/MR 状态 (来自官方 JSON, 无需额外调用; GitHub PR 或 GitLab MR 均适用)
pr_number=$(echo "$input" | jq -r '.pr.number // empty')
pr_state=$(echo "$input" | jq -r '.pr.review_state // empty')
pr_seg=""
if [ -n "$pr_number" ]; then
  pr_icon=$(icon_for_review_state "$pr_state")
  pr_color=$(color_for_review_state "$pr_state")
  pr_seg="${pr_color}${pr_icon} #${pr_number}${RESET}"
fi

effort=$(echo "$input" | jq -r '.effort.level // empty')
thinking=$(echo "$input" | jq -r '.thinking.enabled // false')

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

ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_used=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

if [ -n "$ctx_pct" ] && [ "$ctx_pct" != "null" ]; then
  pct_int=$(printf '%.0f' "$ctx_pct")
  bar_color=$(color_for_pct "$pct_int")

  bar_width=10
  filled=$((pct_int * bar_width / 100))
  empty=$((bar_width - filled))
  bar=""
  [ "$filled" -gt 0 ] && printf -v fill "%${filled}s" && bar="${fill// /▓}"
  [ "$empty" -gt 0 ] && printf -v pad "%${empty}s" && bar="${bar}${pad// /░}"

  line2="${bar_color}${bar} ${pct_int}%${RESET} ${DIM}($(fmt_num "$ctx_used")/$(fmt_num "$ctx_size") tok)${RESET}"
else
  line2="${DIM}上下文: 等待首次响应...${RESET}"
fi

# ================= 第3行: 上行/下行 token │ 缓存命中率 │ 费用 │ 耗时 =================

in_tok=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
out_tok=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

hit_ratio=$(echo "$input" | jq -r '.prompt_cache.hit_ratio // empty')
cache_warm=$(echo "$input" | jq -r '.prompt_cache.warm // false')

cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
duration_sec=$((duration_ms / 1000))
mins=$((duration_sec / 60))
secs=$((duration_sec % 60))

line3="${BLUE}↑$(fmt_num "$in_tok")${RESET} ${DIM}│${RESET} ${BLUE}↓$(fmt_num "$out_tok")${RESET}"

if [ -n "$hit_ratio" ] && [ "$hit_ratio" != "null" ]; then
  hit_pct=$(awk -v r="$hit_ratio" 'BEGIN{printf "%.0f", r * 100}')
  warm_icon="❄️"
  [ "$cache_warm" = "true" ] && warm_icon="🔥"
  line3="${line3} ${DIM}│${RESET} ${warm_icon} 缓存命中 ${hit_pct}%"
fi

cost_fmt=$(printf '$%.3f' "$cost")
line3="${line3} ${DIM}│${RESET} 💰${cost_fmt} ${DIM}│${RESET} ⏱️${mins}m${secs}s"

# ================= 第4行: 5小时 / 7天 用量窗口 =================

five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

rate_parts=()

if [ -n "$five_pct" ]; then
  p=$(printf '%.0f' "$five_pct")
  c=$(color_for_pct "$p")
  seg="${c}5h ${p}%${RESET}"
  if [ -n "$five_reset" ] && [ "$five_reset" != "null" ]; then
    seg="${seg} ${DIM}($(date -r "$five_reset" "+%H:%M" 2>/dev/null) 重置)${RESET}"
  fi
  rate_parts+=("$seg")
fi

if [ -n "$week_pct" ]; then
  p=$(printf '%.0f' "$week_pct")
  c=$(color_for_pct "$p")
  seg="${c}7d ${p}%${RESET}"
  if [ -n "$week_reset" ] && [ "$week_reset" != "null" ]; then
    seg="${seg} ${DIM}($(date -r "$week_reset" "+%m/%d %H:%M" 2>/dev/null) 重置)${RESET}"
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

printf '%b\n%b\n%b\n%b\n' "$line1" "$line2" "$line3" "$line4"
