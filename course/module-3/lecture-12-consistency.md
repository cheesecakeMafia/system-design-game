# Lecture 12: Consistency Patterns

> Module 3 — "The Distributed Mind" | Lecture 12 of 20

CAP told you the *what*: you must choose between consistency and availability during partitions. This lecture covers the *how*: the spectrum of consistency models from "always correct" to "eventually maybe correct," and how to pick the right level for each part of your system.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Consistency patterns*
- *Weak consistency*
- *Eventual consistency*
- *Strong consistency*

---

## Deep Dive

### The Consistency Spectrum

Consistency isn't binary. It's a spectrum from strongest (most expensive, most correct) to weakest (cheapest, least guarantees):

```
Strongest ◄──────────────────────────────────────────────► Weakest

Linearizability → Sequential → Causal → Read-your-writes → Eventual → Weak
    │                                         │                 │
    │                                         │                 │
 "Always correct"                    "You see your         "Eventually
  Expensive, slow"                    own writes"           correct"
```

### Strong Consistency (Linearizability)

**Guarantee:** Every read returns the most recent completed write. All nodes appear to have the same data at the same time.

**How it works:** Typically requires consensus protocols (Paxos, Raft) where a majority of nodes must agree before a write is acknowledged.

```
Time →
Writer: write X=5 ──────────────── ACK (majority confirmed)
Reader:                                           read X → 5 ✓
                                                  (guaranteed to see 5)
```

**Cost:**
- Latency: each write requires round trips to multiple nodes (quorum)
- Throughput: limited by the slowest node in the quorum
- Availability: requires majority of nodes to be reachable

| Use | Example |
|-----|---------|
| Distributed locks | Zookeeper, etcd — a lock must be consistent or it's useless |
| Leader election | Only one node should believe it's the leader |
| Financial transactions | A bank balance must reflect all completed transfers |
| Inventory | Can't sell the last item twice |

### Eventual Consistency

**Guarantee:** If no new writes occur, all replicas will *eventually* converge to the same value. No guarantee about when, or what you'll see in the meantime.

**How it works:** Writes are accepted at any replica. Replicas exchange updates asynchronously. Conflicts are resolved when discovered.

```
Time →
Writer writes X=5 to Replica A
Replica A: X=5
Replica B: X=3 (stale — hasn't received update yet)
Replica C: X=3 (stale)
...
[replication propagates]
...
Replica A: X=5
Replica B: X=5 ✓ (converged)
Replica C: X=5 ✓ (converged)
```

**The "convergence window"** — the time between a write and all replicas having the update — depends on replication lag. Typically milliseconds to seconds, but can be minutes under load.

**Conflict resolution:** What if two replicas receive different writes to the same key before syncing?

| Strategy | How It Works | Risk |
|----------|-------------|------|
| **Last-write-wins (LWW)** | Timestamp-based; highest timestamp wins | Clock skew can pick the wrong "last" write |
| **Vector clocks** | Track causality; detect concurrent writes | More complex; can still require application-level merge |
| **CRDTs** | Data structures that automatically merge without conflicts | Limited to specific data types (counters, sets, registers) |
| **Application-level** | Application logic decides how to merge | Most flexible but most development effort |

**CRDTs (Conflict-free Replicated Data Types)** deserve special mention — they're data structures mathematically guaranteed to converge without coordination:
- **G-Counter** — Grow-only counter (each node increments its own counter; total = sum)
- **PN-Counter** — Positive-negative counter (two G-Counters: one for increments, one for decrements)
- **G-Set** — Grow-only set (add only, no remove)
- **OR-Set** — Observed-remove set (add and remove with proper merge semantics)

### Weak Consistency

**Guarantee:** After a write, there's no guarantee that subsequent reads will see it. Best-effort delivery.

**Example:** Voice/video calls. If you lose a few packets, you don't replay them — the conversation has moved on. The lost data is gone forever, and that's fine.

**When acceptable:**
- Real-time streaming (audio, video, gaming)
- Metrics and telemetry (losing a few data points is OK)
- In-memory caches (cache is a "weak consistency" layer by nature)

### Read-Your-Writes Consistency

**Guarantee:** A user who writes data will always see their own writes on subsequent reads. Other users may see stale data.

This is the most commonly needed consistency level in web applications. It matches user expectations: "I just updated my profile, and I can see the update." But another user looking at your profile might see the old version for a few seconds.

**Implementation strategies:**

1. **Route reads to master after writes:** After a user writes, send their reads to the master (not a replica) for N seconds.
```
User writes → Master → ACK
User reads (within 5s) → routed to Master → fresh data ✓
Other user reads → routed to Replica → may be stale
```

2. **Read from replica, check version:** Include a write timestamp. If the replica's version is older, redirect to the master.

