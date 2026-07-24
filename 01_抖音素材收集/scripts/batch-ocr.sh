#!/bin/bash
# 阶段3：批量画面OCR
source "$(dirname "$0")/../config.sh"
OUTDIR="${1:-$OUTPUT_DIR/$(date +%Y-%m-%d)}"
COUNT=0
OK=0

for DIR in "$OUTDIR"/*/; do
    [ ! -d "$DIR" ] && continue
    MD=$(ls "$DIR"/*.md 2>/dev/null | head -1)
    [ ! -f "$MD" ] && continue

    # 跳过已处理
    grep -q "✅ OCR\|🖼️ 图文帖\|❌ 下载失败" "$MD" 2>/dev/null && continue

    VIDEO=$(ls "$DIR"/*.mp4 "$DIR"/*.mov "$DIR"/*.webm 2>/dev/null | head -1)
    [ ! -f "$VIDEO" ] && continue

    COUNT=$((COUNT + 1))
    NAME=$(basename "$DIR")
    echo "[$COUNT] 📺 $NAME"

    FRAMES="$DIR/_frames"
    mkdir -p "$FRAMES"
    $FFMPEG -i "$VIDEO" -vf "fps=1/3" -vframes 80 -q:v 3 "$FRAMES/f_%04d.png" -y 2>/dev/null

    OCR_TXT="$DIR/_ocr.txt"
    > "$OCR_TXT"
    PREV=""
    for f in "$FRAMES"/f_*.png; do
        [ ! -f "$f" ] && continue
        TEXT=$($TESSERACT "$f" stdout -l "$TESSERACT_LANG" --psm 6 2>/dev/null | \
            sed '/^[[:space:]]*$/d' | sed 's/[[:space:]]\+/ /g')
        if [ -n "$TEXT" ] && [ "$TEXT" != "$PREV" ]; then
            echo "$TEXT" >> "$OCR_TXT"
            PREV="$TEXT"
        fi
    done

    if [ -f "$OCR_TXT" ] && [ -s "$OCR_TXT" ]; then
        python3 -c "
md=open('$MD').read()
ocr=open('$OCR_TXT').read().strip()
md=md.replace('> ⏳ 待处理', '✅ 完成\n\n'+ocr, 1)
open('$MD','w').write(md)
" 2>/dev/null
        OK=$((OK + 1))
        echo "  ✅ ($(wc -l < "$OCR_TXT" | xargs) 行)"
    else
        python3 -c "
md=open('$MD').read()
md=md.replace('> ⏳ 待处理', '⚠️ 无明显字幕', 1)
open('$MD','w').write(md)
" 2>/dev/null
        echo "  ⚠️ 无字幕"
    fi

    rm -rf "$FRAMES" "$OCR_TXT"
done

echo "OCR完成: $OK/$COUNT"
