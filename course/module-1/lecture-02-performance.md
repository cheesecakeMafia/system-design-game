# Lecture 2: Performance, Scalability & Estimation

> Module 1 — "The Request Journey" | Lecture 2 of 20

In Lecture 1 you traced a single request. Now imagine 100 million users sending requests simultaneously. How do you reason about a system's capacity without building it first? This lecture gives you the two most important meta-skills for system design: understanding performance trade-offs and doing back-of-the-envelope math. You will use both in every lecture, every boss battle, and every real interview from here on.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Performance vs scalability*
- *Latency vs throughput*
- *Appendix: Powers of two table*
- *Latency numbers every programmer should know*

Spend a few minutes memorizing the "Latency numbers" — or at least the order of magnitude for each operation. You'll need them for the estimation exercises.

---

## Concept Briefing

### Performance vs Scalability — They're Not the Same Thing

These two terms are often confused, but they describe different problems:

- **Performance** — How fast is the system for a single user? Measured in latency (response time) and throughput (operations per second).
- **Scalability** — How does performance change as load increases? A scalable system maintains acceptable performance as users, data, or traffic grow.

A system can be fast but not scalable (a single beefy server that handles 100 users instantly but collapses at 10,000). A system can be scalable but not fast (a distributed system that handles millions of users but every request takes 2 seconds).

**The goal is both: fast AND scalable.** But the approaches for improving each are different.

### A Simple Test

> If you have a performance problem, your system is slow for a single user.
> If you have a scalability problem, your system is fast for a single user but slow under load.

This distinction matters because the solutions are different. A performance problem might need algorithm optimization or caching. A scalability problem might need horizontal scaling or load balancing.

---

## Deep Dive

### Latency vs Throughput

**Latency** — The time it takes to complete a single operation. "How long does this request take?"

**Throughput** — The number of operations completed per unit of time. "How many requests can we handle per second?"

These are related but not the same. You can have:
- **Low latency, low throughput** — Each request is fast, but the system can only handle a few at a time (e.g., a single-threaded server)
- **High latency, high throughput** — Each request is slow, but the system handles many in parallel (e.g., batch processing, MapReduce)
- **Low latency, high throughput** — The goal. Requires good architecture.

**The trade-off:** Optimizing for one can hurt the other. Adding caching reduces latency but doesn't increase throughput if the bottleneck is elsewhere. Adding more servers increases throughput but may increase latency due to coordination overhead.

In most system design scenarios, **aim to maximize throughput while keeping latency within an acceptable bound.** That "acceptable bound" is usually defined by SLAs — more on this in Lecture 13.

### Latency Numbers Every Programmer Should Know

These numbers are approximate but the order of magnitude is what matters. Memorize the powers of 10:

| Operation | Latency | Relative Scale |
|-----------|---------|----------------|
| L1 cache reference | 0.5 ns | Instant |
| L2 cache reference | 7 ns | |
| Main memory reference | 100 ns | |
| SSD random read | 150 us (150,000 ns) | 1000x slower than RAM |
| HDD random read | 10 ms (10,000,000 ns) | 100x slower than SSD |
| Send 1 MB over 1 Gbps network | 10 ms | |
| Read 1 MB sequentially from SSD | 1 ms | |
| Read 1 MB sequentially from HDD | 20 ms | |
| Round trip within same datacenter | 0.5 ms | |
| Round trip CA to Netherlands | 150 ms | 300x datacenter RTT |

**Key takeaways for system design:**

1. **Memory is ~1000x faster than SSD, which is ~100x faster than HDD.** This is why caching (Lecture 9) is so powerful — moving data from disk to memory gives you orders-of-magnitude improvement.

2. **Network round trips dominate in distributed systems.** A cross-datacenter round trip (150ms) dwarfs everything else. This is why you minimize network hops, co-locate services that communicate frequently, and use CDNs (Lecture 3) to bring data closer to users.

