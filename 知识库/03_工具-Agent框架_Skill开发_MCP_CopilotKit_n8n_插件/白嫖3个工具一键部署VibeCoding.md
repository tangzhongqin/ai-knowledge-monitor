# 🚀 白嫖 3 个工具，一键部署 VibeCoding

> 来源：抖音 @VIBEHUNT | 收集时间：2026-07-23
> 原视频：https://www.douyin.com/video/7631596909697813794

---

## 📌 一句话总结

**Cloudflare（CDN/安全） + Vercel（无服务器部署） + Supabase（数据库/认证）** 组成零成本 VibeCoding 部署铁三角，让 AI 生成的代码一键上线到全球。

---

## 🎙️ 原始语音转录（已清洗纠错）

我一分钱没花，让互联网大善人帮我把网站部署到了全球。做过 VibeCoding 的人都知道，让 AI 写代码容易，但部署到线上非常难——你要买域名、买服务器、买数据库、证书，这四样差不多得花个一年往上。我这个网站花了多少钱部署呢？答案是零。今天就让我们来盘点一下互联网三大善人。

互联网上大概有 20% 的流量，全部经由 Cloudflare 的 CDN 节点转发的。Minecraft 在 2023 年遭到攻击时，每秒遭到一万亿次请求，它的防火墙是谁扛住的？就是大名鼎鼎的 Cloudflare。请问这个防火墙服务收费吗？答案是免费的，免费用户跟付费用户没有任何区别。所以我说它是互联网首善，绝对不过分。

包括早期 OpenAI，也是用 Vercel 来部署自己的服务器的。

Supabase，它绝对是免费数据库里面的王。它不挣钱，我真搞不懂这些公司为什么要这么做，压根不挣钱啊兄弟们。

所有的这些免费服务，全部都是美国的、海外的。建议大家去白嫖 Cloudflare、Vercel，还有 Supabase。毕竟 100 年前老佛爷已经替我们交过税了，放心大胆地白嫖吧。

---

## 🔍 核心内容

### 三大免费工具的定位

| 工具 | 解决什么问题 | 免费额度（关键） |
|------|-------------|-----------------|
| **Cloudflare** | DNS 托管 + CDN 加速 + DDoS 防护 + SSL 证书 | CDN/防火墙完全免费，不限量 |
| **Vercel** | 前端/全栈无服务器部署，Git 推送即上线 | 100GB 带宽/月，无限静态站点 |
| **Supabase** | PostgreSQL 数据库 + 认证 + 实时订阅 + 文件存储 | 500MB 数据库，50MB 文件存储，50,000 月活用户 |

### 为什么这组合能覆盖 VibeCoding 全流程

```
你写的 AI 代码（Next.js / React / Vue）
        │
        ▼
   Vercel 一键部署 ─── 自动 HTTPS、全球 CDN、边缘函数
        │
        ├── 前端静态资源 → Vercel Edge Network（80+ 节点）
        ├── API 路由 → Vercel Serverless Functions
        ├── 数据库操作 → Supabase（PostgreSQL，自带 REST/GraphQL API）
        ├── 用户认证 → Supabase Auth（支持 OAuth、Magic Link）
        ├── 域名 DNS → Cloudflare（免费托管，解析速度最快之一）
        └── DDoS 防护 → Cloudflare（无限量，企业级规则）
```

---

## 🧠 专家升华

### 一、技术深度分析：为什么这个架构能跑生产环境

**1. Cloudflare 的免费防火墙不是"阉割版"**

Cloudflare 的商业模式是"安全即获客"——它的 DDoS 防护和 CDN 对免费用户没有性能或功能缩水，真正的区别在于：高级 WAF 规则、自定义 SSL for SaaS、Argo Smart Routing、Workers 调用次数等。对个人/VibeCoding 项目来说，免费版已经完全够用。

- **全球 Anycast 网络**：330+ 城市、120+ 国家，免费用户共享同一基础设施
- **DDoS 防护原理**：基于 BGP 的流量清洗 + 第 3/4/7 层联合防御，Minecraft 2023 年遭受的 1Tbps+ 攻击就是被这套系统吸收的
- **实际建议**：开启 `Full (strict)` SSL 模式 + 自动 HTTPS 重写 + Brotli 压缩，不需要花一分钱

**2. Vercel 的 Serverless 模型——为什么早期 OpenAI 也用**

Vercel 底层是 AWS Lambda + CloudFront，但它封装了所有运维细节。关键能力：

- **ISR（Incremental Static Regeneration）**：动态内容按需生成静态页面并缓存，兼顾性能和实时性
- **Edge Functions**：代码跑在全球边缘节点而非单一区域，延迟极低
- **Preview Deployments**：每个 PR 自动生成一个独立预览环境，这在 VibeCoding 中意味着你可以让 AI 生成代码后立刻看到效果，不需要搭测试环境
- **冷启动问题**：Serverless 函数的冷启动确实存在（Node.js ~50ms, Next.js ~1-2s），但 Vercel 的边缘网络预热策略可以大幅缓解

**3. Supabase 为什么敢做"免费数据库之王"**

Supabase 本质上是 Firebase 的开源替代品，底层是 PostgreSQL。它的免费逻辑是：

