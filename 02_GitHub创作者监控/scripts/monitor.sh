#!/bin/bash
# ============================================
# T1 50 人每日 GitHub 监控
# 用法: bash monitor-daily.sh [--notify]
# 输出: 02_GitHub创作者监控/reports/YYYY-MM-DD.md
# ============================================
source "$(dirname "$0")/../config.sh" 2>/dev/null || true
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
OUTDIR="$PROJ/02_GitHub创作者监控/reports"
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

# 保存原始数据供后续处理
RAW_DATA="$TMP/raw_updates.txt"
printf '%s\n' "${NEW_REPOS[@]}" | sort -t'|' -k3 -nr > "$RAW_DATA"

# ============ 用 Python 生成结构化报告 ============
python3 << PYEOF
import os, json
from datetime import datetime, timezone, timedelta

today = "$TODAY"
total_updates = $TOTAL_UPDATES
raw_file = "$RAW_DATA"
outfile = "$OUTFILE"
trending_count = ${#TRENDING[@]}
t1_count = ${#T1_NAMES[@]}

# 知识维度映射
dimension_map = {
    "agent": "03_工具-Agent框架",
    "mcp": "03_工具-Agent框架",
    "skill": "03_工具-Agent框架",
    "harness": "03_工具-Agent框架",
    "claude": "07_开发编程-AI Coding",
    "codex": "07_开发编程-AI Coding",
    "gemini": "06_模型-大模型",
    "llm": "06_模型-大模型",
    "gpt": "06_模型-大模型",
    "openai": "06_模型-大模型",
    "rag": "07_开发编程-AI Coding",
    "embedding": "09_数据-数据科学",
    "vector": "09_数据-数据科学",
    "memory": "04_经验-最佳实践",
    "practice": "04_经验-最佳实践",
    "best": "04_经验-最佳实践",
    "vibe": "07_开发编程-AI Coding",
    "coding": "07_开发编程-AI Coding",
    "token": "05_原理理论-机器学习",
    "inference": "05_原理理论-机器学习",
    "docker": "08_部署运维",
    "deploy": "08_部署运维",
    "chrome": "03_工具-Agent框架",
    "browser": "03_工具-Agent框架",
    "sandbox": "03_工具-Agent框架",
    "vscode": "07_开发编程-AI Coding",
    "desktop": "03_工具-Agent框架",
    "plugin": "03_工具-Agent框架",
    "safety": "10_安全对齐",
    "security": "10_安全对齐",
    "align": "10_安全对齐",
}

def map_to_dimension(desc, name):
    text = (desc + " " + name).lower()
    for kw, dim in dimension_map.items():
        if kw in text:
            return dim
    return "01_资讯-行业动态"

# 读取原始数据
raw_updates = []
try:
    with open(raw_file) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            parts = line.split('|')
            if len(parts) >= 5:
                raw_updates.append({
                    'author': parts[0],
                    'repo': parts[1],
                    'stars': int(parts[2]) if parts[2].isdigit() else 0,
                    'desc': parts[3],
                    'url': parts[4],
                })
except:
    pass

# 分析
high_impact = [u for u in raw_updates if u['stars'] >= 1000]
new_repos = [u for u in raw_updates if u['stars'] < 100]
active_authors = len(set(u['author'] for u in raw_updates))
dim_counts = {}

# 为重点仓库获取今日 commit 信息
import subprocess
def fetch_commits(author, repo):
    """获取仓库最近 24h 的 commit 信息"""
    try:
        since = (datetime.now(timezone.utc) - timedelta(hours=24)).strftime('%Y-%m-%dT%H:%M:%SZ')
        result = subprocess.run(
            ["gh", "api", f"repos/{author}/{repo}/commits?since={since}&per_page=5",
             "--jq", ".[].commit.message"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0 and result.stdout.strip():
            msgs = []
            for line in result.stdout.strip().split('\n')[:3]:
                title = line.split('\n')[0].strip()[:100]
                msgs.append(title)
            return msgs
    except:
        pass
    return []

# 对重点仓库（高星或新仓库）获取 commit
for u in raw_updates:
    if u['stars'] >= 500 or u['stars'] < 100:
        u['commits'] = fetch_commits(u['author'], u['repo'])
    else:
        u['commits'] = []
for u in raw_updates:
    dim = map_to_dimension(u['desc'], u['repo'])
    dim_counts[dim] = dim_counts.get(dim, 0) + 1

# 生成报告
lines = []
lines.append("# 📡 AI 创作者每日监控 — $TODAY")
lines.append("")
lines.append("## 🎯 这个系统是干什么的")
lines.append("")
lines.append("**解决的问题**：全球 AI 发展太快，信息过载，你不知道每天该关注什么。")
lines.append("")
lines.append("**本系统做了什么**：")
lines.append(f"- 从 192,215 个 GitHub 用户中用 5 轮雪球采样 + AI 相关性筛选出 **2061 位 AI 创作者**")
lines.append(f"- 按 AI 深度/活跃度/影响力/领域覆盖 四维排序精选 **250 人**")
lines.append(f"- 每天自动扫描其中 **{t1_count} 位 T1 核心创作者** 的 GitHub 仓库动态")
lines.append("- 按知识维度归类，告诉你哪条动态对你的哪个学习方向有用")
lines.append("")
lines.append("**你怎么用**：花 3 分钟扫一眼「今日重点」，看到感兴趣的仓库点进去深读。")
lines.append("")

# 统计摘要
lines.append("---")
lines.append("")
lines.append("## 📊 今日概况")
lines.append("")
lines.append(f"| 指标 | 数值 |")
lines.append(f"|------|------|")
lines.append(f"| 监控 T1 创作者 | {t1_count} 人 |")
lines.append(f"| 今日有更新的人数 | {active_authors} / {t1_count} |")
lines.append(f"| 活跃率 | {active_authors * 100 // t1_count}% |")
lines.append(f"| 更新仓库总数 | {total_updates} 个 |")
lines.append(f"| 今日重点关注 | {len(high_impact)} 个 |")
lines.append(f"| 覆盖知识维度 | {len(dim_counts)} 个 |")
lines.append("")
lines.append("> 💡 **活跃率解读**：GitHub 上的大项目通常有专门团队维护，每天 push 很正常。重点看「今日重点关注」里的高星仓库或新仓库。")
lines.append("")

# 今日重点关注
if high_impact:
    lines.append("---")
    lines.append("")
    lines.append("## 🔥 今日重点关注（⭐≥1000 的大型项目）")
    lines.append("")
    lines.append("> 这些是行业标杆项目的动态，代表技术方向。**优先阅读**。")
    lines.append("")
    lines.append("| 作者 | 仓库 | ⭐ | 今日提交了什么 | 关联维度 |")
    lines.append("|------|------|-----|---------------|----------|")
    for u in high_impact[:15]:
        dim = map_to_dimension(u['desc'], u['repo'])
        dim_short = dim.split('-')[1] if '-' in dim else dim[:6]
        author_link = f"[{u['author']}](https://github.com/{u['author']})"
        repo_link = f"[{u['repo']}]({u['url']})"
        commits = u.get('commits', [])
        if commits:
            commit_str = '<br>'.join(f'• {c[:90]}' for c in commits[:3])
        else:
            commit_str = u['desc'][:80] if u['desc'] else '_(例行更新)_'
        lines.append(f"| {author_link} | {repo_link} | {u['stars']} | {commit_str} | {dim_short} |")
    lines.append("")

# 全部动态（按维度分组）
if total_updates > 0:
    lines.append("---")
    lines.append("")
    lines.append("## 📋 全部今日动态（按知识维度归类）")
    lines.append("")
    lines.append("> 按你的 20 维知识体系分组，方便按需深读。")
    lines.append("")

    # 按维度分组
    dim_groups = {}
    for u in raw_updates:
        dim = map_to_dimension(u['desc'], u['repo'])
        if dim not in dim_groups:
            dim_groups[dim] = []
        dim_groups[dim].append(u)

    for dim in sorted(dim_groups.keys()):
        updates = dim_groups[dim]
        lines.append(f"### {dim} ({len(updates)} 条)")
        lines.append("")
        lines.append("| 作者 | 仓库 | ⭐ | 今日提交 |")
        lines.append("|------|------|-----|----------|")
        for u in updates[:15]:
            author_link = f"[{u['author']}](https://github.com/{u['author']})"
            repo_link = f"[{u['repo']}]({u['url']})"
            commits = u.get('commits', [])
            if commits:
                detail = ' · '.join(c[:80] for c in commits[:2])
            else:
                detail = u['desc'][:70] if u['desc'] else '-'
            lines.append(f"| {author_link} | {repo_link} | {u['stars']} | {detail} |")
        lines.append("")
else:
    lines.append("---")
    lines.append("")
    lines.append("## 😴 今日无更新")
    lines.append("")
    lines.append("T1 核心圈今日均无仓库 push（周末或节假日常见），不影响系统运行。")
    lines.append("")

# 维度覆盖概览
lines.append("---")
lines.append("")
lines.append("## 📊 你的 20 维知识体系 — 今日覆盖情况")
lines.append("")
lines.append("| 维度 | 今日动态 | 覆盖状态 |")
lines.append("|------|----------|----------|")
all_dims = [
    ("01_资讯-行业动态", "新闻/产品/融资"),
    ("02_技巧-Prompt工程", "技巧/教程"),
    ("03_工具-Agent框架", "工具/框架/MCP/Skill"),
    ("04_经验-最佳实践", "踩坑/案例"),
    ("05_原理理论-机器学习", "理论/算法"),
    ("06_模型-大模型", "GPT/Claude/Gemini"),
    ("07_开发编程-AI Coding", "Vibecoding/IDE"),
    ("08_部署运维", "Docker/MLOps"),
    ("09_数据-数据科学", "向量/嵌入"),
    ("10_安全对齐", "AI安全/伦理"),
]
for dim, desc in all_dims:
    count = dim_counts.get(dim, 0)
    if count > 0:
        bar = "█" * min(count, 20)
        status = f"🟢 {count} 条 {bar}"
    else:
        status = "⚪ 今日暂无（需跨平台补）"
    lines.append(f"| {dim} | {desc} | {status} |")

lines.append("")
lines.append("---")
lines.append("")
lines.append("## 💡 推荐行动")
lines.append("")
if high_impact:
    lines.append(f"1. 优先看「今日重点关注」——{len(high_impact)} 个高星项目的动态代表行业方向")
lines.append("2. 扫一眼「按维度归类」，找你当前学习方向相关的仓库深读")
lines.append("3. 标记感兴趣的仓库，后续持续跟踪")
lines.append("4. 如果某维度持续空白，考虑从补充名单中手动搜索该领域内容")
lines.append("")
lines.append("> 🤖 本系统由 GitHub Actions 云端每天自动生成 + macOS launchd 本地备份。")
lines.append(f"> 📅 生成时间: $(date '+%Y-%m-%d %H:%M')")
lines.append("")

with open(outfile, 'w') as f:
    f.write('\n'.join(lines))

print(f"Report written to {outfile}")
PYEOF

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
echo "  下次运行: 明天或手动 bash 02_GitHub创作者监控/scripts/monitor.sh"
