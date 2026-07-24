#!/bin/bash
# ============================================
# 批量处理：下载 + 语音 + OCR → MD
# 用法: batch-process.sh <筛选后的URL列表> <输出目录>
# ============================================
source "$(dirname "$0")/../config.sh"

INPUT_FILE="$1"
OUTPUT_ROOT="$2"

if [ ! -f "$INPUT_FILE" ]; then
    echo "用法: $0 <url列表文件> <输出根目录>"
    exit 1
fi

TODAY=$(date '+%Y-%m-%d')
OUTPUT_ROOT="${OUTPUT_ROOT:-$OUTPUT_DIR/$TODAY}"
mkdir -p "$OUTPUT_ROOT"

TOTAL=$(grep -c '|' "$INPUT_FILE")
CURRENT=0
VOICE_OK=0
OCR_OK=0

log_info "============================================"
log_info "批量处理开始: $TOTAL 条内容"
log_info "输出目录: $OUTPUT_ROOT"
log_info "============================================"

# 创建索引文件
INDEX_FILE="$OUTPUT_ROOT/README.md"
cat > "$INDEX_FILE" << 'EOF'
# 📋 抖音 AI 技巧收集

> 收集时间: $(date '+%Y-%m-%d %H:%M')
> 状态说明: ✅ 完成 | 🔄 语音识别中 | 📺 OCR中 | ⏳ 待处理

---

EOF

while IFS='|' read -r idx type title url; do
    CURRENT=$((CURRENT + 1))

    # 清理标题用作文件名
    SAFE_TITLE=$(echo "$title" | sed 's/[\/:*?"<>|#]/-/g' | sed 's/  */ /g' | cut -c1-80 | xargs)
    [ -z "$SAFE_TITLE" ] && SAFE_TITLE="untitled_$idx"

    # 提取视频 ID
    VIDEO_ID=$(echo "$url" | grep -oE '[0-9]{15,20}' | head -1)
    [ -z "$VIDEO_ID" ] && VIDEO_ID="unknown"

    ITEM_DIR="$OUTPUT_ROOT/$(printf '%02d' $idx)_${SAFE_TITLE}"
    mkdir -p "$ITEM_DIR"

    MD_FILE="$ITEM_DIR/${SAFE_TITLE}.md"

    echo ""
    log_info "[$CURRENT/$TOTAL] $SAFE_TITLE"
    log_info "  URL: $url"

    # ---- 生成初始 MD ----
    cat > "$MD_FILE" << MDEOF
# $title

| 属性 | 值 |
|------|-----|
| 来源 | [$url]($url) |
| 类型 | $type |
| 收集时间 | $TODAY |
| 状态 | ⏳ 处理中... |

---

## 📝 视频简介

> 正在提取...

## 🎙️ 语音识别 (Whisper)

> ⏳ 处理中...

## 📺 画面字幕 (OCR)

> ⏳ 处理中...

---

