# Lecture 1: How the Internet Works

> Module 1 — "The Request Journey" | Lecture 1 of 20

You use the internet every day. But do you actually know what happens between pressing Enter and seeing a web page? This lecture traces the full journey of a single HTTP request — from your browser to a server on another continent and back. Every layer you learn here will show up again in later lectures, so take the time to build a solid mental model.

---

## Pre-Reading

**Read these sections from the [System Design Primer](../../deps/system-design-primer/README.md) before starting this lecture:**

- *Domain name system* — how domain names map to IP addresses
- *Communication* (first half) — TCP and UDP fundamentals

Take notes on anything that surprises you. The lecture below will build on these sections, not repeat them.

---

## Concept Briefing

### What Happens When You Type a URL and Press Enter

Let's trace what happens when you type `https://photos.example.com/album/42` into your browser. This single action triggers a cascade of network operations that touch nearly every system design concept in this course.

**Step 1: URL Parsing**

Your browser parses the URL into components:
- Protocol: `https`
- Host: `photos.example.com`
- Path: `/album/42`
- Port: 443 (implicit — HTTPS default)

The browser checks its local cache first. If you visited this page recently, it might already have the DNS result, or even the page itself, cached.

**Step 2: DNS Resolution**

The browser needs to convert `photos.example.com` into an IP address. This is where the Domain Name System comes in.

**Step 3: TCP Connection**

Once the browser has an IP address (say, `93.184.216.34`), it opens a TCP connection to port 443 using the three-way handshake.

**Step 4: TLS Handshake**

Because this is HTTPS, the browser and server negotiate encryption before any data is exchanged. This adds 1-2 round trips.

**Step 5: HTTP Request**

The browser sends an HTTP GET request for `/album/42`.

**Step 6: Server Processing**

The server receives the request, processes it (authentication, database queries, business logic), and builds a response.

**Step 7: HTTP Response**

The server sends back a response with a status code, headers, and body (usually HTML).

**Step 8: Rendering**

The browser parses the HTML, discovers it needs CSS, JavaScript, and images, and fires off additional requests for each. These often go in parallel.

This entire sequence — all 8 steps — typically happens in under 500 milliseconds for a well-optimized site. Understanding each step is the foundation of system design.

---

## Deep Dive

### DNS — The Internet's Phone Book

DNS translates human-readable domain names (`photos.example.com`) into machine-readable IP addresses (`93.184.216.34`). Without it, you'd have to memorize IP addresses for every website.

#### How DNS Resolution Works

When your browser needs to resolve a domain name, it follows this chain:

```
Browser Cache → OS Cache → Router Cache → ISP's DNS Resolver → Root → TLD → Authoritative
```

1. **Browser cache** — Chrome, Firefox, etc. cache DNS results. Check Chrome's cache: `chrome://net-internals/#dns`
2. **OS cache** — Your operating system has its own DNS cache
3. **Router cache** — Your home/office router often caches DNS results
4. **ISP's recursive resolver** — If no cache hits, your ISP's DNS server starts the recursive lookup
5. **Root nameserver** — 13 root server clusters worldwide. Returns the TLD server address
6. **TLD nameserver** — Handles `.com`, `.org`, `.io`, etc. Returns the authoritative server address
7. **Authoritative nameserver** — The final authority. Returns the actual IP address

#### Recursive vs Iterative Queries

- **Recursive:** Your browser asks the ISP resolver, which does all the work and returns the final answer. The client makes one request and gets one response. This is what most clients use.
- **Iterative:** The DNS server returns a referral ("I don't know, but ask this server next"). The client must follow each referral itself. Root and TLD servers typically use this mode.

In practice, your ISP resolver handles recursive queries from clients, and itself makes iterative queries to root/TLD/authoritative servers.

#### DNS Caching and TTL

Every DNS record has a **TTL (Time to Live)** — how many seconds the result can be cached before it expires.

| TTL | Use Case | Trade-off |
|-----|----------|-----------|
| 60s | Services that change IPs frequently (failover, blue-green deploys) | More DNS lookups, higher latency; but fast failover |
| 3600s (1 hour) | Most web services | Good balance of caching and freshness |
| 86400s (1 day) | Stable services that rarely change | Minimal DNS traffic; slow to propagate changes |

