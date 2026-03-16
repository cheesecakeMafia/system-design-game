# System Design Mastery — Project Plan

> A university-style interactive course built on top of the [System Design Primer](../deps/system-design-primer/README.md) and [Server Survival](../deps/server-survival/index.html).

---

## Course Parameters

| Parameter | Value |
|-----------|-------|
| **Student profile** | Intermediate — understands DB basics (SQL/NoSQL, indexing, ACID) and scaling at a high level (LBs, caches). Gaps in networking foundations and distributed systems theory. |
| **Goal** | Deep understanding of system design — no deadline, genuine curiosity |
| **Pace** | Intensive — 10+ hours/week, ~3-4 weeks |
| **Gamification** | Challenge Missions (guided "boss battle" design problems per topic) |
| **Lecture format** | Pre-Reading → Concept Briefing → Deep Dive → Discussion → Server Survival → Quiz → Challenge Mission |
| **Assessment** | Standardized quizzes (3 fill-in-blank + 4 MCQ + 3 short answer = /10) + 4 Boss Battle assignments at 25% intervals |
| **Materials location** | `course/` (this directory) |

---

## Module Overview

```
MODULE 1: "The Request Journey"     Lectures 1-5    Networking → Traffic Management
MODULE 2: "The Data Fortress"       Lectures 6-10   Data Layer → Performance
MODULE 3: "The Distributed Mind"    Lectures 11-15  Distributed Theory → Protocols → Resilience
MODULE 4: "The Architect's Trial"   Lectures 16-20  Interview Prep → Full Designs
```

---

## Standardized Assessment Format

Every lecture quiz follows this structure:

| Type | Count | Points Each | Total |
|------|-------|-------------|-------|
| Fill-in-the-blank | 3 | 1 | 3 |
| Multiple choice | 4 | 1 | 4 |
| Short answer (2-3 sentences) | 3 | 1 | 3 |
| **Total** | **10** | | **/10** |

Every Boss Battle includes:
1. **Estimation exercise** — back-of-the-envelope calculations for the system
2. **Guided design template** — structured sections to fill in
3. **Module Recap** — 10-point summary of key concepts from the module
4. **Self-assessment rubric** — compare against reference solution
5. **Company architecture reading** — a real-world case study that uses similar patterns

---

## Supplementary Materials

### Anki Flashcard Decks
Integrated from `../deps/system-design-primer/resources/flash_cards/`:
- Review **System Design** deck after each module
- Review **System Design Exercises** deck before Boss Battles
- Review **OO Design** deck alongside Module 2 OOD exercises

### OOD Notebook Exercises
Integrated from `../deps/system-design-primer/solutions/object_oriented_design/`:
- **LRU Cache** (`../deps/system-design-primer/solutions/object_oriented_design/lru_cache/lru_cache.ipynb`) — paired with Lecture 9 (Caching)
- **Hash Map** (`../deps/system-design-primer/solutions/object_oriented_design/hash_table/hash_map.ipynb`) — paired with Lecture 6 (consistent hashing section)
- **Other notebooks** (call center, parking lot, deck of cards, online chat) — optional enrichment

### Course Glossary
- **File:** `course/glossary.md`
- Accumulates key terms as the course progresses
- Each lecture adds its new terms
- Quick reference during Boss Battles and Challenge Missions

---

## Detailed Lecture Plan

### MODULE 1 — "The Request Journey"

> **Theme:** Follow a request from the user's browser to the server and back. Understand every layer it passes through.

#### Lecture 1: How the Internet Works
- **File:** `module-1/lecture-01-internet.md`
- **Pre-Reading:** Primer sections — *Domain name system*, first half of *Communication* (TCP/UDP)
- **Topics:**
  - What happens when you type a URL and press Enter (full trace)
  - DNS resolution: recursive vs iterative, caching, TTL
  - TCP/IP stack: the 4-layer model, 3-way handshake, why it matters for system design
  - HTTP/HTTPS: request/response cycle, status codes, headers, keep-alive
  - UDP: when and why (streaming, DNS, gaming)
- **Server Survival tie-in:** "Internet" node in the game — all traffic enters here. What if DNS fails?
- **Challenge Mission — "Trace the Path":**
  - Given: A user in Tokyo loads `photos.example.com/album/42`
  - Task: Trace the full journey (DNS → TCP → HTTP → server → response), identifying every component. Use a guided template with blanks to fill.
  - Constraints provided, hints available

