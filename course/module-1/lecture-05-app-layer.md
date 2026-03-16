# Lecture 5: Reverse Proxy, Application Layer & Microservices

> Module 1 — "The Request Journey" | Lecture 5 of 20

You've traced the request through DNS, across the network, past the CDN, through the load balancer. Now it hits the application layer — the code that actually does the work. This lecture covers what sits between the load balancer and your business logic, and the fundamental question every growing team faces: monolith or microservices?

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Reverse proxy (web server)*
- *Application layer*
- *Microservices*
- *Service discovery*

---

## Concept Briefing

### The Layers Between Users and Your Code

A typical web request passes through several layers before reaching your business logic:

```
Client → DNS → CDN → Load Balancer → Reverse Proxy → App Server → Database
```

We've covered DNS, CDN, and Load Balancers. Now we zoom into what happens after the load balancer — specifically the reverse proxy and the application server(s) behind it.

In many architectures, the load balancer and reverse proxy are the same service (nginx or HAProxy doing both). But they're conceptually different roles.

---

## Deep Dive

### Reverse Proxy vs Forward Proxy vs Load Balancer

These three are often confused because they all sit between clients and servers.

**Forward Proxy** — Sits in front of **clients**. The client knows it's using a proxy.
```
Client → Forward Proxy → Internet → Server
```
Use cases: corporate firewalls, privacy (hiding client IP), caching for client-side.

**Reverse Proxy** — Sits in front of **servers**. The client doesn't know it exists.
```
Client → Internet → Reverse Proxy → Server
```
Use cases: SSL termination, compression, caching, security, rate limiting.

**Load Balancer** — A reverse proxy that distributes traffic across multiple servers.
```
Client → Internet → Load Balancer → Server 1, 2, or 3
```

The key insight: **a load balancer is a reverse proxy with a distribution algorithm.** Every load balancer is a reverse proxy, but not every reverse proxy is a load balancer (a reverse proxy in front of a single server is just a proxy).

### What Reverse Proxies Do

Even if you only have one backend server, a reverse proxy provides value:

**1. SSL Termination**
- The reverse proxy handles HTTPS encryption/decryption
- Backend servers communicate over plain HTTP (within your internal network)
- Centralizes certificate management

**2. Compression**
- Gzip or Brotli compression of responses
- Backend servers send uncompressed data, proxy compresses it
- Saves bandwidth, speeds up client downloads

**3. Static Content Serving**
- Serve CSS, JS, images directly from the proxy without hitting the backend
- nginx is extremely efficient at serving static files

**4. Caching**
- Cache frequent responses at the proxy level
- Reduces load on backend servers
- Short TTLs (seconds to minutes) for dynamic content

**5. Rate Limiting**
- Limit requests per IP or per API key
- Protects backend from abuse and DDoS
- More efficient to reject at the proxy than at the application

**6. Security**
- Hide backend server details (IP, technology stack)
- Block malicious requests (SQL injection patterns, oversized payloads)
- Add security headers (CORS, CSP, HSTS)

**7. Request/Response Transformation**
- Add headers (X-Request-ID for tracing)
- Rewrite URLs
- Route to different backends based on path

### The Application Layer

Behind the reverse proxy sits your application code. This is where business logic lives — user authentication, data processing, API endpoints.

The key architectural decision is how to organize this code.

### Monolith vs Microservices

This is one of the most debated topics in software architecture. Both approaches have real trade-offs, and the right answer depends on your team size, product maturity, and scale.

#### The Monolith

All functionality lives in a single codebase and deploys as a single unit.

```
┌──────────────────────────────────────────┐
│              Monolith                     │
│  ┌──────┐ ┌──────┐ ┌────────┐ ┌───────┐ │
│  │ Auth │ │Catalog│ │ Orders │ │Payment│ │
│  └──────┘ └──────┘ └────────┘ └───────┘ │
│  ┌──────────────┐ ┌───────────────────┐  │
│  │ Notifications│ │   Shared Database │  │
│  └──────────────┘ └───────────────────┘  │
└──────────────────────────────────────────┘
```

| Pros | Cons |
|------|------|
| Simple to develop, test, deploy | Changes to one feature risk breaking others |
| Easy to debug (one process, one log) | Must deploy everything together |
| No network calls between components | Scaling requires scaling everything |
| Refactoring across features is easy | Team coordination gets harder as team grows |
| Transaction management is simple (one DB) | Technology locked — entire app uses one stack |

**Best for:** Small teams (1-10 engineers), early-stage products, when you're still figuring out your domain boundaries.

