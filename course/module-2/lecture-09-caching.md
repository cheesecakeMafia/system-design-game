# Lecture 9: Caching — All Strategies

> Module 2 — "The Data Fortress" | Lecture 9 of 20

Caching is the single most impactful performance optimization in system design. A well-designed cache can reduce database load by 95%, cut response times from 100ms to 1ms, and save hundreds of thousands of dollars in infrastructure. This lecture covers every caching strategy you'll need — where to cache, how to cache, and the notoriously hard problem of keeping caches in sync.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Cache* (all subsections through *Refresh-ahead*)

**OOD Exercise (recommended):** Work through the LRU Cache notebook at [`../../deps/system-design-primer/solutions/object_oriented_design/lru_cache/lru_cache.ipynb`](../../deps/system-design-primer/solutions/object_oriented_design/lru_cache/lru_cache.ipynb). Implementing LRU eviction yourself makes cache behavior much more intuitive.

---

## Deep Dive

### Where to Cache

Caching can happen at every layer of the stack:

```
Client ── Browser Cache ── CDN Cache ── Web Server Cache ── App Cache ── DB Cache
```

| Layer | What's Cached | TTL | Controlled By |
|-------|--------------|-----|---------------|
| **Browser** | Static assets, API responses | `Cache-Control` header | Server (via HTTP headers) |
| **CDN** | Static files, sometimes API responses | CDN TTL config | DevOps / CDN settings |
| **Reverse proxy** | Full HTTP responses | Proxy config (nginx, Varnish) | DevOps |
| **Application** | Query results, computed data | Application code | Developers |
| **Database** | Query plans, buffer pool (pages) | Automatic | Database engine |

For system design interviews, the **application cache** is where most decisions live — and that's what we'll focus on.

### The Four Caching Strategies

#### 1. Cache-Aside (Lazy Loading)

The most common strategy. The application manages the cache explicitly.

```
Read:
1. Check cache for key
2. Cache HIT → return cached data
3. Cache MISS → read from database → write to cache → return data

Write:
1. Write to database
2. Invalidate (delete) the cache entry
```

```
        ┌──────┐  1. check  ┌──────┐
Client──►│ App  │──────────►│ Cache│
        │Server│◄──────────│(Redis)│
        │      │  2. miss   └──────┘
        │      │──────────►┌──────┐
        │      │◄──────────│  DB  │
        └──────┘  3. read  └──────┘
         │    ▲
         │    │ 4. write result to cache
         └────┘
```

| Pros | Cons |
|------|------|
| Only caches data that's actually requested | First request is always slow (cache miss) |
| Cache failure doesn't break reads (fall through to DB) | **Thundering herd** — if cache expires and 1000 requests arrive simultaneously, all 1000 hit the database |
| Simple to implement | Stale data possible between DB write and cache invalidation |

**The thundering herd problem:** When a popular cache entry expires, hundreds of concurrent requests see a cache miss and ALL query the database simultaneously. Solutions:
- **Locking:** Only one request fetches from DB; others wait for the cache to be populated
- **Early expiration (jitter):** Add random variation to TTLs so entries don't all expire at once
- **Stale-while-revalidate:** Serve stale data while one request refreshes the cache in the background

#### 2. Write-Through

Every write goes to both the cache and the database, in sequence.

```
Write:
1. Write to cache
2. Cache writes to database
3. Return success only after both succeed
```

| Pros | Cons |
|------|------|
| Cache is always consistent with DB | **Higher write latency** — two writes per operation |
| No stale data | Caches data that may never be read (wasted memory) |
| Simple invalidation (cache is always fresh) | Cache failure blocks writes |

**Best for:** Data that is always read after being written (e.g., user profile displayed immediately after update).

#### 3. Write-Behind (Write-Back)

Writes go to the cache first. The cache asynchronously writes to the database in batches.

```
Write:
1. Write to cache
2. Return success immediately
3. Cache asynchronously flushes to database (batched)
```

| Pros | Cons |
|------|------|
| Extremely fast writes (cache-speed) | **Data loss risk** — if cache crashes before flushing, writes are lost |
| Batching reduces DB write load | Complex to implement correctly |
| Absorbs write spikes | Debugging is harder (writes are deferred) |

**Best for:** High write throughput where losing a few seconds of data is acceptable (metrics, analytics, real-time counters).

#### 4. Refresh-Ahead

The cache proactively refreshes entries before they expire, based on access patterns.

```
1. Cache entry will expire in 10 seconds
2. Cache predicts it will be accessed again (based on recent access history)
3. Cache proactively fetches fresh data from DB before expiry
4. Next request gets fresh data with no miss latency
```

