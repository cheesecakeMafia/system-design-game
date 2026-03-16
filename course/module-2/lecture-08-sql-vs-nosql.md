# Lecture 8: SQL vs NoSQL + Denormalization + SQL Tuning

> Module 2 — "The Data Fortress" | Lecture 8 of 20

You've now seen both SQL (Lecture 6) and NoSQL (Lecture 7) databases in depth. This lecture gives you a decision framework for choosing between them — plus the practical skills of denormalization and SQL tuning that make relational databases perform at scale.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *SQL or NoSQL*
- *Denormalization*
- *SQL tuning*

---

## Deep Dive

### The Decision Framework

Instead of "SQL vs NoSQL," think **"Which properties does my use case need?"**

| If you need... | Choose | Because |
|----------------|--------|---------|
| ACID transactions | SQL | NoSQL transactions are limited or slower |
| Flexible schema | Document store (NoSQL) | No migrations, variable attributes per record |
| Complex joins across entities | SQL | NoSQL has no joins; you denormalize or do application-level joins |
| Extreme write throughput (>100K writes/sec) | Wide column store (NoSQL) | Append-only storage engines, horizontal write scaling |
| Relationship traversal (3+ hops) | Graph DB (NoSQL) | O(relationships) traversal vs O(N^k) SQL joins |
| Simple key-value access at high speed | Key-value store (NoSQL) | In-memory, sub-millisecond, purpose-built |
| Strong consistency + complex queries | SQL | Mature query planners, indexes, constraints |
| Horizontal scaling with minimal ops | Managed NoSQL (DynamoDB, Cosmos) | Built-in partitioning, no manual sharding |

**The nuanced answer:** Most production systems use BOTH.

```
User accounts, payments → PostgreSQL (ACID, consistency)
Session cache → Redis (speed, TTL)
Product catalog → MongoDB or PostgreSQL (depends on attribute variability)
Activity feed → Cassandra (write throughput, time-series)
Recommendations → Neo4j or precomputed in Redis
```

### When to Use Both (Polyglot Persistence)

Polyglot persistence means using different databases for different use cases within the same application.

```
┌─────────────────────────────────────────┐
│             Application Layer            │
├─────────┬────────┬──────────┬───────────┤
│PostgreSQL│ Redis  │ MongoDB  │ Cassandra │
│(accounts,│(cache, │(product  │(activity  │
│ payments)│sessions│ catalog) │  feed)    │
└─────────┴────────┴──────────┴───────────┘
```

**Trade-off:** Operational complexity. Each database needs monitoring, backups, failover, and expertise. A 5-person startup running 4 different databases is spending more time on ops than on features. Start with one (probably PostgreSQL), add others only when a specific bottleneck demands it.

---

### Denormalization — Breaking the Rules on Purpose

In normalized databases, data is stored once and referenced by foreign keys. This eliminates duplication but requires joins for most queries.

**Normalized (3NF):**
```
users:    id, name, email
orders:   id, user_id, created_at, total
items:    id, order_id, product_id, quantity, price
products: id, name, description, price
```

Query: "Show order details with customer name and product names"
→ JOIN across 4 tables.

**Denormalized:**
```
order_details: id, user_name, user_email, product_name, product_price, quantity, order_total, created_at
```

Query: Simple SELECT from one table. No joins.

#### Why Denormalize

| Benefit | Explanation |
|---------|-------------|
| Faster reads | No joins = simpler, faster queries |
| Simpler queries | Application code doesn't need to assemble data from multiple tables |
| Better cache hit rates | One cache key per "view" instead of caching partial results |
| Horizontal scaling | Denormalized tables are easier to shard (no cross-shard joins) |

#### The Cost of Denormalization

| Cost | Explanation |
|------|-------------|
| Data duplication | User's name stored in every order row. 1M orders × 50 bytes = 50 MB of duplicated names |
| Write complexity | Updating a user's name requires updating every row that contains it |
| Inconsistency risk | If one update succeeds and another fails, data is out of sync |
| Storage | More total data stored (usually trivial given storage costs) |

#### When to Denormalize

- **Read-heavy workloads** (read:write ratio > 10:1) — The read speedup outweighs the write cost
- **Dashboard/report queries** — Precompute and store the result instead of joining at query time
- **Sharded databases** — Eliminating cross-shard joins is often mandatory
- **Caching layer** — Denormalized records are easier to cache as a single unit

**When NOT to denormalize:**
- Write-heavy workloads (every write must update multiple copies)
- Data that changes frequently (e.g., live pricing with millions of references)
- When you can solve the read performance problem with better indexes first

#### Materialized Views — The Middle Ground

A materialized view is a precomputed query result stored as a table. The database maintains it automatically (or on a schedule).

