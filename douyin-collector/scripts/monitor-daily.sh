#!/bin/bash
# ============================================
# T1 50 人每日 GitHub 监控
# 用法: bash monitor-daily.sh [--notify]
# 输出: AI知识体系/每日监控/YYYY-MM-DD.md
# ============================================
source "$(dirname "$0")/../config.sh" 2>/dev/null || true
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
OUTDIR="$PROJ/AI知识体系/每日监控"
mkdir -p "$OUTDIR"
TODAY=$(date +%Y-%m-%d)
OUTFILE="$OUTDIR/$TODAY.md"
TMP="/tmp/monitor_$$"
mkdir -p "$TMP"

# T1 50 人名单（从精选名单提取）
T1_NAMES=(
  shanraisshan ruvnet hesreallyhim oxylabs rasbt avivsinai SantanderAI
  yanliudesign e2b-dev farion1231 ykdojo LucasDuys addyosmani affaan-m
  MervinPraison mem0ai FlorianBruniaux rtk-ai xiaolai thedotmack
  wshobson pimenov JimLiu code-yeongyu trekhleb google-gemini sickn33
  Piebald-AI openai anthropics ComposioHQ diegopizzocaro seehiong
  assafelovic gaurav0107 kunwar-shah JuliusBrussee yokingma NousResearch
  ChromeDevTools microsoft coleam00 ihower leptonai steipete bytedance
  bl-ue generalaction punkpeye serpro69
)

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📡 每日监控 — $TODAY${NC}"
echo "监控对象: ${#T1_NAMES[@]} 人 (T1 核心圈)"
echo ""

# 结果 tracking（bash 3.2 兼容）
NEW_REPOS=()
TRENDING=()
TOTAL_UPDATES=0

for name in "${T1_NAMES[@]}"; do
  # 获取最近 push 的仓库（per_page=3）
  repos=$(gh api "users/$name/repos?per_page=3&sort=pushed&direction=desc&type=owner" \
    --jq '.[] | {name, pushed_at, updated_at, stargazers_count, description, html_url, language}' 2>/dev/null)

  if [ -z "$repos" ]; then
    continue
  fi

  # 检查今天是否有更新
  today_updates=$(echo "$repos" | python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta

today = datetime.now(timezone.utc).date()
yesterday = today - timedelta(days=1)
week_ago = today - timedelta(days=7)

for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        repo = json.loads(line)
    except: continue

    pushed = repo.get('pushed_at', '')
    if not pushed: continue

    try:
        pushed_date = datetime.fromisoformat(pushed.replace('Z', '+00:00')).date()
    except: continue

    stars = repo.get('stargazers_count', 0)
    name = repo.get('name', '')
    desc = repo.get('description', '') or ''
    url = repo.get('html_url', '')

    if pushed_date >= yesterday:
        print(f'TODAY|{name}|{stars}|{desc[:80]}|{url}|{pushed}')
    elif pushed_date >= week_ago and stars >= 100:
        print(f'TRENDING|{name}|{stars}|{desc[:80]}|{url}|{pushed}')
" 2>/dev/null)

  if [ -n "$today_updates" ]; then
    while IFS='|' read -r type rname stars desc url pushed; do
      [ -z "$type" ] && continue
      if [ "$type" = "TODAY" ]; then
        NEW_REPOS+=("$name|$rname|$stars|$desc|$url")
        TOTAL_UPDATES=$((TOTAL_UPDATES + 1))
      elif [ "$type" = "TRENDING" ]; then
        TRENDING+=("$name|$rname|$stars|$desc|$url ($pushed)")
      fi
    done <<< "$today_updates"
  fi

  # 进度
  if [ $((TOTAL_UPDATES % 10)) -eq 0 ] && [ "$TOTAL_UPDATES" -gt 0 ]; then
    echo -e "  📦 已发现 ${YELLOW}$TOTAL_UPDATES${NC} 个更新..."
  fi
done

# 按 stars 排序
if [ ${#NEW_REPOS[@]} -gt 0 ]; then
  SORTED=$(printf '%s\n' "${NEW_REPOS[@]}" | sort -t'|' -k3 -nr)
else
  SORTED=""
fi

# ============ 生成报告 ============
{
  echo "# 📡 AI 创作者每日监控 — $TODAY"
  echo ""
  echo "> 监控范围: ${#T1_NAMES[@]} 人 (T1 核心圈)"
  echo "> 今日更新: $TOTAL_UPDATES 个仓库"
  echo "> 生成时间: $(date '+%H:%M')"
  echo ""
  echo "---"
  echo ""

  if [ "$TOTAL_UPDATES" -gt 0 ]; then
    echo "## 🔥 今日动态 ($TOTAL_UPDATES)"
    echo ""
    echo "| 作者 | 仓库 | ⭐ | 说明 |"
    echo "|------|------|-----|------|"

    while IFS='|' read -r author repo stars desc url; do
      [ -z "$author" ] && continue
      gh_link="[$repo]($url)"
      author_link="[$author](https://github.com/$author)"
      echo "| $author_link | $gh_link | $stars | $desc |"
    done <<< "$SORTED"
  else
    echo "## 😴 今日无更新"
    echo ""
    echo "T1 核心圈 50 人今日均无仓库 push。"
    echo "这可能是周末或节假日，属正常现象。"
  fi

  if [ ${#TRENDING[@]} -gt 0 ]; then
    echo ""
    echo "---"
    echo ""
    echo "## 📈 近 7 天热门仓库 (⭐≥100)"
    echo ""
    echo "| 作者 | 仓库 | ⭐ | 说明 |"
    echo "|------|------|-----|------|"
    for item in "${TRENDING[@]}"; do
      IFS='|' read -r author repo stars desc extra <<< "$item"
      gh_link="[$repo](https://github.com/$author/$repo)"
      author_link="[$author](https://github.com/$author)"
      echo "| $author_link | $gh_link | $stars | $desc |"
    done
  fi

  echo ""
  echo "---"
  echo ""
  echo "## 📊 监控统计"
  echo ""
  echo "| 维度 | 数值 |"
  echo "|------|------|"
  echo "| T1 监控总数 | ${#T1_NAMES[@]} |"
  echo "| 今日活跃 | $TOTAL_UPDATES |"
  echo "| 活跃率 | $(( TOTAL_UPDATES * 100 / ${#T1_NAMES[@]} ))% |"

  echo ""
  echo "---"
  echo ""
  echo "*自动生成 · 每日监控系统 · $TODAY*"

} > "$OUTFILE"

# ============ 摘要 ============
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  每日监控报告已生成${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  📁 $OUTFILE"
echo "  👥 监控: ${#T1_NAMES[@]} 人"
echo -e "  🔥 今日更新: ${YELLOW}$TOTAL_UPDATES${NC}"

if [ "$TOTAL_UPDATES" -gt 0 ]; then
  echo ""
  echo -e "  ${YELLOW}Top 5:${NC}"
  echo "$SORTED" | head -5 | while IFS='|' read -r author repo stars desc url; do
    echo "    ⭐$stars  $author/$repo — $desc"
  done
fi

# 清理
rm -rf "$TMP"

echo ""
echo "  下次运行: 明天或手动 bash monitor-daily.sh"