| Pros | Cons |
|------|------|
| Eliminates cache miss latency for hot data | Wasted refreshes for data that wouldn't have been requested |
| Prevents thundering herd (entry never actually expires) | Complex to implement — needs access frequency tracking |
| Smooth, consistent latency | Can increase DB load if predictions are wrong |

**Best for:** Predictable, high-frequency access patterns (e.g., a news site's top 10 articles).

### Cache Eviction Policies

When the cache is full, which entries do you remove?

| Policy | How It Works | Best For |
|--------|-------------|----------|
| **LRU (Least Recently Used)** | Evict the entry that hasn't been accessed the longest | General purpose — good default |
| **LFU (Least Frequently Used)** | Evict the entry accessed the fewest times | When frequency is a better signal than recency |
| **TTL (Time to Live)** | Evict when the entry's TTL expires | When staleness has a natural time limit |
| **FIFO (First In, First Out)** | Evict the oldest entry | Simple, but ignores access patterns |
| **Random** | Evict a random entry | Surprisingly effective in practice |

**In practice:** Most systems use LRU + TTL together. LRU handles the "cache is full" case, TTL handles the "data is stale" case.

### Cache Invalidation — The Hard Problem

*"There are only two hard things in Computer Science: cache invalidation and naming things." — Phil Karlton*

When the source data changes, the cached version becomes stale. Your options:

**1. TTL-based expiration**
- Set a TTL. Cache automatically expires entries.
- Simple, but data is stale for up to TTL seconds.
- Trade-off: short TTL = less staleness but more cache misses; long TTL = more staleness but better hit rate.

**2. Event-based invalidation**
- When data changes, publish an event. Cache subscribes and deletes/updates the entry.
- More complex but much fresher data.
- Requires a reliable event system (message queue, pub/sub).

**3. Active invalidation**
- The write path explicitly deletes the cache entry after writing to the DB.
- Simple and immediate, but fragile — if the invalidation fails, cache is stale.

**4. Version keys**
- Include a version number in the cache key: `user:42:v5`.
- When data changes, increment the version. Old cache entry is never read again (it's a different key).
- Clean, but requires storing the current version somewhere.

**The consistency gap:** With cache-aside, there's a brief window between "write to DB" and "invalidate cache" where a concurrent read can get stale data:

```
Time 0: Cache has user.name = "Alice"
Time 1: Writer updates DB: user.name = "Bob"
Time 2: Reader reads cache → gets "Alice" (stale!)
Time 3: Writer invalidates cache
Time 4: Reader reads cache → miss → reads DB → gets "Bob" ✓
```

For most applications, this millisecond-level staleness is acceptable. For financial systems, it's not — which is why write-through or read-your-writes consistency is used.

### Distributed Caching with Consistent Hashing

When you have multiple cache servers (a Redis cluster), which server holds which key?

```
Key "user:42" → hash("user:42") → lands on cache server 3
Key "user:99" → hash("user:99") → lands on cache server 1
```

This is exactly the consistent hashing you learned in Lecture 6, applied to cache nodes instead of database shards. The same benefits apply:
- Adding a cache server only moves ~1/N of keys
- Removing a cache server only moves its keys to neighbors
- Virtual nodes ensure even distribution

**When a cache node dies:** Only the keys on that node are lost. Other nodes are unaffected. The lost keys will be cache misses that repopulate from the database — a brief spike in DB load, not a catastrophe.

**When the entire cache dies:** All reads become cache misses simultaneously — a "cold cache" scenario. The database gets hit with full read traffic. This can cascade into a database overload. Mitigation: gradual cache warming (pre-populate hot keys), circuit breakers on the DB, and ensuring the DB can handle full load briefly.

### Redis vs Memcached

| Feature | Redis | Memcached |
|---------|-------|-----------|
| **Data structures** | Strings, lists, sets, sorted sets, hashes, streams | Strings only |
| **Persistence** | Yes (RDB, AOF) | No — memory only |
| **Replication** | Master-slave | No built-in replication |
| **Clustering** | Redis Cluster (auto-sharding) | Client-side consistent hashing |
| **Memory efficiency** | Less efficient (overhead per key) | More efficient (slab allocation) |
| **Pub/Sub** | Yes | No |
| **Lua scripting** | Yes | No |
| **Max value size** | 512 MB | 1 MB |
| **Threading** | Single-threaded (commands) | Multi-threaded |

**When to choose Redis:** When you need data structures beyond key-value, persistence, replication, or pub/sub. This is the default choice for most applications.

**When to choose Memcached:** When you need a simple, multi-threaded cache with maximum memory efficiency for string-only values, and you don't need persistence. Facebook uses Memcached at massive scale for exactly this reason.

---

## Discussion Prompts

1. **Your cache hit rate is 95%, and you're happy with it. Then a product manager asks: "What's the experience like for the 5% who get cache misses?"** Calculate: if your cache-hit response time is 5ms and cache-miss response time is 200ms, what's the average and the P95 latency?

2. **You run a flash sale that creates 100,000 simultaneous requests for the same product page. The cache entry for that product just expired. Describe exactly what happens (the thundering herd) and design a solution.**

3. **Your team argues about cache invalidation strategy. The frontend team wants long TTLs (1 hour) for performance. The product team wants immediate consistency (no stale data). How do you satisfy both?**

---

## Field Ops: Server Survival

Open [Server Survival](../../deps/server-survival/index.html) and play **Survival mode**.

**Goal:** Achieve high cache effectiveness — watch the DB load drop when you place Cache nodes.

Focus on:
- Place a **Cache** service between **Compute** and **SQL DB**
- Watch the SQL DB's load indicator before and after placing the Cache
- What happens if you place Cache without a SQL DB? (Cache misses have nowhere to go)
- Try placing 2 Cache nodes. Does it help more than 1?

The game's Cache service is essentially a cache-aside pattern: Compute checks Cache first, falls through to SQL DB on miss.

Record your observations in [progress.md](../progress.md).

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. In cache-aside, when a cache entry expires and hundreds of simultaneous requests all hit the database, this is called the ______ problem.

2. The write-behind caching strategy provides the fastest write speed but risks ______ if the cache crashes before flushing writes to the database.

3. The cache eviction policy that removes the entry that hasn't been accessed for the longest time is called ______.

### Multiple Choice (4 points)

4. A user updates their profile. Your system uses cache-aside with a 5-minute TTL. Without explicit invalidation, what's the worst-case staleness?

   - a) 0 seconds — cache-aside always serves fresh data
   - b) Up to 5 minutes — until the TTL expires
   - c) Indefinitely — cache-aside never expires
   - d) Depends on the eviction policy

