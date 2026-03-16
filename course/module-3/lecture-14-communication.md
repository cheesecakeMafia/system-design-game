# Lecture 14: Communication Protocols & API Design

> Module 3 — "The Distributed Mind" | Lecture 14 of 20

Systems are made of components that talk to each other. The choice of communication protocol — TCP, UDP, HTTP, gRPC, WebSockets — determines the performance characteristics of every interaction. This lecture covers protocols and the practical API design patterns (pagination, rate limiting, idempotency) that make APIs production-ready.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Communication*
- *Transmission control protocol (TCP)*
- *User datagram protocol (UDP)*
- *Remote procedure call (RPC)*
- *Representational state transfer (REST)*

---

## Deep Dive

### Protocol Comparison

| Protocol | Layer | Connection | Reliability | Speed | Use Case |
|----------|-------|-----------|-------------|-------|----------|
| **TCP** | Transport | Connection-oriented | Guaranteed delivery + ordering | Slower (handshake, ACKs) | Most internet traffic |
| **UDP** | Transport | Connectionless | No guarantees | Faster (no overhead) | Streaming, gaming, DNS |
| **HTTP/REST** | Application | Request/response over TCP | Via TCP | Moderate | Public APIs, web |
| **gRPC** | Application | HTTP/2 + Protobuf | Via TCP | Fast (binary, multiplexed) | Internal microservices |
| **WebSocket** | Application | Persistent bidirectional over TCP | Via TCP | Low latency | Real-time features |
| **GraphQL** | Application | Request/response over HTTP | Via TCP | Varies | Flexible client queries |

### RPC — Remote Procedure Call

RPC makes calling a function on a remote server look like calling a local function.

```
Client code:
  result = user_service.GetUser(user_id=42)
  # Looks local, but actually sends a network request

What actually happens:
  1. Client serializes the request (user_id=42) into bytes
  2. Sends bytes over the network to the server
  3. Server deserializes, executes GetUser(42)
  4. Server serializes the response
  5. Sends response bytes back
  6. Client deserializes and returns the result
```

#### gRPC

Google's modern RPC framework. Built on HTTP/2 with Protocol Buffers (protobuf) for serialization.

```protobuf
// user.proto — defines the API contract
service UserService {
  rpc GetUser (GetUserRequest) returns (User);
  rpc ListUsers (ListUsersRequest) returns (stream User);
}

message GetUserRequest {
  int64 user_id = 1;
}

message User {
  int64 id = 1;
  string name = 2;
  string email = 3;
}
```

| Feature | gRPC | REST |
|---------|------|------|
| **Serialization** | Protobuf (binary, compact) | JSON (text, human-readable) |
| **Speed** | ~10x faster serialization | Slower, but readable |
| **Streaming** | Native (server, client, bidirectional) | No native streaming |
| **Browser support** | Limited (needs grpc-web proxy) | Universal |
| **Code generation** | Auto-generates client/server code from .proto | Manual or codegen tools |
| **Human debugging** | Hard (binary format) | Easy (curl, browser) |

**When to use gRPC:** Internal microservice communication where speed matters and both sides are controlled by your team.

**When to use REST:** Public APIs, browser clients, or when human readability of requests/responses is important.

### REST — The Web's Standard

REST (Representational State Transfer) is an architectural style, not a protocol. Key constraints:

1. **Stateless** — Each request contains all information needed. No server-side session.
2. **Uniform interface** — Resources identified by URLs, manipulated through HTTP methods.
3. **Cacheable** — Responses indicate whether they can be cached.

```
GET    /users/42          → Read user 42
POST   /users             → Create a new user
PUT    /users/42          → Replace user 42 entirely
PATCH  /users/42          → Update specific fields of user 42
DELETE /users/42          → Delete user 42
```

#### Richardson Maturity Model

| Level | Description | Example |
|-------|-------------|---------|
| 0 | Single URI, single HTTP method | POST /api with action in body |
| 1 | Multiple URIs (resources) | /users, /orders — but only POST |
| 2 | HTTP methods used correctly | GET /users, POST /orders, DELETE /users/42 |
| 3 | Hypermedia (HATEOAS) | Response includes links to related actions |

Most production APIs are Level 2. Level 3 (HATEOAS) is theoretically ideal but rarely implemented in practice.

### GraphQL — Client-Driven Queries

The client specifies exactly what data it needs. No over-fetching, no under-fetching.

