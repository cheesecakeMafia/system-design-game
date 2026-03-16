# Boss Battle 1: Design Pastebin.com

> Module 1 — "The Request Journey" | Boss Battle

You've completed Module 1. Time to put everything together. Design a Pastebin-like service from scratch, using the estimation skills and infrastructure knowledge from Lectures 1-5.

---

## Module 1 Recap — 10 Key Concepts

Before you start, make sure you can explain each of these. If any feel shaky, review the relevant lecture.

1. **DNS** resolves domain names to IPs. Caching with TTL reduces lookup latency. (L1)
2. **TCP** provides reliable, ordered delivery via the three-way handshake. Adds latency. (L1)
3. **HTTP** is the request/response protocol of the web. Status codes indicate outcomes. (L1)
4. **UDP** trades reliability for speed. Used when freshness > completeness. (L1)
5. **Latency vs throughput** — Latency is per-request time, throughput is requests per second. Optimize both. (L2)
6. **Back-of-the-envelope estimation** — Powers of two, QPS, storage, bandwidth. Always estimate before designing. (L2)
7. **CDNs** cache static content at edge locations close to users. Push vs pull trade-offs. (L3)
8. **Object storage** is for large files. Don't put blobs in your database. (L3)
9. **Load balancers** distribute traffic. L4 (fast, blind) vs L7 (smart, slower). Algorithms matter. (L4)
10. **Reverse proxies, monoliths, microservices** — the application layer. Start monolith, split with good reason. (L5)

---

## The Problem

Design a web service like **Pastebin.com** where users can:
- Paste text and get a unique short URL (e.g., `https://paste.example.com/abc123`)
- Anyone with the URL can view the paste
- Pastes can optionally expire after a set time
- Users can optionally set a paste as "private" (requires knowing the URL, not listed publicly)

### Requirements

**Functional:**
- Create a paste: user submits text → gets a unique URL
- Read a paste: user visits URL → sees the text
- Optional: paste expiration (1 hour, 1 day, 1 week, never)
- Optional: syntax highlighting for code
- No user accounts required (anonymous by default)

**Non-functional:**
- High availability — the service should always be reachable
- Low latency — reading a paste should feel instant (<200ms)
- Paste URLs should be short and not guessable (for "private" pastes)
- The system should handle the read-heavy workload (reads >> writes)

---

## Estimation Exercise

Before designing anything, estimate the system's requirements. Show your work.

**Assumptions to use:**
- 10 million monthly active users
- Each user creates 1 paste per month on average
- Each paste is read 10 times on average over its lifetime
- Average paste size: 10 KB
- 70% of pastes expire within 30 days
- Peak traffic is 3x average

**Calculate:**

```
1. Write QPS (paste creation):
   Your calculation: _______________

2. Read QPS (paste views):
   Your calculation: _______________

3. Peak read QPS:
   Your calculation: _______________

4. Storage per day:
   Your calculation: _______________

5. Storage per year (accounting for expiration):
   Your calculation: _______________

6. Bandwidth (reads):
   Your calculation: _______________

7. Memory for caching (if you cache the top 20% most-read pastes):
   Your calculation: _______________
```

<details>
<summary>Estimation Reference Answers</summary>

1. **Write QPS:** 10M pastes/month ÷ 30 days ÷ 86,400 sec ≈ **~4 QPS** (very low!)
2. **Read QPS:** 10M × 10 reads = 100M reads/month ÷ 30 ÷ 86,400 ≈ **~40 QPS** average
3. **Peak read QPS:** 40 × 3 = **~120 QPS** (still modest)
4. **Storage per day:** 10M/30 ≈ 333K pastes/day × 10 KB = **~3.3 GB/day**
5. **Storage per year:** 3.3 GB × 365 = ~1.2 TB raw. With 70% expiring in 30 days, long-term storage is ~30% of total ≈ **~360 GB of permanent pastes per year** + rolling ~100 GB of temporary pastes.
6. **Bandwidth (reads):** 40 QPS × 10 KB = **~400 KB/s** = ~3.2 Mbps. Even at peak: ~1.2 MB/s. Trivial.
7. **Cache:** 100M reads/month, top 20% = 20M reads. If those come from 2M unique pastes × 10 KB = **~20 GB** of cache. Fits easily in RAM on a single Redis instance.

**Key insight:** This is a very small-scale system! The design challenge isn't handling massive QPS — it's about reliability, URL generation, and clean architecture.

</details>

---

## Design Template

Work through each section. Write your answers, then compare with the reference solution.

### Step 1: Use Cases and Constraints