3. **Sequential reads are MUCH faster than random reads.** This is why databases use B-trees (sequential disk access patterns) and why append-only logs (Kafka) are so fast.

### Vertical vs Horizontal Scaling

When your system can't handle the load, you have two options:

**Vertical Scaling (Scale Up)**
- Add more power to a single machine: more CPU, RAM, faster SSD
- Simpler — no distributed systems complexity
- Has a ceiling — you can't buy a server with 1TB of RAM and 1000 cores (well, not cheaply)
- Single point of failure

**Horizontal Scaling (Scale Out)**
- Add more machines
- No theoretical ceiling (add as many as you need)
- Requires distributed systems thinking: load balancing, data partitioning, consistency
- More complex but more resilient

| Factor | Vertical | Horizontal |
|--------|----------|------------|
| Complexity | Simple | Complex |
| Cost curve | Exponential (high-end hardware is disproportionately expensive) | Linear (each server costs the same) |
| Ceiling | Hard limit (biggest server available) | Soft limit (add more machines) |
| Failure | Single point | Redundant |
| Downtime to scale | Usually requires restart | Can add capacity live |

**The real world:** Most systems start vertical (it's simpler) and move to horizontal when they hit the ceiling or need redundancy. Almost every system design interview answer involves horizontal scaling at some point.

### Amdahl's Law — Why Parallelism Has Limits

Amdahl's Law tells you the theoretical speedup from parallelizing a task:

```
Speedup = 1 / ((1 - P) + P/N)

P = fraction of the task that can be parallelized
N = number of parallel processors/workers
```

**Example:** If 90% of your workload can be parallelized:
- 2 workers: 1 / (0.1 + 0.9/2) = **1.82x** speedup
- 10 workers: 1 / (0.1 + 0.9/10) = **5.26x** speedup
- 100 workers: 1 / (0.1 + 0.9/100) = **9.17x** speedup
- 1000 workers: 1 / (0.1 + 0.9/1000) = **9.91x** speedup

Even with infinite workers, you can never exceed **10x** because 10% of the work is inherently sequential.

**Why this matters:** When someone in a design discussion says "just add more servers," Amdahl's Law reminds you to ask: "What fraction of the work is actually parallelizable?" Database writes with strong consistency, sequential workflows, and single-threaded bottlenecks all limit the benefit of horizontal scaling.

---

### Back-of-the-Envelope Estimation

This is the most practical skill in system design. In every interview and design discussion, you need to quickly estimate whether a design is feasible. "Can we store this in memory?" "How many servers do we need?" "Will this fit in a single database?"

#### Powers of Two — Your Mental Math Toolkit

| Power | Exact | Approximate | Name |
|-------|-------|-------------|------|
| 2^10 | 1,024 | ~1 Thousand | 1 KB |
| 2^20 | 1,048,576 | ~1 Million | 1 MB |
| 2^30 | 1,073,741,824 | ~1 Billion | 1 GB |
| 2^40 | ~1.1 Trillion | ~1 Trillion | 1 TB |
| 2^50 | ~1.1 Quadrillion | ~1 Quadrillion | 1 PB |

**Quick conversions to memorize:**
- 1 KB ≈ 1,000 bytes (use 10^3 for estimation)
- 1 MB ≈ 10^6 bytes
- 1 GB ≈ 10^9 bytes
- 1 TB ≈ 10^12 bytes

**Useful reference sizes:**
- A single ASCII character: 1 byte
- A tweet (280 chars): ~280 bytes (text only)
- A typical JSON API response: 1-10 KB
- A web page (HTML + CSS + JS): 2-5 MB
- A photo (compressed JPEG): 200 KB - 2 MB
- A minute of HD video: ~150 MB
- A typical relational database row: 100 bytes - 1 KB

#### The Estimation Framework

For any system, estimate these four things:

**1. QPS (Queries Per Second)**
```
Daily active users (DAU) × actions per user per day
─────────────────────────────────────────────────────
                  86,400 seconds/day

Peak QPS ≈ 2-5× average QPS (depends on usage patterns)
```

**2. Storage**
```
Data per action × actions per day × retention period
```

**3. Bandwidth**
```
QPS × average response size
```

**4. Memory (for caching)**
```
Apply the 80/20 rule: cache the top 20% of requests
Daily requests × average request size × 0.2
```

#### Practice Estimate: Twitter

Let's estimate Twitter's storage needs:

**Assumptions:**
- 300 million monthly active users, 50% are daily active = 150M DAU
- Each user posts 2 tweets per day on average
- Tweet: 280 chars ≈ 280 bytes text + 100 bytes metadata = ~400 bytes
- 10% of tweets include a photo (~200 KB average)
- 1% of tweets include a video (~2 MB average, just the reference/thumbnail)

**QPS:**
```
Write QPS = 150M × 2 / 86,400 ≈ 3,500 tweets/second
Read QPS  = assume 10:1 read:write ratio ≈ 35,000 reads/second
Peak      = 2× average ≈ 7,000 writes/sec, 70,000 reads/sec
```

**Storage per day:**
```
Text:   300M tweets × 400 bytes = 120 GB/day
Photos: 30M tweets × 200 KB    = 6 TB/day
Video:  3M tweets × 2 MB       = 6 TB/day
Total:  ~12 TB/day
```

**Storage per year:**
```
12 TB/day × 365 = ~4.4 PB/year
```

**Memory for caching (tweets served in last 24 hours):**
```
Reads per day: 35,000/sec × 86,400 = ~3 billion reads
Assuming top 20% of tweets get 80% of reads:
300M tweets × 0.2 × 400 bytes = ~24 GB (just text)
This fits comfortably in a single server's RAM.
```

This is the level of estimation you need. Not exact — order of magnitude. If your estimate is within 2-5x of reality, that's excellent. The point is to verify that your design is in the right ballpark.

#### Practice Estimate: Google Search

**Assumptions:**
- 8.5 billion searches per day (publicly known)
- Average query: 20 characters = 20 bytes
- Average results page: 1 MB (HTML + snippets + metadata)

**QPS:**
```
8.5B / 86,400 ≈ 100,000 QPS average
Peak ≈ 200,000-300,000 QPS
```

**Bandwidth:**
```
100,000 QPS × 1 MB = 100 GB/sec = 800 Gbps
```

This gives you a sense of Google's infrastructure needs. A single server with a 10 Gbps network card can serve roughly 10,000 searches per second — so Google needs at minimum tens of thousands of search servers, before accounting for redundancy and geographic distribution.

---

## Discussion Prompts

1. **A startup's single PostgreSQL database handles 500 QPS and they expect 10x growth in a year. Should they scale vertically (bigger database server) or horizontally (shard the database)?** What factors influence this decision? At what QPS would you switch strategies?

2. **You're told a system needs "99th percentile latency under 200ms." Why is the 99th percentile specified rather than the average?** What does this tell you about the distribution of request latencies?

3. **Your back-of-the-envelope estimate says you need 50TB of storage per year. Your manager says "storage is cheap, don't worry about it." Are they right?** When does storage become a real system design concern beyond just disk space?

---

## Field Ops: Server Survival

If you haven't played the Sandbox mode from Lecture 1's assignment yet, do that first.

Now pay attention to the **RPS meter** in the game. This is throughput — the number of requests hitting your infrastructure per second. Watch what happens:
- When RPS increases, which services slow down first?
- Is there a point where adding more of the same service stops helping? (That's Amdahl's Law in action.)
- What's the relationship between the Queue depth and the Compute latency?

You don't need to achieve any specific score yet. Just observe.

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. If a system is fast for one user but slows down as more users are added, this is a ______ problem, not a performance problem.

2. According to the latency numbers, an SSD random read is approximately ______ times slower than a main memory reference.

3. The estimation rule of thumb where 20% of items account for 80% of traffic (used for cache sizing) is called the ______ rule.

### Multiple Choice (4 points)

4. A workload is 80% parallelizable. According to Amdahl's Law, what is the maximum possible speedup with infinite workers?

   - a) 2x
   - b) 4x
   - c) 5x
   - d) 80x