```graphql
# Client requests exactly what it needs:
query {
  user(id: 42) {
    name
    email
    posts(limit: 5) {
      title
      likes
    }
  }
}
```

| Pros | Cons |
|------|------|
| No over-fetching (client gets exactly what it asks for) | Complex server implementation |
| One endpoint replaces many REST endpoints | N+1 queries on the server if not careful |
| Great for mobile (minimize data transfer) | Caching is harder (every query is unique) |
| Self-documenting schema | Potential for expensive queries (deeply nested) |

**When to use:** When clients have diverse data needs (mobile vs web vs third-party), and you want to avoid building 50 specialized REST endpoints.

### WebSockets — Real-Time Bidirectional

A persistent, full-duplex connection between client and server.

```
1. Client → Server: HTTP Upgrade request
2. Server → Client: 101 Switching Protocols
3. Both can send messages at any time (no request/response pattern)
```

| Use Case | Why WebSocket? |
|----------|---------------|
| Chat applications | Both sides send messages independently |
| Live sports scores | Server pushes updates as they happen |
| Collaborative editing | Multiple users' changes streamed in real-time |
| Stock tickers | Sub-second price updates |
| Gaming | Low-latency bidirectional state sync |

**Alternative: Server-Sent Events (SSE)** — One-way (server → client) push over HTTP. Simpler than WebSockets when you only need server-to-client updates.

### Choosing Protocols — Decision Matrix

| Requirement | Protocol |
|-------------|----------|
| Public API for third-party developers | REST (HTTP/JSON) |
| Internal service-to-service, high throughput | gRPC |
| Real-time bidirectional (chat, gaming) | WebSocket |
| Real-time server → client only (notifications) | SSE or WebSocket |
| Client needs flexible data queries | GraphQL |
| Unreliable but fast (video, gaming state) | UDP |
| Reliable file transfer | TCP (raw) or HTTP |

---

### API Design Patterns

These patterns make APIs production-ready. You'll use them in every system design.

#### Pagination

When a query returns thousands of results, you can't return them all at once.

**Offset-based pagination:**
```
GET /posts?offset=0&limit=20    → Posts 1-20
GET /posts?offset=20&limit=20   → Posts 21-40
```

| Pros | Cons |
|------|------|
| Simple to implement | Skips or duplicates items if data changes between pages |
| Client can jump to any page | Performance degrades at high offsets (DB must scan past all skipped rows) |

**Cursor-based pagination:**
```
GET /posts?limit=20                       → Posts 1-20, cursor="abc123"
GET /posts?limit=20&after_cursor=abc123   → Posts 21-40, cursor="def456"
```

| Pros | Cons |
|------|------|
| Consistent results even when data changes | Can't jump to arbitrary pages |
| Performance doesn't degrade at deep pages | Slightly more complex implementation |
| No skipped/duplicate items | |

**Rule of thumb:** Use cursor-based pagination for large datasets. Use offset for small datasets or when "jump to page N" is required.

#### Rate Limiting

Protect your API from abuse and overload.

**Token Bucket:**
```
Bucket holds N tokens. Refills at R tokens/second.
Each request costs 1 token.
If bucket is empty → reject request (429 Too Many Requests).
```
Allows brief bursts (up to bucket size) while enforcing average rate.

**Sliding Window:**
```
Count requests in the last N seconds.
If count > limit → reject.
```
Smoother than fixed windows (which reset at minute boundaries and allow double the rate at boundaries).

**Rate limit headers:**
```
X-RateLimit-Limit: 100        (max requests per window)
X-RateLimit-Remaining: 42     (requests left in current window)
X-RateLimit-Reset: 1679356800 (unix timestamp when window resets)
Retry-After: 30               (seconds to wait before retrying, on 429)
```

#### Idempotency

An idempotent operation produces the same result whether executed once or multiple times.

**Why it matters:** Network failures cause retries. If a client sends a payment request, gets a timeout, and retries — without idempotency, the payment might be processed twice.

**Idempotency keys:**
```
POST /payments
Idempotency-Key: "abc-123-def-456"
Body: {amount: 99.99, card: "..."}

First time: processes payment, stores result keyed by "abc-123-def-456"
Retry:      looks up "abc-123-def-456", returns stored result (no reprocessing)
```

HTTP methods and idempotency:
| Method | Idempotent? | Safe? |
|--------|------------|-------|
| GET | Yes | Yes (no side effects) |
| PUT | Yes | No (replaces resource) |
| DELETE | Yes | No (same result: resource gone) |
| POST | **No** | No (creates new resource each time) |
| PATCH | It depends | No |

