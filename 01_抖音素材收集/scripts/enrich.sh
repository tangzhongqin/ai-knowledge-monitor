#!/bin/bash
# ============================================
# 抖音素材自动加工脚本
# 用法: bash enrich.sh [日期] [--dry-run]
# 流程: 清洗 → 维度归类 → 模板排版 → 归档
# ============================================
source "$(dirname "$0")/../config.sh" 2>/dev/null || true
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
RULES="$PROJ/01_抖音素材收集/加工规则.md"
DATE="${1:-$(date +%Y-%m-%d)}"
DRY_RUN=false
[ "$2" = "--dry-run" ] && DRY_RUN=true

INPUT_DIR="$PROJ/01_抖音素材收集/output/$DATE"
DIM_DIR="$PROJ/知识库"

if [ ! -d "$INPUT_DIR" ]; then
  echo "❌ 没有找到 $DATE 的素材目录: $INPUT_DIR"
  exit 1
fi

echo "📐 抖音素材自动加工"
echo "   日期: $DATE"
echo "   规则: $RULES"
echo "   输入: $INPUT_DIR"
echo ""

# ============ 维度关键词映射（grep 实现，快速） ============
declare_dim() {
  local text="$1"
  # 按优先级从高到低匹配（更具体的先匹配，避免"教程"被"教育"误匹配）
  # 使用 grep -q 快速判断
  if echo "$text" | grep -qiE 'GPU|NPU|TPU|芯片|算力|显存'; then echo "16_硬件芯片"; return; fi
  if echo "$text" | grep -qiE 'AGI|奇点|意识'; then echo "20_哲学未来"; return; fi
  if echo "$text" | grep -qiE 'Stable Diffusion|Midjourney|AI绘画|AI音乐|AI视频|创意'; then echo "19_创意内容"; return; fi
  if echo "$text" | grep -qiE 'Agent|Skill|MCP|harness|Codex|Copilot|n8n|插件'; then echo "03_工具"; return; fi
  if echo "$text" | grep -qiE '越狱|红队|幻觉|AI安全|安全对齐|对齐'; then echo "10_安全对齐"; return; fi
  if echo "$text" | grep -qiE '版权|隐私|法规|监管|伦理|EU AI'; then echo "11_伦理监管"; return; fi
  if echo "$text" | grep -qiE '变现|出海|副业|融资|商业模式|创业|赚钱'; then echo "12_商业创业"; return; fi
  if echo "$text" | grep -qiE '论文|Arxiv|学术|突破|研究'; then echo "14_研究论文"; return; fi
  if echo "$text" | grep -qiE '医疗AI|金融AI|法律AI|制造AI|行业应用'; then echo "15_行业应用"; return; fi
  if echo "$text" | grep -qiE 'UX|产品设计|交互设计|设计'; then echo "18_设计产品"; return; fi
  if echo "$text" | grep -qiE '开源|GitHub|HuggingFace'; then echo "17_开源社区"; return; fi
  if echo "$text" | grep -qiE 'AI Coding|Vibecoding|Function Calling|RAG'; then echo "07_开发编程"; return; fi
  if echo "$text" | grep -qiE '算法|RLHF|Transformer|注意力|训练|原理|推理优化'; then echo "05_原理理论"; return; fi
  if echo "$text" | grep -qiE 'GPT|Claude|Gemini|GLM|LLM|大模型|评测|对比|模型'; then echo "06_模型"; return; fi
  if echo "$text" | grep -qiE '部署|Docker|本地部署|MacBook|量化|GPU集群'; then echo "08_部署运维"; return; fi
  if echo "$text" | grep -qiE '数据集|向量数据库|嵌入|数据清洗'; then echo "09_数据"; return; fi
  if echo "$text" | grep -qiE '踩坑|复盘|案例|方法论|不要|避免|最佳实践'; then echo "04_经验"; return; fi
  if echo "$text" | grep -qiE '课程|学习路径|认证|教育|教学'; then echo "13_教育学习"; return; fi
  if echo "$text" | grep -qiE '教程|用法|技巧|入门|怎么|如何|Prompt|实操|学习'; then echo "02_技巧"; return; fi
  if echo "$text" | grep -qiE '发布|上线|融资|收购|裁员|政策|产品更新|开源了|资讯'; then echo "01_资讯"; return; fi
  echo "01_资讯"
}

# ============ 主处理循环 ============
PROCESSED=0
SKIPPED=0
TOTAL=$(find "$INPUT_DIR" -maxdepth 2 -name "*.md" 2>/dev/null | wc -l | xargs)