5. You need to estimate QPS for a service with 10 million daily active users, where each user makes an average of 5 requests per day. What is the average QPS?

   - a) ~50 QPS
   - b) ~500 QPS
   - c) ~580 QPS
   - d) ~5,000 QPS

6. A system currently handles 1,000 QPS on a single database server. You need to support 50,000 QPS. Which approach is most appropriate?

   - a) Vertical scaling — buy a 50x more powerful server
   - b) Horizontal scaling — shard the database across multiple servers
   - c) Caching — put a cache in front of the database
   - d) It depends on the read/write ratio

7. Reading 1 MB sequentially from an SSD takes approximately 1ms. Reading 1 MB over a 1 Gbps network within the same datacenter takes approximately:

   - a) 0.1 ms
   - b) 1 ms
   - c) 10 ms
   - d) 100 ms

### Short Answer (3 points)

8. You're designing a photo-sharing app. Each photo is 2 MB on average. The app has 10 million users who each upload 3 photos per day. Estimate the daily storage requirement and the annual storage cost if cloud storage costs $0.02 per GB per month.

9. Explain a real-world scenario where vertical scaling is the better choice over horizontal scaling, even at significant load. What makes that scenario different?

10. A read-heavy system has a 100:1 read-to-write ratio. The database handles 1,000 writes/second. What is the total QPS (reads + writes)? If you add a cache with a 95% hit rate, how many reads actually reach the database?

