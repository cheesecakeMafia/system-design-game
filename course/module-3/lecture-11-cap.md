# Lecture 11: CAP Theorem — Deep Dive

> Module 3 — "The Distributed Mind" | Lecture 11 of 20

In Lecture 6 you got a 10-minute CAP primer. Now we go deep. The CAP theorem is the most cited — and most misunderstood — result in distributed systems. This lecture separates what CAP actually says from the myths, introduces PACELC (the theorem's practical extension), and gives you the tools to reason about consistency vs availability trade-offs in every system you design.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Availability vs consistency*
- *CAP theorem*
- *CP — consistency and partition tolerance*
- *AP — availability and partition tolerance*

---

## Deep Dive

### What CAP Actually Says

Eric Brewer's conjecture (proven as a theorem by Gilbert and Lynch in 2002):

> In a distributed data store, it is impossible to simultaneously provide more than two out of three guarantees: **Consistency**, **Availability**, and **Partition Tolerance**.

Let's define each term precisely — the common definitions are often wrong:

**Consistency (C):** Every read receives the most recent write or an error. Technically, this is *linearizability* — the strongest form of consistency. All nodes see the same data at the same time.

**Availability (A):** Every request (read or write) receives a non-error response, without the guarantee that it contains the most recent write. The system always answers — it never says "try again later."

**Partition Tolerance (P):** The system continues to operate despite arbitrary message loss or failure of part of the system. Network partitions — where nodes can't communicate with each other — don't stop the system.

### Why You Can't Avoid P

Here's the crucial insight: **network partitions are not a choice. They happen.**

Cables get cut. Switches fail. Datacenters lose connectivity. In any system with more than one node, partitions are inevitable. You can't "choose not to have partitions" — you can only choose what to do when they occur.

This means the real choice is binary: **when a partition happens, do you choose C or A?**

```
Partition occurs!
  │
  ├── Choose C (CP system):
  │     Stop serving requests that might return stale data.
  │     Some/all requests get errors until partition heals.
  │     Data is guaranteed correct for anyone who gets a response.
  │
  └── Choose A (AP system):
        Continue serving all requests.
        Responses may contain stale/inconsistent data.
        No one gets an error, but some get wrong answers.
```

### Common Misconceptions

**Myth 1: "You pick 2 out of 3"**
Not exactly. You always have P (partitions happen). So you're choosing between CP and AP during a partition. When there's no partition, you can have both C and A.

**Myth 2: "CA systems exist"**
A "CA system" (consistent + available, not partition-tolerant) is a single-node database. If you only have one server, there are no partitions — but you have a single point of failure. The moment you add a second node, you must deal with P.

**Myth 3: "A system is always CP or always AP"**
Many systems let you choose per-operation. DynamoDB lets you choose strongly consistent reads (CP behavior) or eventually consistent reads (AP behavior) on each individual query. The system isn't categorically one or the other.

**Myth 4: "CAP means you can't have all three"**
More precisely: you can't have all three *during a partition*. When the network is healthy (no partition), a well-designed system provides both consistency and availability. CAP only constrains behavior during the failure mode.

### CP Systems — Consistency Over Availability

When a partition occurs, CP systems refuse to serve potentially stale data. They return errors or timeouts for operations that can't be guaranteed consistent.

**Examples:**

| System | CP Behavior |
|--------|------------|
| **HBase** | Reads/writes fail if the RegionServer can't reach the master |
| **MongoDB** (strong read concern) | Reads fail if the primary is unreachable |
| **Zookeeper** | Followers that can't reach the leader stop serving reads |
| **etcd** | Requires majority quorum — minority partition becomes unavailable |
| **Google Spanner** | Uses TrueTime + Paxos — sacrifices availability for global consistency |

**When to choose CP:**
- Financial systems — a bank balance must be correct, even if temporarily unavailable
- Inventory systems — selling an item that's already sold is worse than returning an error
- Leader election / coordination — a distributed lock must be consistent or it's useless
- Configuration management — serving stale config can cause cascading failures

### AP Systems — Availability Over Consistency

When a partition occurs, AP systems continue serving all requests, even if responses may be stale or conflicting.

**Examples:**

| System | AP Behavior |
|--------|------------|
| **Cassandra** | All nodes accept reads and writes; conflicts resolved on read (read repair) |
| **DynamoDB** (eventual consistency mode) | Reads may return slightly stale data |
| **CouchDB** | Accepts writes on any replica; merges conflicts later |
| **DNS** | Serves cached (potentially stale) results even when authoritative servers are unreachable |

**When to choose AP:**
- Social media feeds — a slightly stale timeline is better than "Timeline unavailable"
- Shopping cart — showing a slightly outdated cart is better than "Cart unavailable"
- Product catalog — showing a price that's 30 seconds old is acceptable
- Recommendation systems — stale recommendations are still useful

### PACELC Theorem — The Practical Extension

CAP only talks about what happens during a partition. But what about normal operation? PACELC fills this gap:

> If there is a **P**artition, choose between **A**vailability and **C**onsistency. **E**lse (no partition), choose between **L**atency and **C**onsistency.

```
PACELC:
  P → A or C    (during partition: same as CAP)
  E → L or C    (normal operation: latency vs consistency)
```

This is more useful because it captures the day-to-day trade-off: even when the network is fine, stronger consistency requires more coordination (more round trips, more latency).

| System | During Partition | Normal Operation | Classification |
|--------|-----------------|-----------------|----------------|
| **Cassandra** | Choose A | Choose L (tunable) | PA/EL |
| **DynamoDB** (eventual) | Choose A | Choose L | PA/EL |
| **MongoDB** (strong) | Choose C | Choose C | PC/EC |
| **HBase** | Choose C | Choose C | PC/EC |
| **Google Spanner** | Choose C | Choose L (TrueTime minimizes latency cost) | PC/EL |
| **PNUTS (Yahoo)** | Choose A | Choose C (per-record master) | PA/EC |

**Spanner is fascinating:** It achieves PC/EL by using atomic clocks (TrueTime) to minimize the latency cost of consistency. Without hardware clocks, strong consistency across datacenters requires round trips for consensus — Spanner's clocks let it bound the uncertainty window to ~7ms, making globally consistent reads fast.

### Connecting Back to Module 2

Now revisit your Module 2 decisions through the CAP lens:

**Master-slave replication (L6):**
During a partition between master and slave, reads from the slave return stale data (AP behavior). Writes to the master are consistent (CP behavior). The system is hybrid — CP for writes, AP for reads.

**Sharding (L6):**
If two shards can't communicate, cross-shard queries fail (CP behavior for cross-shard operations). Operations within a single shard are unaffected. Sharding turns a global availability problem into a per-shard one.

**NoSQL databases (L7):**
Cassandra → AP (always available, eventually consistent). HBase → CP (consistent, may become unavailable). MongoDB → configurable per query. Your choice of NoSQL database was implicitly a CAP choice.

**Caching (L9):**
A cache is inherently an AP system — it serves stale data (previous reads) when the source of truth is unavailable. Cache-aside explicitly chooses availability over consistency during the staleness window.

---

## Discussion Prompts

1. **Your bank's payment system uses a CP database. During a network partition, customers can't check their balance or make transfers. The CEO demands "zero downtime." Is this achievable while keeping strong consistency?** What would you explain to the CEO?

2. **DNS is an AP system — it serves cached (potentially stale) records when authoritative servers are unreachable. What would happen if DNS were CP instead?** Think about the cascading impact on the internet.

3. **DynamoDB lets you choose consistent or eventually consistent reads per query. In a single application, you might use both: consistent reads for "show the user their balance" and eventually consistent reads for "show the user their activity feed." Why is this a better approach than making the entire database CP or AP?**

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. The CAP theorem states that during a network ______, a distributed system must choose between consistency and availability.

2. The PACELC theorem extends CAP by adding that during normal operation (no partition), the trade-off is between ______ and consistency.

3. A system that continues serving all requests during a partition, even if responses may be stale, is classified as ______ in CAP terminology.

### Multiple Choice (4 points)

4. A network partition separates your database cluster into two groups of nodes. Group A has 3 nodes, Group B has 2 nodes. In a CP system, what happens?

   - a) Both groups continue serving reads and writes
   - b) Only the majority group (A) continues serving; Group B becomes unavailable
   - c) Both groups become unavailable until the partition heals
   - d) Group B continues serving reads only

