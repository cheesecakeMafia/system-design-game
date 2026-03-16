# Boss Battle 2: Design Twitter Timeline & Search

> Module 2 — "The Data Fortress" | Boss Battle

Module 2 is complete. You now understand databases, caching, and async processing — the three pillars of the data layer. Time to design a system that uses all three at massive scale.

---

## Module 2 Recap — 10 Key Concepts

1. **ACID** guarantees correctness in relational databases. Expensive in distributed systems. (L6)
2. **Master-slave replication** scales reads. Master handles writes, slaves serve reads. Replication lag causes stale reads. (L6)
3. **Sharding** distributes rows across multiple databases. Shard key choice is critical. (L6)
4. **Consistent hashing** minimizes data movement when nodes are added/removed. Virtual nodes ensure even distribution. (L6)
5. **NoSQL types** each solve specific problems: key-value (speed), document (flexibility), wide column (write throughput), graph (relationships). (L7)
6. **Polyglot persistence** — use different databases for different use cases. Don't force one DB to do everything. (L8)
7. **Denormalization** trades write complexity for read speed. Essential for sharded systems where joins are impossible. (L8)
8. **Cache-aside with LRU + TTL** is the default caching strategy. Cache hit rate has an outsized impact on capacity. (L9)
9. **Message queues** decouple producers from consumers. Enable async processing, absorb spikes, improve resilience. (L10)
10. **Idempotent consumers** with at-least-once delivery is the practical sweet spot for most systems. (L10)

---

## The Problem

Design **Twitter's core features:**
- **Home timeline:** A user sees tweets from people they follow, in reverse chronological order
- **User timeline:** A user's own tweets
- **Tweet creation:** Post a tweet (280 chars + optional media)
- **Search:** Find tweets by keyword

### Requirements

