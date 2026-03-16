# Lecture 16: The System Design Interview Framework

> Module 4 — "The Architect's Trial" | Lecture 16 of 20

You've learned the building blocks. Now you need a process for assembling them under pressure. This lecture gives you the 4-step framework for approaching any system design problem — the same framework used in Lectures 17-20 and in real interviews.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *How to approach a system design interview question* (all 4 steps)

---

## Deep Dive

### The 4-Step Framework

Every system design problem follows this structure:

```
Step 1: Requirements & Constraints (5 min)
Step 1.5: Back-of-the-Envelope Estimation (5 min)
Step 2: High-Level Design (10 min)
Step 3: Deep Dive into Core Components (15 min)
Step 4: Scaling & Bottlenecks (10 min)
```

Total: ~45 minutes. This matches the typical interview format.

### Step 1: Requirements & Constraints (5 minutes)

**The most important step.** A vague problem leads to a vague design. Ask questions to narrow the scope.

**Functional requirements** — What the system does:
- What are the core features? (Not ALL features — the 2-3 most important)
- Who are the users?
- What's the expected input and output?

**Non-functional requirements** — How the system behaves:
- How many users? How many requests per second?
- What's the latency requirement?
- Availability target? (99.9%? 99.99%?)
- Consistency requirement? (Strong? Eventual?)
- Read-heavy or write-heavy?

**Questions you MUST ask** (don't assume):
- "How many daily active users?"
- "What's the read-to-write ratio?"
- "Is eventual consistency acceptable, or do we need strong consistency?"
- "What's the expected data retention period?"
- "Are there any geographic requirements (multi-region)?"

**Common mistake:** Jumping straight to "I'll use Kafka and Redis and..." without understanding the problem. The interviewer is evaluating your ability to gather requirements, not your knowledge of tools.

### Step 1.5: Back-of-the-Envelope Estimation (5 minutes)

After requirements, estimate the system's scale. This grounds your design in reality.

**Always estimate:**
1. QPS (read and write separately)
2. Storage (per day, per year)
3. Bandwidth
4. Memory (for caching)

**Show your work.** The interviewer cares about your reasoning process, not the exact number.

### Step 2: High-Level Design (10 minutes)

Draw the system architecture. Include every major component and how they connect.

**Start with the data flow:**
1. How does data enter the system? (API endpoint, upload, event)
2. Where is data stored? (Database, cache, object storage)
3. How is data served to users? (API response, push notification, feed)

**Include:**
- Clients (web, mobile)
- Load balancer
- Application servers
- Databases (specify type)
- Cache layer
- Message queues (if async processing needed)
- CDN (if serving static content)
- Object storage (if handling files/media)

**Don't include:**
- Every microservice (keep it high-level first)
- Specific vendor names unless asked
- Monitoring/logging infrastructure (mention later if time permits)

### Step 3: Deep Dive into Core Components (15 minutes)

Pick the 2-3 most interesting or challenging components and design them in detail.

**The interviewer will often guide you:** "Tell me more about the database schema" or "How does the notification system work?"

**For each component, cover:**
- Data model (schema, key structures)
- API design (endpoints, request/response)
- Algorithm or strategy (e.g., fan-out approach, caching strategy)
- Trade-offs (why this approach vs alternatives)

**This is where your knowledge shines.** Use specific concepts:
- "I'd use cache-aside with a 5-minute TTL because..."
- "I'd shard by user_id using consistent hashing because..."
- "I'd use at-least-once delivery with idempotent consumers because..."

### Step 4: Scaling & Bottlenecks (10 minutes)

Now stress-test your design. What happens at 10x scale? 100x?

**Identify bottlenecks:**
- Which component hits its limit first?
- Where is the single point of failure?
- What happens if the database can't keep up?

**Propose solutions:**
- Horizontal scaling (more instances behind LB)
- Database read replicas or sharding
- Caching layers (reduce DB load)
- Async processing (move work out of the critical path)
- CDN (offload static content)

**Discuss trade-offs:**
- "Adding a cache improves read latency but introduces staleness..."
- "Sharding allows horizontal scaling but makes cross-shard queries expensive..."

### Time Management

| Step | Time | What Interviewers Evaluate |
|------|------|---------------------------|
| Requirements | 5 min | Can you ask the right questions? |
| Estimation | 5 min | Can you reason about scale quantitatively? |
| High-level design | 10 min | Can you identify the right components? |
| Deep dive | 15 min | Do you understand the trade-offs in detail? |
| Scaling | 10 min | Can you identify and address bottlenecks? |

**Total: 45 minutes.** If you spend 20 minutes on requirements, you won't have time for the deep dive. If you skip estimation, your design may be wrong at the stated scale.

### Common Mistakes

1. **Jumping to solutions** — Designing the database before understanding the requirements
2. **Over-engineering** — Adding Kafka, Redis, 5 microservices for a system that needs 100 QPS
3. **Ignoring constraints** — Designing for 1M QPS when the problem says 1,000 DAU
4. **Not estimating** — "I'll just use a big database" instead of checking if the data fits
5. **Only happy path** — Never mentioning what happens when things fail
6. **Naming tools without explaining why** — "I'll use Cassandra" is worse than "I need high write throughput and eventual consistency is acceptable, so I'd consider Cassandra"

### Communication

System design interviews are collaborative conversations, not exams.

- **Think out loud** — "I'm considering two approaches: A does X, B does Y. A is simpler but doesn't handle Z. I'll go with B because..."
- **Acknowledge trade-offs** — "This adds latency but improves consistency"
- **Be honest about uncertainty** — "I'm not sure about the exact number, but the order of magnitude is..."
- **Check in with the interviewer** — "Does this level of detail make sense, or should I go deeper on any component?"

---

## Discussion Prompts

1. **An interviewer asks you to "design YouTube." How do you narrow this massive problem into something you can design in 45 minutes?** What 2-3 core features would you focus on, and what would you explicitly scope out?

2. **You're 20 minutes into a design and realize your initial assumption about the read-write ratio was wrong (you assumed read-heavy, but it's actually write-heavy). How do you recover?** Is it better to start over or adapt?