5. Which of the following is a "CA system"?

   - a) A 3-node Cassandra cluster
   - b) A single PostgreSQL server (no replication)
   - c) A MongoDB replica set
   - d) CA systems don't exist in distributed systems

6. Your application reads user preferences from a distributed cache. During a network partition, the cache serves the user's preferences from 2 hours ago (stale). This is an example of:

   - a) CP behavior — consistency is maintained
   - b) AP behavior — availability is chosen over consistency
   - c) CA behavior — both consistency and availability
   - d) A bug that needs to be fixed

7. Google Spanner achieves globally consistent reads with low latency by using:

   - a) Eventual consistency with conflict resolution
   - b) Atomic clocks (TrueTime) to bound uncertainty windows
   - c) Giving up availability — it's a pure CP system
   - d) Sharding so each partition is independent

### Short Answer (3 points)

8. Explain why "just choose CA" (consistency + availability without partition tolerance) is not a real option for any distributed system. What happens to a "CA system" when a network partition occurs?

9. A social media platform has two features: (1) "Post a tweet" and (2) "Show the follower count." For each, should the system prioritize consistency or availability during a partition? Explain with a concrete user-visible consequence for each choice.

10. Your system uses Cassandra (AP) for the main data store and Zookeeper (CP) for distributed locks. During a partition, what can and can't your system do? Is this combination valid?

