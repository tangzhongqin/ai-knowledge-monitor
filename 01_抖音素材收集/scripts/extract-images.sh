#!/bin/bash
# ============================================
# 图片文字提取脚本（图文帖专用）
# 用法: extract-images.sh <图片目录或单张图片> <输出目录>
# ============================================
source "$(dirname "$0")/../config.sh"

INPUT="$1"
OUTDIR="$2"

if [ -z "$INPUT" ] || [ -z "$OUTDIR" ]; then
    echo "用法: $0 <图片目录|图片文件> <输出目录>"
    exit 1
fi

mkdir -p "$OUTDIR"
OCR_RESULT="$OUTDIR/images_ocr.txt"
> "$OCR_RESULT"

log_info "开始图片 OCR..."

process_image() {
    local img="$1"
    local idx="$2"
    local fname=$(basename "$img")

    # 检查是否是有效图片
    local MIME=$(file --mime-type -b "$img" 2>/dev/null)
    if [[ ! "$MIME" =~ image/ ]]; then
        return
    fi

    local TEXT=$($TESSERACT "$img" stdout -l "$TESSERACT_LANG" --psm 6 2>/dev/null | \
        sed '/^[[:space:]]*$/d' | \
        sed 's/[[:space:]]\+/ /g')

    if [ -n "$TEXT" ]; then
        echo "" >> "$OCR_RESULT"
        echo "── 图片 ${idx} ──" >> "$OCR_RESULT"
        echo "$TEXT" >> "$OCR_RESULT"
        log_info "  图片${idx}: 识别到 $(echo "$TEXT" | wc -l) 行文字"
    else
        log_info "  图片${idx}: 无文字内容"
    fi
}

if [ -f "$INPUT" ]; then
    # 单张图片
    process_image "$INPUT" 1
elif [ -d "$INPUT" ]; then
    # 图片目录
    local idx=1
    # 按文件名排序
    for img in "$INPUT"/*.png "$INPUT"/*.jpg "$INPUT"/*.jpeg "$INPUT"/*.webp "$INPUT"/*.avif 2>/dev/null; do
        [ -f "$img" ] || continue
        process_image "$img" $idx
        idx=$((idx + 1))
    done
fi

if [ -s "$OCR_RESULT" ]; then
    log_ok "图片 OCR 完成: $(wc -l < "$OCR_RESULT") 行"
    cat "$OCR_RESULT"
else
    log_warn "未识别到任何图片文字"
    echo "(图片中未检测到文字)" > "$OCR_RESULT"
fi