3. **Two candidates design the same system. Candidate A uses 8 technologies and discusses each briefly. Candidate B uses 3 technologies and discusses each in depth. Who makes a better impression?** Why?

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. The first step in the system design framework is gathering ______ — both functional (what it does) and non-functional (how it behaves).

2. Back-of-the-envelope estimation should happen ______ drawing the high-level design, so the design is grounded in the actual scale.

3. The most common system design interview mistake is ______ — proposing solutions before understanding the problem.

### Multiple Choice (4 points)

4. An interviewer asks: "Design a notification system." What should you do first?

   - a) Draw a diagram with Kafka, Redis, and push notification servers
   - b) Ask clarifying questions about scale, notification types, and latency requirements
   - c) Estimate the storage needed for notifications
   - d) Discuss the trade-offs between push and pull models

5. Your estimation shows the system needs 500 QPS and 50 GB of storage. Which architecture is most appropriate?

   - a) 10 microservices with Kafka, Redis cluster, and Cassandra
   - b) A single application server with PostgreSQL and a Redis cache
   - c) A distributed system with sharding across 5 database nodes
   - d) A serverless architecture with Lambda and DynamoDB

6. You're in Step 3 (deep dive) and the interviewer asks: "How would you handle 10x more traffic?" You should:

   - a) Say "I'll add more servers" and move on
   - b) Identify the specific bottleneck (DB? cache? network?) and propose a targeted solution
   - c) Redesign the entire system from scratch for the higher load
   - d) Say you'd need to do more research

7. Which statement demonstrates the best trade-off communication?

   - a) "I'll use Redis because it's fast"
   - b) "I'll use Redis for caching because we need sub-millisecond reads, but this means cached data can be up to 60 seconds stale"
   - c) "I'll use the best caching solution available"
   - d) "I'll use Redis, Memcached, and Varnish for maximum performance"

### Short Answer (3 points)

8. You have 45 minutes and the problem is "Design Uber." Write down your time allocation and the 2-3 core features you'd focus on. What would you explicitly scope out?

