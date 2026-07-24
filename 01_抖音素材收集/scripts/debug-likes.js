// 先诊断抖音喜欢页的 DOM 结构
console.log('=== 抖音页面诊断 ===');
console.log('当前URL:', location.href);

// 检查各种可能的链接模式
const patterns = [
    'a[href*="/video/"]',
    'a[href*="/note/"]',
    'a[href*="video"]',
    'a[href*="aweme"]',
    'div[data-e2e="like-item"] a',
    'div[data-e2e="feed-card"] a',
    '.waterfall-item a',
    '[class*="video"] a',
    '[class*="card"] a',
    'ul li a',
];

patterns.forEach(sel => {
    try {
        const els = document.querySelectorAll(sel);
        if (els.length > 0) {
            console.log(`✅ "${sel}" → ${els.length} 个，示例: ${els[0].href?.substring(0,80)}`);
        }
    } catch(e) {}
});

// 列出页面上所有链接域名
const allLinks = document.querySelectorAll('a[href^="http"]');
const domains = {};
allLinks.forEach(a => {
    try {
        const u = new URL(a.href);
        domains[u.hostname] = (domains[u.hostname]||0) + 1;
    } catch(e) {}
});
console.log('📊 页面链接分布:', JSON.stringify(domains, null, 2));

// 找包含 "video" 的所有链接（不限于 a 标签属性）
console.log('📋 页面中包含 "video" 的链接:');
allLinks.forEach(a => {
    if (a.href && a.href.includes('video')) {
        console.log('  ', a.href.substring(0, 100));
    }
});
