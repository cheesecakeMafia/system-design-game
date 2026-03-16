# Lecture 3: CDNs & Object Storage

> Module 1 — "The Request Journey" | Lecture 3 of 20

In Lecture 1 you traced a request from Tokyo to Virginia — 160ms round trip. What if the response was already sitting on a server in Tokyo? That's what a CDN does. This lecture covers how content delivery networks move data closer to users, and how object storage provides the backbone for files that don't belong in a database.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Content delivery network*
- *Push CDNs*
- *Pull CDNs*

---

## Concept Briefing

### What CDNs Actually Do

A **Content Delivery Network** is a geographically distributed network of servers that cache content close to end users. Instead of every request traveling to your origin server in Virginia, static assets (images, CSS, JS, videos) are served from the nearest **edge server** — also called a **Point of Presence (PoP)**.

```
Without CDN:
  User (Tokyo) ──── 160ms ────► Origin (Virginia)

With CDN:
  User (Tokyo) ──── 10ms ────► CDN Edge (Tokyo) ──── cache miss? ────► Origin (Virginia)
```

A CDN doesn't just reduce latency for individual users. It reduces load on your origin servers because most requests never reach them.

### The CDN Architecture

```
┌─────────┐     ┌─────────┐     ┌─────────┐
│ Edge PoP│     │ Edge PoP│     │ Edge PoP│
│ Tokyo   │     │ London  │     │ Sao Paulo│
└────┬────┘     └────┬────┘     └────┬────┘
     │               │               │
     └───────────────┼───────────────┘
                     │
              ┌──────┴──────┐
              │   Origin    │
              │   Server    │
              └─────────────┘
```

Each edge PoP has its own cache. When a user requests content:
1. Request goes to the nearest edge PoP
2. If the content is cached (cache hit) → serve immediately
3. If not cached (cache miss) → fetch from origin, cache it, serve it

---

## Deep Dive

### Push vs Pull CDNs

This is the fundamental CDN architecture decision.

**Pull CDN (Lazy Loading)**
- Content is fetched from origin on the first request (cache miss)
- Subsequent requests are served from the cache until TTL expires
- You change nothing about your deployment — the CDN sits in front

| Pros | Cons |
|------|------|
| Zero upfront work — just point DNS to CDN | First request in each region is slow (origin fetch) |
| Only caches content that's actually requested | Thundering herd: popular new content → many simultaneous cache misses |
| Storage-efficient — no unused content cached | TTL management is critical |

**Push CDN (Proactive Loading)**
- You upload content directly to the CDN before users request it
- Content is pre-positioned at edge locations
- You manage what's on the CDN explicitly

| Pros | Cons |
|------|------|
| No cold-start latency — content is already there | More operational complexity — you manage the upload pipeline |
| Predictable performance for new content | Wastes storage if content is rarely accessed |
| Works well for large files (videos, software updates) | Requires knowing in advance what to push |

**When to use which:**

| Scenario | Choice | Why |
|----------|--------|-----|
| Blog with unpredictable traffic | Pull | Don't know which posts will go viral |
| Video streaming platform | Push | You know exactly which videos exist, and buffering is unacceptable |
| E-commerce product images | Pull | High catalog volume, not all products are equally popular |
| Software update distribution | Push | Every user needs the same file, pre-positioning guarantees fast downloads |
| User-generated content (social media) | Pull + Warm | Can't predict what goes viral, but can pre-warm trending content |

### CDN Caching: TTL, Invalidation, and Cache Keys

#### TTL (Time to Live)

Every cached object has a TTL — how long the edge server keeps it before checking with the origin for a fresh copy.

| Content Type | Suggested TTL | Reasoning |
|-------------|---------------|-----------|
| Static assets (CSS, JS with hash in filename) | 1 year | The hash changes when content changes — old URLs are never reused |
| Product images | 24 hours | Rarely change, and slight staleness is acceptable |
| User profile photos | 1 hour | Users expect changes to reflect quickly |
| API responses | 0-60 seconds | Data changes frequently, staleness is often unacceptable |
| HTML pages | 0-5 minutes | Depends on how dynamic the content is |

**The immutable content trick:** If you include a content hash in the filename (`app.a8b3f2.js` instead of `app.js`), you can set a TTL of 1 year. When the content changes, the filename changes, so the old cached version is never served for the new file. This is the standard approach for modern web apps.

#### Cache Invalidation

