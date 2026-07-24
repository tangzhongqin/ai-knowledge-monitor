#!/bin/bash
# ============================================
# 语音转文字脚本 (Whisper ASR)
# 用法: extract-voice.sh <视频文件> <输出目录>
# ============================================
source "$(dirname "$0")/../config.sh"

VIDEO_FILE="$1"
OUTDIR="$2"

if [ ! -f "$VIDEO_FILE" ]; then
    echo "用法: $0 <视频文件> <输出目录>"
    exit 1
fi

mkdir -p "$OUTDIR"

VIDEO_NAME=$(basename "$VIDEO_FILE" | sed 's/\.[^.]*$//')
AUDIO_FILE="$OUTDIR/${VIDEO_NAME}_audio.wav"
TEXT_FILE="$OUTDIR/${VIDEO_NAME}_voice.txt"

log_info "提取音频..."
$FFMPEG -i "$VIDEO_FILE" \
    -vn \
    -acodec pcm_s16le \
    -ar $AUDIO_SAMPLE_RATE \
    -ac 1 \
    -y "$AUDIO_FILE" 2>&1 | grep -v "^$" | tail -2

log_info "Whisper 语音识别中（这可能需要几分钟）..."
$WHISPER \
    -m "$WHISPER_MODEL" \
    -l "$WHISPER_LANG" \
    -f "$AUDIO_FILE" \
    -otxt \
    -of "$OUTDIR/${VIDEO_NAME}_voice" 2>&1 | tail -5

# whisper-cpp 输出文件会加后缀，找到它
if [ -f "$TEXT_FILE" ]; then
    LINE_COUNT=$(wc -l < "$TEXT_FILE")
    log_ok "语音识别完成: $LINE_COUNT 行文字"
    cat "$TEXT_FILE"
else
    # 可能输出为其他格式
    OUTPUT_TXT=$(ls "$OUTDIR/${VIDEO_NAME}_voice"*.txt 2>/dev/null | head -1)
    if [ -n "$OUTPUT_TXT" ]; then
        mv "$OUTPUT_TXT" "$TEXT_FILE"
        LINE_COUNT=$(wc -l < "$TEXT_FILE")
        log_ok "语音识别完成: $LINE_COUNT 行文字"
        cat "$TEXT_FILE"
    else
        log_warn "语音识别未产出文本（可能视频没有语音内容）"
        echo "(该视频无明显语音内容)" > "$TEXT_FILE"
    fi
fi

# 清理临时音频文件（保留原视频）
rm -f "$AUDIO_FILE"
log_info "语音提取完成: $TEXT_FILE"
