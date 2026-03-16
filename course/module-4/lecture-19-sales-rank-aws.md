# Lecture 19: Design Amazon Sales Ranking — Time-Boxed Drill

> Module 4 — "The Architect's Trial" | Lecture 19 of 20

**Format: Time-Boxed Drill.** This simulates interview pressure. You have 30 minutes to design a system solo, using the 4-step framework from Lecture 16. No hints during the timer.

This is your dress rehearsal for the Final Boss.

---

## References

After completing your design, compare with:
- [Sales Rank Reference Solution](../../deps/system-design-primer/solutions/system_design/sales_rank/README.md)
- [Scaling AWS Reference](../../deps/system-design-primer/solutions/system_design/scaling_aws/README.md)

---

## The Problem

Design Amazon's **Sales Ranking** system:
- Every product has a sales rank (e.g., "#1 Best Seller in Electronics")
- Rankings are computed per category (Electronics, Books, Clothing, etc.)
- Rankings update multiple times per day (not real-time, but "recent")
- Rankings are visible on every product page

### Constraints Given

- 100 million products across 10,000 categories
- 1 million orders per hour at peak
- Rank must reflect sales within the last 24-48 hours (weighted toward recent)
- Product pages serve 500,000 views per second
- Ranks must be consistent — two users viewing the same product at the same time should see the same rank

---

## Instructions

### Set a 30-minute timer. Start now.

**Time allocation:**
- Minutes 0-5: Requirements & estimation
- Minutes 5-8: Estimation calculations
- Minutes 8-18: High-level design
- Minutes 18-25: Deep dive on the ranking computation
- Minutes 25-30: Scaling discussion

### Write your design below.

**Step 1: Requirements & Estimation**
```
Questions I'd ask: _______________
Assumed answers: _______________

Calculations:
- Orders per second: _______________
- Read QPS (product pages): _______________
- Storage for order data: _______________
- Storage for rank data: _______________
```

**Step 2: High-Level Architecture**
```
[Your architecture diagram]
```

**Step 3: Deep Dive — Ranking Computation**
```
How do you compute sales rank? _______________
Batch or real-time? _______________
Data pipeline: _______________
How often do ranks update? _______________
How do you handle the time-weighted component? _______________
```

**Step 4: Scaling**
```
Bottleneck 1: _______________
Solution: _______________

Bottleneck 2: _______________
Solution: _______________
```

---

## Stop the timer. Now debrief.

### Post-Timer Debrief

Compare your design to the reference solution. Answer these questions:

1. **What did you prioritize?** Was it the right thing to focus on?
2. **What did you miss?** Would the interviewer have caught it?
3. **How did you allocate time?** Did you spend too long on any step?
4. **Did you estimate before designing?** Did your estimates change your design?

### Key Concepts You Should Have Covered

Check which you addressed:

- [ ] **Batch processing vs real-time** — Ranking is a batch computation, not real-time. Orders are collected, ranks are recomputed periodically.
- [ ] **MapReduce or similar** — Count sales per product per category in the time window, sort by count, assign ranks.
- [ ] **Time weighting** — Recent sales count more. Exponential decay or sliding time windows.
- [ ] **Precomputed ranks** — Rank results stored in a fast-access store (Redis, DynamoDB). Product pages read precomputed ranks, not computing live.
- [ ] **Read path separation** — 500K reads/sec is too much for the rank computation system. Serve from cache/precomputed store.
- [ ] **Category hierarchy** — A product can be in multiple categories (sub-categories). Rank computation per category.
- [ ] **Consistency** — Eventual consistency is fine (ranks are inherently approximate — they reflect a recent time window).
- [ ] **Scaling the write path** — 1M orders/hour → order events in Kafka → batch process → rank update.

Record your score and observations in [progress.md](../progress.md).
