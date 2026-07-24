#!/bin/bash
# ============================================
# 画面 OCR 脚本（ffmpeg 截图 + tesseract 识别）
# 用法: extract-ocr.sh <视频文件> <输出目录>
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
FRAMES_DIR="$OUTDIR/${VIDEO_NAME}_frames"
OCR_TEXT_FILE="$OUTDIR/${VIDEO_NAME}_ocr.txt"

mkdir -p "$FRAMES_DIR"

# 获取视频时长
DURATION=$($FFMPEG -i "$VIDEO_FILE" 2>&1 | grep "Duration" | awk '{print $2}' | sed 's/,//')
log_info "视频时长: $DURATION"
log_info "每 ${OCR_FRAME_INTERVAL} 秒截一帧（最多 $MAX_FRAMES 帧）..."

# 按间隔截图
$FFMPEG -i "$VIDEO_FILE" \
    -vf "fps=1/${OCR_FRAME_INTERVAL}" \
    -vframes $MAX_FRAMES \
    -q:v 2 \
    "$FRAMES_DIR/frame_%04d.png" -y 2>&1 | grep -v "^$" | tail -2

FRAME_COUNT=$(ls "$FRAMES_DIR"/*.png 2>/dev/null | wc -l)
log_info "共截取 $FRAME_COUNT 帧"

if [ "$FRAME_COUNT" -eq 0 ]; then
    log_error "截图失败"
    exit 1
fi

log_info "开始 OCR 识别..."

# 每帧 OCR，收集结果
PREV_TEXT=""
> "$OCR_TEXT_FILE"

for frame in "$FRAMES_DIR"/frame_*.png; do
    FRAME_NUM=$(echo "$frame" | grep -oE '[0-9]+\.png' | sed 's/\.png//')

    # tesseract OCR
    TEXT=$($TESSERACT "$frame" stdout -l "$TESSERACT_LANG" --psm 6 2>/dev/null | \
        sed '/^[[:space:]]*$/d' | \
        sed 's/[[:space:]]\+/ /g')

    # 去重：与上一帧相同的文字不重复输出
    if [ -n "$TEXT" ] && [ "$TEXT" != "$PREV_TEXT" ]; then
        # 计算时间戳
        SECONDS=$((10#$FRAME_NUM * OCR_FRAME_INTERVAL))
        TIMESTAMP=$(printf "%02d:%02d" $((SECONDS/60)) $((SECONDS%60)))
        echo "[$TIMESTAMP] $TEXT" >> "$OCR_TEXT_FILE"
        PREV_TEXT="$TEXT"
    fi
done

TEXT_LINES=$(wc -l < "$OCR_TEXT_FILE")
log_ok "OCR 完成: $TEXT_LINES 行有效文字"

# 输出结果
cat "$OCR_TEXT_FILE"

# 清理截图（保留文字结果）
rm -rf "$FRAMES_DIR"
log_info "画面文字提取完成: $OCR_TEXT_FILE"