What if you need content to update before the TTL expires? CDN invalidation options:

1. **Wait for TTL** — Simplest. Just wait for the cache to expire naturally. Only works if your TTL is short enough.
2. **Purge** — Tell the CDN to delete a specific URL from all edge caches. Fast (seconds), but costs API calls.
3. **Versioned URLs** — Change the URL when content changes (e.g., `/v2/image.jpg` or `/image.jpg?v=2`). Old URL stays cached, new URL is a cache miss.
4. **Soft purge / stale-while-revalidate** — Serve the stale version while fetching a fresh one in the background. Best UX — no delay.

**Cache invalidation is notoriously hard.** The famous quote: *"There are only two hard things in Computer Science: cache invalidation and naming things."* We'll go much deeper on caching strategies in Lecture 9.

#### Cache Keys

A **cache key** determines what counts as "the same request." Usually it's the URL, but it can include:
- URL path
- Query parameters
- Headers (e.g., `Accept-Language` for localized content)
- Cookies (careful — this can destroy your hit rate)

**Common mistake:** Including too much in the cache key. If you include the user's auth cookie, every user gets their own cached copy, and your hit rate drops to near zero. Only include what actually changes the response.

### CDN for Dynamic Content (Edge Computing)

Modern CDNs can do more than cache static files:
- **Edge functions** (Cloudflare Workers, Lambda@Edge) — Run code at the edge
- **A/B testing** — Route users to different variants without hitting origin
- **Personalization** — Assemble personalized pages from cached fragments
- **API acceleration** — Cache API responses with short TTLs

This blurs the line between CDN and application server, but the principle is the same: move computation closer to the user.

### Real CDNs: How They Differ

| CDN | Strength | Typical Use |
|-----|----------|-------------|
| **CloudFront** | Deep AWS integration | AWS-native apps |
| **Cloudflare** | Free tier, DDoS protection, Workers | Wide range, startups to enterprise |
| **Akamai** | Largest network, enterprise features | Media, large enterprise |
| **Fastly** | Real-time purging, VCL flexibility | Dynamic content, API caching |

### When CDNs Hurt (Anti-patterns)

Not everything benefits from a CDN:

1. **Highly personalized content** — If every response is unique to the user, there's nothing to cache. The CDN just adds a hop.
2. **Low-traffic sites** — If your origin handles the load fine, a CDN adds complexity without meaningful benefit.
3. **Rapidly changing data** — If content changes every second, even short TTLs mean stale data.
4. **Geographic concentration** — If all your users are in one city and your server is in that city, a CDN adds latency (user → CDN edge → origin vs user → origin).

---

### Object/Blob Storage

Not everything belongs in a database. Photos, videos, PDFs, backups, log files — these are **binary large objects (blobs)** that are better served by specialized storage.

#### What Object Storage Is

Object storage treats files as flat objects with:
- A **key** (like a file path: `users/42/profile.jpg`)
- The **data** (the file itself)
- **Metadata** (content type, creation date, custom tags)

There are no directories, no file system hierarchy — just a flat namespace of key-value pairs. The "directories" you see in S3 are just key prefixes.

#### Object Storage vs Database vs File System

| Factor | Object Storage (S3) | Database (PostgreSQL) | File System (ext4) |
|--------|---------------------|----------------------|-------------------|
| **Best for** | Large files, unstructured data | Structured data, relationships, queries | Local files, OS-level access |
| **Max object size** | 5 TB (S3) | ~1 GB (practical limit) | Limited by disk |
| **Query capability** | Key lookup only | Full SQL | Directory listing |
| **Scalability** | Virtually unlimited | Requires sharding | Single machine |
| **Cost per GB** | ~$0.02/month | ~$0.10-0.50/month | Hardware cost |
| **Durability** | 99.999999999% (11 nines, S3) | Depends on replication | Depends on RAID |
| **Access pattern** | Read-heavy, write-once | Read/write, transactional | Local read/write |

**Rule of thumb:** If you're storing files >1 MB that don't need SQL queries, use object storage. If you're storing structured data that needs relationships and queries, use a database. Don't store user-uploaded videos in PostgreSQL.

#### How Object Storage Fits in System Design

```
User uploads photo → App Server → Object Storage (S3)
                                        │
                                        ▼
                                   CDN caches it
                                        │
                                        ▼
                              Other users fetch from CDN
```

This pattern appears in almost every system that handles user-generated content: social media, file sharing, video platforms, document editors.

---

