# Lecture 4: Load Balancers

> Module 1 — "The Request Journey" | Lecture 4 of 20

You have one server handling all requests. What happens when traffic doubles? It falls over. Load balancers solve this by distributing traffic across multiple servers — but the choice of algorithm, layer, and topology has real consequences. This lecture covers all of it.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Load balancer*
- *Active-passive*
- *Active-active*
- *Layer 4 load balancing*
- *Layer 7 load balancing*
- *Horizontal scaling*

---

## Concept Briefing

### Why Load Balancers Exist

Without a load balancer, your architecture looks like this:

```
All users ──────► Single Server
                  (single point of failure)
```

Problems:
1. **Capacity** — One server has a throughput ceiling
2. **Availability** — If it dies, everyone is down
3. **Maintenance** — You can't update without downtime

A load balancer sits in front of multiple servers and distributes incoming requests:

```
              ┌──► Server 1
Users ──► LB ─┼──► Server 2
              └──► Server 3
```

Now you have capacity (3x throughput), redundancy (one server can die), and the ability to roll out updates one server at a time.

---

## Deep Dive

### L4 vs L7 Load Balancing

This is the most important distinction. Load balancers operate at different layers of the network stack, and the layer determines what information they can use to make routing decisions.

**Layer 4 (Transport Layer)**

L4 load balancers work at the TCP/UDP level. They see:
- Source and destination IP addresses
- Source and destination ports
- Protocol (TCP or UDP)

They do NOT see:
- HTTP headers, URLs, cookies, or request body
- Application-level content of any kind

**How it works:** The LB receives a TCP connection, picks a backend server, and forwards all packets in that connection to that server. It's essentially a smart network switch.

```
Client ── TCP connection ──► L4 LB ── TCP connection ──► Server 2
                              (routes based on IP/port)
```

| Pros | Cons |
|------|------|
| Very fast — minimal processing per packet | Can't route based on URL or content |
| Low resource usage | No HTTP-aware features (header manipulation, compression) |
| Protocol-agnostic (works with anything over TCP/UDP) | Limited health check options (TCP connect only) |
| Simple to configure | Can't do SSL termination efficiently |

**Layer 7 (Application Layer)**

L7 load balancers work at the HTTP level. They see everything L4 sees, plus:
- HTTP method, URL path, query parameters
- HTTP headers (Host, Cookie, Authorization, etc.)
- Request and response body

**How it works:** The LB terminates the client's HTTP connection, inspects the request, and opens a new connection to the chosen backend server.

```
Client ── HTTP request ──► L7 LB ── new HTTP request ──► Server 2
                           (inspects URL, headers, cookies)
```

| Pros | Cons |
|------|------|
| Content-based routing (`/api` → API servers, `/images` → image servers) | More resource-intensive — must parse HTTP |
| SSL termination — offloads encryption from backends | Higher latency per request (inspect + new connection) |
| Header manipulation, compression, caching | More complex to configure |
| Advanced health checks (HTTP status codes) | Protocol-specific (HTTP/HTTPS only) |
| Can inject headers (X-Request-ID, X-Forwarded-For) | |

**When to use which:**

| Scenario | Choice | Why |
|----------|--------|-----|
| High-throughput TCP service (database proxy) | L4 | Don't need HTTP inspection, need raw speed |
| Web application with microservices | L7 | Need URL-based routing to different service backends |
| Mixed traffic (HTTP + WebSocket + gRPC) | L7 | Need protocol-aware routing |
| Simple round-robin across identical servers | L4 | Simplest setup, lowest overhead |
| Need SSL termination | L7 | L4 can't terminate SSL without seeing the content |

### Load Balancing Algorithms

The algorithm determines HOW the load balancer picks which backend server to send each request to.

#### Round Robin

Sends requests to each server in sequence: 1, 2, 3, 1, 2, 3, ...

```
Request 1 → Server 1
Request 2 → Server 2
Request 3 → Server 3
Request 4 → Server 1 (cycle repeats)
```

| Pros | Cons |
|------|------|
| Simplest possible algorithm | Assumes all servers are equally capable |
| No state to maintain | Ignores current server load |
| Perfectly even distribution | Long-running requests create imbalance |

**Best for:** Stateless services with similar request processing times.

#### Weighted Round Robin

Like round robin, but servers with higher weights get more requests.

```
Server 1 (weight 5): gets 5 of every 8 requests
Server 2 (weight 2): gets 2 of every 8 requests
Server 3 (weight 1): gets 1 of every 8 requests
```

**Best for:** When servers have different capacities (e.g., mixing old and new hardware).

#### Least Connections

Sends each request to the server with the fewest active connections.

```
Server 1: 15 active connections
Server 2: 8 active connections   ◄── next request goes here
Server 3: 12 active connections
```

