#!/bin/bash
# ============================================
# 抖音素材收集系统 - 配置文件
# ============================================

# 项目根目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# 工具路径
YT_DLP="$PROJECT_DIR/.venv/bin/yt-dlp"
FFMPEG="$(which ffmpeg)"
WHISPER="$(which whisper-cli)"
TESSERACT="$(which tesseract)"

# Cookie 文件（登录态）
COOKIE_FILE="$PROJECT_DIR/../douyin_cookies.txt"

# Whisper 模型
WHISPER_MODEL="$PROJECT_DIR/models/ggml-small.bin"

# 输出根目录
OUTPUT_DIR="$PROJECT_DIR/output"

# 语言设置
TESSERACT_LANG="chi_sim+eng"    # OCR: 简体中文 + 英文
WHISPER_LANG="zh"               # ASR: 中文

# 视频处理参数
OCR_FRAME_INTERVAL=2            # OCR: 每 N 秒截一帧
MAX_FRAMES=200                  # OCR: 最大截图数（防止超长视频）
AUDIO_SAMPLE_RATE=16000         # ASR: 音频采样率

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