**Why TTL matters for system design:** If you're designing a system that needs fast failover, you need low DNS TTLs. But low TTLs mean more DNS queries, which increases load on your DNS infrastructure. This is your first trade-off.

#### DNS Record Types

| Type | Purpose | Example |
|------|---------|---------|
| **A** | Maps domain to IPv4 address | `example.com → 93.184.216.34` |
| **AAAA** | Maps domain to IPv6 address | `example.com → 2606:2800:220:1:...` |
| **CNAME** | Alias — maps domain to another domain | `www.example.com → example.com` |
| **MX** | Mail server for the domain | `example.com → mail.example.com` |
| **NS** | Nameserver for the domain | `example.com → ns1.example.com` |
| **TXT** | Arbitrary text (often used for verification) | SPF records, domain ownership proof |

#### What Happens When DNS Fails

DNS is a single point of failure for the entire internet experience. If DNS resolution fails:
- Users see "DNS_PROBE_FINISHED_NXDOMAIN" or similar errors
- The site appears completely down even if the servers are healthy
- Cached DNS results (at the browser, OS, or resolver level) provide temporary resilience

This is why large systems use multiple DNS providers, and why some CDNs like Cloudflare also provide DNS services — reducing the number of things that can fail independently.

---

### TCP/IP — The Reliable Delivery System

#### The 4-Layer Model

The TCP/IP model has four layers, each with a specific responsibility:

```
┌─────────────────────┐
│   Application       │  HTTP, HTTPS, FTP, SMTP, DNS
│   (Layer 4)         │  "What data to send"
├─────────────────────┤
│   Transport         │  TCP, UDP
│   (Layer 3)         │  "How to deliver reliably (or fast)"
├─────────────────────┤
│   Internet          │  IP, ICMP
│   (Layer 2)         │  "How to route across networks"
├─────────────────────┤
│   Link              │  Ethernet, Wi-Fi
│   (Layer 1)         │  "How to send bits on the wire"
└─────────────────────┘
```

For system design, you mainly care about the Application and Transport layers. The lower layers are handled by the OS and network infrastructure.

#### The TCP Three-Way Handshake

Before any data flows, TCP establishes a connection:

```
Client                    Server
  |                         |
  |--- SYN (seq=x) ------->|    1. "I want to connect"
  |                         |
  |<-- SYN-ACK (seq=y, -----|    2. "OK, I acknowledge"
  |    ack=x+1)             |
  |                         |
  |--- ACK (ack=y+1) ----->|    3. "Got it, let's go"
  |                         |
  |=== Data can flow now ===|
```

**Why this matters for system design:** Every new TCP connection costs 1 round trip (1.5 if you count the SYN). At intercontinental distances (~150ms round trip), this latency adds up. This is why:
- **HTTP keep-alive** reuses TCP connections across multiple requests
- **Connection pooling** in application servers avoids repeated handshakes
- **HTTP/2** multiplexes many requests over a single TCP connection

#### TCP Guarantees

TCP provides three guarantees that UDP does not:

1. **Reliable delivery** — Lost packets are detected and retransmitted
2. **Ordered delivery** — Packets arrive in the order they were sent
3. **Flow control** — The sender won't overwhelm the receiver
4. **Congestion control** — The sender adapts to network congestion

The cost: **latency**. Retransmissions, acknowledgments, and flow control all add overhead. For some applications, this cost is too high.

---

### HTTP/HTTPS — The Language of the Web

#### The Request/Response Cycle

Every HTTP interaction follows the same pattern:

```
Client sends:                  Server sends:
┌─────────────────┐            ┌──────────────────┐
│ GET /album/42   │            │ 200 OK           │
│ Host: photos... │  ------->  │ Content-Type:    │
│ Accept: text/.. │  <-------  │   text/html      │
│ Cookie: ...     │            │                  │
└─────────────────┘            │ <html>...</html> │
     Request                   └──────────────────┘
                                    Response
```

#### Status Codes You Must Know

