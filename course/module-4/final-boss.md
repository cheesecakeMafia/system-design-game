# Final Boss: Original System Design

> Module 4 — "The Architect's Trial" | Final Boss

This is it. Everything you've learned across 20 lectures, 4 modules, and 3 boss battles comes together in one design under real interview conditions.

---

## Rules

1. **45-minute time box.** Set a timer. When it rings, stop — even mid-sentence.
2. **No reference material.** Don't look at lectures, the primer, or any notes. This tests what you've internalized.
3. **Use the 4-step framework** from Lecture 16.
4. **Write everything down.** Requirements, estimation, architecture, deep dive, scaling.
5. **After the timer:** Unlimited time to improve your design. Then compare.

---

## The Problem

Choose ONE (don't read the others until you've finished):

<details>
<summary>Option A: Design a Ride-Sharing Service (Uber/Lyft)</summary>

### Design a ride-sharing platform

**Core features:**
- Rider requests a ride from location A to location B
- System matches rider with the nearest available driver
- Real-time tracking of driver's location during the ride
- Automatic fare calculation based on distance and time
- Payment processing after ride completion

**Key challenges:**
- Real-time geolocation matching (finding nearest drivers)
- High-frequency location updates (drivers send GPS every 3-5 seconds)
- Surge pricing during high demand
- ETA calculation and route optimization

**Scale:** 50M riders, 5M drivers, 10M rides per day, 1M concurrent active rides at peak.
</details>

<details>
<summary>Option B: Design a Real-Time Collaborative Document Editor (Google Docs)</summary>

### Design a collaborative document editor

**Core features:**
- Multiple users edit the same document simultaneously
- Changes appear in real-time for all participants (< 500ms latency)
- Each user sees a cursor showing where others are editing
- Full version history with the ability to revert to any previous version
- Offline editing with sync when reconnected

**Key challenges:**
- Conflict resolution when two users edit the same paragraph simultaneously
- Operational transformation or CRDTs for real-time merge
- Version history storage and efficient diff computation
- Offline support and eventual sync

**Scale:** 500M documents, 50M daily active users, average 3 collaborators per document, 10,000 concurrent edits per second.
</details>

<details>
<summary>Option C: Design a Distributed Rate Limiter</summary>

### Design a distributed rate limiter

**Core features:**
- Rate limit API requests per user (e.g., 1,000 requests per minute per user)
- Support multiple rate limiting rules (per user, per IP, per endpoint)
- Work across multiple API server instances (distributed)
- Return proper 429 responses with Retry-After headers
- Dashboard for monitoring rate limit hits

**Key challenges:**
- Distributed counting (multiple servers must share state)
- Performance (the rate limiter is in the critical path of every request)
- Accuracy vs performance trade-off (exact counting vs approximate)
- Different time windows (per minute, per hour, per day)

**Scale:** 100,000 API clients, 500,000 requests per second aggregate, 50 API server instances, < 1ms added latency per request.
</details>

<details>
<summary>Option D: Design a URL Shortener with Analytics</summary>

### Design a URL shortener with detailed analytics

**Core features:**
- Shorten long URLs (e.g., `https://long-url.com/...` → `https://sho.rt/abc123`)
- Redirect short URLs to original URLs (fast, <50ms)
- Analytics: click count, geographic distribution, referrer, device type, time series
- Custom short URLs (vanity URLs)
- Expiration support

**Key challenges:**
- URL generation (short, unique, not guessable for private links)
- Redirect performance (this is the hot path — every click goes through it)
- Analytics data pipeline (recording every click without slowing down the redirect)
- Read-heavy workload (redirects >> URL creations by 100:1+)

**Scale:** 500M shortened URLs, 10 billion redirects per month, 100M new URLs per month, analytics queryable within 5 minutes of click.
</details>

---

## Your Design Space

### Step 1: Requirements & Constraints
```
Problem chosen: _______________

Functional requirements:
1. _______________
2. _______________
3. _______________

Non-functional requirements:
- Users/Scale: _______________
- Latency: _______________
- Availability: _______________
- Consistency: _______________
```

### Step 1.5: Estimation
```
Read QPS: _______________
Write QPS: _______________
Storage: _______________
Bandwidth: _______________
Cache sizing: _______________
```

