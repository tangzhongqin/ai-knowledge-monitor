// ============================================
// 抖音素材收集 - Content Script
// 在抖音页面上注入收集按钮
// ============================================

(function() {
    'use strict';

    // 只在已登录且是喜欢/收藏页时显示按钮
    function shouldShow() {
        return location.hostname.includes('douyin.com') &&
               (location.search.includes('showTab=like') ||
                location.search.includes('showTab=favor') ||
                location.pathname.includes('/user/self'));
    }

    if (!shouldShow()) return;

    // 避免重复注入
    if (document.getElementById('dy-collector-btn')) return;

    // ---- 创建浮动按钮 ----
    const btn = document.createElement('div');
    btn.id = 'dy-collector-btn';
    btn.textContent = '📋 一键收集';
    btn.style.cssText = `
        position: fixed; bottom: 80px; right: 20px; z-index: 999999;
        background: linear-gradient(135deg, #fe2c55, #ff5e7a);
        color: #fff; padding: 14px 22px; border-radius: 28px;
        font-size: 15px; font-weight: 700; cursor: pointer;
        box-shadow: 0 4px 18px rgba(254,44,85,.45);
        user-select: none; letter-spacing: 0.5px;
        transition: transform .15s;
    `;
    btn.onmouseenter = () => btn.style.transform = 'scale(1.06)';
    btn.onmouseleave = () => btn.style.transform = 'scale(1)';

    // ---- Toast 通知 ----
    function toast(msg, bg) {
        const t = document.createElement('div');
        t.textContent = msg;
        t.style.cssText = `
            position: fixed; top: 20px; left: 50%; transform: translateX(-50%);
            z-index: 9999999; background: ${bg || '#222'}; color: #fff;
            padding: 14px 28px; border-radius: 12px; font-size: 16px;
            font-weight: 600; box-shadow: 0 6px 24px rgba(0,0,0,.35);
            transition: opacity .3s;
        `;
        document.body.appendChild(t);
        setTimeout(() => { t.style.opacity = '0'; setTimeout(() => t.remove(), 400); }, 4000);
    }

    // ---- 收集逻辑 ----
    btn.onclick = async function() {
        btn.textContent = '⏳ 收集中...';
        btn.style.pointerEvents = 'none';

        const collected = new Set();
        let emptyScrolls = 0;
        const maxScrolls = 60;

        // 辅助：收集当前可见链接
        function collect() {
            let found = 0;
            document.querySelectorAll('a[href*="/video/"], a[href*="/note/"]').forEach(a => {
                if (a.href && !collected.has(a.href)) {
                    collected.add(a.href);
                    found++;
                }
            });
            return found;
        }

        collect(); // 首轮

        // 滚动加载
        for (let i = 0; i < maxScrolls; i++) {
            window.scrollTo(0, document.body.scrollHeight);
            await new Promise(r => setTimeout(r, 1200));

            const before = collected.size;
            collect();
            if (collected.size === before) {
                emptyScrolls++;
                if (emptyScrolls > 4) break; // 连续 5 次没新内容，到底了
            } else {
                emptyScrolls = 0;
            }

            btn.textContent = `⏳ ${collected.size} 条...`;
        }

        // 完成
        const urls = [...collected];
        if (urls.length === 0) {
            toast('❌ 未找到视频/图文链接', '#e74c3c');
            btn.textContent = '📋 一键收集';
            btn.style.pointerEvents = 'auto';
            return;
        }

        // 复制到剪贴板
        try {
            await navigator.clipboard.writeText(urls.join('\n'));
            toast(`✅ 已复制 ${urls.length} 条链接！`, '#27ae60');
        } catch(e) {
            // fallback
            const ta = document.createElement('textarea');
            ta.value = urls.join('\n');
            ta.style.cssText = 'position:fixed;left:-9999px';
            document.body.appendChild(ta);
            ta.select();
            document.execCommand('copy');
            document.body.removeChild(ta);
            toast(`✅ 已复制 ${urls.length} 条链接！`, '#27ae60');
        }

        btn.textContent = `📋 收集 (${urls.length}条)`;
        btn.style.pointerEvents = 'auto';

        // 3 秒后恢复按钮文字
        setTimeout(() => { btn.textContent = '📋 一键收集'; }, 3000);
    };

    document.body.appendChild(btn);
    console.log('🎬 抖音素材收集插件已就绪');
})();
