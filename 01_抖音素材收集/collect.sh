#!/bin/bash
# ============================================
# 抖音素材收集 - 主控脚本
# 用法:
#   ./collect.sh                          交互式输入
#   ./collect.sh <视频URL>                 处理单个视频
#   ./collect.sh <urls.txt>               处理文件中的多个视频
#   ./collect.sh --list                   列出今天已收集的视频
# ============================================
source "$(dirname "$0")/config.sh"

TODAY=$(date '+%Y-%m-%d')
TODAY_DIR="$OUTPUT_DIR/$TODAY"

# ---------- 检查依赖 ----------
check_deps() {
    local missing=0
    log_info "检查依赖..."

    if [ ! -f "$YT_DLP" ]; then
        log_error "yt-dlp 未安装: brew install yt-dlp"
        missing=1
    fi
    if [ ! -f "$FFMPEG" ]; then
        log_error "ffmpeg 未安装: brew install ffmpeg"
        missing=1
    fi
    if [ ! -f "$WHISPER" ]; then
        log_error "whisper-cpp 未安装: brew install whisper-cpp"
        missing=1
    fi
    if [ ! -f "$TESSERACT" ]; then
        log_error "tesseract 未安装: brew install tesseract"
        missing=1
    fi
    if [ ! -f "$COOKIE_FILE" ]; then
        log_warn "Cookie 文件未找到: $COOKIE_FILE"
        log_warn "抖音下载可能失败，请重新提取 Cookie"
    fi
    if [ ! -f "$WHISPER_MODEL" ]; then
        log_error "Whisper 模型未找到: $WHISPER_MODEL"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        exit 1
    fi
    log_ok "依赖检查通过"
}

# ---------- 显示进度 ----------
show_progress() {
    echo ""
    echo "┌─────────────────────────────────────────┐"
    echo "│  抖音素材收集 - $TODAY                    │"
    echo "├─────────────────────────────────────────┤"
    echo "│  待处理: ${TOTAL} 个视频                      │"
    echo "│  已完成: ${DONE}/${TOTAL}                         │"
    echo "│  当前: ${CURRENT_VIDEO}                    │"
    echo "└─────────────────────────────────────────┘"
    echo ""
}

# ---------- 处理单个视频 ----------
process_video() {
    local URL="$1"
    local index="${2:-1}"

    log_info "------------------------------------------------"
    log_info "处理视频 ($index/$TOTAL): $URL"

    # 先用 yt-dlp 获取视频信息（不下载）
    local TITLE=$($YT_DLP --cookies "$COOKIE_FILE" --get-title "$URL" 2>/dev/null | head -1)
    local DESC=$($YT_DLP --cookies "$COOKIE_FILE" --get-description "$URL" 2>/dev/null | head -5)

    if [ -z "$TITLE" ]; then
        log_error "无法获取视频信息，跳过: $URL"
        return 1
    fi

    # 清理标题用作目录名（移除特殊字符）
    local SAFE_TITLE=$(echo "$TITLE" | sed 's/[\/:*?"<>|]/-/g' | cut -c1-60)
    local VIDEO_DIR="$TODAY_DIR/${index}_${SAFE_TITLE}"

    log_info "视频标题: $TITLE"
    log_info "输出目录: $VIDEO_DIR"

    # 步骤 1: 下载
    CURRENT_VIDEO="$TITLE"
    echo ""
    log_info "📥 步骤 1/4: 下载视频..."
    VIDEO_FILE=$(bash "$PROJECT_DIR/scripts/download.sh" "$URL" "$VIDEO_DIR")
    if [ $? -ne 0 ] || [ ! -f "$VIDEO_FILE" ]; then
        log_error "下载失败"
        return 1
    fi
    VIDEO_FILE=$(echo "$VIDEO_FILE" | tail -1)

    # 步骤 2: 语音提取（后台运行 OCR 的同时做 ASR）
    echo ""
    log_info "🎙️ 步骤 2/4: 语音识别 (Whisper)..."
    bash "$PROJECT_DIR/scripts/extract-voice.sh" "$VIDEO_FILE" "$VIDEO_DIR"
    VOICE_OK=$?

    # 步骤 3: 画面 OCR
    echo ""
    log_info "📺 步骤 3/4: 画面文字提取 (OCR)..."
    bash "$PROJECT_DIR/scripts/extract-ocr.sh" "$VIDEO_FILE" "$VIDEO_DIR"
    OCR_OK=$?

    # 步骤 4: 合并
    echo ""
    log_info "📝 步骤 4/4: 合并输出..."
    VIDEO_NAME=$(basename "$VIDEO_FILE" | sed 's/\.[^.]*$//')
    bash "$PROJECT_DIR/scripts/merge-text.sh" "$VIDEO_NAME" "$VIDEO_DIR" "$DESC"

    DONE=$((DONE + 1))

    echo ""
    log_ok "✅ 完成: $TITLE"
    log_info "📄 文案: $VIDEO_DIR/${VIDEO_NAME}.txt"
}

