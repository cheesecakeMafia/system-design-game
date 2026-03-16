# Lecture 20: Capstone — Patterns, Anti-Patterns & Decision Trees

> Module 4 — "The Architect's Trial" | Lecture 20 of 20

This is your last lecture. You've learned 19 lectures worth of concepts — now you need to organize them into a mental framework you can access under pressure. This lecture builds your personal "system design toolbox" with decision trees for the choices that come up in every design.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Real world architectures*
- *Company architectures*
- Browse 2-3 *Company engineering blogs* for companies that interest you

---

## Deep Dive

### Decision Trees

When you face a design decision, use these decision trees to guide your choice.

#### Database Selection

```
Need ACID transactions?
  ├── Yes → Need horizontal scaling beyond single server?
  │         ├── Yes → Sharded PostgreSQL (Citus) or CockroachDB
  │         └── No → PostgreSQL or MySQL
  └── No → What's the access pattern?
           ├── Key-value lookup → Redis or DynamoDB
           ├── Flexible schema, document queries → MongoDB
           ├── Time-series / high write throughput → Cassandra or TimescaleDB
           ├── Graph traversal (3+ hops) → Neo4j
           └── Full-text search → Elasticsearch
```

#### Caching Strategy

```
Is data read-heavy (>10:1 read:write)?
  ├── Yes → Cache-aside (lazy loading) with TTL
  │         └── Is thundering herd a concern?
  │             ├── Yes → Add locking or stale-while-revalidate
  │             └── No → Standard cache-aside
  └── No → Is write latency critical?
           ├── Yes → Write-behind (async flush to DB)
           └── No → Write-through (sync to cache + DB)
```

#### Communication Protocol

```
Who is the consumer?
  ├── Public (third-party developers, browsers)
  │   → REST with JSON (+ cursor pagination, rate limiting, API keys)
  ├── Internal services (your own microservices)
  │   → gRPC with Protocol Buffers
  └── Real-time (chat, gaming, live updates)
      ├── Bidirectional → WebSocket
      └── Server-to-client only → SSE
```

#### Consistency Level

```
What happens if a user sees stale data?
  ├── Money is lost or safety is compromised → Strong consistency (linearizable)
  ├── User sees their own action not reflected → Read-your-writes
  ├── Users see different data briefly → Eventual consistency
  └── Data is ephemeral (gaming, streaming) → Weak consistency
```

#### Scaling Strategy

```
What's the bottleneck?
  ├── Read throughput → Add read replicas, add caching layer
  ├── Write throughput → Shard the database, use async processing
  ├── Compute → Horizontal scaling (more app servers behind LB)
  ├── Network → CDN for static content, compression, protocol optimization
  └── Storage → Object storage for large files, archival for old data
```

### Anti-Patterns

Things that seem right but cause problems:

**1. Premature Optimization**
Building for 10M users when you have 1,000. The infrastructure overhead costs more than the scaling problem you don't have. Start simple, add complexity when measurements demand it.

**2. Over-Sharding**
Sharding a database that has 50GB of data and 1,000 QPS. A single PostgreSQL instance handles this trivially. Sharding adds: cross-shard query complexity, distributed transaction headaches, operational overhead. Shard when you've exhausted vertical scaling AND read replicas AND caching.

**3. Cache Stampede**
Caching everything with the same TTL. When the cache restarts, ALL entries expire simultaneously, crushing the database. Fix: jittered TTLs, stale-while-revalidate.

**4. Distributed Monolith**
15 microservices that must be deployed together, share a database, and call each other synchronously in chains. You have the complexity of microservices with none of the benefits. Either commit to proper microservices (independent deployment, own data) or go back to a monolith.

**5. Cargo Cult Architecture**
"Netflix uses Cassandra, so we should too." Netflix has 200M users and custom infrastructure. Your 10K-user app needs PostgreSQL and Redis. Choose technology based on YOUR requirements, not someone else's.

**6. Ignoring the Human Factor**
A system that requires 5 engineers to operate 24/7 is expensive even if the cloud costs are low. Operational complexity is a real cost. Managed services (RDS, ElastiCache, SQS) reduce this cost at the expense of flexibility.

### Trade-Off Matrices

Every system design decision involves trade-offs. Here are the key axes:

| Axis | Favoring Left | Favoring Right |
|------|--------------|----------------|
| **Consistency vs Availability** | Financial systems, inventory | Social feeds, recommendations |
| **Latency vs Throughput** | User-facing APIs | Batch processing, analytics |
| **Cost vs Reliability** | Side projects, MVPs | Production systems, SLA-bound |
| **Simplicity vs Flexibility** | Early-stage, small team | Large team, complex domain |
| **Managed vs Self-hosted** | Most cases (less ops) | Need full control, compliance |

### Building Your Mental Model

After 20 lectures, your system design thinking should follow this pattern:

1. **Understand the problem** — Requirements, scale, constraints
2. **Estimate** — Is this a small system or a massive one? This determines everything.
3. **Choose the right level of complexity** — Don't over-engineer. Match the solution to the scale.
4. **Design for failure** — Everything fails eventually. Plan for it.
5. **Articulate trade-offs** — Every choice has a cost. Be explicit about what you're gaining and losing.

---

## Course Retrospective

Take 15 minutes to reflect:

1. **What concept was hardest to grasp?** Go back and review that lecture.
2. **What concept changed how you think about software?** (For most people: estimation, CAP theorem, or caching)
3. **What would you design differently in systems you've worked on?** (Apply your new knowledge to real experience)
4. **Where are you still uncertain?** (Mark these as areas for continued learning)