| Range | Category | Examples |
|-------|----------|---------|
| **2xx** | Success | `200 OK`, `201 Created`, `204 No Content` |
| **3xx** | Redirect | `301 Moved Permanently`, `302 Found`, `304 Not Modified` |
| **4xx** | Client Error | `400 Bad Request`, `401 Unauthorized`, `403 Forbidden`, `404 Not Found`, `429 Too Many Requests` |
| **5xx** | Server Error | `500 Internal Server Error`, `502 Bad Gateway`, `503 Service Unavailable`, `504 Gateway Timeout` |

**For system design:** Pay special attention to `429` (rate limiting), `503` (overloaded), and `504` (upstream timeout). These are the codes you'll see when systems are under stress, and they directly relate to load balancers, back pressure, and circuit breakers — topics in later lectures.

#### Key Headers

| Header | Purpose | System Design Relevance |
|--------|---------|------------------------|
| `Cache-Control` | How long to cache the response | CDN behavior, client caching (Lecture 3, 9) |
| `Content-Type` | Format of the response body | API design (Lecture 14) |
| `Authorization` | Authentication credentials | Security (Lecture 15) |
| `X-Request-ID` | Trace ID for distributed tracing | Observability (Lecture 13) |
| `Retry-After` | When to retry after a 429 or 503 | Rate limiting (Lecture 14) |

#### HTTP Versions

| Version | Key Feature | Impact |
|---------|------------|--------|
| HTTP/1.0 | One request per connection | Slow — new TCP handshake every time |
| HTTP/1.1 | Keep-alive connections, pipelining | Reuses connections; still head-of-line blocking |
| HTTP/2 | Multiplexing, header compression, server push | Multiple requests on one connection, truly parallel |
| HTTP/3 | QUIC (UDP-based), no head-of-line blocking | Faster connection setup, better on lossy networks |

---

### UDP — When Speed Beats Reliability

UDP strips away TCP's guarantees in exchange for raw speed:

- **No handshake** — data flows immediately
- **No retransmissions** — lost packets are just gone
- **No ordering** — packets can arrive out of sequence
- **No congestion control** — sends as fast as it wants

#### When to Use UDP

| Use Case | Why UDP? |
|----------|----------|
| **DNS lookups** | Tiny request/response, retransmission at the app level is fine |
| **Video streaming** | A dropped frame is better than a delayed one |
| **Online gaming** | Stale position data is worse than missing one update |
| **Voice/video calls** | Latency matters more than perfect audio |
| **Metrics/logging** | Losing a few data points is acceptable |

**The key insight:** UDP doesn't mean "unreliable." It means "I'll handle reliability myself at the application level, if I even need it." Many protocols build their own reliability on top of UDP (e.g., QUIC, which powers HTTP/3).

---

## Discussion Prompts

Think through these questions. When you're ready, discuss your reasoning with Claude.

1. **Why doesn't the browser just connect to web servers directly by IP address, bypassing DNS entirely?** What would break, and what problems would DNS's absence create for system design?

2. **HTTP/2 multiplexes many requests over a single TCP connection. What happens if that single connection drops? How does HTTP/3 solve this?** Think about this in terms of the TCP guarantees we discussed.

3. **If you were designing a real-time collaborative editor (like Google Docs), would you use TCP or UDP for transmitting keystrokes between users? What about for saving the document to the server?** Can you use different protocols for different parts of the same system?

---

## Field Ops: Server Survival

Open [Server Survival](../../deps/server-survival/index.html) and play **Sandbox mode** for 15 minutes.

Don't read any guides first. Just play blind and notice:
- Where does traffic enter the system?
- What happens when a service gets overwhelmed?
- Which services seem to depend on each other?

Write down what broke and why you think it broke in your [progress tracker](../progress.md) under "Notes & Aha Moments > Module 1."

This baseline experience is important — you'll return to the game after Lecture 4 with specific goals and see how much your intuition has improved.

---

## Knowledge Check

Record your score in [progress.md](../progress.md).

### Fill in the Blank (3 points)

1. The DNS record type that maps a domain name to an IPv4 address is called an ______ record.

2. TCP ensures packets arrive in the correct order through ______ delivery, while UDP provides no such guarantee.

3. When a DNS resolver receives a query and follows referrals from root to TLD to authoritative server itself, rather than returning referrals to the client, this is called a ______ query.