#### Lecture 2: Performance, Scalability & Estimation
- **File:** `module-1/lecture-02-performance.md`
- **Pre-Reading:** Primer sections — *Performance vs scalability*, *Latency vs throughput*, *Appendix: Powers of two table*, *Latency numbers every programmer should know*
- **Topics:**
  - Defining performance, scalability, latency, throughput precisely
  - Vertical vs horizontal scaling — when each makes sense
  - Latency numbers every programmer should know (with exercises)
  - Throughput: bandwidth vs application throughput
  - Amdahl's Law and why parallelism has limits
  - Real-world examples: why is X slow? (case studies)
  - **Back-of-the-envelope calculations** *(moved here from L15 — this is a meta-skill needed for all subsequent lectures)*
  - Powers of two: KB, MB, GB, TB — instant mental math
  - Estimation framework: QPS, storage, bandwidth, memory
  - Practice estimates: storage for 1B tweets, QPS for Google Search
- **Server Survival tie-in:** RPS meter in the game = throughput. Watch how latency increases as services approach capacity.
- **Challenge Mission — "The Bottleneck Hunt":**
  - Given: Architecture diagram with labeled throughputs and latencies + estimation problem
  - Task: (1) Estimate the system's total QPS and storage needs. (2) Identify the bottleneck. (3) Propose 3 solutions, rank by cost-effectiveness.
  - Guided with constraint framework

#### Lecture 3: CDNs & Object Storage
- **File:** `module-1/lecture-03-cdn.md`
- **Pre-Reading:** Primer sections — *Content delivery network*, *Push CDNs*, *Pull CDNs*
- **Topics:**
  - What CDNs actually do — edge servers, PoPs, origin servers
  - Push vs Pull CDNs: trade-offs, when to use each
  - CDN caching: TTL, cache invalidation, cache keys
  - CDN for dynamic content (edge computing)
  - Real CDNs: CloudFront, Cloudflare, Akamai — how they differ
  - Anti-patterns: when CDNs hurt
  - **Object/Blob Storage** *(new — needed for web crawler, video streaming, file uploads)*
  - S3, GCS, Azure Blob — what they are and how they differ from databases
  - When to use object storage vs database vs file system
- **Server Survival tie-in:** "Storage" service handles STATIC/UPLOAD traffic. A CDN would offload STATIC entirely, while object storage handles UPLOAD.
- **Challenge Mission — "The Global Deploy":**
  - Given: A video streaming startup going global (US → EU → Asia). Users upload videos (avg 500MB each, 10K uploads/day) and stream them (1B views/day).
  - Task: (1) Estimate storage and bandwidth needs. (2) Design CDN strategy — push or pull? (3) Where do uploads land? Object store architecture. (4) How do you handle cache invalidation for user-uploaded content?

#### Lecture 4: Load Balancers
- **File:** `module-1/lecture-04-load-balancers.md`
- **Pre-Reading:** Primer sections — *Load balancer*, *Active-passive*, *Active-active*, *Layer 4*, *Layer 7*, *Horizontal scaling*
- **Topics:**
  - Why load balancers exist — the single server problem
  - L4 (transport) vs L7 (application) load balancing — deep comparison
  - Algorithms: round robin, weighted, least connections, IP hash, consistent hashing (intro)
  - Active-passive vs active-active HA
  - Health checks and circuit breakers
  - Horizontal scaling: stateless services, session affinity
  - Real examples: nginx, HAProxy, AWS ALB/NLB
- **Server Survival tie-in:** Load Balancer service distributes traffic to Compute instances. Without it, one Compute node gets overwhelmed.
- **Challenge Mission — "The Traffic Storm":**
  - Given: Your e-commerce site gets 10x traffic on Black Friday (normal: 5K QPS → spike: 50K QPS)
  - Task: (1) Estimate how many backend instances you need. (2) Design LB layer — which algorithm? L4 or L7? (3) How many backend instances? (4) What about sticky sessions for shopping carts?

#### Lecture 5: Reverse Proxy + Application Layer + Microservices
- **File:** `module-1/lecture-05-app-layer.md`
- **Pre-Reading:** Primer sections — *Reverse proxy*, *Application layer*, *Microservices*, *Service discovery*
- **Topics:**
  - Reverse proxy vs forward proxy vs load balancer
  - What reverse proxies do: SSL termination, compression, caching, rate limiting
  - Monolith vs microservices — honest trade-offs (not just "microservices good")
  - Service discovery: client-side vs server-side, service registries
  - API Gateway pattern
  - Inter-service communication: sync vs async