9. Your estimation shows 10,000 QPS and 1 TB of data. The interviewer says "Assume it needs to work in 3 regions (US, EU, Asia)." How does multi-region change your design? List 3 specific things that become harder.

10. Describe what "thinking out loud" looks like in practice. Give an example of a design decision where you'd verbalize your reasoning process.

<details>
<summary>Answer Key</summary>

1. **requirements**
2. **before**
3. **jumping to solutions** (or "premature solutioning")
4. **b)** — Always start with clarifying questions. "What types of notifications? (push, email, SMS, in-app?) How many users? What's the latency requirement? Is ordering important?" Without this, you might design for the wrong problem.
5. **b)** — 500 QPS and 50 GB is modest. A single PostgreSQL instance can handle 10,000+ QPS. A Redis cache in front of it is standard. This doesn't need microservices, Kafka, or sharding. Over-engineering for small scale is a common interview mistake.
6. **b)** — Identify the specific bottleneck. "At 10x, the database read QPS goes from 500 to 5,000. PostgreSQL handles this fine with a read replica. If we grow to 50,000, I'd add a caching layer with Redis." Targeted solutions based on identified bottlenecks demonstrate deeper understanding than generic "add more servers."
7. **b)** — This shows three things: (1) the choice (Redis), (2) the reason (sub-millisecond reads), and (3) the trade-off (staleness). This is what interviewers want — not just tool names, but justified decisions with acknowledged trade-offs.
8. Time allocation: Requirements (5 min), Estimation (5 min), High-level design (10 min), Deep dive (15 min), Scaling (10 min). Core features: (1) Real-time ride matching (rider → nearest driver), (2) Location tracking (driver positions updated continuously), (3) Trip management (request → match → ride → payment). Scope out: driver onboarding, payment processing details, rider rating system, fare estimation algorithm, surge pricing, admin tools. Focus on the real-time data flow — that's where the interesting system design lives.
9. Multi-region changes: (1) **Data replication across regions** — Do you replicate all data or partition by geography? Cross-region replication adds 100-200ms latency. Need to decide: strong consistency (slow writes) or eventual (stale reads). (2) **User-to-region routing** — How do you route a user to the nearest region? GeoDNS or anycast. What about users who travel? (3) **Conflict resolution** — If the same data is written in two regions simultaneously (master-master), how do you resolve conflicts? LWW? CRDTs? Application-level? All three increase architectural complexity significantly.
10. Example: "For the database, I'm choosing between PostgreSQL and Cassandra. The workload is 80% reads, 20% writes. At 10,000 QPS, PostgreSQL with a read replica handles this fine. Cassandra would give us easier horizontal scaling, but we don't need it yet, and we'd lose SQL joins for the analytics queries the product team needs. I'll go with PostgreSQL and plan for Cassandra or sharding if we hit 100K QPS. Does that reasoning make sense?" This demonstrates: weighing alternatives, connecting the choice to requirements, acknowledging future considerations, and checking in with the interviewer.

</details>

---

## Challenge Mission: "The Framework Drill"

### Scenario

**Surprise problem:** Design a notification system.

You have **30 minutes**. Set a timer. Do not look at any reference material.

**Rules:**
1. Spend the first 5 minutes on requirements (write down the questions you'd ask)
2. Spend 3 minutes on estimation
3. Spend 10 minutes on high-level design
4. Spend 7 minutes on deep dive (pick the most interesting component)
5. Spend 5 minutes on scaling

**What to submit:**
- Your list of clarifying questions (and your assumed answers)
- Your estimation calculations
- Your architecture diagram (ASCII art or description)
- Your deep dive on one component
- Your scaling discussion

**After the timer:** Discuss your design with Claude. Focus on:
- Did you spend time correctly across the 4 steps?
- Did you identify the core challenge of a notification system?
- What did you miss under time pressure?

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 4:

- **System design framework** — 4-step approach: (1) Requirements, (1.5) Estimation, (2) High-level design, (3) Deep dive, (4) Scaling.
- **Functional requirements** — What the system does (features, use cases).
- **Non-functional requirements** — How the system behaves (latency, availability, consistency, scale).
- **Trade-off articulation** — Explicitly stating both the benefit and cost of a design decision. Essential in interviews.