```sql
CREATE MATERIALIZED VIEW order_summary AS
SELECT o.id, u.name, u.email, o.total, o.created_at
FROM orders o
JOIN users u ON o.user_id = u.id;

-- Refresh periodically:
REFRESH MATERIALIZED VIEW order_summary;
```

This gives you the read performance of denormalization without manually managing the duplicated data. The trade-off: refresh has a cost, and data is stale between refreshes.

---

### SQL Tuning — Making Relational Databases Fast

Before reaching for NoSQL or denormalization, make sure you've actually optimized your SQL database. These techniques can often 10-100x your query performance without architectural changes.

#### Indexes — The Most Important Optimization

An index is a data structure (usually a B-tree) that allows the database to find rows without scanning the entire table.

**Without index:** Full table scan — read every row. O(N).
**With index:** B-tree traversal — jump directly to matching rows. O(log N).

| Index Type | Best For | Example |
|-----------|----------|---------|
| **B-tree** (default) | Range queries, equality, sorting | `WHERE created_at > '2026-01-01'` |
| **Hash** | Exact equality only | `WHERE session_id = 'abc123'` |
| **Composite** | Queries on multiple columns | `WHERE user_id = 42 AND status = 'active'` |
| **Partial** | Queries on a subset of rows | `WHERE status = 'pending'` (index only pending rows) |
| **GIN/GiST** | Full-text search, JSON, arrays | `WHERE tags @> '{"urgent"}'` |

**Composite index ordering matters:**
```sql
CREATE INDEX idx_user_status ON orders(user_id, status);
```
This index is useful for:
- `WHERE user_id = 42` (uses the left prefix)
- `WHERE user_id = 42 AND status = 'shipped'` (uses both columns)

It is NOT useful for:
- `WHERE status = 'shipped'` (can't skip the first column)

**Rule:** The leftmost prefix rule. A composite index on (A, B, C) supports queries on A, (A, B), and (A, B, C) — but not B alone or (B, C).

#### EXPLAIN — Understanding Query Execution

The most valuable debugging tool for slow queries:

```sql
EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = 42 AND status = 'pending';
```

Key things to look for:
- **Seq Scan** (Sequential Scan) — Reading every row. Slow on large tables. Add an index.
- **Index Scan** — Using an index to find rows. Good.
- **Index Only Scan** — All needed data is in the index itself. Best.
- **Nested Loop** — Join algorithm. Fine for small result sets, terrible for large ones.
- **Hash Join** — Join algorithm for larger result sets. Uses memory.
- **Sort** — If no index supports the ORDER BY, the database sorts in memory. Expensive for large results.

#### The N+1 Query Problem

The most common performance mistake in application code:

```python
# BAD: N+1 queries
users = db.query("SELECT * FROM users LIMIT 100")  # 1 query
for user in users:
    orders = db.query("SELECT * FROM orders WHERE user_id = %s", user.id)  # 100 queries
# Total: 101 queries
```

```python
# GOOD: 2 queries with JOIN or IN
users = db.query("SELECT * FROM users LIMIT 100")
user_ids = [u.id for u in users]
orders = db.query("SELECT * FROM orders WHERE user_id IN %s", tuple(user_ids))
# Total: 2 queries
```

At 100 users, the bad version takes 101 × 5ms = 500ms. The good version takes 2 × 5ms = 10ms. At 10,000 users, it's 50 seconds vs 10ms. N+1 is the #1 cause of "my app is slow" in web development.

#### Connection Pooling

Creating a new database connection is expensive (~20-50ms for TCP + authentication). Connection pooling reuses connections.

```
Without pooling:
  Request 1 → open connection → query → close connection
  Request 2 → open connection → query → close connection

With pooling:
  Request 1 → borrow connection → query → return to pool
  Request 2 → borrow same connection → query → return to pool
```

Most web frameworks have built-in pooling. Set your pool size to approximately `(number of CPU cores × 2) + number of disk spindles` for optimal throughput.

#### Prepared Statements

Parse the SQL once, execute many times with different parameters:

```sql
PREPARE user_lookup AS SELECT * FROM users WHERE id = $1;
EXECUTE user_lookup(42);
EXECUTE user_lookup(99);
```

Benefits: Avoids re-parsing the query plan each time, AND prevents SQL injection.

---

## Discussion Prompts

1. **Your application currently uses PostgreSQL for everything and handles 10,000 QPS. The CEO says "We need to switch to MongoDB for better scalability." You disagree. Make your case — when is PostgreSQL at 10,000 QPS NOT a scaling problem?**

2. **You have a denormalized `order_details` table. A user changes their email. You need to update their email in 100,000 order rows. In a production system handling 5,000 QPS, how do you do this without causing a performance incident?**

3. **A team adds 15 indexes to a table to speed up every possible query. Reads are now fast, but writes have slowed to a crawl. Why?** What's the right approach to indexing?

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. The practice of using different database types for different use cases within the same application is called ______ persistence.

2. A composite index on columns (A, B, C) can efficiently support queries filtering on A, or on A and B, or on A, B, and C — this is called the ______ prefix rule.

3. The common ORM performance problem where loading a list of N items generates N additional queries (one per item) is called the ______ problem.

### Multiple Choice (4 points)

4. A table has 10 million rows. A query filters by `status` column, which has 3 possible values ('active', 'pending', 'closed'). 95% of rows are 'closed'. You frequently query for 'pending' rows. What index strategy is best?

   - a) Full B-tree index on `status`
   - b) Partial index: `CREATE INDEX ON orders(status) WHERE status = 'pending'`
   - c) Hash index on `status`
   - d) No index — the column has too few distinct values