#### Microservices

Each feature is a separate service with its own codebase, deployment, and often its own database.

```
┌────────┐  ┌─────────┐  ┌────────┐  ┌─────────┐
│  Auth  │  │ Catalog  │  │ Orders │  │ Payment │
│Service │  │ Service  │  │Service │  │ Service │
│  DB 1  │  │  DB 2    │  │  DB 3  │  │  DB 4   │
└────┬───┘  └────┬─────┘  └────┬───┘  └────┬────┘
     │           │             │            │
     └───────────┴──────┬──────┴────────────┘
                        │
                   Message Bus
```

| Pros | Cons |
|------|------|
| Independent deployment per service | Distributed systems complexity (network failures, latency) |
| Scale individual services independently | Data consistency across services is hard |
| Team autonomy — each team owns a service | Debugging requires distributed tracing |
| Technology flexibility per service | Operational overhead (monitoring, deployment for each service) |
| Failure isolation — one service crash ≠ total outage | Testing integration points is more complex |

**Best for:** Large teams (50+ engineers), mature products with clear domain boundaries, when different components have very different scaling needs.

#### The Honest Truth About Microservices

Microservices solve **organizational problems**, not technical ones. A monolith can handle millions of QPS (Shopify processes billions of dollars in sales on a monolith). Microservices let large teams work independently — but they introduce an entire category of problems (distributed transactions, service discovery, network failures) that don't exist in a monolith.

**The common mistake:** Starting with microservices too early. If you have 5 engineers, you don't need 15 services. You need a well-structured monolith that you can split later when the organizational pressure demands it.

**Martin Fowler's advice:** "Don't start with microservices. Start with a monolith, keep it modular, and split when you have a good reason."

### Service Discovery

In a microservices architecture, services need to find each other. Hard-coding IP addresses doesn't work when services scale up/down and move between hosts.

**Client-Side Discovery:**
```
Order Service → Service Registry → "Catalog Service is at 10.0.1.5:8080"
Order Service → 10.0.1.5:8080
```
The calling service queries a registry (Consul, etcd, Zookeeper) and connects directly.

**Server-Side Discovery:**
```
Order Service → Load Balancer → Catalog Service (whichever instance)
```
The calling service hits a load balancer, which knows where instances are (via health checks or registry).

| Factor | Client-Side | Server-Side |
|--------|------------|-------------|
| Extra network hop | No — direct connection | Yes — through LB |
| Client complexity | Higher — must handle discovery + load balancing | Lower — just call the LB |
| Language support | Need discovery library in every language | Language-agnostic — just HTTP |
| Failure handling | Client must handle stale registry entries | LB handles failover |

**In practice:** Kubernetes uses server-side discovery (kube-proxy + Services). Service meshes (Istio, Linkerd) abstract this further with sidecar proxies.

### The API Gateway Pattern

An API gateway is a reverse proxy specifically designed for microservices. It sits between clients and your internal services:

```
                   ┌──► Auth Service
Client → API ──────┼──► Catalog Service
         Gateway   ├──► Order Service
                   └──► Payment Service
```

An API gateway handles:
- **Request routing** — `/auth/*` → Auth Service, `/catalog/*` → Catalog Service
- **Authentication** — Verify tokens once at the gateway, not in every service
- **Rate limiting** — Per-client limits across all services
- **Response aggregation** — Combine responses from multiple services into one response
- **Protocol translation** — REST for clients, gRPC between internal services

Examples: Kong, AWS API Gateway, Nginx as gateway, Envoy.

### Inter-Service Communication

When services need to talk to each other, you have two fundamental options:

**Synchronous (Request/Response)**
```
Order Service ── HTTP/gRPC ──► Catalog Service
                (waits for response)
```
- Simple to understand and implement
- Creates coupling — Order Service is blocked until Catalog responds
- Cascading failures: if Catalog is slow, Order becomes slow too

**Asynchronous (Event/Message)**
```
Order Service ── publishes event ──► Message Queue ──► Catalog Service
                (doesn't wait)                        (processes later)
```
- Services are decoupled — Order doesn't know or care when Catalog processes the event
- More resilient — if Catalog is down, messages queue up
- More complex — eventual consistency, message ordering, dead letters
- We'll go deep on async in Lecture 10.

**Which to choose:**
- Use sync when you need an immediate answer ("Is this item in stock?")
- Use async when the caller doesn't need to wait ("Send a confirmation email")

---

## Discussion Prompts

1. **A monolithic e-commerce app has these components: auth, product catalog, order processing, payment, notifications, recommendations, and search. If you HAD to split two of these into separate services first, which two would you choose and why?** What makes certain boundaries better than others?