3. **Causal tokens:** The write returns a token. The read includes the token. The replica waits until it has that version before responding.

### Causal Consistency

**Guarantee:** Operations that are causally related are seen in the correct order by all nodes. Concurrent (unrelated) operations may be seen in any order.

**Example:**
```
Alice posts: "I'm engaged!"           (Event A)
Bob replies: "Congratulations!"        (Event B, caused by A)

Causal consistency guarantees: everyone sees A before B.
But if Charlie posts "Nice weather today" at the same time (unrelated),
Charlie's post can appear before or after A and B — order doesn't matter.
```

**Why it matters:** Without causal consistency, Bob's "Congratulations!" might appear in someone's feed before Alice's post — confusing and wrong.

**Implementation:** Usually via vector clocks or logical timestamps (Lamport timestamps) that track which operations have "happened before" others.

### Real-World Systems and Their Consistency

| System | Default Consistency | Configurable? |
|--------|-------------------|---------------|
| **PostgreSQL** (single node) | Linearizable | N/A (single node) |
| **PostgreSQL** (streaming replication) | Eventual (reads from replica) | Yes — can force sync replication |
| **DynamoDB** | Eventual | Yes — strongly consistent reads available per-query |
| **Cassandra** | Tunable (per-query) | Yes — consistency level from ONE to ALL |
| **MongoDB** | Read-your-writes (default) | Yes — read concern: local, majority, linearizable |
| **Zookeeper** | Linearizable (writes), Sequential (reads) | Limited |
| **Google Spanner** | Linearizable (global) | No — always strongly consistent |

**Cassandra's tunable consistency** is particularly powerful:
```
Write consistency ALL + Read consistency ONE = strong consistency (but slow writes)
Write consistency ONE + Read consistency ALL = strong consistency (but slow reads)
Write consistency QUORUM + Read consistency QUORUM = strong consistency (balanced)
Write consistency ONE + Read consistency ONE = eventual consistency (fast, but may be stale)
```

The rule: if `W + R > N` (write replicas + read replicas > total replicas), you get strong consistency.

---

## Discussion Prompts

1. **An online exam platform records student answers. After a student clicks "Submit," they see a confirmation page showing their answer. Another student viewing the same exam at the same time doesn't need to see the first student's submission. What consistency level do you need and why?**

2. **You're designing a collaborative document editor (like Google Docs). Two users edit the same paragraph simultaneously. What consistency model and conflict resolution strategy would you use?** Why can't you use simple last-write-wins here?

3. **A distributed counter tracks "total downloads" for an app across 5 regions. Each region processes download events locally. How would you implement this with CRDTs?** What happens when regions reconnect after a partition?

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. The consistency model where a user is guaranteed to see their own writes, but other users may see stale data, is called ______ consistency.

2. In Cassandra, if write consistency is QUORUM and read consistency is QUORUM with a replication factor of 3, the system provides ______ consistency because W + R > N.

3. Data structures that are mathematically guaranteed to converge without coordination in a distributed system are called ______.

### Multiple Choice (4 points)

4. Two users simultaneously update the same document on different replicas. With last-write-wins (LWW) conflict resolution, what happens?

   - a) Both updates are preserved and merged
   - b) The update with the later timestamp survives; the other is silently lost
   - c) The system rejects the second write
   - d) Both replicas maintain their own version permanently

5. A social media app shows a "like count" on posts. The count is eventually consistent with a convergence window of ~5 seconds. A post has 1,000 likes. What might a user see?

   - a) Always exactly 1,000
   - b) Between 995-1,005 (a few seconds of likes pending)
   - c) Any number from 0 to 1,000
   - d) 1,000 or higher, never lower

6. Which consistency level is cheapest (lowest latency, highest throughput)?

   - a) Linearizability
   - b) Causal consistency
   - c) Read-your-writes
   - d) Eventual consistency

7. You need to implement a distributed lock. Which consistency model is REQUIRED?

   - a) Eventual consistency — the lock will converge
   - b) Read-your-writes — only the lock holder needs to see it
   - c) Linearizability — all nodes must agree on who holds the lock
   - d) Weak consistency — the lock is best-effort

### Short Answer (3 points)

8. Explain why read-your-writes consistency is the most important consistency level for web applications. Give a concrete example of a user-visible bug that occurs without it and how users would describe the problem.

9. A system uses Cassandra with `QUORUM` reads and `ONE` writes (replication factor 3). Is this strongly consistent? Show the math (W + R vs N) and explain what can go wrong.

10. Describe a scenario where eventual consistency is not just acceptable but actually *better* than strong consistency. What makes strong consistency counterproductive in that scenario?

<details>
<summary>Answer Key</summary>