Write your reflections in [progress.md](../progress.md) under "Notes & Aha Moments > Module 4."

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. Building a microservices architecture when you have 5 engineers and 1,000 users is an example of the ______ anti-pattern.

2. The pattern where 15 microservices must be deployed together and share a database, giving the worst of both architectures, is called a ______.

3. When choosing between managed services and self-hosted, most teams should favor ______ to reduce operational complexity.

### Multiple Choice (4 points)

4. A startup has 5,000 DAU, 100 QPS, and 10 GB of data. Which architecture is most appropriate?

   - a) PostgreSQL + Redis + nginx — simple and sufficient
   - b) Cassandra cluster + Kafka + Elasticsearch + Redis cluster
   - c) Microservices with 8 services, each with its own database
   - d) Serverless with DynamoDB, Lambda, and API Gateway

5. You need to choose a database for IoT sensor data: 1 million writes/second, queries by sensor_id + time range, 2-year retention. Best choice?

   - a) PostgreSQL
   - b) MongoDB
   - c) Cassandra or TimescaleDB
   - d) Neo4j

6. A user updates their profile and immediately views it. Which consistency level is needed?

   - a) Strong consistency across all replicas
   - b) Read-your-writes consistency
   - c) Eventual consistency with 5-second window
   - d) Weak consistency

7. Which anti-pattern does this describe: "We use Kafka because Netflix uses it, even though we only have 50 events per second"?

   - a) Premature optimization
   - b) Distributed monolith
   - c) Cargo cult architecture
   - d) Over-sharding

### Short Answer (3 points)

8. You're starting a new project. Create a decision checklist: what 5 questions would you answer before choosing ANY technology?

9. A team has a PostgreSQL database with 500 QPS and 20 GB of data. They want to "migrate to microservices for scalability." Argue against this decision using specific numbers.

10. Looking back at the entire course, describe the single most important system design principle you've learned and how it changes your approach to building software.

<details>
<summary>Answer Key</summary>

1. **premature optimization** (or "over-engineering")
2. **distributed monolith**
3. **managed services**
4. **a)** — At 100 QPS and 10 GB, a single PostgreSQL instance handles everything. Redis adds caching for hot data. nginx serves as reverse proxy. Total infrastructure cost: ~$50/month. The other options are orders of magnitude more complex than needed.
5. **c)** — Cassandra (or TimescaleDB) is designed for time-series data: high write throughput, range queries on timestamp, automatic data expiration. PostgreSQL (a) would struggle at 1M writes/sec. MongoDB (b) isn't optimized for time-series. Neo4j (d) is for graph data.
6. **b)** — Read-your-writes is exactly this scenario: the user who made the change must see it immediately. Other users can see the old profile for a few seconds (eventual consistency for them). Strong consistency (a) is overkill — other users don't need to see the update instantly.
7. **c)** — Cargo cult architecture: copying another company's technology choices without having their problems. Netflix uses Kafka because they process billions of events per day. At 50 events/sec, a simple message queue (or even a database table) is sufficient.
8. Five questions before choosing technology: (1) **What's the scale?** (QPS, data size, users) — This eliminates 80% of options. (2) **What's the access pattern?** (Read-heavy? Write-heavy? Key-value? Relational? Graph?) (3) **What consistency level is needed?** (Strong? Eventual? Read-your-writes?) (4) **What does the team know?** (A PostgreSQL expert with PostgreSQL is more productive than a PostgreSQL expert learning Cassandra.) (5) **What's the operational cost?** (Managed vs self-hosted? How many people to operate it?)
9. At 500 QPS and 20 GB, PostgreSQL is at approximately 5% of its capacity (a single instance handles 10,000+ QPS and TBs of data). "Scalability" isn't the problem. Migrating to microservices would: (a) require 3-6 months of engineering time (opportunity cost), (b) add distributed systems complexity (network failures, distributed transactions, eventual consistency bugs), (c) require new infrastructure (service discovery, message queues, distributed tracing, separate deployments), (d) increase operational overhead (monitoring 8 services instead of 1), (e) make debugging harder (a bug now spans multiple services and logs). If the team has organizational scaling problems (too many engineers in one codebase), microservices might help — but that's an organizational solution, not a technical one. At 500 QPS, the database isn't the bottleneck. Find the actual bottleneck first.
10. Open-ended. Strong answers reference: estimation before design (grounding decisions in numbers), trade-off thinking (every choice has a cost), or simplicity (the right amount of complexity is the minimum needed for the current scale).

</details>

---

## Challenge Mission: "The Pattern Library"

Build a personal cheat sheet / decision tree that you can reference in future designs and interviews.

### Your cheat sheet must cover:

1. **Database selection** — Decision tree with at least 5 branches
2. **Caching strategy** — When to use each of the 4 strategies
3. **Communication protocol** — REST vs gRPC vs WebSocket vs others
4. **Consistency level** — When to use each level (strong, read-your-writes, eventual, weak)
5. **Availability architecture** — How to achieve each level of nines

### Format

Write it as a markdown document that fits on 2-3 pages. Use tables, bullet points, and decision trees. Make it something you'd actually reference.

This is the most practical deliverable of the entire course — it's YOUR mental model, organized in YOUR way.

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 4:

- **Premature optimization** — Adding complexity for scale you don't have. Build for current needs, plan for growth.
- **Cargo cult architecture** — Copying technology choices from companies with different problems and scale.
- **Distributed monolith** — Microservices that are so coupled they must be deployed together.
- **Decision tree** — Structured approach to choosing between options based on requirements.
- **Trade-off articulation** — Explicitly stating both the benefit and cost of every design decision.