2. **Your reverse proxy adds ~2ms of latency to every request. With 10 microservices involved in a single user action, and each service calling 1-2 others, how much total latency could internal network hops add?** When does this become a problem?

3. **Netflix famously uses microservices. Your 3-person startup wants to copy Netflix's architecture. Why is this likely a mistake?** What signals would tell you it's time to move to microservices?

---

## Field Ops: Server Survival

In the game, look at the chain: **Firewall → Load Balancer → Compute**.

This mirrors the real-world pattern: Reverse Proxy (Firewall handles security) → Load Balancer → Application Servers (Compute).

Observe:
- What happens if you place Compute without a Firewall? (Malicious traffic overwhelms it)
- What happens if you place Compute without an LB? (Traffic hits one instance)
- The Firewall + LB + Compute chain is the basic "request pipeline" you'd see in any production deployment

Try building the chain in order: Firewall first, then LB, then Compute. Then try the reverse. Notice how the order of placement affects survivability.

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. A ______ proxy sits in front of servers and is invisible to clients, while a ______ proxy sits in front of clients and is invisible to servers.

2. The architectural pattern where a single entry point routes requests to multiple backend microservices, handles authentication, and aggregates responses is called an ______.

3. When services need to find each other's network addresses in a microservices architecture, this is solved by ______.

### Multiple Choice (4 points)

4. Which of the following is NOT a benefit of using a reverse proxy even with a single backend server?

   - a) SSL termination
   - b) Response compression
   - c) Distributing traffic across multiple servers
   - d) Rate limiting

5. A 5-person startup is building an MVP. They expect 1,000 daily users in the first year. Which architecture is most appropriate?

   - a) Microservices — it's the modern best practice
   - b) Monolith — simpler to develop, deploy, and debug with a small team
   - c) Serverless — no servers to manage
   - d) Microservices with a service mesh — future-proof from day one

6. Service A needs to send a welcome email after a user signs up. Which communication pattern is more appropriate?

   - a) Synchronous — call the email service and wait for confirmation
   - b) Asynchronous — publish a "user_created" event and let the email service handle it
   - c) Direct database access — email service reads the user table directly
   - d) Polling — email service checks for new users every second

7. In a microservices architecture, the Order Service needs to check product availability in the Catalog Service and deduct inventory. If the Order Service writes to its own database but the Catalog Service update fails, what problem occurs?

   - a) No problem — databases are independent
   - b) Data inconsistency — an order exists but inventory wasn't deducted
   - c) Both operations automatically roll back
   - d) The load balancer retries the failed operation

### Short Answer (3 points)

8. Explain the difference between a reverse proxy and a load balancer. When would you use a reverse proxy without load balancing?

9. Describe the "distributed monolith" anti-pattern. How can a microservices architecture end up being worse than a monolith?

10. You're splitting a monolith into microservices. The Auth module and the User Profile module share 15 database tables. Should they become one service or two? Explain your reasoning.

<details>
<summary>Answer Key</summary>

1. **reverse** / **forward**
2. **API Gateway**
3. **service discovery**
4. **c)** — Distributing traffic across multiple servers is load balancing, which requires multiple backends. All other options (SSL termination, compression, rate limiting) work with a single backend.
5. **b)** — At 1,000 DAU with 5 engineers, the overhead of microservices (separate deployments, distributed tracing, service discovery, inter-service communication) far outweighs the benefits. A monolith lets the small team move fast and debug easily.
6. **b)** — Sending email is not time-critical — the user doesn't need to wait for the email to be sent before seeing the "Welcome" page. Async decouples the signup flow from email delivery, and if the email service is temporarily down, the message queues up instead of failing the signup.
7. **b)** — This is the distributed transaction problem. Without a coordination mechanism (like the Saga pattern, covered in Lecture 13), each service's database is independent. If one succeeds and the other fails, the data is inconsistent. This is one of the hardest problems in microservices.
8. A reverse proxy is a server that sits in front of backend servers and forwards client requests to them. It can provide SSL termination, compression, caching, and security. A load balancer is a reverse proxy that additionally distributes traffic across multiple backend servers using an algorithm (round robin, least connections, etc.). You'd use a reverse proxy without load balancing when you have a single backend server but want SSL termination, compression, static file serving, or rate limiting — all things nginx commonly does in front of a single app server.
9. A distributed monolith has the complexity of microservices with none of the benefits. It happens when services are tightly coupled: they must be deployed together (changes to one require deploying others), they share a database (defeating independent data ownership), or they make synchronous calls in chains (A calls B calls C calls D, and if any fails, everything fails). The result: you have 15 services to deploy and monitor, but you can't deploy any independently, and debugging requires tracing across all of them. A well-structured monolith would be simpler, faster, and more reliable.
10. They should likely be one service ("User Service" or "Identity Service"). 15 shared tables indicate deep data coupling — splitting them would mean either: (a) duplicating data across two databases (inconsistency risk), (b) one service calling the other for every operation involving shared tables (latency, coupling), or (c) keeping a shared database (defeating the purpose of separate services). The high degree of data sharing suggests these aren't truly separate domains. Split only if you can clearly divide the tables with minimal cross-references.

