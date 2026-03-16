# Lecture 7: NoSQL Deep Dive

> Module 2 — "The Data Fortress" | Lecture 7 of 20

Relational databases have dominated for 40 years. Then, around 2010, companies like Google, Amazon, and Facebook started hitting walls that SQL couldn't solve at their scale. NoSQL databases emerged to fill specific gaps — but they're not replacements for SQL. They're different tools for different problems. This lecture covers the four major types and when each one is the right choice.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *NoSQL*
- *Key-value store*
- *Document store*
- *Wide column store*
- *Graph database*

---

## Concept Briefing

### Why NoSQL Exists

Relational databases are excellent when:
- Your data has clear structure and relationships
- You need ACID transactions
- Your queries involve complex joins
- Your data fits on one server (or scales with replication + sharding)

But they struggle when:
- Your data model doesn't fit neat tables (flexible schemas, deeply nested data)
- You need to write millions of small records per second (IoT sensor data)
- Your relationships ARE the data (social graphs with billions of edges)
- You need horizontal scaling without the pain of manual sharding
- You can tolerate eventual consistency for higher availability

NoSQL databases were built to handle these specific cases.

---

## Deep Dive

### Key-Value Stores

The simplest data model: a key maps to a value. That's it.

```
"user:42:session" → {"logged_in": true, "cart": [...], "expires": "2026-03-17T00:00:00Z"}
"config:feature_flags" → {"dark_mode": true, "new_checkout": false}
"rate_limit:ip:10.0.0.1" → 47
```

**Operations:** GET, SET, DELETE. Some support TTL (auto-expiration), atomic increments, and basic data structures (lists, sets, sorted sets).

#### Redis

The most popular key-value store. Stores everything in memory with optional disk persistence.

| Feature | Detail |
|---------|--------|
| **Speed** | 100,000+ ops/sec single-threaded, sub-millisecond latency |
| **Data structures** | Strings, lists, sets, sorted sets, hashes, streams, bitmaps |
| **Persistence** | RDB snapshots, AOF (append-only file), or both |
| **Clustering** | Redis Cluster for horizontal scaling |
| **Use cases** | Caching, session storage, rate limiting, real-time leaderboards, pub/sub |

**Limitations:** Data must fit in memory (or memory + disk with Redis on Flash). Not designed for complex queries. Single-threaded for commands (though I/O is multi-threaded in Redis 6+).

#### DynamoDB

Amazon's managed key-value (and document) store.

| Feature | Detail |
|---------|--------|
| **Scaling** | Automatic horizontal scaling, provisioned or on-demand capacity |
| **Consistency** | Eventually consistent (default) or strongly consistent reads |
| **Pricing** | Pay per read/write capacity unit |
| **Use cases** | Session storage, user profiles, gaming leaderboards, IoT |

**Key insight:** DynamoDB's partition key is effectively the shard key. Choosing a good partition key is critical — a bad one creates "hot partitions" that throttle.

#### When to use key-value stores

- **Sessions** — Fast lookup by session ID, TTL for auto-expiration
- **Caching** — Store computed results, cache DB query results (Lecture 9)
- **Rate limiting** — Increment a counter per IP/user, check against threshold
- **Feature flags** — Quick lookup of configuration
- **Queues** (simple) — Redis lists as lightweight queues

#### When NOT to use key-value stores

- When you need to query by anything other than the key
- When you need relationships between records
- When you need transactions across multiple keys (Redis has limited support)
- When your data exceeds available memory (for in-memory stores)

---

### Document Stores

Like key-value stores, but the value is a structured document (usually JSON or BSON) that the database understands and can query.

```json
{
  "_id": "user_42",
  "name": "Alice",
  "email": "alice@example.com",
  "addresses": [
    {"type": "home", "city": "Seattle", "zip": "98101"},
    {"type": "work", "city": "San Francisco", "zip": "94105"}
  ],
  "orders": [
    {"id": "order_1", "total": 49.99, "items": ["widget_a", "widget_b"]}
  ]
}
```

