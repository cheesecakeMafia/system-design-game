# Lecture 6: RDBMS Deep Dive + Consistent Hashing

> Module 2 — "The Data Fortress" | Lecture 6 of 20

Welcome to Module 2. From here on, everything gets harder — because the data layer is where most system design complexity lives. This lecture covers how relational databases scale beyond a single server, and introduces consistent hashing — one of the most elegant algorithms in distributed systems.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Relational database management system (RDBMS)*
- *Master-slave replication*
- *Master-master replication*
- *Federation*
- *Sharding*

**OOD Exercise (optional but recommended):** Work through the Hash Map notebook at [`../../deps/system-design-primer/solutions/object_oriented_design/hash_table/hash_map.ipynb`](../../deps/system-design-primer/solutions/object_oriented_design/hash_table/hash_map.ipynb) before this lecture. Implementing a hash table yourself makes consistent hashing much more intuitive.

---

## Concept Briefing

### CAP Theorem Primer — A 10-Minute Foundation

Before we dive into database scaling, you need a mental model for the fundamental tension in distributed data systems. We'll go deep on CAP in Lecture 11 — but you need this foundation now because every replication and sharding decision involves this trade-off.

**The CAP Theorem states:** A distributed data store can provide at most two of these three guarantees simultaneously:

- **Consistency** — Every read returns the most recent write (all nodes see the same data at the same time)
- **Availability** — Every request receives a response (no timeouts, no errors)
- **Partition Tolerance** — The system continues operating despite network failures between nodes

**The catch:** Network partitions are inevitable in any distributed system. You can't choose to "not have partitions." So the real choice is between **C** and **A** when a partition happens:

- **CP system** — During a partition, refuses to serve potentially stale data. Returns errors until partition heals. (Example: HBase, MongoDB with strong reads)
- **AP system** — During a partition, serves potentially stale data rather than returning errors. (Example: Cassandra, DynamoDB in eventual consistency mode)

**Why this matters right now:** When we discuss replication below, you'll see that replication lag creates a window where replicas have stale data. This is the CAP trade-off in action — you're choosing availability (serve from replica even if slightly stale) over consistency (only serve if guaranteed fresh).

Hold this mental model. We'll go much deeper in Module 3.

---

## Deep Dive

### ACID — What Each Letter Really Means

You probably know ACID stands for Atomicity, Consistency, Isolation, Durability. But what do they mean in practice?

**Atomicity** — A transaction is all-or-nothing. If any part fails, the entire transaction rolls back. Transfer $100 from Account A to Account B? Either both the debit and credit happen, or neither does. There's no state where the money left A but didn't arrive at B.

**Consistency** — The database moves from one valid state to another. Constraints (foreign keys, unique indexes, check constraints) are always satisfied. If a transaction would violate a constraint, it's rejected.

**Isolation** — Concurrent transactions don't interfere with each other. The result is the same as if they ran sequentially. In practice, databases offer different isolation levels (read uncommitted, read committed, repeatable read, serializable) that trade correctness for performance.

**Durability** — Once a transaction is committed, it survives crashes. The data is written to non-volatile storage (disk). Even if the power goes out 1ms after commit, the data is safe.

**Why this matters for system design:** ACID guarantees are expensive. They require coordination (locks, write-ahead logs, fsync). As you distribute data across multiple servers, maintaining ACID becomes exponentially harder — which is why NoSQL databases (Lecture 7) often relax these guarantees.

### Master-Slave Replication

The simplest way to scale reads: copy the data to multiple servers.

```
         Writes
Client ────────► Master (Primary)
                    │
                    │ Replication stream
                    ├─────────► Slave 1 (Replica) ◄── Reads
                    └─────────► Slave 2 (Replica) ◄── Reads
```

**How it works:**
1. All writes go to the master
2. The master writes changes to a replication log (binlog in MySQL, WAL in PostgreSQL)
3. Slaves continuously read the log and apply changes
4. Reads can go to any slave (or the master)

**Replication lag:** The time between a write on the master and the data appearing on the slave. Typically milliseconds, but can spike to seconds or minutes under heavy load.

| Pros | Cons |
|------|------|
| Read throughput scales linearly with replicas | Writes are limited to one server (master) |
| Simple to set up and understand | Replication lag → stale reads from replicas |
| Master failure → promote a slave | Promoting a slave risks data loss (unreplicated writes) |
| Can use replicas for analytics, backups | More replicas = more replication load on master |