- **PostgreSQL 本身就是开源的**，Supabase 没有数据库授权成本
- **边际成本极低**：500MB 数据库存储成本几乎可以忽略
- **转化漏斗**：当你用户量起来后，自然需要更大存储、更多计算、团队协作功能 → 付费转化
- **技术亮点**：自带 PostgREST（自动将数据库表映射为 RESTful API）、Realtime（基于 PostgreSQL 的 WAL 流实现实时订阅）、Row Level Security（行级安全策略直接在数据库层面做权限控制，不需要后端中间层）

### 二、更优方案与补充工具

**除了这三大件，你还应该知道的免费午餐：**

| 需求 | 免费方案 | 比视频推荐更好的点 |
|------|---------|------------------|
| **后端逻辑** | Cloudflare Workers（10 万次/天） | 比 Vercel Serverless 更便宜，冷启动更快（V8 Isolate） |
| **对象存储** | Cloudflare R2（10GB 免费） | 零出站流量费，比 S3 良心太多 |
| **邮件服务** | Resend（100 封/天） | 比 SendGrid 免费版好用，React 组件式模板 |
| **定时任务** | Cloudflare Cron Triggers | 无需单独买 VPS 跑 cron |
| **用户认证（备选）** | Clerk（1 万月活免费） | 比 Supabase Auth UI 组件更好看 |
| **监控分析** | Umami（自部署免费）/ PostHog（100 万事件/月） | 替代 Google Analytics |
| **AI 接口代理** | Cloudflare AI Gateway | 免费缓存 + 限流 + 成本追踪，直接套在 OpenAI API 前面 |

**完整免费部署技术栈推荐：**

```
域名 → Cloudflare Registrar（成本价注册，免费 WHOIS 隐私保护）
DNS → Cloudflare DNS
前端 → Vercel（Next.js / Astro / Nuxt）
后端逻辑 → Vercel Serverless + Cloudflare Workers（分场景）
数据库 → Supabase（PostgreSQL + Auth + Realtime）
对象存储 → Cloudflare R2（文件上传/图片/视频）
邮件 → Resend
监控 → Umami + Cloudflare Web Analytics
API 网关 → Cloudflare AI Gateway（套在 LLM API 前）
```

### 三、行业位置：为什么这些公司都来自美国

视频提到"全部都是美国的"，这背后有其结构性原因：

1. **AWS/Cloudflare 的边际成本优势**：美国云厂商经过 20 年竞争，已经将计算、存储、带宽的边际成本压到极低，免费额度在财务上完全可行
2. **开发者关系（DevRel）文化**：美国 SaaS 公司普遍重视"先让开发者用起来"，免费额度是获客成本的一部分，而非亏损
3. **PLG（Product-Led Growth）模式成熟**：免费用户 → 个人项目 → 团队使用 → 企业签约，这个漏斗经过 Stripe、Atlassian、GitHub 验证
4. **国内对应方案**：阿里云/腾讯云有免费额度但限制更多（需实名、信用卡预绑定、免费期短），Vercel 的国内替代可以看 EdgeOne Pages（腾讯云）和云开发CloudBase，但体验差距明显

### 四、实操建议

**快速启动 VibeCoding 部署工作流（0 到上线，15 分钟）：**

1. **Supabase 建项目**（2 分钟）→ 创建数据库表 → 获取 API Key
2. **本地用 AI 生成 Next.js 应用** → 设置环境变量（Supabase URL + Anon Key）
3. **`git push` 到 GitHub** → Vercel 自动检测并部署
4. **Cloudflare 添加域名** → 改 Nameserver → 等 DNS 生效（5-10 分钟）
5. **Vercel 绑定自定义域名** → 自动申请 SSL 证书
6. **上线完成**，全程只花了域名注册费（约 $10/年，用 Cloudflare Registrar 更便宜）

**注意事项：**
- Supabase 免费数据库在 7 天无活动后会暂停（需要访问一次唤醒）
- Vercel 免费版不能用于商业用途（Hobby 计划限制），商业化项目需要升级 Pro（$20/月）
- Cloudflare 的 CDN 在中国大陆没有节点，国内访问速度一般——如果主要服务国内用户，需要额外考虑国内 CDN

---

## 🔗 涉及工具

| 工具 | 地址 | 一句话说明 |
|------|------|-----------|
| Cloudflare | https://cloudflare.com | CDN + DNS + DDoS 防护 + Workers |
| Vercel | https://vercel.com | 前端/全栈无服务器部署平台 |
| Supabase | https://supabase.com | Firebase 替代品，PostgreSQL 即服务 |
| Cloudflare R2 | https://developers.cloudflare.com/r2/ | 零出站费对象存储 |
| Resend | https://resend.com | 开发者友好的邮件 API |
| Clerk | https://clerk.com | 即插即用用户认证组件 |
| Umami | https://umami.is | 隐私友好的开源网站分析 |

---

## 💪 行动清单

- [ ] 注册 Cloudflare 账号，将自己的域名 DNS 迁移到 Cloudflare
- [ ] 注册 Vercel 账号，关联 GitHub，尝试部署一个 AI 生成的 Next.js 项目
- [ ] 注册 Supabase 账号，创建一个测试项目，体验数据库 + Auth + Realtime
- [ ] 将三个工具串联：Supabase 建表 → Next.js 写 CRUD → Vercel 部署 → Cloudflare 挂域名
- [ ] 探索 Cloudflare Workers 作为补充后端，降低 Vercel Serverless 成本
- [ ] 了解 Supabase Row Level Security，做到数据库层面权限控制，避免写后端中间层
- [ ] 如服务国内用户，研究国内 CDN 方案（EdgeOne / 阿里云 CDN）作为补充