<details>
<summary>Answer Key</summary>

1. **scalability**
2. **1,500x** (150 us / 100 ns = 1,500. Accept answers in the range of 1,000-2,000x since the exact numbers are approximate.)
3. **80/20** (or "Pareto principle")
4. **c) 5x** — Speedup = 1 / (1 - 0.8) = 1 / 0.2 = 5. The 20% sequential portion limits you to a 5x maximum speedup regardless of how many workers you add.
5. **c) ~580 QPS** — 10M × 5 / 86,400 = 578.7, approximately 580 QPS.
6. **d) It depends on the read/write ratio** — If the workload is 95% reads, adding a cache might handle 50,000 QPS without touching the database architecture. If it's write-heavy, sharding is needed. There's no single right answer without knowing the workload pattern. (Give yourself the point if you chose b or d and explained your reasoning.)
7. **c) 10 ms** — Sending 1 MB over 1 Gbps ≈ 8 Mbit / 1 Gbit = 8ms, plus network overhead puts it around 10ms. This is the same order of magnitude as an SSD read for the same data size — an important insight for distributed systems.
8. Daily storage: 10M users × 3 photos × 2 MB = 60 TB/day. Annual storage: 60 TB × 365 = 21.9 PB/year. Annual cost: 21,900 TB × 1,000 GB/TB × $0.02/GB/month × 12 months = $5.256M/year. That's over $5 million per year just for storage — so no, "storage is cheap" is not always true at scale.
9. A common scenario: a single Redis instance can handle 100,000+ operations/second. If your caching layer needs 80,000 ops/sec, a single vertically-scaled Redis instance (more RAM, faster CPU) is simpler and more cost-effective than a Redis cluster. Vertical scaling wins when: (a) the workload fits on one machine, (b) the application is hard to distribute (e.g., transactions with strong consistency), and (c) the operational complexity of clustering isn't justified.
10. Total QPS = 1,000 writes + 100,000 reads = 101,000 QPS. With a 95% cache hit rate, only 5% of reads reach the database: 100,000 × 0.05 = 5,000 reads/sec. The database now handles 1,000 writes + 5,000 reads = 6,000 QPS instead of 101,000 — a 94% reduction.

</details>

---

## Challenge Mission: "The Bottleneck Hunt"

### Scenario

You're given the architecture of a photo-sharing service with the following components and measured performance:

```
                         ┌──────────────┐
                         │   CDN        │
Users ──── DNS ────────► │  (images)    │──────► 90% of image reads
  │                      └──────────────┘
  │
  │        ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
  └──────► │ Load Balancer │──►│ App Server   │──►│ Database     │
           │ (L7)         │    │ (x3)         │    │ (single)     │
           │ 20,000 QPS   │    │ 2,000 QPS ea │    │ 5,000 QPS   │
           │ capacity      │    │ capacity     │    │ capacity     │
           └──────────────┘    └──────────────┘    └──────────────┘
                                      │
                                      ▼
                               ┌──────────────┐
                               │ Cache        │
                               │ (Redis)      │
                               │ 80% hit rate │
                               │ 50,000 QPS   │
                               │ capacity      │
                               └──────────────┘
```

**Current traffic:** 8,000 QPS (non-CDN requests)
**Growth projection:** 3x in the next 6 months → 24,000 QPS

### Your Task

**Part 1 — Estimation (show your work)**

The service has 20 million DAU. Each user:
- Views 30 images per day (90% served by CDN, 10% are cache misses that hit the app servers)
- Uploads 1 photo per day (2 MB average)
- Makes 5 non-image API calls per day (profile views, likes, comments)

Calculate:
1. Total image read QPS (before CDN)
2. Image reads reaching the app servers (after CDN)
3. Upload QPS
4. API call QPS
5. Total QPS hitting the load balancer
6. Daily and annual storage growth

**Part 2 — Bottleneck Analysis**

Using the capacities in the diagram and your QPS estimates:
1. Which component hits its capacity limit first as traffic grows to 24,000 QPS?
2. At what QPS does each component become saturated?
3. What is the order of bottlenecks from first to last?

**Part 3 — Solutions**

Propose three solutions to handle 24,000 QPS, ranked by cost-effectiveness:
1. Cheapest / simplest change
2. Medium investment
3. Significant architecture change

For each solution, estimate the new capacity it provides.

### Constraints

- Budget: you can add up to 5 more servers of any type
- The database cannot be sharded yet (that's a Module 2 topic)
- Redis cache hit rate can be improved to 90% with better cache keys

### Hints (use only if stuck)

<details>
<summary>Hint 1: The bottleneck</summary>
Calculate how many requests actually reach the database. Remember: the cache handles 80% of reads, so only 20% of read requests plus ALL write requests hit the database.
</details>

<details>
<summary>Hint 2: Cheapest solution</summary>
If the cache hit rate improves from 80% to 90%, how does that change the load on the database? Calculate the new QPS reaching the database.
</details>

<details>
<summary>Hint 3: App server math</summary>
3 app servers × 2,000 QPS each = 6,000 QPS capacity. At 8,000 QPS, you're already over capacity. But wait — are all 8,000 requests hitting the app servers, or are some served by the cache before reaching them? Trace the request flow carefully.
</details>

When you've completed all three parts, discuss your analysis with Claude. Pay attention to whether your Part 1 estimates are consistent with the "Current traffic: 8,000 QPS" number — if they're wildly different, revisit your assumptions.

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 1:

- **Latency** — Time to complete a single operation. Measured in ms or us.
- **Throughput** — Operations completed per unit time. Measured in QPS (queries per second) or RPS (requests per second).
- **QPS (Queries Per Second)** — Standard measure of system throughput.
- **Vertical scaling (scale up)** — Adding more resources to a single machine.
- **Horizontal scaling (scale out)** — Adding more machines to distribute load.
- **Amdahl's Law** — Maximum speedup from parallelization is limited by the sequential fraction of the workload.
- **Back-of-the-envelope estimation** — Quick, approximate calculations to verify a design's feasibility.
- **80/20 rule (Pareto principle)** — Roughly 20% of items account for 80% of traffic/usage. Used for cache sizing.
- **SLA (Service Level Agreement)** — Contractual performance guarantee (e.g., 99.9% uptime, p99 latency < 200ms).