</details>

---

## Challenge Mission: "The Monolith Splitter"

### Scenario

You're a senior engineer at a mid-size e-commerce company (50 engineers, 500K DAU). The monolithic application has these major components:

| Component | Responsibility | Traffic | Team Size |
|-----------|---------------|---------|-----------|
| **Auth** | Login, registration, sessions, password reset | 5% of requests | 3 engineers |
| **Catalog** | Product listings, search, categories, pricing | 40% of requests | 8 engineers |
| **Orders** | Cart, checkout, order history, returns | 25% of requests | 10 engineers |
| **Payments** | Payment processing, refunds, invoicing | 10% of requests | 5 engineers |
| **Notifications** | Email, SMS, push notifications | 15% of requests | 4 engineers |
| **Recommendations** | "You might also like", personalized feeds | 5% of requests | 6 engineers |

**Current problems:**
- Deploying a Catalog change requires deploying the entire app (20-minute deploy, affects all components)
- The Recommendations team wants to use Python/ML but the monolith is in Java
- Catalog needs 10x more servers than Payments, but they scale together
- A bug in Notifications caused an OOM crash that took down the entire application last month

**Database dependencies:**
- Auth and Orders share the `users` table
- Orders and Payments share the `transactions` table
- Catalog and Recommendations both read the `products` table
- Notifications reads from `users`, `orders`, and `products` (send-only, never writes)

### Your Task

**Part 1 — Splitting Decisions**

1. Which components would you split into separate services? Rank them by priority (split first → split last).
2. For each split, explain your reasoning (what problem it solves).
3. Which components should NOT be split (and stay in the monolith)? Why?

**Part 2 — Data Ownership**

For each service you split out:
1. Which database tables does it own?
2. How does it access data it needs from other services?
3. Where are the shared tables, and who owns them?

**Part 3 — Communication Design**

For each pair of services that need to communicate:
1. Sync or async? Why?
2. What protocol? (HTTP, gRPC, message queue)
3. What happens if the called service is down?

**Part 4 — Migration Strategy**

1. Do you split everything at once or incrementally? Why?
2. What's the order of migration?
3. How do you handle the transition period where some components are services and others are still in the monolith?

### Constraints

- You cannot stop feature development during the migration
- Each service must be independently deployable
- The existing Java monolith must remain operational during migration
- Budget for new infrastructure: $10,000/month additional

### Hints

<details>
<summary>Hint 1: Priority ranking</summary>
Rank based on the pain each split solves. The Notifications crash affected everyone (high blast radius). The Recommendations team is blocked on technology (team productivity). The Catalog scaling issue wastes money (cost). Which pain is most urgent?
</details>

<details>
<summary>Hint 2: The Strangler Fig pattern</summary>
You don't replace a monolith overnight. The Strangler Fig pattern: put a reverse proxy in front of the monolith. Route specific endpoints to the new service, everything else to the monolith. Gradually move endpoints until the monolith is empty.
</details>

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 1:

- **Reverse proxy** — Server that sits in front of backends, providing SSL termination, compression, caching, and security. Invisible to clients.
- **Forward proxy** — Server that sits in front of clients, providing privacy, caching, and access control. Invisible to servers.
- **Monolith** — Application architecture where all functionality is in a single codebase and deployment unit.
- **Microservices** — Application architecture where each feature is a separate service with its own codebase, deployment, and database.
- **API Gateway** — A reverse proxy that routes requests to microservices, handles cross-cutting concerns (auth, rate limiting, aggregation).
- **Service discovery** — Mechanism for services to find each other's network addresses in a dynamic environment.
- **Strangler Fig pattern** — Migration strategy where a new system gradually replaces a legacy system by intercepting requests at the proxy layer.
- **Distributed monolith** — Anti-pattern where microservices are so tightly coupled they must be deployed together, giving the worst of both architectures.