### Multiple Choice (4 points)

4. A client connects to a server over TCP. How many round trips does the three-way handshake require before data can be sent?

   - a) 0 — TCP is connectionless
   - b) 1 — SYN, SYN-ACK, then data flows with the ACK
   - c) 2 — SYN, SYN-ACK, ACK, then data
   - d) 3 — SYN, SYN-ACK, ACK, then another confirmation

5. Your DNS record has a TTL of 3600 seconds. You update the IP address it points to. What is the worst-case delay before ALL clients see the new IP?

   - a) Instantly — DNS updates are immediate
   - b) 3600 seconds (1 hour) — cached entries must expire
   - c) Longer than 3600 seconds — intermediate caches may have their own TTLs
   - d) 24 hours — DNS always takes a day to propagate

6. A real-time multiplayer game needs to send player position updates 60 times per second. Which protocol is more appropriate and why?

   - a) TCP — reliability ensures no positions are lost
   - b) UDP — latency matters more than receiving every single update
   - c) HTTP — it's the standard web protocol
   - d) TCP with keep-alive — solves the latency problem

7. An HTTP response returns status code 304. What does this mean?

   - a) The resource was permanently moved to a new URL
   - b) The server encountered an internal error
   - c) The resource has not been modified since the client last requested it
   - d) The client's request was malformed

### Short Answer (3 points)

8. Explain why HTTP keep-alive exists. What performance problem does it solve, and what is the trade-off of keeping connections open?

9. A company's website goes down, but their servers are running fine. DNS resolution is failing. Explain two reasons DNS could fail and one way to reduce this risk.

10. You're designing a video streaming service. The video player uses UDP for streaming, but the user's account page uses HTTPS. Why would you use different protocols for different parts of the same application?

<details>
<summary>Answer Key</summary>

1. **A** (A record)
2. **ordered** (or "in-order" / "sequential")
3. **recursive**
4. **b)** — The three-way handshake is SYN, SYN-ACK, ACK. Data can piggyback on the third packet (the ACK), so effectively 1 round trip before data flows. (Some sources say 1.5 RTT because the ACK is the start of the second round trip, but in terms of delay before the client can send data, it's 1 RTT.)
5. **c)** — While the authoritative TTL is 1 hour, intermediate resolvers and caches may have cached the old result with their own policies. In practice, propagation can exceed the TTL. This is why DNS changes are described as "propagating" rather than being instant.
6. **b)** — At 60 updates/second, a single lost update is immediately superseded by the next one. TCP's retransmission would add latency for a packet that's already stale. UDP lets the game prioritize freshness over completeness.
7. **c)** — 304 Not Modified means the client's cached version is still valid. The server sends no body, saving bandwidth. This is how browser caching works with `If-Modified-Since` or `ETag` headers.
8. Without keep-alive, every HTTP request requires a new TCP connection (three-way handshake + TLS handshake for HTTPS). For a page with 50 resources, that's 50 separate connections. Keep-alive reuses a single TCP connection for multiple requests, eliminating repeated handshake latency. The trade-off: the server must keep connections open, consuming memory and file descriptors. If too many clients hold idle connections, the server can run out of resources.
9. DNS can fail because: (1) The authoritative nameserver is down or unreachable — if the server hosting your DNS records crashes, no one can resolve your domain. (2) A DDoS attack on your DNS provider — the 2016 Dyn attack took down Twitter, GitHub, and Netflix by attacking their DNS provider. To reduce this risk: use multiple DNS providers (e.g., Route 53 + Cloudflare) so that if one fails, the other still resolves.
10. Video streaming prioritizes low latency and can tolerate packet loss — a dropped frame is barely noticeable, but a delayed frame causes buffering. UDP is ideal here. The account page handles sensitive data (login, payment info) that must be delivered reliably and securely — TCP + TLS guarantees both. Different parts of a system have different requirements, so they can (and should) use different protocols.

</details>

---

## Challenge Mission: "Trace the Path"

### Scenario

A user in Tokyo opens their browser and types: `https://photos.example.com/album/42`

