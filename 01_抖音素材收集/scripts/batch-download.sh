#!/bin/bash
# ============================================
# 阶段1：批量下载 + 生成初始 MD
# ============================================
source "$(dirname "$0")/../config.sh"

INPUT="$1"
OUTDIR="$2"
mkdir -p "$OUTDIR"

TOTAL=$(wc -l < "$INPUT" | xargs)
CUR=0

echo "开始下载 $TOTAL 条..."

while IFS='|' read -r idx type title url; do
    CUR=$((CUR + 1))
    SAFE=$(echo "$title" | sed 's/[\/:*?"<>|#]/_/g' | cut -c1-60 | xargs)
    [ -z "$SAFE" ] && SAFE="item_$idx"
    DIR="$OUTDIR/$(printf '%02d' $idx)_$SAFE"
    mkdir -p "$DIR"
    MD="$DIR/$SAFE.md"

    echo "[$CUR/$TOTAL] $SAFE"

    if [ "$type" = "📹" ]; then
        # 下载视频
        $YT_DLP --cookies "$COOKIE_FILE" --no-playlist \
            -o "${DIR}/%(title)s.%(ext)s" "$url" 2>&1 | grep -E "Destination|100%" | head -1

        VIDEO=$(ls "$DIR"/*.mp4 "$DIR"/*.mov "$DIR"/*.webm 2>/dev/null | head -1)

        if [ -n "$VIDEO" ]; then
            echo "  ✅ 已下载"
            # 生成 MD
            cat > "$MD" << EOF
# $title

| 属性 | 值 |
|------|-----|
| 来源 | [$url]($url) |
| 类型 | 视频 |
| 文件 | $(basename "$VIDEO") |
| 收集时间 | $(date +%Y-%m-%d) |

## 🎙️ 语音识别

> ⏳ 待处理

## 📺 画面字幕

> ⏳ 待处理
EOF
        else
            echo "  ❌ 下载失败"
            cat > "$MD" << EOF
# $title

| 属性 | 值 |
|------|-----|
| 来源 | [$url]($url) |
| 类型 | 视频 |
| 状态 | ❌ 下载失败 |
EOF
        fi
    else
        # 图文帖：创建占位 MD
        echo "  🖼️ 图文帖"
        cat > "$MD" << EOF
# $title

| 属性 | 值 |
|------|-----|
| 来源 | [$url]($url) |
| 类型 | 图文帖 |
| 收集时间 | $(date +%Y-%m-%d) |

## 📝 内容

> 🖼️ 图文帖 — 请通过浏览器打开链接查看图片，或运行 extract-page-text.js 提取图片文字
EOF
    fi

done < "$INPUT"

echo "完成! 输出: $OUTDIR"