1. **read-your-writes**
2. **strong** (QUORUM with RF=3 means W=2, R=2, N=3. W+R=4 > 3=N, so reads always see the latest write.)
3. **CRDTs** (Conflict-free Replicated Data Types)
4. **b)** — LWW uses timestamps to pick a winner. The write with the later timestamp survives; the other is discarded. Neither user is notified that their write was lost. This is why LWW is sometimes called "last-write-wins, data-loses" — it's simple but can silently lose data.
5. **b)** — With a 5-second convergence window, the counter might be a few likes behind (likes that haven't propagated yet) or occasionally slightly different across replicas. It won't be wildly wrong (not 0, not random), just a few behind real-time.
6. **d)** — Eventual consistency is cheapest because it requires no coordination between nodes. Writes go to any single node, reads from any single node. No quorum, no consensus, no round trips for agreement.
7. **c)** — A distributed lock requires linearizability. If two nodes disagree about who holds the lock (due to stale data), two processes could enter a critical section simultaneously, defeating the purpose. Eventual consistency for locks means "eventually one process has the lock, but in the meantime both think they do" — which is a bug, not a feature.
8. Read-your-writes is the most important because it matches user expectations of causality. Example: A user changes their profile picture. They immediately view their profile and see the old picture. They change it again. Old picture again. From the user's perspective, "the site is broken — it won't save my profile picture." They'd file a bug report. In reality, reads are going to a stale replica. The write succeeded on the master but hasn't replicated. The fix is routing that user's reads to the master for a few seconds after any write. Without read-your-writes, every write-then-read flow in the application feels broken to users.
9. W=1, R=2 (QUORUM of 3), N=3. W+R = 1+2 = 3 = N. This is NOT strongly consistent — it requires W+R > N for guaranteed consistency. What can go wrong: a write goes to one replica (W=1). Before that write replicates, a QUORUM read hits the two OTHER replicas that don't have the write yet. The read returns stale data even though it's QUORUM. To get strong consistency with RF=3: use W=QUORUM (2) + R=QUORUM (2), giving W+R=4 > 3.
10. A multiplayer game server tracking player positions. Players send position updates 60 times per second. Strong consistency would require coordinating 60 updates/second across all servers before any player sees movement — adding latency that makes the game unplayable (players appear to teleport or stutter). Eventual consistency lets each server immediately render position updates it receives, even if different servers briefly disagree about a player's exact position. The visual result: smooth movement with occasional minor desync that self-corrects in milliseconds. Strong consistency would make the game literally unplayable for the sake of correctness no one needs.

</details>

---

## Challenge Mission: "The Consistency Spectrum"

### Scenario

You're designing a social media platform with these five features. For each, choose the appropriate consistency level and justify your decision.

**Feature 1: Profile Updates**
- User changes their name, bio, or profile picture
- Viewed by the user and by other users visiting their profile
- Update frequency: ~once per month per user

**Feature 2: Post Likes**
- Users like posts; the like count is displayed on every post
- Popular posts get 10,000+ likes per minute
- The count is displayed on every page view

**Feature 3: Direct Messages**
- User sends a private message to another user
- Messages must arrive in order
- Both participants must see the same conversation history

**Feature 4: Notification Count (badge)**
- The red badge showing "3 unread notifications"
- Updated when someone likes, comments, or follows
- Displayed on every page load

**Feature 5: Search Index**
- When a user posts a tweet, it should become searchable
- Searches by keyword across all posts

### Your Task

For each feature:
1. **Choose a consistency level** (strong, read-your-writes, causal, eventual, weak)
2. **Justify with a concrete user-visible bug** — describe what goes wrong if you pick one level weaker than your choice
3. **Justify with a concrete cost** — describe what you waste if you pick one level stronger than needed
4. **Estimate the acceptable staleness window** (0, 1 second, 5 seconds, 30 seconds, etc.)

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 3:

- **Strong consistency (linearizability)** — Every read returns the most recent write. Requires coordination (consensus). Most expensive.
- **Eventual consistency** — All replicas converge eventually if writes stop. No guarantee about timing or what you see before convergence.
- **Read-your-writes consistency** — A user always sees their own writes. Other users may see stale data. The most important level for web apps.
- **Causal consistency** — Causally related operations are seen in order. Concurrent operations may be seen in any order.
- **Last-write-wins (LWW)** — Conflict resolution using timestamps. Simple but can silently lose data.
- **Vector clocks** — Mechanism to track causality in distributed systems. Detects concurrent writes.
- **CRDTs** — Data structures that merge automatically without coordination. Examples: counters, sets, registers.
- **Tunable consistency** — Per-query choice of consistency level (e.g., Cassandra's ONE, QUORUM, ALL).