| Pros | Cons |
|------|------|
| Adapts to server load in real-time | Requires tracking connection counts |
| Handles varying request durations well | Slightly more overhead than round robin |

**Best for:** Services where request processing time varies significantly (some requests take 10ms, others take 2 seconds).

#### IP Hash

Hashes the client's IP address to determine which server gets the request. The same IP always goes to the same server.

```
hash(client_IP) % num_servers = server_index
```

| Pros | Cons |
|------|------|
| Session affinity without cookies | Uneven distribution if some IPs generate more traffic |
| Simple and stateless at the LB | Adding/removing servers reshuffles ALL assignments |
| No need for shared session storage | Behind NAT, many users share one IP |

**Best for:** When you need basic session stickiness without application-level support.

#### Consistent Hashing (Preview)

A more sophisticated version of IP hash that minimizes redistribution when servers are added or removed. We'll do a deep dive on this in Lecture 6 — for now, just know it exists and solves the "reshuffling problem" of simple IP hash.

### Active-Passive vs Active-Active HA

The load balancer itself is a single point of failure. How do you make the load balancer highly available?

**Active-Passive (Failover)**

```
                ┌──── Active LB ────┐
Users ──────────┤                   ├──► Backend Servers
                └── Passive LB ─────┘
                    (standby)
```

- One LB handles all traffic (active)
- A second LB monitors the first (passive/standby)
- If the active LB fails, the passive takes over (typically using a virtual IP / VRRP)
- Failover time: typically 1-30 seconds

**Active-Active**

```
                ┌──── LB 1 ─────┐
Users ──────────┤               ├──► Backend Servers
                └──── LB 2 ─────┘
```

- Both load balancers handle traffic simultaneously
- DNS returns both LB IPs, or an upstream router distributes traffic
- If one fails, the other absorbs all traffic (temporarily at 2x load)
- No failover delay — but each LB must be sized to handle full traffic alone

| Factor | Active-Passive | Active-Active |
|--------|---------------|---------------|
| Resource utilization | 50% (passive is idle) | 100% (both working) |
| Failover time | 1-30 seconds | Near-zero |
| Complexity | Simpler | More complex (state sync, split-brain risk) |
| Cost efficiency | Lower (but passive is wasted) | Higher (both serve traffic) |

### Health Checks and Circuit Breakers

A load balancer is only useful if it knows which backend servers are healthy.

**Health Checks:**
- **TCP check** — Can I open a TCP connection? (L4)
- **HTTP check** — Does `GET /health` return 200? (L7)
- **Custom check** — Does the server respond correctly to a specific query?

Typical configuration:
- Check interval: every 5-10 seconds
- Failure threshold: 3 consecutive failures → mark unhealthy
- Recovery threshold: 2 consecutive successes → mark healthy again

**Circuit Breakers** (covered deeply in Lecture 13):
When a backend starts failing, a circuit breaker stops sending it traffic immediately rather than waiting for health checks. This is faster and prevents cascading failures.

### Horizontal Scaling: The Load Balancer's Purpose

The whole point of a load balancer is to enable **horizontal scaling** — adding more servers to handle more traffic.

For this to work, your application servers should be **stateless**:
- No user session stored in server memory
- No local file storage that other servers need
- Any server can handle any request

**What about state?** Move it out:
- Sessions → Redis or database
- Files → Object storage (Lecture 3)
- Cache → Distributed cache (Lecture 9)

**Session Affinity (Sticky Sessions)**

Sometimes you can't make servers fully stateless. Session affinity routes a user's requests to the same server:

```
User A → always Server 1 (based on cookie or IP)
User B → always Server 3
```

| Pros | Cons |
|------|------|
| Doesn't require external session store | Uneven load distribution |
| Simpler application code | If "your" server dies, session is lost |
| | Can't scale down easily |

**Recommendation:** Avoid sticky sessions if possible. External session storage (Redis) is almost always worth the effort.

### Real-World Load Balancers

| Load Balancer | Type | Key Feature |
|-------------|------|-------------|
| **nginx** | L7 (also L4) | Most popular web server + reverse proxy + LB |
| **HAProxy** | L4 and L7 | High performance, battle-tested, widely used in production |
| **AWS ALB** | L7 | Managed, integrates with ECS/EKS, path-based routing |
| **AWS NLB** | L4 | Managed, ultra-low latency, millions of QPS |
| **Envoy** | L7 | Service mesh sidecar proxy, gRPC-native |
| **Traefik** | L7 | Auto-discovery, popular in Kubernetes |

---

## Discussion Prompts

