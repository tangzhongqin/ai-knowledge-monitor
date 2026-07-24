#!/bin/bash
# ============================================
# 图片下载脚本（从 URL 列表下载图片）
# 用法: download-images.sh <urls.txt> <输出目录>
# ============================================
source "$(dirname "$0")/../config.sh"

URLS_FILE="$1"
OUTDIR="$2"

if [ ! -f "$URLS_FILE" ] || [ -z "$OUTDIR" ]; then
    echo "用法: $0 <图片URL列表文件> <输出目录>"
    exit 1
fi

mkdir -p "$OUTDIR"

log_info "下载图片..."

COUNT=0
while IFS= read -r url; do
    url=$(echo "$url" | xargs)
    [ -z "$url" ] && continue
    [[ "$url" != http* ]] && continue

    COUNT=$((COUNT + 1))
    EXT="${url##*.}"
    EXT="${EXT%%\?*}"
    [[ "$EXT" =~ ^(jpg|jpeg|png|webp|avif)$ ]] || EXT="jpg"

    OUTPUT="$OUTDIR/img_$(printf '%02d' $COUNT).${EXT}"
    curl -s -L -o "$OUTPUT" \
        -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
        -H "Referer: https://www.douyin.com/" \
        "$url" 2>&1

    if [ -f "$OUTPUT" ] && [ -s "$OUTPUT" ]; then
        log_info "  [$COUNT] $(basename "$OUTPUT") ($(du -h "$OUTPUT" | cut -f1))"
    else
        log_warn "  [$COUNT] 下载失败: $url"
        rm -f "$OUTPUT"
    fi
done < "$URLS_FILE"

log_ok "下载完成: $COUNT 个文件 → $OUTDIR"