**Key difference from key-value:** The database can index and query fields within the document. `db.users.find({"addresses.city": "Seattle"})` is a valid query.

#### MongoDB

The most popular document store.

| Feature | Detail |
|---------|--------|
| **Schema** | Flexible — documents in the same collection can have different fields |
| **Queries** | Rich query language, aggregation pipeline, full-text search |
| **Scaling** | Built-in sharding with automatic balancing |
| **Consistency** | Configurable — from eventual to strong (with read concern levels) |
| **Use cases** | Content management, product catalogs, user profiles, event logging |

**When MongoDB shines:** When your data is naturally hierarchical (a user has addresses, orders, preferences) and you frequently read the entire "document" at once. Instead of joining 5 tables, you read one document.

**When MongoDB hurts:** When you need cross-document transactions frequently (added in MongoDB 4.0 but slower than SQL), or when data relationships are complex and many-to-many.

#### Schema Flexibility — Blessing and Curse

Document stores don't enforce a schema at the database level. This means:
- **Blessing:** Rapid development. Change the schema by just writing different documents. No migration needed.
- **Curse:** Schema debt. Over time, documents in the same collection may have wildly different structures. Your application code must handle all variants. "Schema-less" really means "schema is in your application code, not the database."

**Best practice:** Use schema validation (MongoDB supports it) to enforce structure while keeping some fields flexible.

---

### Wide Column Stores

Data is organized by rows and column families, but unlike relational tables, each row can have different columns.

```
Row key: "user_42"
  Column family "profile":
    name: "Alice"
    email: "alice@example.com"
  Column family "activity":
    last_login: "2026-03-15"
    login_count: 842
    last_post: "2026-03-14"

Row key: "user_43"
  Column family "profile":
    name: "Bob"
    email: "bob@example.com"
  Column family "activity":
    last_login: "2026-03-16"
    # login_count not set for this user — that's fine
```

#### Cassandra

The most widely used wide column store.

| Feature | Detail |
|---------|--------|
| **Architecture** | Fully distributed, no master node (peer-to-peer ring) |
| **Consistency** | Tunable — per-query choice of consistency level |
| **Write performance** | Extremely fast writes (append-only storage engine) |
| **Scaling** | Linear horizontal scaling — add nodes, capacity increases proportionally |
| **Use cases** | Time-series data, IoT sensor data, messaging, activity feeds |

**Key design principle:** Model your tables around your queries, not your entities. In Cassandra, you often denormalize heavily — the same data might exist in 3 different tables, each optimized for a different query pattern. This is the opposite of relational normalization.

#### HBase

Built on top of Hadoop/HDFS. Designed for very large datasets with sparse data.

| Feature | Detail |
|---------|--------|
| **Architecture** | Master-slave (HBase Master + RegionServers) |
| **Consistency** | Strong consistency (CP in CAP) |
| **Integration** | Native Hadoop/MapReduce integration |
| **Use cases** | Analytics on massive datasets, time-series at petabyte scale |

#### When to use wide column stores

- **Time-series data** — Sensor readings, metrics, logs. The row key includes a timestamp, and each reading is a column. Cassandra excels here.
- **High write throughput** — When you need to ingest millions of writes per second
- **Data with variable columns** — When different records have different attributes
- **Global distribution** — Cassandra's peer-to-peer architecture works well across datacenters

---

### Graph Databases

When your data is defined by relationships, not attributes.

```
(Alice) ──FRIENDS_WITH──► (Bob)
(Alice) ──LIKES──► (Post_123)
(Bob) ──WORKS_AT──► (Acme Corp)
(Acme Corp) ──LOCATED_IN──► (San Francisco)
```

#### Neo4j

The most popular graph database.