1. **You're running 10 app servers behind a load balancer. One server starts responding 10x slower than the others (but doesn't fail health checks). How would each algorithm handle this?** Which algorithm would you choose, and could you combine algorithms?

2. **An e-commerce site uses sticky sessions for shopping carts. A server with 5,000 active shopping carts dies. What happens?** How would you redesign this to avoid the problem?

3. **Your load balancer handles 50,000 QPS. How do you load balance the load balancer itself?** Is there a point where you can't add another layer of load balancing?

---

## Field Ops: Server Survival

Open [Server Survival](../../deps/server-survival/index.html) and play **Survival mode**.

**Goal:** Survive 2 minutes with budget > $200.

Focus on:
- Place a **Firewall** first to block malicious traffic
- Place a **Load Balancer** to distribute traffic across multiple **Compute** nodes
- Observe what happens when you have 1 Compute vs 3 Compute nodes behind the LB
- Watch the reputation meter — are you losing reputation because requests are being dropped?

**Key observation:** Without a Load Balancer, adding more Compute nodes doesn't help — traffic still goes to one node. The LB is what enables horizontal scaling.

Record your score and architecture notes in [progress.md](../progress.md).

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. A Layer 4 load balancer routes traffic based on ______ and ______, while a Layer 7 load balancer can additionally inspect HTTP ______ and URLs.

2. The load balancing algorithm that sends each request to the server with the fewest active connections is called ______.

3. For horizontal scaling to work effectively, application servers should be ______, meaning they don't store user-specific state in memory.

### Multiple Choice (4 points)

4. Your application serves two types of traffic: `/api/*` requests that go to API servers, and `/static/*` requests that go to file servers. Which load balancer type do you need?

   - a) L4 — it's faster
   - b) L7 — it can route based on URL path
   - c) Either — both can inspect URLs
   - d) Neither — use DNS routing instead

5. You have 5 servers behind a load balancer using round robin. Server 3 starts taking 10x longer to respond. What happens?

   - a) The LB automatically stops sending traffic to Server 3
   - b) 1/5 of all requests become slow, degrading overall performance
   - c) The LB detects the slowness and switches to least connections
   - d) Server 3 crashes and is removed from the pool

6. In an active-passive load balancer setup, the passive LB:

   - a) Handles 50% of the traffic
   - b) Sits idle until the active LB fails, then takes over
   - c) Handles read requests while the active handles writes
   - d) Is used for health checks only

7. A service uses IP hash load balancing. You add a 6th server to the existing 5. What happens to existing user sessions?

   - a) Nothing — all sessions continue to the same servers
   - b) Approximately 1/6 of sessions are redirected to the new server
   - c) ALL sessions are potentially reshuffled across all 6 servers
   - d) Only new sessions go to the new server

### Short Answer (3 points)

8. Explain why SSL termination at the load balancer is beneficial. What are the trade-offs of terminating SSL at the LB versus at each backend server?

9. Your e-commerce site has a shopping cart stored in server memory (sticky sessions). You need to do a rolling deployment across 10 servers. Describe the problem this creates and propose a solution.

10. You have 3 backend servers with different capacities: Server A handles 1,000 QPS, Server B handles 2,000 QPS, Server C handles 500 QPS. Total incoming traffic is 3,000 QPS. Which algorithm would you use and what weights would you set?

<details>
<summary>Answer Key</summary>