## Discussion Prompts

1. **A social media platform lets users upload photos that can be viewed globally. Should you use a push or pull CDN for these photos?** What about for the first 5 minutes after upload, when the uploader's friends are most likely to view it?

2. **You set a 24-hour TTL on product images. A product is recalled and its image must be removed immediately from all CDN edges. What's your strategy?** Consider the trade-offs between speed, cost, and complexity.

3. **Why does object storage (S3) achieve 11 nines of durability while a typical database only achieves 3-4 nines of availability?** What architectural differences explain this gap? (Hint: durability and availability are different things.)

---

## Field Ops: Server Survival

In the game, the **Storage** service handles `STATIC` and `UPLOAD` traffic types.

Think about it through the CDN lens:
- `STATIC` traffic is read-heavy — these are the requests a CDN would handle
- `UPLOAD` traffic goes directly to storage — CDNs don't help with writes
- What happens to your system when you place Storage far from Compute? That's the latency you'd see without a CDN

Notice how `STATIC` traffic volume is typically much higher than `UPLOAD` — this is the read-heavy pattern that makes CDNs so effective.

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. A CDN edge server location is called a Point of ______ (PoP).

2. In a ______ CDN, content is fetched from the origin server on the first request, while in a ______ CDN, content is uploaded to edge servers before users request it.

3. Object storage systems like S3 store data as flat ______ with a key, data, and metadata — there is no directory hierarchy.

### Multiple Choice (4 points)

4. Your web app serves product images with a 1-hour TTL. A product image is accidentally replaced with an offensive image. What is the fastest way to remove it from all CDN edges?

   - a) Wait 1 hour for the TTL to expire
   - b) Send a purge request to the CDN for that specific URL
   - c) Delete the origin file and wait for cache misses
   - d) Reduce the TTL to 1 second

5. Which content type would benefit LEAST from a CDN?

   - a) A site's logo image used on every page
   - b) Real-time stock prices updated every 100ms
   - c) A JavaScript bundle with a content hash in the filename
   - d) Product photos on an e-commerce site

6. You're storing 10 million user-uploaded photos (average 500 KB each). Which storage option is most appropriate?

   - a) PostgreSQL with a BYTEA column
   - b) Redis for fast access
   - c) Object storage (S3 or equivalent)
   - d) Local filesystem on the app server

7. A pull CDN has a 95% cache hit rate. Your origin server can handle 1,000 QPS. What is the maximum total QPS (including CDN-served requests) the system can handle?

   - a) 1,000 QPS
   - b) 10,000 QPS
   - c) 20,000 QPS
   - d) 95,000 QPS

### Short Answer (3 points)

8. Explain the "immutable content" caching strategy. How does including a content hash in filenames allow you to set very long TTLs without serving stale content?

9. A video streaming startup serves 1 billion video views per day. Each view streams an average of 500 MB. Estimate the bandwidth savings if a CDN achieves an 85% cache hit rate versus serving everything from the origin.

10. You're designing a file-sharing service like Dropbox. Users upload files (1 KB to 10 GB). Explain why object storage is better than a relational database for this use case, and name one thing a relational database would still be needed for.

<details>
<summary>Answer Key</summary>

1. **Presence** (Point of Presence)
2. **pull** / **push**
3. **objects**
4. **b)** — A CDN purge request removes the specific URL from all edge caches within seconds. Waiting for TTL (a) takes too long. Deleting the origin file (c) only affects future cache misses. Reducing TTL (d) only applies to future caches, not existing ones.
5. **b)** — Real-time stock prices updated every 100ms change too frequently for caching to be effective. Even a 1-second TTL would serve stale data 90% of the time. The other options are all excellent CDN candidates: static images, hashed JS bundles, and product photos change infrequently.
6. **c)** — Object storage is designed for this: large binary files, read-heavy, no need for SQL queries. PostgreSQL (a) has practical blob size limits and wastes database resources. Redis (b) stores data in memory — 10M × 500KB = 5 TB of RAM is impractical. Local filesystem (d) doesn't scale to multiple app servers.
7. **c) 20,000 QPS** — If 95% of requests are served by the CDN, only 5% reach the origin. If the origin handles 1,000 QPS, that 1,000 = 5% of total, so total = 1,000 / 0.05 = 20,000 QPS.
8. When you include a content hash in the filename (e.g., `app.a8b3f2.js`), the filename itself changes whenever the content changes. You can set a TTL of 1 year because the old URL will never be requested once the HTML page references the new filename. Users always get the fresh version because the URL is different, while the old cached version expires naturally. This eliminates the need for cache invalidation entirely for versioned assets.
9. Total daily bandwidth without CDN: 1B views × 500 MB = 500 PB/day (500,000 TB). With 85% CDN hit rate, origin serves only 15%: 500 PB × 0.15 = 75 PB/day. Savings: 425 PB/day. At even $0.01/GB for bandwidth, that's 425,000,000 GB × $0.01 = $4.25M/day saved. This is why Netflix, YouTube, and every major streaming service uses CDNs — the bandwidth cost savings alone justify it.
10. Object storage is better because: it's designed for arbitrarily large files (up to 5 TB per object), it's extremely durable (11 nines), it scales without sharding, and it costs ~5-25x less per GB than database storage. A relational database would still be needed for file metadata: user ownership, file names, sharing permissions, folder structure, version history, and access control. The pattern is: metadata in the database, file content in object storage.