The server hosting this site is in Virginia, USA. The site uses:
- A DNS provider with servers in multiple regions
- HTTPS (TLS 1.3)
- HTTP/2
- A response that includes an HTML page, 3 CSS files, 12 images, and 2 JavaScript files

### Your Task

Trace the **complete journey** of this request. For each step, identify:
1. What happens
2. Which protocol is used
3. The approximate latency added
4. What could go wrong

Use this template — fill in every blank:

```
STEP 1: DNS Resolution
  Protocol: ______
  What happens: The browser looks up photos.example.com. Cache check order: ______, ______, ______, ______.
  If no cache hit, the ISP resolver queries: ______ → ______ → ______.
  Approximate latency: ______ (cache hit) / ______ (full resolution)
  Failure mode: ______

STEP 2: TCP Connection
  Protocol: ______
  What happens: ______
  Number of round trips: ______
  Approximate latency (Tokyo → Virginia): ______
  Failure mode: ______

STEP 3: TLS Handshake
  Protocol: ______
  What happens: ______
  Additional round trips: ______
  Approximate latency: ______
  Failure mode: ______

STEP 4: HTTP Request
  Protocol: ______
  Method: ______
  Key headers the browser sends: ______, ______, ______
  Approximate latency: ______ (included in existing connection)
  Failure mode: ______

STEP 5: Server Processing
  What happens: ______
  Components likely involved: ______, ______, ______
  Approximate latency: ______
  Failure mode: ______

STEP 6: HTTP Response
  Status code (success): ______
  Key headers the server sends: ______, ______, ______
  Body: ______
  Approximate latency: ______ (included in existing connection)

STEP 7: Subsequent Requests
  Resources needed: ______ CSS files, ______ images, ______ JS files
  How HTTP/2 helps: ______
  How many TCP connections needed with HTTP/2 vs HTTP/1.1: ______

TOTAL: Estimate end-to-end time from Enter to fully loaded page: ______
```

### Constraints

- Tokyo to Virginia round-trip latency: ~160ms
- Assume the DNS result is NOT cached (worst case)
- The server's response time for database query + rendering: ~50ms
- Each image is ~200KB, CSS/JS files are ~50KB each

### Hints (use only if stuck)

<details>
<summary>Hint 1: DNS latency</summary>
A full DNS resolution with no cache hits typically takes 20-120ms depending on how many servers need to be queried and their geographic distribution. With the ISP resolver in Tokyo, but root/TLD servers potentially elsewhere, expect the higher end.
</details>

<details>
<summary>Hint 2: TLS 1.3 round trips</summary>
TLS 1.3 requires only 1 round trip for the handshake (compared to 2 for TLS 1.2). On a resumption (returning visitor), it can be 0 round trips (0-RTT).
</details>

<details>
<summary>Hint 3: HTTP/2 multiplexing</summary>
HTTP/2 can send all 17 subsequent requests (3 CSS + 12 images + 2 JS) over the same TCP connection in parallel. HTTP/1.1 browsers typically open 6 parallel connections per domain.
</details>

When you've completed the template, discuss your trace with Claude. Compare your latency estimates to see if the total makes sense.

---

## Glossary Terms

Add these to your [glossary](../glossary.md) under Module 1:

- **DNS (Domain Name System)** — Translates domain names to IP addresses. Hierarchical, cached at multiple levels.
- **TTL (Time to Live)** — How long a DNS record or cached response can be reused before it must be refreshed.
- **TCP (Transmission Control Protocol)** — Reliable, ordered, connection-based transport protocol. Used by HTTP, HTTPS.
- **UDP (User Datagram Protocol)** — Fast, connectionless transport protocol. No reliability or ordering guarantees.
- **Three-way handshake** — TCP connection establishment: SYN → SYN-ACK → ACK.
- **HTTP (Hypertext Transfer Protocol)** — Application-layer protocol for web communication. Request/response model.
- **TLS (Transport Layer Security)** — Encryption protocol that provides HTTPS. Adds 1-2 round trips to connection setup.
- **Round trip time (RTT)** — Time for a packet to travel from sender to receiver and back. Key latency metric.
- **Keep-alive** — HTTP feature that reuses TCP connections across multiple requests, avoiding repeated handshakes.
