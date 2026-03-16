# Boss Battle 3: Design a Web Crawler at Scale

> Module 3 — "The Distributed Mind" | Boss Battle

Module 3 is complete. You now understand the theoretical foundations: CAP, consistency, availability, resilience, protocols, and security. Time to design a system where ALL of these concepts matter simultaneously.

---

## Module 3 Recap — 10 Key Concepts

1. **CAP Theorem** — During a partition, choose Consistency or Availability. Network partitions are inevitable. (L11)
2. **PACELC** — Even without partitions, there's a Latency vs Consistency trade-off. (L11)
3. **Consistency spectrum** — From linearizability (expensive, correct) to eventual (cheap, may be stale). (L12)
4. **Read-your-writes** — The most important consistency level for web apps. Users must see their own changes. (L12)
5. **Availability nines** — 99.99% = 52 min downtime/year. Serial components reduce availability; parallel components improve it. (L13)
6. **Circuit breaker + retry + bulkhead** — Resilience patterns that prevent cascading failures. (L13)
7. **Observability** — Metrics (RED/USE), logs, traces. Alert on symptoms, not causes. (L13)
8. **gRPC vs REST** — gRPC for internal services (fast, typed); REST for public APIs (readable, universal). (L14)
9. **Pagination, rate limiting, idempotency** — The three API patterns every production system needs. (L14)
10. **Security layers** — AuthN, AuthZ, rate limiting, encryption, zero trust. Never trust user input. (L15)

---

## The Problem

Design a **web crawler** that crawls the entire web and builds a searchable index.

### Requirements

**Functional:**
- Crawl web pages starting from a seed list of URLs
- Follow links on each page to discover new URLs
- Store the content of each page
- Avoid crawling the same page twice
- Respect `robots.txt` (politeness)
- Build an inverted index for keyword search

**Non-functional:**
- Crawl 1 billion pages per month (~400 pages/second continuously)
- Store crawled content for at least 1 year
- Handle pages in multiple languages
- Prioritize important/popular pages
- Detect and handle duplicate content
- Operate continuously — the web is always changing

---

## Estimation Exercise

**Calculate:**

```
1. Pages per second:
   1B pages / 30 days / 86,400 sec = _______________

2. Average page size (HTML): ~100 KB
   Storage per month: _______________

3. Storage per year: _______________

4. Bandwidth (download):
   Pages/sec × 100 KB = _______________

5. URL frontier size (URLs discovered but not yet crawled):
   If each page has 50 links on average, and you've crawled 100M pages:
   Potential URLs discovered: _______________
   After dedup: estimate _______________

6. Inverted index size:
   If each page has ~500 unique words, and you index 1B pages:
   Total word-page mappings: _______________
```

<details>
<summary>Estimation Reference Answers</summary>

1. **~386 pages/sec** (1B / 30 / 86,400). Round to ~400/sec.
2. **~100 TB/month** (1B × 100 KB)
3. **~1.2 PB/year**
4. **~40 MB/sec = 320 Mbps** (400 pages/sec × 100 KB). Surprisingly modest — a few servers' bandwidth.
5. **5 billion URLs discovered** (100M × 50). After dedup: ~1-2 billion unique URLs (lots of overlap). Storing just URLs: 2B × 100 bytes = ~200 GB.
6. **500 billion word-page mappings**. If each mapping is ~20 bytes (word_id + page_id): ~10 TB. With compression: ~2-5 TB. Manageable on a distributed storage system.

</details>

---

## Design Template

### Step 1: High-Level Architecture

```
[Design your architecture with these components:]

1. URL Frontier (queue of URLs to crawl)
2. Fetcher (downloads pages)
3. Parser (extracts links and content)
4. Deduplication (avoid crawling same page twice)
5. Content Store (store raw HTML)
6. Indexer (build inverted index)
7. Scheduler (prioritize which URLs to crawl next)
```

### Step 2: URL Frontier Design

The frontier is the queue of URLs waiting to be crawled.

```
How do you prioritize URLs? _______________
How do you enforce politeness (don't DDoS websites)? _______________
How do you handle the frontier growing faster than you can crawl? _______________
```

### Step 3: Deduplication

How do you avoid crawling the same page twice?

```
URL deduplication strategy: _______________
Content deduplication strategy (same content at different URLs): _______________
Data structure for checking if a URL has been seen: _______________
```

**Hint:** A Bloom filter is a probabilistic data structure that can tell you "definitely not seen" or "probably seen" using very little memory. Perfect for URL dedup.

### Step 4: Politeness and robots.txt

```
How do you rate-limit requests to each domain? _______________
How do you cache robots.txt? _______________
What if a site's robots.txt blocks your crawler? _______________
```

### Step 5: Fault Tolerance

```
What happens when a fetcher crashes mid-crawl? _______________
What if the content store is temporarily unavailable? _______________
How do you handle pages that return errors (404, 500, timeout)? _______________
```

### Step 6: Scaling

```
How do you distribute crawling across multiple machines? _______________
How do you coordinate deduplication across crawlers? _______________
What's the bottleneck — CPU, network, storage, or something else? _______________
```

---

## Reference Solution

After completing your design, compare with the reference:

**[Web Crawler Reference Solution](../../deps/system-design-primer/solutions/system_design/web_crawler/README.md)**

---

## Self-Assessment Rubric

| Section | Score | What I Missed |
|---------|-------|---------------|
| Estimation accuracy | /5 | |
| URL frontier design | /5 | |
| Fetcher architecture | /5 | |
| Deduplication strategy (URL + content) | /5 | |
| Politeness / robots.txt | /5 | |
| Content storage | /5 | |
| Fault tolerance | /5 | |
| Scaling and distribution | /5 | |
| **Total** | **/40** | |

Record your score in [progress.md](../progress.md).

---

## Supplementary Reading

**[Google Architecture](http://highscalability.com/google-architecture)**

Google's original web crawler was the foundation of the company. Note the scale of their infrastructure and how many of the concepts from Module 3 (distributed systems, fault tolerance, consistency) are visible in their architecture.

---

## Anki Flashcard Review

Review the [System Design flashcard deck](../../deps/system-design-primer/resources/flash_cards/). Focus on:
- CAP theorem and consistency patterns
- Availability and resilience patterns
- Communication protocols
- Security fundamentals

---

## What's Next

You've completed Module 3: "The Distributed Mind." You now understand the theoretical foundations governing distributed systems — why trade-offs exist, how to reason about consistency and availability, and how to keep systems resilient.

Module 4: "The Architect's Trial" puts it all together. You'll learn the interview framework, practice with varied formats (guided walkthrough, peer review, time-boxed drill), and face the Final Boss.

Proceed to [Module 4, Lecture 16: The System Design Interview Framework](../module-4/lecture-16-framework.md).