| Feature | Detail |
|---------|--------|
| **Query language** | Cypher — pattern-matching query language |
| **Performance** | Traversal of relationships is O(1) per hop (index-free adjacency) |
| **Use cases** | Social networks, recommendation engines, fraud detection, knowledge graphs |

**Why graphs beat relational for relationships:** In SQL, finding "friends of friends" requires a self-join:
```sql
SELECT DISTINCT f2.friend_id
FROM friendships f1
JOIN friendships f2 ON f1.friend_id = f2.user_id
WHERE f1.user_id = 42;
```
With 1 billion friendships, this join is extremely expensive.

In Neo4j:
```cypher
MATCH (alice:User {id: 42})-[:FRIENDS_WITH*2]-(fof:User)
RETURN DISTINCT fof
```
This traverses the graph in O(number of friends × friends), independent of total database size.

**At what depth does this matter?** For 1-2 hops, SQL is fine. At 3+ hops (friends of friends of friends), graph databases are orders of magnitude faster. Real-world graph queries often go 3-6 hops deep.

#### When to use graph databases

- **Social networks** — Followers, friends, mutual connections
- **Recommendation engines** — "People who bought X also bought Y" (via shared purchase patterns)
- **Fraud detection** — Find suspicious patterns in transaction graphs
- **Knowledge graphs** — Entity relationships (Google Knowledge Graph)
- **Network topology** — Route planning, dependency analysis

#### When NOT to use graph databases

- When data is mostly tabular with simple relationships
- When you need heavy aggregations (SUM, COUNT over large datasets)
- When write throughput is the bottleneck (graph updates can be complex)
- When your dataset is small and SQL joins are fast enough

---

### BASE vs ACID — The Real Trade-off

Now that you've seen both SQL (ACID) and NoSQL databases, here's the fundamental tension:

| Property | ACID (SQL) | BASE (NoSQL) |
|----------|-----------|-------------|
| **Consistency model** | Strong — always correct | Eventual — correct "soon" |
| **Availability** | May sacrifice availability for consistency | Prioritizes availability |
| **Focus** | Correctness first | Performance and availability first |
| **Example** | Bank transfer must be atomic | Social media like count can be slightly off |

**BASE** stands for:
- **B**asically **A**vailable — The system is always reachable
- **S**oft state — Data may be in flux (not all replicas agree)
- **E**ventually consistent — Given time with no new writes, all replicas converge

**The right mental model:** It's not ACID vs BASE. It's a spectrum. Most systems use ACID for some operations (payment processing) and BASE for others (activity feed counts) within the same application. Now that you have the CAP context from the beginning of this module, you can see that ACID ≈ CP and BASE ≈ AP.

---

### The Anti-Pattern: NoSQL Because It's "Modern"

A common mistake: choosing NoSQL because "SQL is old" or "NoSQL scales better." In reality:
- PostgreSQL can handle millions of rows and thousands of QPS with proper indexing
- Most startups never outgrow a single PostgreSQL instance
- NoSQL adds complexity (no joins, eventual consistency, denormalization) that isn't justified unless you have a specific problem SQL can't solve

**Choose NoSQL when:** You have a specific technical reason (schema flexibility, write throughput, graph traversal, horizontal scaling beyond what sharding provides).

**Default to SQL when:** You're unsure. SQL's constraints are features — they prevent data corruption. You can always add a NoSQL store for specific use cases later.

---

## Discussion Prompts

1. **Instagram stores user photos in S3 (object storage) and photo metadata in PostgreSQL. Could they use MongoDB for metadata instead?** What would they gain? What would they lose? Which choice is more defensible at Instagram's scale?

2. **A startup is building an IoT platform that ingests 1 million sensor readings per second. Each reading is ~100 bytes: sensor_id, timestamp, value. They need to query by sensor_id + time range. SQL or NoSQL? Which specific database, and why?**

3. **Your team wants to use MongoDB because "we don't know our schema yet." Is this a good reason?** What happens 2 years later when you have 500 million documents with 47 different "versions" of the schema?

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. Key-value stores like Redis store data in ______, which limits dataset size but provides sub-millisecond read latency.

