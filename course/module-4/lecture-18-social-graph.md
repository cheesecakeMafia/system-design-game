# Lecture 18: Design a Social Network Graph — Peer Review

> Module 4 — "The Architect's Trial" | Lecture 18 of 20

**Format: Peer Review.** This lecture is different. Instead of designing from scratch, you'll review a **flawed design** for a social network's graph feature. Your job: find the bugs, missing components, and scalability problems, then fix them.

Reviewing others' designs builds a different muscle than creating from scratch. It trains you to spot anti-patterns — a skill that's equally valuable in interviews and code reviews.

---

## Reference Solution

After completing your review, compare with: [Social Graph Reference Solution](../../deps/system-design-primer/solutions/system_design/social_graph/README.md)

---

## The Problem

Design the social graph for a platform like Facebook/LinkedIn:
- Users can follow/friend other users
- "People you may know" suggestions
- Find the shortest path between two users (degrees of separation)
- 500M users, average 200 connections each

---

## The Flawed Design

A junior engineer designed this system. It works for 1,000 users but won't scale. Your job: find every problem and propose fixes.

### Their Architecture

```
Client → API Server (single instance) → PostgreSQL (single instance)
```

### Their Database Schema

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(255)
);

CREATE TABLE friendships (
    user_id INT REFERENCES users(id),
    friend_id INT REFERENCES users(id),
    created_at TIMESTAMP,
    PRIMARY KEY (user_id, friend_id)
);
```

### Their API

```
GET /friends/:user_id → Returns all friends (SELECT * FROM friendships WHERE user_id = :id)
GET /mutual/:user_id_1/:user_id_2 → Returns mutual friends
GET /path/:user_id_1/:user_id_2 → Returns shortest path (BFS in application code)
GET /suggestions/:user_id → Returns "people you may know" (friends of friends not already friends)
```

### Their "People You May Know" Query

```sql
SELECT DISTINCT f2.friend_id
FROM friendships f1
JOIN friendships f2 ON f1.friend_id = f2.user_id
WHERE f1.user_id = :target_user
  AND f2.friend_id != :target_user
  AND f2.friend_id NOT IN (
      SELECT friend_id FROM friendships WHERE user_id = :target_user
  )
LIMIT 20;
```

### Their Shortest Path Algorithm

```python
def shortest_path(user_a, user_b):
    visited = set()
    queue = [(user_a, [user_a])]
    while queue:
        current, path = queue.pop(0)
        if current == user_b:
            return path
        visited.add(current)
        friends = db.query("SELECT friend_id FROM friendships WHERE user_id = %s", current)
        for friend in friends:
            if friend not in visited:
                queue.append((friend, path + [friend]))
    return None  # no path found
```

---

## Your Review

### Part 1: Architecture Problems

Find at least 5 problems with the overall architecture and propose fixes.

```
Problem 1: _______________
Fix: _______________

Problem 2: _______________
Fix: _______________

(continue for all problems you find)
```

<details>
<summary>Problems to find</summary>

1. **Single API server** — No redundancy, no horizontal scaling. Fix: multiple instances behind a load balancer.
2. **Single PostgreSQL instance** — Single point of failure, will hit capacity. Fix: read replicas for reads, consider sharding for 500M users.
3. **No caching** — Every request hits the database. Friend lists are read-heavy and change infrequently. Fix: Redis cache for friend lists.
4. **No rate limiting** — API is open to abuse. Fix: rate limiting at the API gateway.
5. **No async processing** — "People you may know" is computed synchronously per request. Fix: precompute suggestions in a background job.
6. **No CDN or reverse proxy** — Missing basic infrastructure.
7. **Serial INT primary key** — `SERIAL` won't work across shards. Fix: use UUIDs or snowflake IDs.
</details>

### Part 2: Schema Problems

Find problems with the database schema for a 500M-user social graph.

```
Problem 1: _______________
Fix: _______________

(continue)
```

<details>
<summary>Problems to find</summary>

1. **Friendships table is unidirectional** — If Alice friends Bob, only `(Alice, Bob)` is stored. Querying Bob's friends requires `WHERE friend_id = Bob` (no index on friend_id). Fix: store both directions `(Alice, Bob)` AND `(Bob, Alice)`, or add an index on `friend_id`.
2. **No index on friend_id** — The query `WHERE friend_id = :id` does a full table scan on 100B rows. Fix: add index, or store bidirectional.
3. **100 billion rows** — 500M users × 200 friends = 100B friendship rows. A single PostgreSQL instance can't handle this. Fix: shard the friendships table by user_id.
4. **No connection metadata** — Real friendships have types (close friend, acquaintance, blocked). Fix: add a `type` or `strength` column.
5. **SQL for graph traversal** — SQL JOINs for graph operations (BFS, shortest path) are extremely expensive at scale. Fix: consider a graph database (Neo4j) for traversal queries, keep PostgreSQL for basic CRUD.
</details>

### Part 3: Query Problems

Analyze the "People You May Know" query. What's wrong at 500M users?

```
Problem: _______________
Estimated query time at scale: _______________
Fix: _______________
```

<details>
<summary>Problems to find</summary>

1. **The query is O(friends × friends_of_friends)** — For a user with 200 friends, each having 200 friends: 200 × 200 = 40,000 candidate rows, minus existing friends. Seems okay? But the `NOT IN` subquery scans the user's friendship list for each candidate. With proper indexes, it's manageable for one user but...
2. **It's computed on every request** — This expensive query runs every time a user loads their suggestions. At 500M users hitting this endpoint, the database melts.
3. **Fix:** Precompute suggestions in a batch job. Run nightly (or on friendship changes). Store the top 20 suggestions per user in a fast-access store (Redis or precomputed table). The API reads from the precomputed store — zero database load at read time.
4. **Better fix at scale:** Use a graph database or dedicated recommendation engine. Graph traversal (friends-of-friends) is what graph databases are optimized for.
</details>

### Part 4: Algorithm Problems

Review the shortest-path BFS implementation.

```
Problem 1: _______________
Problem 2: _______________
Problem 3: _______________
Proposed fix: _______________
```

<details>
<summary>Problems to find</summary>

1. **Database query per BFS step** — Each step of the BFS fires a SQL query. For 6 degrees of separation with 200 friends per hop, that's potentially hundreds of thousands of queries. Fix: batch queries, or use a graph database that does traversal natively.
2. **Unbounded BFS** — No depth limit. If user_a and user_b aren't connected, this explores the entire graph (500M nodes). Fix: limit depth to 3-4 hops. Beyond that, users aren't meaningfully connected.
3. **Single-direction BFS** — Searches from A to B. Bidirectional BFS (search from both ends, meet in the middle) is exponentially faster for graph search. Fix: implement bidirectional BFS.
4. **In-memory visited set** — At scale, the visited set grows to millions of entries per query. Fix: use a Bloom filter for visited checks (probabilistic but memory-efficient).
5. **No caching** — The path between two popular users is queried repeatedly. Fix: cache path results with a TTL.
</details>

### Part 5: Your Improved Design

Redesign the system to handle 500M users. Include:
1. Your architecture diagram
2. Your database choice(s) and schema
3. How you handle "people you may know"
4. How you handle shortest path
5. Caching strategy

---

## Self-Assessment

| Category | Problems Found | Reference Count |
|----------|---------------|----------------|
| Architecture problems | /7 | 7 |
| Schema problems | /5 | 5 |
| Query problems | /3 | 3 |
| Algorithm problems | /5 | 5 |

Record your score in [progress.md](../progress.md).