### Step 2: High-Level Architecture
```
[Your architecture diagram — ASCII art or description]
```

### Step 3: Deep Dive
```
Component 1: _______________
[Detailed design]

Component 2: _______________
[Detailed design]
```

### Step 4: Scaling & Bottlenecks
```
Bottleneck 1: _______________
Solution: _______________

Bottleneck 2: _______________
Solution: _______________

What changes at 10x scale: _______________
```

---

## Post-Timer: Improve Your Design

Now take unlimited time. Review your design and:

1. **What did you miss?** Add the missing components.
2. **What would you change?** Now that you're not under pressure.
3. **What trade-offs did you not articulate?** Add them.
4. **How does your design handle failure?** Add resilience patterns.

---

## Self-Assessment Rubric

| Category | Timed Score | Improved Score | Notes |
|----------|-----------|----------------|-------|
| Requirements gathering | /5 | /5 | |
| Estimation (reasonable numbers) | /5 | /5 | |
| High-level design (correct components) | /5 | /5 | |
| Deep dive (trade-off awareness) | /5 | /5 | |
| Database/storage choices (justified) | /5 | /5 | |
| Caching strategy | /5 | /5 | |
| Scaling discussion | /5 | /5 | |
| Failure handling | /5 | /5 | |
| **Total** | **/40** | **/40** | |

Record both scores in [progress.md](../progress.md).

**Timed score interpretation:**
- 35-40: Interview-ready. You can walk into a system design interview with confidence.
- 25-34: Strong foundation. A few more practice rounds and you're there.
- 15-24: Good understanding but need to practice under time pressure. Redo the drill.
- Below 15: Review the modules where you scored lowest. The knowledge is there — you need to practice accessing it quickly.

---

## Post-Mortem

Compare your timed design to your improved design:

1. **What did you prioritize under pressure?** Was it the right thing?
2. **What did you miss?** Is it something you know but forgot, or a genuine gap?
3. **How did time pressure change your design?** Simpler? More hand-wavy?
4. **What would you study next?** Where are your remaining gaps?

---

## Final Server Survival Run

Open [Server Survival](../../deps/server-survival/index.html) one last time.

**Goal:** Document every placement decision and why.

Play a full Survival mode run. After, write up your architecture decisions as if explaining to a teammate:
- Why did you place each service where you did?
- What was your strategy for handling traffic spikes?
- How did your understanding change from your first blind play (before Lecture 1)?

Record this in [progress.md](../progress.md).

---

## Company Architecture Reading

**Pick 2 from the list below and read them:**

- [How Uber Scales Their Real-Time Market Platform](http://highscalability.com/blog/2015/9/14/how-uber-scales-their-real-time-market-platform.html)
- [The WhatsApp Architecture Facebook Bought for $19 Billion](http://highscalability.com/blog/2014/2/26/the-whatsapp-architecture-facebook-bought-for-19-billion.html)
- [Instagram Architecture: 14 Million Users, Terabytes of Photos](http://highscalability.com/blog/2011/12/6/instagram-architecture-14-million-users-terabytes-of-photos.html)

For each, identify:
1. Which patterns from this course do they use?
2. What surprised you about their architecture?
3. What would you do differently with what you know now?

---

## Course Complete

You've finished System Design Mastery.

**What you've covered:**
- 20 lectures across networking, data, distributed systems, and architecture
- 4 Boss Battles designing real systems (Pastebin, Twitter, Web Crawler)
- 1 Final Boss under real interview conditions
- 20 quizzes, 20+ challenge missions, 6 Server Survival runs
- Company architecture case studies (Netflix, Twitter, Google, Facebook)

**What to do next:**
1. Review your [progress tracker](../progress.md) — identify your weakest areas
2. Practice with more system design problems (use the framework from Lecture 16)
3. Review the [glossary](../glossary.md) — these are the terms you should be fluent in
4. Re-read the [System Design Primer](../../deps/system-design-primer/README.md) — you'll understand it at a much deeper level now
5. Play Server Survival one more time — notice how much more intentional your decisions are

Good luck with your interviews. You've put in the work.