for DIR in "$INPUT_DIR"/*/; do
  [ ! -d "$DIR" ] && continue
  MD=$(ls "$DIR"/*.md 2>/dev/null | head -1)
  [ ! -f "$MD" ] && continue

  BASENAME=$(basename "$MD" .md)

  # 跳过已加工的
  grep -q "✅ \*\*已精加工\*\*" "$MD" 2>/dev/null && { SKIPPED=$((SKIPPED + 1)); continue; }
  # 跳过下载失败的
  grep -q "❌ 下载失败" "$MD" 2>/dev/null && { SKIPPED=$((SKIPPED + 1)); continue; }

  PROCESSED=$((PROCESSED + 1))
  echo "[$PROCESSED/$TOTAL] 🔧 $BASENAME" | head -c 120
  echo ""

  # --- 提取元数据 ---
  TITLE=$(head -1 "$MD" | sed 's/^# //; s/ #[^ ]*//g' | cut -c1-60)
  SOURCE_URL=$(grep "来源" "$MD" | head -1 | grep -o 'https://[^ )]*' | head -1)
  CONTENT_TYPE="视频"
  grep -q "图文帖" "$MD" 2>/dev/null && CONTENT_TYPE="图文"

  # --- 提取文本内容 ---
  VOICE_TEXT=$(sed -n '/## 🎙️ 语音识别/,/## 📺/p' "$MD" 2>/dev/null | grep -v "^#" | grep -v "^>" | grep -v "^$" | grep -v "✅\|⚠️\|⏳" | head -50)
  OCR_TEXT=$(sed -n '/## 📺 画面OCR/,/^---/p' "$MD" 2>/dev/null | grep -v "^#" | grep -v "^>" | grep -v "^$" | grep -v "✅\|⚠️\|⏳" | head -30)

  # 合并清洗
  FULL_TEXT="$VOICE_TEXT
