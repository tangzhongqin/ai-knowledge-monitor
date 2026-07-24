#!/bin/bash
# ============================================
# 视频下载脚本
# 用法: download.sh <视频URL> <输出目录>
# ============================================
source "$(dirname "$0")/../config.sh"

URL="$1"
OUTDIR="$2"

if [ -z "$URL" ] || [ -z "$OUTDIR" ]; then
    echo "用法: $0 <视频URL> <输出目录>"
    exit 1
fi

mkdir -p "$OUTDIR"

log_info "开始下载: $URL"

# yt-dlp 下载视频，自动以视频标题命名
# --no-playlist: 不下载播放列表
# -o: 输出模板（标题+扩展名）
$YT_DLP \
    --cookies "$COOKIE_FILE" \
    --no-playlist \
    --write-info-json \
    -o "${OUTDIR}/%(title)s.%(ext)s" \
    "$URL" 2>&1 | while IFS= read -r line; do
    # 过滤掉噪音，只显示进度
    if echo "$line" | grep -qE '\[download\]|Destination|ERROR|WARNING'; then
        echo "  $line"
    fi
done

# 检查下载结果
VIDEO_FILE=$(ls "$OUTDIR"/*.mp4 "$OUTDIR"/*.mov "$OUTDIR"/*.webm 2>/dev/null | head -1)
INFO_FILE=$(ls "$OUTDIR"/*.info.json 2>/dev/null | head -1)

if [ -n "$VIDEO_FILE" ]; then
    VIDEO_NAME=$(basename "$VIDEO_FILE" | sed 's/\.[^.]*$//')
    log_ok "下载完成: $VIDEO_NAME"
    # 返回视频文件路径
    echo "$VIDEO_FILE"
    exit 0
else
    log_error "下载失败，请检查 URL 和 Cookie 是否有效"
    echo "  URL: $URL"
    exit 1
fi