5. You're designing a real-time leaderboard that updates every second with 10,000 concurrent viewers. Which caching strategy is most appropriate?

   - a) Cache-aside with 1-second TTL
   - b) Write-through — update cache on every score change
   - c) Write-behind — batch score updates to the database
   - d) No caching — always read from the database

6. Your Redis cluster has 5 nodes. Node 3 crashes permanently. What happens to the keys that were on Node 3?

   - a) They're automatically redistributed to the remaining 4 nodes
   - b) They're lost — subsequent reads for those keys become cache misses
   - c) The entire cache becomes unavailable
   - d) Redis automatically restores them from disk

7. A product page is cached with a 10-minute TTL. The product price changes from $99 to $79 (a sale). Which invalidation approach ensures customers see the new price immediately?

   - a) Wait for the TTL to expire — it's only 10 minutes
   - b) Explicitly delete the cache entry after updating the database
   - c) Use a longer TTL to reduce cache misses
   - d) Disable caching for all product pages

### Short Answer (3 points)

8. Explain the difference between cache-aside and write-through caching. For an e-commerce product catalog that updates prices twice daily but serves 50,000 reads/second, which strategy would you choose and why?

9. Your cache has a 95% hit rate. Your database can handle 10,000 QPS. What is the maximum total QPS your system can handle? If the cache hit rate drops to 80%, what happens?

10. Describe a scenario where caching makes things WORSE, not better. What characteristics of the workload make caching counterproductive?

<details>
<summary>Answer Key</summary>