POST is the problem child. Idempotency keys solve it.

#### API Versioning

How to evolve an API without breaking existing clients.

| Strategy | Example | Pros | Cons |
|----------|---------|------|------|
| **URL path** | `/v1/users`, `/v2/users` | Clear, easy to route | URL pollution, hard to sunset |
| **Header** | `Accept: application/vnd.api.v2+json` | Clean URLs | Less discoverable |
| **Query param** | `/users?version=2` | Simple | Feels hacky |

**Best practice:** URL path versioning (`/v1/`, `/v2/`) is the most common and least confusing for API consumers. Only introduce a new version for breaking changes. For non-breaking changes (adding a field), just add it to the current version.

---

## Discussion Prompts

1. **You're building a ride-sharing app. The rider's phone needs real-time location updates from the driver (every 1 second) and also needs to call REST APIs for ride booking and payment. How many protocols are you using and why?**

2. **Your public API uses offset-based pagination. A client fetches page 1 (items 1-20). While they're reading, 3 new items are inserted at the top. They fetch page 2 (items 21-40). What do they see?** How does cursor-based pagination solve this?

3. **A payment API processes $99.99 charges. Due to a network issue, the client sends the same request 3 times (no idempotency key). The customer is charged $299.97. How would you prevent this?** Design the idempotency system.

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. The rate limiting algorithm that allows brief traffic bursts while enforcing an average rate is called ______.

2. An API operation that produces the same result whether executed once or multiple times is called ______.

3. gRPC uses ______ (a binary serialization format) instead of JSON, which makes it approximately 10x faster for serialization.

### Multiple Choice (4 points)

4. You're building internal communication between 15 microservices that exchange structured data at high throughput. Which protocol is most appropriate?

   - a) REST with JSON
   - b) gRPC with Protocol Buffers
   - c) WebSockets
   - d) GraphQL

5. A client fetches page 50 using offset-based pagination (`offset=980&limit=20`) on a table with 10 million rows. What performance issue might occur?

   - a) The query returns too much data
   - b) The database must scan past 980 rows before returning results
   - c) The connection times out because of pagination
   - d) No performance issue — offset pagination is always efficient

6. Your API receives a POST request with `Idempotency-Key: xyz-123`. The server processes it and returns 200. The same request arrives again with the same key. What should happen?

   - a) Process the request again (POST is not idempotent)
   - b) Return the stored result from the first request without reprocessing
   - c) Return 409 Conflict
   - d) Return 400 Bad Request

7. A notification system needs to push real-time alerts from server to client. The client never sends messages to the server through this channel. Which protocol is simplest?

   - a) WebSocket (bidirectional)
   - b) Server-Sent Events (SSE, unidirectional)
   - c) Polling (client asks every second)
   - d) gRPC streaming

### Short Answer (3 points)

8. Compare REST and gRPC for a public-facing API. Why is REST typically chosen over gRPC for public APIs, despite gRPC being faster?

9. Design a rate limiting strategy for an API that serves both free and paid users. Free users: 100 requests/minute. Paid users: 1,000 requests/minute. What happens when a free user exceeds their limit?

10. A client sends a payment request, receives a timeout (no response), and doesn't know if the payment was processed. Without idempotency, what are the two bad outcomes? With an idempotency key, what happens when they retry?

<details>
<summary>Answer Key</summary>