**The stale read problem:** User writes a comment, immediately refreshes the page, and the comment isn't there — because the read hit a slave that hasn't received the write yet. Solutions:
- **Read-your-writes consistency** — Route the user's reads to the master for N seconds after they write
- **Synchronous replication** — Wait for at least one slave to confirm before acknowledging the write (but adds latency)
- **Version tokens** — Client includes a version number; if the slave is behind, redirect to master

### Master-Master Replication

Both servers accept writes. Each replicates to the other.

```
Client A ──► Master 1 ◄──────────► Master 2 ◄── Client B
             (writes)  replication  (writes)
```

| Pros | Cons |
|------|------|
| Write availability — if one master dies, the other handles writes | Conflict resolution is HARD |
| Can distribute writes geographically | Increased latency (cross-datacenter replication) |
| No single point of failure for writes | Complex configuration |

**The conflict problem:** Client A updates row X on Master 1. Client B updates the same row X on Master 2 at the same time. When they replicate to each other, which write wins?

Conflict resolution strategies:
- **Last-write-wins (LWW)** — Timestamp-based. Simple but can lose data.
- **Application-level resolution** — The application decides how to merge (complex but correct).
- **Avoid conflicts by partitioning** — Each master "owns" certain data. Eliminates conflicts but limits flexibility.

**When to use:** Multi-region deployments where you need low-latency writes from multiple geographies. Otherwise, master-slave is simpler and avoids conflict headaches.

### Federation (Functional Partitioning)

Split the database by function — each feature gets its own database.

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Users DB     │  │ Products DB  │  │ Orders DB    │
│ (users,      │  │ (products,   │  │ (orders,     │
│  profiles)   │  │  categories) │  │  line_items) │
└──────────────┘  └──────────────┘  └──────────────┘
```

| Pros | Cons |
|------|------|
| Each DB handles less load | Joins across databases are impossible (or very expensive) |
| Independent scaling per function | Application must manage multiple DB connections |
| Failure isolation — Users DB crash ≠ Orders crash | Cross-function transactions are very complex |
| Simpler per-DB schemas | Data duplication may be needed |

**When to use:** When different features have clearly separated data with minimal cross-references. If Users and Orders share 15 tables, federation between them is painful (recall the Monolith Splitter from Lecture 5).

### Sharding (Horizontal Partitioning)

Split the same table across multiple databases, each holding a subset of rows.

```
User table (1 billion rows):

┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ Shard 0  │  │ Shard 1  │  │ Shard 2  │  │ Shard 3  │
│ Users    │  │ Users    │  │ Users    │  │ Users    │
│ 0-250M   │  │ 250M-500M│  │ 500M-750M│  │ 750M-1B  │
└──────────┘  └──────────┘  └──────────┘  └──────────┘
```

#### Sharding Strategies

**Hash-based sharding:**
```
shard_id = hash(shard_key) % num_shards
```
Even distribution, but adding/removing shards requires rehashing everything (unless you use consistent hashing — see below).

**Range-based sharding:**
```
Shard 0: users with last names A-F
Shard 1: users with last names G-M
...
```
Natural for time-series data (shard by month), but can create hot spots (the "S" shard in English names is much bigger).

**Directory-based sharding:**
A lookup service maps each key to its shard.
```
Directory: user_42 → Shard 2, user_99 → Shard 0, ...
```
Maximum flexibility but the directory is a single point of failure and a potential bottleneck.

#### Sharding Challenges

| Challenge | Description |
|-----------|-------------|
| **Cross-shard queries** | `SELECT * FROM users WHERE email = 'x'` — if sharded by user_id, you must query ALL shards |
| **Cross-shard joins** | Joining users and orders on different shards requires application-level logic |
| **Rebalancing** | Adding shards with hash-based sharding reshuffles most data |
| **Referential integrity** | Foreign keys don't work across shards |
| **Operational complexity** | Backups, migrations, schema changes multiply by shard count |

---

### Consistent Hashing — The Deep Dive

This is one of the most important algorithms in distributed systems. It solves the fundamental problem of hash-based sharding: **when you add or remove a node, almost all keys need to move.**

#### The Problem with Simple Hashing

With `shard = hash(key) % N`:
- 3 servers: `hash("user_42") % 3 = 1` → Server 1
- Add a 4th server: `hash("user_42") % 4 = 2` → Server 2

The user moved! In fact, with simple modulo hashing, adding one server redistributes approximately `(N-1)/N` of all keys. With 100 servers, adding one more moves ~99% of data. This is catastrophic for cache servers (massive cache miss storm) and expensive for database shards.

#### The Ring

Consistent hashing places both servers and keys on a circular hash space (a ring):

```
            0 / 2^32
              │
     ┌────────┼────────┐
     │                  │
   Server A           Server B
     │                  │
     │    key_1  key_2  │
     │                  │
     └────────┼────────┘
              │
           Server C