2. In Cassandra, data modeling follows the principle of designing tables around your ______, often denormalizing the same data into multiple tables.

3. The consistency model used by most NoSQL databases, where all replicas eventually converge to the same state, is called ______ consistency.

### Multiple Choice (4 points)

4. Which database type is most appropriate for finding "friends of friends of friends" in a social network with 1 billion users?

   - a) Relational (PostgreSQL) — use self-joins
   - b) Document store (MongoDB) — embed friend lists in user documents
   - c) Graph database (Neo4j) — traverse relationship edges
   - d) Wide column store (Cassandra) — store friendship rows

5. A real-time gaming leaderboard needs to: store player scores, retrieve the top 100 players instantly, and handle 50,000 score updates per second. Which database is most appropriate?

   - a) PostgreSQL with an index on score
   - b) Redis with sorted sets
   - c) MongoDB with a scores collection
   - d) Cassandra with a scores table

6. Your application stores product listings. Each product has a title, description, price, and a variable set of attributes (clothing has size/color, electronics have specs, books have ISBN/author). Which database type handles this most naturally?

   - a) Relational — use a fixed schema with nullable columns
   - b) Document store — each product is a document with flexible fields
   - c) Key-value — store serialized product data
   - d) Wide column — different columns per product type

7. An e-commerce system needs to process a payment and update inventory atomically. If the payment succeeds but inventory update fails, the system must roll back both. Which database property ensures this?

   - a) Eventual consistency
   - b) ACID atomicity
   - c) BASE availability
   - d) Partition tolerance

### Short Answer (3 points)

8. Explain why Cassandra's peer-to-peer architecture (no master node) makes it more available than MySQL's master-slave replication. What does Cassandra sacrifice in return?

9. You're storing user sessions. The data is simple (session_id → session_data), access pattern is always by session_id, sessions expire after 30 minutes, and you need sub-millisecond reads. Justify your database choice.

10. A company uses MongoDB for everything: user accounts (with passwords), financial transactions, product catalog, and user-generated content. Critique this decision — which use cases are appropriate for MongoDB and which should use a different database type?

<details>
<summary>Answer Key</summary>

1. **memory** (RAM)
2. **queries** (or "access patterns" / "read patterns")
3. **eventual**
4. **c)** — Graph databases like Neo4j perform relationship traversal in O(relationships per hop) regardless of total database size. A 3-hop traversal in a 1-billion-user graph is fast because it only visits the relevant nodes. SQL self-joins for 3 hops would produce a massive intermediate result set.
5. **b)** — Redis sorted sets are purpose-built for this. `ZADD` updates scores atomically, `ZREVRANGE` retrieves the top N in O(log(N)+M). At 50,000 ops/sec, Redis handles this trivially in memory. PostgreSQL could work but would struggle with 50,000 concurrent updates to the same index.
6. **b)** — Document stores handle variable schemas naturally. Each product document has whatever fields it needs. Relational databases would require either many nullable columns (wasteful), an EAV pattern (complex and slow), or separate tables per product type (joins). Both wide column (d) and document (b) handle this, but document stores are more natural for querying nested product attributes.
7. **b)** — ACID atomicity ensures a transaction is all-or-nothing. If any part fails, the entire transaction rolls back. This is precisely what you need for financial operations where partial completion would mean losing money or selling phantom inventory.
8. Cassandra has no single master — any node can accept reads and writes. If a node dies, the remaining nodes continue serving all operations. With MySQL master-slave, if the master dies, writes stop until a slave is promoted (which risks data loss from unreplicated writes). Cassandra sacrifices strong consistency: because any node can accept writes, two clients might write conflicting data to different nodes simultaneously. Cassandra uses eventual consistency (with tunable consistency levels) to resolve this — trading correctness guarantees for availability.
9. Redis. Reasoning: (1) Access pattern is key-value (session_id → data) — perfect for key-value stores. (2) Sub-millisecond reads require in-memory storage — Redis operates entirely in RAM. (3) 30-minute TTL — Redis has native TTL support, automatically expiring sessions. (4) No need for queries on session data (never "find all sessions for user X" at runtime). (5) Session data is transient — losing it on crash is acceptable (users just re-login). If persistence matters, Redis AOF or RDB snapshots provide durability.
10. **Appropriate for MongoDB:** Product catalog (flexible schema, variable attributes, read-heavy) and user-generated content (documents, flexible structure, high write volume). **Should use a relational database:** User accounts with passwords (need strong consistency, ACID transactions for password changes, foreign key relationships to other tables) and financial transactions (require ACID atomicity — a charge and inventory deduction must be atomic, consistent, and durable). Financial data in MongoDB risks partial updates and inconsistency because multi-document transactions, while supported, are slower and more limited than in PostgreSQL.