List the specific use cases you're designing for:
```
Use Case 1: _______________
Use Case 2: _______________
Use Case 3: _______________
Use Case 4: _______________
```

State your constraints (from the estimation):
```
Write QPS:   _______________
Read QPS:    _______________
Storage:     _______________
Key insight: _______________
```

### Step 2: High-Level Design

Draw (or describe) your system architecture. Include every component from DNS to database.

```
Your architecture diagram:

[Sketch it here — use ASCII art or describe the components and connections]
```

For each component, explain why it's there:
```
Component 1: _______________  Why: _______________
Component 2: _______________  Why: _______________
Component 3: _______________  Why: _______________
(continue as needed)
```

### Step 3: Core Component Deep Dive

**URL Generation:**
- How do you generate unique, short paste IDs? (e.g., `abc123`)
- How many characters? What character set?
- How do you avoid collisions?
- How do you make "private" paste URLs unguessable?

```
Your URL generation approach: _______________
Character set: _______________
ID length: _______________
Collision handling: _______________
Total unique IDs possible: _______________
```

**Data Model:**
- What database type would you use and why?
- What does the paste record look like?
- How do you handle expiration?

```
Database choice: _______________
Paste record fields: _______________
Expiration strategy: _______________
```

**Read Path:**
- A user visits `paste.example.com/abc123`. Trace the full request path.
- Where does caching help?

```
Read path: _______________
Caching strategy: _______________
```

**Write Path:**
- A user submits new text. Trace the full write path.
- What happens if the write fails?

```
Write path: _______________
Failure handling: _______________
```

### Step 4: Scaling Considerations

Even though the current scale is modest, describe how you'd handle 1000x growth:
- 4,000 write QPS, 40,000 read QPS
- 3.3 TB of new data per day

```
Scaling the read path: _______________
Scaling the write path: _______________
Scaling storage: _______________
What changes in the architecture: _______________
```

---

## Reference Solution

After completing your design, compare it with the reference solution from the System Design Primer:

**[Pastebin Reference Solution](../../deps/system-design-primer/solutions/system_design/pastebin/README.md)**

Read the full reference, then complete the self-assessment below.

---

## Self-Assessment Rubric

Rate yourself 1-5 for each section:

| Section | Score | What I Missed |
|---------|-------|---------------|
| Estimation accuracy (within 5x of reference) | /5 | |
| Use cases identified | /5 | |
| High-level design completeness | /5 | |
| URL generation approach | /5 | |
| Data model design | /5 | |
| Read/write path clarity | /5 | |
| Caching strategy | /5 | |
| Scaling discussion | /5 | |
| **Total** | **/40** | |

**Scoring guide:**
- 35-40: Excellent — ready for Module 2
- 25-34: Good — review the areas you scored lowest
- 15-24: Fair — re-read the reference solution and redo the sections you struggled with
- Below 15: Review Lectures 1-5 before continuing

Record your score in [progress.md](../progress.md).

---

## Supplementary Reading

After completing the Boss Battle, read this case study:

**[Twitter: Making Twitter 10000 Percent Faster](http://highscalability.com/scaling-twitter-making-twitter-10000-percent-faster)**

This article covers early-stage scaling decisions — the kind of thinking you just practiced. Note how many of the components (caching, load balancing, database optimization) map to what you designed for Pastebin.

---

## Company Architecture Reading: Netflix

**[Netflix: What Happens When You Press Play?](http://highscalability.com/blog/2017/12/11/netflix-what-happens-when-you-press-play.html)**

As you read, identify how Netflix uses every concept from Module 1:
- How does Netflix use DNS and CDNs?
- Where are their load balancers?
- Is Netflix a monolith or microservices? Why?
- How do their estimation numbers compare to Pastebin?

Write 2-3 "aha moments" from this reading in your [progress tracker](../progress.md).

---

## Anki Flashcard Review

If you imported the [System Design flashcard deck](../../deps/system-design-primer/resources/flash_cards/), now is a good time to review the cards you've seen so far. Focus on:
- Networking fundamentals (DNS, TCP, HTTP)
- CDN concepts
- Load balancing algorithms
- Scalability patterns

---

## What's Next

You've completed Module 1: "The Request Journey." You now understand how a request travels from the user's browser through DNS, CDN, load balancers, and the application layer to reach your code.

Module 2: "The Data Fortress" goes deeper — into the data layer where most system design complexity lives. You'll master databases, caching, and asynchronous processing.

Proceed to [Module 2, Lecture 6: RDBMS Deep Dive + Consistent Hashing](../module-2/lecture-06-rdbms.md).
