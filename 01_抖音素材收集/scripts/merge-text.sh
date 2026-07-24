#!/bin/bash
# ============================================
# 合并输出脚本
# 用法: merge-text.sh <视频名称> <输出目录> <视频描述>
# ============================================
source "$(dirname "$0")/../config.sh"

VIDEO_NAME="$1"
OUTDIR="$2"
DESCRIPTION="$3"

VOICE_FILE="$OUTDIR/${VIDEO_NAME}_voice.txt"
OCR_FILE="$OUTDIR/${VIDEO_NAME}_ocr.txt"
FINAL_FILE="$OUTDIR/${VIDEO_NAME}.txt"

cat > "$FINAL_FILE" << EOF
╔══════════════════════════════════════════╗
║  视频标题: ${VIDEO_NAME}
║  提取时间: $(date '+%Y-%m-%d %H:%M:%S')
╚══════════════════════════════════════════╝

EOF

# 视频描述/简介
if [ -n "$DESCRIPTION" ] && [ "$DESCRIPTION" != "null" ]; then
    cat >> "$FINAL_FILE" << EOF
📝 视频简介:
${DESCRIPTION}

────────────────────────────────────────
EOF
fi

# 语音文字
echo "" >> "$FINAL_FILE"
echo "🎙️ 【语音识别 - 画面内讲话/旁白】" >> "$FINAL_FILE"
echo "" >> "$FINAL_FILE"
if [ -f "$VOICE_FILE" ]; then
    cat "$VOICE_FILE" >> "$FINAL_FILE"
else
    echo "(无语音内容)" >> "$FINAL_FILE"
fi

# 画面 OCR 文字
echo "" >> "$FINAL_FILE"
echo "" >> "$FINAL_FILE"
echo "📺 【画面字幕/文字 - OCR 识别】" >> "$FINAL_FILE"
echo "" >> "$FINAL_FILE"
if [ -f "$OCR_FILE" ]; then
    cat "$OCR_FILE" >> "$FINAL_FILE"
else
    echo "(无画面文字)" >> "$FINAL_FILE"
fi

echo "" >> "$FINAL_FILE"
echo "────────────────────────────────────────" >> "$FINAL_FILE"
echo "提取完成 ✅" >> "$FINAL_FILE"

log_ok "最终文件: $FINAL_FILE"
cat "$FINAL_FILE"