</details>

---

## Challenge Mission: "The Right Tool"

### Scenario

You're a senior architect advising 5 different teams, each building a different application. Your job: recommend the right database type for each, with specific technical justifications.

### The Applications

**Application 1: Social Media Activity Feed**
- 100M users, 500M posts/day
- Feed query: "Show me the latest 50 posts from people I follow"
- User follows ~200 people on average
- Reads are 100x more frequent than writes
- Slight staleness (30 seconds) is acceptable

**Application 2: IoT Sensor Platform**
- 10M sensors, each sends a reading every 5 seconds
- Data: sensor_id, timestamp, value (temperature, humidity, etc.)
- Queries: readings for sensor X between time T1 and T2
- Must retain 2 years of data, then auto-delete
- Write throughput is the primary concern

**Application 3: E-Commerce Product Catalog**
- 5M products across 200 categories
- Each category has different attributes (clothing: size/color; electronics: specs; books: ISBN)
- Full-text search on product names and descriptions
- Price updates must be immediately consistent
- Complex queries: "Red dresses under $50 in size M, sorted by popularity"

**Application 4: Fraud Detection System**
- Analyze transaction patterns across accounts
- Detect rings of accounts sending money in circles
- Find "2nd-degree connections" — people who transacted with people who transacted with a flagged account
- Real-time analysis of new transactions
- 1M transactions per day

**Application 5: User Session Store**
- 50M concurrent sessions
- Access pattern: lookup by session_id only
- Average session data: 5 KB
- Sessions expire after 30 minutes
- 200,000 reads/second, 50,000 writes/second
- Sub-millisecond read latency required

### Your Task

For each application:
1. **Choose a database type** (and a specific product if you have a preference)
2. **Justify with 3 specific technical reasons** — don't just say "it scales well"
3. **Estimate the data volume** (storage per day/year)
4. **Identify the main risk** of your choice and how to mitigate it

### Constraints

- Each choice must be the best fit, not just "acceptable"
- You can recommend multiple databases for a single application if different components have different needs
- Justify any case where SQL is the right answer despite the "NoSQL" lecture context

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 2:

- **Key-value store** — Database where each record is a key mapped to a value. No schema, no queries on values. Examples: Redis, DynamoDB.
- **Document store** — Key-value store where values are structured documents (JSON/BSON) that can be queried. Examples: MongoDB, CouchDB.
- **Wide column store** — Database organized by rows and column families, where each row can have different columns. Examples: Cassandra, HBase.
- **Graph database** — Database optimized for storing and traversing relationships between entities. Examples: Neo4j, Amazon Neptune.
- **BASE** — Basically Available, Soft state, Eventually consistent. The consistency model of most NoSQL databases.
- **Denormalization** — Intentionally duplicating data across tables/documents to optimize read performance at the cost of write complexity.
- **Hot partition** — A shard/partition that receives disproportionately more traffic than others, causing throttling.
