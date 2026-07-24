#!/bin/bash
# 阶段2：批量语音转文字
source "$(dirname "$0")/../config.sh"
OUTDIR="${1:-$OUTPUT_DIR/$(date +%Y-%m-%d)}"
COUNT=0
OK=0

for DIR in "$OUTDIR"/*/; do
    [ ! -d "$DIR" ] && continue
    MD=$(ls "$DIR"/*.md 2>/dev/null | head -1)
    [ ! -f "$MD" ] && continue

    # 跳过已处理和图文帖
    grep -q "✅ 语音完成\|🖼️ 图文帖\|❌ 下载失败" "$MD" 2>/dev/null && continue

    VIDEO=$(ls "$DIR"/*.mp4 "$DIR"/*.mov "$DIR"/*.webm 2>/dev/null | head -1)
    [ ! -f "$VIDEO" ] && continue

    COUNT=$((COUNT + 1))
    NAME=$(basename "$DIR")
    echo "[$COUNT] 🎙️ $NAME"

    AUDIO="$DIR/_audio.wav"
    $FFMPEG -i "$VIDEO" -vn -acodec pcm_s16le -ar 16000 -ac 1 -y "$AUDIO" 2>/dev/null

    if [ -f "$AUDIO" ] && [ -s "$AUDIO" ]; then
        VOICE_OUT="$DIR/_voice"
        $WHISPER -m "$WHISPER_MODEL" -l "$WHISPER_LANG" -f "$AUDIO" -otxt -of "$VOICE_OUT" 2>/dev/null

        if [ -f "${VOICE_OUT}.txt" ] && [ -s "${VOICE_OUT}.txt" ]; then
            TEXT=$(cat "${VOICE_OUT}.txt")
            python3 -c "
md=open('$MD').read()
text=open('${VOICE_OUT}.txt').read().strip()
md=md.replace('> ⏳ 待处理', '✅ 完成\n\n'+text, 1)
open('$MD','w').write(md)
" 2>/dev/null
            OK=$((OK + 1))
            echo "  ✅ ($(wc -l < "${VOICE_OUT}.txt" | xargs) 行)"
            rm -f "${VOICE_OUT}.txt"
        else
            python3 -c "
md=open('$MD').read()
md=md.replace('> ⏳ 待处理', '⚠️ 无明显语音')
open('$MD','w').write(md)
" 2>/dev/null
            echo "  ⚠️ 无语音"
        fi
        rm -f "$AUDIO"
    fi
done

echo "语音识别完成: $OK/$COUNT"