1. **token bucket**
2. **idempotent**
3. **Protocol Buffers** (protobuf)
4. **b)** — gRPC with protobuf is designed for internal service communication: fast binary serialization, auto-generated client/server code, native streaming, HTTP/2 multiplexing. REST/JSON (a) is slower and more verbose for internal use. WebSockets (c) are for bidirectional real-time communication, not request/response. GraphQL (d) is for flexible client queries, not high-throughput service-to-service.
5. **b)** — With offset-based pagination, the database must scan past 980 rows to reach the starting point. At offset=980, this is minor. But at offset=9,800,000, the database scans 9.8M rows before returning 20. This is O(offset) performance degradation — cursor-based pagination avoids this by using an indexed starting point.
6. **b)** — The server recognizes the idempotency key, looks up the stored result from the first processing, and returns it without reprocessing. This is the entire purpose of idempotency keys — making retries safe.
7. **b)** — SSE is the simplest for server-to-client-only push. It uses standard HTTP, auto-reconnects, and requires no special client library (browser EventSource API). WebSocket (a) works but is overkill for unidirectional communication. Polling (c) wastes resources. gRPC streaming (d) requires gRPC infrastructure.
8. REST is typically chosen for public APIs because: (1) **Browser support** — REST works natively in any browser; gRPC requires a proxy (grpc-web). (2) **Human readability** — JSON responses can be read and debugged with curl, browser dev tools, or Postman. Protobuf is binary. (3) **Ubiquity** — Every programming language has HTTP/JSON libraries. gRPC client libraries are less universal. (4) **Discoverability** — REST APIs can be explored with documentation tools (Swagger/OpenAPI). gRPC requires the .proto file. For internal APIs where both sides are controlled, gRPC's speed advantage matters. For public APIs where developer experience matters, REST wins.
9. Strategy: Use token bucket per API key. Free users get a bucket of 100 tokens that refills at 100/minute. Paid users get 1,000 tokens refilling at 1,000/minute. Identify user tier from the API key. When a free user exceeds the limit: return 429 Too Many Requests with headers `Retry-After: 30` and `X-RateLimit-Remaining: 0`. Optionally include an upgrade prompt: "Upgrade to paid for 10x higher limits." Don't silently drop requests — always return a clear error.
10. Without idempotency: (1) **Double charge** — The payment was processed, but the client didn't get the response. They retry. The payment processes again. Customer charged twice. (2) **Missed payment** — The client doesn't retry (gives up). The payment actually failed on the first attempt. The order goes unprocessed. Both outcomes are bad. With an idempotency key: The client retries with the same key. The server checks: "Did I already process key xyz-123?" If yes → return the stored result (success or failure). If no → process normally. Either way, the payment is processed exactly once regardless of retries.

</details>

---

## Challenge Mission: "The Protocol Picker"

### Scenario

You're designing the communication layer for five different features. For each, choose the protocol and justify your decision.

**Feature 1: Real-Time Multiplayer Game**
- 1,000 concurrent players per game instance
- Player positions update 60 times per second
- Losing a position update is acceptable (next one arrives in 16ms)
- Latency must be <50ms

**Feature 2: Public REST API**
- Used by 10,000 third-party developers
- Returns JSON data about products and orders
- Must be cacheable, well-documented, easy to debug
- 50,000 requests/second at peak

**Feature 3: Internal Microservice Communication**
- 20 services exchanging structured data
- Average request: 500 bytes
- 200,000 requests/second aggregate
- All services controlled by your team

**Feature 4: Large File Transfer**
- Users upload files up to 10 GB
- Uploads must be resumable (if connection drops at 90%, don't restart from 0)
- Download speed is critical

**Feature 5: Push Notifications**
- Server sends notifications to 10M connected mobile clients
- Notifications are infrequent (1-5 per user per day)
- Must arrive within 5 seconds of the triggering event

### Your Task

For each feature:
1. **Choose protocol(s)** — be specific (TCP, UDP, HTTP/REST, gRPC, WebSocket, SSE, etc.)
2. **Justify** — explain why this protocol fits the requirements
3. **Identify the trade-off** — what do you give up with this choice?

**Then for Feature 2 (Public REST API):**
4. Design the pagination strategy (cursor or offset? why?)
5. Design the rate limiting strategy (algorithm, limits per tier, headers)
6. Design the versioning strategy (how to handle breaking changes)

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 3:

- **RPC (Remote Procedure Call)** — Making remote service calls look like local function calls. gRPC is the modern standard.
- **gRPC** — Google's RPC framework using HTTP/2 + Protocol Buffers. Fast, typed, code-generated. Best for internal services.
- **REST** — Architectural style using HTTP methods on resources. Stateless, cacheable, human-readable. Best for public APIs.
- **GraphQL** — Query language where clients specify exactly what data they need. Prevents over/under-fetching.
- **WebSocket** — Persistent, full-duplex TCP connection. Both client and server can send messages at any time.
- **SSE (Server-Sent Events)** — One-way push from server to client over HTTP. Simpler than WebSocket for server→client only.
- **Cursor-based pagination** — Uses an opaque cursor as a bookmark. Consistent results, no performance degradation at deep pages.
- **Token bucket** — Rate limiting algorithm that allows bursts up to bucket size while enforcing average rate.
- **Idempotency key** — Client-generated unique ID for a request. Server uses it to deduplicate retries safely.
- **API versioning** — Strategy for evolving APIs without breaking existing clients. Common: URL path (/v1/, /v2/).
