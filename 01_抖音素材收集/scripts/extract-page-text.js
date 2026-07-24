// ============================================
// 抖音页面文字提取 - 通用版
// 图文 note + 视频 都能用
// 用法：打开任意抖音页面 → F12 → Console → 粘贴运行
// ============================================
(function extractDouyinText() {
    const result = {
        title: '',
        description: '',
        subtitleText: [],  // 画面上的字幕/文字
        url: location.href,
        type: location.pathname.includes('/note/') ? '图文' : '视频'
    };

    // 1. 提取描述文字
    const descSelectors = [
        '[data-e2e="feed-desc"]',
        '[data-e2e="aweme-desc"]',
        '.video-info-detail .desc',
        '[class*="desc"] span',
        'meta[name="description"]',
        'meta[property="og:description"]'
    ];

    for (const sel of descSelectors) {
        try {
            const el = document.querySelector(sel);
            if (el) {
                const text = (el.content || el.textContent || '').trim();
                if (text && text.length > result.description.length) {
                    result.description = text;
                }
            }
        } catch(e) {}
    }

    // 2. 提取标题 (note 类型有标题栏)
    const titleEls = document.querySelectorAll('[class*="title"], h1, h2');
    titleEls.forEach(el => {
        const text = el.textContent.trim();
        if (text && text.length > 5 && text.length < 200 && !result.title) {
            result.title = text;
        }
    });

    // 3. 抓取页面所有可见文本（fallback）
    if (!result.description) {
        const body = document.body.innerText;
        result._rawText = body.substring(0, 2000);
    }

    // 4. 提取图片链接（图文帖专用）
    result.imageUrls = [];
    // 尝试多种选择器
    const imgSelectors = [
        'img[src*="douyinvod"]',
        'img[src*="byteimg"]',
        'img[src*="ibyteimg"]',
        'img[src*="douyinpic"]',
        '.swiper-slide img',
        '[class*="image"] img',
        '[class*="img"] img',
        '.note-image img',
        'img[src^="http"]'
    ];
    const seenUrls = new Set();
    for (const sel of imgSelectors) {
        try {
            document.querySelectorAll(sel).forEach(img => {
                const src = img.src || img.getAttribute('data-src') || '';
                if (src && src.startsWith('http') && !seenUrls.has(src)) {
                    // 过滤掉小图标
                    const w = img.naturalWidth || img.width || 0;
                    const h = img.naturalHeight || img.height || 0;
                    if ((w > 100 || h > 100) || !w) {
                        seenUrls.add(src);
                        result.imageUrls.push(src);
                    }
                }
            });
        } catch(e) {}
    }

    // 5. 找 meta 信息
    const ogTitle = document.querySelector('meta[property="og:title"]');
    if (ogTitle && ogTitle.content) result.title = result.title || ogTitle.content;

    console.log('╔══════════════════════════════╗');
    console.log('║   抖音内容提取结果           ║');
    console.log('╚══════════════════════════════╝');
    console.log('类型:', result.type);
    console.log('标题:', result.title || '(无)');
    console.log('描述:', result.description || '(无)');
    console.log('URL:', result.url);

    // 复制
    // 构造输出
    let output = `【${result.type}】${result.title || ''}
${result.description || ''}
`;
    if (result.imageUrls.length > 0) {
        output += `---
📸 图片链接 (${result.imageUrls.length}张):
${result.imageUrls.join('\n')}
`;
    }
    output += `---
🔗 ${result.url}`;

    navigator.clipboard.writeText(output).then(() => {
        console.log('✅ 文案+图片链接已复制！直接粘贴给 Claude');
    }).catch(() => {
        console.log('📋 请手动复制上方内容');
        console.log(output);
    });

    return result;
})();
