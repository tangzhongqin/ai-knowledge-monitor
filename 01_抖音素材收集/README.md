# 01_抖音素材收集

> 从抖音喜欢列表一键提取视频/图文，自动语音识别+画面OCR，加工后归档到知识库。

## 命令入口

```bash
# 一键收集（交互式）
bash 01_抖音素材收集/collect.sh

# 批量下载 + ASR + OCR
bash 01_抖音素材收集/scripts/batch-process.sh <url列表> <输出目录>

# 加工清洗 → 排版 → 归档到知识库
bash 01_抖音素材收集/scripts/enrich.sh [日期]

# 使用 Chrome 扩展采集喜欢列表
# 打开 01_抖音素材收集/extension/ → Chrome 加载已解压的扩展程序 → 抖音喜欢页点按钮
```

## 加工流程

```
Chrome扩展采集URL → 下载视频 → ASR语音识别 → OCR画面字幕 → enrich清洗加工 → 归档知识库
```

## 目录

| 目录 | 说明 |
|------|------|
| `scripts/` | 脚本：下载(batch-download)、语音(batch-asr)、字幕(batch-ocr)、加工(enrich) |
| `extension/` | Chrome 扩展（一键采集抖音喜欢列表） |
| `output/` | 原始素材输出（按日期） |
| `config.sh` | 配置：工具路径、模型、语言参数 |
| `加工规则.md` | 加工标准：命名/模板/三维度归类/三步流程 |

## 依赖

- yt-dlp（视频下载，需 cookie 登录态）
- whisper-cli（语音识别，ggml-small.bin 模型）
- tesseract（OCR，chi_sim+eng）
- ffmpeg（音频提取/截图）
