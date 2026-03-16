# Lecture 17: Design Mint.com — Guided Walkthrough

> Module 4 — "The Architect's Trial" | Lecture 17 of 20

This is an interactive walkthrough. Unlike previous lectures, there's no concept briefing — you're designing from the start. Work through each section, write your answer, then check the guidance before moving to the next section.

---

## The Problem

Design a personal finance service like **Mint.com** that:
- Connects to users' bank accounts, credit cards, and investment accounts
- Aggregates all transactions into one view
- Categorizes spending (food, rent, entertainment, etc.)
- Provides monthly budget tracking and alerts
- Shows net worth across all accounts

### Reference Solution

After completing your design, compare with: [Mint Reference Solution](../../deps/system-design-primer/solutions/system_design/mint/README.md)

---

## Section 1: Requirements (Do this first)

Write down:
1. **Core features** (3-4 most important)
2. **Key questions** you'd ask an interviewer
3. **Your assumed answers** (use reasonable defaults)

```
Your core features:
1. _______________
2. _______________
3. _______________

Key questions & assumed answers:
- Users: _______________
- Update frequency: _______________
- Latency requirements: _______________
- Consistency: _______________
```

<details>
<summary>Guidance</summary>

Core features: (1) Account linking and transaction syncing, (2) Transaction categorization, (3) Budget tracking with alerts, (4) Dashboard showing spending and net worth.

Key assumptions: 10M users, 5 linked accounts per user average, transactions sync every 6 hours, dashboard loads in <2 seconds, eventual consistency is fine (bank data is already hours old).

The key insight: this is a **data aggregation** system, not a real-time trading system. The data is inherently stale (banks batch-process transactions). This relaxes many constraints.
</details>

---

## Section 2: Estimation

Calculate:
```
Total accounts: _______________
Transaction sync QPS: _______________
Average transactions per account per month: _______________
Storage per year: _______________
Dashboard read QPS: _______________
```

<details>
<summary>Guidance</summary>

Total accounts: 10M users × 5 accounts = 50M accounts.

Transaction sync: 50M accounts ÷ 6 hours ÷ 3600 sec ≈ 2,300 account syncs/sec. Each sync fetches ~10 new transactions → ~23,000 transactions ingested/sec.

Storage: 50M accounts × 50 transactions/month × 200 bytes/transaction = 500 GB/month = 6 TB/year. Modest.

Dashboard reads: 10M users × 2 views/day ÷ 86,400 ≈ 230 QPS. Very low.

Key insight: The write side (ingesting transactions from banks) is the bottleneck, not the read side.
</details>

---

## Section 3: High-Level Design

Draw your architecture. Include:
- How does the system connect to banks? (API? Scraping? Third-party service?)
- Where are transactions stored?
- How is categorization done?
- How is the dashboard served?

```
[Your architecture here]
```

<details>
<summary>Guidance</summary>

Key components:
1. **Bank Integration Service** — Uses a third-party aggregator (Plaid, Yodlee) to connect to banks. You don't build bank API integrations yourself.
2. **Transaction Ingestion Pipeline** — Scheduled jobs pull new transactions per account. Write to message queue → process → store.
3. **Transaction Store** — SQL database (transactions are structured, relational).
4. **Categorization Service** — ML model or rule-based engine that categorizes transactions.
5. **Budget Service** — Compares spending against user-defined budgets. Triggers alerts.
6. **Dashboard API** — Reads from precomputed summaries (not raw transactions).
7. **Notification Service** — Sends budget alerts via email/push.

The third-party bank aggregator (Plaid) is a critical design decision. Building your own bank integrations for 10,000+ financial institutions is a multi-year, compliance-heavy effort. Every real fintech uses an aggregator.
</details>

---

## Section 4: Deep Dive — Transaction Pipeline

Design the transaction ingestion pipeline in detail:

```
1. How do you schedule 50M account syncs across 6-hour windows?
2. What happens if a bank API is slow or unavailable?
3. How do you handle duplicate transactions?
4. How do you categorize transactions?
5. How do you compute monthly spending summaries?
```

<details>
<summary>Guidance</summary>

1. **Scheduling:** Distribute accounts across time. Use a queue-based scheduler: every hour, enqueue 1/6 of all accounts for sync. Workers pull from queue and sync. This spreads load evenly.

2. **Bank API failures:** Retry with exponential backoff. If a bank is consistently failing, mark the account as "sync pending" and try again next cycle. Alert the user only after 24+ hours of failure.

3. **Duplicate transactions:** Use the bank's transaction ID + account ID as a dedup key. Before inserting, check if this transaction already exists. Idempotent ingestion.

4. **Categorization:** Two approaches: (a) Rule-based: merchant name mapping ("Starbucks" → Food & Drink). Covers 80% of transactions. (b) ML model: for ambiguous merchants, use a classifier trained on user corrections. Users can override any category.

5. **Monthly summaries:** Don't compute on-the-fly (would require scanning all transactions). Use a **MapReduce-like batch job** or **incremental aggregation**: as each transaction is stored, update a running sum in a `monthly_summary` table. Dashboard reads from this precomputed table — fast.
</details>

---

## Section 5: Scaling & Trade-offs

```
1. What if you grow to 100M users (10x)?
2. What's the hardest part of this system to scale?
3. What would you monitor?
```

<details>
<summary>Guidance</summary>

1. At 100M users: 500M accounts, 23,000 → 230,000 transactions/sec ingestion. The database needs sharding (shard by user_id). The sync scheduler needs more workers. The categorization service needs horizontal scaling.

2. The hardest part: the bank integration layer. Third-party aggregators (Plaid) have rate limits. Each bank API has different quirks. Failures and inconsistencies in bank data are the #1 operational headache for fintech companies — not the system design itself.

3. Monitor: sync success rate per bank (detect bank API outages), categorization accuracy, transaction ingestion lag, dashboard response time, error rates in the sync pipeline.
</details>

---

## Self-Assessment

| Section | Did I cover it? | What I missed |
|---------|----------------|---------------|
| Third-party bank integration (Plaid) | Yes / No | |
| Queue-based sync scheduling | Yes / No | |
| Transaction dedup | Yes / No | |
| Categorization approach | Yes / No | |
| Precomputed summaries (not real-time) | Yes / No | |
| Budget alerts (async) | Yes / No | |
| Scaling discussion | Yes / No | |

Record your self-assessment in [progress.md](../progress.md).

---

## Supplementary Reading

**[Instagram: 14 Million Users, Terabytes of Photos](http://highscalability.com/blog/2011/12/6/instagram-architecture-14-million-users-terabytes-of-photos.html)**

Instagram's early architecture shows similar patterns: data pipeline → storage → precomputed feeds. Note how they kept things simple early on.