5. An e-commerce site stores product reviews. Reads are 100:1 over writes. The "product page" query joins products, reviews, and users tables. Which optimization should you try FIRST?

   - a) Denormalize reviews into the product document
   - b) Switch to MongoDB
   - c) Add composite indexes on the join columns
   - d) Add a Redis cache layer

6. You need to support both "lookup user by ID" (90% of queries) and "search users by email" (10% of queries). Users are sharded by user_id. How do you handle email lookups?

   - a) Scatter-gather across all shards for every email query
   - b) Maintain a secondary index: email → user_id in a separate table/service
   - c) Shard by email instead of user_id
   - d) Store users in both SQL (by ID) and MongoDB (by email)

7. Which scenario is the WORST fit for denormalization?

   - a) A read-heavy dashboard that joins 6 tables
   - b) A write-heavy system where the denormalized fields change 1,000 times/sec
   - c) A sharded database where cross-shard joins are impossible
   - d) A caching layer that needs to store complete records

### Short Answer (3 points)

8. Explain what a materialized view is and how it differs from both a regular view and a denormalized table. When would you choose a materialized view over denormalization?

9. You run `EXPLAIN ANALYZE` on a slow query and see "Seq Scan on users (rows=10000000)". The query is `WHERE email = 'bob@example.com'`. Diagnose the problem and provide the fix.

10. A startup uses PostgreSQL and is happy with it at 5,000 QPS. They're projecting 50,000 QPS in a year. Walk through the optimization sequence: what would you try first, second, third, and at what point would you consider adding a different database type?

<details>
<summary>Answer Key</summary>

1. **polyglot**
2. **leftmost** (or "left")
3. **N+1** (or "N+1 query")
4. **b)** — A partial index on `WHERE status = 'pending'` is ideal. It indexes only the ~5% of rows you care about, making it tiny and fast. A full index on `status` would include all 10M rows but only has 3 distinct values — low selectivity makes it less useful. A partial index is perfect for "query a small subset of rows that match a specific condition."
5. **c)** — Always optimize SQL before making architectural changes. Proper composite indexes on join columns (e.g., `reviews.product_id`, `reviews.user_id`) can make the join orders of magnitude faster. If indexing doesn't solve it, then consider caching (d) or denormalization (a). Switching to MongoDB (b) is the most disruptive option and should be last.
6. **b)** — A secondary index mapping email → user_id is the standard approach. It's a small table (two columns), can be replicated everywhere or stored in a separate lightweight service, and converts an O(shards) scatter-gather into an O(1) lookup + O(1) shard query. Scatter-gather (a) works but is slow and expensive at scale. Sharding by email (c) would break the 90% of queries by user_id.
7. **b)** — Denormalization duplicates data, so every write to the source must update all copies. At 1,000 writes/second to the same field, you'd be writing to potentially millions of denormalized rows continuously. The write amplification would crush performance. Denormalization works best for read-heavy, write-light data.
8. A regular view is just a saved query — it executes the full query every time you read from it (no performance benefit for complex joins). A materialized view stores the query results as a physical table on disk. It's faster to read (like a denormalized table) but must be refreshed to see new data. Unlike manual denormalization, the database manages the materialized view — you define the query once and call REFRESH. Choose materialized views over denormalization when: (a) you want the database to manage the denormalized data, (b) you can tolerate slightly stale data between refreshes, and (c) you don't want to handle write amplification in application code.
9. The query is doing a full sequential scan of 10M rows to find one email. There's no index on the `email` column. Fix: `CREATE INDEX idx_users_email ON users(email);` If email lookups are always exact-match (not LIKE or pattern), a hash index would also work: `CREATE INDEX idx_users_email ON users USING hash(email);` After adding the index, the EXPLAIN should show "Index Scan" or "Index Only Scan" instead of "Seq Scan."
10. Optimization sequence: (1) **Indexes** — Ensure all frequently-queried columns are indexed. This alone can take you from 5K to 20K+ QPS by eliminating full table scans. (2) **Connection pooling** — Ensure you're using PgBouncer or similar. Eliminates connection creation overhead. (3) **Read replicas** — Add 1-3 PostgreSQL replicas for read traffic. At a 10:1 read:write ratio, this 10x your read capacity. (4) **Caching (Redis)** — Cache hot queries. At 95% hit rate, your database sees 5% of read traffic. This alone can handle 50K+ QPS. (5) **Query optimization** — Fix N+1 queries, denormalize specific views, add materialized views. At this point you're likely handling 50K QPS without changing databases. (6) **Only then** consider adding NoSQL for specific use cases (e.g., Redis for sessions, Cassandra for time-series data). (7) **Sharding PostgreSQL** (via Citus or application-level) only if writes become the bottleneck.