- **Server Survival tie-in:** The Firewall + LB + Compute chain in the game mirrors a real reverse proxy → app server pipeline.
- **Challenge Mission — "The Monolith Splitter":**
  - Given: A monolithic e-commerce app (auth, catalog, orders, payments, notifications) serving 100K daily users
  - Task: (1) Decide which parts to split into services, justify boundaries. (2) Design service communication. (3) What stays monolithic and why?

#### BOSS BATTLE 1: Design Pastebin.com (or Bit.ly)
- **File:** `module-1/boss-battle-1.md`
- **Reference:** `../../deps/system-design-primer/solutions/system_design/pastebin/README.md`
- **Module 1 Recap:** 10-point summary of key concepts (DNS, HTTP, CDN, LB, reverse proxy, estimation)
- **Estimation exercise:** Calculate QPS, storage for 10M monthly users, read/write ratio
- **Format:**
  1. Problem statement with constraints (users, data volume, read/write ratio)
  2. Guided template: Use cases → Estimation → High-level design → Core components → Scaling
  3. Student fills in each section
  4. Compare with reference solution
  5. Self-assessment rubric (1-5 per section)
- **Concepts tested:** DNS, HTTP, hashing, databases, caching, load balancing, estimation
- **Supplementary reading:** [Twitter: Making Twitter 10000 percent faster](http://highscalability.com/scaling-twitter-making-twitter-10000-percent-faster) — early-stage scaling decisions

---

### MODULE 2 — "The Data Fortress"

> **Theme:** Master the data layer — where most system design complexity lives. Databases, caching, and async processing.

#### Lecture 6: RDBMS Deep Dive + Consistent Hashing
- **File:** `module-2/lecture-06-rdbms.md`
- **Pre-Reading:** Primer sections — *RDBMS*, *Master-slave replication*, *Master-master replication*, *Federation*, *Sharding*
- **OOD exercise:** Work through `../../deps/system-design-primer/solutions/object_oriented_design/hash_table/hash_map.ipynb` before this lecture
- **Topics:**
  - **CAP Theorem Primer** *(10-minute intro — the full deep dive is in Lecture 11, but you need this foundation now)*
    - The fundamental tension: consistency vs availability when networks partition
    - Why replication lag exists as a trade-off, not a bug
    - "We'll go deep in Module 3 — for now, hold this mental model"
  - RDBMS recap: ACID deep dive (what each letter really means in practice)
  - Master-slave replication: how it works, read replicas, replication lag
  - Master-master replication: conflict resolution, when to use
  - Federation (functional partitioning): splitting by function
  - Sharding: hash-based, range-based, directory-based
  - **Consistent Hashing — dedicated deep dive** *(critical missing topic)*
    - The ring visualization — how it works
    - Virtual nodes — why they exist
    - Adding/removing nodes — minimal redistribution
    - Applications: DB sharding, cache distribution, load balancing
    - Shard rebalancing — the hard problem nobody talks about
  - Real examples: MySQL replication, PostgreSQL partitioning, Vitess
- **Server Survival tie-in:** SQL DB service handles READ/WRITE/SEARCH. What if you could "shard" it into multiple DB instances?
- **Challenge Mission — "The Shard Puzzle":**
  - Given: User table with 500M rows, queries by user_id and by email. Hash ring with 5 nodes.
  - Task: (1) Choose sharding key — why? (2) Draw the consistent hash ring. (3) What happens when node 3 dies? (4) Handle cross-shard queries for email lookup. (5) Design resharding strategy when adding 2 nodes.

#### Lecture 7: NoSQL Deep Dive
- **File:** `module-2/lecture-07-nosql.md`
- **Pre-Reading:** Primer sections — *NoSQL*, *Key-value store*, *Document store*, *Wide column store*, *Graph Database*
- **Topics:**
  - Why NoSQL exists — what problems does it solve that SQL can't?
  - Key-value stores: Redis, DynamoDB — data model, use cases, limitations
  - Document stores: MongoDB, CouchDB — schema flexibility, querying
  - Wide column stores: Cassandra, HBase — column families, when to use
  - Graph databases: Neo4j — relationships, traversal, social graphs
  - BASE vs ACID — the real trade-off (now with CAP context from Lecture 6)
  - Anti-pattern: using NoSQL because it's "modern"
- **Challenge Mission — "The Right Tool":**
  - Given: 5 different applications (social feed, IoT sensor data, e-commerce catalog, fraud detection, session storage)
  - Task: Pick the right database type for each, justify with specific technical reasons. Include estimation of data volume for each.

#### Lecture 8: SQL vs NoSQL + Denormalization + SQL Tuning
- **File:** `module-2/lecture-08-sql-vs-nosql.md`
- **Pre-Reading:** Primer sections — *SQL or NoSQL*, *Denormalization*, *SQL tuning*
- **Topics:**
  - Decision framework: when SQL, when NoSQL, when both
  - Denormalization: why break normal forms? Read performance vs write complexity
  - SQL tuning: indexes (B-tree, hash, composite), EXPLAIN plans, query optimization
  - N+1 query problem and how to fix it
  - Connection pooling, prepared statements
  - Materialized views as a middle ground
- **Challenge Mission — "The Query Optimizer":**
  - Given: A slow dashboard query (provided SQL), table schema, EXPLAIN output
  - Task: Diagnose the problem, add indexes, consider denormalization, justify trade-offs

#### Lecture 9: Caching — All Strategies
- **File:** `module-2/lecture-09-caching.md`
- **Pre-Reading:** Primer sections — *Cache* (all subsections through *Refresh-ahead*)
- **OOD exercise:** Work through `../../deps/system-design-primer/solutions/object_oriented_design/lru_cache/lru_cache.ipynb` — implement LRU eviction before learning caching strategies
- **Topics:**
  - Where to cache: client, CDN, web server, application, database query level, object level
  - Cache-aside (lazy loading): how it works, thundering herd problem
  - Write-through: consistency guarantee, latency cost
  - Write-behind (write-back): performance gain, durability risk
  - Refresh-ahead: predictive caching
  - Cache eviction: LRU, LFU, TTL — when each makes sense
  - Cache invalidation — "the two hard problems in CS"
  - **Distributed caching with consistent hashing** *(connects back to Lecture 6)*
    - Which cache server holds which key?
    - What happens when a cache node dies?
  - Redis vs Memcached — real comparison
- **Server Survival tie-in:** Cache service reduces DB load for READ requests. Place it between Compute and SQL DB.
- **Supplementary reading:** [Scaling Memcached at Facebook](https://cs.uwaterloo.ca/~brecht/courses/854-Emerging-2014/readings/key-value/fb-memcached-nsdi-2013.pdf)
- **Challenge Mission — "The Cache Conundrum":**
  - Given: E-commerce site — product catalog (read-heavy), shopping cart (write-heavy), user sessions
  - Task: Design caching layer for each. Which strategy per component? How do you handle invalidation when a product price changes? What's your cache hit rate target?

#### Lecture 10: Asynchronism — Queues & Back Pressure
- **File:** `module-2/lecture-10-async.md`
- **Pre-Reading:** Primer sections — *Asynchronism*, *Message queues*, *Task queues*, *Back pressure*
- **Topics:**
  - Synchronous vs asynchronous — when async is necessary
  - Message queues: RabbitMQ, SQS, Kafka — producers, consumers, acknowledgment
  - Task queues: Celery, Sidekiq — background job processing
  - Event-driven architecture: events vs commands
  - Back pressure: what it is, why it matters, how to implement
  - Dead letter queues and poison messages
  - Exactly-once vs at-least-once vs at-most-once delivery
  - Real example: how Uber processes ride requests
- **Server Survival tie-in:** Queue service buffers requests during spikes. Without it, traffic bursts overwhelm Compute directly.
- **Supplementary reading:** [How Uber Scales Their Real-Time Market Platform](http://highscalability.com/blog/2015/9/14/how-uber-scales-their-real-time-market-platform.html)
- **Challenge Mission — "The Queue Commander":**
  - Given: Image processing service — users upload photos, app generates 5 thumbnail sizes. 50K uploads/hour peak.
  - Task: (1) Estimate queue depth at peak. (2) Design async pipeline — queue type? How many consumers? (3) What if a thumbnail generation fails? (4) Back pressure strategy when queue fills?

#### BOSS BATTLE 2: Design Twitter Timeline & Search
- **File:** `module-2/boss-battle-2.md`
- **Reference:** `../../deps/system-design-primer/solutions/system_design/twitter/README.md`
- **Module 2 Recap:** 10-point summary (ACID, replication, sharding, consistent hashing, NoSQL types, caching strategies, async patterns)
- **Estimation exercise:** Calculate storage for 500M users, 300M tweets/day, timeline fan-out
- **Format:** Same guided template as Boss Battle 1, but less hand-holding
- **Concepts tested:** Fan-out, caching, NoSQL, async processing, sharding, consistent hashing, estimation
- **Supplementary reading:** [Twitter: Timelines at Scale](https://www.infoq.com/presentations/Twitter-Timeline-Scalability) + [Storing 250 million tweets a day using MySQL](http://highscalability.com/blog/2011/12/19/how-twitter-stores-250-million-tweets-a-day-using-mysql.html)

---

### MODULE 3 — "The Distributed Mind"

> **Theme:** Understand the theoretical foundations that govern distributed systems, the protocols that connect them, and the patterns that keep them alive.

#### Lecture 11: CAP Theorem — Deep Dive
- **File:** `module-3/lecture-11-cap.md`
- **Pre-Reading:** Primer sections — *Availability vs consistency*, *CAP theorem*, *CP*, *AP*
- **Topics:**
  - What CAP actually says (and what it doesn't — common misconceptions)
  - Network partitions: why they're inevitable, not theoretical
  - CP systems: choosing consistency over availability (e.g., HBase, MongoDB with strong read)
  - AP systems: choosing availability over consistency (e.g., Cassandra, DynamoDB)
  - PACELC theorem: what happens when there's NO partition? Latency vs consistency
  - Real-world examples: how Google Spanner "cheats" CAP with TrueTime
  - **Connecting back:** Now revisit the replication and NoSQL choices from Module 2 through the CAP lens
- **Challenge Mission — "The CAP Dilemma":**
  - Given: 3 systems (banking ledger, social media likes, DNS)
  - Task: Classify each as CP or AP, justify with specific failure scenarios. For each, describe what happens during a network partition.

#### Lecture 12: Consistency Patterns
- **File:** `module-3/lecture-12-consistency.md`
- **Pre-Reading:** Primer sections — *Consistency patterns*, *Weak consistency*, *Eventual consistency*, *Strong consistency*
- **Topics:**
  - Strong consistency: linearizability, what it costs
  - Eventual consistency: convergence, conflict resolution (last-write-wins, vector clocks, CRDTs)
  - Weak consistency: fire-and-forget, best-effort
  - Read-your-writes consistency: why users expect it
  - Causal consistency: ordering that matters
  - Real examples: how DynamoDB does eventual consistency, how Zookeeper does strong
- **Challenge Mission — "The Consistency Spectrum":**
  - Given: 5 features of a social media app (profile updates, post likes, direct messages, notifications, search index)
  - Task: Assign consistency level to each, justify the trade-off. For each, describe a concrete user-visible bug that would occur with the *wrong* consistency level.

#### Lecture 13: Availability, Resilience & Observability
- **File:** `module-3/lecture-13-availability.md`
- **Pre-Reading:** Primer sections — *Availability patterns*, *Fail-over*, *Replication*, *Availability in numbers*
- **Topics:**
  - **Availability Patterns**
    - What "nines" mean: 99.9% vs 99.99% vs 99.999% in real downtime
    - Active-passive failover: cold/warm/hot standby, failover time
    - Active-active failover: load distribution, conflict handling
    - Replication for availability: sync vs async replication
    - Redundancy at every layer: multi-AZ, multi-region
    - SLAs and SLOs: how companies define and measure availability
    - Calculating composite availability (serial vs parallel components)
  - **Resilience Patterns** *(new — critical for production systems)*
    - Circuit Breaker: detect failures, fail fast, recover gracefully
    - Retry with exponential backoff + jitter: why jitter matters
    - Bulkhead pattern: isolate failures to prevent cascade
    - Timeout strategies: connect timeout vs read timeout
    - Saga pattern: distributed transactions without 2PC
    - Graceful degradation: serve stale data vs serve errors
  - **Monitoring & Observability** *(new — "you can't maintain availability without observing it")*
    - The three pillars: metrics, logs, traces
    - Key metrics: latency percentiles (p50, p95, p99), error rates, saturation
    - Distributed tracing: how Jaeger/Zipkin work, why they matter
    - Alerting: what to alert on, alert fatigue
    - Health checks and readiness probes
- **Server Survival tie-in:** Service health bars in the game = observability. Auto-repair = a form of self-healing. The game's "Active Event Bar" = alerting.
- **Challenge Mission — "The Uptime Contract":**
  - Given: A payments API with SLA of 99.99% (52 min downtime/year). Architecture: LB → 3 API servers → primary DB with 1 replica. Each component has individual availability.
  - Task: (1) Calculate composite availability of this architecture. (2) Can you meet the SLA? (3) What resilience patterns would you add? (4) What metrics would you monitor? (5) Design an alerting strategy.

#### Lecture 14: Communication Protocols & API Design
- **File:** `module-3/lecture-14-communication.md`
- **Pre-Reading:** Primer sections — *Communication*, *TCP*, *UDP*, *RPC*, *REST*
- **Topics:**
  - **Protocols**
    - TCP deep dive: reliability, ordering, flow control, congestion control
    - UDP: when speed beats reliability
    - RPC: how it works, gRPC and Protocol Buffers, service stubs
    - REST: constraints (stateless, cacheable, uniform interface), Richardson Maturity Model
    - GraphQL: when REST isn't enough
    - WebSockets: real-time bidirectional communication
    - Choosing protocols: decision matrix based on requirements
  - **API Design Patterns** *(new — complements protocols with practical design)*
    - Pagination: cursor-based vs offset — why cursor wins at scale
    - Rate limiting algorithms: token bucket, leaky bucket, sliding window
    - Idempotency: why it matters, idempotency keys, retry safety
    - API versioning: URL path vs header vs query param
    - Backward-compatible changes: additive changes, deprecation strategy
- **Challenge Mission — "The Protocol Picker":**
  - Given: 5 communication needs (real-time multiplayer game, public REST API, internal microservice calls, file transfer, notification push)
  - Task: (1) Pick protocol for each, justify with latency/reliability/complexity trade-offs. (2) For the public API: design pagination, rate limiting, and versioning strategy.

#### Lecture 15: Security Fundamentals for System Design
- **File:** `module-3/lecture-15-security.md`
- **Pre-Reading:** Primer sections — *Security*
- **Topics:**
  - Security fundamentals for system design: authentication, authorization, encryption
  - AuthN vs AuthZ: OAuth 2.0, JWT, API keys — when to use each
  - Common attack vectors: DDoS, injection, MITM, CSRF — and architectural defenses
  - Rate limiting and throttling as security (connects back to Lecture 14)
  - Encryption: at rest vs in transit, TLS, certificate management
  - Zero trust architecture: principles and trade-offs
  - Security at the system design level: what interviewers expect
- **Server Survival tie-in:** Firewall blocks MALICIOUS traffic (DDoS). What if 50% of traffic is malicious? Rate limiting = the Queue's capacity limit.
- **Challenge Mission — "The Fortress":**
  - Given: A public API serving 10M users. Currently has basic API key auth. Has experienced a credential leak and DDoS attack.
  - Task: (1) Design authentication and authorization layers. (2) Rate limiting strategy per user and per IP. (3) DDoS mitigation architecture. (4) What data needs encryption and where?

#### BOSS BATTLE 3: Design a Web Crawler at Scale
- **File:** `module-3/boss-battle-3.md`
- **Reference:** `../../deps/system-design-primer/solutions/system_design/web_crawler/README.md`
- **Module 3 Recap:** 10-point summary (CAP, PACELC, consistency levels, availability nines, resilience patterns, observability, protocols, API design, security)
- **Estimation exercise:** Calculate pages to crawl, bandwidth, storage, politeness delay
- **Format:** Guided template with constraints, less scaffolding than previous battles
- **Concepts tested:** Distributed systems, queues, politeness, deduplication (bloom filters), DNS, object storage, consistent hashing, monitoring
- **Supplementary reading:** [Google architecture](http://highscalability.com/google-architecture) + primer appendix on GFS

---

### MODULE 4 — "The Architect's Trial"

> **Theme:** Put it all together. Learn the interview framework, practice with varied formats, then face the final boss.

#### Lecture 16: The System Design Interview Framework
- **File:** `module-4/lecture-16-framework.md`
- **Pre-Reading:** Primer sections — *How to approach a system design interview question* (4 steps)
- **Topics:**
  - Step 1: Requirements gathering — the questions you MUST ask
  - Step 2: High-level design — component diagram, data flow
  - Step 3: Core component deep dive — the "zoom in" skill
  - Step 4: Scaling — identify bottlenecks, address them systematically
  - **Estimation as Step 1.5** — always do napkin math after requirements, before design
  - Time management: how to allocate 45 minutes
  - Common mistakes: jumping to solutions, over-engineering, ignoring constraints
  - Communication: thinking out loud, trade-off articulation
- **Challenge Mission — "The Framework Drill":**
  - Given: "Design a notification system" (surprise problem)
  - Task: Apply the 4-step framework in writing. Include estimation. Focus on process, not perfection. Time yourself to 30 minutes.

#### Lecture 17: Design Mint.com — Guided Walkthrough
- **File:** `module-4/lecture-17-mint.md`
- **Reference:** `../../deps/system-design-primer/solutions/system_design/mint/README.md`
- **Format:** **Interactive walkthrough** — I present the problem, you design step by step, we discuss after each step
- **Key concepts:** Data aggregation, MapReduce, third-party APIs, data pipeline
- **Supplementary reading:** [Instagram: 14 million users, terabytes of photos](http://highscalability.com/blog/2011/12/6/instagram-architecture-14-million-users-terabytes-of-photos.html)

#### Lecture 18: Design a Social Network Graph — Peer Review
- **File:** `module-4/lecture-18-social-graph.md`
- **Reference:** `../../deps/system-design-primer/solutions/system_design/social_graph/README.md`
- **Format:** **Peer review** *(varied format to prevent fatigue)* — I give you a **flawed design** for a social graph. You identify the problems (missing components, wrong database choices, scalability bottlenecks) and improve it.
- **Key concepts:** Graph databases, BFS/DFS at scale, caching relationships, sharding social data
- **Why this format:** Reviewing others' designs builds a different muscle than creating from scratch. It trains you to spot anti-patterns, which is equally valuable.

#### Lecture 19: Design Amazon Sales Ranking — Time-Boxed Drill
- **File:** `module-4/lecture-19-sales-rank-aws.md`
- **References:** `../../deps/system-design-primer/solutions/system_design/sales_rank/README.md`, `../../deps/system-design-primer/solutions/system_design/scaling_aws/README.md`
- **Format:** **Time-boxed drill** *(simulates interview pressure)* — 30-minute timer, you design solo using the 4-step framework, then we debrief. No hints during the timer.
- **Key concepts:** MapReduce, real-time vs batch processing, AWS services, auto-scaling
- **Why this format:** Prepares you for the Final Boss. The debrief after is where most learning happens — comparing what you prioritized vs what you missed under time pressure.

#### Lecture 20: Capstone — Patterns, Anti-Patterns & Decision Trees
- **File:** `module-4/lecture-20-capstone.md`
- **Pre-Reading:** Primer sections — *Real world architectures*, *Company architectures*, browse 2-3 *Company engineering blogs* for companies that interest you
- **Topics:**
  - Pattern catalog: when to use each component (decision trees)
  - Anti-patterns: premature optimization, over-sharding, cache stampede, distributed monolith
  - Trade-off matrices: consistency vs availability, latency vs throughput, cost vs reliability
  - Building your own "system design toolbox" — mental models for any new problem
  - Course retrospective: what changed in your thinking from Lecture 1 to now?
- **Challenge Mission — "The Pattern Library":**
  - Build a personal cheat sheet / decision tree: "Given X requirements, I would choose Y because Z"
  - Must cover: database selection, caching strategy, communication protocol, consistency level, availability architecture

#### FINAL BOSS: Original System Design
- **File:** `module-4/final-boss.md`
- **Format:** Problem revealed during the session (not in advance). Full system design from scratch. **45-minute time box** — real interview conditions.
- **Possible problems (one will be chosen):**
  - Design a ride-sharing service (Uber/Lyft)
  - Design a real-time collaborative document editor (Google Docs)
  - Design a distributed rate limiter
  - Design a URL shortener with analytics
- **Assessment:** Self-evaluation rubric + comparison discussion
- **Post-mortem:** After the timer, unlimited time to improve your design. Compare the timed version to the improved version — what did you miss under pressure?

---

## Server Survival Integration Schedule

| Timing | Mission | Success Criteria | Purpose |
|--------|---------|-----------------|---------|
| Before Lecture 1 | Play Sandbox mode blind (15 min) | Just play and note what breaks | Baseline intuition |
| After Lecture 4 | Survival mode: survive 2 min, budget > $200 | Focus on Firewall + LB placement, minimize reputation loss | Apply LB and security knowledge |
| After Lecture 9 | Survival mode: achieve high cache effectiveness | Place Cache nodes strategically, watch DB load drop | Practice caching strategy in real-time |
| After Lecture 10 | Survival mode: survive a DDoS spike without losing >5% reputation | Use Queue buffering to absorb burst traffic | Feel back pressure viscerally |
| After Module 3 | Full Survival mode: survive 5+ minutes | Apply all knowledge — full architecture build | Integration test of all concepts |
| After Module 4 | Final Survival run: document every placement decision and why | Write up your architecture decisions as if explaining to a teammate | Capstone reflection — connects game intuition to formal knowledge |

---

## Company Architecture Reading List

Assigned readings from the primer's appendix, one per module:

| Module | Reading | Why |
|--------|---------|-----|
| 1 (after Boss Battle) | [Netflix: What Happens When You Press Play?](http://highscalability.com/blog/2017/12/11/netflix-what-happens-when-you-press-play.html) | CDN, request routing, load balancing at massive scale |
| 2 (after Boss Battle) | [Twitter: Timelines at Scale](https://www.infoq.com/presentations/Twitter-Timeline-Scalability) + [Facebook: Scaling Memcached](https://cs.uwaterloo.ca/~brecht/courses/854-Emerging-2014/readings/key-value/fb-memcached-nsdi-2013.pdf) | Fan-out, caching, sharding in production |
| 3 (after Boss Battle) | [Google architecture](http://highscalability.com/google-architecture) | Distributed systems, crawling, indexing at Google scale |
| 4 (after Final Boss) | Pick 2 from: [Uber](http://highscalability.com/blog/2015/9/14/how-uber-scales-their-real-time-market-platform.html), [WhatsApp](http://highscalability.com/blog/2014/2/26/the-whatsapp-architecture-facebook-bought-for-19-billion.html), [Instagram](http://highscalability.com/blog/2011/12/6/instagram-architecture-14-million-users-terabytes-of-photos.html) | Breadth — see how different companies solve different problems |

---

## Progress Tracking

Progress will be tracked in `course/progress.md`:
- Each quiz score (out of /10, standardized format)
- Challenge Mission completion status + self-rating
- Boss Battle self-assessment score (rubric-based)
- Estimation accuracy tracking (compare your estimates to known values)
- Server Survival high scores and architecture notes
- Personal notes and "aha moments"

---

## File Structure

```
course/
├── README.md                    # Course overview, module map, status tracking
├── project-plan.md              # This file — detailed curriculum plan
├── progress.md                  # Quiz scores, challenge log, survival scores
├── glossary.md                  # Accumulating key terms
├── module-1/
│   ├── lecture-01-internet.md
│   ├── lecture-02-performance.md
│   ├── lecture-03-cdn.md
│   ├── lecture-04-load-balancers.md
│   ├── lecture-05-app-layer.md
│   └── boss-battle-1.md
├── module-2/
│   ├── lecture-06-rdbms.md
│   ├── lecture-07-nosql.md
│   ├── lecture-08-sql-vs-nosql.md
│   ├── lecture-09-caching.md
│   ├── lecture-10-async.md
│   └── boss-battle-2.md
├── module-3/
│   ├── lecture-11-cap.md
│   ├── lecture-12-consistency.md
│   ├── lecture-13-availability.md
│   ├── lecture-14-communication.md
│   ├── lecture-15-security.md
│   └── boss-battle-3.md
└── module-4/
    ├── lecture-16-framework.md
    ├── lecture-17-mint.md
    ├── lecture-18-social-graph.md
    ├── lecture-19-sales-rank-aws.md
    ├── lecture-20-capstone.md
    └── final-boss.md
```

---

## Implementation Status

- [x] Course README (overview + progress tracker)
- [x] Project plan (this file)
- [x] Progress tracking file
- [x] Glossary file
- [x] Module 1: Lectures 1-5 + Boss Battle 1
- [x] Module 2: Lectures 6-10 + Boss Battle 2
- [x] Module 3: Lectures 11-15 + Boss Battle 3
- [x] Module 4: Lectures 16-20 + Final Boss

---

## Revision Log

| Date | Changes |
|------|---------|
| 2026-03-16 | Initial plan created |
| 2026-03-16 | **v2 — Review-driven revision:** Added CAP primer to L6, consistent hashing deep dive to L6, moved estimation to L2, added resilience patterns + observability to L13, added API design to L14, varied M4 lecture formats (guided/peer-review/time-boxed), added pre-reading assignments, module recaps in boss battles, specific Server Survival success criteria, company architecture reading list, standardized quiz format, integrated OOD notebooks + Anki decks, added glossary, renamed L15 to focus on security (estimation moved out). |