</details>

---

## Challenge Mission: "The Global Deploy"

### Scenario

You're the lead engineer at a video streaming startup. Currently US-only, you're expanding to Europe and Asia. Here are your numbers:

**Current state:**
- 5 million users (US only)
- Users upload videos: average 500 MB each, 10,000 uploads per day
- Users stream videos: 1 billion views per day, average stream 200 MB
- All infrastructure is in US-East (Virginia)
- European users report 3-4 second load times (vs 500ms for US users)

**Expansion targets:**
- EU (Frankfurt region): 3 million expected users
- Asia (Tokyo region): 2 million expected users
- Latency target: <1 second first-frame time for all regions

### Your Task

**Part 1 — Estimation**

Calculate:
1. Daily upload storage growth (in TB)
2. Annual storage requirement (in PB)
3. Peak streaming bandwidth (assume peak is 3x average, concentrated in 4 peak hours per timezone)
4. Annual storage cost at $0.023/GB/month (S3 standard)

**Part 2 — CDN Strategy**

1. Push or pull CDN for video streaming? Justify your choice.
2. Should newly uploaded videos be pushed to all regions immediately, or pulled on first request? Consider that most views happen in the first 24 hours after upload.
3. What TTL would you set for video files? For video thumbnails? For the video catalog API?
4. Estimate the CDN cache hit rate you'd need to keep origin bandwidth under 50 Gbps.

**Part 3 — Upload Architecture**

1. Where do uploads land? Single region or multi-region object storage?
2. How do you handle a user in Tokyo uploading a 500 MB video to storage in Virginia? (Hint: think about upload acceleration.)
3. Design the upload → processing → CDN pipeline. What happens between upload and the video being available to stream?

**Part 4 — Cache Invalidation**

1. A content creator uploads a video, then immediately re-uploads an edited version to the same URL. How do you ensure viewers see the updated version?
2. A video is taken down for copyright violation. How quickly can you remove it from all CDN edges worldwide?

### Constraints

- Budget: you can spend up to $500K/month on infrastructure
- Regulatory: EU user data must be processed in the EU (GDPR)
- Users expect videos to be available to stream within 5 minutes of upload

### Hints

<details>
<summary>Hint 1: Upload acceleration</summary>
Major cloud providers offer "transfer acceleration" — uploads are routed to the nearest edge location, then transferred to the destination region over the provider's backbone network (which is faster and more reliable than the public internet).
</details>

<details>
<summary>Hint 2: Processing pipeline</summary>
Raw uploaded videos need transcoding (converting to multiple formats and resolutions). This is CPU-intensive and takes time. Think about where this processing happens and how the CDN fits in.
</details>

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 1:

- **CDN (Content Delivery Network)** — Geographically distributed cache that serves content from edge servers close to users.
- **Edge server / PoP (Point of Presence)** — A CDN server location near end users.
- **Origin server** — The original source of content that the CDN caches from.
- **Pull CDN** — Fetches content from origin on first request, then caches it.
- **Push CDN** — Content is pre-uploaded to edge servers before users request it.
- **Cache hit rate** — Percentage of requests served from cache vs fetched from origin.
- **TTL (in CDN context)** — How long an edge server caches content before re-validating with the origin.
- **Object storage** — Storage system for unstructured data (files/blobs), accessed by key. Examples: S3, GCS, Azure Blob.
- **Cache invalidation** — Removing or updating stale cached content before its TTL expires.
