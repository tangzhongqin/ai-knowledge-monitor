// ============================================
// 抖音"喜欢"列表提取脚本
// 使用方法：
//   1. 打开 https://www.douyin.com，进入"喜欢"页面
//   2. 按 F12 打开控制台 (Console)
//   3. 粘贴本脚本，回车运行
//   4. 等待自动滚动结束，链接会自动复制
// ============================================

(async function extractLikedVideos() {
    const collected = new Set();
    const maxScrolls = 50;  // 最多滚动次数
    const scrollDelay = 1500; // 每次滚动间隔 ms

    console.log('🔍 开始扫描喜欢的视频...');
    console.log('📜 自动滚动中，请等待...');

    // 收集当前页面的视频链接
    function collect() {
        const links = document.querySelectorAll('a[href*="/video/"], a[href*="/note/"]');
        let newCount = 0;
        links.forEach(a => {
            const href = a.href;
            if (href && !collected.has(href)) {
                collected.add(href);
                newCount++;
            }
        });
        return newCount;
    }

    // 首次收集
    collect();

    // 滚动加载更多
    for (let i = 0; i < maxScrolls; i++) {
        window.scrollTo(0, document.body.scrollHeight);
        await new Promise(r => setTimeout(r, scrollDelay));

        const before = collected.size;
        collect();
        const after = collected.size;

        if (after === before && i > 3) {
            // 连续没新内容，可能到底了
            console.log(`📊 已到底，共找到 ${after} 个视频`);
            break;
        }
        console.log(`  ↕️ 滚动 ${i+1}/${maxScrolls}，已找到 ${after} 个`);
    }

    // 输出结果
    const urls = [...collected].join('\n');
    console.log(`\n✅ 完成！共 ${collected.size} 个视频：`);
    console.log(urls);
    console.log('\n📋 链接已自动复制到剪贴板！');

    // 复制到剪贴板
    try {
        await navigator.clipboard.writeText(urls);
        console.log('✅ 已复制，直接粘贴到终端即可');
    } catch(e) {
        // fallback
        const ta = document.createElement('textarea');
        ta.value = urls;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
        console.log('✅ 已复制（fallback方式）');
    }
})();