```

**How it works:**
1. Hash each server's name/IP to a position on the ring
2. Hash each key to a position on the ring
3. Walk clockwise from the key's position until you hit a server — that server owns the key

**When you add a server:** Only keys between the new server and its predecessor (counterclockwise) need to move. All other keys stay put.

**When you remove a server:** Only keys that were assigned to the removed server need to move to the next server clockwise.

Result: Adding or removing a server only moves approximately `K/N` keys (where K is total keys and N is total servers). With 100 servers, adding one moves only ~1% of keys instead of ~99%.

#### Virtual Nodes — Why They're Essential

With just physical servers on the ring, distribution is uneven — one server might "own" a huge arc while another owns a tiny one.

**Virtual nodes** solve this: each physical server is represented by multiple points on the ring.

```
Server A → positions: A1, A2, A3, A4, A5 (5 virtual nodes)
Server B → positions: B1, B2, B3, B4, B5
Server C → positions: C1, C2, C3, C4, C5
```

With 100-200 virtual nodes per physical server, the distribution becomes very even. You can also use different numbers of virtual nodes for servers with different capacities (a beefy server gets 200 virtual nodes, a smaller one gets 50).

#### Adding/Removing Nodes — Minimal Redistribution

**Adding Server D:**
```
Before: key_x → Server A (next clockwise)
After:  key_x → Server D (D is now between key_x and A)
```
Only keys in the arc between D and the server before D (counterclockwise) move. Everything else stays.

**Removing Server B:**
```
Before: key_y → Server B
After:  key_y → Server C (next clockwise after B's position)
```
Only keys that were on Server B move to Server C. Everything else stays.

#### Shard Rebalancing — The Hard Problem

Consistent hashing minimizes which keys need to move, but the actual movement is still hard:
- **Data transfer** — Moving GBs or TBs of data takes time
- **During transfer** — Which server serves requests for data in transit?
- **Consistency** — What if data is written to the old shard while being transferred?
- **Backfill** — After the move, indexes need to be rebuilt on the new shard

Real-world approach: **gradual migration**. Mark data as "migrating," serve reads from both old and new shard (prefer new), write to both, then cut over. This is operationally complex and is one reason teams avoid resharding unless absolutely necessary.

#### Applications of Consistent Hashing

| Use Case | How It's Used |
|----------|---------------|
| **Database sharding** | Assign rows to shards. Minimize data movement when adding shards. |
| **Cache distribution** | Which Memcached/Redis server holds a given key? (Lecture 9) |
| **Load balancing** | Route requests to servers. When a server dies, only its traffic redistributes. |
| **Content distribution** | Which CDN node caches a given URL? |

### Real-World Examples

| Technology | Feature |
|-----------|---------|
| **MySQL** | Master-slave replication (binlog), Group Replication for multi-master |
| **PostgreSQL** | Streaming replication, logical replication, partitioning (native since v10) |
| **Vitess** | Horizontal sharding layer for MySQL (used by YouTube, Slack, Square) |
| **CockroachDB** | Distributed SQL that handles sharding automatically |
| **Amazon Aurora** | MySQL/PostgreSQL compatible with storage-level replication (up to 15 replicas) |

---

## Discussion Prompts

1. **You have a users table with 500 million rows, sharded by user_id. A product manager asks for a report: "How many users signed up from each country last month?" How do you answer this query?** What makes cross-shard analytics hard, and what are the common solutions?

2. **Replication lag on your read replica spikes to 30 seconds during peak load. A user updates their profile, then immediately views it and sees the old data. They file a bug report. Is this a bug?** How would you explain this to the product manager, and what's your fix?

3. **Your 4-shard database is at 80% capacity. You want to add 2 more shards. With consistent hashing and 100 virtual nodes per shard, approximately what percentage of data needs to move?** How long would the migration take if each shard holds 500 GB and your network can transfer 1 Gbps?

---

## Field Ops: Server Survival

In the game, the **SQL DB** service handles `READ`, `WRITE`, and `SEARCH` traffic.

Observe:
- What happens when you have only one SQL DB and write-heavy traffic arrives?
- If you could "shard" the SQL DB (place multiple instances), each would handle a subset of traffic — that's exactly what database sharding does
- Notice how the SQL DB's health degrades under load. In a real system, this is when you'd add read replicas or shards

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. In master-slave replication, all ______ go to the master, while ______ can be served by any replica.

2. The time delay between a write on the master and the data appearing on a replica is called replication ______.

3. In consistent hashing, each physical server is represented by multiple ______ on the ring to ensure even key distribution.

### Multiple Choice (4 points)

4. You have 10 cache servers using simple modulo hashing (`hash(key) % 10`). You add an 11th server. Approximately what percentage of cached keys become invalid (mapped to a different server)?

   - a) ~10%
   - b) ~50%
   - c) ~90%
   - d) 100%

5. A user writes a comment, then immediately reads the page. The read is routed to a slave with 2 seconds of replication lag. What happens?

   - a) The comment appears correctly — replicas are always up to date
   - b) The comment doesn't appear — the slave hasn't received the write yet
   - c) The system returns an error
   - d) The slave fetches the comment from the master automatically

6. You shard a users table by `user_id`. A query asks: `SELECT * FROM users WHERE email = 'bob@example.com'`. What happens?

   - a) The query runs on one shard efficiently
   - b) The query must run on ALL shards (scatter-gather)
   - c) The query fails because email isn't the shard key
   - d) The query is automatically redirected to the correct shard

7. In the CAP theorem, when a network partition occurs, a CP system will:

   - a) Continue serving all requests with potentially stale data
   - b) Refuse to serve requests that might return stale data
   - c) Automatically heal the partition
   - d) Switch from master to slave

### Short Answer (3 points)

8. Explain why adding a server with consistent hashing moves approximately K/N keys, while adding a server with modulo hashing moves approximately (N-1)/N of all keys. Use a concrete example with 4 servers.

9. Your e-commerce database uses master-slave replication with 1 master and 3 slaves. The master handles 2,000 write QPS and each slave handles 10,000 read QPS. What is the total read capacity? If you need to handle 50,000 read QPS, how many slaves do you add?

10. Describe a scenario where master-master replication creates a data conflict. What is the conflict, and how would last-write-wins resolve it? What data could be lost?

<details>
<summary>Answer Key</summary>

1. **writes** / **reads**
2. **lag**
3. **virtual nodes** (or "vnodes")
4. **c) ~90%** — With modulo hashing, changing N from 10 to 11 changes the result for approximately (N-1)/N = 9/10 = 90% of keys. Only keys where `hash(key) % 10 == hash(key) % 11` keep their assignment.
5. **b)** — The slave hasn't received the write yet due to replication lag. The user won't see their comment. This is the "read-your-writes consistency" problem — a common real-world issue with master-slave replication.
6. **b)** — Since the table is sharded by `user_id`, the system has no way to know which shard holds `bob@example.com` without checking all of them. This "scatter-gather" query hits every shard, combines results, and returns. It's much slower than a query on the shard key. Solution: maintain a secondary index (email → user_id mapping) or a global email-to-shard lookup table.
7. **b)** — CP systems choose consistency over availability. During a partition, they refuse to serve data that might be stale, returning errors instead. This ensures that any data served is guaranteed to be the latest version.
8. With modulo hashing and 4 servers: `hash(key) % 4`. Adding a 5th: `hash(key) % 5`. For a key with hash value 7: old = 7%4=3, new = 7%5=2 → moved. For hash value 8: old = 8%4=0, new = 8%5=3 → moved. Approximately 3/4 (75%) of keys change server. With consistent hashing: adding a 5th server only takes keys from its neighbors on the ring — approximately 1/5 (20%) of keys move. The ring structure means only the arc between the new node and its predecessor is affected.
9. Total read capacity: 3 slaves × 10,000 QPS = 30,000 read QPS. For 50,000 read QPS: need 50,000 / 10,000 = 5 slaves. Currently have 3, so add 2 more slaves. Note: the master is also saturated at 2,000 write QPS — if writes also need to scale, you'd need sharding since replicas don't help with writes.
10. Scenario: User updates their email on Master 1 to "new@example.com" at timestamp T1. At the same moment (T1), an admin on Master 2 updates the same user's email to "admin@example.com" due to a support request. When the masters replicate to each other, both have conflicting updates for the same field. Last-write-wins (LWW) picks the update with the later timestamp — say the admin's update at T1+1ms wins. The user's intended email change is silently lost, and the user doesn't know their change was overwritten. This is why LWW is called "last-write-wins, data-loses."

</details>

---

## Challenge Mission: "The Shard Puzzle"

### Scenario

You're designing the database architecture for a social platform with the following data:
- **500 million users** (growing 2% per month)
- **User record:** user_id (bigint), username (varchar), email (varchar), country (varchar), created_at (timestamp), profile_data (JSON, ~2 KB average)
- **Queries:** 80% by user_id, 15% by email, 5% by country

Current single-server database is at 90% capacity. You've decided to shard across 5 nodes using consistent hashing.

### Your Task

**Part 1 — Sharding Key Selection**

1. Choose your sharding key. Why this key over alternatives?
2. What percentage of queries will be efficient (single-shard) vs scatter-gather?
3. How do you handle the 15% of queries by email?

**Part 2 — The Hash Ring**

1. Draw (or describe) your consistent hash ring with 5 nodes and 100 virtual nodes each.
2. Approximately how many users are on each shard? Is the distribution even?
3. One node is 2x more powerful than the others. How do you give it a proportionally larger share?

**Part 3 — Failure Scenario**

Node 3 crashes and is unrecoverable.

1. Which keys move, and where do they go?
2. How many users are affected?
3. What happens to requests for users that were on Node 3 during the recovery period?
4. How do you rebuild Node 3 from backup?

**Part 4 — Growth Planning**

Six months later, the database is at 80% capacity again. You need to add 2 more nodes (total 7).

1. With consistent hashing, approximately what percentage of data needs to move?
2. Estimate the data transfer: each node holds ~200 GB. How long does migration take at 500 MB/s transfer speed?
3. Design a migration plan that doesn't cause downtime. How do you handle reads/writes during migration?

### Constraints

- Zero downtime during normal operations
- Maximum acceptable replication lag: 5 seconds
- Each shard must have at least 1 read replica
- Cross-shard queries must complete within 500ms

### Hints

<details>
<summary>Hint 1: Email queries</summary>
Consider maintaining a separate lookup table that maps email → user_id. This table is small (just two columns) and can either be replicated to all shards or stored in a separate lightweight database.
</details>

<details>
<summary>Hint 2: Data migration math</summary>
Adding 2 nodes to 5 with consistent hashing moves approximately 2/7 ≈ 29% of data. That's 200 GB × 5 nodes × 29% ≈ 290 GB to transfer. At 500 MB/s, that's ~580 seconds (~10 minutes) for raw transfer. But you also need to rebuild indexes and handle writes during migration.
</details>

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 2:

- **ACID** — Atomicity, Consistency, Isolation, Durability. Guarantees of relational database transactions.
- **CAP Theorem** — A distributed system can provide at most two of: Consistency, Availability, Partition Tolerance.
- **Master-slave replication** — One write server (master) replicates to read-only servers (slaves/replicas).
- **Replication lag** — Delay between a write on the master and its appearance on a replica.
- **Master-master replication** — Multiple servers accept writes and replicate to each other. Requires conflict resolution.
- **Federation** — Splitting databases by function (users DB, orders DB, etc.).
- **Sharding** — Splitting a table's rows across multiple databases, each holding a subset.
- **Shard key** — The column used to determine which shard holds a given row.
- **Consistent hashing** — Algorithm using a hash ring to distribute keys across nodes. Minimizes redistribution when nodes change.
- **Virtual nodes** — Multiple points on the hash ring per physical server, ensuring even distribution.
- **Scatter-gather** — Query pattern where a request is sent to all shards and results are combined.
