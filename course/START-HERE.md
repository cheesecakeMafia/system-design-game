# System Design Mastery

> An interactive, university-style course built on the [System Design Primer](../deps/system-design-primer/README.md) and [Server Survival](../deps/server-survival/index.html).

---

## Required Materials

1. **This course** — you're here
2. **[System Design Primer](../deps/system-design-primer/README.md)** — the main textbook (read assigned sections before each lecture)
3. **[Server Survival](../deps/server-survival/index.html)** — open in your browser to play

Optional: Import the [Anki flashcard decks](../deps/system-design-primer/resources/flash_cards/) for spaced repetition.

---

## Your Journey

```
  YOU ARE HERE
      |
      v
[Module 1] -----> [Module 2] -----> [Module 3] -----> [Module 4]
 "The Request      "The Data        "The Distributed   "The Architect's
  Journey"          Fortress"        Mind"               Trial"

 Lectures 1-5      Lectures 6-10    Lectures 11-15     Lectures 16-20
 + Boss Battle 1   + Boss Battle 2  + Boss Battle 3    + FINAL BOSS
```

---

## Module Map

### Module 1 — "The Request Journey"
*Follow a request from browser to server and back.*

| # | Lecture | Challenge Mission | Status |
|---|---------|-------------------|--------|
| 1 | [How the Internet Works](module-1/lecture-01-internet.md) | "Trace the Path" | [ ] |
| 2 | [Performance, Scalability & Estimation](module-1/lecture-02-performance.md) | "The Bottleneck Hunt" | [ ] |
| 3 | [CDNs & Object Storage](module-1/lecture-03-cdn.md) | "The Global Deploy" | [ ] |
| 4 | [Load Balancers](module-1/lecture-04-load-balancers.md) | "The Traffic Storm" | [ ] |
| 5 | [Reverse Proxy & App Layer](module-1/lecture-05-app-layer.md) | "The Monolith Splitter" | [ ] |
| **BB** | [**BOSS BATTLE 1: Design Pastebin**](module-1/boss-battle-1.md) | Full System Design | [ ] |

### Module 2 — "The Data Fortress"
*Master databases, caching, and async — where most complexity lives.*

| # | Lecture | Challenge Mission | Status |
|---|---------|-------------------|--------|
| 6 | [RDBMS + Consistent Hashing](module-2/lecture-06-rdbms.md) | "The Shard Puzzle" | [ ] |
| 7 | [NoSQL Deep Dive](module-2/lecture-07-nosql.md) | "The Right Tool" | [ ] |
| 8 | [SQL vs NoSQL + Tuning](module-2/lecture-08-sql-vs-nosql.md) | "The Query Optimizer" | [ ] |
| 9 | [Caching Strategies](module-2/lecture-09-caching.md) | "The Cache Conundrum" | [ ] |
| 10 | [Async & Queues](module-2/lecture-10-async.md) | "The Queue Commander" | [ ] |
| **BB** | [**BOSS BATTLE 2: Design Twitter**](module-2/boss-battle-2.md) | Full System Design | [ ] |

### Module 3 — "The Distributed Mind"
*Understand the theory governing distributed systems.*

| # | Lecture | Challenge Mission | Status |
|---|---------|-------------------|--------|
| 11 | [CAP Theorem](module-3/lecture-11-cap.md) | "The CAP Dilemma" | [ ] |
| 12 | [Consistency Patterns](module-3/lecture-12-consistency.md) | "The Consistency Spectrum" | [ ] |
| 13 | [Availability, Resilience & Observability](module-3/lecture-13-availability.md) | "The Uptime Contract" | [ ] |
| 14 | [Protocols & API Design](module-3/lecture-14-communication.md) | "The Protocol Picker" | [ ] |
| 15 | [Security Fundamentals](module-3/lecture-15-security.md) | "The Fortress" | [ ] |
| **BB** | [**BOSS BATTLE 3: Design Web Crawler**](module-3/boss-battle-3.md) | Full System Design | [ ] |

### Module 4 — "The Architect's Trial"
*Put it all together. Design real systems.*

| # | Lecture | Format | Status |
|---|---------|--------|--------|
| 16 | [Interview Framework](module-4/lecture-16-framework.md) | Lecture + Challenge | [ ] |
| 17 | [Design Mint.com](module-4/lecture-17-mint.md) | Guided Walkthrough | [ ] |
| 18 | [Design Social Graph](module-4/lecture-18-social-graph.md) | Peer Review | [ ] |
| 19 | [Sales Ranking + AWS](module-4/lecture-19-sales-rank-aws.md) | Time-Boxed Drill | [ ] |
| 20 | [Capstone: Patterns](module-4/lecture-20-capstone.md) | Decision Trees | [ ] |
| **FB** | [**FINAL BOSS**](module-4/final-boss.md) | 45-Min Design | [ ] |

---

## Server Survival Missions

*Play [Server Survival](../deps/server-survival/index.html) at key moments to reinforce concepts.*

| When | Mission | Success Criteria | Status |
|------|---------|-----------------|--------|
| Before Lecture 1 | Play Sandbox blind — 15 min | Just play and note what breaks | [ ] |
| After Lecture 4 | Survival: survive 2 min, budget > $200 | Focus on Firewall + LB | [ ] |
| After Lecture 9 | Survival: optimize cache effectiveness | Watch DB load drop with Cache | [ ] |
| After Lecture 10 | Survival: survive DDoS, <5% rep loss | Use Queue for burst absorption | [ ] |
| After Module 3 | Survival: survive 5+ minutes | Full architecture, all concepts | [ ] |
| After Module 4 | Final run: document all decisions | Write-up of why you placed each service | [ ] |

---

## How Each Lecture Works

Every lecture follows this flow:

```
0. PRE-READING         Read assigned primer sections
1. CONCEPT BRIEFING    Read the detailed explanation
2. DEEP DIVE           Study trade-offs and real-world examples
3. DISCUSSION          Answer open-ended questions (discuss with Claude)
4. FIELD OPS           Server Survival connection (when applicable)
5. KNOWLEDGE CHECK     3 fill-in-blank + 4 MCQ + 3 short answer = /10
6. CHALLENGE MISSION   Guided design problem — must complete to advance
```

**To start a lecture:** Read the Pre-Reading from the primer first. Then open the lecture file. When you hit the Discussion section, come back to Claude. When you hit the Quiz, answer in `progress.md`. When you hit the Challenge Mission, design your solution and discuss with Claude.

---

## Quick Reference

- [Full Curriculum](curriculum.md) — detailed curriculum with all topics
- [Progress Tracker](progress.md) — your scores and notes
- [Glossary](glossary.md) — key terms accumulated throughout the course
- [System Design Primer](../deps/system-design-primer/README.md) — main textbook
- [Server Survival](../deps/server-survival/index.html) — the game