# ---------- 列出今天收集的视频 ----------
list_today() {
    echo ""
    echo "📂 今日收集 ($TODAY):"
    echo "=========================================="
    if [ -d "$TODAY_DIR" ]; then
        find "$TODAY_DIR" -name "*.txt" -not -name "*_voice*" -not -name "*_ocr*" | while read f; do
            echo "  📄 $(basename "$f")"
            echo "     $(dirname "$f")"
            echo ""
        done
    else
        echo "  今天还没有收集任何视频"
    fi
}

# ---------- 生成书签脚本 ----------
generate_bookmarklet() {
    cat << 'EOF'

┌──────────────────────────────────────────────────────────┐
│  📌 获取抖音"喜欢"列表的方法                               │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  方法 1（推荐）: 在浏览器地址栏粘贴这段 JavaScript：        │
│                                                          │
│  javascript:(function(){var a=document.querySelectorAll('a[href*="/video/"],a[href*="/note/"]');var b=[...new Set([...a].map(function(c){return c.href}))];var d=b.join('\n');var e=document.createElement('textarea');e.value=d;document.body.appendChild(e);e.select();document.execCommand('copy');document.body.removeChild(e);alert('已复制 '+b.length+' 个链接！')})();                                                       │
│                                                          │
│  ⚠️ 注意：浏览器可能会删掉开头的 "javascript:"，             │
│     你需要手动打上去！                                     │
│                                                          │
│  方法 2: 手动复制链接，粘贴到文本文件                        │
│  方法 3: 用 "抖音" App 的分享功能，复制链接后发过来          │
│                                                          │
└──────────────────────────────────────────────────────────┘
EOF
}

# ---------- 主入口 ----------
main() {
    check_deps

    case "${1:-}" in
        --list|-l)
            list_today
            exit 0
            ;;
        --bookmarklet|-b)
            generate_bookmarklet
            exit 0
            ;;
    esac

    # 收集 URL 列表
    URLS=()
    if [ -n "$1" ]; then
        if [ -f "$1" ]; then
            # 从文件读取
            log_info "从文件读取 URL: $1"
            while IFS= read -r line; do
                line=$(echo "$line" | xargs)
                if [ -n "$line" ] && [[ "$line" == http* ]]; then
                    URLS+=("$line")
                fi
            done < "$1"
        else
            # 单个 URL
            URLS+=("$1")
        fi
    else
        # 交互式输入
        echo ""
        echo "╔══════════════════════════════════════╗"
        echo "║     抖音素材收集 - 交互模式           ║"
        echo "╚══════════════════════════════════════╝"
        echo ""
        echo "请粘贴视频链接（每行一个，输入空行结束）:"
        echo "----------------------------------------"
        while IFS= read -r line; do
            [ -z "$line" ] && break
            line=$(echo "$line" | xargs)
            if [[ "$line" == http* ]]; then
                URLS+=("$line")
            fi
        done
    fi

    if [ ${#URLS[@]} -eq 0 ]; then
        log_error "没有有效的视频链接"
        echo ""
        echo "提示:"
        echo "  1. 打开抖音网页版 https://www.douyin.com"
        echo "  2. 进入「喜欢」页面"
        echo "  3. 运行 ./collect.sh --bookmarklet 获取书签工具"
        echo "  4. 复制链接后重新运行 ./collect.sh"
        exit 1
    fi

    TOTAL=${#URLS[@]}
    DONE=0
    CURRENT_VIDEO=""

    mkdir -p "$TODAY_DIR"

    show_progress

    for i in "${!URLS[@]}"; do
        process_video "${URLS[$i]}" $((i+1))
    done

    # 总结
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║  🎉 收集完成！                        ║"
    echo "║                                      ║"
    echo "║  处理: $DONE/$TOTAL 个视频                ║"
    echo "║  位置: $TODAY_DIR                     ║"
    echo "╚══════════════════════════════════════╝"

    list_today
}

main "$@"