*由抖音素材收集系统自动生成*
MDEOF

    # ---- 步骤 1: 下载视频 ----
    if [ "$type" = "📹" ]; then
        log_info "  📥 下载视频..."

        DESC=$($YT_DLP --cookies "$COOKIE_FILE" --print "%(description)s" "$url" 2>/dev/null | head -20)

        $YT_DLP --cookies "$COOKIE_FILE" --no-playlist \
            -o "${ITEM_DIR}/%(title)s.%(ext)s" "$url" 2>&1 | \
            grep -E "\[download\] Destination|100%" | head -2

        VIDEO_FILE=$(ls "$ITEM_DIR"/*.mp4 "$ITEM_DIR"/*.mov "$ITEM_DIR"/*.webm 2>/dev/null | head -1)

        if [ -n "$VIDEO_FILE" ]; then
            log_ok "    下载完成: $(basename "$VIDEO_FILE")"

            # 更新描述
            if [ -n "$DESC" ] && [ "$DESC" != "null" ]; then
                perl -i -pe "s/> 正在提取.../\n${DESC}/" "$MD_FILE" 2>/dev/null || true
            else
                perl -i -pe "s/> 正在提取.../(无简介)/" "$MD_FILE" 2>/dev/null || true
            fi

            # 更新状态
            perl -i -pe "s/⏳ 处理中.../🔄 语音识别中/" "$MD_FILE" 2>/dev/null || true

            # ---- 步骤 2: 语音识别 ----
            log_info "  🎙️ 语音识别..."
            AUDIO_FILE="${ITEM_DIR}/_audio.wav"
            $FFMPEG -i "$VIDEO_FILE" -vn -acodec pcm_s16le -ar 16000 -ac 1 -y "$AUDIO_FILE" 2>/dev/null

            if [ -f "$AUDIO_FILE" ] && [ -s "$AUDIO_FILE" ]; then
                VOICE_OUT="$ITEM_DIR/_voice"
                $WHISPER -m "$WHISPER_MODEL" -l "$WHISPER_LANG" \
                    -f "$AUDIO_FILE" -otxt -of "$VOICE_OUT" 2>/dev/null

                VOICE_TXT="${VOICE_OUT}.txt"
                if [ -f "$VOICE_TXT" ] && [ -s "$VOICE_TXT" ]; then
                    # 把语音文字插入 MD
                    VOICE_CONTENT=$(cat "$VOICE_TXT")
                    # 用 Python 做文本替换（更可靠）
                    python3 -c "
import sys
md = open('$MD_FILE').read()
voice = open('$VOICE_TXT').read().strip()
md = md.replace('> ⏳ 处理中...', '✅ 完成\\n\\n' + voice)
open('$MD_FILE','w').write(md)
" 2>/dev/null
                    VOICE_OK=$((VOICE_OK + 1))
                    log_ok "    语音识别完成 ($(wc -l < "$VOICE_TXT") 行)"
                    perl -i -pe "s/🔄 语音识别中/✅ 语音完成/" "$MD_FILE" 2>/dev/null || true
                else
                    perl -i -pe "s/> ⏳ 处理中.../(该视频无明显语音)/" "$MD_FILE" 2>/dev/null || true
                    perl -i -pe "s/🔄 语音识别中/⚠️ 无语音/" "$MD_FILE" 2>/dev/null || true
                fi
                rm -f "$AUDIO_FILE" "$VOICE_TXT"
            fi

            # ---- 步骤 3: OCR 字幕 ----
            log_info "  📺 画面 OCR..."
            FRAMES_DIR="$ITEM_DIR/_frames"
            mkdir -p "$FRAMES_DIR"

            # 获取视频时长，按 3 秒间隔截图（最多 80 帧）
            $FFMPEG -i "$VIDEO_FILE" -vf "fps=1/3" -vframes 80 \
                -q:v 2 "$FRAMES_DIR/frame_%04d.png" -y 2>/dev/null

            # OCR 识别
            OCR_TXT="$ITEM_DIR/_ocr.txt"
            > "$OCR_TXT"
            PREV=""
            for frame in "$FRAMES_DIR"/frame_*.png; do
                [ ! -f "$frame" ] && continue
                TEXT=$($TESSERACT "$frame" stdout -l "$TESSERACT_LANG" --psm 6 2>/dev/null | \
                    sed '/^[[:space:]]*$/d' | sed 's/[[:space:]]\+/ /g')
                if [ -n "$TEXT" ] && [ "$TEXT" != "$PREV" ]; then
                    echo "$TEXT" >> "$OCR_TXT"
                    PREV="$TEXT"
                fi
            done

            if [ -f "$OCR_TXT" ] && [ -s "$OCR_TXT" ]; then
                OCR_CONTENT=$(cat "$OCR_TXT")
                python3 -c "
md = open('$MD_FILE').read()
ocr = open('$OCR_TXT').read().strip()
md = md.replace('> ⏳ 处理中...', '✅ 完成\\n\\n' + ocr, 1)
open('$MD_FILE','w').write(md)
" 2>/dev/null
                OCR_OK=$((OCR_OK + 1))
                log_ok "    OCR 完成 ($(wc -l < "$OCR_TXT") 行)"
                perl -i -pe "s/📺 OCR中/✅ OCR完成/" "$MD_FILE" 2>/dev/null || true
            else
                perl -i -pe "s/> ⏳ 处理中.../(该视频无明显字幕)/" "$MD_FILE" 2>/dev/null || true
            fi

            rm -rf "$FRAMES_DIR" "$OCR_TXT"

        else
            log_error "    下载失败！"
            perl -i -pe "s/⏳ 处理中.../❌ 下载失败/" "$MD_FILE" 2>/dev/null || true
        fi

    else
        # 图文帖：只保存元数据（图片需浏览器手动提取）
        log_info "  🖼️ 图文帖，标记待手动处理"
        perl -i -pe "s/> 正在提取.../(图文帖 - 请通过浏览器提取图片文字)/" "$MD_FILE" 2>/dev/null || true
        perl -i -pe "s/⏳ 处理中.../🖼️ 图文帖 - 待手动OCR/" "$MD_FILE" 2>/dev/null || true
    fi

    # 更新状态
    perl -i -pe "s/🔄 语音识别中|📺 OCR中/✅ 完成/" "$MD_FILE" 2>/dev/null || true

    # 添加到索引
    echo "| $idx | [$SAFE_TITLE]($(printf '%02d' $idx)_${SAFE_TITLE// /%20}/${SAFE_TITLE// /%20}.md) | $type | ✅ |" >> "$INDEX_FILE"

done < "$INPUT_FILE"

echo ""
log_info "============================================"
log_info "批量处理完成!"
log_info "  总数: $TOTAL"
log_info "  语音识别成功: $VOICE_OK"
log_info "  OCR 成功: $OCR_OK"
log_info "  输出: $OUTPUT_ROOT"
log_info "============================================"