1. **thundering herd** (or "stampede" / "cache stampede")
2. **data loss**
3. **LRU (Least Recently Used)**
4. **b)** — With cache-aside and a 5-minute TTL, the cached data is served until it expires. If the profile is updated at time 0, the cache still serves the old data until the TTL expires at time 5:00. Without explicit invalidation (just TTL), the worst case is 5 minutes of stale data.
5. **b)** — Write-through ensures the cache is always up to date. Every score change writes to both cache and DB, so the 10,000 viewers always see current data. Cache-aside with 1-second TTL (a) would cause thundering herd every second. Write-behind (c) would delay visibility. No caching (d) would put 10,000 reads/sec directly on the DB.
6. **b)** — In a standard Redis cluster, keys on a crashed node are lost. Subsequent reads for those keys become cache misses and are repopulated from the database. Redis doesn't automatically redistribute cache data from a dead node. (With Redis Sentinel or Cluster replicas, a replica can take over — but the question says "permanently crashed" with no replica mentioned.)
7. **b)** — Explicit cache deletion immediately after updating the database ensures the next read is a cache miss that fetches the new price. Waiting for TTL (a) means some customers see $99 for up to 10 minutes during a sale — lost revenue. Longer TTL (c) makes it worse. Disabling caching (d) is overkill.
8. Cache-aside: the application checks the cache, falls through to DB on miss, and populates the cache. Write-through: every write goes to both cache and DB; the cache is always fresh. For the product catalog (updates 2x/day, 50K reads/sec): cache-aside with explicit invalidation on price updates. The write rate is so low (2x/day) that write-through's "always cache everything written" would cache many products that are never read. Cache-aside only caches products that are actually requested (the hot set), which is more memory-efficient. The 2x/day price updates can explicitly invalidate the cache entry, keeping data fresh.
9. At 95% hit rate: only 5% of requests reach the database. If DB handles 10,000 QPS, total = 10,000 / 0.05 = 200,000 QPS. At 80% hit rate: 20% reach the DB. Total = 10,000 / 0.20 = 50,000 QPS. Dropping from 95% to 80% hit rate reduces capacity by 4x — from 200K to 50K QPS. Cache hit rate has an outsized impact on overall capacity because it's inversely proportional.
10. Caching makes things worse when: (1) The workload is write-heavy with low read repetition — every write invalidates the cache, and the next read is always a miss. You pay the cache write cost with no read benefit. (2) The data is highly unique (e.g., user-specific search results) — each entry is read once, so the cache never gets a hit. You waste memory storing data that's never reused. (3) Cache key space is too large relative to cache size — constant evictions mean the cache is churning but not actually serving hits. The characteristic: when your cache hit rate is below ~50%, the overhead of maintaining the cache (writes, invalidations, memory) may exceed the benefit.

</details>

---

## Challenge Mission: "The Cache Conundrum"

### Scenario

You're designing the caching layer for an e-commerce platform with three distinct components:

**Component 1: Product Catalog (read-heavy)**
- 500,000 products
- 50,000 product page views per second
- Products update 2-3 times per day (price changes, description edits)
- Average product data: 5 KB

**Component 2: Shopping Cart (write-heavy)**
- 2 million active carts
- Users add/remove items every 30 seconds on average during a shopping session
- Cart data: 1-10 KB (list of items with quantities)
- Carts expire after 24 hours of inactivity
- Cart contents must be consistent (user adds item → immediately sees it)

**Component 3: User Sessions**
- 5 million concurrent sessions
- Session data: 2 KB (auth token, preferences, last-visited)
- Lookup by session_id only
- Sessions expire after 30 minutes of inactivity
- 200,000 session reads/second

### Your Task

For each component, design the caching layer:

1. **Caching strategy** — Which of the four strategies (cache-aside, write-through, write-behind, refresh-ahead)?
2. **Cache technology** — Redis, Memcached, or other?
3. **TTL** — What expiration time?
4. **Invalidation** — How do you handle data changes?
5. **Memory estimation** — How much cache memory is needed?
6. **Failure mode** — What happens if the cache goes down?

**Then answer:**
7. A product's price changes from $99 to $79 (flash sale). A customer views the product, sees $99 (stale cache), adds it to their cart, and proceeds to checkout. What price do they pay? Design a solution that prevents this inconsistency.

8. Black Friday hits. Your cache hit rate drops from 95% to 70% due to an influx of new users browsing products they've never viewed before (cold cache for those products). Your database is at 80% capacity. What's your immediate response?

### Constraints

- Total cache budget: 128 GB of Redis memory across all components
- Maximum acceptable staleness: 30 seconds for product data, 0 seconds for cart data
- P99 read latency target: 10ms for all three components

---

## Supplementary Reading

**[Scaling Memcached at Facebook](https://cs.uwaterloo.ca/~brecht/courses/854-Emerging-2014/readings/key-value/fb-memcached-nsdi-2013.pdf)**

This paper describes how Facebook scaled Memcached to handle billions of requests per second. Key concepts: look-aside caching, thundering herd mitigation with leases, regional pools, and cold cluster warmup. Many of the patterns in this lecture come directly from Facebook's experience.

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 2:

- **Cache-aside (lazy loading)** — Application checks cache first; on miss, reads from DB and populates cache. Most common strategy.
- **Write-through** — Every write goes to both cache and DB. Cache is always consistent but writes are slower.
- **Write-behind (write-back)** — Writes go to cache first; cache asynchronously flushes to DB. Fast writes, data loss risk.
- **Refresh-ahead** — Cache proactively refreshes entries before TTL expires based on access patterns.
- **Thundering herd** — Many simultaneous cache misses for the same key overwhelm the database.
- **LRU (Least Recently Used)** — Eviction policy that removes the least recently accessed entry.
- **Cache hit rate** — Percentage of requests served from cache. Has outsized impact on system capacity.
- **Cache invalidation** — Removing or updating stale cached data when the source changes.
- **Cold cache** — A cache with no data (after restart or failure). Causes a spike of DB load as entries are populated.