**Functional:**
- Users can follow other users
- Users can post tweets (text, up to 280 characters, optional photo/video)
- Home timeline shows recent tweets from followed users, reverse chronological
- User can search tweets by keyword
- Tweet visibility: real-time (appear in followers' timelines within 5 seconds)

**Non-functional:**
- 500 million monthly active users, 200 million daily active users
- 300 million tweets per day
- Average user follows 200 people
- Average user reads their timeline 50 times per day
- Timeline read:write ratio is approximately 300:1
- High availability — Twitter should always be reachable
- Eventual consistency is acceptable for timeline (a few seconds delay is fine)

---

## Estimation Exercise

**Calculate (show your work):**

```
1. Tweet write QPS:
   300M tweets/day ÷ 86,400 =  _______________

2. Timeline read QPS:
   200M DAU × 50 reads/day ÷ 86,400 = _______________

3. Fan-out: When a user with 1,000 followers tweets,
   how many timeline deliveries is that? _______________

4. Total fan-out writes per second:
   (tweet QPS) × (average followers) = _______________

5. Storage per day (text only):
   300M tweets × 280 bytes = _______________

6. Storage per day (with media — assume 10% have 200KB photos):
   _______________

7. Storage per year: _______________

8. Memory for caching timelines:
   If you cache the last 200 tweets for each active user's timeline:
   200M users × 200 tweets × (tweet_id + tweet reference) ≈ _______________
```

<details>
<summary>Estimation Reference Answers</summary>

1. **~3,500 QPS** (300M / 86,400)
2. **~115,000 QPS** (200M × 50 / 86,400). This is the critical number — timeline reads dominate.
3. **1,000 deliveries** for that single tweet
4. **~700,000 fan-out writes/sec** (3,500 tweets/sec × 200 avg followers). This is massive.
5. **~84 GB/day** (300M × 280 bytes)
6. **~6 TB/day** (30M photos × 200 KB = 6 TB). Media dominates storage.
7. **~2.2 PB/year** (6 TB × 365)
8. **~320 GB** (200M × 200 × 8 bytes per tweet reference). Fits in a moderate Redis cluster.

**Key insight:** The fan-out problem is the core challenge. 3,500 tweets/sec translates to 700,000 timeline writes/sec due to fan-out. This is a write amplification problem.

</details>

---

## Design Template

### Step 1: The Fan-Out Problem

This is the central design challenge of Twitter. When a user tweets, their 200 followers need to see it. Two approaches:

**Fan-out on Write (Push Model):**
When a user tweets, immediately write that tweet reference to all followers' timelines.
```
User A tweets → write to 200 followers' timeline caches → done
Read timeline: just read your pre-built timeline cache
```

**Fan-out on Read (Pull Model):**
When a user reads their timeline, fetch tweets from all followed users at read time.
```
User reads timeline → query all 200 followed users' tweets → merge & sort → return
Read: expensive (200 queries per timeline read)
```

**Your analysis:**
```
Which approach would you use? _______________
What's the trade-off? _______________
What about celebrities with 50 million followers? _______________
```

### Step 2: High-Level Architecture

Design your system architecture. Include all components.

```
[Sketch your architecture here]
```

For each component, explain its role:
```
Component 1: _______________  Purpose: _______________
Component 2: _______________  Purpose: _______________
(continue as needed)
```

### Step 3: Core Components Deep Dive

**Tweet Storage:**
```
What database? _______________
Schema: _______________
Sharding strategy: _______________
```

**Timeline Service:**
```
How are timelines built? _______________
Where are they stored? _______________
How are they updated when someone you follow tweets? _______________
```

**Search:**
```
How is search implemented? _______________
How do you index 300M tweets/day? _______________
How fresh are search results? _______________
```

**Media Storage:**
```
Where do photos/videos go? _______________
How are they served to readers? _______________
```

### Step 4: The Celebrity Problem

User @PopStar has 50 million followers. They tweet once. Your system must fan-out to 50 million timelines.

```
How do you handle this? _______________
Does your approach change for users with >1M followers? _______________
```

### Step 5: Scaling Considerations

```
Bottleneck 1: _______________
  Solution: _______________

Bottleneck 2: _______________
  Solution: _______________

Bottleneck 3: _______________
  Solution: _______________
```

---

## Reference Solution

After completing your design, compare with the reference:

**[Twitter Reference Solution](../../deps/system-design-primer/solutions/system_design/twitter/README.md)**

---

## Self-Assessment Rubric

| Section | Score | What I Missed |
|---------|-------|---------------|
| Estimation accuracy | /5 | |
| Fan-out approach (with celebrity handling) | /5 | |
| Data model and storage | /5 | |
| Timeline architecture | /5 | |
| Search design | /5 | |
| Caching strategy | /5 | |
| Async processing | /5 | |
| Scaling discussion | /5 | |
| **Total** | **/40** | |

**Scoring guide:**
- 35-40: Excellent — solid system design thinking
- 25-34: Good — review the areas you scored lowest
- 15-24: Fair — re-read the reference and focus on the fan-out problem
- Below 15: Review Module 2 lectures before continuing

Record your score in [progress.md](../progress.md).

---

## Supplementary Reading

**[Twitter: Timelines at Scale](https://www.infoq.com/presentations/Twitter-Timeline-Scalability)** — How Twitter actually solved the timeline problem. Pay attention to their hybrid fan-out approach.

**[Storing 250 Million Tweets a Day Using MySQL](http://highscalability.com/blog/2011/12/19/how-twitter-stores-250-million-tweets-a-day-using-mysql.html)** — Early Twitter storage decisions. Note how they sharded MySQL and why.

---

## Anki Flashcard Review

Review the [System Design flashcard deck](../../deps/system-design-primer/resources/flash_cards/) — focus on:
- Database concepts (replication, sharding, ACID, BASE)
- Caching patterns (cache-aside, write-through, eviction)
- Async processing (queues, back pressure, delivery guarantees)

---

## What's Next

You've completed Module 2: "The Data Fortress." You now understand databases, caching, and asynchronous processing — the data layer where most system design complexity lives.

Module 3: "The Distributed Mind" takes you into theory — CAP theorem, consistency patterns, availability, resilience, and communication protocols. These concepts explain *why* the trade-offs you've been making throughout Module 2 exist.

Proceed to [Module 3, Lecture 11: CAP Theorem — Deep Dive](../module-3/lecture-11-cap.md).