<details>
<summary>Answer Key</summary>

1. **partition** (network partition)
2. **latency**
3. **AP** (Available + Partition-tolerant)
4. **b)** — CP systems that use majority quorum (like etcd or Zookeeper) only allow the majority partition to serve requests. Group A (3 of 5 = majority) continues serving. Group B (2 of 5 = minority) becomes unavailable. This ensures consistency — there's only one "source of truth."
5. **b)** — A single PostgreSQL server with no replication is technically CA — it's consistent (one node, always up to date) and available (always responds if it's up). But it's not partition-tolerant because there's only one node — if it fails, everything is down. CA is only possible without distribution.
6. **b)** — The cache is choosing availability (serving a response, even if stale) over consistency (which would require checking the authoritative source). This is AP behavior and is typically desirable for non-critical data like preferences.
7. **b)** — Spanner uses TrueTime (GPS receivers and atomic clocks in every datacenter) to bound clock uncertainty to ~7ms. This allows globally consistent reads without the full round-trip latency of consensus protocols, because the system can determine ordering based on real-time intervals. It's a hardware solution to a software problem.
8. A CA system assumes network partitions never happen. But in any distributed system (multiple nodes communicating over a network), partitions are inevitable — cables fail, switches reboot, datacenters lose connectivity. When a partition occurs in a "CA system," it must become either CP (stop serving to maintain consistency) or AP (serve stale data to maintain availability). It can't be both during the partition. So "CA" isn't a category for distributed systems — it's only possible with a single non-distributed node.
9. (1) "Post a tweet" — prioritize **availability** (AP). If the system returns an error when a user tries to tweet, they're frustrated and may leave. It's better to accept the tweet (even if it takes a few seconds to propagate to all replicas) than to refuse it. User-visible consequence of choosing CP: "Failed to post tweet, try again later." (2) "Show follower count" — prioritize **availability** (AP). A follower count that's 30 seconds stale is imperceptible to users. CP would mean "Follower count unavailable" which looks like a bug. Even "post a tweet" benefits from AP — very few social media operations truly need CP during a partition.
10. During a partition: Cassandra (AP) continues serving reads and writes — data may be inconsistent across nodes, but the system is available. Zookeeper (CP) may become unavailable if the partition splits the ensemble such that no majority exists — distributed locks stop working. So the system can: read/write data (via Cassandra), but cannot: acquire or release distributed locks (via Zookeeper). This combination is valid and common — the AP store handles the high-throughput data path while the CP store handles the low-frequency coordination tasks. The risk: if locks are required for correctness (e.g., preventing double-processing), the system may need to pause certain operations when Zookeeper is unavailable.

</details>

---

## Challenge Mission: "The CAP Dilemma"

### Scenario

You're the architect for three different systems. For each, classify it as CP or AP, justify with specific failure scenarios, and describe what users experience during a partition.

**System 1: Banking Ledger**
- Records all financial transactions (deposits, withdrawals, transfers)
- Used by millions of customers for balance checks and transfers
- Regulated — auditors require exact account balances at all times
- Multi-region deployment (US East, US West)

**System 2: Social Media Likes Counter**
- Displays the number of likes on a post
- Posts can receive 10,000 likes per second (viral content)
- Displayed on every page view (50M views/day)
- Multi-region deployment

**System 3: DNS (Domain Name System)**
- Maps domain names to IP addresses
- Queried billions of times per day globally
- TTL-based caching at every level
- Root servers distributed globally

### Your Task

For each system:
1. **Classify as CP or AP** — justify your choice
2. **Describe a partition scenario** — what specific nodes/regions lose connectivity?
3. **CP path:** What happens if you choose consistency? Describe the user experience.
4. **AP path:** What happens if you choose availability? Describe the user experience.
5. **Your recommendation:** Which path and why? What's the unacceptable failure mode?

### Then answer:
6. For the banking ledger, design a system that provides the *illusion* of availability during a partition without sacrificing consistency. (Hint: think about what operations can safely proceed vs which must wait.)

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 3:

- **CAP Theorem** — During a network partition, a distributed system must choose between Consistency and Availability. Partition tolerance is not optional.
- **Linearizability** — The strongest consistency model. Every read returns the most recent write. What CAP means by "Consistency."
- **CP system** — Chooses consistency during partitions. Returns errors rather than stale data. Examples: HBase, Zookeeper, etcd.
- **AP system** — Chooses availability during partitions. Serves stale data rather than errors. Examples: Cassandra, DynamoDB (eventual), DNS.
- **PACELC** — Extension of CAP: during Partition choose A or C; Else choose Latency or Consistency. Captures the normal-operation trade-off.
- **Network partition** — Communication failure between nodes in a distributed system. Inevitable in any multi-node system.
- **Quorum** — Minimum number of nodes that must agree for an operation to succeed. Majority quorum = (N/2)+1 nodes.