1. **IP addresses** and **ports** / **headers** (Accept: "IP address and port" for L4; "headers" or "cookies" or "content" for L7)
2. **least connections**
3. **stateless**
4. **b)** — Only L7 load balancers can inspect the URL path. L4 sees only IP addresses and ports, so it can't distinguish between `/api/` and `/static/` requests.
5. **b)** — Round robin doesn't consider server response time. It keeps sending 1/5 of requests to Server 3 regardless of how slow it is. This is a key limitation of round robin — it's blind to server performance. Least connections would handle this better because slow servers accumulate connections.
6. **b)** — In active-passive, the passive LB monitors the active one and takes over only when the active fails. Until then, it handles zero traffic. This wastes resources but provides high availability.
7. **c)** — With simple IP hash (`hash(IP) % N`), changing N from 5 to 6 potentially changes the result for every IP address. Most existing sessions will be reshuffled. This is the exact problem that consistent hashing (Lecture 6) solves — with consistent hashing, only ~1/6 of sessions would move.
8. SSL termination at the LB means the LB handles encryption/decryption. Benefits: (1) Backend servers are freed from the CPU-intensive TLS work. (2) You manage certificates in one place instead of on every server. (3) The LB can inspect HTTP content for routing. Trade-offs: (1) Traffic between the LB and backend servers is unencrypted (unless you re-encrypt, which adds overhead). (2) In high-security environments, this may violate compliance requirements for end-to-end encryption. (3) The LB becomes the bottleneck for SSL processing.
9. The problem: when you restart a server during deployment, all shopping carts stored in that server's memory are lost. With 10 servers and sticky sessions, each restart loses ~10% of active carts. Solution: move shopping cart state to an external store (Redis). This makes servers stateless — any server can handle any user's cart, and restarting a server loses nothing. Rolling deployments become safe.
10. Weighted round robin with weights proportional to capacity: Server A = weight 2, Server B = weight 4, Server C = weight 1 (total weight 7). This gives A ~29% (1,000/3,500), B ~57% (2,000/3,500), C ~14% (500/3,500) of 3,000 QPS = ~860, ~1,710, ~430. Each server is at ~86% capacity, leaving headroom. (Accept any weight ratio that's approximately 2:4:1 or equivalent.)

</details>

---

## Challenge Mission: "The Traffic Storm"

### Scenario

You're the infrastructure lead at an e-commerce company. Black Friday is in 2 weeks.

**Normal traffic:** 5,000 QPS average, 8,000 QPS peak
**Expected Black Friday:** 50,000 QPS peak (10x normal)
**Current architecture:**

```
              ┌──► App Server 1 (4 CPU, 16 GB RAM, capacity: 2,000 QPS)
DNS ──► LB ──┼──► App Server 2 (same)
              └──► App Server 3 (same)

Each app server connects to:
  - Redis (session store, 50,000 QPS capacity)
  - PostgreSQL primary (5,000 QPS read, 1,000 QPS write)
  - PostgreSQL replica (5,000 QPS read-only)
```

**Application details:**
- 70% of requests are product page views (read-heavy)
- 20% are search queries (read-heavy, CPU-intensive)
- 5% are add-to-cart (write to Redis session + DB)
- 5% are checkout (write-heavy, requires DB transaction)

### Your Task

**Part 1 — Capacity Analysis**

1. Calculate current total app server capacity. Can you handle 50,000 QPS with the current 3 servers?
2. How many app servers do you need for 50,000 QPS? (Include 20% headroom)
3. Calculate the read and write QPS hitting the database at 50,000 QPS. Can the current DB setup handle it?

**Part 2 — Load Balancer Design**

1. L4 or L7 load balancer? Justify your choice given the traffic types.
2. Which algorithm? Consider: product views are fast (50ms), search is slow (500ms), checkout is very slow (2s).
3. Should you use sticky sessions for shopping carts? Why or why not? (Consider that carts are in Redis.)

**Part 3 — Scaling Plan**

Design your Black Friday architecture:
1. How many total app servers?
2. Any changes to the database tier?
3. Any changes to the caching tier?
4. What's your LB failover strategy? (Can't afford LB downtime on Black Friday.)

**Part 4 — What Could Go Wrong?**

List three things that could fail on Black Friday despite your scaling plan, and your mitigation for each.

### Constraints

- Budget: $20,000 for additional cloud servers for the month
- Cloud servers cost: $500/month for a 4-CPU, 16 GB server
- Database replicas cost: $1,000/month
- You cannot change the application code in 2 weeks
- Managed load balancer cost: $200/month per LB

### Hints

<details>
<summary>Hint 1: Algorithm choice</summary>
With request processing times varying from 50ms to 2s, round robin will cause problems. A checkout request takes 40x longer than a product view. Think about which algorithm handles this variation best.
</details>

<details>
<summary>Hint 2: Database bottleneck</summary>
At 50,000 QPS with 70% reads and 5% writes to DB: that's 35,000 reads + 2,500 writes. Your current DB has 10,000 read QPS (primary + replica) and 1,000 write QPS. What's the bottleneck? Can you add more read replicas?
</details>

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 1:

- **Load balancer** — Distributes incoming traffic across multiple backend servers.
- **L4 load balancing** — Routes based on IP and port (transport layer). Fast, protocol-agnostic.
- **L7 load balancing** — Routes based on HTTP content (URL, headers, cookies). More flexible.
- **Round robin** — LB algorithm that sends requests to servers in sequence.
- **Least connections** — LB algorithm that sends requests to the server with fewest active connections.
- **Consistent hashing** — LB/sharding algorithm that minimizes redistribution when servers change (deep dive in Lecture 6).
- **Active-passive** — HA pattern where a standby takes over when the primary fails.
- **Active-active** — HA pattern where both instances handle traffic simultaneously.
- **Sticky sessions (session affinity)** — Routing that sends the same user to the same backend server.
- **Stateless** — Server design where no user-specific state is stored locally, enabling horizontal scaling.
- **Health check** — Periodic test to verify a backend server is responsive.
- **SSL termination** — Decrypting HTTPS traffic at the load balancer so backends receive plain HTTP.