</details>

---

## Challenge Mission: "The Query Optimizer"

### Scenario

You're investigating a slow dashboard at an e-commerce company. The dashboard shows: recent orders, customer info, and product details.

**The Schema:**
```sql
CREATE TABLE users (
    id BIGINT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(255),
    country VARCHAR(2),
    created_at TIMESTAMP
);  -- 5 million rows

CREATE TABLE orders (
    id BIGINT PRIMARY KEY,
    user_id BIGINT REFERENCES users(id),
    status VARCHAR(20),  -- 'pending', 'shipped', 'delivered', 'cancelled'
    total DECIMAL(10,2),
    created_at TIMESTAMP
);  -- 50 million rows

CREATE TABLE order_items (
    id BIGINT PRIMARY KEY,
    order_id BIGINT REFERENCES orders(id),
    product_id BIGINT REFERENCES products(id),
    quantity INT,
    price DECIMAL(10,2)
);  -- 200 million rows

CREATE TABLE products (
    id BIGINT PRIMARY KEY,
    name VARCHAR(200),
    category VARCHAR(50),
    price DECIMAL(10,2)
);  -- 500,000 rows
```

**The Slow Query:**
```sql
SELECT u.name, u.email, o.id as order_id, o.total, o.status,
       p.name as product_name, oi.quantity, oi.price
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN order_items oi ON oi.order_id = o.id
JOIN products p ON oi.product_id = p.id
WHERE o.status = 'pending'
  AND o.created_at > NOW() - INTERVAL '7 days'
ORDER BY o.created_at DESC
LIMIT 100;
```

**Current EXPLAIN output:**
```
Sort (actual time=12847.32..12847.35 rows=100)
  Sort Key: o.created_at DESC
  -> Nested Loop (actual time=0.87..12843.21 rows=15234)
       -> Nested Loop (actual time=0.52..8924.11 rows=15234)
            -> Nested Loop (actual time=0.31..3201.44 rows=8432)
                 -> Seq Scan on orders o (actual time=0.12..2891.33 rows=8432)
                       Filter: (status = 'pending' AND created_at > '2026-03-09')
                       Rows Removed by Filter: 49991568
                 -> Index Scan on users u (actual time=0.02..0.03 rows=1)
            -> Index Scan on order_items oi (actual time=0.05..0.68 rows=2)
       -> Index Scan on products p (actual time=0.01..0.02 rows=1)
```

**The query takes 12.8 seconds.** The dashboard times out.

### Your Task

1. **Diagnose:** Identify every performance problem in the EXPLAIN output. What's the bottleneck?
2. **Fix with indexes:** Write the exact CREATE INDEX statements that would fix this query. Explain why each index helps.
3. **Estimate improvement:** What should the query time drop to after your indexes?
4. **Consider denormalization:** If indexes aren't enough, design a denormalized table or materialized view for this dashboard. What are the trade-offs?
5. **Long-term:** At 500M orders (10x growth), will your solution still work? What changes?

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 2:

- **Polyglot persistence** — Using different database types for different use cases within one application.
- **Denormalization** — Intentionally duplicating data to eliminate joins and improve read performance.
- **Materialized view** — A precomputed query result stored as a physical table. Must be refreshed periodically.
- **B-tree index** — Default index type in most databases. Supports equality, range queries, and sorting. O(log N) lookup.
- **Composite index** — Index on multiple columns. Follows the leftmost prefix rule.
- **N+1 query problem** — Loading N records triggers N additional queries (one per record) instead of a single batch query.
- **Connection pooling** — Reusing database connections across requests to avoid the overhead of creating new connections.
- **EXPLAIN** — Database command that shows the query execution plan, revealing which indexes are used and where time is spent.