$OCR_TEXT"

  # --- 判断维度 ---
  DIM_KEY=$(declare_dim "$TITLE $FULL_TEXT")
  DIM_NUM="${DIM_KEY:0:2}"

  # 找到对应维度目录
  DIM_FULL_DIR=$(ls -d "$DIM_DIR"/"${DIM_NUM}"_*/ 2>/dev/null | head -1)
  if [ -z "$DIM_FULL_DIR" ]; then
    echo "  ⚠️ 未找到维度 ${DIM_NUM} 对应的目录，创建默认目录"
    DIM_FULL_DIR="$DIM_DIR/${DIM_KEY}"
    mkdir -p "$DIM_FULL_DIR"
  fi
  DIM_NAME=$(basename "$DIM_FULL_DIR")

  # --- 确定序号 ---
  NEXT_NUM=$(ls "$DIM_FULL_DIR"/*.md 2>/dev/null | wc -l | xargs)
  NEXT_NUM=$((NEXT_NUM + 1))
  SEQ=$(printf "%03d" $NEXT_NUM)

  # --- 生成输出文件名 ---
  SAFE_TITLE=$(echo "$TITLE" | sed 's/[\/:*?"<>|]//g' | cut -c1-40)
  OUT_FILE="$DIM_FULL_DIR/${SEQ}_${DATE}_${SAFE_TITLE}.md"

  # --- 用 AI 生成结构化内容 ---
  # 这一步调用 Python 做文本清洗和内容提取
  if [ "$DRY_RUN" = false ]; then
    python3 << PYEOF
import re, sys

title = """$TITLE"""
voice = """$VOICE_TEXT"""
ocr = """$OCR_TEXT"""
source_url = """$SOURCE_URL"""
content_type = """$CONTENT_TYPE"""
dim_name = """$DIM_NAME"""
out_file = """$OUT_FILE"""
date = """$DATE"""
seq = """$SEQ"""

# 基础清洗
def clean(text):
    # 去语气词
    text = re.sub(r'[嗯啊呃哦哎唉嘿哈]+', '', text)
    # 去重复行
    lines = []
    seen = set()
    for line in text.split('\n'):
        line = line.strip()
        if line and len(line) > 2 and line not in seen:
            lines.append(line)
            seen.add(line)
    return '\n'.join(lines)

voice_clean = clean(voice)
ocr_clean = clean(ocr)
combined = voice_clean + '\n' + ocr_clean

# 提取关键词
ai_kw = ['Agent', 'Skill', 'MCP', 'Claude', 'Codex', 'GPT', 'LLM', 'RAG',
         'Prompt', 'API', '开源', '部署', '模型', '工具', '教程',
         'Copilot', 'n8n', 'harness', 'Vibecoding', '框架']
found_kw = [kw for kw in ai_kw if kw.lower() in combined.lower()]

# 提取核心要点（简单规则：找"第一/第二/首先/其次/还有/另外"引导的句子）
key_points = []
for line in combined.split('\n'):
    line = line.strip()
    if not line or len(line) < 10: continue
    if any(marker in line for marker in ['第一', '第二', '第三', '首先', '其次', '然后', '最后',
                                          '还有', '另外', '重要', '关键', '核心', '注意', '总结']):
        key_points.append(f"- {line[:100]}")
    elif len(key_points) < 5 and len(line) > 20:
        key_points.append(f"- {line[:100]}")

if len(key_points) > 8:
    key_points = key_points[:8]
elif len(key_points) < 3:
    # 没有明确标记时，取前几个长句
    long_lines = [l for l in combined.split('\n') if len(l.strip()) > 15]
    key_points = [f"- {l.strip()[:100]}" for l in long_lines[:5]]

key_points_str = '\n'.join(key_points) if key_points else '_(待人工提取)_'

# 工具提取
tools = []
tool_patterns = [
    (r'(Claude\s*Code|claude\s*code)', 'Claude Code', 'AI 编程助手'),
    (r'(Codex|codex)', 'Codex CLI', 'OpenAI 编程 Agent'),
    (r'(Gemini|gemini)', 'Gemini CLI', 'Google AI 终端'),
    (r'(n8n)', 'n8n', '自动化工作流'),
    (r'(CopilotKit)', 'CopilotKit', 'Agent UI 框架'),
    (r'(MCP|mcp)', 'MCP', '模型上下文协议'),
    (r'(whisper)', 'Whisper', '语音识别'),
    (r'(Cursor|cursor)', 'Cursor', 'AI IDE'),
    (r'(Docker|docker)', 'Docker', '容器化'),
]

for pattern, tool_name, tool_use in tool_patterns:
    if re.search(pattern, combined, re.IGNORECASE):
        tools.append((tool_name, tool_use))

# 去重工具
seen_tools = set()
unique_tools = []
for t, u in tools:
    if t.lower() not in seen_tools:
        unique_tools.append((t, u))
        seen_tools.add(t.lower())

tools_str = '\n'.join([f'| {t} | {u} | - |' for t, u in unique_tools[:8]]) if unique_tools else '| _(待补充)_ | _(待补充)_ | _(待补充)_ |'

# Emoji 选择
emoji_map = {
    '02_': '📖', '03_': '🔧', '04_': '💡', '06_': '📦',
    '07_': '💻', '01_': '📰', '08_': '🚀', '13_': '🎓'
}
emoji = '📰'
for prefix, e in emoji_map.items():
    if dim_name.startswith(prefix):
        emoji = e
        break

# 板块判断
section = '工具' if dim_name.startswith('03_') else '技巧' if dim_name.startswith('02_') else '经验' if dim_name.startswith('04_') else '资讯'

# 生成输出
output = f"""# {emoji} {title}

> {section} | ⚠️ 待审核 | 来源: [{source_url or '抖音'}]({source_url or '#'}) | {date}

## 📌 一句话总结
_(AI 辅助生成，需人工审核)_
{key_points[0] if key_points else '_(待补充)_'}

## 🔍 核心内容
{key_points_str}

## 🧠 专家升华
> ⚠️ AI 辅助生成，需人工审核和修正

### 技术深度分析
_(待补充：工具背后的原理、设计思路)_

### 更优方案 / 替代思路
_(待补充：竞品对比、有无更好选择)_

### 行业位置
_(待补充：该工具/方法在 AI 生态中的位置)_

### 实操建议
_(待补充：什么场景用、怎么开始、坑在哪)_

## 🔗 涉及工具
| 工具 | 用途 | 链接 |
|------|------|------|
{tools_str}

## 💪 行动清单
- [ ] 理解核心概念
- [ ] 实操验证文中方法
- [ ] 对比是否有更优方案
- [ ] 归档至 {dim_name}

---
*原始素材: {source_url or '抖音'} | 采集于 {date} | 自动加工 {seq}*
"""

with open(out_file, 'w') as f:
    f.write(output)

print(f"  ✅ → {out_file}")
print(f"     维度: {dim_name} | 序号: {seq} | 关键词: {', '.join(found_kw[:5])}")
PYEOF

    # 标记原文件为已加工
    python3 -c "
md = open('$MD').read()
if '✅ **已精加工**' not in md:
    md = '> ✅ **已精加工** → \`知识库/${DIM_NAME}/${SEQ}_${DATE}_${SAFE_TITLE}.md\` | 三步流程：清洗→校验升华→排版 | $(date +%Y-%m-%d)\n\n' + md
    open('$MD','w').write(md)
" 2>/dev/null

  else
    echo "  🔍 [DRY-RUN] → 维度: $DIM_KEY, 序号: $SEQ"
  fi

done

echo ""
echo "========================================"
echo "  加工完成"
echo "========================================"
echo "  处理: $PROCESSED | 跳过: $SKIPPED | 总计: $TOTAL"
echo ""

if [ "$PROCESSED" -gt 0 ]; then
  echo "  🧠 专家升华部分需手动补充"
  echo "  📂 输出在 知识库/ 对应维度目录下"
fi
